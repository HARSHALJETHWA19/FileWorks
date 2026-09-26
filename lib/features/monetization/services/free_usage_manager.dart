import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../free_usage_config.dart';
import '../models/limit_check_result.dart';

class FreeUsageManager {
  final SharedPreferences _prefs;
  final Set<ToolFeature> _activeTemporaryRewards = <ToolFeature>{};

  FreeUsageManager(this._prefs);

  /// Checks if the requested operation is within free limits, active reward, or Premium.
  LimitCheckResult checkLimit({
    required ToolFeature feature,
    required int requestedAmount,
    required bool isPro,
  }) {
    final freeLimit = FreeUsageConfig.getFreeLimit(feature);
    final rewardedLimit = FreeUsageConfig.getRewardedLimit(feature);

    // 1. Premium users bypass all limits
    if (isPro) {
      return LimitCheckResult.allowed(
        feature: feature,
        requestedAmount: requestedAmount,
        isPro: true,
        freeLimit: freeLimit,
        rewardedLimit: rewardedLimit,
      );
    }

    // 2. Within baseline free limit
    if (requestedAmount <= freeLimit) {
      return LimitCheckResult.allowed(
        feature: feature,
        requestedAmount: requestedAmount,
        isPro: false,
        freeLimit: freeLimit,
        rewardedLimit: rewardedLimit,
      );
    }

    // 3. Check if a temporary rewarded-ad allowance is active for this tool
    final hasReward = hasTemporaryReward(feature);
    if (hasReward && requestedAmount <= rewardedLimit) {
      return LimitCheckResult.allowed(
        feature: feature,
        requestedAmount: requestedAmount,
        isPro: false,
        freeLimit: freeLimit,
        rewardedLimit: rewardedLimit,
        usedTemporaryReward: true,
      );
    }

    // 4. Limit exceeded
    return LimitCheckResult.exceeded(
      feature: feature,
      requestedAmount: requestedAmount,
      freeLimit: freeLimit,
      rewardedLimit: rewardedLimit,
      hasReward: hasReward,
    );
  }

  /// Grants a temporary reward for [feature] applicable to the current operation.
  void grantTemporaryReward(ToolFeature feature) {
    _activeTemporaryRewards.add(feature);
  }

  /// Checks whether an unconsumed temporary reward is active for [feature].
  bool hasTemporaryReward(ToolFeature feature) {
    return _activeTemporaryRewards.contains(feature);
  }

  /// Consumes the temporary reward after the operation completes.
  void consumeReward(ToolFeature feature) {
    _activeTemporaryRewards.remove(feature);
  }

  /// Resets all temporary rewards (e.g. on navigation away or app reset).
  void resetAllRewards() {
    _activeTemporaryRewards.clear();
  }

  /// Records anonymous local operation count for [feature] without collecting sensitive data.
  Future<void> recordFeatureUsage(ToolFeature feature) async {
    final key = '${AppConstants.keyFeatureUsagePrefix}${feature.name}';
    final count = (_prefs.getInt(key) ?? 0) + 1;
    await _prefs.setInt(key, count);
  }

  /// Returns the historical usage count for [feature].
  int getFeatureUsageCount(ToolFeature feature) {
    return _prefs.getInt('${AppConstants.keyFeatureUsagePrefix}${feature.name}') ?? 0;
  }
}
