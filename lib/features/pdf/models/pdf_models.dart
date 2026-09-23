import 'dart:io';

class PdfPageInfo {
  final int pageNumber; // 1-indexed
  final int rotation; // 0, 90, 180, 270
  final bool isSelected;
  final File? thumbnailFile;

  const PdfPageInfo({
    required this.pageNumber,
    this.rotation = 0,
    this.isSelected = true,
    this.thumbnailFile,
  });

  PdfPageInfo copyWith({
    int? pageNumber,
    int? rotation,
    bool? isSelected,
    File? thumbnailFile,
  }) {
    return PdfPageInfo(
      pageNumber: pageNumber ?? this.pageNumber,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      thumbnailFile: thumbnailFile ?? this.thumbnailFile,
    );
  }
}

enum PdfSplitMode {
  everyPage,
  pageRange,
  customPages,
}

enum PdfCompressQuality {
  highQuality, // 80% image quality
  balanced, // 50% image quality
  maximumCompression, // 25% image quality
}

enum ImageToPdfPageSize {
  a4,
  letter,
  original,
}

enum ImageToPdfOrientation {
  portrait,
  landscape,
}

enum ImageToPdfMargin {
  none,
  small,
  medium,
}

class ImageToPdfOptions {
  final ImageToPdfPageSize pageSize;
  final ImageToPdfOrientation orientation;
  final ImageToPdfMargin margin;

  const ImageToPdfOptions({
    this.pageSize = ImageToPdfPageSize.a4,
    this.orientation = ImageToPdfOrientation.portrait,
    this.margin = ImageToPdfMargin.none,
  });
}
