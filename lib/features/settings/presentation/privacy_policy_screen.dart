import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/privacy_badge.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Privacy Policy',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: PrivacyBadge()),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => OpenFilex.open(AppConstants.privacyPolicyUrl),
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('View Official Web Privacy Policy'),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              theme,
              '1. On-Device Local File Processing',
              'FileWorks processes all supported files (PDFs, images, ZIP archives, and file renames) locally on your device using Dart background isolates. '
              'FileWorks does NOT operate its own cloud servers or cloud storage for user documents. '
              'FileWorks does NOT upload your documents, images, or archives to any FileWorks-owned backend or third-party cloud processing API. '
              'FileWorks does NOT require a user account for normal functionality. '
              'Your selected files remain on your device unless you explicitly initiate an Android system share or export action.',
            ),
            _buildSection(
              theme,
              '2. Temporary Files and Local Storage',
              'To perform transformations such as PDF merging, splitting, or image compression, FileWorks may generate temporary working files in your device\'s isolated application cache directory. '
              'These temporary working files are transient, isolated from other apps, and are automatically removed after processing or during cache cleanup.\n\n'
              'FileWorks also stores user preferences on your physical device via Android SharedPreferences, including:\n'
              '• App appearance preferences (Light, Dark, or System mode)\n'
              '• Interaction preferences (haptic feedback, confirm delete)\n'
              '• Recent operations history (which you can clear at any time in the History tab)\n'
              '• Tool free-usage counters to enforce per-tool operation capacity\n'
              '• Cached Google Play subscription entitlement status',
            ),
            _buildSection(
              theme,
              '3. Advertising and Google Mobile Ads SDK',
              'FileWorks displays advertisements to free users via the official Google Mobile Ads SDK to keep the core toolset accessible without charge.\n\n'
              'The Google Mobile Ads SDK may collect and transmit certain diagnostic, device, and advertising information directly to Google, including:\n'
              '• Device and other identifiers (such as the Google Advertising ID / GAID)\n'
              '• Diagnostic data, crash logs, and app performance metrics\n'
              '• Ad interaction and engagement telemetry for fraud detection\n'
              '• Coarse location data derived from network IP address\n\n'
              'FileWorks itself never receives, inspects, or associates your personal documents with advertising identifiers. '
              'For users in the European Economic Area (EEA), the UK, and Switzerland, FileWorks integrates the Google User Messaging Platform (UMP) '
              'to request and manage your consent choices. You can review or adjust your consent choices at any time in Settings > Ad & Privacy Choices.',
            ),
            _buildSection(
              theme,
              '4. Voluntary Rewarded Advertisements',
              'Free users may voluntarily choose to watch a rewarded advertisement ("Watch Ad & Continue") to temporarily expand the capacity for a single specific operation beyond standard free limits. '
              'Watching a rewarded ad is entirely optional and grants a temporary, operation-scoped extension only. '
              'It does not permanently alter your free account or replace a subscription.',
            ),
            _buildSection(
              theme,
              '5. Google Play Billing and Subscriptions',
              'FileWorks offers optional Premium subscriptions:\n'
              '• 6-Month Plan (fileworks_premium_6m)\n'
              '• 12-Month Plan (fileworks_premium_1y)\n\n'
              'All purchases, renewals, and cancellations are processed directly and securely by Google Play. '
              'FileWorks never collects, stores, or receives your payment card details or banking information. '
              'Subscriptions automatically renew until cancelled. You can manage or cancel your subscription at any time via the Google Play Store Subscriptions center.',
            ),
            _buildSection(
              theme,
              '6. Permissions Used',
              'FileWorks requests minimal Android permissions:\n'
              '• READ_MEDIA_IMAGES / Storage: To enable selecting images and documents via the Android system file picker.\n'
              '• INTERNET & ACCESS_NETWORK_STATE: Required exclusively by Google Mobile Ads and Google Play Billing for ad delivery and subscription validation.',
            ),
            _buildSection(
              theme,
              '7. Third-Party Service Providers',
              'FileWorks integrates only official, reputable platform SDKs:\n'
              '• Google Mobile Ads (AdMob) — Advertising\n'
              '• Google Play Billing — Subscription processing\n'
              'No third-party analytics trackers, social network SDKs, or cloud telemetry brokers are present.',
            ),
            _buildSection(
              theme,
              '8. Contact & Data Inquiries',
              'If you have questions or inquiries regarding this Privacy Policy or your data, please contact:\n'
              'Email: ${AppConstants.contactEmail}\n'
              'Web: ${AppConstants.privacyPolicyUrl}',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Version ${AppConstants.appVersion} • Effective Date: September 2026',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
