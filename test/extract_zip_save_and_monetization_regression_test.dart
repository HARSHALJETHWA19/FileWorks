import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:filekit/core/constants/app_constants.dart';
import 'package:filekit/core/services/file_save_service.dart';
import 'package:filekit/features/monetization/ad_config.dart';
import 'package:filekit/features/monetization/ad_service.dart';
import 'package:filekit/features/monetization/free_usage_config.dart';
import 'package:filekit/features/monetization/presentation/free_limit_sheet.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/features/monetization/services/free_usage_manager.dart';
import 'package:filekit/shared/models/processing_result.dart';
import 'package:filekit/shared/presentation/result_screen.dart';

class CustomMockFilePickerPlatform extends FilePickerPlatform {
  final List<String> savedNames = [];
  final List<Uint8List> savedBytes = [];
  int cancelAfterCount = -1;
  int failAfterCount = -1;
  int callIndex = 0;

  void reset() {
    savedNames.clear();
    savedBytes.clear();
    cancelAfterCount = -1;
    failAfterCount = -1;
    callIndex = 0;
  }

  @override
  Future<Uri?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
    LinuxOptions? linuxOptions,
    String? mimeType,
    dynamic onFileSaving,
    dynamic webOptions,
    dynamic windowsOptions,
  }) async {
    callIndex++;
    if (cancelAfterCount > 0 && callIndex > cancelAfterCount) {
      return null;
    }
    if (failAfterCount > 0 && callIndex > failAfterCount) {
      throw Exception('SAF write permission denied on device');
    }

    if (fileName != null) {
      savedNames.add(fileName);
    }
    if (bytes != null) {
      savedBytes.add(bytes);
    }
    return Uri.file('/storage/emulated/0/Download/$fileName');
  }
}

class TestAdService extends AdService {
  int interstitialCount = 0;
  int rewardedCount = 0;
  bool isProUser = false;
  bool networkAvailable = true;
  bool shouldEarnReward = true;
  final List<AdTransitionPoint> recordedActions = [];

  @override
  int get operationCount => 0;

  @override
  Future<void> initialize() async {}

  @override
  Widget buildBannerAd() => const SizedBox.shrink();

