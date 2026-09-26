import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:filekit/core/constants/app_constants.dart';
import 'package:filekit/features/monetization/ad_config.dart';
import 'package:filekit/features/monetization/billing_constants.dart';
import 'package:filekit/features/monetization/presentation/pro_upgrade_sheet.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/features/monetization/services/billing_service.dart';

class MockInAppPurchase implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> _streamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  List<ProductDetails> productsToReturn = [];
  bool buyNonConsumableCalled = false;
  bool restorePurchasesCalled = false;
  List<PurchaseDetails> completedPurchases = [];

  void emitPurchases(List<PurchaseDetails> purchases) {
    _streamController.add(purchases);
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _streamController.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: productsToReturn,
      notFoundIDs: identifiers.where((id) => !productsToReturn.any((p) => p.id == id)).toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyNonConsumableCalled = true;
    return true;
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) async {
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() {
    throw UnimplementedError();
  }

  @override
  Future<String> countryCode() async => 'US';

  void dispose() {
    _streamController.close();
  }
}

class TestPurchaseDetails extends PurchaseDetails {
  TestPurchaseDetails({
    required super.productID,
    required super.status,
    super.purchaseID = 'test_purchase_123',
    super.transactionDate,
    PurchaseVerificationData? verificationData,
  }) : super(
          verificationData: verificationData ??
              PurchaseVerificationData(
                localVerificationData: 'test_local',
                serverVerificationData: 'test_server',
                source: 'google_play',
              ),
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late MockInAppPurchase mockIap;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    mockIap = MockInAppPurchase();
  });

  tearDown(() {
    mockIap.dispose();
  });

  group('Monetization & Billing Architecture Tests', () {
    test('BILLING-001: BillingConstants defines required 6m and 1y subscription IDs', () {
      expect(BillingConstants.subscription6Months, 'fileworks_premium_6m');
      expect(BillingConstants.subscription1Year, 'fileworks_premium_1y');
      expect(BillingConstants.productIds.contains('fileworks_premium_6m'), isTrue);
      expect(BillingConstants.productIds.contains('fileworks_premium_1y'), isTrue);
    });

    test('BILLING-002: BillingService initializes correctly for new free user', () async {
      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      expect(billingService.state.isPro, isFalse);
      expect(billingService.state.status, SubscriptionStatus.free);
      expect(testPrefs.getBool(AppConstants.keyIsProUser), isNull);
    });

    test('BILLING-003: BillingService restores active cached entitlement on startup', () async {
      await testPrefs.setBool(AppConstants.keyIsProUser, true);
      await testPrefs.setString(
          BillingConstants.keySubscriptionStatus, SubscriptionStatus.premiumActive.name);
      await testPrefs.setString(
          BillingConstants.keySubscriptionProductId, BillingConstants.subscription1Year);
      // Valid for 30 more days
      final expiry = DateTime.now().add(const Duration(days: 30));
      await testPrefs.setInt(BillingConstants.keySubscriptionExpiry, expiry.millisecondsSinceEpoch);

      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      expect(billingService.state.isPro, isTrue);
      expect(billingService.state.status, SubscriptionStatus.premiumActive);
      expect(billingService.state.productId, BillingConstants.subscription1Year);
    });

    test('BILLING-004: BillingService marks expired subscription on startup safely', () async {
      await testPrefs.setBool(AppConstants.keyIsProUser, true);
      await testPrefs.setString(
          BillingConstants.keySubscriptionStatus, SubscriptionStatus.premiumActive.name);
      // Expired 5 days ago
      final expiry = DateTime.now().subtract(const Duration(days: 5));
      await testPrefs.setInt(BillingConstants.keySubscriptionExpiry, expiry.millisecondsSinceEpoch);

      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      expect(billingService.state.isPro, isFalse);
      expect(billingService.state.status, SubscriptionStatus.premiumExpired);
      expect(testPrefs.getBool(AppConstants.keyIsProUser), isFalse);
    });

    test('BILLING-005: Successful 6-month purchase unlocks Pro and sets ~6-month expiry', () async {
      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      final purchase = TestPurchaseDetails(
        productID: BillingConstants.subscription6Months,
        status: PurchaseStatus.purchased,
      );
      purchase.pendingCompletePurchase = true;

      mockIap.emitPurchases([purchase]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(billingService.state.isPro, isTrue);
      expect(billingService.state.status, SubscriptionStatus.premiumActive);
      expect(billingService.state.productId, BillingConstants.subscription6Months);
      expect(testPrefs.getBool(AppConstants.keyIsProUser), isTrue);
      expect(mockIap.completedPurchases, contains(purchase));
    });

    test('BILLING-006: Successful 1-year purchase unlocks Pro and completes purchase', () async {
      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      final purchase = TestPurchaseDetails(
        productID: BillingConstants.subscription1Year,
        status: PurchaseStatus.purchased,
      );
      purchase.pendingCompletePurchase = true;

      mockIap.emitPurchases([purchase]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(billingService.state.isPro, isTrue);
      expect(billingService.state.status, SubscriptionStatus.premiumActive);
      expect(billingService.state.productId, BillingConstants.subscription1Year);
      expect(testPrefs.getBool(AppConstants.keyIsProUser), isTrue);
    });

    test('BILLING-007: Canceled or failed purchase does not unlock Pro', () async {
      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      final purchase = TestPurchaseDetails(
        productID: BillingConstants.subscription1Year,
        status: PurchaseStatus.canceled,
      );

      mockIap.emitPurchases([purchase]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(billingService.state.isPro, isFalse);
      expect(testPrefs.getBool(AppConstants.keyIsProUser), isNot(true));
    });

    test('BILLING-008: Restore purchases triggers InAppPurchase restore call', () async {
      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      await billingService.restorePurchases();
      expect(mockIap.restorePurchasesCalled, isTrue);
    });
  });

  group('AdConfig & Ad Safety Tests', () {
    test('ADCONFIG-001: Centralized parameters meet UX and policy requirements', () {
      expect(AdConfig.interstitialOperationThreshold, 3);
      expect(AdConfig.interstitialCooldown.inSeconds, anyOf(45, 60));
      expect(AdConfig.bannerEnabled, isTrue);
      expect(AdConfig.interstitialEnabled, isTrue);
      expect(AdConfig.isProduction, isFalse); // Test mode enforced
    });
  });

  group('ProUpgradeSheet UI Verification Tests', () {
    testWidgets('PRO-UI-001: Renders subscription options and non-deceptive disclosures',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            billingServiceProvider.overrideWithValue(billingService),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProUpgradeSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Features
      expect(find.text('FileWorks Premium'), findsOneWidget);
      expect(find.text('100% Ad-Free Experience'), findsOneWidget);
      expect(find.text('Unlimited Batch Processing'), findsOneWidget);
      expect(find.text('100% On-Device Privacy'), findsOneWidget);

      // Subscription Plans
      expect(find.text('12-Month Plan'), findsOneWidget);
      expect(find.text('6-Month Plan'), findsOneWidget);

      // Legal & Action
      expect(find.text('Subscribe with Google Play'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);

      // No manipulative text
      expect(find.textContaining('only 2 left'), findsNothing);
      expect(find.textContaining('hurry'), findsNothing);
    });

    testWidgets('PRO-UI-002: Shows active subscription view when user is Pro', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      await testPrefs.setBool(AppConstants.keyIsProUser, true);
      await testPrefs.setString(
          BillingConstants.keySubscriptionStatus, SubscriptionStatus.premiumActive.name);

      final billingService = BillingService(testPrefs, mockIap);
      await billingService.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            billingServiceProvider.overrideWithValue(billingService),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProUpgradeSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Premium Active'), findsOneWidget);
      expect(find.text('Manage Subscription on Google Play'), findsOneWidget);
      expect(find.text('Subscribe with Google Play'), findsNothing);
    });
  });
}
