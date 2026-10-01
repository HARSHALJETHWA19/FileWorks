import 'package:flutter/foundation.dart';

enum AdFormatType {
  banner,
  interstitial,
  rewarded,
  appOpen,
  global,
}

enum AdDiagnosticEventType {
  adRequest,
  adLoadSuccess,
  adLoadFailure,
  adReady,
  adEligibilityRejected,
  adShowAttempt,
  adShowSuccess,
  adDismissed,
  adImpression,
  adCooldownRejected,
  adActionThresholdRejected,
  adPremiumRejected,
  adProcessingRejected,
  adSavingRejected,
  adSharingRejected,
  adFullscreenRejected,
  adNoConsent,
  adNoFill,
}

class AdDiagnosticLogEntry {
  final DateTime timestamp;
  final AdFormatType format;
  final AdDiagnosticEventType event;
  final String? reason;
  final Map<String, dynamic>? details;

  AdDiagnosticLogEntry({
    required this.timestamp,
    required this.format,
    required this.event,
    this.reason,
    this.details,
  });

  @override
  String toString() {
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final reasonStr = reason != null ? ' | reason = $reason' : '';
    final detailsStr = details != null && details!.isNotEmpty ? ' | details = $details' : '';
    return '[$timeStr] ${format.name.toUpperCase()} -> ${event.name}$reasonStr$detailsStr';
  }
}

class AdDiagnosticMetrics {
  // Banner
  int bannerRequests = 0;
  int bannerLoaded = 0;
  int bannerFailures = 0;
  int bannerImpressions = 0;
  bool isBannerVisible = false;

  // Interstitial
  int interstitialRequests = 0;
  int interstitialLoaded = 0;
  int interstitialShown = 0;
  int interstitialFailures = 0;
  int interstitialImpressions = 0;
  int interstitialDismissed = 0;
  int actionsSinceInterstitial = 0;
  DateTime? lastInterstitialShownAt;

  // App Open
  int appOpenRequests = 0;
  int appOpenLoaded = 0;
  int appOpenShown = 0;
  int appOpenFailures = 0;
  int appOpenImpressions = 0;
  DateTime? lastAppOpenShownAt;

  // Rewarded
  int rewardedRequests = 0;
  int rewardedLoaded = 0;
  int rewardedShown = 0;
  int rewardedEarned = 0;
  int rewardedFailures = 0;

  // Rejection count maps
  final Map<String, int> interstitialRejections = {};
  final Map<String, int> appOpenRejections = {};
  final Map<String, int> bannerRejections = {};

  void reset() {
    bannerRequests = 0;
    bannerLoaded = 0;
    bannerFailures = 0;
    bannerImpressions = 0;
    isBannerVisible = false;

    interstitialRequests = 0;
    interstitialLoaded = 0;
    interstitialShown = 0;
    interstitialFailures = 0;
    interstitialImpressions = 0;
    interstitialDismissed = 0;
    actionsSinceInterstitial = 0;
    lastInterstitialShownAt = null;

    appOpenRequests = 0;
    appOpenLoaded = 0;
    appOpenShown = 0;
    appOpenFailures = 0;
    appOpenImpressions = 0;
    lastAppOpenShownAt = null;

    rewardedRequests = 0;
    rewardedLoaded = 0;
    rewardedShown = 0;
    rewardedEarned = 0;
    rewardedFailures = 0;

    interstitialRejections.clear();
    appOpenRejections.clear();
    bannerRejections.clear();
  }
}

class AdDiagnosticsService extends ChangeNotifier {
  static final AdDiagnosticsService _instance = AdDiagnosticsService._internal();
  factory AdDiagnosticsService() => _instance;
  AdDiagnosticsService._internal();

  final AdDiagnosticMetrics metrics = AdDiagnosticMetrics();
  final List<AdDiagnosticLogEntry> _recentLogs = [];
  bool isDevDiagnosticsEnabled = true;

  List<AdDiagnosticLogEntry> get recentLogs => List.unmodifiable(_recentLogs);

