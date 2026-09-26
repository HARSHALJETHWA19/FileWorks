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
}
