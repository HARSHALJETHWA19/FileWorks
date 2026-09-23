import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../models/history_item.dart';

class HistoryRepository {
  final SharedPreferences _prefs;

  HistoryRepository(this._prefs);

  List<HistoryItem> getHistory() {
    final raw = _prefs.getString(AppConstants.keyHistoryItems);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => HistoryItem.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  Future<void> addItem(HistoryItem item) async {
    final current = getHistory();
    // Prepend new item
    current.insert(0, item);
    // Keep at most 100 most recent items to keep storage lightweight
    final trimmed = current.take(100).toList();
    final jsonString = jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await _prefs.setString(AppConstants.keyHistoryItems, jsonString);
  }

  Future<void> deleteItem(String id) async {
    final current = getHistory();
    current.removeWhere((item) => item.id == id);
    final jsonString = jsonEncode(current.map((e) => e.toJson()).toList());
    await _prefs.setString(AppConstants.keyHistoryItems, jsonString);
  }

  Future<void> clearAll() async {
    await _prefs.remove(AppConstants.keyHistoryItems);
  }
}
