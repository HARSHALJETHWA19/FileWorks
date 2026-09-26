import '../free_usage_config.dart';

class LimitCheckResult {
  final bool isAllowed;
  final bool isPro;
  final bool isWithinFreeLimit;
  final bool usedTemporaryReward;
  final ToolFeature feature;
  final int requestedAmount;
  final int freeLimit;
  final int rewardedLimit;
  final bool canUnlockWithAd;
  final String message;

  const LimitCheckResult({
    required this.isAllowed,
    required this.isPro,
    required this.isWithinFreeLimit,
    required this.usedTemporaryReward,
    required this.feature,
    required this.requestedAmount,
    required this.freeLimit,
    required this.rewardedLimit,
    required this.canUnlockWithAd,
    required this.message,
  });

  factory LimitCheckResult.allowed({
    required ToolFeature feature,
    required int requestedAmount,
    required bool isPro,
    required int freeLimit,
    required int rewardedLimit,
    bool usedTemporaryReward = false,
  }) {
    return LimitCheckResult(
      isAllowed: true,
      isPro: isPro,
      isWithinFreeLimit: requestedAmount <= freeLimit,
      usedTemporaryReward: usedTemporaryReward,
      feature: feature,
      requestedAmount: requestedAmount,
      freeLimit: freeLimit,
      rewardedLimit: rewardedLimit,
      canUnlockWithAd: false,
      message: 'Operation is allowed.',
    );
  }

  factory LimitCheckResult.exceeded({
    required ToolFeature feature,
    required int requestedAmount,
    required int freeLimit,
    required int rewardedLimit,
    bool hasReward = false,
  }) {
    final canUnlock = requestedAmount <= rewardedLimit && !hasReward;
    final formattedReq = FreeUsageConfig.formatAmount(feature, requestedAmount);
    final formattedFree = FreeUsageConfig.formatAmount(feature, freeLimit);
    final formattedReward = FreeUsageConfig.formatAmount(feature, rewardedLimit);

    String msg;
    if (canUnlock) {
      msg = 'Requested $formattedReq exceeds free limit of $formattedFree. '
          'Watch a short ad to allow up to $formattedReward for this operation.';
    } else if (hasReward && requestedAmount > rewardedLimit) {
      msg = 'Requested $formattedReq exceeds the rewarded allowance of $formattedReward. '
          'Upgrade to FileWorks Premium for unlimited processing.';
    } else {
      msg = 'Requested $formattedReq exceeds the free limit of $formattedFree (maximum $formattedReward with ad). '
          'Upgrade to FileWorks Premium for unlimited processing.';
    }

    return LimitCheckResult(
      isAllowed: false,
      isPro: false,
      isWithinFreeLimit: false,
      usedTemporaryReward: false,
      feature: feature,
      requestedAmount: requestedAmount,
      freeLimit: freeLimit,
      rewardedLimit: rewardedLimit,
      canUnlockWithAd: canUnlock,
      message: msg,
    );
  }
}
