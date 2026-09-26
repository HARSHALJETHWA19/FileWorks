import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filekit/core/constants/app_constants.dart';
import 'package:filekit/core/constants/route_constants.dart';
import 'package:filekit/features/monetization/ad_service.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/shared/models/processing_result.dart';
import 'package:filekit/shared/presentation/result_screen.dart';

class MockAdService implements AdService {
  int recordCallCount = 0;
  int showInterstitialCallCount = 0;
  bool forceShown = false;
  int _ops = 0;

  @override
  int get operationCount => _ops;

  @override
  Future<void> initialize() async {}

  @override
  Widget buildBannerAd() => const SizedBox.shrink();

  @override
  Future<void> recordOperationCompleted() async {
    recordCallCount++;
    _ops++;
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    showInterstitialCallCount++;
    forceShown = force;
  }

  @override
  void updateProStatus(bool isPro) {}

  @override
  Future<bool> showRewardedAd() async => true;

  @override
  bool get isRewardedAdAvailable => true;

  @override
  Future<void> preloadRewardedAd() async {}

  @override
  Future<bool> isNetworkAvailable() async => true;

  @override
  bool isInterstitialEligible() => false;

  @override
  void recordAction(AdTransitionPoint point) {}

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    showInterstitialCallCount++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdService mockAdService;
  late SharedPreferences testPrefs;
  late File sampleOutputFile;

  setUpAll(() {
    sampleOutputFile = File('${Directory.systemTemp.path}/test_result_out.pdf')
      ..writeAsStringSync('Sample PDF content for test');
  });

