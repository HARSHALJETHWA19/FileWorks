import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_config.dart';
import '../providers/monetization_provider.dart';
import '../services/ad_diagnostics_service.dart';

class AdDiagnosticsScreen extends ConsumerStatefulWidget {
  const AdDiagnosticsScreen({super.key});

  @override
  ConsumerState<AdDiagnosticsScreen> createState() => _AdDiagnosticsScreenState();
}

class _AdDiagnosticsScreenState extends ConsumerState<AdDiagnosticsScreen> {
  Timer? _refreshTimer;
  bool _canRequestAds = false;

  @override
  void initState() {
    super.initState();
    _checkConsent();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConsent() async {
    try {
      final allowed = await ConsentInformation.instance.canRequestAds();
      if (mounted) setState(() => _canRequestAds = allowed);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final adService = ref.watch(adServiceProvider);
    final isPro = ref.watch(isProProvider);
    final diagnostics = AdDiagnosticsService();
    final metrics = diagnostics.metrics;
    final freqState = adService.frequencyState;
    final theme = Theme.of(context);

    // Calculate interstitial cooldown remaining
    int interstitialCooldownSec = 0;
    if (freqState.lastInterstitialAt != null) {
      final elapsed = DateTime.now().difference(freqState.lastInterstitialAt!);
      final remaining = AdConfig.interstitialCooldown.inSeconds - elapsed.inSeconds;
      if (remaining > 0) interstitialCooldownSec = remaining;
    }

    // Calculate app open cooldown remaining
    int appOpenCooldownSec = 0;
    if (freqState.lastAppOpenAt != null) {
      final elapsed = DateTime.now().difference(freqState.lastAppOpenAt!);
      final remaining = AdConfig.appOpenCooldown.inSeconds - elapsed.inSeconds;
      if (remaining > 0) appOpenCooldownSec = remaining;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Diagnostics (Dev)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              _checkConsent();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear Metrics & Logs',
            onPressed: () {
              diagnostics.clearLogs();
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionCard(
            theme: theme,
            title: 'GLOBAL STATE',
            icon: Icons.public_rounded,
            color: Colors.blueGrey,
            children: [
              _buildRow('Premium State', isPro ? 'PRO (Ad-Free)' : 'FREE (Monetized)', isPro ? Colors.amber : Colors.blue),
              _buildRow('canRequestAds()', _canRequestAds ? 'YES' : 'NO / PENDING', _canRequestAds ? Colors.green : Colors.orange),
              _buildRow('Consent Info Initialized', adService.isConsentInfoInitialized ? 'YES' : 'NO', adService.isConsentInfoInitialized ? Colors.green : Colors.grey),
              _buildRow('Privacy Options Required', adService.isPrivacyOptionsRequired ? 'YES' : 'NO', Colors.blue),
              _buildRow('Fullscreen Ad Showing', freqState.isFullscreenAdShowing ? 'YES (Blocking)' : 'NO', freqState.isFullscreenAdShowing ? Colors.red : Colors.green),
              _buildRow('File Processing Active', freqState.isProcessing ? 'YES (Blocking)' : 'NO', freqState.isProcessing ? Colors.red : Colors.green),
              _buildRow('File Saving Active', freqState.isSaving ? 'YES (Blocking)' : 'NO', freqState.isSaving ? Colors.red : Colors.green),
              _buildRow('File Sharing Active', freqState.isSharing ? 'YES (Blocking)' : 'NO', freqState.isSharing ? Colors.red : Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            theme: theme,
            title: 'BANNERS',
            icon: Icons.ad_units_rounded,
            color: Colors.teal,
            children: [
              _buildRow('Format Enabled', AdConfig.bannerEnabled ? 'YES' : 'DISABLED', AdConfig.bannerEnabled ? Colors.green : Colors.red),
              _buildRow('Requests Made', '${metrics.bannerRequests}', Colors.blue),
              _buildRow('Loaded Successfully', '${metrics.bannerLoaded}', Colors.green),
              _buildRow('Load Failures', '${metrics.bannerFailures}', metrics.bannerFailures > 0 ? Colors.red : Colors.grey),
              _buildRow('Impressions', '${metrics.bannerImpressions}', Colors.teal),
              _buildRow('Currently Visible', metrics.isBannerVisible ? 'YES' : 'NO', metrics.isBannerVisible ? Colors.green : Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            theme: theme,
            title: 'INTERSTITIALS',
            icon: Icons.fullscreen_rounded,
            color: Colors.indigo,
            children: [
              _buildRow('Format Enabled', AdConfig.interstitialEnabled ? 'YES' : 'DISABLED', AdConfig.interstitialEnabled ? Colors.green : Colors.red),
              _buildRow('Requests Made', '${metrics.interstitialRequests}', Colors.blue),
              _buildRow('Loaded In Memory', '${metrics.interstitialLoaded}', Colors.green),
              _buildRow('Total Shown', '${metrics.interstitialShown}', Colors.indigo),
              _buildRow('Dismissed Count', '${metrics.interstitialDismissed}', Colors.blueGrey),
              _buildRow('Load Failures', '${metrics.interstitialFailures}', metrics.interstitialFailures > 0 ? Colors.red : Colors.grey),
              _buildRow(
                'Action Counter',
                '${freqState.actionsSinceInterstitial} / ${AdConfig.maxActionsBetweenInterstitials} needed',
                freqState.actionsSinceInterstitial >= AdConfig.maxActionsBetweenInterstitials ? Colors.green : Colors.orange,
              ),
              _buildRow(
                'Cooldown Remaining',
                interstitialCooldownSec > 0 ? '${interstitialCooldownSec}s remaining' : 'Ready (0s)',
                interstitialCooldownSec > 0 ? Colors.orange : Colors.green,
              ),
              _buildRow('Is Eligible Now', adService.isInterstitialEligible() ? 'YES' : 'NO', adService.isInterstitialEligible() ? Colors.green : Colors.grey),
              _buildRow('Last Shown At', freqState.lastInterstitialAt?.toLocal().toString().split('.').first ?? 'Never', Colors.blueGrey),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            theme: theme,
            title: 'APP OPEN ADS',
            icon: Icons.open_in_new_rounded,
            color: Colors.deepOrange,
            children: [
              _buildRow('Format Enabled', AdConfig.appOpenEnabled ? 'YES' : 'DISABLED', AdConfig.appOpenEnabled ? Colors.green : Colors.red),
              _buildRow('Requests Made', '${metrics.appOpenRequests}', Colors.blue),
              _buildRow('Loaded In Memory', '${metrics.appOpenLoaded}', Colors.green),
              _buildRow('Total Shown', '${metrics.appOpenShown}', Colors.deepOrange),
              _buildRow('Load Failures', '${metrics.appOpenFailures}', metrics.appOpenFailures > 0 ? Colors.red : Colors.grey),
              _buildRow(
                'Cooldown Remaining',
                appOpenCooldownSec > 0 ? '${appOpenCooldownSec}s remaining' : 'Ready (0s)',
                appOpenCooldownSec > 0 ? Colors.orange : Colors.green,
              ),
              _buildRow('Is Eligible Now', adService.isAppOpenEligible() ? 'YES' : 'NO', adService.isAppOpenEligible() ? Colors.green : Colors.grey),
              _buildRow('Last Shown At', freqState.lastAppOpenAt?.toLocal().toString().split('.').first ?? 'Never', Colors.blueGrey),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            theme: theme,
            title: 'REWARDED ADS',
            icon: Icons.stars_rounded,
            color: Colors.amber.shade800,
            children: [
              _buildRow('Format Enabled', AdConfig.rewardedEnabled ? 'YES' : 'DISABLED', AdConfig.rewardedEnabled ? Colors.green : Colors.red),
              _buildRow('Requests Made', '${metrics.rewardedRequests}', Colors.blue),
              _buildRow('Loaded In Memory', '${metrics.rewardedLoaded}', Colors.green),
              _buildRow('Available Now', adService.isRewardedAdAvailable ? 'YES' : 'NO', adService.isRewardedAdAvailable ? Colors.green : Colors.grey),
              _buildRow('Total Shown', '${metrics.rewardedShown}', Colors.amber.shade800),
              _buildRow('Rewards Earned', '${metrics.rewardedEarned}', Colors.green),
              _buildRow('Load Failures', '${metrics.rewardedFailures}', metrics.rewardedFailures > 0 ? Colors.red : Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'RECENT DIAGNOSTIC EVENTS (${diagnostics.recentLogs.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (diagnostics.recentLogs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No diagnostic events recorded yet in this session.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...diagnostics.recentLogs.map((entry) => _buildLogCard(theme, entry)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ThemeData theme, AdDiagnosticLogEntry entry) {
    final isFailure = entry.event == AdDiagnosticEventType.adLoadFailure ||
        entry.event == AdDiagnosticEventType.adEligibilityRejected ||
        entry.event == AdDiagnosticEventType.adCooldownRejected ||
        entry.event == AdDiagnosticEventType.adNoFill;
    final isSuccess = entry.event == AdDiagnosticEventType.adLoadSuccess ||
        entry.event == AdDiagnosticEventType.adShowSuccess ||
        entry.event == AdDiagnosticEventType.adImpression;

    final badgeColor = isFailure
        ? Colors.red
        : isSuccess
            ? Colors.green
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withAlpha(80)),
                  ),
                  child: Text(
                    entry.format.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.event.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Text(
                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            if (entry.reason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reason: ${entry.reason}',
                style: TextStyle(
                  fontSize: 12,
                  color: isFailure ? Colors.red.shade400 : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (entry.details != null && entry.details!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Details: ${entry.details}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
