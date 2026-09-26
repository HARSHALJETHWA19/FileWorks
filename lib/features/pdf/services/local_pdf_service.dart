import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as px;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/isolate_helper.dart';
import '../models/pdf_models.dart';
import 'pdf_service.dart';

class LocalPdfService implements PdfService {
  @override
  Future<int> getPageCount(File pdfFile) async {
    return IsolateHelper.run<String, int>(_getPageCountIsolate, pdfFile.path);
  }

  static int _getPageCountIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      final count = document.pages.count;
      document.dispose();
      return count;
    } catch (e) {
      throw CorruptFileException('Failed to read PDF pages: $e');
    }
  }

  @override
  Future<File> mergePdfs(List<File> pdfFiles, String outputFileName) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputFileName);
    final filePaths = pdfFiles.map((f) => f.path).toList();

    return IsolateHelper.run<_MergePdfParams, File>(
      _mergePdfsIsolate,
      _MergePdfParams(filePaths: filePaths, outputPath: outputPath),
    );
  }

  /// Copies a source PDF page to target document while strictly preserving:
  /// - exact physical page dimensions (width & height)
  /// - orientation (portrait vs landscape)
  /// - page rotation
  /// - zero margins (eliminates 40pt default inset coordinate shift and edge cropping)
  static void _copyPagePreservingGeometry(PdfDocument targetDoc, PdfPage sourcePage) {
    final section = targetDoc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = sourcePage.size;
    if (sourcePage.size.width > sourcePage.size.height) {
      section.pageSettings.orientation = PdfPageOrientation.landscape;
    } else {
      section.pageSettings.orientation = PdfPageOrientation.portrait;
    }
    section.pageSettings.rotate = sourcePage.rotation;

    final newPage = section.pages.add();
    final template = sourcePage.createTemplate();
    newPage.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
  }

  static File _mergePdfsIsolate(_MergePdfParams params) {
    try {
      final outputDoc = PdfDocument();

      for (final filePath in params.filePaths) {
        final bytes = File(filePath).readAsBytesSync();
        final loadedDoc = PdfDocument(inputBytes: bytes);

        for (int i = 0; i < loadedDoc.pages.count; i++) {
          final page = loadedDoc.pages[i];
          _copyPagePreservingGeometry(outputDoc, page);
        }
        loadedDoc.dispose();
      }

      final savedBytes = outputDoc.saveSync();
      outputDoc.dispose();

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(savedBytes, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException(
        'Unable to merge selected PDFs. One or more files may be corrupt or encrypted: $e',
      );
    }
  }

  @override
  Future<List<File>> splitPdf(File pdfFile, List<int> pageNumbers, String baseName) async {
    final outDir = await FileUtils.getAppOutputDirectory();
    final cleanBase = FileUtils.sanitizeFilename(baseName);

    return IsolateHelper.run<_SplitPdfParams, List<File>>(
      _splitPdfIsolate,
      _SplitPdfParams(
        filePath: pdfFile.path,
        pageNumbers: pageNumbers,
        outputDir: outDir.path,
        baseName: cleanBase,
      ),
    );
  }

  static List<File> _splitPdfIsolate(_SplitPdfParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      final outputFiles = <File>[];

      for (int i = 0; i < params.pageNumbers.length; i++) {
        final pageNum = params.pageNumbers[i]; // 1-indexed
        final pageIndex = pageNum - 1;

        if (pageIndex < 0 || pageIndex >= loadedDoc.pages.count) {
          continue;
        }

        final singlePageDoc = PdfDocument();
        final page = loadedDoc.pages[pageIndex];
        _copyPagePreservingGeometry(singlePageDoc, page);

        final targetName = '${params.baseName}_page_$pageNum.pdf';
        final targetPath = p.join(params.outputDir, targetName);
        final file = File(targetPath);

        file.writeAsBytesSync(singlePageDoc.saveSync(), flush: true);
        singlePageDoc.dispose();
        outputFiles.add(file);
      }

      loadedDoc.dispose();
      return outputFiles;
    } catch (e) {
      throw CorruptFileException('Failed to split PDF: $e');
    }
  }

  @override
  Future<File> rotatePdf(File pdfFile, Map<int, int> pageRotations, String outputFileName) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputFileName);

    return IsolateHelper.run<_RotatePdfParams, File>(
      _rotatePdfIsolate,
      _RotatePdfParams(
        filePath: pdfFile.path,
        pageRotations: pageRotations,
        outputPath: outputPath,
      ),
    );
  }

  static File _rotatePdfIsolate(_RotatePdfParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      final loadedDoc = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < loadedDoc.pages.count; i++) {
        final pageNum = i + 1;
        final rotation = params.pageRotations[pageNum] ?? 0;

        if (rotation != 0) {
          final page = loadedDoc.pages[i];
          final currentAngle = _rotationToAngle(page.rotation);
          final totalAngle = (currentAngle + rotation) % 360;
          page.rotation = _angleToPdfPageRotateAngle(totalAngle);
        }
      }

      final savedBytes = loadedDoc.saveSync();
      loadedDoc.dispose();

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(savedBytes, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to rotate PDF: $e');
    }
  }

  static int _rotationToAngle(PdfPageRotateAngle angle) {
    switch (angle) {
      case PdfPageRotateAngle.rotateAngle90:
        return 90;
      case PdfPageRotateAngle.rotateAngle180:
        return 180;
      case PdfPageRotateAngle.rotateAngle270:
        return 270;
      case PdfPageRotateAngle.rotateAngle0:
        return 0;
    }
  }

  static PdfPageRotateAngle _angleToPdfPageRotateAngle(int degrees) {
    switch (degrees) {
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  @override
  Future<File> reorderPdf(File pdfFile, List<int> newPageOrder, String outputFileName) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputFileName);

    return IsolateHelper.run<_ReorderPdfParams, File>(
      _reorderPdfIsolate,
      _ReorderPdfParams(
        filePath: pdfFile.path,
        newPageOrder: newPageOrder,
        outputPath: outputPath,
      ),
    );
  }

  static File _reorderPdfIsolate(_ReorderPdfParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      final outputDoc = PdfDocument();

      for (final pageNum in params.newPageOrder) {
        final pageIndex = pageNum - 1;
        if (pageIndex >= 0 && pageIndex < loadedDoc.pages.count) {
          final page = loadedDoc.pages[pageIndex];
          _copyPagePreservingGeometry(outputDoc, page);
        }
      }

      final savedBytes = outputDoc.saveSync();
      outputDoc.dispose();
      loadedDoc.dispose();

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(savedBytes, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to reorder PDF pages: $e');
    }
  }

  @override
  Future<File> compressPdf(File pdfFile, PdfCompressQuality quality, String outputFileName) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputFileName);

    return IsolateHelper.run<_CompressPdfParams, File>(
      _compressPdfIsolate,
      _CompressPdfParams(
        filePath: pdfFile.path,
        quality: quality,
        outputPath: outputPath,
      ),
    );
  }

  static File _compressPdfIsolate(_CompressPdfParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      final loadedDoc = PdfDocument(inputBytes: bytes);

      // Configure compression level and cross reference streams
      loadedDoc.compressionLevel = PdfCompressionLevel.best;
      loadedDoc.fileStructure.crossReferenceType = PdfCrossReferenceType.crossReferenceStream;

      final savedBytes = loadedDoc.saveSync();
      loadedDoc.dispose();

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(savedBytes, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to compress PDF: $e');
    }
  }

  @override
  Future<File> imagesToPdf(
    List<File> imageFiles,
    ImageToPdfOptions options,
    String outputFileName,
  ) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputFileName);
    final imagePaths = imageFiles.map((f) => f.path).toList();

    return IsolateHelper.run<_ImagesToPdfParams, File>(
      _imagesToPdfIsolate,
      _ImagesToPdfParams(
        imagePaths: imagePaths,
        options: options,
        outputPath: outputPath,
      ),
    );
  }

  static File _imagesToPdfIsolate(_ImagesToPdfParams params) {
    try {
      final document = PdfDocument();

      for (final imgPath in params.imagePaths) {
        final imageBytes = File(imgPath).readAsBytesSync();
        final bitmap = PdfBitmap(imageBytes);

        ui.Size pageSize;
        switch (params.options.pageSize) {
          case ImageToPdfPageSize.letter:
            pageSize = const ui.Size(612, 792);
            break;
          case ImageToPdfPageSize.original:
            pageSize = ui.Size(bitmap.width.toDouble(), bitmap.height.toDouble());
            break;
          case ImageToPdfPageSize.a4:
            pageSize = const ui.Size(595, 842);
            break;
        }

        if (params.options.orientation == ImageToPdfOrientation.landscape) {
          pageSize = ui.Size(pageSize.height, pageSize.width);
        }

        final section = document.sections!.add();
        section.pageSettings.size = pageSize;
        section.pageSettings.margins.all = params.options.margin == ImageToPdfMargin.none
            ? 0
            : params.options.margin == ImageToPdfMargin.small
                ? 16
                : 32;

        final page = section.pages.add();

        // Fit image within page bounds while preserving aspect ratio
        final availableWidth = page.getClientSize().width;
        final availableHeight = page.getClientSize().height;

        final imageAspect = bitmap.width / bitmap.height;
        final pageAspect = availableWidth / availableHeight;

        double drawWidth;
        double drawHeight;

        if (imageAspect > pageAspect) {
          drawWidth = availableWidth;
          drawHeight = availableWidth / imageAspect;
        } else {
          drawHeight = availableHeight;
          drawWidth = availableHeight * imageAspect;
        }

        final x = (availableWidth - drawWidth) / 2;
        final y = (availableHeight - drawHeight) / 2;

        page.graphics.drawImage(
          bitmap,
          ui.Rect.fromLTWH(x, y, drawWidth, drawHeight),
        );
      }

      final savedBytes = document.saveSync();
      document.dispose();

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(savedBytes, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to convert images to PDF: $e');
    }
  }

  @override
  Future<List<File>> pdfToImages(
    File pdfFile, {
    required List<int> pages,
    required bool isPng,
    required int quality,
    void Function(int current, int total)? onProgress,
  }) async {
    final outDir = await FileUtils.getAppOutputDirectory();
    final baseName = p.basenameWithoutExtension(pdfFile.path);

    try {
      final document = await px.PdfDocument.openFile(pdfFile.path);
      final outputFiles = <File>[];

      for (int i = 0; i < pages.length; i++) {
        final pageNum = pages[i];
        if (pageNum < 1 || pageNum > document.pagesCount) continue;

        final page = await document.getPage(pageNum);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: isPng ? px.PdfPageImageFormat.png : px.PdfPageImageFormat.jpeg,
          quality: quality,
        );
        await page.close();

        if (pageImage != null) {
          final ext = isPng ? '.png' : '.jpg';
          final outPath = p.join(outDir.path, '${baseName}_page_$pageNum$ext');
          final outFile = File(outPath);
          await outFile.writeAsBytes(pageImage.bytes, flush: true);
          outputFiles.add(outFile);
        }

        onProgress?.call(i + 1, pages.length);
      }

      await document.close();
      return outputFiles;
    } catch (e) {
      throw CorruptFileException('Failed to convert PDF pages to images: $e');
    }
  }
}

