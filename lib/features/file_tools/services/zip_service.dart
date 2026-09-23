import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/isolate_helper.dart';

class ZipService {
  /// Compresses a list of files into a single .zip archive
  Future<File> createZip(List<File> files, String zipFileName) async {
    final outPath = await FileUtils.generateUniqueFilePath(zipFileName);
    final filePaths = files.map((f) => f.path).toList();

    return IsolateHelper.run<_CreateZipParams, File>(
      _createZipIsolate,
      _CreateZipParams(filePaths: filePaths, outPath: outPath),
    );
  }

  static File _createZipIsolate(_CreateZipParams params) {
    try {
      final archive = Archive();

      for (final filePath in params.filePaths) {
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final bytes = file.readAsBytesSync();
        final fileName = p.basename(filePath);
        final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
        archive.addFile(archiveFile);
      }

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);

      final outFile = File(params.outPath);
      outFile.writeAsBytesSync(zipBytes, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Unable to create ZIP archive: $e');
    }
  }

  /// Extracts a ZIP archive safely with STRICT Zip Slip (path traversal) protection.
  /// Any entry trying to escape the destination directory will trigger a SecurityException.
  Future<List<File>> extractZip(File zipFile, {String? customDestDirName}) async {
    final baseDir = await FileUtils.getAppOutputDirectory();
    final folderName = customDestDirName != null && customDestDirName.isNotEmpty
        ? FileUtils.sanitizeFilename(customDestDirName)
        : '${p.basenameWithoutExtension(zipFile.path)}_extracted';

    final targetDir = Directory(p.join(baseDir.path, folderName));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return IsolateHelper.run<_ExtractZipParams, List<File>>(
      _extractZipIsolate,
      _ExtractZipParams(
        zipPath: zipFile.path,
        destinationDirPath: targetDir.path,
      ),
    );
  }

  static List<File> _extractZipIsolate(_ExtractZipParams params) {
    try {
      final zipBytes = File(params.zipPath).readAsBytesSync();
      if (zipBytes.isEmpty) {
        throw CorruptFileException('The specified archive is 0 bytes and cannot be extracted.');
      }
      final archive = ZipDecoder().decodeBytes(zipBytes);
      if (archive.isEmpty) {
        throw CorruptFileException('The ZIP archive contains no entries or is invalid/corrupt.');
      }
      final destDir = Directory(params.destinationDirPath);
      final extractedFiles = <File>[];

      for (final entry in archive) {
        final entryName = entry.name;

        // CRITICAL SECURITY CHECK: Validate against path traversal
        final targetFile = FileUtils.validateZipPath(entryName, destDir);

        if (entry.isFile) {
          final parent = targetFile.parent;
          if (!parent.existsSync()) {
            parent.createSync(recursive: true);
          }

          final data = entry.content as List<int>;
          targetFile.writeAsBytesSync(data, flush: true);
          extractedFiles.add(targetFile);
        } else {
          // Directory entry
          targetFile.createSync(recursive: true);
        }
      }

      return extractedFiles;
    } catch (e) {
      if (e is SecurityException) rethrow;
      throw CorruptFileException('Failed to extract ZIP archive: $e');
    }
  }
}

class _CreateZipParams {
  final List<String> filePaths;
  final String outPath;
  const _CreateZipParams({required this.filePaths, required this.outPath});
}

class _ExtractZipParams {
  final String zipPath;
  final String destinationDirPath;
  const _ExtractZipParams({required this.zipPath, required this.destinationDirPath});
}
