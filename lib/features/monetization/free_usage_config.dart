enum ToolFeature {
  pdfMerge,
  pdfSplit,
  pdfRotate,
  pdfReorder,
  pdfToImage,
  imageToPdf,
  pdfCompress,
  imageCompress,
  imageResize,
  imageConvert,
  createZip,
  extractZip,
  batchRename,
}

class FreeUsageConfig {
  static const int _mbInBytes = 1024 * 1024;

  // File size limits in bytes
  static const int maxFreeFileSizeBytes = 10 * _mbInBytes; // 10 MB
  static const int maxRewardedFileSizeBytes = 25 * _mbInBytes; // 25 MB

  /// Returns the baseline free limit for the given [feature].
  static int getFreeLimit(ToolFeature feature) {
    switch (feature) {
      case ToolFeature.pdfMerge:
        return 3; // Max 3 input PDFs
      case ToolFeature.pdfSplit:
        return 5; // Max 5 pages/selections
      case ToolFeature.pdfRotate:
        return 5; // Max 5 pages
      case ToolFeature.pdfReorder:
        return 10; // Max 10 pages
      case ToolFeature.pdfToImage:
        return 5; // Max 5 pages
      case ToolFeature.imageToPdf:
        return 5; // Max 5 images
      case ToolFeature.pdfCompress:
      case ToolFeature.imageCompress:
      case ToolFeature.imageResize:
      case ToolFeature.imageConvert:
        return maxFreeFileSizeBytes; // 10 MB
      case ToolFeature.createZip:
        return 10; // Max 10 files
      case ToolFeature.extractZip:
        return 10; // Max 10 files
      case ToolFeature.batchRename:
        return 10; // Max 10 files
    }
  }

  /// Returns the rewarded limit (free limit + bonus) for the given [feature].
  static int getRewardedLimit(ToolFeature feature) {
    switch (feature) {
      case ToolFeature.pdfMerge:
        return 8; // 3 + 5 additional PDFs
      case ToolFeature.pdfSplit:
        return 10; // 5 + 5 additional pages/selections
      case ToolFeature.pdfRotate:
        return 10; // 5 + 5 additional pages
      case ToolFeature.pdfReorder:
        return 20; // 10 + 10 additional pages
      case ToolFeature.pdfToImage:
        return 10; // 5 + 5 additional pages
      case ToolFeature.imageToPdf:
        return 10; // 5 + 5 additional images
      case ToolFeature.pdfCompress:
      case ToolFeature.imageCompress:
      case ToolFeature.imageResize:
      case ToolFeature.imageConvert:
        return maxRewardedFileSizeBytes; // Up to 25 MB
      case ToolFeature.createZip:
        return 20; // 10 + 10 additional files
      case ToolFeature.extractZip:
        return 20; // 10 + 10 additional files
      case ToolFeature.batchRename:
        return 20; // 10 + 10 additional files
    }
  }

  /// Returns whether this feature is evaluated by byte size instead of count.
  static bool isByteLimit(ToolFeature feature) {
    switch (feature) {
      case ToolFeature.pdfCompress:
      case ToolFeature.imageCompress:
      case ToolFeature.imageResize:
      case ToolFeature.imageConvert:
        return true;
      default:
        return false;
    }
  }

  /// Returns the human-readable unit for the feature (e.g. 'PDFs', 'pages', 'MB').
  static String getUnit(ToolFeature feature) {
    switch (feature) {
      case ToolFeature.pdfMerge:
        return 'PDFs';
      case ToolFeature.pdfSplit:
      case ToolFeature.pdfRotate:
      case ToolFeature.pdfReorder:
      case ToolFeature.pdfToImage:
        return 'pages';
      case ToolFeature.imageToPdf:
        return 'images';
      case ToolFeature.pdfCompress:
      case ToolFeature.imageCompress:
      case ToolFeature.imageResize:
      case ToolFeature.imageConvert:
        return 'MB';
      case ToolFeature.createZip:
      case ToolFeature.extractZip:
      case ToolFeature.batchRename:
        return 'files';
    }
  }

  /// Returns the user-friendly tool display name.
  static String getDisplayName(ToolFeature feature) {
    switch (feature) {
      case ToolFeature.pdfMerge:
        return 'Merge PDF';
      case ToolFeature.pdfSplit:
        return 'Split PDF';
      case ToolFeature.pdfRotate:
        return 'Rotate PDF';
      case ToolFeature.pdfReorder:
        return 'Reorder PDF';
      case ToolFeature.pdfToImage:
        return 'PDF to Image';
      case ToolFeature.imageToPdf:
        return 'Image to PDF';
      case ToolFeature.pdfCompress:
        return 'Compress PDF';
      case ToolFeature.imageCompress:
        return 'Compress Image';
      case ToolFeature.imageResize:
        return 'Resize Image';
      case ToolFeature.imageConvert:
        return 'Convert Image';
      case ToolFeature.createZip:
        return 'Create ZIP';
      case ToolFeature.extractZip:
        return 'Extract ZIP';
      case ToolFeature.batchRename:
        return 'Batch Rename';
    }
  }

  /// Returns the additional bonus description granted by watching a rewarded ad.
  static String getRewardBonusText(ToolFeature feature) {
    if (isByteLimit(feature)) {
      return 'up to 25 MB';
    }
    final bonus = getRewardedLimit(feature) - getFreeLimit(feature);
    return '+$bonus ${getUnit(feature)}';
  }

  /// Formats an amount with its unit.
  static String formatAmount(ToolFeature feature, int amount) {
    if (isByteLimit(feature)) {
      final mb = (amount / _mbInBytes).toStringAsFixed(1);
      return mb.endsWith('.0') ? '${mb.substring(0, mb.length - 2)} MB' : '$mb MB';
    }
    return '$amount ${getUnit(feature)}';
  }
}
