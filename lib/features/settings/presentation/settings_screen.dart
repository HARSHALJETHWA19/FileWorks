import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/admob_service.dart';
import '../../monetization/presentation/banner_ad_widget.dart';
import '../../monetization/presentation/pro_upgrade_sheet.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.tune_rounded),
                        title: const Text('Ad & Privacy Choices'),
                        subtitle: const Text('Review European (EEA/UK) consent preferences'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => AdmobService.showPrivacyOptionsForm(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.subscriptions_outlined),
                        title: const Text('Manage Subscriptions'),
                        subtitle: const Text('View or cancel plans in Google Play'),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => OpenFilex.open(AppConstants.manageSubscriptionsUrl),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // About Section
                _buildSectionHeader(theme, 'ABOUT'),
                Card(
                  child: ListTile(
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
}
