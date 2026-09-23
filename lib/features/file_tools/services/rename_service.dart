import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/file_utils.dart';

class RenamePreviewItem {
  final File originalFile;
  final String originalName;
  final String newName;

  const RenamePreviewItem({
    required this.originalFile,
    required this.originalName,
    required this.newName,
  });
}

class RenameService {
  /// Generates a preview mapping of original files to new names
  List<RenamePreviewItem> generatePreview({
    required List<File> files,
    required String pattern, // e.g. "Dubai_Trip_{number}" or "Doc_{date}_{number}"
    int startNumber = 1,
    int zeroPadding = 3,
    String? findText,
    String? replaceText,
  }) {
    final previewList = <RenamePreviewItem>[];
    final dateString = DateFormat('yyyyMMdd').format(DateTime.now());

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final origName = p.basename(file.path);
      final ext = p.extension(origName);
      final nameWithoutExt = p.basenameWithoutExtension(origName);

      final currentNumber = (startNumber + i).toString().padLeft(zeroPadding, '0');

      var newBase = pattern;
      if (newBase.isEmpty) {
        newBase = nameWithoutExt;
      }

      // Replace template tokens
      newBase = newBase.replaceAll('{number}', currentNumber);
      newBase = newBase.replaceAll('{date}', dateString);
      newBase = newBase.replaceAll('{name}', nameWithoutExt);

      // Search & replace if supplied
      if (findText != null && findText.isNotEmpty) {
        newBase = newBase.replaceAll(findText, replaceText ?? '');
      }

      final sanitizedNewName = '${FileUtils.sanitizeFilename(newBase)}$ext';

      previewList.add(
        RenamePreviewItem(
          originalFile: file,
          originalName: origName,
          newName: sanitizedNewName,
        ),
      );
    }

    return previewList;
  }

  /// Executes batch renaming on device
  Future<List<File>> executeBatchRename(List<RenamePreviewItem> items) async {
    final renamedFiles = <File>[];

    // Check for collisions inside the batch itself
    final targetNames = items.map((e) => e.newName.toLowerCase()).toSet();
    if (targetNames.length != items.length) {
      throw AppException('Duplicate file names detected in pattern. Please include {number} to ensure unique names.');
    }

    for (final item in items) {
      final dir = item.originalFile.parent;
      final targetPath = p.join(dir.path, item.newName);
      final targetFile = File(targetPath);

      // If name hasn't changed, skip
      if (targetPath == item.originalFile.path) {
        renamedFiles.add(item.originalFile);
        continue;
      }

      if (await targetFile.exists()) {
        throw AppException('Cannot rename: "${item.newName}" already exists in directory.');
      }

      final renamed = await item.originalFile.rename(targetPath);
      renamedFiles.add(renamed);
    }

    return renamedFiles;
  }
}
