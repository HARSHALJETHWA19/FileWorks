import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../models/history_item.dart';
import '../services/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HistoryRepository(prefs);
});

class HistoryListNotifier extends Notifier<List<HistoryItem>> {
  @override
  List<HistoryItem> build() {
    final repo = ref.watch(historyRepositoryProvider);
    return repo.getHistory();
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.addItem(item);
    state = repo.getHistory();
  }

  Future<void> deleteHistoryItem(String id) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.deleteItem(id);
    state = repo.getHistory();
  }

  Future<void> clearAll() async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.clearAll();
    state = [];
  }
}

final historyProvider =
    NotifierProvider<HistoryListNotifier, List<HistoryItem>>(HistoryListNotifier.new);
