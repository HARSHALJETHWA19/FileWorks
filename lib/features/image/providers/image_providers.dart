import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/image_service.dart';
import '../services/local_image_service.dart';

final imageServiceProvider = Provider<ImageService>((ref) {
  return LocalImageService();
});
