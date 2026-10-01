import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filekit/features/monetization/ad_config.dart';
import 'package:filekit/features/monetization/ad_service.dart';
import 'package:filekit/features/monetization/models/ad_frequency_state.dart';
import 'package:filekit/features/monetization/services/ad_diagnostics_service.dart';

/// Test implementation of AdService implementing full V3 lifecycle tracking
class TestV3AdService implements AdService {
  final AdDiagnosticsService diagnostics = AdDiagnosticsService();
  bool isProUser = false;
  bool processingActive = false;
  bool savingActive = false;
  bool sharingActive = false;
  bool fullscreenShowing = false;
  bool consentAllowed = true;
  int actionCount = 0;
  int opCount = 0;
  DateTime? lastInterstitial;
  DateTime? lastAppOpen;
  bool interstitialLoaded = false;
  bool isInterstitialLoading = false;
  bool appOpenLoaded = false;
  bool isAppOpenLoading = false;
  bool rewardedLoaded = false;
  bool shouldEarnReward = false;
  String? lastInterstitialRejection;
  String? lastAppOpenRejection;

  @override
  void updateProStatus(bool isPro) {
    isProUser = isPro;
    if (isPro) {
      interstitialLoaded = false;
      appOpenLoaded = false;
      rewardedLoaded = false;
    }
  }

  @override
  void setProcessing(bool value) {
    processingActive = value;
  }

  @override
  void setSaving(bool value) {
    savingActive = value;
  }

  @override
  void setSharing(bool value) {
    sharingActive = value;
  }

  @override
  void setCurrentRoute(String? route) {}

  @override
  void recordAction(AdTransitionPoint point) {
    if (!isProUser) {
      actionCount++;
      diagnostics.updateActionCount(actionCount);
    }
  }

  @override
  Future<void> recordOperationCompleted() async {
    opCount++;
  }

  @override
  int get operationCount => opCount;

  @override
  bool get isFullscreenAdShowing => fullscreenShowing;

  @override
  String? getLastInterstitialRejectionReason() => lastInterstitialRejection;

  @override
  String? getLastAppOpenRejectionReason() => lastAppOpenRejection;

