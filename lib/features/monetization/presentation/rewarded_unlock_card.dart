import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../free_usage_config.dart';
import '../providers/monetization_provider.dart';

class RewardedUnlockCard extends ConsumerStatefulWidget {
  final ToolFeature feature;

  const RewardedUnlockCard({
    super.key,
    required this.feature,
  });

  @override
  ConsumerState<RewardedUnlockCard> createState() => _RewardedUnlockCardState();
}

class _RewardedUnlockCardState extends ConsumerState<RewardedUnlockCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    if (isPro) return const SizedBox.shrink();

    final usageManager = ref.watch(freeUsageManagerProvider);
    final hasReward = usageManager.hasTemporaryReward(widget.feature);
    final freeLimit = FreeUsageConfig.getFreeLimit(widget.feature);
    final rewardedLimit = FreeUsageConfig.getRewardedLimit(widget.feature);
    final unit = FreeUsageConfig.getUnit(widget.feature);

    final theme = Theme.of(context);

    if (hasReward) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade900.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade600.withAlpha(100)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bonus Unlocked: Up to $rewardedLimit $unit for this operation',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(120),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.ondemand_video_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need more than $freeLimit $unit?',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  'Watch a short ad to unlock up to $rewardedLimit $unit for this operation.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _handleWatchAd,
                  child: const Text('Unlock', style: TextStyle(fontSize: 12)),
                ),
        ],
      ),
    );
  }

  Future<void> _handleWatchAd() async {
    setState(() => _isLoading = true);
    try {
      final adService = ref.read(adServiceProvider);
      final isOnline = await adService.isNetworkAvailable();
      if (!isOnline) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Connect to the internet to watch an ad.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final rewarded = await adService.showRewardedAd();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (rewarded) {
        final usageManager = ref.read(freeUsageManagerProvider);
        usageManager.grantTemporaryReward(widget.feature);
        final rewardedLimit = FreeUsageConfig.getRewardedLimit(widget.feature);
        final unit = FreeUsageConfig.getUnit(widget.feature);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bonus unlocked! You can now use up to $rewardedLimit $unit.'),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rewarded ad isn\'t available right now. Please try again later or upgrade to Premium.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
