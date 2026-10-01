import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ad_config.dart';
import '../providers/monetization_provider.dart';

class BannerAdContainer extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;

  const BannerAdContainer({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    if (isPro || !AdConfig.bannerEnabled) {
      return const SizedBox.shrink();
    }

    final adService = ref.watch(adServiceProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: margin ?? const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha(240),
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withAlpha(50),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'ADVERTISEMENT',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 50,
                maxHeight: 60,
              ),
              child: Center(
                child: adService.buildBannerAd(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
