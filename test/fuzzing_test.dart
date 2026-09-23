import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:filekit/core/errors/exceptions.dart';
import 'package:filekit/features/pdf/services/local_pdf_service.dart';
import 'package:filekit/features/image/services/local_image_service.dart';
import 'package:filekit/features/file_tools/services/zip_service.dart';

import 'package:flutter/services.dart';

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
    tempDir = Directory.systemTemp.createTempSync('fileworks_fuzz_');
    pdfService = LocalPdfService();
    imageService = LocalImageService();
    zipService = ZipService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Fuzzing & Malformed Input Robustness Tests', () {
    test('FUZZ-PDF-001: 0-byte file passed to getPageCount throws CorruptFileException', () async {
      final zeroByteFile = File(p.join(tempDir.path, 'zero.pdf'))..writeAsBytesSync([]);
      expect(
        () => pdfService.getPageCount(zeroByteFile),
        throwsA(isA<CorruptFileException>()),
      );
    });

    test('FUZZ-PDF-002: Random garbage bytes passed to getPageCount throws CorruptFileException', () async {
      final garbageFile = File(p.join(tempDir.path, 'garbage.pdf'))
        ..writeAsBytesSync([0x00, 0xFF, 0x41, 0x42, 0x43, 0x89, 0x50, 0x4E, 0x47]);
      expect(
        () => pdfService.getPageCount(garbageFile),
        throwsA(isA<CorruptFileException>()),
      );
    });

    test('FUZZ-PDF-003: 0-byte file in mergePdfs throws CorruptFileException', () async {
      final zero1 = File(p.join(tempDir.path, 'zero1.pdf'))..writeAsBytesSync([]);
      final zero2 = File(p.join(tempDir.path, 'zero2.pdf'))..writeAsBytesSync([]);
      expect(
        () => pdfService.mergePdfs([zero1, zero2], 'merged_zero.pdf'),
        throwsA(isA<CorruptFileException>()),
      );
    });

    test('FUZZ-PDF-004: Truncated PDF header throws CorruptFileException', () async {
      final truncated = File(p.join(tempDir.path, 'truncated.pdf'))
        ..writeAsStringSync('%PDF-1.4\n%EOF');
      expect(
        () => pdfService.getPageCount(truncated),
        throwsA(isA<CorruptFileException>()),
      );
    });

    test('FUZZ-IMG-001: 0-byte file passed to getImageDimensions throws UnsupportedFormatException', () async {
      final zeroImg = File(p.join(tempDir.path, 'zero.jpg'))..writeAsBytesSync([]);
      expect(
        () => imageService.getImageDimensions(zeroImg),
        throwsA(isA<UnsupportedFormatException>()),
      );
    });

    test('FUZZ-IMG-002: Text file disguised as JPEG throws UnsupportedFormatException or CorruptFileException', () async {
      final fakeJpg = File(p.join(tempDir.path, 'fake.jpg'))
        ..writeAsStringSync('This is plain text pretending to be an image.');
      expect(
        () => imageService.compressImage(fakeJpg, 80, 'compressed.jpg'),
        throwsA(isA<AppException>()),
      );
    });

    test('FUZZ-ZIP-001: 0-byte file passed to extractZip throws CorruptFileException', () async {
      final zeroZip = File(p.join(tempDir.path, 'zero.zip'))..writeAsBytesSync([]);
      expect(
        () => zipService.extractZip(zeroZip),
        throwsA(isA<CorruptFileException>()),
      );
    });

    test('FUZZ-ZIP-002: Corrupted archive bytes passed to extractZip throws CorruptFileException', () async {
      final corruptZip = File(p.join(tempDir.path, 'corrupt.zip'))
        ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0xDE, 0xAD, 0xBE, 0xEF]);
      expect(
        () => zipService.extractZip(corruptZip),
        throwsA(isA<CorruptFileException>()),
      );
    });
  });
}