  void logEvent(
    AdFormatType format,
    AdDiagnosticEventType event, {
    String? reason,
    Map<String, dynamic>? details,
  }) {
    // Never log personal file names or content
    final safeDetails = details != null ? Map<String, dynamic>.from(details) : null;
    if (safeDetails != null) {
      safeDetails.remove('filePath');
      safeDetails.remove('fileContent');
      safeDetails.remove('fileName');
    }

    _updateMetrics(format, event, reason);

    final entry = AdDiagnosticLogEntry(
      timestamp: DateTime.now(),
      format: format,
      event: event,
      reason: reason,
      details: safeDetails,
    );

    _recentLogs.insert(0, entry);
    if (_recentLogs.length > 100) {
      _recentLogs.removeLast();
    }

    // Diagnostic console print in debug/development mode
    if (kDebugMode && isDevDiagnosticsEnabled) {
      final reasonPart = reason != null ? ' reason = $reason' : '';
      final detailsPart = safeDetails != null && safeDetails.isNotEmpty ? ' details = $safeDetails' : '';
      debugPrint('[AdDiagnostics] ${format.name.toUpperCase()} -> ${event.name}:$reasonPart$detailsPart');
    }

    notifyListeners();
  }

  void _updateMetrics(AdFormatType format, AdDiagnosticEventType event, String? reason) {
    switch (format) {
      case AdFormatType.banner:
        if (event == AdDiagnosticEventType.adRequest) metrics.bannerRequests++;
        if (event == AdDiagnosticEventType.adLoadSuccess) metrics.bannerLoaded++;
        if (event == AdDiagnosticEventType.adLoadFailure || event == AdDiagnosticEventType.adNoFill) {
          metrics.bannerFailures++;
        }
        if (event == AdDiagnosticEventType.adImpression) metrics.bannerImpressions++;
        if (reason != null && (event == AdDiagnosticEventType.adEligibilityRejected || event == AdDiagnosticEventType.adCooldownRejected)) {
          metrics.bannerRejections[reason] = (metrics.bannerRejections[reason] ?? 0) + 1;
        }
        break;

      case AdFormatType.interstitial:
        if (event == AdDiagnosticEventType.adRequest) metrics.interstitialRequests++;
        if (event == AdDiagnosticEventType.adLoadSuccess) metrics.interstitialLoaded++;
        if (event == AdDiagnosticEventType.adLoadFailure || event == AdDiagnosticEventType.adNoFill) {
          metrics.interstitialFailures++;
        }
        if (event == AdDiagnosticEventType.adShowSuccess) {
          metrics.interstitialShown++;
          metrics.lastInterstitialShownAt = DateTime.now();
        }
        if (event == AdDiagnosticEventType.adImpression) metrics.interstitialImpressions++;
        if (event == AdDiagnosticEventType.adDismissed) metrics.interstitialDismissed++;
        if (reason != null) {
          metrics.interstitialRejections[reason] = (metrics.interstitialRejections[reason] ?? 0) + 1;
        }
        break;

      case AdFormatType.appOpen:
        if (event == AdDiagnosticEventType.adRequest) metrics.appOpenRequests++;
        if (event == AdDiagnosticEventType.adLoadSuccess) metrics.appOpenLoaded++;
        if (event == AdDiagnosticEventType.adLoadFailure || event == AdDiagnosticEventType.adNoFill) {
          metrics.appOpenFailures++;
        }
        if (event == AdDiagnosticEventType.adShowSuccess) {
          metrics.appOpenShown++;
          metrics.lastAppOpenShownAt = DateTime.now();
        }
        if (event == AdDiagnosticEventType.adImpression) metrics.appOpenImpressions++;
        if (reason != null) {
          metrics.appOpenRejections[reason] = (metrics.appOpenRejections[reason] ?? 0) + 1;
        }
        break;

      case AdFormatType.rewarded:
        if (event == AdDiagnosticEventType.adRequest) metrics.rewardedRequests++;
        if (event == AdDiagnosticEventType.adLoadSuccess) metrics.rewardedLoaded++;
        if (event == AdDiagnosticEventType.adLoadFailure || event == AdDiagnosticEventType.adNoFill) {
          metrics.rewardedFailures++;
        }
        if (event == AdDiagnosticEventType.adShowSuccess) metrics.rewardedShown++;
        if (event == AdDiagnosticEventType.adImpression) metrics.rewardedEarned++;
        break;

      case AdFormatType.global:
        break;
    }
  }

  void setBannerVisible(bool visible) {
    if (metrics.isBannerVisible != visible) {
      metrics.isBannerVisible = visible;
      notifyListeners();
    }
  }

  void updateActionCount(int count) {
    metrics.actionsSinceInterstitial = count;
    notifyListeners();
  }

  void clearLogs() {
    _recentLogs.clear();
    metrics.reset();
    notifyListeners();
  }
}
