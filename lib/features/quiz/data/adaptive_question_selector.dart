import 'dart:math';

import '../domain/learning_profile.dart';
import 'quiz_repository.dart';

/// Seleciona perguntas aleatórias ponderadas pelo nível do jogador.
class AdaptiveQuestionSelector {
  const AdaptiveQuestionSelector();

  List<QuizQuestion> pick({
    required List<QuizQuestion> pool,
    required CategoryLearningProfile profile,
    required int limit,
    int? seed,
  }) {
    if (pool.isEmpty) return [];
    if (pool.length <= limit) {
      final copy = [...pool];
      copy.shuffle(seed != null ? Random(seed) : Random());
      return copy;
    }

    final random = seed != null ? Random(seed) : Random();
    final selected = <QuizQuestion>[];
    final remaining = [...pool];

    while (selected.length < limit && remaining.isNotEmpty) {
      final weights = remaining
          .map((question) => _weight(profile: profile))
          .toList();
      final totalWeight = weights.fold<double>(0, (sum, w) => sum + w);
      var pick = random.nextDouble() * totalWeight;
      var chosenIndex = 0;

      for (var i = 0; i < weights.length; i++) {
        pick -= weights[i];
        if (pick <= 0) {
          chosenIndex = i;
          break;
        }
      }

      selected.add(remaining.removeAt(chosenIndex));
    }

    return selected;
  }

  double _weight({required CategoryLearningProfile profile}) {
    return switch (profile.level) {
      1 => 1.2,
      3 => 0.9,
      _ => 1.0,
    };
  }
}
