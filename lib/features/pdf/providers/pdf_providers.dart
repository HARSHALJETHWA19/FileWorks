import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_pdf_service.dart';
import '../services/pdf_service.dart';

final pdfServiceProvider = Provider<PdfService>((ref) {
  return LocalPdfService();
});
