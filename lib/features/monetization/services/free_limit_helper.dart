import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../free_usage_config.dart';
import '../presentation/free_limit_sheet.dart';
import '../providers/monetization_provider.dart';

class FreeLimitHelper {
  /// Evaluates whether the requested operation can proceed according to Free/Pro/Rewarded rules.
  /// If the limit is exceeded, automatically displays the FreeLimitSheet.
  /// Returns `true` if allowed or unlocked; `false` otherwise.
  static Future<bool> checkAndEnforce({
    required BuildContext context,
    required WidgetRef ref,
    required ToolFeature feature,
    required int requestedAmount,
  }) async {
    final isPro = ref.read(isProProvider);
    final usageManager = ref.read(freeUsageManagerProvider);

    final check = usageManager.checkLimit(
      feature: feature,
      requestedAmount: requestedAmount,
      isPro: isPro,
    );

    if (check.isAllowed) {
      return true;
    }

    // Show free limit sheet to offer Rewarded Ad or Premium upgrade
    final rewarded = await FreeLimitSheet.show(
      context,
      feature: feature,
      requestedAmount: requestedAmount,
    );

    if (rewarded == true) {
      usageManager.grantTemporaryReward(feature);
      return true;
    }

    return false;
  }
}
