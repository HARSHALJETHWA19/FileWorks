import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../monetization/providers/monetization_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(AppConstants.keyThemeMode);
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(AppConstants.keyThemeMode, value);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class SettingsPreferences {
  final bool hapticEnabled;
  final bool confirmDelete;

  const SettingsPreferences({
    required this.hapticEnabled,
    required this.confirmDelete,
  });

  SettingsPreferences copyWith({
    bool? hapticEnabled,
    bool? confirmDelete,
  }) {
    return SettingsPreferences(
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      confirmDelete: confirmDelete ?? this.confirmDelete,
    );
  }
}

class SettingsPreferencesNotifier extends Notifier<SettingsPreferences> {
  @override
  SettingsPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsPreferences(
      hapticEnabled: prefs.getBool(AppConstants.keyHapticFeedback) ?? true,
      confirmDelete: prefs.getBool(AppConstants.keyConfirmDelete) ?? true,
    );
  }

  Future<void> toggleHaptic(bool value) async {
    state = state.copyWith(hapticEnabled: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyHapticFeedback, value);
  }

  Future<void> toggleConfirmDelete(bool value) async {
    state = state.copyWith(confirmDelete: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyConfirmDelete, value);
  }
}

final settingsPreferencesProvider =
    NotifierProvider<SettingsPreferencesNotifier, SettingsPreferences>(
        SettingsPreferencesNotifier.new);
