import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../quiz/data/multiplayer_navigation.dart';
import '../../../quiz/data/multiplayer_repository.dart';
import '../../../quiz/domain/room_settings.dart';
import '../../../quiz/domain/game_mode.dart';
import '../../../quiz/presentation/room_config_dialog.dart';

/// Card de Ações para Salas Virtuais (Jogar com amigos / Criar sala).
class RoomActionsCard extends ConsumerWidget {
  const RoomActionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Multijogador',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Arena Relâmpago e Duelo 1v1 em tempo real',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Linha com os dois botões principais
            Row(
              children: [
                // Botão "Criar Sala" (Borda fina dourada/estilizada)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createRoom(context, ref),
                    icon: Icon(
                      Icons.add_box_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                    label: const Text('Criar Sala'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(
                        color: theme.colorScheme.secondary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botão "Entrar em Sala" (Preenchido com o Azul Primário)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showJoinRoomDialog(context, ref),
                    icon: const Icon(Icons.login_rounded, color: Colors.white),
                    label: const Text(
                      'Entrar em Sala',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createDuelRoom(context, ref),
                    icon: Icon(
                      Icons.sports_martial_arts,
                      color: theme.colorScheme.secondary,
                    ),
                    label: const Text('Duelo 1v1'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      side: BorderSide(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context.go('/estatisticas'),
                    icon: Icon(
                      Icons.bar_chart_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    label: const Text('Estatísticas'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDuelRoom(BuildContext context, WidgetRef ref) async {
    final category = await _showDuelCategoryDialog(context);
    if (category == null || !context.mounted) return;

    final currentName = ref.read(sessionPlayerNameProvider);
    final playerName = await _askPlayerName(context, initial: currentName);
    if (playerName == null || !context.mounted) return;

    ref.read(sessionPlayerNameProvider.notifier).state = playerName;

    try {
      final playerId = ref.read(sessionPlayerIdProvider);
      final repository = ref.read(multiplayerRepositoryProvider);
      final roomId = await repository.createDuelRoom(
        hostId: playerId,
        hostName: playerName,
        categoryTitle: category,
      );

      ref.read(currentRoomIdProvider.notifier).state = roomId;

      if (!context.mounted) return;
      _showSnackBar(context, 'Duelo criado! PIN: $roomId');
      goToMultiplayerRoom(
        GoRouter.of(context),
        roomId,
        categoryTitle: category,
      );
      ref.read(analyticsServiceProvider).logRoomCreated(gameMode: 'duel');
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Erro ao criar duelo: $error');
    }
  }

  Future<String?> _showDuelCategoryDialog(BuildContext context) async {
    var category = RoomCategoryOptions.titles.first;
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Duelo 1v1'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '11 perguntas • 2 jogadores • link exclusivo /duelo/PIN',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: RoomCategoryOptions.titles
                    .map(
                      (title) => DropdownMenuItem(
                        value: title,
                        child: Text(title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => category = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(category),
              child: const Text('Criar Duelo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<String?> _askPlayerName(BuildContext context, {String? initial}) async {
    final controller = TextEditingController(text: initial);
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Seu nome na partida'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: João',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop(name);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom(BuildContext context, WidgetRef ref) async {
    final settings = await showRoomConfigDialog(context);
    if (settings == null || !context.mounted) return;

    final currentName = ref.read(sessionPlayerNameProvider);
    final playerName = await _askPlayerName(context, initial: currentName);
    if (playerName == null || !context.mounted) return;

    ref.read(sessionPlayerNameProvider.notifier).state = playerName;

    try {
      final playerId = ref.read(sessionPlayerIdProvider);
      final repository = ref.read(multiplayerRepositoryProvider);
      final roomId = await repository.createRoom(
        hostId: playerId,
        hostName: playerName,
        settings: settings,
      );

      ref.read(currentRoomIdProvider.notifier).state = roomId;

      if (!context.mounted) return;
      _showSnackBar(context, 'Sala criada! PIN: $roomId');
      goToMultiplayerRoom(
        GoRouter.of(context),
        roomId,
        categoryTitle: settings.categoryTitle,
      );
      ref.read(analyticsServiceProvider).logRoomCreated(
            gameMode: settings.gameMode.firestoreValue,
          );
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Erro ao criar sala: $error');
    }
  }

  void _showJoinRoomDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinController = TextEditingController();
    final nameController = TextEditingController(
      text: ref.read(sessionPlayerNameProvider),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.meeting_room, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Entrar na Sala'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insira o PIN de 6 dígitos e seu nome:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                decoration: InputDecoration(
                  hintText: 'Ex: 482901',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Seu nome',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final roomId = pinController.text.trim();
                final playerName = nameController.text.trim();

                if (roomId.length != 6 || playerName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informe um PIN válido e seu nome.'),
                    ),
                  );
                  return;
                }

                final router = GoRouter.of(context);
                final messenger = ScaffoldMessenger.of(context);

                Navigator.of(context).pop();

                ref.read(sessionPlayerNameProvider.notifier).state = playerName;

                try {
                  final playerId = ref.read(sessionPlayerIdProvider);
                  final repository = ref.read(multiplayerRepositoryProvider);
                  await repository.joinRoom(
                    roomId: roomId,
                    playerId: playerId,
                    playerName: playerName,
                  );

                  final room = await repository.getRoom(roomId);
                  ref.read(currentRoomIdProvider.notifier).state = roomId;
                  goToMultiplayerRoom(
                    router,
                    roomId,
                    categoryTitle: room.categoryTitle,
                  );
                  ref.read(analyticsServiceProvider).logRoomJoined(
                        gameMode: room.gameMode.firestoreValue,
                      );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('$error'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }
}