class _MergePdfParams {
  final List<String> filePaths;
  final String outputPath;
  const _MergePdfParams({required this.filePaths, required this.outputPath});
}

class _SplitPdfParams {
  final String filePath;
  final List<int> pageNumbers;
  final String outputDir;
  final String baseName;
  const _SplitPdfParams({
    required this.filePath,
    required this.pageNumbers,
    required this.outputDir,
    required this.baseName,
  });
}

class _RotatePdfParams {
  final String filePath;
  final Map<int, int> pageRotations;
  final String outputPath;
  const _RotatePdfParams({
    required this.filePath,
    required this.pageRotations,
    required this.outputPath,
  });
}

class _ReorderPdfParams {
  final String filePath;
  final List<int> newPageOrder;
  final String outputPath;
  const _ReorderPdfParams({
    required this.filePath,
    required this.newPageOrder,
    required this.outputPath,
  });
}

class _CompressPdfParams {
  final String filePath;
  final PdfCompressQuality quality;
  final String outputPath;
  const _CompressPdfParams({
    required this.filePath,
    required this.quality,
    required this.outputPath,
  });
}

class _ImagesToPdfParams {
  final List<String> imagePaths;
  final ImageToPdfOptions options;
  final String outputPath;
  const _ImagesToPdfParams({
    required this.imagePaths,
    required this.options,
    required this.outputPath,
  });
}
