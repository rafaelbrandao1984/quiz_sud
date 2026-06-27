import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../quiz/data/session_history_repository.dart';
import '../../quiz/domain/session_record.dart';

/// Resumo do histórico local de partidas.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recordsAsync = ref.watch(sessionHistoryRecordsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Suas Estatísticas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 64,
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma partida registrada ainda',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jogue uma trilha, arena ou duelo — seus resultados aparecerão aqui.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final repo = ref.watch(sessionHistoryRepositoryProvider).value;
          final modeCounts = repo?.sessionsByMode ?? {};

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SummaryGrid(
                totalSessions: records.length,
                modeCounts: modeCounts,
              ),
              const SizedBox(height: 24),
              Text(
                'Partidas recentes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              ...records.map((record) => _SessionTile(record: record)),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int totalSessions;
  final Map<String, int> modeCounts;

  const _SummaryGrid({
    required this.totalSessions,
    required this.modeCounts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topMode = modeCounts.entries.isEmpty
        ? null
        : modeCounts.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
          );

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.sports_esports_outlined,
            label: 'Partidas',
            value: '$totalSessions',
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.star_outline_rounded,
            label: 'Modo favorito',
            value: topMode?.key ?? '—',
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionRecord record;

  const _SessionTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _formatDate(record.playedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
          child: Icon(
            _iconForMode(record.modeLabel),
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          record.categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$record.modeLabel • $date'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.scoreLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (record.rank != null && record.playerCount != null)
              Text(
                '${record.rank}º de ${record.playerCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForMode(String mode) {
    return switch (mode) {
      'Arena' => Icons.bolt_rounded,
      'Duelo' => Icons.sports_martial_arts,
      'Trilha' => Icons.route_rounded,
      'Reforço' => Icons.menu_book_rounded,
      'Campeonato' => Icons.emoji_events_outlined,
      _ => Icons.person_outline,
    };
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}
