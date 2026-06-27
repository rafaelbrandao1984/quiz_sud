/** Espelha lib/features/quiz/domain/lightning_scoring.dart */

function computeLightningPoints({
  isCorrect,
  responseTimeMs,
  questionTimeMs,
  streakBefore,
}) {
  if (!isCorrect) return 0;

  const speedFactor = Math.max(0.5, 1 - responseTimeMs / questionTimeMs);
  const streakMultiplier =
    streakBefore >= 3 ? 1.5 : streakBefore >= 2 ? 1.25 : 1.0;

  return Math.round(1000 * speedFactor * streakMultiplier);
}

function nextStreak({ isCorrect, currentStreak }) {
  return isCorrect ? currentStreak + 1 : 0;
}

module.exports = { computeLightningPoints, nextStreak };
