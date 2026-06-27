import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/quiz_room.dart';

/// Tela de Encerramento e Resultados.
class ResultsView extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final String categoryTitle;
  final VoidCallback onRestart;
  final List<QuizPlayer>? players;
  final String? roomId;
  final bool isPointsBased;
  final String? levelLabel;
  final bool isDiagnosticResult;

  const ResultsView({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.categoryTitle,
    required this.onRestart,
    this.players,
    this.roomId,
    this.isPointsBased = false,
    this.levelLabel,
    this.isDiagnosticResult = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final correctCount = isPointsBased ? null : score;
    final percentage = isPointsBased || totalQuestions == 0
        ? 0.0
        : (correctCount! / totalQuestions) * 100;

    // Textos personalizados dependendo do desempenho
    String message = 'Bom trabalho!';
    String description =
        'Continue estudando e praticando para aprofundar seu conhecimento.';
    IconData feedbackIcon = Icons.stars_rounded;
    Color feedbackColor = theme.colorScheme.secondary;

    if (percentage == 100) {
      message = 'Excelente!';
      description =
          'Você gabaritou todas as perguntas! Conhecimento digno de um mestre.';
      feedbackIcon = Icons.emoji_events_rounded;
      feedbackColor = Colors.amber.shade700;
    } else if (!isPointsBased && percentage < 50) {
      message = 'Continue Praticando!';
      description =
          'O aprendizado é uma jornada. Revise os temas e tente novamente!';
      feedbackIcon = Icons.menu_book_rounded;
      feedbackColor = theme.colorScheme.primary;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: size.width > 800 ? size.width * 0.25 : 24.0,
              vertical: 32,
            ),
            child: Card(
              elevation: 4,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 40.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Círculo decorado com ícone de troféu/estrela
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: feedbackColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          feedbackIcon,
                          color: feedbackColor,
                          size: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título dos resultados
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 36),

                    if (levelLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              color: theme.colorScheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nível na trilha: $levelLabel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (players != null && players!.isNotEmpty) ...[
                      Text(
                        'Ranking Final',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (roomId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Sala $roomId',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      ...([...players!]..sort((a, b) => b.score.compareTo(a.score)))
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final player = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.04,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                '${player.score} pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],

                    // Painel de estatísticas pontuadas
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.04,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Categoria',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                categoryTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1.5,
                            height: 40,
                            color: Colors.grey.shade300,
                          ),
                          Column(
                            children: [
                              Text(
                                'Desempenho',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isPointsBased
                                    ? '$score pts'
                                    : '$score / $totalQuestions acertos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: feedbackColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Botões de ação pós-jogo
                    ElevatedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Jogar Novamente',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Retorna ao menu inicial da HomeScreen
                        context.go('/'); // Navegação corrigida
                      },
                      icon: Icon(
                        Icons.home_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      label: const Text(
                        'Voltar ao Início',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
