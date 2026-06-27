import 'package:flutter/material.dart';
import '../../domain/quiz_room.dart';

/// Ranking lateral para layout web da Arena Relâmpago.
class PlayerRankingSidebar extends StatelessWidget {
  final List<QuizPlayer> players;
  final String currentPlayerId;
  final int responsesCount;
  final int totalPlayers;
  final Map<String, int> streaks;

  const PlayerRankingSidebar({
    super.key,
    required this.players,
    required this.currentPlayerId,
    required this.responsesCount,
    required this.totalPlayers,
    this.streaks = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.03),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.secondary.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.leaderboard_rounded,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ranking',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$responsesCount/$totalPlayers responderam',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sortedPlayers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final player = sortedPlayers[index];
                final isCurrentPlayer = player.id == currentPlayerId;
                final streak = streaks[player.id] ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentPlayer
                        ? theme.colorScheme.secondary.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentPlayer
                          ? theme.colorScheme.secondary
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.name,
                              style: TextStyle(
                                fontWeight: isCurrentPlayer
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (streak >= 2)
                              Text(
                                '🔥 $streak streak',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${player.score}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
