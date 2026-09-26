import 'dart:io';
import '../../features/monetization/free_usage_config.dart';

class ProcessingResult {
  final bool success;
  final String title;
  final String message;
  final List<File> outputFiles;
  final int originalTotalBytes;
  final int outputTotalBytes;
  final Map<String, dynamic>? extraStats;
  final String? repeatRoute;
  final ToolFeature? feature;

  const ProcessingResult({
    required this.success,
    required this.title,
    required this.message,
    required this.outputFiles,
    this.originalTotalBytes = 0,
    this.outputTotalBytes = 0,
    this.extraStats,
    this.repeatRoute,
    this.feature,
  });

  bool get hasFiles => outputFiles.isNotEmpty;
  File? get primaryFile => outputFiles.isNotEmpty ? outputFiles.first : null;
  bool get isExtractZip => feature == ToolFeature.extractZip;

  int get totalFilesCount => outputFiles.length;

  double get savingsPercentage {
    if (originalTotalBytes <= 0 || outputTotalBytes <= 0) return 0.0;
    final diff = originalTotalBytes - outputTotalBytes;
    if (diff <= 0) return 0.0;
    return (diff / originalTotalBytes) * 100.0;
  }
}
