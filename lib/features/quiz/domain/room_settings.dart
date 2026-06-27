import 'game_mode.dart';

/// Configurações definidas pelo host ao criar uma sala multijogador.
class RoomSettings {
  final String categoryTitle;
  final int questionCount;
  final int maxTimeSeconds;
  final GameMode gameMode;
  final int questionTimeSeconds;
  final int autoAdvanceSeconds;

  const RoomSettings({
    required this.categoryTitle,
    required this.questionCount,
    required this.maxTimeSeconds,
    this.gameMode = GameMode.lightning,
    this.questionTimeSeconds = 20,
    this.autoAdvanceSeconds = 12,
  });

  int get maxTimeMinutes => maxTimeSeconds ~/ 60;

  /// Rodadas completas por jogador quando a sala estiver cheia (modo turnos).
  int roundsPerPlayerAtFullRoom(int playerCount) {
    if (playerCount <= 0) return 0;
    return questionCount ~/ playerCount;
  }

  /// Estimativa de duração para Arena Relâmpago (~35s por pergunta).
  int get estimatedLightningMinutes {
    final secondsPerQuestion = questionTimeSeconds + autoAdvanceSeconds + 3;
    return ((questionCount * secondsPerQuestion) / 60).ceil();
  }
}

/// Categorias disponíveis para salas multijogador.
class RoomCategoryOptions {
  static const List<String> titles = [
    'Obras Padrão',
    'História da Igreja',
    'História da Igreja no Brasil',
    'Desafio Geral',
  ];
}

/// Limites e opções pré-definidas para o menu de criação de sala.
class RoomConfigOptions {
  static const int maxPlayers = 10;
  static const int duelMaxPlayers = 2;
  static const int duelQuestions = 11;
  static const int maxQuestions = 50;
  static const int maxDurationMinutes = 60;

  static const List<int> questionCounts = [10, 15, 20, 30, 40, 50];
  static const List<int> lightningQuestionCounts = [10, 15, 20];
  static const List<int> duelQuestionCounts = [11];
  static const List<int> durationMinutes = [15, 30, 45, 60];

  static int minutesToSeconds(int minutes) => minutes * 60;

  static String roundsHint(int questionCount, {int players = maxPlayers}) {
    final rounds = questionCount ~/ players;
    return 'Com $players jogadores: $rounds rodada(s) por jogador';
  }

  static String lightningDurationHint(int questionCount) {
    final settings = RoomSettings(
      categoryTitle: '',
      questionCount: questionCount,
      maxTimeSeconds: 0,
    );
    return '~${settings.estimatedLightningMinutes} min de disputa';
  }
}
