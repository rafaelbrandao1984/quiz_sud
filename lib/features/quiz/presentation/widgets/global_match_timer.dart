import 'package:flutter/material.dart';

/// Cronômetro global do campeonato multijogador.
class GlobalMatchTimer extends StatelessWidget {
  final int secondsRemaining;
  final int maxSeconds;

  const GlobalMatchTimer({
    super.key,
    required this.secondsRemaining,
    required this.maxSeconds,
  });

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        maxSeconds == 0 ? 0.0 : secondsRemaining / maxSeconds;
    final isUrgent = secondsRemaining <= 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isUrgent
          ? Colors.red.shade50
          : theme.colorScheme.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            color: isUrgent ? Colors.red.shade700 : theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tempo Restante da Partida',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUrgent
                          ? Colors.red.shade600
                          : theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(secondsRemaining),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isUrgent ? Colors.red.shade700 : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
