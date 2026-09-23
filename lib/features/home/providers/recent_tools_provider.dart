import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../monetization/providers/monetization_provider.dart';

class RecentToolsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(AppConstants.keyRecentTools) ?? [];
  }

  Future<void> recordToolUsage(String route) async {
    final list = List<String>.from(state);
    list.remove(route);
    list.insert(0, route);
    final trimmed = list.take(4).toList();
    state = trimmed;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(AppConstants.keyRecentTools, trimmed);
  }
}

final recentToolsProvider =
    NotifierProvider<RecentToolsNotifier, List<String>>(RecentToolsNotifier.new);