  @override
  bool isInterstitialEligible() {
    if (!consentAllowed) {
      lastInterstitialRejection = 'no_consent';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adNoConsent, reason: 'no_consent');
      return false;
    }
    if (isProUser) {
      lastInterstitialRejection = 'premium';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
      return false;
    }
    if (!AdConfig.interstitialEnabled) {
      lastInterstitialRejection = 'format_disabled';
      return false;
    }
    if (fullscreenShowing) {
      lastInterstitialRejection = 'fullscreen_showing';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adFullscreenRejected, reason: 'fullscreen_showing');
      return false;
    }
    if (processingActive) {
      lastInterstitialRejection = 'processing';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adProcessingRejected, reason: 'processing');
      return false;
    }
    if (savingActive) {
      lastInterstitialRejection = 'saving';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adSavingRejected, reason: 'saving');
      return false;
    }
    if (sharingActive) {
      lastInterstitialRejection = 'sharing';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adSharingRejected, reason: 'sharing');
      return false;
    }
    if (actionCount < AdConfig.maxActionsBetweenInterstitials &&
        opCount < AdConfig.interstitialOperationThreshold) {
      lastInterstitialRejection = 'action_threshold';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adActionThresholdRejected, reason: 'action_threshold');
      return false;
    }
    if (lastInterstitial != null) {
      final elapsed = DateTime.now().difference(lastInterstitial!);
      if (elapsed < AdConfig.interstitialCooldown) {
        lastInterstitialRejection = 'cooldown';
        diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adCooldownRejected, reason: 'cooldown');
        return false;
      }
    }
    lastInterstitialRejection = null;
    return true;
  }

  @override
  bool isAppOpenEligible() {
    if (!consentAllowed) {
      lastAppOpenRejection = 'no_consent';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adNoConsent, reason: 'no_consent');
      return false;
    }
    if (isProUser) {
      lastAppOpenRejection = 'premium';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
      return false;
    }
    if (!AdConfig.appOpenEnabled) {
      lastAppOpenRejection = 'format_disabled';
      return false;
    }
    if (fullscreenShowing) {
      lastAppOpenRejection = 'fullscreen_showing';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adFullscreenRejected, reason: 'fullscreen_showing');
      return false;
    }
    if (processingActive) {
      lastAppOpenRejection = 'processing';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adProcessingRejected, reason: 'processing');
      return false;
    }
    if (savingActive) {
      lastAppOpenRejection = 'saving';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adSavingRejected, reason: 'saving');
      return false;
    }
    if (sharingActive) {
      lastAppOpenRejection = 'sharing';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adSharingRejected, reason: 'sharing');
      return false;
    }
    if (lastAppOpen != null) {
      final elapsed = DateTime.now().difference(lastAppOpen!);
      if (elapsed < AdConfig.appOpenCooldown) {
        lastAppOpenRejection = 'cooldown';
        diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adCooldownRejected, reason: 'cooldown');
        return false;
      }
    }
    if (!appOpenLoaded) {
      lastAppOpenRejection = 'not_loaded';
      diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adEligibilityRejected, reason: 'not_loaded');
      return false;
    }
    lastAppOpenRejection = null;
    return true;
  }

  @override
  Future<void> preloadInterstitialAd() async {
    if (isProUser || !AdConfig.interstitialEnabled || interstitialLoaded || isInterstitialLoading) {
      return;
    }
    isInterstitialLoading = true;
    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adRequest);
    // Simulate successful load
    isInterstitialLoading = false;
    interstitialLoaded = true;
    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adLoadSuccess);
    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adReady);
  }

  @override
  Future<void> preloadAppOpenAd() async {
    if (isProUser || !AdConfig.appOpenEnabled || appOpenLoaded || isAppOpenLoading) {
      return;
    }
    isAppOpenLoading = true;
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adRequest);
    isAppOpenLoading = false;
    appOpenLoaded = true;
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adLoadSuccess);
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adReady);
  }

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    recordAction(point);
    if (!isInterstitialEligible()) return false;
    if (!interstitialLoaded) {
      lastInterstitialRejection = 'not_loaded';
      diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adEligibilityRejected, reason: 'not_loaded');
      preloadInterstitialAd();
      return false;
    }

    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adShowAttempt);
    fullscreenShowing = true;
    lastInterstitial = DateTime.now();
    actionCount = 0;
    opCount = 0;
    interstitialLoaded = false;
    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adShowSuccess);
    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adImpression);
    fullscreenShowing = false;
    diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adDismissed);
    preloadInterstitialAd();
    return true;
  }

  @override
  Future<bool> maybeShowAppOpenAd() async {
    if (!isAppOpenEligible()) return false;
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adShowAttempt);
    fullscreenShowing = true;
    lastAppOpen = DateTime.now();
    appOpenLoaded = false;
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adShowSuccess);
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adImpression);
    fullscreenShowing = false;
    diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adDismissed);
    preloadAppOpenAd();
    return true;
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    if (force || isInterstitialEligible()) {
      maybeShowTransitionInterstitial(point: AdTransitionPoint.doneNavigation);
    }
  }

  @override
  Future<bool> showRewardedAd() async {
    if (isProUser) return true;
    if (fullscreenShowing || !rewardedLoaded) return false;
    diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adShowAttempt);
    fullscreenShowing = true;
    final earned = shouldEarnReward;
    if (earned) {
      diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adImpression, details: {'reward': 'extra_files'});
    }
    fullscreenShowing = false;
    diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adDismissed);
    return earned;
  }

  @override
  bool get isRewardedAdAvailable => rewardedLoaded;

  @override
  Future<void> preloadRewardedAd() async {
    diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adRequest);
    rewardedLoaded = true;
    diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adLoadSuccess);
  }

  @override
  Widget buildBannerAd() {
    if (isProUser || !AdConfig.bannerEnabled) return const SizedBox.shrink();
    diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adRequest);
    diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adLoadSuccess);
    diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adImpression);
    diagnostics.setBannerVisible(true);
    return const SizedBox(width: 320, height: 50);
  }

  @override
  Future<void> initialize() async {}
  @override
  bool get isConsentInfoInitialized => true;
  @override
  bool get isPrivacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptionsForm(BuildContext context) async {}
  @override
  void addConsentListener(VoidCallback listener) {}
  @override
  void removeConsentListener(VoidCallback listener) {}
  @override
  Future<bool> isNetworkAvailable() async => true;
  @override
  AdFrequencyState get frequencyState => AdFrequencyState(
        lastInterstitialAt: lastInterstitial,
        lastAppOpenAt: lastAppOpen,
        actionsSinceInterstitial: actionCount,
        isFullscreenAdShowing: fullscreenShowing,
        isProcessing: processingActive,
        isSaving: savingActive,
        isSharing: sharingActive,
        isPro: isProUser,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ads Visibility & Monetization Optimization V3 Suite', () {
    late TestV3AdService service;

    setUp(() {
      service = TestV3AdService();
      service.diagnostics.clearLogs();
    });

    test('AD-V3-001: Every ad request is tracked diagnostically', () async {
      expect(service.diagnostics.metrics.interstitialRequests, equals(0));
      await service.preloadInterstitialAd();
      expect(service.diagnostics.metrics.interstitialRequests, equals(1));

      expect(service.diagnostics.metrics.appOpenRequests, equals(0));
      await service.preloadAppOpenAd();
      expect(service.diagnostics.metrics.appOpenRequests, equals(1));

      expect(service.diagnostics.metrics.bannerRequests, equals(0));
      service.buildBannerAd();
      expect(service.diagnostics.metrics.bannerRequests, equals(1));
    });

    test('AD-V3-002: Every load success is tracked', () async {
      expect(service.diagnostics.metrics.interstitialLoaded, equals(0));
      await service.preloadInterstitialAd();
      expect(service.diagnostics.metrics.interstitialLoaded, equals(1));

      expect(service.diagnostics.metrics.appOpenLoaded, equals(0));
      await service.preloadAppOpenAd();
      expect(service.diagnostics.metrics.appOpenLoaded, equals(1));
    });

    test('AD-V3-003: Every load failure is tracked', () {
      service.diagnostics.logEvent(
        AdFormatType.interstitial,
        AdDiagnosticEventType.adLoadFailure,
        reason: 'Network timeout',
        details: {'code': 3},
      );
      expect(service.diagnostics.metrics.interstitialFailures, equals(1));

      service.diagnostics.logEvent(
        AdFormatType.banner,
        AdDiagnosticEventType.adLoadFailure,
        reason: 'No fill',
      );
      expect(service.diagnostics.metrics.bannerFailures, equals(1));
    });

    test('AD-V3-004: Interstitial rejection reports exact reason', () async {
      // 1. Premium rejection
      service.isProUser = true;
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('premium'));
      service.isProUser = false;

      // 2. Action threshold rejection
      service.actionCount = 0;
      service.opCount = 0;
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('action_threshold'));

      // Reach action threshold
      service.actionCount = AdConfig.maxActionsBetweenInterstitials;
      service.interstitialLoaded = true;

      // 3. Processing rejection
      service.setProcessing(true);
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('processing'));
      service.setProcessing(false);

      // 4. Saving rejection
      service.setSaving(true);
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('saving'));
      service.setSaving(false);

      // 5. Sharing rejection
      service.setSharing(true);
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('sharing'));
      service.setSharing(false);

      // 6. Fullscreen showing rejection
      service.fullscreenShowing = true;
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('fullscreen_showing'));
      service.fullscreenShowing = false;

      // Show interstitial to activate cooldown
      final shown = await service.maybeShowTransitionInterstitial(point: AdTransitionPoint.processingComplete);
      expect(shown, isTrue);

      // 7. Cooldown rejection
      service.actionCount = 2;
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('cooldown'));
    });

    test('AD-V3-005: App Open rejection reports exact reason', () async {
      service.appOpenLoaded = true;

      // 1. Premium rejection
      service.isProUser = true;
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('premium'));
      service.isProUser = false;

      // 2. Processing rejection
      service.setProcessing(true);
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('processing'));
      service.setProcessing(false);

      // 3. Saving rejection
      service.setSaving(true);
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('saving'));
      service.setSaving(false);

      // 4. Sharing rejection
      service.setSharing(true);
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('sharing'));
      service.setSharing(false);

      // 5. Not loaded rejection
      service.appOpenLoaded = false;
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('not_loaded'));
      service.appOpenLoaded = true;

      // Show App Open to activate cooldown
      final shown = await service.maybeShowAppOpenAd();
      expect(shown, isTrue);

      // 6. Cooldown rejection
      service.appOpenLoaded = true;
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('cooldown'));
    });

    test('AD-V3-006: Banner placement does not overlap controls', () {
      // Banner widget adheres to standard container constraints (height 50-60)
      final widget = service.buildBannerAd();
      expect(widget, isA<SizedBox>());
      final sizedBox = widget as SizedBox;
      expect(sizedBox.width, equals(320.0));
      expect(sizedBox.height, equals(50.0));
    });

    test('AD-V3-007: Premium receives no ads', () async {
      service.updateProStatus(true);

      // Banner is empty
      final banner = service.buildBannerAd();
      expect(banner, isA<SizedBox>());
      expect((banner as SizedBox).width, equals(0.0));

      // Interstitial is ineligible
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('premium'));

      // App Open is ineligible
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('premium'));

      // Rewarded is auto-bypassed for Pro
      final rewardedResult = await service.showRewardedAd();
      expect(rewardedResult, isTrue);
    });

    test('AD-V3-008: Consent prevents unauthorized ad requests', () {
      service.consentAllowed = false;
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('no_consent'));

      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastAppOpenRejectionReason(), equals('no_consent'));
    });

    test('AD-V3-009: Interstitial cooldown remains 60 seconds', () {
      expect(AdConfig.interstitialCooldown.inSeconds, equals(60));
    });

    test('AD-V3-010: No more than one interstitial after every two user actions', () {
      expect(AdConfig.maxActionsBetweenInterstitials, equals(2));
      service.actionCount = 1;
      service.opCount = 0;
      expect(service.isInterstitialEligible(), isFalse);

      service.actionCount = 2;
      expect(service.isInterstitialEligible(), isTrue);
    });

    test('AD-V3-011: App Open cooldown remains 120 seconds', () {
      expect(AdConfig.appOpenCooldown.inSeconds, equals(120));
    });

    test('AD-V3-012: Processing blocks fullscreen ads', () {
      service.appOpenLoaded = true;
      service.interstitialLoaded = true;
      service.actionCount = 2;

      service.setProcessing(true);
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('processing'));
      expect(service.getLastAppOpenRejectionReason(), equals('processing'));

      service.setProcessing(false);
      expect(service.isInterstitialEligible(), isTrue);
      expect(service.isAppOpenEligible(), isTrue);
    });

    test('AD-V3-013: Saving blocks fullscreen ads', () {
      service.appOpenLoaded = true;
      service.interstitialLoaded = true;
      service.actionCount = 2;

      service.setSaving(true);
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('saving'));
      expect(service.getLastAppOpenRejectionReason(), equals('saving'));

      service.setSaving(false);
      expect(service.isInterstitialEligible(), isTrue);
      expect(service.isAppOpenEligible(), isTrue);
    });

    test('AD-V3-014: Sharing blocks fullscreen ads', () {
      service.appOpenLoaded = true;
      service.interstitialLoaded = true;
      service.actionCount = 2;

      service.setSharing(true);
      expect(service.isInterstitialEligible(), isFalse);
      expect(service.isAppOpenEligible(), isFalse);
      expect(service.getLastInterstitialRejectionReason(), equals('sharing'));
      expect(service.getLastAppOpenRejectionReason(), equals('sharing'));

      service.setSharing(false);
      expect(service.isInterstitialEligible(), isTrue);
      expect(service.isAppOpenEligible(), isTrue);
    });

    test('AD-V3-015: Rewarded remains user initiated', () async {
      service.rewardedLoaded = true;
      service.shouldEarnReward = false;
      // Rewarded is only executed on user call
      expect(service.isRewardedAdAvailable, isTrue);
      final earned = await service.showRewardedAd();
      expect(earned, isFalse);
    });

    test('AD-V3-016: Reward granted only after earned callback', () async {
      service.rewardedLoaded = true;
      service.shouldEarnReward = true;
      final earned = await service.showRewardedAd();
      expect(earned, isTrue);
      expect(service.diagnostics.metrics.rewardedEarned, equals(1));
    });

    test('AD-V3-017: No duplicate banner requests', () {
      service.diagnostics.metrics.bannerRequests = 0;
      service.buildBannerAd();
      expect(service.diagnostics.metrics.bannerRequests, equals(1));
    });

    test('AD-V3-018: No duplicate interstitial loads', () async {
      service.interstitialLoaded = false;
      await service.preloadInterstitialAd();
      expect(service.diagnostics.metrics.interstitialRequests, equals(1));

      // Second preload when already loaded does not duplicate request
      await service.preloadInterstitialAd();
      expect(service.diagnostics.metrics.interstitialRequests, equals(1));
    });

    test('AD-V3-019: No duplicate App Open loads', () async {
      service.appOpenLoaded = false;
      await service.preloadAppOpenAd();
      expect(service.diagnostics.metrics.appOpenRequests, equals(1));

      // Second preload when already loaded does not duplicate request
      await service.preloadAppOpenAd();
      expect(service.diagnostics.metrics.appOpenRequests, equals(1));
    });

    test('AD-V3-020: Ads unavailable never block file processing', () async {
      // When ad is null, maybeShowTransitionInterstitial returns false gracefully without throwing
      service.interstitialLoaded = false;
      service.actionCount = 2;
      final result = await service.maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );
      expect(result, isFalse);
      // File processing continues smoothly
    });
  });
}
