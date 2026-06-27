import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/shared_preferences_provider.dart';
import '../domain/learning_profile.dart';

/// Persistência local do perfil de aprendizado por categoria.
class LearningProfileRepository {
  static const String storageKey = 'learning_profile_v1';

  final SharedPreferences _prefs;

  LearningProfileRepository(this._prefs);

  Map<String, CategoryLearningProfile> getProfiles() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          CategoryLearningProfile.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  CategoryLearningProfile getProfile(String categoryTitle) {
    return getProfiles()[categoryTitle] ??
        CategoryLearningProfile(categoryTitle: categoryTitle);
  }

  Future<void> saveProfile(CategoryLearningProfile profile) async {
    final profiles = getProfiles();
    profiles[profile.categoryTitle] = profile;
    await _prefs.setString(
      storageKey,
      jsonEncode(
        profiles.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<void> recordDiagnostic({
    required String categoryTitle,
    required int correct,
    required int total,
  }) async {
    final level = CategoryLearningProfile.levelFromDiagnosticScore(
      correct,
      total,
    );
    final current = getProfile(categoryTitle);
    await saveProfile(
      current.copyWith(
        diagnosticCompleted: true,
        level: level,
        totalAnswered: current.totalAnswered + total,
        totalCorrect: current.totalCorrect + correct,
      ),
    );
  }

  Future<void> recordSessionResult({
    required String categoryTitle,
    required int correct,
    required int total,
  }) async {
    final current = getProfile(categoryTitle);
    final newAnswered = current.totalAnswered + total;
    final newCorrect = current.totalCorrect + correct;
    var level = current.level;

    if (current.diagnosticCompleted && newAnswered >= 20) {
      final accuracy = newCorrect / newAnswered;
      if (accuracy >= 0.85 && level < 3) {
        level = 3;
      } else if (accuracy < 0.45 && level > 1) {
        level = 1;
      }
    }

    await saveProfile(
      current.copyWith(
        level: level,
        totalAnswered: newAnswered,
        totalCorrect: newCorrect,
      ),
    );
  }
}

final learningProfileRepositoryProvider =
    FutureProvider<LearningProfileRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LearningProfileRepository(prefs);
});
