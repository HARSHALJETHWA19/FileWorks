import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../ad_service.dart';
import '../admob_service.dart';
import '../billing_constants.dart';
import '../services/billing_service.dart';
import '../services/free_usage_manager.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main');
});

final freeUsageManagerProvider = Provider<FreeUsageManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FreeUsageManager(prefs);
});

final billingServiceProvider = Provider<BillingService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = BillingService(prefs);
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

class EntitlementNotifier extends Notifier<EntitlementState> {
  BillingService? _service;

  @override
  EntitlementState build() {
    _service = ref.watch(billingServiceProvider);
    _service!.stateNotifier.addListener(_onStateChanged);
    ref.onDispose(() {
      _service?.stateNotifier.removeListener(_onStateChanged);
    });
    return _service!.state;
  }

  void _onStateChanged() {
    if (_service != null) {
      state = _service!.state;
      // Immediately notify ad service of Pro status changes
      try {
        final adService = ref.read(adServiceProvider);
        adService.updateProStatus(state.isPro);
      } catch (_) {}
    }
  }
}

final entitlementStateProvider =
    NotifierProvider<EntitlementNotifier, EntitlementState>(EntitlementNotifier.new);

class ProNotifier extends Notifier<bool> {
  @override
  bool build() {
    final entitlement = ref.watch(entitlementStateProvider);
    return entitlement.isPro;
  }

  Future<void> setPro(bool isPro) async {
    state = isPro;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyIsProUser, isPro);
    try {
      ref.read(adServiceProvider).updateProStatus(isPro);
    } catch (_) {}
  }

  Future<void> togglePro() async {
    await setPro(!state);
  }
}

final isProProvider = NotifierProvider<ProNotifier, bool>(ProNotifier.new);

final adServiceProvider = Provider<AdService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = AdmobService(prefs);
  return service;
});
