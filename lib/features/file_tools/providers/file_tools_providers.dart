import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rename_service.dart';
import '../services/zip_service.dart';

final zipServiceProvider = Provider<ZipService>((ref) {
  return ZipService();
});

final renameServiceProvider = Provider<RenameService>((ref) {
  return RenameService();
});
