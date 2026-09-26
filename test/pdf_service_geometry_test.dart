import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filekit/features/pdf/models/pdf_models.dart';
import 'package:filekit/features/pdf/services/local_pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalPdfService service;

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });
    service = LocalPdfService();
  });

  test('mergePdfs preserves exact dimensions of mixed size PDFs without cropping', () async {
    final resume = File('test/fixtures/sample_resume.pdf');
    final edge = File('test/fixtures/sample_edge.pdf');

    final merged = await service.mergePdfs([resume, edge], 'merged_preservation_test.pdf');
    expect(merged.existsSync(), isTrue);

    final doc = PdfDocument(inputBytes: merged.readAsBytesSync());
    expect(doc.pages.count, 4);

    // First 2 pages from resume: Letter size (612 x 792)
    expect(doc.pages[0].size.width, 612.0);
    expect(doc.pages[0].size.height, 792.0);
    expect(doc.pages[1].size.width, 612.0);
    expect(doc.pages[1].size.height, 792.0);

    // Next 2 pages from edge: A4 size (~595.28 x ~841.88)
    expect(doc.pages[2].size.width, closeTo(595.28, 0.5));
    expect(doc.pages[2].size.height, closeTo(841.88, 0.5));
    expect(doc.pages[3].size.width, closeTo(595.28, 0.5));
    expect(doc.pages[3].size.height, closeTo(841.88, 0.5));

    doc.dispose();
  });

  test('splitPdf preserves exact dimensions of original page without cropping', () async {
    final resume = File('test/fixtures/sample_resume.pdf');
    final splitFiles = await service.splitPdf(resume, [1, 2], 'split_geo_test');

    expect(splitFiles.length, 2);
    for (final f in splitFiles) {
      expect(f.existsSync(), isTrue);
      final doc = PdfDocument(inputBytes: f.readAsBytesSync());
      expect(doc.pages.count, 1);
      expect(doc.pages[0].size.width, 612.0);
      expect(doc.pages[0].size.height, 792.0);
      doc.dispose();
    }
  });

  test('reorderPdf preserves exact dimensions of original pages', () async {
    final resume = File('test/fixtures/sample_resume.pdf');
    final reordered = await service.reorderPdf(resume, [2, 1], 'reorder_geo_test.pdf');

    expect(reordered.existsSync(), isTrue);
    final doc = PdfDocument(inputBytes: reordered.readAsBytesSync());
    expect(doc.pages.count, 2);
    expect(doc.pages[0].size.width, 612.0);
    expect(doc.pages[0].size.height, 792.0);
    expect(doc.pages[1].size.width, 612.0);
    expect(doc.pages[1].size.height, 792.0);
    doc.dispose();
  });

  test('compressPdf preserves exact dimensions of original pages', () async {
    final resume = File('test/fixtures/sample_resume.pdf');
    final compressed = await service.compressPdf(resume, PdfCompressQuality.balanced, 'compress_geo_test.pdf');

    expect(compressed.existsSync(), isTrue);
    final doc = PdfDocument(inputBytes: compressed.readAsBytesSync());
    expect(doc.pages.count, 2);
    expect(doc.pages[0].size.width, 612.0);
    expect(doc.pages[0].size.height, 792.0);
    doc.dispose();
  });

  test('rotatePdf preserves exact dimensions with rotation', () async {
    final resume = File('test/fixtures/sample_resume.pdf');
    final rotated = await service.rotatePdf(resume, {1: 90}, 'rotate_geo_test.pdf');

    expect(rotated.existsSync(), isTrue);
    final doc = PdfDocument(inputBytes: rotated.readAsBytesSync());
    expect(doc.pages.count, 2);
    expect(doc.pages[0].rotation, PdfPageRotateAngle.rotateAngle90);
    expect(doc.pages[0].size.width, 612.0);
    expect(doc.pages[0].size.height, 792.0);
    doc.dispose();
  });
}
