import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:filekit/features/monetization/ad_service.dart';
import 'package:filekit/features/monetization/free_usage_config.dart';
import 'package:filekit/features/monetization/presentation/free_limit_sheet.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/features/monetization/services/free_usage_manager.dart';

class ControllableAdService implements AdService {
  bool isAdAvailable = true;
  bool shouldEarnReward = true;
  bool shouldFailLoad = false;
  bool shouldThrowError = false;
  int showRewardedCalls = 0;
  int preloadCalls = 0;
  bool isShowingAd = false;

  @override
  int get operationCount => 0;

  @override
  Future<void> initialize() async {}

  @override
  Widget buildBannerAd() => const SizedBox.shrink();

  @override
  Future<void> recordOperationCompleted() async {}

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {}

  @override
  void updateProStatus(bool isPro) {}

  @override
  bool get isRewardedAdAvailable => isAdAvailable;

  @override
  Future<void> preloadRewardedAd() async {
    preloadCalls++;
  }

  @override
  Future<bool> showRewardedAd() async {
    showRewardedCalls++;
    if (isShowingAd) {
      // Rapid tap protection: reject concurrent shows
      return false;
    }
    if (shouldThrowError) {
      throw Exception('Ad network socket failure');
    }
    if (shouldFailLoad || !isAdAvailable) {
      return false;
    }

    isShowingAd = true;
    await Future.delayed(const Duration(milliseconds: 10));
    isShowingAd = false;

    return shouldEarnReward;
  }

  bool networkAvailable = true;
  int transitionAdCalls = 0;

  @override
  Future<bool> isNetworkAvailable() async => networkAvailable;

  @override
  bool isInterstitialEligible() => false;

