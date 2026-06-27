import 'package:flutter/material.dart';
import '../../domain/quiz_room.dart';

/// Painel de ranking em tempo real dos jogadores da sala.
class PlayerRankingPanel extends StatelessWidget {
  final List<QuizPlayer> players;
  final String currentPlayerId;
  final int? currentTurnIndex;
  final bool isLightning;
  final int responsesCount;
  final int totalPlayers;

  const PlayerRankingPanel({
    super.key,
    required this.players,
    required this.currentPlayerId,
    this.currentTurnIndex,
    this.isLightning = false,
    this.responsesCount = 0,
    this.totalPlayers = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.secondary.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.leaderboard_rounded,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Ranking ao vivo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (isLightning && totalPlayers > 0) ...[
                const Spacer(),
                Text(
                  '$responsesCount/$totalPlayers responderam',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sortedPlayers.asMap().entries.map((entry) {
                final index = entry.key;
                final player = entry.value;
                final isCurrentPlayer = player.id == currentPlayerId;
                final playerListIndex =
                    players.indexWhere((p) => p.id == player.id);
                final isTurnLeader = currentTurnIndex != null &&
                    playerListIndex == currentTurnIndex;

                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isTurnLeader
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : isCurrentPlayer
                            ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTurnLeader
                          ? theme.colorScheme.primary
                          : isCurrentPlayer
                              ? theme.colorScheme.secondary
                              : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        player.name,
                        style: TextStyle(
                          fontWeight: isCurrentPlayer || isTurnLeader
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (isTurnLeader) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 14,
                          color: theme.colorScheme.secondary,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '${player.score} pts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
