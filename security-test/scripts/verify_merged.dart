import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final file = File('security-test/evidence/merged_document.pdf');
  final doc = PdfLoadedDocument(file.readAsBytesSync());
  print('MERGED_PAGE_COUNT: ${doc.pages.count}');
  doc.close();
}
