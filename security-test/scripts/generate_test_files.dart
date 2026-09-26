import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';

void main() async {
  final outDir = Directory('security-test/generated-files');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // 1. PDF 1: 3-page document
  final pdf1 = pw.Document();
  for (int i = 1; i <= 3; i++) {
    pdf1.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text('Document 1 - Page $i\nCanary: FILEWORKS_SECURITY_CANARY_9F73A2',
              style: pw.TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
  final filePdf1 = File('${outDir.path}/test_doc1.pdf');
  await filePdf1.writeAsBytes(await pdf1.save());
  print('Generated ${filePdf1.path} (${filePdf1.lengthSync()} bytes)');

  // 2. PDF 2: 2-page document
  final pdf2 = pw.Document();
  for (int i = 1; i <= 2; i++) {
    pdf2.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text('Document 2 - Page $i', style: pw.TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
  final filePdf2 = File('${outDir.path}/test_doc2.pdf');
  await filePdf2.writeAsBytes(await pdf2.save());
  print('Generated ${filePdf2.path} (${filePdf2.lengthSync()} bytes)');

  // 3. Image 1: JPG
  final image = img.Image(width: 800, height: 600);
  img.fill(image, color: img.ColorRgb8(255, 100, 50));
  final jpgBytes = img.encodeJpg(image, quality: 90);
  final fileJpg = File('${outDir.path}/sample_photo.jpg');
  await fileJpg.writeAsBytes(jpgBytes);
  print('Generated ${fileJpg.path} (${fileJpg.lengthSync()} bytes)');

  // 4. Image 2: PNG
  final pngBytes = img.encodePng(image);
  final filePng = File('${outDir.path}/sample_image.png');
  await filePng.writeAsBytes(pngBytes);
  print('Generated ${filePng.path} (${filePng.lengthSync()} bytes)');

  // 5. Normal ZIP
  final archive = Archive();
  archive.addFile(ArchiveFile('hello.txt', 12, 'Hello World!'.codeUnits));
  archive.addFile(ArchiveFile('nested/data.txt', 18, 'Nested File Data!!'.codeUnits));
  final zipBytes = ZipEncoder().encode(archive);
  final fileZip = File('${outDir.path}/normal_archive.zip');
  await fileZip.writeAsBytes(zipBytes!);
  print('Generated ${fileZip.path} (${fileZip.lengthSync()} bytes)');

  // 6. Zip-Slip Malicious Archive
  final maliciousArchive = Archive();
  maliciousArchive.addFile(ArchiveFile('../../evil.txt', 16, 'Malicious payload'.codeUnits));
  maliciousArchive.addFile(ArchiveFile('../../../tmp/test.txt', 14, 'Path traversal'.codeUnits));
  maliciousArchive.addFile(ArchiveFile(r'..\..\evil_win.txt', 17, 'Windows traversal'.codeUnits));
  maliciousArchive.addFile(ArchiveFile('/absolute/path.txt', 16, 'Absolute payload'.codeUnits));
  final maliciousZipBytes = ZipEncoder().encode(maliciousArchive);
  final fileMaliciousZip = File('${outDir.path}/zip_slip_exploit.zip');
  await fileMaliciousZip.writeAsBytes(maliciousZipBytes!);
  print('Generated ${fileMaliciousZip.path} (${fileMaliciousZip.lengthSync()} bytes)');

  // 7. Empty ZIP & Corrupt ZIP
  final fileEmptyZip = File('${outDir.path}/empty.zip');
  await fileEmptyZip.writeAsBytes([]);
  final fileCorruptZip = File('${outDir.path}/corrupt.zip');
  await fileCorruptZip.writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0xFF, 0xFF]);

  // 8. Text file with canary
  final fileCanary = File('${outDir.path}/security_canary.txt');
  await fileCanary.writeAsString('FILEWORKS_SECURITY_CANARY_9F73A2\nConfidential local test data');

  print('All test assets generated successfully!');
}
