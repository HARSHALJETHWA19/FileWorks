import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../errors/exceptions.dart';

class FileUtils {
  /// Format bytes into human-readable representation: B, KB, MB, GB
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, clampedIndex);
    return '${size.toStringAsFixed(decimals)} ${suffixes[clampedIndex]}';
  }

  /// Calculates percentage saved: positive percentage means reduced size
  static double calculateSavings(int originalBytes, int newBytes) {
    if (originalBytes <= 0) return 0.0;
    return ((originalBytes - newBytes) / originalBytes) * 100.0;
  }

  /// Strips dangerous characters and illegal Windows/Linux characters from a filename
  static String sanitizeFilename(String filename) {
    final clean = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (clean.isEmpty) return 'file_${DateTime.now().millisecondsSinceEpoch}';
    return clean;
  }

  static File validateZipPath(String entryName, Directory destinationDir) {
    var sanitizedEntry = entryName.replaceAll(r'\', '/');
    
    // Strip leading slashes to prevent absolute path override in p.join
    while (sanitizedEntry.startsWith('/')) {
      sanitizedEntry = sanitizedEntry.substring(1);
    }

    // Reject Windows drive letters
    if (RegExp(r'^[a-zA-Z]:').hasMatch(sanitizedEntry)) {
      throw SecurityException(
        'Zip Slip detected! Illegal archive entry attempting to write outside target directory: $entryName',
      );
    }

    final canonicalDestPath = destinationDir.resolveSymbolicLinksSync();
    
    // Normalize and join
    final rawCombined = p.join(canonicalDestPath, sanitizedEntry);
    final normalizedPath = p.normalize(rawCombined);

    // Ensure the target is strictly inside destinationDir
    if (!p.isWithin(canonicalDestPath, normalizedPath)) {
      throw SecurityException(
        'Zip Slip detected! Illegal archive entry attempting to write outside target directory: $entryName',
      );
    }

    return File(normalizedPath);
  }

  /// Parses page ranges like "1-5, 8, 10-12" into sorted list of unique 1-indexed page numbers
  static List<int> parsePageRange(String input, int maxPages) {
    if (input.trim().isEmpty) return [];

    final pages = <int>{};
    final parts = input.split(RegExp(r'[,;]'));

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());

          if (start != null && end != null && start > 0 && end > 0) {
            final from = min(start, end);
            final to = min(max(start, end), maxPages);
            for (var i = from; i <= to; i++) {
              pages.add(i);
            }
          }
        }
      } else {
        final single = int.tryParse(part);
        if (single != null && single > 0 && single <= maxPages) {
          pages.add(single);
        }
      }
    }

    final sorted = pages.toList()..sort();
    return sorted;
  }

  /// Gets the output directory for FileWorks processed files
  static Future<Directory> getAppOutputDirectory() async {
    Directory base;
    try {
      if (Platform.isAndroid) {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
        if (extDirs != null && extDirs.isNotEmpty) {
          base = extDirs.first;
        } else {
          base = await getApplicationDocumentsDirectory();
        }
      } else {
        base = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      base = await getTemporaryDirectory();
    }

    final fileWorksDir = Directory(p.join(base.path, 'FileWorks'));
    if (!await fileWorksDir.exists()) {
      await fileWorksDir.create(recursive: true);
    }
    return fileWorksDir;
  }

  /// Generates a non-conflicting unique output path
  static Future<String> generateUniqueFilePath(String filename) async {
    final dir = await getAppOutputDirectory();
    final sanitized = sanitizeFilename(filename);
    final ext = p.extension(sanitized);
    final basenameWithoutExt = p.basenameWithoutExtension(sanitized);

    var targetPath = p.join(dir.path, sanitized);
    var counter = 1;

    while (await File(targetPath).exists()) {
      targetPath = p.join(dir.path, '${basenameWithoutExt}_$counter$ext');
      counter++;
    }

    return targetPath;
  }
}
