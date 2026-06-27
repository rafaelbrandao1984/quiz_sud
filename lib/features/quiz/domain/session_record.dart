/// Registro local de uma partida concluída.
class SessionRecord {
  final String id;
  final DateTime playedAt;
  final String modeLabel;
  final String categoryTitle;
  final int score;
  final int totalQuestions;
  final bool isPointsBased;
  final int? rank;
  final int? playerCount;

  const SessionRecord({
    required this.id,
    required this.playedAt,
    required this.modeLabel,
    required this.categoryTitle,
    required this.score,
    required this.totalQuestions,
    this.isPointsBased = false,
    this.rank,
    this.playerCount,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: json['id'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      modeLabel: json['modeLabel'] as String,
      categoryTitle: json['categoryTitle'] as String,
      score: (json['score'] as num).toInt(),
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      isPointsBased: json['isPointsBased'] as bool? ?? false,
      rank: (json['rank'] as num?)?.toInt(),
      playerCount: (json['playerCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playedAt': playedAt.toIso8601String(),
      'modeLabel': modeLabel,
      'categoryTitle': categoryTitle,
      'score': score,
      'totalQuestions': totalQuestions,
      'isPointsBased': isPointsBased,
      if (rank != null) 'rank': rank,
      if (playerCount != null) 'playerCount': playerCount,
    };
  }

  String get scoreLabel =>
      isPointsBased ? '$score pts' : '$score/$totalQuestions acertos';

  double get accuracy =>
      totalQuestions > 0 ? score / totalQuestions : 0;
}
