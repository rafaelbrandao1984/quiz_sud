import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_mode.dart';
import 'room_settings.dart';

/// Jogador participante de uma sala multijogador.
class QuizPlayer {
  final String id;
  final String name;
  final int score;

  const QuizPlayer({
    required this.id,
    required this.name,
    this.score = 0,
  });

  factory QuizPlayer.fromMap(Map<String, dynamic> map) {
    return QuizPlayer(
      id: map['id'] as String,
      name: map['name'] as String,
      score: (map['score'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'score': score,
    };
  }

  QuizPlayer copyWith({String? name, int? score}) {
    return QuizPlayer(
      id: id,
      name: name ?? this.name,
      score: score ?? this.score,
    );
  }
}

/// Sala de quiz em tempo real sincronizada via Firestore.
class QuizRoom {
  static const int defaultMaxTimeSeconds = 3600;
  static const int defaultQuestionTimeSeconds = 20;
  static const int defaultAutoAdvanceSeconds = 12;
  static const int maxPlayers = RoomConfigOptions.maxPlayers;

  final String roomId;
  final String hostId;
  final List<QuizPlayer> players;
  final int currentQuestionIndex;
  final String status;
  final DateTime createdAt;
  final int maxTimeSeconds;
  final DateTime? startTime;
  final int currentPlayerTurnIndex;
  final bool allAnswersCollected;
  final List<String> answeredPlayerIds;
  final String categoryTitle;
  final int questionCount;
  final List<String> questionIds;
  final int? currentTurnAnswerIndex;

  // Arena Relâmpago
  final GameMode gameMode;
  final GamePhase phase;
  final DateTime? questionDeadline;
  final Map<String, PlayerAnswer> playerAnswers;
  final DateTime? autoAdvanceAt;
  final Map<String, int> streaks;
  final int questionTimeSeconds;
  final int autoAdvanceSeconds;
  final int? correctAnswerIndex;
  final Map<String, String> activeReactions;
  final DateTime? finishedAt;

  const QuizRoom({
    required this.roomId,
    required this.hostId,
    required this.players,
    required this.currentQuestionIndex,
    required this.status,
    required this.createdAt,
    this.maxTimeSeconds = defaultMaxTimeSeconds,
    this.startTime,
    this.currentPlayerTurnIndex = 0,
    this.allAnswersCollected = false,
    this.answeredPlayerIds = const [],
    this.categoryTitle = 'Desafio Geral',
    this.questionCount = 15,
    this.questionIds = const [],
    this.currentTurnAnswerIndex,
    this.gameMode = GameMode.lightning,
    this.phase = GamePhase.question,
    this.questionDeadline,
    this.playerAnswers = const {},
    this.autoAdvanceAt,
    this.streaks = const {},
    this.questionTimeSeconds = defaultQuestionTimeSeconds,
    this.autoAdvanceSeconds = defaultAutoAdvanceSeconds,
    this.correctAnswerIndex,
    this.activeReactions = const {},
    this.finishedAt,
  });

  int get playerLimit => gameMode.playerLimit;
  bool get isDuel => gameMode == GameMode.duel;
  bool get isLightning => gameMode.usesLightningEngine;
  bool get isTurnBased => gameMode == GameMode.turnBased;

  int get questionSecondsRemaining {
    if (questionDeadline == null) return questionTimeSeconds;
    final remaining = questionDeadline!.difference(DateTime.now()).inSeconds;
    return remaining.clamp(0, questionTimeSeconds);
  }

  int get autoAdvanceSecondsRemaining {
    if (autoAdvanceAt == null) return autoAdvanceSeconds;
    final remaining = autoAdvanceAt!.difference(DateTime.now()).inSeconds;
    return remaining.clamp(0, autoAdvanceSeconds);
  }

  bool get isQuestionDeadlineUp =>
      questionDeadline != null &&
      DateTime.now().isAfter(questionDeadline!);

  bool get isAutoAdvanceDue =>
      autoAdvanceAt != null && DateTime.now().isAfter(autoAdvanceAt!);

  bool get allPlayersAnswered =>
      players.isNotEmpty &&
      players.every((player) => playerAnswers.containsKey(player.id));

  int get responsesCount => playerAnswers.length;

  DateTime? get globalEndTime {
    if (startTime == null) return null;
    return startTime!.add(Duration(seconds: maxTimeSeconds));
  }

  int get globalSecondsRemaining {
    final endTime = globalEndTime;
    if (endTime == null) return maxTimeSeconds;
    final remaining = endTime.difference(DateTime.now()).inSeconds;
    return remaining.clamp(0, maxTimeSeconds);
  }

  bool get isGlobalTimeUp => globalSecondsRemaining <= 0;

  factory QuizRoom.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final playersRaw = data['players'] as List<dynamic>? ?? [];
    final answeredRaw = data['answeredPlayerIds'] as List<dynamic>? ?? [];
    final questionIdsRaw = data['questionIds'] as List<dynamic>? ?? [];
    final playerAnswersRaw =
        data['playerAnswers'] as Map<String, dynamic>? ?? {};
    final streaksRaw = data['streaks'] as Map<String, dynamic>? ?? {};
    final reactionsRaw = data['activeReactions'] as Map<String, dynamic>? ?? {};
    final activeReactions = reactionsRaw.map(
      (key, value) => MapEntry(key, value as String),
    );

    final playerAnswers = <String, PlayerAnswer>{};
    for (final entry in playerAnswersRaw.entries) {
      final answerMap = Map<String, dynamic>.from(entry.value as Map);
      final answeredAt = answerMap['answeredAt'];
      playerAnswers[entry.key] = PlayerAnswer(
        answerIndex: (answerMap['answerIndex'] as num?)?.toInt() ?? -1,
        answeredAt: answeredAt is Timestamp
            ? answeredAt.toDate()
            : DateTime.now(),
      );
    }

    final streaks = <String, int>{};
    for (final entry in streaksRaw.entries) {
      streaks[entry.key] = (entry.value as num?)?.toInt() ?? 0;
    }

    return QuizRoom(
      roomId: data['roomId'] as String? ?? doc.id,
      hostId: data['hostId'] as String,
      players: playersRaw
          .map(
            (player) =>
                QuizPlayer.fromMap(Map<String, dynamic>.from(player as Map)),
          )
          .toList(),
      currentQuestionIndex: (data['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'waiting',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxTimeSeconds:
          (data['maxTimeSeconds'] as num?)?.toInt() ?? defaultMaxTimeSeconds,
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      currentPlayerTurnIndex:
          (data['currentPlayerTurnIndex'] as num?)?.toInt() ?? 0,
      allAnswersCollected: data['allAnswersCollected'] as bool? ?? false,
      answeredPlayerIds: answeredRaw.map((id) => id as String).toList(),
      categoryTitle: data['categoryTitle'] as String? ?? 'Desafio Geral',
      questionCount: (data['questionCount'] as num?)?.toInt() ?? 15,
      questionIds: questionIdsRaw.map((id) => id as String).toList(),
      currentTurnAnswerIndex: (data['currentTurnAnswerIndex'] as num?)?.toInt(),
      gameMode: GameModeX.fromString(data['gameMode'] as String?),
      phase: GamePhaseX.fromString(data['phase'] as String?),
      questionDeadline: (data['questionDeadline'] as Timestamp?)?.toDate(),
      playerAnswers: playerAnswers,
      autoAdvanceAt: (data['autoAdvanceAt'] as Timestamp?)?.toDate(),
      streaks: streaks,
      questionTimeSeconds:
          (data['questionTimeSeconds'] as num?)?.toInt() ??
              defaultQuestionTimeSeconds,
      autoAdvanceSeconds:
          (data['autoAdvanceSeconds'] as num?)?.toInt() ??
              defaultAutoAdvanceSeconds,
      correctAnswerIndex: (data['correctAnswerIndex'] as num?)?.toInt(),
      activeReactions: activeReactions,
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'hostId': hostId,
      'players': players.map((player) => player.toMap()).toList(),
      'currentQuestionIndex': currentQuestionIndex,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'maxTimeSeconds': maxTimeSeconds,
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime!),
      'currentPlayerTurnIndex': currentPlayerTurnIndex,
      'allAnswersCollected': allAnswersCollected,
      'answeredPlayerIds': answeredPlayerIds,
      'categoryTitle': categoryTitle,
      'questionCount': questionCount,
      'questionIds': questionIds,
      if (currentTurnAnswerIndex != null)
        'currentTurnAnswerIndex': currentTurnAnswerIndex,
      'gameMode': gameMode.firestoreValue,
      'phase': phase.firestoreValue,
      if (questionDeadline != null)
        'questionDeadline': Timestamp.fromDate(questionDeadline!),
      'playerAnswers': playerAnswers.map(
        (key, value) => MapEntry(
          key,
          {
            'answerIndex': value.answerIndex,
            'answeredAt': Timestamp.fromDate(value.answeredAt),
          },
        ),
      ),
      if (autoAdvanceAt != null)
        'autoAdvanceAt': Timestamp.fromDate(autoAdvanceAt!),
      'streaks': streaks,
      'questionTimeSeconds': questionTimeSeconds,
      'autoAdvanceSeconds': autoAdvanceSeconds,
      if (correctAnswerIndex != null) 'correctAnswerIndex': correctAnswerIndex,
      if (activeReactions.isNotEmpty) 'activeReactions': activeReactions,
      if (finishedAt != null) 'finishedAt': Timestamp.fromDate(finishedAt!),
    };
  }

  QuizRoom copyWith({
    List<QuizPlayer>? players,
    int? currentQuestionIndex,
    String? status,
    DateTime? startTime,
    int? currentPlayerTurnIndex,
    bool? allAnswersCollected,
    List<String>? answeredPlayerIds,
    GamePhase? phase,
    DateTime? questionDeadline,
    Map<String, PlayerAnswer>? playerAnswers,
    DateTime? autoAdvanceAt,
    Map<String, int>? streaks,
    int? correctAnswerIndex,
  }) {
    return QuizRoom(
      roomId: roomId,
      hostId: hostId,
      players: players ?? this.players,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      status: status ?? this.status,
      createdAt: createdAt,
      maxTimeSeconds: maxTimeSeconds,
      startTime: startTime ?? this.startTime,
      currentPlayerTurnIndex:
          currentPlayerTurnIndex ?? this.currentPlayerTurnIndex,
      allAnswersCollected: allAnswersCollected ?? this.allAnswersCollected,
      answeredPlayerIds: answeredPlayerIds ?? this.answeredPlayerIds,
      categoryTitle: categoryTitle,
      questionCount: questionCount,
      questionIds: questionIds,
      currentTurnAnswerIndex: currentTurnAnswerIndex,
      gameMode: gameMode,
      phase: phase ?? this.phase,
      questionDeadline: questionDeadline ?? this.questionDeadline,
      playerAnswers: playerAnswers ?? this.playerAnswers,
      autoAdvanceAt: autoAdvanceAt ?? this.autoAdvanceAt,
      streaks: streaks ?? this.streaks,
      questionTimeSeconds: questionTimeSeconds,
      autoAdvanceSeconds: autoAdvanceSeconds,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
    );
  }
}
