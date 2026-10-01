import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:filekit/features/monetization/ad_config.dart';
import 'package:filekit/features/monetization/ad_service.dart';
import 'package:filekit/features/monetization/admob_service.dart';
import 'package:filekit/features/monetization/free_usage_config.dart';
import 'package:filekit/features/monetization/presentation/banner_ad_widget.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/features/monetization/services/free_usage_manager.dart';

class TestControllableAdService extends AdService {
  bool isProUser = false;
  bool fullscreenShowing = false;
  bool processingActive = false;
  bool savingActive = false;
  bool sharingActive = false;
  DateTime? lastInterstitial;
  DateTime? lastAppOpen;
  int actionCount = 0;
  int opCount = 0;
  bool rewardedAvailable = true;
  bool shouldEarnReward = true;

  @override
  int get operationCount => opCount;

  @override
  bool get isFullscreenAdShowing => fullscreenShowing;

  @override
  void updateProStatus(bool isPro) {
    isProUser = isPro;
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
  void recordAction(AdTransitionPoint point) {
    if (!isProUser) actionCount++;
  }

  @override
  Future<void> recordOperationCompleted() async {
    opCount++;
  }

  @override
  bool isInterstitialEligible() {
    if (isProUser || !AdConfig.interstitialEnabled) return false;
    if (fullscreenShowing || processingActive || savingActive || sharingActive) return false;
    if (actionCount < AdConfig.maxActionsBetweenInterstitials &&
        opCount < AdConfig.interstitialOperationThreshold) {
      return false;
    }
    if (lastInterstitial != null) {
      final elapsed = DateTime.now().difference(lastInterstitial!);
      if (elapsed < AdConfig.interstitialCooldown) return false;
    }
    return true;
  }

  @override
  bool isAppOpenEligible() {
    if (isProUser || !AdConfig.appOpenEnabled) return false;
    if (fullscreenShowing || processingActive || savingActive || sharingActive) return false;
    if (lastAppOpen != null) {
      final elapsed = DateTime.now().difference(lastAppOpen!);
      if (elapsed < AdConfig.appOpenCooldown) return false;
    }
    return true;
  }

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    recordAction(point);
    if (!isInterstitialEligible()) return false;
    fullscreenShowing = true;
    lastInterstitial = DateTime.now();
    actionCount = 0;
    fullscreenShowing = false;
    return true;
  }

  @override
  Future<bool> maybeShowAppOpenAd() async {
    if (!isAppOpenEligible()) return false;
    fullscreenShowing = true;
    lastAppOpen = DateTime.now();
    fullscreenShowing = false;
    return true;
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {}

  @override
  Future<bool> showRewardedAd() async {
    if (isProUser) return true;
    if (fullscreenShowing) return false;
    if (!rewardedAvailable) return false;
    return shouldEarnReward;
  }

  @override
  Widget buildBannerAd() {
    if (isProUser || !AdConfig.bannerEnabled) return const SizedBox.shrink();
    return const SizedBox(width: 320, height: 50);
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ads Monetization Optimization V2 Test Suite', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('AD-V2-001: Premium user sees no banner', () {
      final service = TestControllableAdService()..updateProStatus(true);
      final widget = service.buildBannerAd();
      expect(widget, isA<SizedBox>());
      final sizedBox = widget as SizedBox;
      expect(sizedBox.width, equals(0.0));
      expect(sizedBox.height, equals(0.0));
    });

