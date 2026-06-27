import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_functions_provider.dart';
import '../domain/learning_profile.dart';
import 'adaptive_question_selector.dart';

/// Modelo de Dados para representar as Perguntas do Quiz.
class QuizQuestion {
  /// Índice usado quando o gabarito não foi revelado (modos competitivos).
  static const int hiddenAnswerIndex = -1;

  final String id;
  final String questionText;
  final List<String> alternatives;
  final int correctAnswerIndex;
  final String embasamento;
  final String categoryTitle;

  const QuizQuestion({
    required this.id,
    required this.questionText,
    required this.alternatives,
    required this.correctAnswerIndex,
    required this.embasamento,
    required this.categoryTitle,
  });

  bool get isAnswerHidden => correctAnswerIndex == hiddenAnswerIndex;

  QuizQuestion withoutCorrectAnswer() {
    return QuizQuestion(
      id: id,
      questionText: questionText,
      alternatives: alternatives,
      correctAnswerIndex: hiddenAnswerIndex,
      embasamento: embasamento,
      categoryTitle: categoryTitle,
    );
  }

  /// Primeira linha do embasamento — ideal para leitura rápida na Arena.
  String get embasamentoCurto {
    final firstLine = embasamento.split('\n').first.trim();
    if (firstLine.length <= 120) return firstLine;
    return '${firstLine.substring(0, 117)}...';
  }

  factory QuizQuestion.fromCallableMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] as String,
      questionText: map['questionText'] as String,
      alternatives: List<String>.from(map['alternatives'] as List),
      correctAnswerIndex: (map['correctAnswerIndex'] as num?)?.toInt() ?? 0,
      embasamento: map['embasamento'] as String? ??
          'Embasamento histórico não disponível para esta questão.',
      categoryTitle: map['categoryTitle'] as String? ?? 'Desafio Geral',
    );
  }
}

/// Repositório responsável por buscar perguntas via Cloud Functions.
class QuizRepository {
  static const String desafioGeralTitle = 'Desafio Geral';
  static const int questionsPerSession = 15;
  static const int diagnosticQuestionCount = 5;

  final FirebaseFunctions _functions;
  final AdaptiveQuestionSelector _selector;

  QuizRepository(this._functions, [AdaptiveQuestionSelector? selector])
      : _selector = selector ?? const AdaptiveQuestionSelector();

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  List<QuizQuestion> _parseQuestions(Map<String, dynamic> payload) {
    final raw = payload['questions'] as List<dynamic>? ?? [];
    return raw
        .map(
          (item) => QuizQuestion.fromCallableMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Busca perguntas de uma sala multijogador (gabarito omitido no Relâmpago/Duelo).
  Future<List<QuizQuestion>> fetchRoomQuestions(String roomId) async {
    final payload = await _call('fetchRoomQuestions', {'roomId': roomId});
    return _parseQuestions(payload);
  }

  /// Consulta perguntas via Function, embaralha e retorna o limite solicitado.
  Future<List<QuizQuestion>> fetchQuestions(
    String categoryTitle, {
    int? limit,
    int? shuffleSeed,
  }) async {
    final sessionLimit = limit ?? questionsPerSession;
    final payload = await _call('fetchSoloQuestions', {
      'categoryTitle': categoryTitle,
      'limit': sessionLimit,
      'shuffleSeed': ?shuffleSeed,
    });
    return _parseQuestions(payload);
  }

  /// Diagnóstico inicial: 5 perguntas aleatórias da categoria.
  Future<List<QuizQuestion>> fetchDiagnosticQuestions(String categoryTitle) async {
    return fetchQuestions(
      categoryTitle,
      limit: diagnosticQuestionCount,
    );
  }

  /// Trilha adaptativa ponderada pelo nível do jogador.
  Future<List<QuizQuestion>> fetchAdaptiveQuestions({
    required String categoryTitle,
    required CategoryLearningProfile profile,
    int? limit,
    int? shuffleSeed,
  }) async {
    final sessionLimit = limit ?? questionsPerSession;
    final pool = await fetchQuestions(
      categoryTitle,
      limit: 100,
      shuffleSeed: shuffleSeed ?? profile.level * 1000,
    );
    return _selector.pick(
      pool: pool,
      profile: profile,
      limit: sessionLimit,
      seed: shuffleSeed ?? profile.level * 1000,
    );
  }
}

/// Provedor para injetar o QuizRepository.
final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  final functions = ref.watch(firebaseFunctionsProvider);
  return QuizRepository(functions);
});
