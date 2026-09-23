import 'package:flutter/material.dart';
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
            const SizedBox(height: 24),
            _buildSection(
              theme,
              'Core Privacy Principle',
              'Your files stay on your device. FileWorks is designed with local-first, privacy-by-design architecture. '
              'All document manipulation, image compression, image format conversion, and archive creation happen '
              'entirely inside your device\'s local storage and processor using background isolates.',
            ),
            _buildSection(
              theme,
              'Zero Cloud Processing & Zero Server Uploads',
              'FileWorks does NOT maintain any backend servers, AWS S3 buckets, Firebase Storage buckets, or cloud processing APIs for file manipulation. '
              'Your files are never transmitted to FileWorks or any third-party document processing service.',
            ),
            _buildSection(
              theme,
              'Advertising (Google AdMob)',
              'FileWorks displays advertisements provided by Google AdMob to remain free for all users. '
              'Google AdMob may collect and process pseudonymous identifiers, such as the Google Advertising ID (GAID) and crash diagnostics, '
              'in accordance with Google\'s Privacy Policy and Play Store Data Safety guidelines.',
            ),
            _buildSection(
              theme,
              'Permissions',
              '• Media / Storage: Requested solely to let you choose files via Android\'s system picker and save processed outputs.\n'
              '• Internet: Used strictly by Google Mobile Ads SDK for serving advertisements.',
            ),
            _buildSection(
              theme,
              'Local History & Settings',
              'Your recent operations history and preferences (such as Dark/Light theme) are stored only on your physical device using local key-value storage. '
              'You can clear your history at any time from the History screen.',
            ),
            _buildSection(
              theme,
              'Contact & Data Inquiries',
              'If you have questions regarding this Privacy Policy or your data, you can contact us at:\n${AppConstants.contactEmail}',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Version ${AppConstants.appVersion} • Last updated: September 2026',
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