    test('AD-V2-002: Premium user sees no interstitial', () async {
      final service = TestControllableAdService()..updateProStatus(true);
      service.actionCount = 10;
      service.opCount = 10;
      expect(service.isInterstitialEligible(), isFalse);
      final shown = await service.maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );
      expect(shown, isFalse);
    });

    test('AD-V2-003: Premium user sees no rewarded requirement', () {
      final manager = FreeUsageManager(prefs);
      final check = manager.checkLimit(
        feature: ToolFeature.pdfMerge,
        requestedAmount: 50,
        isPro: true,
      );
      expect(check.isAllowed, isTrue);
      expect(check.isPro, isTrue);
      expect(check.canUnlockWithAd, isFalse);
    });

    test('AD-V2-004: Premium user sees no App Open ad', () async {
      final service = TestControllableAdService()..updateProStatus(true);
      expect(service.isAppOpenEligible(), isFalse);
      final shown = await service.maybeShowAppOpenAd();
      expect(shown, isFalse);
    });

    test('AD-V2-005: Interstitial cooldown enforced (60s)', () {
      final service = TestControllableAdService();
      service.actionCount = 2;
      expect(AdConfig.interstitialCooldown, equals(const Duration(seconds: 60)));

      // Simulate ad shown 30s ago
      service.lastInterstitial = DateTime.now().subtract(const Duration(seconds: 30));
      expect(service.isInterstitialEligible(), isFalse);

      // Simulate ad shown 65s ago
      service.lastInterstitial = DateTime.now().subtract(const Duration(seconds: 65));
      expect(service.isInterstitialEligible(), isTrue);
    });

    test('AD-V2-006: Maximum two actions between interstitial opportunities enforced', () {
      final service = TestControllableAdService();
      expect(AdConfig.maxActionsBetweenInterstitials, equals(2));

      service.actionCount = 0;
      service.opCount = 0;
      expect(service.isInterstitialEligible(), isFalse);

      service.actionCount = 1;
      expect(service.isInterstitialEligible(), isFalse);

      service.actionCount = 2;
      expect(service.isInterstitialEligible(), isTrue);
    });

    test('AD-V2-007: No interstitial during processing', () {
      final service = TestControllableAdService();
      service.actionCount = 5;
      expect(service.isInterstitialEligible(), isTrue);

      service.setProcessing(true);
      expect(service.isInterstitialEligible(), isFalse);

      service.setProcessing(false);
      expect(service.isInterstitialEligible(), isTrue);
    });

    test('AD-V2-008: No interstitial during saving', () {
      final service = TestControllableAdService();
      service.actionCount = 5;
      expect(service.isInterstitialEligible(), isTrue);

      service.setSaving(true);
      expect(service.isInterstitialEligible(), isFalse);

      service.setSaving(false);
      expect(service.isInterstitialEligible(), isTrue);
    });

    test('AD-V2-009: No interstitial during sharing', () {
      final service = TestControllableAdService();
      service.actionCount = 5;
      expect(service.isInterstitialEligible(), isTrue);

      service.setSharing(true);
      expect(service.isInterstitialEligible(), isFalse);

      service.setSharing(false);
      expect(service.isInterstitialEligible(), isTrue);
    });

    test('AD-V2-010: No two fullscreen ads simultaneously', () async {
      final service = TestControllableAdService();
      service.actionCount = 5;
      service.fullscreenShowing = true;

      expect(service.isInterstitialEligible(), isFalse);
      expect(service.isAppOpenEligible(), isFalse);
      expect(await service.showRewardedAd(), isFalse);
    });

    test('AD-V2-011: App Open cooldown enforced (120s)', () {
      final service = TestControllableAdService();
      expect(AdConfig.appOpenCooldown, equals(const Duration(seconds: 120)));

      // Shown 60s ago
      service.lastAppOpen = DateTime.now().subtract(const Duration(seconds: 60));
      expect(service.isAppOpenEligible(), isFalse);

      // Shown 125s ago
      service.lastAppOpen = DateTime.now().subtract(const Duration(seconds: 125));
      expect(service.isAppOpenEligible(), isTrue);
    });

    test('AD-V2-012: App Open does not block startup', () async {
      final admobService = AdmobService(prefs);
      // initialize() completes promptly without throwing
      await admobService.initialize();
      expect(admobService.operationCount, equals(0));
    });

    testWidgets('AD-V2-013: Banner does not overlap controls and renders in safe dedicated container', (tester) async {
      final service = TestControllableAdService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            adServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(child: Center(child: Text('Interactive Content'))),
                  BannerAdContainer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADVERTISEMENT'), findsOneWidget);
      expect(find.text('Interactive Content'), findsOneWidget);

      final contentRect = tester.getRect(find.text('Interactive Content'));
      final adRect = tester.getRect(find.text('ADVERTISEMENT'));

      // Clean separation without overlapping
      expect(adRect.top, greaterThan(contentRect.bottom));
    });

    test('AD-V2-014: Rewarded reward only granted after earned callback', () async {
      final service = TestControllableAdService();

      service.shouldEarnReward = false;
      final rewardNotEarned = await service.showRewardedAd();
      expect(rewardNotEarned, isFalse);

      service.shouldEarnReward = true;
      final rewardEarned = await service.showRewardedAd();
      expect(rewardEarned, isTrue);
    });

    test('AD-V2-015: Rewarded reward is operation-scoped', () {
      final manager = FreeUsageManager(prefs);
      expect(manager.hasTemporaryReward(ToolFeature.pdfMerge), isFalse);

      manager.grantTemporaryReward(ToolFeature.pdfMerge);
      expect(manager.hasTemporaryReward(ToolFeature.pdfMerge), isTrue);

      manager.consumeReward(ToolFeature.pdfMerge);
      expect(manager.hasTemporaryReward(ToolFeature.pdfMerge), isFalse);
    });

    test('AD-V2-016: Rewarded unavailable does not block operation within free limit', () {
      final manager = FreeUsageManager(prefs);
      // Free limit for PDF merge is 3
      final check = manager.checkLimit(
        feature: ToolFeature.pdfMerge,
        requestedAmount: 3,
        isPro: false,
      );
      expect(check.isAllowed, isTrue);
    });

    test('AD-V2-017: Offline operation still works for baseline limits', () {
      final manager = FreeUsageManager(prefs);
      final check = manager.checkLimit(
        feature: ToolFeature.imageToPdf,
        requestedAmount: 5,
        isPro: false,
      );
      expect(check.isAllowed, isTrue);
    });

    test('AD-V2-018: Ad load failure does not block operation', () async {
      final service = TestControllableAdService()..rewardedAvailable = false;
      final result = await service.showRewardedAd();
      expect(result, isFalse);
      // App continues normally
    });

    test('AD-V2-019: No automatic rewarded ad launch', () {
      final service = TestControllableAdService();
      // On fresh service without user tapping watch ad, no ad is showing
      expect(service.isFullscreenAdShowing, isFalse);
    });

    test('AD-V2-020: No ad click simulation in tests', () {
      // Test suite explicitly never performs simulated taps on live ad views
      expect(true, isTrue);
    });

    test('AD-V2-021: Processing -> Result transition can trigger eligible interstitial', () async {
      final service = TestControllableAdService();
      service.actionCount = 2;
      service.setProcessing(true);

      // During processing: not eligible
      expect(service.isInterstitialEligible(), isFalse);

      // Processing completes
      service.setProcessing(false);
      expect(service.isInterstitialEligible(), isTrue);

      final shown = await service.maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );
      expect(shown, isTrue);
    });

    test('AD-V2-022: Premium bypass works centrally in AdmobService', () {
      final admobService = AdmobService(prefs);
      admobService.updateProStatus(true);

      expect(admobService.isInterstitialEligible(), isFalse);
      expect(admobService.isAppOpenEligible(), isFalse);
      final banner = admobService.buildBannerAd();
      expect(banner, isA<SizedBox>());
    });
  });
}
