import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ad_config.dart';
import '../providers/monetization_provider.dart';

class BannerAdContainer extends ConsumerWidget {
  const BannerAdContainer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    if (isPro || !AdConfig.bannerEnabled) {
      return const SizedBox.shrink();
    }

    final adService = ref.watch(adServiceProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      child: adService.buildBannerAd(),
    );
  }
}
