import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../quiz/data/multiplayer_repository.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../quiz/data/multiplayer_navigation.dart';
import '../../quiz/domain/game_mode.dart';

import 'widgets/active_room_banner.dart';
import 'widgets/categories_section.dart';
import 'widgets/header_widget.dart';
import 'widgets/room_actions_card.dart';

/// Tela Inicial (Home) do Quiz SUD.
/// Organizada de forma responsiva para rodar no Chrome, Linux Desktop ou dispositivos móveis.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _handledJoinPin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final joinPin = GoRouterState.of(context).uri.queryParameters['join'];
    if (joinPin != null &&
        joinPin.length == 6 &&
        joinPin != _handledJoinPin) {
      _handledJoinPin = joinPin;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openJoinWithPin(joinPin);
      });
    }
  }

  Future<void> _openJoinWithPin(String pin) async {
    final currentName = ref.read(sessionPlayerNameProvider);
    final playerName = await _askJoinPlayerName(initial: currentName);
    if (playerName == null || !mounted) return;

    ref.read(sessionPlayerNameProvider.notifier).state = playerName;

    try {
      final playerId = ref.read(sessionPlayerIdProvider);
      final repository = ref.read(multiplayerRepositoryProvider);
      await repository.joinRoom(
        roomId: pin,
        playerId: playerId,
        playerName: playerName,
      );

      final room = await repository.getRoom(pin);
      ref.read(currentRoomIdProvider.notifier).state = pin;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Entrou na sala $pin!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      goToMultiplayerRoom(
        GoRouter.of(context),
        pin,
        categoryTitle: room.categoryTitle,
      );
      ref.read(analyticsServiceProvider).logRoomJoined(
            gameMode: room.gameMode.firestoreValue,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<String?> _askJoinPlayerName({String? initial}) async {
    final controller = TextEditingController(text: initial);
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Entrar na disputa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Seu nome',
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
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabeçalho Gradiente + Título
              const HeaderWidget(),

              // Espaço controlado para sobreposição visual do Card de Salas
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 800 ? size.width * 0.15 : 16.0,
                  ),
                  child: const RoomActionsCard(),
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width > 800 ? size.width * 0.15 : 16.0,
                ),
                child: const ActiveRoomBanner(),
              ),
              const SizedBox(height: 4),

              // 2. Título da seção de Categorias
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width > 800 ? size.width * 0.15 : 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Categorias de Estudo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trilhas adaptativas por tema — ou quiz clássico',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // 3. Grade ou Lista Responsiva de Categorias
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width > 800 ? size.width * 0.15 : 16.0,
                ),
                child: const CategoriesSection(),
              ),

              const SizedBox(height: 20),

              // Rodapé sutil com detalhe estético
              Center(
                child: Text(
                  'Liahona Quiz © 2026 • Preparando o Caminho',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
