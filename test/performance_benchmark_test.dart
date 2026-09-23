import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:filekit/features/pdf/services/local_pdf_service.dart';
import 'package:filekit/features/image/services/local_image_service.dart';
import 'package:filekit/features/file_tools/services/zip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalPdfService pdfService;
  late LocalImageService imageService;
  late ZipService zipService;

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fileworks_perf_');
    pdfService = LocalPdfService();
    imageService = LocalImageService();
    zipService = ZipService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Empirical Performance Benchmarks', () {
    test('PERF-001: PDF Creation & Page Extraction Benchmark', () async {
      final doc = PdfDocument();
      for (int i = 0; i < 20; i++) {
        doc.pages.add().graphics.drawString('Test Page $i', PdfStandardFont(PdfFontFamily.helvetica, 14));
      }
      final pdfFile = File(p.join(tempDir.path, 'benchmark_20p.pdf'))
        ..writeAsBytesSync(doc.saveSync(), flush: true);
      doc.dispose();

      final stopwatch = Stopwatch()..start();
      final pageCount = await pdfService.getPageCount(pdfFile);
      stopwatch.stop();

      expect(pageCount, equals(20));
      print('PERF-METRIC: PDF_20P_READ_MS=${stopwatch.elapsedMilliseconds}');
    });

    test('PERF-002: Image Compression Benchmark', () async {
      final image = img.Image(width: 1920, height: 1080);
      img.fill(image, color: img.ColorRgb8(100, 150, 200));
      final rawJpeg = img.encodeJpg(image, quality: 100);

      final sampleFile = File(p.join(tempDir.path, 'benchmark_1080p.jpg'))
        ..writeAsBytesSync(rawJpeg, flush: true);

      final stopwatch = Stopwatch()..start();
      final compressed = await imageService.compressImage(sampleFile, 70, 'bench_out.jpg');
      stopwatch.stop();

      expect(compressed.existsSync(), isTrue);
      print('PERF-METRIC: IMG_1080P_COMPRESS_MS=${stopwatch.elapsedMilliseconds}');
      print('PERF-METRIC: IMG_INPUT_BYTES=${sampleFile.lengthSync()}');
      print('PERF-METRIC: IMG_OUTPUT_BYTES=${compressed.lengthSync()}');
    });

    test('PERF-003: ZIP Archive Create & Extract Benchmark', () async {
      final filesToZip = <File>[];
      for (int i = 0; i < 10; i++) {
        final f = File(p.join(tempDir.path, 'file_$i.txt'))
          ..writeAsStringSync('Sample text content repeated for file $i ' * 100);
        filesToZip.add(f);
      }

      final stopwatchCreate = Stopwatch()..start();
      final zipFile = await zipService.createZip(filesToZip, 'benchmark.zip');
      stopwatchCreate.stop();

      final stopwatchExtract = Stopwatch()..start();
      final extracted = await zipService.extractZip(zipFile);
      stopwatchExtract.stop();

      expect(extracted.length, equals(10));
      print('PERF-METRIC: ZIP_CREATE_MS=${stopwatchCreate.elapsedMilliseconds}');
      print('PERF-METRIC: ZIP_EXTRACT_MS=${stopwatchExtract.elapsedMilliseconds}');
    });
  });
}