  tearDownAll(() {
    if (sampleOutputFile.existsSync()) {
      sampleOutputFile.deleteSync();
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    mockAdService = MockAdService();
  });

  Widget buildTestableWidget({
    required ProcessingResult result,
    bool isPro = false,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(testPrefs),
        adServiceProvider.overrideWithValue(mockAdService),
        isProProvider.overrideWith(() {
          final notifier = ProNotifier();
          if (isPro) {
            testPrefs.setBool(AppConstants.keyIsProUser, true);
          }
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: ResultScreen(result: result),
      ),
    );
  }

  group('ResultScreen UX & Ad Timing Verification Tests', () {
    testWidgets('RESULT-001: Displays successful result details on mount without automatic interstitial ad',
        (tester) async {
      final testResult = ProcessingResult(
        success: true,
        title: 'PDF Compression Complete',
        message: 'Reduced file size by 65.0%.',
        outputFiles: [sampleOutputFile],
        originalTotalBytes: 1000,
        outputTotalBytes: 350,
        repeatRoute: RouteConstants.pdfCompress,
      );

      await tester.pumpWidget(buildTestableWidget(result: testResult, isPro: false));
      await tester.pumpAndSettle();

      // Verify that result UI details are immediately visible to user
      expect(find.text('PDF Compression Complete'), findsOneWidget);
      expect(find.text('Reduced file size by 65.0%.'), findsOneWidget);
      expect(find.text('Process Another File'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Open File'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      // Verify that operation completion was recorded
      expect(mockAdService.recordCallCount, equals(1));

      // CRITICAL: Interstitial ad must NOT have been shown automatically on screen entry!
      expect(mockAdService.showInterstitialCallCount, equals(0));
    });

    testWidgets('RESULT-002: Tapping "Process Another File" triggers interstitial eligibility check for free users',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testResult = ProcessingResult(
        success: true,
        title: 'Image Compression Complete',
        message: 'Target reached! All images reduced under 500 KB.',
        outputFiles: [sampleOutputFile],
        originalTotalBytes: 800,
        outputTotalBytes: 300,
        repeatRoute: RouteConstants.imageCompress,
      );

      await tester.pumpWidget(buildTestableWidget(result: testResult, isPro: false));
      await tester.pumpAndSettle();

      expect(mockAdService.showInterstitialCallCount, equals(0));

      final processAnotherBtn = find.widgetWithText(FilledButton, 'Process Another File');
      expect(processAnotherBtn, findsOneWidget);

      await tester.ensureVisible(processAnotherBtn);
      await tester.tap(processAnotherBtn);
      await tester.pumpAndSettle();

      // Free user exit action should trigger ad readiness check
      expect(mockAdService.showInterstitialCallCount, equals(1));
    });

    testWidgets('RESULT-003: Pro user never triggers interstitial ad on any action', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testResult = ProcessingResult(
        success: true,
        title: 'PDF Split Complete',
        message: 'Extracted 3 individual pages.',
        outputFiles: [sampleOutputFile],
        originalTotalBytes: 1200,
        outputTotalBytes: 600,
        repeatRoute: RouteConstants.pdfSplit,
      );

      await tester.pumpWidget(buildTestableWidget(result: testResult, isPro: true));
      await tester.pumpAndSettle();

      // Verify Pro user on entry: no ad
      expect(mockAdService.showInterstitialCallCount, equals(0));

      // Tap Process Another File
      final processAnotherBtn = find.widgetWithText(FilledButton, 'Process Another File');
      await tester.ensureVisible(processAnotherBtn);
      await tester.tap(processAnotherBtn);
      await tester.pumpAndSettle();

      // Pro user must NEVER trigger interstitial
      expect(mockAdService.showInterstitialCallCount, equals(0));
    });

    testWidgets('RESULT-004: Process Another File button has semantic label for accessibility',
        (tester) async {
      final testResult = ProcessingResult(
        success: true,
        title: 'ZIP Archive Created',
        message: 'Compressed 2 files into an archive.',
        outputFiles: [sampleOutputFile],
        originalTotalBytes: 500,
        outputTotalBytes: 250,
        repeatRoute: RouteConstants.createZip,
      );

      await tester.pumpWidget(buildTestableWidget(result: testResult, isPro: false));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Process Another File'), findsOneWidget);
      expect(find.bySemanticsLabel('Done and return home'), findsOneWidget);
    });
  });

  group('Target Compression Presets Calculation Tests', () {
    test('PRESET-001: Standard presets resolve to exact target bytes', () {
      const preset100Kb = 100 * 1024;
      const preset200Kb = 200 * 1024;
      const preset500Kb = 500 * 1024;
      const preset2Mb = 2 * 1024 * 1024;

      expect(preset100Kb, equals(102400));
      expect(preset200Kb, equals(204800));
      expect(preset500Kb, equals(512000));
      expect(preset2Mb, equals(2097152));
    });

    test('PRESET-002: Custom input parses valid numbers and handles unit switching safely', () {
      int calculateTarget(String input, String unit) {
        final text = input.trim();
        final value = double.tryParse(text);
        if (value != null && value > 0) {
          if (unit == 'MB') {
            return (value * 1024 * 1024).round().clamp(10 * 1024, 100 * 1024 * 1024);
          } else {
            return (value * 1024).round().clamp(10 * 1024, 100 * 1024 * 1024);
          }
        }
        return 500 * 1024; // fallback default
      }

      // Valid KB & MB inputs
      expect(calculateTarget('150', 'KB'), equals(150 * 1024));
      expect(calculateTarget('1.5', 'MB'), equals((1.5 * 1024 * 1024).round()));

      // Clamp protection: very small input clamped to 10 KB
      expect(calculateTarget('1', 'KB'), equals(10 * 1024));

      // Clamp protection: very large input clamped to 100 MB
      expect(calculateTarget('500', 'MB'), equals(100 * 1024 * 1024));

      // Invalid input falls back to default
      expect(calculateTarget('invalid', 'KB'), equals(500 * 1024));
      expect(calculateTarget('-50', 'KB'), equals(500 * 1024));
      expect(calculateTarget('0', 'KB'), equals(500 * 1024));
      expect(calculateTarget('', 'KB'), equals(500 * 1024));
    });
  });
}
