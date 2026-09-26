import 'package:in_app_purchase/in_app_purchase.dart';

enum SubscriptionStatus {
  unknown,
  free,
  premiumActive,
  premiumExpired,
  purchasePending,
  billingUnavailable,
}

class BillingConstants {
  static const String subscription6Months = 'fileworks_premium_6m';
  static const String subscription1Year = 'fileworks_premium_1y';

  static const Set<String> productIds = {
    subscription6Months,
    subscription1Year,
  };

  // Preference keys
  static const String keySubscriptionStatus = 'subscription_status';
  static const String keySubscriptionProductId = 'subscription_product_id';
  static const String keySubscriptionExpiry = 'subscription_expiry_millis';
}

class EntitlementState {
  final SubscriptionStatus status;
  final String? productId;
  final DateTime? expiryDate;
  final List<ProductDetails> products;
  final bool isLoading;
  final String? errorMessage;

  const EntitlementState({
    this.status = SubscriptionStatus.unknown,
    this.productId,
    this.expiryDate,
    this.products = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isPro => status == SubscriptionStatus.premiumActive;

  EntitlementState copyWith({
    SubscriptionStatus? status,
    String? productId,
    DateTime? expiryDate,
    List<ProductDetails>? products,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EntitlementState(
      status: status ?? this.status,
      productId: productId ?? this.productId,
      expiryDate: expiryDate ?? this.expiryDate,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
