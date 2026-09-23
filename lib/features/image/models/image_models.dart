enum ImageFormatType {
  jpg,
  png,
  webp;

  String get extension => name;
  String get label => name.toUpperCase();
}

enum ImageCompressMode {
  quality,
  targetSize,
}

enum ImageResizePreset {
  hd('HD (1280 x 720)', 1280, 720),
  fullHd('Full HD (1920 x 1080)', 1920, 1080),
  instagramSquare('Instagram Square (1080 x 1080)', 1080, 1080),
  whatsApp('WhatsApp Sharing (1280 x 1280)', 1280, 1280),
  email('Email Friendly (800 x 600)', 800, 600),
  avatar('Profile Avatar (512 x 512)', 512, 512),
  custom('Custom Size', 0, 0);

  final String label;
  final int width;
  final int height;

  const ImageResizePreset(this.label, this.width, this.height);
}