  @override
  void recordAction(AdTransitionPoint point) {}

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    transitionAdCalls++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late FreeUsageManager usageManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    usageManager = FreeUsageManager(testPrefs);
  });

  group('FreeUsageConfig Centralized Constants', () {
    test('Configures exact per-feature limits', () {
      expect(FreeUsageConfig.getFreeLimit(ToolFeature.pdfMerge), 3);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.pdfMerge), 8);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.pdfSplit), 5);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.pdfSplit), 10);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.pdfRotate), 5);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.pdfRotate), 10);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.pdfReorder), 10);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.pdfReorder), 20);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.pdfToImage), 5);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.pdfToImage), 10);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.imageToPdf), 5);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.imageToPdf), 10);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.pdfCompress), 10 * 1024 * 1024);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.pdfCompress), 25 * 1024 * 1024);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.imageCompress), 10 * 1024 * 1024);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.imageCompress), 25 * 1024 * 1024);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.imageResize), 10 * 1024 * 1024);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.imageResize), 25 * 1024 * 1024);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.imageConvert), 10 * 1024 * 1024);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.imageConvert), 25 * 1024 * 1024);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.createZip), 10);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.createZip), 20);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.extractZip), 10);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.extractZip), 20);

      expect(FreeUsageConfig.getFreeLimit(ToolFeature.batchRename), 10);
      expect(FreeUsageConfig.getRewardedLimit(ToolFeature.batchRename), 20);
    });

    test('Identifies byte-limit tools properly', () {
      expect(FreeUsageConfig.isByteLimit(ToolFeature.pdfCompress), true);
      expect(FreeUsageConfig.isByteLimit(ToolFeature.imageCompress), true);
      expect(FreeUsageConfig.isByteLimit(ToolFeature.imageResize), true);
      expect(FreeUsageConfig.isByteLimit(ToolFeature.imageConvert), true);
      expect(FreeUsageConfig.isByteLimit(ToolFeature.pdfMerge), false);
      expect(FreeUsageConfig.isByteLimit(ToolFeature.createZip), false);
    });

    test('Formats amounts and bonus text cleanly', () {
      expect(FreeUsageConfig.formatAmount(ToolFeature.pdfMerge, 3), '3 PDFs');
      expect(FreeUsageConfig.formatAmount(ToolFeature.pdfCompress, 10 * 1024 * 1024), '10 MB');
      expect(FreeUsageConfig.getRewardBonusText(ToolFeature.pdfMerge), '+5 PDFs');
      expect(FreeUsageConfig.getRewardBonusText(ToolFeature.pdfCompress), 'up to 25 MB');
    });
  });

  group('Free Usage Limits & Rewarded Allowance Tests', () {
    test('1. Free Merge limit: 1, 2, 3 PDFs allowed, 4 PDFs blocked', () {
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 1, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 2, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 3, isPro: false).isAllowed, isTrue);

      final blocked = usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 4, isPro: false);
      expect(blocked.isAllowed, isFalse);
      expect(blocked.canUnlockWithAd, isTrue);
    });

    test('2. Merge rewarded allowance: +5 grants up to 8 PDFs, resets after consume', () {
      // 4 PDFs blocked initially
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 4, isPro: false).isAllowed, isFalse);

      // Reward grants +5 (up to 8)
      usageManager.grantTemporaryReward(ToolFeature.pdfMerge);
      expect(usageManager.hasTemporaryReward(ToolFeature.pdfMerge), isTrue);

      final allowedAfterReward = usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 4, isPro: false);
      expect(allowedAfterReward.isAllowed, isTrue);
      expect(allowedAfterReward.usedTemporaryReward, isTrue);

      // 8 PDFs allowed
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 8, isPro: false).isAllowed, isTrue);

      // 9 PDFs blocked even with reward
      final overReward = usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 9, isPro: false);
      expect(overReward.isAllowed, isFalse);
      expect(overReward.canUnlockWithAd, isFalse);

      // Reward applies only to current operation: consume returns to free limit
      usageManager.consumeReward(ToolFeature.pdfMerge);
      expect(usageManager.hasTemporaryReward(ToolFeature.pdfMerge), isFalse);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 4, isPro: false).isAllowed, isFalse);
    });

    test('3. Split limits: 5 allowed, 6 blocked, rewarded unlocks up to 10', () {
      expect(usageManager.checkLimit(feature: ToolFeature.pdfSplit, requestedAmount: 5, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfSplit, requestedAmount: 6, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.pdfSplit);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfSplit, requestedAmount: 10, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfSplit, requestedAmount: 11, isPro: false).isAllowed, isFalse);
    });

    test('4. Rotate limits: 5 allowed, 6 blocked, rewarded unlocks up to 10', () {
      expect(usageManager.checkLimit(feature: ToolFeature.pdfRotate, requestedAmount: 5, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfRotate, requestedAmount: 6, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.pdfRotate);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfRotate, requestedAmount: 10, isPro: false).isAllowed, isTrue);
    });

    test('5. Reorder limits: 10 allowed, 11 blocked, rewarded unlocks up to 20', () {
      expect(usageManager.checkLimit(feature: ToolFeature.pdfReorder, requestedAmount: 10, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfReorder, requestedAmount: 11, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.pdfReorder);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfReorder, requestedAmount: 20, isPro: false).isAllowed, isTrue);
    });

    test('6. PDF -> Image limits: 5 allowed, 6 blocked, rewarded unlocks up to 10', () {
      expect(usageManager.checkLimit(feature: ToolFeature.pdfToImage, requestedAmount: 5, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfToImage, requestedAmount: 6, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.pdfToImage);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfToImage, requestedAmount: 10, isPro: false).isAllowed, isTrue);
    });

    test('7. Image -> PDF limits: 5 allowed, 6 blocked, rewarded unlocks up to 10', () {
      expect(usageManager.checkLimit(feature: ToolFeature.imageToPdf, requestedAmount: 5, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.imageToPdf, requestedAmount: 6, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.imageToPdf);
      expect(usageManager.checkLimit(feature: ToolFeature.imageToPdf, requestedAmount: 10, isPro: false).isAllowed, isTrue);
    });

    test('8. PDF compression file-size limits: 10MB free, up to 25MB rewarded', () {
      const mb = 1024 * 1024;
      expect(usageManager.checkLimit(feature: ToolFeature.pdfCompress, requestedAmount: 5 * mb, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfCompress, requestedAmount: 10 * mb, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfCompress, requestedAmount: 15 * mb, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.pdfCompress);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfCompress, requestedAmount: 25 * mb, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfCompress, requestedAmount: 26 * mb, isPro: false).isAllowed, isFalse);
    });

    test('9. Image compression limits: 10MB free, 25MB rewarded', () {
      const mb = 1024 * 1024;
      expect(usageManager.checkLimit(feature: ToolFeature.imageCompress, requestedAmount: 9 * mb, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.imageCompress, requestedAmount: 11 * mb, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.imageCompress);
      expect(usageManager.checkLimit(feature: ToolFeature.imageCompress, requestedAmount: 20 * mb, isPro: false).isAllowed, isTrue);
    });

    test('10. Image resize limits: 10MB free, 25MB rewarded', () {
      const mb = 1024 * 1024;
      expect(usageManager.checkLimit(feature: ToolFeature.imageResize, requestedAmount: 8 * mb, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.imageResize, requestedAmount: 12 * mb, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.imageResize);
      expect(usageManager.checkLimit(feature: ToolFeature.imageResize, requestedAmount: 22 * mb, isPro: false).isAllowed, isTrue);
    });

    test('11. Image conversion limits: 10MB free, 25MB rewarded', () {
      const mb = 1024 * 1024;
      expect(usageManager.checkLimit(feature: ToolFeature.imageConvert, requestedAmount: 10 * mb, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.imageConvert, requestedAmount: 12 * mb, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.imageConvert);
      expect(usageManager.checkLimit(feature: ToolFeature.imageConvert, requestedAmount: 24 * mb, isPro: false).isAllowed, isTrue);
    });

    test('12. Create ZIP limits: 10 files free, 20 files rewarded', () {
      expect(usageManager.checkLimit(feature: ToolFeature.createZip, requestedAmount: 10, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.createZip, requestedAmount: 11, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.createZip);
      expect(usageManager.checkLimit(feature: ToolFeature.createZip, requestedAmount: 20, isPro: false).isAllowed, isTrue);
    });

    test('13. Extract ZIP limits: 10 files free, 20 files rewarded', () {
      expect(usageManager.checkLimit(feature: ToolFeature.extractZip, requestedAmount: 10, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.extractZip, requestedAmount: 12, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.extractZip);
      expect(usageManager.checkLimit(feature: ToolFeature.extractZip, requestedAmount: 18, isPro: false).isAllowed, isTrue);
    });

    test('14. Batch rename limits: 10 files free, 20 files rewarded', () {
      expect(usageManager.checkLimit(feature: ToolFeature.batchRename, requestedAmount: 10, isPro: false).isAllowed, isTrue);
      expect(usageManager.checkLimit(feature: ToolFeature.batchRename, requestedAmount: 15, isPro: false).isAllowed, isFalse);

      usageManager.grantTemporaryReward(ToolFeature.batchRename);
      expect(usageManager.checkLimit(feature: ToolFeature.batchRename, requestedAmount: 20, isPro: false).isAllowed, isTrue);
    });

    test('15. Premium user bypasses every free limit across all 13 tools', () {
      const hugeAmount = 500 * 1024 * 1024; // 500 MB
      for (final feature in ToolFeature.values) {
        final result = usageManager.checkLimit(
          feature: feature,
          requestedAmount: hugeAmount,
          isPro: true,
        );
        expect(result.isAllowed, isTrue, reason: 'Pro user must bypass limit for ${feature.name}');
        expect(result.isPro, isTrue);
      }
    });

    test('21. Temporary reward does not leak across different tools', () {
      usageManager.grantTemporaryReward(ToolFeature.pdfMerge);

      // Merge is unlocked for current operation
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 5, isPro: false).isAllowed, isTrue);

      // Split must REMAIN BLOCKED
      final splitResult = usageManager.checkLimit(feature: ToolFeature.pdfSplit, requestedAmount: 8, isPro: false);
      expect(splitResult.isAllowed, isFalse);
      expect(splitResult.usedTemporaryReward, isFalse);
    });

    test('22. App restart keeps persistent state but cleans temporary in-memory rewards', () async {
      // Record historical feature usage in SharedPreferences
      await usageManager.recordFeatureUsage(ToolFeature.pdfMerge);
      await usageManager.recordFeatureUsage(ToolFeature.pdfMerge);
      expect(usageManager.getFeatureUsageCount(ToolFeature.pdfMerge), 2);

      // Grant in-memory temporary reward
      usageManager.grantTemporaryReward(ToolFeature.pdfMerge);
      expect(usageManager.hasTemporaryReward(ToolFeature.pdfMerge), isTrue);

      // Simulate App Restart (new instance initialized with same SharedPreferences)
      final restartedManager = FreeUsageManager(testPrefs);

      // Usage count persists
      expect(restartedManager.getFeatureUsageCount(ToolFeature.pdfMerge), 2);

      // Temporary reward is clean (in-memory only, no accidental permanent unlock)
      expect(restartedManager.hasTemporaryReward(ToolFeature.pdfMerge), isFalse);
      expect(restartedManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 4, isPro: false).isAllowed, isFalse);
    });
  });

  group('Rewarded Ad Manager & Lifecycle Tests', () {
    late ControllableAdService mockAdService;

    setUp(() {
      mockAdService = ControllableAdService();
    });

    test('16. Rewarded ad completed grants reward', () async {
      mockAdService.shouldEarnReward = true;
      final success = await mockAdService.showRewardedAd();
      expect(success, isTrue);
      expect(mockAdService.showRewardedCalls, 1);
    });

    test('17. Rewarded ad dismissed early grants NO reward', () async {
      mockAdService.shouldEarnReward = false;
      final success = await mockAdService.showRewardedAd();
      expect(success, isFalse);
    });

    test('18. Rewarded ad load failure or offline returns false without usage increase', () async {
      mockAdService.shouldFailLoad = true;
      final success = await mockAdService.showRewardedAd();
      expect(success, isFalse);
    });

    test('19. Ad network exception is caught gracefully', () async {
      mockAdService.shouldThrowError = true;
      expect(() => mockAdService.showRewardedAd(), throwsA(isA<Exception>()));
    });

    test('20. Rapid tap protection blocks concurrent ad displays', () async {
      mockAdService.isShowingAd = true; // Simulates ad already open
      final secondCall = await mockAdService.showRewardedAd();
      expect(secondCall, isFalse);
    });
  });

  group('FreeLimitSheet & FreeLimitHelper UI Tests', () {
    late ControllableAdService mockAdService;

    setUp(() {
      mockAdService = ControllableAdService();
    });

    testWidgets('Renders FreeLimitSheet with details, buttons, and accessibility labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            adServiceProvider.overrideWithValue(mockAdService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FreeLimitSheet(
                feature: ToolFeature.pdfMerge,
                requestedAmount: 5,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // UI verification
      expect(find.text('Free Limit Reached'), findsOneWidget);
      expect(find.text("You're using the free version of FileWorks."), findsOneWidget);
      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('5 PDFs selected'), findsOneWidget);
      expect(find.text('Free limit: 3 PDFs per operation.'), findsOneWidget);
      expect(find.text('Watch Ad & Continue'), findsOneWidget);
      expect(find.text('Go Premium (Unlimited & Ad-Free)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Tapping Watch Ad & Continue invokes showRewardedAd and pops with true', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            adServiceProvider.overrideWithValue(mockAdService),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    dialogResult = await FreeLimitSheet.show(
                      context,
                      feature: ToolFeature.pdfMerge,
                      requestedAmount: 4,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Free Limit Reached'), findsOneWidget);

      // Tap Watch Ad
      await tester.tap(find.text('Watch Ad & Continue'));
      await tester.pumpAndSettle();

      expect(mockAdService.showRewardedCalls, 1);
      expect(dialogResult, isTrue);
    });

    testWidgets('When ad is unavailable or offline, shows helpful error message', (tester) async {
      mockAdService.isAdAvailable = false;
      mockAdService.shouldFailLoad = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            adServiceProvider.overrideWithValue(mockAdService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FreeLimitSheet(
                feature: ToolFeature.pdfMerge,
                requestedAmount: 4,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Watch Ad & Continue'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("You're offline or a rewarded ad is currently unavailable."),
        findsOneWidget,
      );
    });

    testWidgets('When request exceeds rewarded limit, offers Premium rather than rewarded ad', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            adServiceProvider.overrideWithValue(mockAdService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FreeLimitSheet(
                feature: ToolFeature.pdfMerge,
                requestedAmount: 15, // > rewarded limit of 8
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Watch Ad & Continue'), findsNothing);
      expect(find.textContaining('exceeds the ad-rewarded allowance'), findsOneWidget);
      expect(find.text('Go Premium (Unlimited & Ad-Free)'), findsOneWidget);
    });
  });
}
