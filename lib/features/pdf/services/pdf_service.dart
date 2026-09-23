import 'dart:io';
import '../models/pdf_models.dart';

abstract class PdfService {
  /// Merges multiple PDF files in order into a single output file
  Future<File> mergePdfs(List<File> pdfFiles, String outputFileName);

  /// Splits a PDF file based on the given page numbers (1-indexed) into separate PDFs
  Future<List<File>> splitPdf(File pdfFile, List<int> pageNumbers, String baseName);

  /// Rotates specific pages or all pages of a PDF
  Future<File> rotatePdf(File pdfFile, Map<int, int> pageRotations, String outputFileName);

  /// Reorders pages of a PDF based on the new page order list (1-indexed page indices)
  Future<File> reorderPdf(File pdfFile, List<int> newPageOrder, String outputFileName);

  /// Compresses a PDF by reducing embedded stream quality
  Future<File> compressPdf(File pdfFile, PdfCompressQuality quality, String outputFileName);

  /// Converts PDF pages to JPG or PNG images
  Future<List<File>> pdfToImages(
    File pdfFile, {
    required List<int> pages,
    required bool isPng,
    required int quality,
    void Function(int current, int total)? onProgress,
  });

  /// Converts a list of image files to a single PDF
  Future<File> imagesToPdf(
    List<File> imageFiles,
    ImageToPdfOptions options,
    String outputFileName,
  );

  /// Retrieves the total page count of a PDF file
  Future<int> getPageCount(File pdfFile);
}
