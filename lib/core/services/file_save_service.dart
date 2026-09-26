import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

enum FileSaveStatus {
  success,
  cancelled,
  failed,
}

class FileSaveResult {
  final FileSaveStatus status;
  final String? savedPath;
  final String? errorMessage;

  const FileSaveResult({
    required this.status,
    this.savedPath,
    this.errorMessage,
  });

  bool get isSuccess => status == FileSaveStatus.success;
}

class FileSaveService {
  /// Saves a single file to device storage using Android SAF via FilePicker.saveFile
  static Future<FileSaveResult> saveFileToDevice({
    required File file,
    String? dialogTitle,
    String? suggestedName,
  }) async {
    try {
      if (!await file.exists()) {
        debugPrint('FileSaveService: File does not exist at ${file.path}');
        return const FileSaveResult(
          status: FileSaveStatus.failed,
          errorMessage: 'File not found on storage.',
        );
      }

      final bytes = await file.readAsBytes();
      final fileName = suggestedName ?? p.basename(file.path);
      final rawExt = p.extension(fileName).replaceFirst('.', '').toLowerCase();
      final allowedExts = rawExt.isNotEmpty ? [rawExt] : null;

      final uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Save to Device',
        fileName: fileName,
        bytes: bytes,
        type: allowedExts != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExts,
      );

      if (uri == null) {
        return const FileSaveResult(status: FileSaveStatus.cancelled);
      }

      return FileSaveResult(
        status: FileSaveStatus.success,
        savedPath: uri.toString(),
      );
    } catch (e) {
      debugPrint('FileSaveService error saving file: $e');
      return FileSaveResult(
        status: FileSaveStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Bundles multiple files into a single ZIP archive and saves to device storage
  static Future<FileSaveResult> saveMultipleFilesAsZipToDevice({
    required List<File> files,
    required String zipFileName,
    String? dialogTitle,
  }) async {
    try {
      final validFiles = files.where((f) => f.existsSync()).toList();
      if (validFiles.isEmpty) {
        debugPrint('FileSaveService: No existing files to archive.');
        return const FileSaveResult(
          status: FileSaveStatus.failed,
          errorMessage: 'No valid files available to archive.',
        );
      }

      final archive = Archive();
      for (final file in validFiles) {
        final bytes = await file.readAsBytes();
        final name = p.basename(file.path);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      final zipData = ZipEncoder().encode(archive);

      final cleanZipName = zipFileName.toLowerCase().endsWith('.zip')
          ? zipFileName
          : '$zipFileName.zip';

      final uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Save Archive to Device',
        fileName: cleanZipName,
        bytes: Uint8List.fromList(zipData),
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (uri == null) {
        return const FileSaveResult(status: FileSaveStatus.cancelled);
      }

      return FileSaveResult(
        status: FileSaveStatus.success,
        savedPath: uri.toString(),
      );
    } catch (e) {
      debugPrint('FileSaveService error saving zip archive: $e');
      return FileSaveResult(
        status: FileSaveStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Saves multiple files individually to device storage using Android SAF.
  /// Preserves each file's original name and extension, handles cancellation gracefully,
  /// safely handles duplicate names, and reports partial successes or failures.
  static Future<BatchSaveResult> saveAllFilesIndividually({
    required List<File> files,
  }) async {
    final validFiles = files.where((f) => f.existsSync()).toList();
    if (validFiles.isEmpty) {
      return const BatchSaveResult(
        totalFiles: 0,
        savedCount: 0,
        cancelledCount: 0,
        failedCount: 0,
        errorMessage: 'No valid files available to save.',
      );
    }

    int saved = 0;
    int cancelled = 0;
    int failed = 0;
    final failedNames = <String>[];

    for (int i = 0; i < validFiles.length; i++) {
      final file = validFiles[i];
      final fileName = p.basename(file.path);
      final res = await saveFileToDevice(
        file: file,
        dialogTitle: 'Save "$fileName" (${i + 1}/${validFiles.length})',
        suggestedName: fileName,
      );

      if (res.status == FileSaveStatus.success) {
        saved++;
      } else if (res.status == FileSaveStatus.cancelled) {
        cancelled++;
        // If the user cancelled a save dialog, break cleanly to avoid
        // repetitive dialogs while preserving previously saved files.
        break;
      } else {
        failed++;
        failedNames.add(fileName);
      }
    }

    return BatchSaveResult(
      totalFiles: validFiles.length,
      savedCount: saved,
      cancelledCount: cancelled,
      failedCount: failed,
      failedFileNames: failedNames,
    );
  }
}

class BatchSaveResult {
  final int totalFiles;
  final int savedCount;
  final int cancelledCount;
  final int failedCount;
  final List<String> failedFileNames;
  final String? errorMessage;

  const BatchSaveResult({
    required this.totalFiles,
    required this.savedCount,
    required this.cancelledCount,
    required this.failedCount,
    this.failedFileNames = const [],
    this.errorMessage,
  });

  bool get isAllSuccess => savedCount == totalFiles && totalFiles > 0;
  bool get isAllSuccessful => isAllSuccess;
  bool get isPartialSuccess => savedCount > 0 && (cancelledCount > 0 || failedCount > 0);
  bool get wasCancelled => cancelledCount > 0 && savedCount == 0 && failedCount == 0;
  bool get isAllFailed => failedCount == totalFiles && totalFiles > 0;
  int get totalCount => totalFiles;
}
