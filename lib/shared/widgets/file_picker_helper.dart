import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FilePickerHelper {
  /// Picks multiple PDF files
  static Future<List<File>> pickPdfFiles({bool allowMultiple = true}) async {
    if (allowMultiple) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      return result
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
    } else {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (file?.path != null) {
        return [File(file!.path!)];
      }
      return [];
    }
  }

  /// Picks a single PDF file
  static Future<File?> pickSinglePdfFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    return file?.path != null ? File(file!.path!) : null;
  }

  /// Picks multiple image files (JPG, JPEG, PNG, WEBP)
  static Future<List<File>> pickImageFiles({bool allowMultiple = true}) async {
    if (allowMultiple) {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      return result
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
    } else {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );
      if (file?.path != null) {
        return [File(file!.path!)];
      }
      return [];
    }
  }

  /// Picks a single image file
  static Future<File?> pickSingleImageFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
    );
    return file?.path != null ? File(file!.path!) : null;
  }

  /// Picks a ZIP archive
  static Future<File?> pickZipFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return file?.path != null ? File(file!.path!) : null;
  }

  /// Picks multiple arbitrary files for archiving or renaming
  static Future<List<File>> pickAnyFiles({bool allowMultiple = true}) async {
    if (allowMultiple) {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );
      return result
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
    } else {
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );
      if (file?.path != null) {
        return [File(file!.path!)];
      }
      return [];
    }
  }
}
