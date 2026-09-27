class AppConstants {
  static const String appName = 'FileWorks';
  static const String appTagline = 'Simple. Private. Local.';
  static const String appVersion = '1.0.0';
  static const String privacyNotice = 'Your files stay on your device.';
  static const String privacyDescription =
      'FileWorks processes all supported files locally on your device using Dart background isolates. '
      'FileWorks does NOT upload your documents, images, or archives to any server. '
      'Zero backend. Zero cloud processing. Complete privacy.';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.fileworks.app';
  static const String privacyPolicyUrl =
      'https://harshaljethwa19.github.io/FileWorks/privacy-policy.html';
  static const String manageSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions?package=com.fileworks.app';
  static const String contactEmail = 'aetherkube@gmail.com';

  // Local storage keys
  static const String keyThemeMode = 'settings_theme_mode';
  static const String keyHapticFeedback = 'settings_haptic_feedback';
  static const String keyConfirmDelete = 'settings_confirm_delete';
  static const String keyOperationCount = 'analytics_operation_count';
  static const String keyHistoryItems = 'history_items_cache';
  static const String keyRecentTools = 'recent_tools_list';
  static const String keyIsProUser = 'user_entitlement_pro';
  static const String keyFeatureUsagePrefix = 'feature_usage_count_';
}
