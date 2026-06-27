import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/shared_preferences_provider.dart';
import '../domain/session_record.dart';

/// Histórico local de partidas (até 100 registros).
class SessionHistoryRepository {
  static const String storageKey = 'session_history_v1';
  static const int maxRecords = 100;

  final SharedPreferences _prefs;

  SessionHistoryRepository(this._prefs);

  List<SessionRecord> getRecords() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => SessionRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(SessionRecord record) async {
    final records = getRecords();
    records.insert(0, record);
    if (records.length > maxRecords) {
      records.removeRange(maxRecords, records.length);
    }
    await _save(records);
  }

  int get totalSessions => getRecords().length;

  int get totalPoints {
    return getRecords()
        .where((record) => record.isPointsBased)
        .fold(0, (sum, record) => sum + record.score);
  }

  int get totalCorrect {
    return getRecords()
        .where((record) => !record.isPointsBased)
        .fold(0, (sum, record) => sum + record.score);
  }

  Map<String, int> get sessionsByMode {
    final counts = <String, int>{};
    for (final record in getRecords()) {
      counts[record.modeLabel] = (counts[record.modeLabel] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _save(List<SessionRecord> records) async {
    final encoded = jsonEncode(records.map((record) => record.toJson()).toList());
    await _prefs.setString(storageKey, encoded);
  }
}

final sessionHistoryRepositoryProvider =
    FutureProvider<SessionHistoryRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SessionHistoryRepository(prefs);
});

final sessionHistoryRecordsProvider = FutureProvider<List<SessionRecord>>((ref) async {
  final repo = await ref.watch(sessionHistoryRepositoryProvider.future);
  return repo.getRecords();
});
