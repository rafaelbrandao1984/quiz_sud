import 'dart:math';

/// Calcula pontos de uma resposta no modo Arena Relâmpago.
int computeLightningPoints({
  required bool isCorrect,
  required int responseTimeMs,
  required int questionTimeMs,
  required int streakBefore,
}) {
  if (!isCorrect) return 0;

  final speedFactor = max(
    0.5,
    1 - (responseTimeMs / questionTimeMs),
  );
  final streakMultiplier = streakBefore >= 3
      ? 1.5
      : streakBefore >= 2
          ? 1.25
          : 1.0;

  return (1000 * speedFactor * streakMultiplier).round();
}

/// Streak após uma resposta.
int nextStreak({required bool isCorrect, required int currentStreak}) {
  if (isCorrect) return currentStreak + 1;
  return 0;
}
