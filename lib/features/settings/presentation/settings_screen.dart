import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/presentation/banner_ad_widget.dart';
import '../../monetization/presentation/pro_upgrade_sheet.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _devTapCount = 0;
  bool _devModeUnlocked = false;

  void _onVersionTap() {
    _devTapCount++;
    if (_devTapCount >= 5 && !_devModeUnlocked) {
      setState(() => _devModeUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer options unlocked!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final preferences = ref.watch(settingsPreferencesProvider);
    final isPro = ref.watch(isProProvider);

    return AppScaffold(
      title: 'Settings',
      showBackButton: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                // Pro Banner Card
                Card(
                  color: theme.colorScheme.primaryContainer.withAlpha(90),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      isPro ? 'FileWorks Pro Active' : 'Upgrade to FileWorks Pro',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      isPro
                          ? 'Ad-free experience enabled'
                          : 'Remove all ads & unlock advanced tools',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => ProUpgradeSheet.show(context),
                  ),
                ),
                const SizedBox(height: 20),

                // Appearance Section
                _buildSectionHeader(theme, 'APPEARANCE'),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('System Default'),
                        secondary: const Icon(Icons.brightness_auto_rounded),
                        value: ThemeMode.system,
                        groupValue: themeMode,
                        onChanged: (val) =>
                            ref.read(themeModeProvider.notifier).setThemeMode(val!),
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        title: const Text('Light Mode'),
                        secondary: const Icon(Icons.light_mode_rounded),
                        value: ThemeMode.light,
                        groupValue: themeMode,
                        onChanged: (val) =>
                            ref.read(themeModeProvider.notifier).setThemeMode(val!),
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark Mode'),
                        secondary: const Icon(Icons.dark_mode_rounded),
                        value: ThemeMode.dark,
                        groupValue: themeMode,
                        onChanged: (val) =>
                            ref.read(themeModeProvider.notifier).setThemeMode(val!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Preferences Section
                _buildSectionHeader(theme, 'PREFERENCES'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Haptic Feedback'),
                        subtitle: const Text('Vibrate on successful operations'),
                        secondary: const Icon(Icons.vibration_rounded),
                        value: preferences.hapticEnabled,
                        onChanged: (val) =>
                            ref.read(settingsPreferencesProvider.notifier).toggleHaptic(val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Confirm Before Delete'),
                        subtitle: const Text('Ask before clearing history records'),
                        secondary: const Icon(Icons.delete_outline_rounded),
                        value: preferences.confirmDelete,
                        onChanged: (val) => ref
                            .read(settingsPreferencesProvider.notifier)
                            .toggleConfirmDelete(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Privacy & Security
                _buildSectionHeader(theme, 'PRIVACY & SECURITY'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.security_rounded),
                        title: const Text('Local-First Processing'),
                        subtitle: const Text('All file operations run 100% on your device'),
                        trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text('Read our complete data handling terms'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(RouteConstants.privacyPolicy),
                      ),
                      if (ref.watch(privacyOptionsRequiredProvider)) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.tune_rounded),
                          title: const Text('Ad & Privacy Choices'),
                          subtitle: const Text('Review European (EEA/UK) consent preferences'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ref.read(adServiceProvider).showPrivacyOptionsForm(context);
                          },
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.subscriptions_outlined),
                        title: const Text('Manage Subscriptions'),
                        subtitle: const Text('View or cancel plans in Google Play'),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _handleManageSubscriptions(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // About Section
                _buildSectionHeader(theme, 'ABOUT'),
                Card(
                  child: ListTile(
                    onTap: _onVersionTap,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/branding/app_icon_in_app.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: const Text(
                      'FileWorks',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Fast & Private File Utilities'),
                    trailing: Text(
                      'v${AppConstants.appVersion}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                if (kDebugMode || _devModeUnlocked) ...[
                  const SizedBox(height: 20),
                  _buildSectionHeader(theme, 'DEVELOPER'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bug_report_rounded, color: Colors.orange),
                      title: const Text('Ad Diagnostics (Dev)'),
                      subtitle: const Text('Inspect requests, impressions & state'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(RouteConstants.adDiagnostics),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          const BannerAdContainer(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Future<void> _handleManageSubscriptions(BuildContext context) async {
    final uri = Uri.parse(AppConstants.manageSubscriptionsUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showSubscriptionFallback(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showSubscriptionFallback(context);
      }
    }
  }

  void _showSubscriptionFallback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open Google Play subscriptions. '
          'Please open Google Play → Profile → Payments & subscriptions → Subscriptions.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ),
    );
  }
}
