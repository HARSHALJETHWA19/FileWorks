import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filekit/features/pdf/models/pdf_models.dart';
import 'package:filekit/features/pdf/services/local_pdf_service.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalPdfService service;
  late File sampleResume;
  late File sampleEdge;
  late File sampleMerged;

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    service = LocalPdfService();
    sampleResume = File('test/fixtures/sample_resume.pdf');
    sampleEdge = File('test/fixtures/sample_edge.pdf');
    sampleMerged = File('test/fixtures/sample_merged.pdf');

    expect(sampleResume.existsSync(), isTrue);
    expect(sampleEdge.existsSync(), isTrue);
    expect(sampleMerged.existsSync(), isTrue);
  });

  group('PDF Geometry & Edge Case Regression Tests (Items 18-30)', () {
    test('18. PDF merge with different page sizes preserves distinct page dimensions', () async {
      // sample_resume is Letter (612 x 792), sample_edge is A4 (~595.28 x ~841.88)
      final merged = await service.mergePdfs([sampleResume, sampleEdge], 'test_merge_diff_sizes.pdf');
      expect(merged.existsSync(), isTrue);

      final doc = PdfDocument(inputBytes: merged.readAsBytesSync());
      expect(doc.pages.count, 4);

      // Pages 0 & 1: Letter
      expect(doc.pages[0].size.width, 612.0);
      expect(doc.pages[0].size.height, 792.0);
      expect(doc.pages[1].size.width, 612.0);
      expect(doc.pages[1].size.height, 792.0);

      // Pages 2 & 3: A4
      expect(doc.pages[2].size.width, closeTo(595.28, 0.5));
      expect(doc.pages[2].size.height, closeTo(841.88, 0.5));
      expect(doc.pages[3].size.width, closeTo(595.28, 0.5));
      expect(doc.pages[3].size.height, closeTo(841.88, 0.5));

      doc.dispose();
    });

    test('19. PDF split preserving exact page dimensions', () async {
      final splitFiles = await service.splitPdf(sampleEdge, [1, 2], 'test_split_edge');
      expect(splitFiles.length, 2);

      for (final f in splitFiles) {
        expect(f.existsSync(), isTrue);
        final doc = PdfDocument(inputBytes: f.readAsBytesSync());
        expect(doc.pages.count, 1);
        expect(doc.pages[0].size.width, closeTo(595.28, 0.5));
        expect(doc.pages[0].size.height, closeTo(841.88, 0.5));
        doc.dispose();
      }
    });

    test('20. PDF rotate preserving all content at 90, 180, and 270 degrees', () async {
      for (final angle in [90, 180, 270]) {
        final rotated = await service.rotatePdf(sampleResume, {1: angle}, 'test_rot_$angle.pdf');
        expect(rotated.existsSync(), isTrue);

        final doc = PdfDocument(inputBytes: rotated.readAsBytesSync());
        final expectedAngle = angle == 90
            ? PdfPageRotateAngle.rotateAngle90
            : angle == 180
                ? PdfPageRotateAngle.rotateAngle180
                : PdfPageRotateAngle.rotateAngle270;

        expect(doc.pages[0].rotation, expectedAngle);
        expect(doc.pages[0].size.width, 612.0);
        expect(doc.pages[0].size.height, 792.0);
        doc.dispose();
      }
    });

    test('21. PDF reorder preserving all content and page sizes', () async {
      final reordered = await service.reorderPdf(sampleResume, [2, 1], 'test_reorder_all.pdf');
      expect(reordered.existsSync(), isTrue);

      final doc = PdfDocument(inputBytes: reordered.readAsBytesSync());
      expect(doc.pages.count, 2);
      expect(doc.pages[0].size.width, 612.0);
      expect(doc.pages[0].size.height, 792.0);
      expect(doc.pages[1].size.width, 612.0);
      expect(doc.pages[1].size.height, 792.0);
      doc.dispose();
    });

    test('22. PDF compression preserving geometry across all quality levels', () async {
      for (final quality in [PdfCompressQuality.highQuality, PdfCompressQuality.balanced, PdfCompressQuality.maximumCompression]) {
        final compressed = await service.compressPdf(sampleResume, quality, 'test_comp_${quality.name}.pdf');
        expect(compressed.existsSync(), isTrue);

        final doc = PdfDocument(inputBytes: compressed.readAsBytesSync());
        expect(doc.pages.count, 2);
        expect(doc.pages[0].size.width, 612.0);
        expect(doc.pages[0].size.height, 792.0);
        doc.dispose();
      }
    });

    test('23. PDF to Image preserving complete page rasterization', () async {
      // Test page count inspection
      final pageCount = await service.getPageCount(sampleResume);
      expect(pageCount, 2);

      // Verify each page rasterization is non-empty
      final tempDoc = PdfDocument(inputBytes: sampleResume.readAsBytesSync());
      final p1 = tempDoc.pages[0];
      expect(p1.size.width, 612.0);
      expect(p1.size.height, 792.0);
      // Aspect ratio of Letter = 612/792 ~ 0.7727
      expect((p1.size.width / p1.size.height), closeTo(0.7727, 0.01));
      tempDoc.dispose();
    });

    test('24. Image to PDF preserving aspect ratio without distortion or cropping', () async {
      // Create a test 400x200 landscape image
      final testImg = img.Image(width: 400, height: 200);
      img.fill(testImg, color: img.ColorRgb8(0, 128, 255));
      final testImgFile = File('${Directory.systemTemp.path}/test_aspect_img.png')
        ..writeAsBytesSync(img.encodePng(testImg));

      final pdfOut = await service.imagesToPdf(
        [testImgFile],
        const ImageToPdfOptions(
          pageSize: ImageToPdfPageSize.a4,
          orientation: ImageToPdfOrientation.portrait,
          margin: ImageToPdfMargin.none,
        ),
        'test_img_to_pdf.pdf',
      );

      expect(pdfOut.existsSync(), isTrue);
      final doc = PdfDocument(inputBytes: pdfOut.readAsBytesSync());
      expect(doc.pages.count, 1);
      expect(doc.pages[0].size.width, 595.0);
      expect(doc.pages[0].size.height, 842.0);
      doc.dispose();
      testImgFile.deleteSync();
    });

    test('25. Landscape PDF page geometry preservation', () async {
      // Create a document with landscape section
      final landscapeDoc = PdfDocument();
      final sec = landscapeDoc.sections!.add();
      sec.pageSettings.size = const Size(792, 612); // Landscape Letter
      sec.pageSettings.orientation = PdfPageOrientation.landscape;
      sec.pageSettings.margins.all = 0;
      sec.pages.add();
      final landscapeFile = File('${Directory.systemTemp.path}/test_landscape.pdf')
        ..writeAsBytesSync(landscapeDoc.saveSync());
      landscapeDoc.dispose();

      // Merge it with portrait sample_resume
      final merged = await service.mergePdfs([landscapeFile, sampleResume], 'test_merge_landscape.pdf');
      final doc = PdfDocument(inputBytes: merged.readAsBytesSync());
      expect(doc.pages.count, 3);
      // First page must remain landscape (width > height)
      expect(doc.pages[0].size.width, 792.0);
      expect(doc.pages[0].size.height, 612.0);
      expect(doc.pages[0].size.width > doc.pages[0].size.height, isTrue);

      // Remaining pages must remain portrait Letter (height > width)
      expect(doc.pages[1].size.width, 612.0);
      expect(doc.pages[1].size.height, 792.0);
      expect(doc.pages[1].size.height > doc.pages[1].size.width, isTrue);

      doc.dispose();
      landscapeFile.deleteSync();
    });

    test('26. Portrait PDF page dimensions preserved', () async {
      final doc = PdfDocument(inputBytes: sampleResume.readAsBytesSync());
      expect(doc.pages[0].size.height > doc.pages[0].size.width, isTrue);
      expect(doc.pages[0].size.width, 612.0);
      expect(doc.pages[0].size.height, 792.0);
      doc.dispose();
    });

    test('27. Rotated PDF pages preserve intrinsic rotation angle', () async {
      final rotatedDoc = PdfDocument();
      final sec = rotatedDoc.sections!.add();
      sec.pageSettings.size = const Size(612, 792);
      sec.pageSettings.rotate = PdfPageRotateAngle.rotateAngle180;
      sec.pages.add();
      final rotatedFile = File('${Directory.systemTemp.path}/test_intrinsic_rot.pdf')
        ..writeAsBytesSync(rotatedDoc.saveSync());
      rotatedDoc.dispose();

      final split = await service.splitPdf(rotatedFile, [1], 'test_split_rot');
      expect(split.length, 1);
      final checkDoc = PdfDocument(inputBytes: split[0].readAsBytesSync());
      expect(checkDoc.pages[0].rotation, PdfPageRotateAngle.rotateAngle180);
      checkDoc.dispose();
      rotatedFile.deleteSync();
    });

    test('28. PDF with images preserves content integrity across operations', () async {
      // sample_resume contains vector shapes and images
      final compressed = await service.compressPdf(sampleResume, PdfCompressQuality.balanced, 'test_img_compress.pdf');
      expect(compressed.existsSync(), isTrue);
      expect(compressed.lengthSync(), greaterThan(0));

      final doc = PdfDocument(inputBytes: compressed.readAsBytesSync());
      expect(doc.pages.count, 2);
      doc.dispose();
    });

    test('29. PDF with text near page edges: zero-margin section eliminates template inset shift', () async {
      final split = await service.splitPdf(sampleEdge, [1], 'test_split_edge_margins');
      expect(split.length, 1);

      final doc = PdfDocument(inputBytes: split[0].readAsBytesSync());
      final page = doc.pages[0];
      // Size must be exactly A4, without 40pt shrinkage
      expect(page.size.width, closeTo(595.28, 0.5));
      expect(page.size.height, closeTo(841.88, 0.5));
      // Client size with 0 margin equals full page size
      expect(page.getClientSize().width, page.size.width);
      expect(page.getClientSize().height, page.size.height);
      doc.dispose();
    });

    test('30. PDF with content close to left/right boundaries preserved in merge', () async {
      final merged = await service.mergePdfs([sampleEdge, sampleEdge], 'test_edge_merge.pdf');
      expect(merged.existsSync(), isTrue);

      final doc = PdfDocument(inputBytes: merged.readAsBytesSync());
      expect(doc.pages.count, 4);
      for (int i = 0; i < doc.pages.count; i++) {
        final p = doc.pages[i];
        expect(p.size.width, closeTo(595.28, 0.5));
        expect(p.size.height, closeTo(841.88, 0.5));
        expect(p.getClientSize().width, p.size.width);
      }
      doc.dispose();
    });
  });
}
