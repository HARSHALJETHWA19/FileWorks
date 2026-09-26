import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../billing_constants.dart';

class BillingService {
  final SharedPreferences _prefs;
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final ValueNotifier<EntitlementState> stateNotifier =
      ValueNotifier<EntitlementState>(const EntitlementState());

  BillingService(this._prefs, [InAppPurchase? iap])
      : _iap = iap ?? InAppPurchase.instance;

  EntitlementState get state => stateNotifier.value;

  Future<void> initialize() async {
    // 1. Load initial cached state from SharedPreferences
    final isPro = _prefs.getBool(AppConstants.keyIsProUser) ?? false;
    final savedStatusStr = _prefs.getString(BillingConstants.keySubscriptionStatus);
    final savedProductId = _prefs.getString(BillingConstants.keySubscriptionProductId);
    final expiryMillis = _prefs.getInt(BillingConstants.keySubscriptionExpiry);

    DateTime? expiryDate;
    if (expiryMillis != null && expiryMillis > 0) {
      expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    }

    SubscriptionStatus initialStatus = SubscriptionStatus.free;
    if (isPro) {
      if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        initialStatus = SubscriptionStatus.premiumExpired;
        await _persistProStatus(false, initialStatus, savedProductId, expiryDate);
      } else {
        initialStatus = SubscriptionStatus.premiumActive;
      }
    } else if (savedStatusStr != null) {
      initialStatus = SubscriptionStatus.values.firstWhere(
        (e) => e.name == savedStatusStr,
        orElse: () => SubscriptionStatus.free,
      );
    }

    stateNotifier.value = EntitlementState(
      status: initialStatus,
      productId: savedProductId,
      expiryDate: expiryDate,
      isLoading: true,
    );

    // 2. Listen to purchase stream
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('IAP purchaseStream error: $error');
        stateNotifier.value = stateNotifier.value.copyWith(
          errorMessage: 'Billing error: $error',
          isLoading: false,
        );
      },
    );

    // 3. Check Play Store availability and query products
    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        debugPrint('Google Play Billing is unavailable on this device.');
        stateNotifier.value = stateNotifier.value.copyWith(
          status: isPro ? SubscriptionStatus.premiumActive : SubscriptionStatus.billingUnavailable,
          isLoading: false,
        );
        return;
      }

      await queryProducts();
    } catch (e) {
      debugPrint('Error initializing billing: $e');
      stateNotifier.value = stateNotifier.value.copyWith(
        status: isPro ? SubscriptionStatus.premiumActive : SubscriptionStatus.billingUnavailable,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> queryProducts() async {
    stateNotifier.value = stateNotifier.value.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _iap.queryProductDetails(BillingConstants.productIds);
      if (response.error != null) {
        debugPrint('QueryProductDetails error: ${response.error!.message}');
        stateNotifier.value = stateNotifier.value.copyWith(
          isLoading: false,
          errorMessage: response.error!.message,
        );
        return;
      }

      stateNotifier.value = stateNotifier.value.copyWith(
        products: response.productDetails,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Exception querying products: $e');
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> buySubscription(ProductDetails product) async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoading: true,
      status: SubscriptionStatus.purchasePending,
      errorMessage: null,
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        stateNotifier.value = stateNotifier.value.copyWith(
          isLoading: false,
          status: state.isPro ? SubscriptionStatus.premiumActive : SubscriptionStatus.free,
          errorMessage: 'Purchase could not be initiated.',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Exception initiating purchase: $e');
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        status: state.isPro ? SubscriptionStatus.premiumActive : SubscriptionStatus.free,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> restorePurchases() async {
    stateNotifier.value = stateNotifier.value.copyWith(isLoading: true, errorMessage: null);
    try {
      await _iap.restorePurchases();
      // Allow brief delay for purchase stream updates to settle, then clear loading
      await Future.delayed(const Duration(milliseconds: 600));
      if (stateNotifier.value.isLoading) {
        stateNotifier.value = stateNotifier.value.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Exception restoring purchases: $e');
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: 'Failed to restore purchases: $e',
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          stateNotifier.value = stateNotifier.value.copyWith(
            status: SubscriptionStatus.purchasePending,
            isLoading: true,
          );
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final valid = _verifyPurchase(purchase);
          if (valid) {
            // Calculate approximate expiry based on product duration
            DateTime? expiry;
            if (purchase.productID == BillingConstants.subscription6Months) {
              expiry = DateTime.now().add(const Duration(days: 183));
            } else if (purchase.productID == BillingConstants.subscription1Year) {
              expiry = DateTime.now().add(const Duration(days: 365));
            }

            await _persistProStatus(
              true,
              SubscriptionStatus.premiumActive,
              purchase.productID,
              expiry,
            );

            stateNotifier.value = stateNotifier.value.copyWith(
              status: SubscriptionStatus.premiumActive,
              productId: purchase.productID,
              expiryDate: expiry,
              isLoading: false,
              errorMessage: null,
            );
          } else {
            stateNotifier.value = stateNotifier.value.copyWith(
              isLoading: false,
              errorMessage: 'Purchase verification failed.',
            );
          }

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          stateNotifier.value = stateNotifier.value.copyWith(
            status: state.isPro ? SubscriptionStatus.premiumActive : SubscriptionStatus.free,
            isLoading: false,
            errorMessage: purchase.error?.message ?? 'Purchase encountered an error.',
          );
          break;

        case PurchaseStatus.canceled:
          stateNotifier.value = stateNotifier.value.copyWith(
            status: state.isPro ? SubscriptionStatus.premiumActive : SubscriptionStatus.free,
            isLoading: false,
            errorMessage: null,
          );
          break;
      }
    }
  }

  bool _verifyPurchase(PurchaseDetails purchase) {
    // Local verification: verify product ID is one of our registered subscription IDs
    return BillingConstants.productIds.contains(purchase.productID);
  }

  Future<void> _persistProStatus(
    bool isPro,
    SubscriptionStatus status,
    String? productId,
    DateTime? expiry,
  ) async {
    await _prefs.setBool(AppConstants.keyIsProUser, isPro);
    await _prefs.setString(BillingConstants.keySubscriptionStatus, status.name);
    if (productId != null) {
      await _prefs.setString(BillingConstants.keySubscriptionProductId, productId);
    }
    if (expiry != null) {
      await _prefs.setInt(BillingConstants.keySubscriptionExpiry, expiry.millisecondsSinceEpoch);
    }
  }

  void dispose() {
    _subscription?.cancel();
    stateNotifier.dispose();
  }
}
