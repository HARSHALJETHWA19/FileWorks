import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../free_usage_config.dart';
import '../providers/monetization_provider.dart';
import 'pro_upgrade_sheet.dart';

class FreeLimitSheet extends ConsumerStatefulWidget {
  final ToolFeature feature;
  final int requestedAmount;

  const FreeLimitSheet({
    super.key,
    required this.feature,
    required this.requestedAmount,
  });

  /// Shows the Free Limit Bottom Sheet and returns `true` if the user unlocked
  /// the operation (via rewarded ad or premium upgrade), or `false` if cancelled.
  static Future<bool?> show(
    BuildContext context, {
    required ToolFeature feature,
    required int requestedAmount,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => FreeLimitSheet(
        feature: feature,
        requestedAmount: requestedAmount,
      ),
    );
  }

  @override
  ConsumerState<FreeLimitSheet> createState() => _FreeLimitSheetState();
}

class _FreeLimitSheetState extends ConsumerState<FreeLimitSheet> {
  bool _isLoadingAd = false;
  bool _isCheckingConnection = false;
  bool _isOffline = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final adService = ref.read(adServiceProvider);
    final online = await adService.isNetworkAvailable();
    if (mounted) {
      setState(() {
        _isOffline = !online;
      });
    }
  }

  Future<void> _handleRetryConnection() async {
    if (_isCheckingConnection) return;
    setState(() {
      _isCheckingConnection = true;
      _errorMessage = null;
    });

    final adService = ref.read(adServiceProvider);
    final online = await adService.isNetworkAvailable();

    if (!mounted) return;

    setState(() {
      _isCheckingConnection = false;
      _isOffline = !online;
      if (!online) {
        _errorMessage = "Still offline. Please check your internet connection.";
      }
    });

    if (online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected to the internet! You can now watch an ad.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleWatchAd() async {
    if (_isLoadingAd) return;

    setState(() {
      _isLoadingAd = true;
      _errorMessage = null;
    });

    try {
      final adService = ref.read(adServiceProvider);
      final isOnline = await adService.isNetworkAvailable();
      if (!isOnline) {
        if (!mounted) return;
        setState(() {
          _isLoadingAd = false;
          _isOffline = true;
        });
        return;
      }

      final rewardEarned = await adService.showRewardedAd();

      if (!mounted) return;

      if (rewardEarned) {
        // User completed the ad and earned the reward
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoadingAd = false;
          _errorMessage =
              "You're offline or a rewarded ad is currently unavailable. "
              "Connect to the internet to try again, or upgrade to Premium.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
          _errorMessage =
              "You're offline or a rewarded ad is currently unavailable. "
              "Connect to the internet to try again, or upgrade to Premium.";
        });
      }
    }
  }

  void _handleGoPremium() {
    Navigator.of(context).pop(false);
    ProUpgradeSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final freeLimit = FreeUsageConfig.getFreeLimit(widget.feature);
    final rewardedLimit = FreeUsageConfig.getRewardedLimit(widget.feature);
    final toolName = FreeUsageConfig.getDisplayName(widget.feature);
    final formattedReq = FreeUsageConfig.formatAmount(widget.feature, widget.requestedAmount);
    final formattedFree = FreeUsageConfig.formatAmount(widget.feature, freeLimit);
    final formattedReward = FreeUsageConfig.formatAmount(widget.feature, rewardedLimit);
    final limitDescription = FreeUsageConfig.getFeatureLimitDescription(widget.feature);
    final rewardDescription = FreeUsageConfig.getRewardedDescription(widget.feature);
    final canUnlockWithAd = widget.requestedAmount <= rewardedLimit;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isOffline
                        ? theme.colorScheme.errorContainer.withAlpha(120)
                        : theme.colorScheme.primaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _isOffline ? Icons.wifi_off_rounded : Icons.lock_clock_rounded,
                    color: _isOffline ? theme.colorScheme.error : theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Limit Reached',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _isOffline
                            ? "Rewarded ads require an internet connection."
                            : "You're using the free version of FileWorks.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Content Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: _isOffline
                  ? Text(
                      "You're currently offline, so a rewarded ad isn't available.\n\n"
                      "Connect to the internet to watch an ad and continue, or upgrade to Premium.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              toolName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer.withAlpha(150),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$formattedReq selected',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Free limit: $formattedFree per operation.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          limitDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (canUnlockWithAd) ...[
                          Text(
                            rewardDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'This operation exceeds the ad-rewarded allowance ($formattedReward). '
                            'Upgrade to FileWorks Premium for higher limits, or adjust your selection.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Error / notification if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withAlpha(90),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.error.withAlpha(120)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (_isOffline) ...[
              PrimaryButton(
                label: _isCheckingConnection
                    ? 'Checking Connection…'
                    : 'Connect / Try Again',
                icon: Icons.refresh_rounded,
                isLoading: _isCheckingConnection,
                onPressed: _isCheckingConnection ? null : _handleRetryConnection,
              ),
              const SizedBox(height: 10),
            ] else if (canUnlockWithAd) ...[
              PrimaryButton(
                label: _isLoadingAd
                    ? 'Loading Ad…'
                    : 'Watch Ad & Continue',
                icon: Icons.play_circle_outline_rounded,
                isLoading: _isLoadingAd,
                onPressed: _isLoadingAd ? null : _handleWatchAd,
              ),
              const SizedBox(height: 10),
            ],

            // Action: Go Premium
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'Go Premium (Unlimited & Ad-Free)',
                semanticsLabel: 'Go Premium (Unlimited & Ad-Free)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              onPressed: _handleGoPremium,
            ),
            const SizedBox(height: 8),

            // Action: Cancel
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
