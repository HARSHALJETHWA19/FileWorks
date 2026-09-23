import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../ad_service.dart';
import '../admob_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main');
});

final adServiceProvider = Provider<AdService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AdmobService(prefs);
});

class ProNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(AppConstants.keyIsProUser) ?? false;
  }

  Future<void> togglePro() async {
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyIsProUser, state);
  }

  Future<void> setPro(bool isPro) async {
    state = isPro;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyIsProUser, state);
  }
}

final isProProvider = NotifierProvider<ProNotifier, bool>(ProNotifier.new);
