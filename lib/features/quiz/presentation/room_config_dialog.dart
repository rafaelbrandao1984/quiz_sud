import 'package:flutter/material.dart';

import '../domain/game_mode.dart';
import '../domain/room_settings.dart';

/// Diálogo para o host configurar categoria e parâmetros da Arena Relâmpago.
Future<RoomSettings?> showRoomConfigDialog(BuildContext context) {
  final theme = Theme.of(context);
  var category = RoomCategoryOptions.titles.first;
  var questionCount = 15;

  return showDialog<RoomSettings>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          const questionOptions = RoomConfigOptions.lightningQuestionCounts;

          if (!questionOptions.contains(questionCount)) {
            questionCount = questionOptions.first;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: theme.colorScheme.secondary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Configurar Arena')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Arena Relâmpago • Até ${RoomConfigOptions.maxPlayers} jogadores • '
                      '20 s por pergunta',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Categoria',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
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
                  const SizedBox(height: 20),
                  Text(
                    'Quantidade de perguntas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: questionCount,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: questionOptions
                        .map(
                          (count) => DropdownMenuItem(
                            value: count,
                            child: Text('$count perguntas'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => questionCount = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    RoomConfigOptions.lightningDurationHint(questionCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    RoomSettings(
                      categoryTitle: category,
                      questionCount: questionCount,
                      maxTimeSeconds: RoomConfigOptions.minutesToSeconds(
                        (questionCount * 35 / 60).ceil().clamp(15, 60),
                      ),
                      gameMode: GameMode.lightning,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );
    },
  );
}
