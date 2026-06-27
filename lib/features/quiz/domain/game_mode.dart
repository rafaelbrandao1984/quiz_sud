import 'room_settings.dart';

/// Modos de disputa multijogador.
enum GameMode {
  /// Todos respondem em paralelo — modo padrão (Arena Relâmpago).
  lightning,

  /// Dois jogadores, 11 perguntas — melhor pontuação vence.
  duel,

  /// Legado — salas antigas por turnos (não criável pela UI).
  turnBased,
}

/// Modos exibidos na UI de criação de sala.
const playableGameModes = [GameMode.lightning, GameMode.duel];

extension GameModeX on GameMode {
  String get label => switch (this) {
        GameMode.lightning => 'Arena Relâmpago',
        GameMode.duel => 'Duelo 1v1',
        GameMode.turnBased => 'Campeonato (descontinuado)',
      };

  String get description => switch (this) {
        GameMode.lightning =>
          'Todos respondem ao mesmo tempo. Pontos por velocidade e streak.',
        GameMode.duel =>
          'Você contra um amigo. 11 perguntas rápidas — quem pontuar mais vence.',
        GameMode.turnBased => 'Formato antigo — não disponível para novas salas.',
      };

  int get playerLimit => switch (this) {
        GameMode.duel => RoomConfigOptions.duelMaxPlayers,
        _ => RoomConfigOptions.maxPlayers,
      };

  bool get usesLightningEngine =>
      this == GameMode.lightning || this == GameMode.duel;

  static GameMode fromString(String? value) {
    return switch (value) {
      'duel' => GameMode.duel,
      'turn_based' => GameMode.turnBased,
      _ => GameMode.lightning,
    };
  }

  String get firestoreValue => switch (this) {
        GameMode.lightning => 'lightning',
        GameMode.duel => 'duel',
        GameMode.turnBased => 'turn_based',
      };
}

/// Fases de uma rodada no modo Arena Relâmpago.
enum GamePhase {
  question,
  reveal,
  embasamento,
}

extension GamePhaseX on GamePhase {
  static GamePhase fromString(String? value) {
    return switch (value) {
      'reveal' => GamePhase.reveal,
      'embasamento' => GamePhase.embasamento,
      _ => GamePhase.question,
    };
  }

  String get firestoreValue => switch (this) {
        GamePhase.question => 'question',
        GamePhase.reveal => 'reveal',
        GamePhase.embasamento => 'embasamento',
      };
}

/// Resposta de um jogador em uma rodada relâmpago.
class PlayerAnswer {
  final int answerIndex;
  final DateTime answeredAt;

  const PlayerAnswer({
    required this.answerIndex,
    required this.answeredAt,
  });

  factory PlayerAnswer.fromMap(Map<String, dynamic> map) {
    return PlayerAnswer(
      answerIndex: (map['answerIndex'] as num?)?.toInt() ?? -1,
      answeredAt: map['answeredAt'] is DateTime
          ? map['answeredAt'] as DateTime
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'answerIndex': answerIndex,
      'answeredAt': answeredAt,
    };
  }
}

/// Emoji enviado por um jogador durante a partida.
class PlayerReaction {
  final String playerId;
  final String playerName;
  final String emoji;

  const PlayerReaction({
    required this.playerId,
    required this.playerName,
    required this.emoji,
  });
}

/// Emojis disponíveis para reações ao vivo.
class LiveReactionOptions {
  static const List<String> emojis = ['👏', '🔥', '😮', '💪', '🙌'];
}
