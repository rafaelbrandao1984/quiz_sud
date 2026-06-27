/// Perfil de aprendizado por categoria (local).
class CategoryLearningProfile {
  final String categoryTitle;
  final bool diagnosticCompleted;
  final int level;
  final int totalAnswered;
  final int totalCorrect;

  const CategoryLearningProfile({
    required this.categoryTitle,
    this.diagnosticCompleted = false,
    this.level = 2,
    this.totalAnswered = 0,
    this.totalCorrect = 0,
  });

  double get accuracy =>
      totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  String get levelLabel => switch (level) {
        1 => 'Iniciante',
        3 => 'Avançado',
        _ => 'Intermediário',
      };

  factory CategoryLearningProfile.fromJson(Map<String, dynamic> json) {
    return CategoryLearningProfile(
      categoryTitle: json['categoryTitle'] as String,
      diagnosticCompleted: json['diagnosticCompleted'] as bool? ?? false,
      level: (json['level'] as num?)?.toInt() ?? 2,
      totalAnswered: (json['totalAnswered'] as num?)?.toInt() ?? 0,
      totalCorrect: (json['totalCorrect'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryTitle': categoryTitle,
      'diagnosticCompleted': diagnosticCompleted,
      'level': level,
      'totalAnswered': totalAnswered,
      'totalCorrect': totalCorrect,
    };
  }

  CategoryLearningProfile copyWith({
    bool? diagnosticCompleted,
    int? level,
    int? totalAnswered,
    int? totalCorrect,
  }) {
    return CategoryLearningProfile(
      categoryTitle: categoryTitle,
      diagnosticCompleted: diagnosticCompleted ?? this.diagnosticCompleted,
      level: level ?? this.level,
      totalAnswered: totalAnswered ?? this.totalAnswered,
      totalCorrect: totalCorrect ?? this.totalCorrect,
    );
  }

  /// Nível sugerido a partir do diagnóstico (5 perguntas).
  static int levelFromDiagnosticScore(int correct, int total) {
    if (total <= 0) return 2;
    final ratio = correct / total;
    if (ratio >= 0.8) return 3;
    if (ratio >= 0.4) return 2;
    return 1;
  }
}
