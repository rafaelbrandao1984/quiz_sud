import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../quiz/data/multiplayer_navigation.dart';
import '../../../quiz/data/multiplayer_repository.dart';

/// Banner para reentrar em uma sala multijogador ativa na sessão.
class ActiveRoomBanner extends ConsumerWidget {
  const ActiveRoomBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roomId = ref.watch(currentRoomIdProvider);
    if (roomId == null) return const SizedBox.shrink();

    final roomAsync = ref.watch(currentRoomProvider(roomId));

    return roomAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (room) {
        if (room.status == 'finished') return const SizedBox.shrink();

        final subtitle = room.status == 'waiting'
            ? 'Aguardando o host iniciar o campeonato'
            : 'Partida em andamento — toque para voltar à sala';

        return Card(
          color: theme.colorScheme.secondary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.secondary.withValues(alpha: 0.35),
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.meeting_room_rounded,
              color: theme.colorScheme.secondary,
            ),
            title: Text(
              'Sala $roomId',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            subtitle: Text(subtitle),
            trailing: FilledButton(
              onPressed: () => goToMultiplayerRoom(
                GoRouter.of(context),
                roomId,
                categoryTitle: room.categoryTitle,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Reentrar'),
            ),
          ),
        );
      },
    );
  }
}