  @override
  Future<void> recordOperationCompleted() async {}

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    if (isProUser) return;
    interstitialCount++;
  }

  @override
  void updateProStatus(bool isPro) {
    isProUser = isPro;
  }

  @override
  bool get isRewardedAdAvailable => true;

  @override
  Future<void> preloadRewardedAd() async {}

  @override
  Future<bool> showRewardedAd() async {
    rewardedCount++;
    if (!networkAvailable) return false;
    return shouldEarnReward;
  }

  @override
  Future<bool> isNetworkAvailable() async => networkAvailable;

  @override
  bool isInterstitialEligible() => !isProUser;

  @override
  void recordAction(AdTransitionPoint point) {
    recordedActions.add(point);
  }

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    recordAction(point);
    if (isProUser) return false;
    interstitialCount++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CustomMockFilePickerPlatform mockPicker;
  late TestAdService mockAdService;
  late SharedPreferences testPrefs;
  late Directory tempDir;
  late File filePdf;
  late File fileJpg;
  late File fileDocx;
  late File fileTxt;

  setUpAll(() async {
    mockPicker = CustomMockFilePickerPlatform();
    FilePickerPlatform.instance = mockPicker;

    tempDir = await Directory.systemTemp.createTemp('fw_zip_monetize_test_');
    filePdf = File('${tempDir.path}/report.pdf')..writeAsStringSync('PDF Document Content');
    fileJpg = File('${tempDir.path}/photo.jpg')..writeAsStringSync('JPG Image Content');
    fileDocx = File('${tempDir.path}/notes.docx')..writeAsStringSync('DOCX Document Content');
    fileTxt = File('${tempDir.path}/data.txt')..writeAsStringSync('Plain text file content');
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    mockPicker.reset();
    FilePickerPlatform.instance = mockPicker;
    mockAdService = TestAdService();
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget({
    required ProcessingResult result,
    bool isPro = false,
  }) {
    mockAdService.updateProStatus(isPro);
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
        home: Scaffold(
          body: ResultScreen(result: result),
        ),
      ),
    );
  }

  group('Extract ZIP Save All & Individual File Tests', () {
    test('1. saveAllFilesIndividually saves every extracted file with original name and extension', () async {
      final res = await FileSaveService.saveAllFilesIndividually(
        files: [filePdf, fileJpg, fileDocx, fileTxt],
      );

      expect(res.isAllSuccessful, isTrue);
      expect(res.savedCount, 4);
      expect(mockPicker.savedNames.length, 4);
      expect(mockPicker.savedNames, containsAll(['report.pdf', 'photo.jpg', 'notes.docx', 'data.txt']));
      // Never silently create a ZIP archive
      expect(mockPicker.savedNames.any((n) => n.endsWith('.zip')), isFalse);
    });

    test('2. saveAllFilesIndividually handles cancellation gracefully preserving earlier saved files', () async {
      mockPicker.cancelAfterCount = 2;
      final res = await FileSaveService.saveAllFilesIndividually(
        files: [filePdf, fileJpg, fileDocx, fileTxt],
      );

      expect(res.savedCount, 2);
      expect(res.cancelledCount, 1);
      expect(res.wasCancelled, isFalse); // Has partial saves
      expect(res.isPartialSuccess, isTrue);
      expect(mockPicker.savedNames.length, 2);
    });

    test('3. saveAllFilesIndividually reports partial failure clearly without losing saved files', () async {
      mockPicker.failAfterCount = 2;
      final res = await FileSaveService.saveAllFilesIndividually(
        files: [filePdf, fileJpg, fileDocx, fileTxt],
      );

      expect(res.savedCount, 2);
      expect(res.failedCount, 2);
      expect(res.failedFileNames, containsAll(['notes.docx', 'data.txt']));
      expect(mockPicker.savedNames.length, 2);
    });

    test('4. Explicit saveMultipleFilesAsZipToDevice creates a single ZIP when deliberately chosen', () async {
      final res = await FileSaveService.saveMultipleFilesAsZipToDevice(
        files: [filePdf, fileJpg, fileDocx, fileTxt],
        zipFileName: 'custom_archive.zip',
      );

      expect(res.status, FileSaveStatus.success);
      expect(mockPicker.savedNames.length, 1);
      expect(mockPicker.savedNames.first, 'custom_archive.zip');
    });

    testWidgets('5. Extract ZIP with 1 file presents single file UI and actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final result = ProcessingResult(
        success: true,
        feature: ToolFeature.extractZip,
        title: 'ZIP Extracted Successfully',
        message: '1 file extracted safely.',
        outputFiles: [filePdf],
      );

      await tester.pumpWidget(buildTestWidget(result: result));
      await tester.pumpAndSettle();

      expect(find.text('Save to Device'), findsOneWidget);
      expect(find.text('Open File'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('6. Extract ZIP with multiple files renders "Save All Files" as primary and "Save as ZIP" as secondary', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final result = ProcessingResult(
        success: true,
        feature: ToolFeature.extractZip,
        title: 'ZIP Extracted Successfully',
        message: '4 files extracted safely.',
        outputFiles: [filePdf, fileJpg, fileDocx, fileTxt],
      );

      await tester.pumpWidget(buildTestWidget(result: result));
      await tester.pumpAndSettle();

      // Primary button for Extract ZIP must be Save All Files
      expect(find.text('Save All Files'), findsOneWidget);
      // Explicit secondary button must be Save as ZIP
      expect(find.text('Save as ZIP'), findsOneWidget);
      // Share All must exist
      expect(find.text('Share All (4 files)'), findsOneWidget);
    });

    testWidgets('7. Non-extractZip operations (e.g. Split PDF) retain "Save All to Device (ZIP)" as primary', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final result = ProcessingResult(
        success: true,
        feature: ToolFeature.pdfSplit,
        title: 'PDF Split Complete',
        message: '2 pages extracted.',
        outputFiles: [filePdf, fileDocx],
      );

      await tester.pumpWidget(buildTestWidget(result: result));
      await tester.pumpAndSettle();

      // For split PDF, primary is Save All to Device (ZIP)
      expect(find.text('Save All to Device (ZIP)'), findsOneWidget);
      // Secondary provides individual save
      expect(find.text('Save All Files'), findsOneWidget);
    });
  });

  group('Free Limits & Monetization Across All 13 Tools', () {
    late FreeUsageManager usageManager;

    setUp(() {
      usageManager = FreeUsageManager(testPrefs);
    });

    test('All 13 tools have exact production free & rewarded limits configured', () {
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

    test('Temporary rewarded capacity is operation-scoped and resets after operation', () {
      // 1. Within free limit (3 PDFs)
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 3, isPro: false).isAllowed, isTrue);

      // 2. Over free limit (5 PDFs) -> Blocked
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 5, isPro: false).isAllowed, isFalse);

      // 3. User watches rewarded ad -> Temporary capacity granted
      usageManager.grantTemporaryReward(ToolFeature.pdfMerge);
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 5, isPro: false).isAllowed, isTrue);

      // 4. Operation completes -> Consume reward
      usageManager.consumeReward(ToolFeature.pdfMerge);

      // 5. Subsequent operation returns to baseline free limit (5 PDFs is blocked again)
      expect(usageManager.checkLimit(feature: ToolFeature.pdfMerge, requestedAmount: 5, isPro: false).isAllowed, isFalse);
    });

    test('Premium user bypasses limits for all 13 tools without rewarded ads', () {
      for (final tool in ToolFeature.values) {
        final hugeAmount = 99999999;
        final res = usageManager.checkLimit(feature: tool, requestedAmount: hugeAmount, isPro: true);
        expect(res.isAllowed, isTrue);
        expect(res.isPro, isTrue);
      }
    });
  });

  group('Offline Monetization & Limit UI Tests', () {
    testWidgets('Offline user over limit sees clear offline message and Connect / Try Again button', (tester) async {
      mockAdService.networkAvailable = false;

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

      // Verification of offline message
      expect(find.text('Free Limit Reached'), findsOneWidget);
      expect(find.textContaining("You're currently offline, so a rewarded ad isn't available."), findsOneWidget);
      expect(find.text('Connect / Try Again'), findsOneWidget);
      expect(find.text('Go Premium (Unlimited & Ad-Free)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Watch Ad & Continue'), findsNothing);

      // Tap Connect / Try Again when network restores
      mockAdService.networkAvailable = true;
      await tester.tap(find.text('Connect / Try Again'));
      await tester.pumpAndSettle();

      // Online view restored with Watch Ad button
      expect(find.text('Watch Ad & Continue'), findsOneWidget);
    });
  });

  group('Centralized Interstitial Ad Policy Tests', () {
    test('AdConfig parameters match monetization policy', () {
      expect(AdConfig.interstitialCooldown.inSeconds, anyOf(45, 60));
      expect(AdConfig.maxActionsBetweenInterstitials, 2);
      expect(AdConfig.interstitialEnabled, isTrue);
    });

    test('AdService records transitions and respects Pro bypass', () async {
      final adService = TestAdService();
      adService.updateProStatus(true);
      expect(await adService.maybeShowTransitionInterstitial(point: AdTransitionPoint.processingComplete), isFalse);
      expect(adService.interstitialCount, 0);

      adService.updateProStatus(false);
      expect(await adService.maybeShowTransitionInterstitial(point: AdTransitionPoint.saveToDeviceComplete), isTrue);
      expect(adService.interstitialCount, 1);
      expect(adService.recordedActions, contains(AdTransitionPoint.saveToDeviceComplete));
    });
  });
}
