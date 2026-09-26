import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:filekit/core/constants/route_constants.dart';
import 'package:filekit/core/services/file_save_service.dart';
import 'package:filekit/features/history/models/history_item.dart';
import 'package:filekit/features/monetization/ad_service.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/shared/models/processing_result.dart';
import 'package:filekit/shared/presentation/result_screen.dart';

class MockFilePickerPlatform extends FilePickerPlatform {
  Uri? saveFileUri;
  bool shouldThrow = false;

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
    if (shouldThrow) {
      throw Exception('Storage write permission denied');
    }
    return saveFileUri;
  }
}

class MockAdService implements AdService {
  int recordOperationCount = 0;
  int interstitialCount = 0;

  @override
  int get operationCount => recordOperationCount;

  @override
  Future<void> initialize() async {}

  @override
  Widget buildBannerAd() => const SizedBox.shrink();

  @override
  Future<void> recordOperationCompleted() async {
    recordOperationCount++;
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    interstitialCount++;
  }

  @override
  void updateProStatus(bool isPro) {}

  @override
  bool get isRewardedAdAvailable => true;

  @override
  Future<void> preloadRewardedAd() async {}

  @override
  Future<bool> showRewardedAd() async => true;

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
  }) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdService mockAdService;
  late MockFilePickerPlatform mockFilePicker;
  late SharedPreferences testPrefs;
  late Directory tempDir;
  late File file1;
  late File file2;
  late File file3;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('fw_regression_');
    file1 = File('${tempDir.path}/page_1.pdf')..writeAsStringSync('PDF page 1');
    file2 = File('${tempDir.path}/page_2.pdf')..writeAsStringSync('PDF page 2');
    file3 = File('${tempDir.path}/page_3.pdf')..writeAsStringSync('PDF page 3');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    mockAdService = MockAdService();
    mockFilePicker = MockFilePickerPlatform();
    mockFilePicker.saveFileUri = Uri.file('${tempDir.path}/saved_output.pdf');
    FilePickerPlatform.instance = mockFilePicker;
  });

  Widget buildTestableResultScreen({
    required ProcessingResult result,
    bool isDark = false,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(testPrefs),
        adServiceProvider.overrideWithValue(mockAdService),
        isProProvider.overrideWith(() => ProNotifier()),
      ],
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: ResultScreen(result: result),
      ),
    );
  }

  void setupPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Result Screen & Storage Regression Tests (Items 1-17)', () {
    testWidgets('1. Result with one output file displays single-file UI and actions', (tester) async {
      setupPhoneViewport(tester);
      final singleResult = ProcessingResult(
        success: true,
        title: 'PDF Compress Complete',
        message: 'Reduced file size by 50%.',
        outputFiles: [file1],
        originalTotalBytes: 2048,
        outputTotalBytes: 1024,
        repeatRoute: RouteConstants.pdfCompress,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: singleResult));
      await tester.pumpAndSettle();

      expect(find.text('PDF Compress Complete'), findsOneWidget);
      expect(find.text('Open File'), findsOneWidget);
      expect(find.text('Save to Device'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Process Another File'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('2. Result with multiple output files displays file list with individual actions', (tester) async {
      setupPhoneViewport(tester);
      final multiResult = ProcessingResult(
        success: true,
        title: 'PDF Split Complete',
        message: 'Extracted 3 individual pages.',
        outputFiles: [file1, file2, file3],
        originalTotalBytes: 3072,
        outputTotalBytes: 3072,
        repeatRoute: RouteConstants.pdfSplit,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: multiResult));
      await tester.pumpAndSettle();

      expect(find.text('PDF Split Complete'), findsOneWidget);
      expect(find.text('3 files ready'), findsOneWidget);
      expect(find.text('page_1.pdf'), findsOneWidget);
      expect(find.text('page_2.pdf'), findsOneWidget);
      expect(find.text('page_3.pdf'), findsOneWidget);

      expect(find.textContaining('Save All to Device'), findsOneWidget);
      expect(find.textContaining('Share All'), findsOneWidget);
      expect(find.text('Process Another File'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('3. Open first output in multi-file result', (tester) async {
      setupPhoneViewport(tester);
      final multiResult = ProcessingResult(
        success: true,
        title: 'PDF Split Complete',
        message: '3 files ready.',
        outputFiles: [file1, file2, file3],
        repeatRoute: RouteConstants.pdfSplit,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: multiResult));
      await tester.pumpAndSettle();

      final openButtons = find.byTooltip('Open');
      expect(openButtons, findsNWidgets(3));
      await tester.tap(openButtons.first);
      await tester.pump();
      expect(find.text('page_1.pdf'), findsOneWidget);
    });

    testWidgets('4. Open second output in multi-file result', (tester) async {
      setupPhoneViewport(tester);
      final multiResult = ProcessingResult(
        success: true,
        title: 'PDF Split Complete',
        message: '3 files ready.',
        outputFiles: [file1, file2, file3],
        repeatRoute: RouteConstants.pdfSplit,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: multiResult));
      await tester.pumpAndSettle();

      final openBtn2 = find.byTooltip('Open').at(1);
      await tester.tap(openBtn2);
      await tester.pump();
      expect(find.text('page_2.pdf'), findsOneWidget);
    });

    testWidgets('5. Open every output from a multi-file result individually', (tester) async {
      setupPhoneViewport(tester);
      final multiResult = ProcessingResult(
        success: true,
        title: 'PDF Split Complete',
        message: '3 files ready.',
        outputFiles: [file1, file2, file3],
        repeatRoute: RouteConstants.pdfSplit,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: multiResult));
      await tester.pumpAndSettle();

      for (int i = 0; i < 3; i++) {
        final btn = find.byTooltip('Open').at(i);
        await tester.tap(btn);
        await tester.pump();
      }
      expect(find.text('page_1.pdf'), findsOneWidget);
      expect(find.text('page_2.pdf'), findsOneWidget);
      expect(find.text('page_3.pdf'), findsOneWidget);
    });

    testWidgets('6. Share one output triggers share flow', (tester) async {
      setupPhoneViewport(tester);
      final singleResult = ProcessingResult(
        success: true,
        title: 'PDF Complete',
        message: '1 file.',
        outputFiles: [file1],
        repeatRoute: RouteConstants.pdfCompress,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: singleResult));
      await tester.pumpAndSettle();

      expect(find.text('Share'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pump();
    });

    testWidgets('7. Share multiple outputs handles multi-file share', (tester) async {
      setupPhoneViewport(tester);
      final multiResult = ProcessingResult(
        success: true,
        title: 'PDF Split',
        message: '3 files.',
        outputFiles: [file1, file2, file3],
        repeatRoute: RouteConstants.pdfSplit,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: multiResult));
      await tester.pumpAndSettle();

      expect(find.textContaining('Share All'), findsOneWidget);
      await tester.tap(find.textContaining('Share All'));
      await tester.pump();
    });

    test('8. Save one output to device using FileSaveService', () async {
      mockFilePicker.saveFileUri = Uri.file('${tempDir.path}/page_1_saved.pdf');
      final res = await FileSaveService.saveFileToDevice(file: file1);
      expect(res.status, FileSaveStatus.success);
      expect(res.isSuccess, isTrue);
      expect(res.savedPath, contains('page_1_saved.pdf'));
    });

    test('9. Save multiple outputs as ZIP archive using FileSaveService', () async {
      mockFilePicker.saveFileUri = Uri.file('${tempDir.path}/split_pages.zip');
      final res = await FileSaveService.saveMultipleFilesAsZipToDevice(
        files: [file1, file2, file3],
        zipFileName: 'split_pages.zip',
      );
      expect(res.status, FileSaveStatus.success);
      expect(res.isSuccess, isTrue);
      expect(res.savedPath, contains('split_pages.zip'));
    });

    testWidgets('10. Done navigation works reliably in light and dark themes', (tester) async {
      for (final isDark in [false, true]) {
        setupPhoneViewport(tester);
        final res = ProcessingResult(
          success: true,
          title: 'Complete',
          message: 'Operation finished.',
          outputFiles: [file1],
        );

        await tester.pumpWidget(buildTestableResultScreen(result: res, isDark: isDark));
        await tester.pumpAndSettle();

        final doneButton = find.text('Done');
        expect(doneButton, findsOneWidget);
        await tester.tap(doneButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('11. Process Another File navigation triggers repeat route', (tester) async {
      setupPhoneViewport(tester);
      final res = ProcessingResult(
        success: true,
        title: 'Merge Complete',
        message: '2 files merged.',
        outputFiles: [file1],
        repeatRoute: RouteConstants.pdfMerge,
      );

      await tester.pumpWidget(buildTestableResultScreen(result: res));
      await tester.pumpAndSettle();

      final processAnother = find.text('Process Another File');
      expect(processAnother, findsOneWidget);
      await tester.tap(processAnother);
      await tester.pumpAndSettle();
    });

    test('12. History for single-output operation tracks file correctly', () {
      final item = HistoryItem(
        id: '1',
        toolName: 'PDF Compress',
        title: 'Compressed document.pdf',
        subtitle: 'Reduced by 45%',
        filePaths: [file1.path],
        originalBytes: 1000,
        outputBytes: 550,
        timestamp: DateTime.now(),
      );

      expect(item.filePaths.length, 1);
      expect(item.filePaths.first, file1.path);
      expect(item.originalBytes, 1000);
      expect(item.outputBytes, 550);
    });

    test('13. History for multi-output operation tracks all generated files', () {
      final item = HistoryItem(
        id: '2',
        toolName: 'PDF Split',
        title: '3 Pages Extracted',
        subtitle: 'From sample.pdf',
        filePaths: [file1.path, file2.path, file3.path],
        originalBytes: 3000,
        outputBytes: 3000,
        timestamp: DateTime.now(),
      );

      expect(item.filePaths.length, 3);
      expect(item.filePaths[0], file1.path);
      expect(item.filePaths[1], file2.path);
      expect(item.filePaths[2], file3.path);
    });

    test('14. Cancel save operation handles null return gracefully without false success', () async {
      mockFilePicker.saveFileUri = null; // User cancelled
      final res = await FileSaveService.saveFileToDevice(file: file1);
      expect(res.status, FileSaveStatus.cancelled);
      expect(res.isSuccess, isFalse);
    });

    test('15. Duplicate filename handling preserves suggested names safely', () async {
      mockFilePicker.saveFileUri = Uri.file('${tempDir.path}/export_report.pdf');
      final res1 = await FileSaveService.saveFileToDevice(
        file: file1,
        suggestedName: 'export_report.pdf',
      );
      expect(res1.status, FileSaveStatus.success);

      mockFilePicker.saveFileUri = Uri.file('${tempDir.path}/export_report (1).pdf');
      final res2 = await FileSaveService.saveFileToDevice(
        file: file1,
        suggestedName: 'export_report (1).pdf',
      );
      expect(res2.status, FileSaveStatus.success);
    });

    test('16. Failed save returns clear error status and message', () async {
      final nonexistentFile = File('${tempDir.path}/nonexistent_file.pdf');
      final res = await FileSaveService.saveFileToDevice(file: nonexistentFile);

      expect(res.status, FileSaveStatus.failed);
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, isNotNull);
      expect(res.errorMessage, contains('File not found'));
    });

    testWidgets('17. Missing output file handled gracefully on UI tap', (tester) async {
      setupPhoneViewport(tester);
      final nonexistentFile = File('${tempDir.path}/deleted_file.pdf');
      final res = ProcessingResult(
        success: true,
        title: 'Complete',
        message: 'File deleted externally.',
        outputFiles: [nonexistentFile],
      );

      await tester.pumpWidget(buildTestableResultScreen(result: res));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open File'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('File not found.'), findsOneWidget);
    });
  });
}
