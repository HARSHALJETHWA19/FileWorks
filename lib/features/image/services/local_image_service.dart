import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/isolate_helper.dart';
import '../models/image_models.dart';
import 'image_service.dart';

class LocalImageService implements ImageService {
  @override
  Future<Map<String, int>> getImageDimensions(File imageFile) async {
    return IsolateHelper.run<String, Map<String, int>>(
      _getDimensionsIsolate,
      imageFile.path,
    );
  }

  static Map<String, int> _getDimensionsIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw UnsupportedFormatException('Could not decode image metadata.');
      }
      return {'width': decoded.width, 'height': decoded.height};
    } catch (e) {
      throw UnsupportedFormatException('Failed to read image dimensions: $e');
    }
  }

  @override
  Future<File> compressImage(File imageFile, int quality, String outputName) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputName);

    return IsolateHelper.run<_CompressImageParams, File>(
      _compressImageIsolate,
      _CompressImageParams(
        filePath: imageFile.path,
        quality: quality.clamp(1, 100),
        outputPath: outputPath,
      ),
    );
  }

  static File _compressImageIsolate(_CompressImageParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw UnsupportedFormatException('Unable to decode image format.');
      }

      final ext = p.extension(params.outputPath).toLowerCase();
      List<int> encoded;

      if (ext == '.png') {
        encoded = img.encodePng(decoded, level: 9);
      } else if (ext == '.webp') {
        encoded = img.WebPEncoder(lossless: false, quality: params.quality).encode(decoded);
      } else {
        encoded = img.encodeJpg(decoded, quality: params.quality);
      }

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(encoded, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Error compressing image: $e');
    }
  }

  @override
  Future<File> compressToTargetSize(File imageFile, int targetBytes, String outputName) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputName);

    return IsolateHelper.run<_TargetSizeParams, File>(
      _compressToTargetSizeIsolate,
      _TargetSizeParams(
        filePath: imageFile.path,
        targetBytes: targetBytes,
        outputPath: outputPath,
      ),
    );
  }

  static File _compressToTargetSizeIsolate(_TargetSizeParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw UnsupportedFormatException('Unable to decode image.');
      }

      // Binary search for optimal JPG/WEBP quality
      int low = 5;
      int high = 95;
      List<int> bestEncoded = [];

      for (int i = 0; i < 6; i++) {
        final mid = ((low + high) / 2).round();
        final currentEncoded = img.encodeJpg(decoded, quality: mid);

        if (currentEncoded.length <= params.targetBytes) {
          bestEncoded = currentEncoded;
          low = mid + 1; // Try better quality
        } else {
          high = mid - 1; // Need smaller size
        }
      }

      if (bestEncoded.isEmpty) {
        // If even lowest quality is larger than target, downscale dimensions
        decoded = img.copyResize(decoded, width: (decoded.width * 0.7).toInt());
        bestEncoded = img.encodeJpg(decoded, quality: 30);
      }

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(bestEncoded, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to compress image to target size: $e');
    }
  }

  @override
  Future<File> resizeImage({
    required File imageFile,
    required int targetWidth,
    required int targetHeight,
    required bool maintainAspectRatio,
    required String outputName,
  }) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputName);

    return IsolateHelper.run<_ResizeImageParams, File>(
      _resizeImageIsolate,
      _ResizeImageParams(
        filePath: imageFile.path,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        maintainAspectRatio: maintainAspectRatio,
        outputPath: outputPath,
      ),
    );
  }

  static File _resizeImageIsolate(_ResizeImageParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw UnsupportedFormatException('Unable to decode image.');
      }

      final resized = img.copyResize(
        decoded,
        width: params.targetWidth > 0 ? params.targetWidth : null,
        height: params.targetHeight > 0 ? params.targetHeight : null,
        maintainAspect: params.maintainAspectRatio,
        interpolation: img.Interpolation.linear,
      );

      final ext = p.extension(params.outputPath).toLowerCase();
      List<int> encoded;

      if (ext == '.png') {
        encoded = img.encodePng(resized);
      } else if (ext == '.webp') {
        encoded = img.WebPEncoder(lossless: false, quality: 90).encode(resized);
      } else {
        encoded = img.encodeJpg(resized, quality: 90);
      }

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(encoded, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to resize image: $e');
    }
  }

  @override
  Future<File> convertFormat({
    required File imageFile,
    required ImageFormatType targetFormat,
    required String outputName,
  }) async {
    final outputPath = await FileUtils.generateUniqueFilePath(outputName);

    return IsolateHelper.run<_ConvertFormatParams, File>(
      _convertFormatIsolate,
      _ConvertFormatParams(
        filePath: imageFile.path,
        targetFormat: targetFormat,
        outputPath: outputPath,
      ),
    );
  }

  static File _convertFormatIsolate(_ConvertFormatParams params) {
    try {
      final bytes = File(params.filePath).readAsBytesSync();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw UnsupportedFormatException('Unable to decode image for format conversion.');
      }

      List<int> encoded;
      switch (params.targetFormat) {
        case ImageFormatType.png:
          encoded = img.encodePng(decoded);
          break;
        case ImageFormatType.webp:
          encoded = img.WebPEncoder(lossless: false, quality: 90).encode(decoded);
          break;
        case ImageFormatType.jpg:
          // If original image has alpha channel, blend over solid white background
          if (decoded.hasAlpha) {
            final whiteCanvas = img.Image(
              width: decoded.width,
              height: decoded.height,
              numChannels: 3,
            );
            whiteCanvas.clear(img.ColorRgb8(255, 255, 255));
            img.compositeImage(whiteCanvas, decoded);
            decoded = whiteCanvas;
          }
          encoded = img.encodeJpg(decoded, quality: 90);
          break;
      }

      final outFile = File(params.outputPath);
      outFile.writeAsBytesSync(encoded, flush: true);
      return outFile;
    } catch (e) {
      throw CorruptFileException('Failed to convert image format: $e');
    }
  }

  @override
  Future<List<File>> batchCompress({
    required List<File> images,
    required int quality,
    void Function(int current, int total)? onProgress,
  }) async {
    final outputFiles = <File>[];
    for (int i = 0; i < images.length; i++) {
      final imgFile = images[i];
      final name = p.basename(imgFile.path);
      final compressed = await compressImage(imgFile, quality, 'comp_$name');
      outputFiles.add(compressed);
      onProgress?.call(i + 1, images.length);
    }
    return outputFiles;
  }

  @override
  Future<List<File>> batchConvert({
    required List<File> images,
    required ImageFormatType targetFormat,
    void Function(int current, int total)? onProgress,
  }) async {
    final outputFiles = <File>[];
    for (int i = 0; i < images.length; i++) {
      final imgFile = images[i];
      final base = p.basenameWithoutExtension(imgFile.path);
      final newName = '$base.${targetFormat.extension}';
      final converted = await convertFormat(
        imageFile: imgFile,
        targetFormat: targetFormat,
        outputName: newName,
      );
      outputFiles.add(converted);
      onProgress?.call(i + 1, images.length);
    }
    return outputFiles;
  }
}

class _CompressImageParams {
  final String filePath;
  final int quality;
  final String outputPath;
  const _CompressImageParams({
    required this.filePath,
    required this.quality,
    required this.outputPath,
  });
}

class _TargetSizeParams {
  final String filePath;
  final int targetBytes;
  final String outputPath;
  const _TargetSizeParams({
    required this.filePath,
    required this.targetBytes,
    required this.outputPath,
  });
}

class _ResizeImageParams {
  final String filePath;
  final int targetWidth;
  final int targetHeight;
  final bool maintainAspectRatio;
  final String outputPath;
  const _ResizeImageParams({
    required this.filePath,
    required this.targetWidth,
    required this.targetHeight,
    required this.maintainAspectRatio,
    required this.outputPath,
  });
}

class _ConvertFormatParams {
  final String filePath;
  final ImageFormatType targetFormat;
  final String outputPath;
  const _ConvertFormatParams({
    required this.filePath,
    required this.targetFormat,
    required this.outputPath,
  });
}
