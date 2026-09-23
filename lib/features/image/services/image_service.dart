import 'dart:io';
import '../models/image_models.dart';

abstract class ImageService {
  /// Compresses a single image with quality (1-100)
  Future<File> compressImage(File imageFile, int quality, String outputName);

  /// Compresses image to reach a target file size in bytes
  Future<File> compressToTargetSize(File imageFile, int targetBytes, String outputName);

  /// Resizes image with custom width, height, and aspect ratio constraint
  Future<File> resizeImage({
    required File imageFile,
    required int targetWidth,
    required int targetHeight,
    required bool maintainAspectRatio,
    required String outputName,
  });

  /// Converts image format (JPG, PNG, WEBP) with background fill for transparency
  Future<File> convertFormat({
    required File imageFile,
    required ImageFormatType targetFormat,
    required String outputName,
  });

  /// Batch processes multiple images (e.g. compress or convert all)
  Future<List<File>> batchCompress({
    required List<File> images,
    required int quality,
    void Function(int current, int total)? onProgress,
  });

  /// Batch converts multiple images
  Future<List<File>> batchConvert({
    required List<File> images,
    required ImageFormatType targetFormat,
    void Function(int current, int total)? onProgress,
  });

  /// Inspect image resolution (width x height)
  Future<Map<String, int>> getImageDimensions(File imageFile);
}
