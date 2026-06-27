import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/analytics/analytics_service.dart';
import '../data/quiz_repository.dart';
import '../data/multiplayer_repository.dart';
import '../data/multiplayer_navigation.dart';
import '../data/learning_profile_repository.dart';
import '../data/session_history_repository.dart';
import '../domain/game_mode.dart';
import '../domain/learning_profile.dart';
import '../domain/quiz_room.dart';
import '../domain/session_record.dart';
import 'package:go_router/go_router.dart';

import 'widgets/alternative_button.dart';
import 'widgets/lobby_setting_row.dart';
import 'widgets/player_ranking_panel.dart';
import 'widgets/player_ranking_sidebar.dart';
import 'widgets/results_view.dart';

/// Tela de Jogo (Quiz Screen) que gerencia o fluxo de perguntas, alternativas e cronômetro.
class QuizScreen extends ConsumerStatefulWidget {
  final String categoryTitle;
  final String? roomId;
  final bool isAdaptiveMode;

  const QuizScreen({
    super.key,
    this.categoryTitle = '',
    this.roomId,
    this.isAdaptiveMode = false,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool get _isMultiplayer => widget.roomId != null;

  // Referência do Future criada uma única vez no initState (modo solo)
  Future<List<QuizQuestion>>? _questionsFuture;
  Future<List<QuizQuestion>>? _multiplayerQuestionsFuture;
  String? _loadedQuestionIdsKey;

  // Lista de perguntas que será preenchida com base no repositório
  List<QuizQuestion> _questions = [];

  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _isAnswered = false;
  bool _isFinished = false;
  int _lastSyncedQuestionIndex = -1;
  GamePhase? _lastSyncedPhase;
  bool _hasSubmittedLightningAnswer = false;
  bool _isProcessingPhase = false;
  bool _historyRecorded = false;
  bool _analyticsStartedLogged = false;
  final Set<int> _recordedLightningQuestions = {};
  QuizRoom? _timerRoom;
  bool _isDiagnosticPhase = false;
  bool _awaitingAdaptiveStart = false;
  String? _suggestedLevelLabel;
  String? _adaptiveLevelLabel;

  // Lógica do cronômetro
  Timer? _timer;
  static const int _soloQuestionDurationSeconds = 60;
  int _activeQuestionDurationSeconds = _soloQuestionDurationSeconds;
  int _secondsRemaining = _soloQuestionDurationSeconds;
  int _globalSecondsRemaining = QuizRoom.defaultMaxTimeSeconds;
  DateTime? _roomStartTime;
  int _roomMaxTimeSeconds = QuizRoom.defaultMaxTimeSeconds;

  @override
  void initState() {
    super.initState();
    if (!_isMultiplayer) {
      _questionsFuture = widget.isAdaptiveMode
          ? _loadAdaptiveSession()
          : _fetchQuestions(widget.categoryTitle);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Consulta perguntas no Firestore.
  Future<List<QuizQuestion>> _fetchQuestions(
    String categoryTitle, {
    int? limit,
  }) async {
    final repository = ref.read(quizRepositoryProvider);
    return repository.fetchQuestions(categoryTitle, limit: limit);
  }

  Future<List<QuizQuestion>> _loadAdaptiveSession() async {
    final profileRepo = await ref.read(learningProfileRepositoryProvider.future);
    final profile = profileRepo.getProfile(widget.categoryTitle);

    if (!profile.diagnosticCompleted) {
      _isDiagnosticPhase = true;
      return ref
          .read(quizRepositoryProvider)
          .fetchDiagnosticQuestions(widget.categoryTitle);
    }

    _adaptiveLevelLabel = profile.levelLabel;
    return _fetchAdaptiveQuestions(profile);
  }

  Future<List<QuizQuestion>> _fetchAdaptiveQuestions(
    CategoryLearningProfile profile,
  ) {
    return ref.read(quizRepositoryProvider).fetchAdaptiveQuestions(
          categoryTitle: widget.categoryTitle,
          profile: profile,
        );
  }

  Future<void> _recordAdaptiveProgress() async {
    if (!widget.isAdaptiveMode || _isDiagnosticPhase) return;

    final profileRepo = await ref.read(learningProfileRepositoryProvider.future);
    await profileRepo.recordSessionResult(
      categoryTitle: widget.categoryTitle,
      correct: _score,
      total: _questions.length,
    );
  }

  Future<void> _finishSession({QuizRoom? room}) async {
    await _recordAdaptiveProgress();
    await _recordSessionHistory(room: room);
  }

  Future<void> _recordSessionHistory({QuizRoom? room}) async {
    if (_historyRecorded) return;
    _historyRecorded = true;

    final repo = await ref.read(sessionHistoryRepositoryProvider.future);
    final playerId = ref.read(sessionPlayerIdProvider);

    String modeLabel;
    int score;
    bool isPointsBased;
    int? rank;
    int? playerCount;
    final totalQuestions = _questions.isNotEmpty
        ? _questions.length
        : (room?.questionCount ?? 0);

    if (room != null) {
      modeLabel = room.isDuel ? 'Duelo' : 'Arena';
      final matching = room.players.where((p) => p.id == playerId);
      final player = matching.isEmpty
          ? QuizPlayer(id: playerId, name: 'Jogador')
          : matching.first;
      score = player.score;
      isPointsBased = room.isLightning;
      playerCount = room.players.length;
      final sorted = [...room.players]..sort((a, b) => b.score.compareTo(a.score));
      rank = sorted.indexWhere((p) => p.id == playerId) + 1;
    } else if (widget.isAdaptiveMode) {
      modeLabel = 'Trilha';
      score = _score;
      isPointsBased = false;
    } else {
      modeLabel = 'Solo';
      score = _score;
      isPointsBased = false;
    }

    await repo.addRecord(
      SessionRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}_$playerId',
        playedAt: DateTime.now(),
        modeLabel: modeLabel,
        categoryTitle: room?.categoryTitle ?? widget.categoryTitle,
        score: score,
        totalQuestions: totalQuestions,
        isPointsBased: isPointsBased,
        rank: rank,
        playerCount: playerCount,
      ),
    );
    ref.invalidate(sessionHistoryRecordsProvider);
  }

  Future<void> _finishDiagnosticPhase() async {
    final profileRepo = await ref.read(learningProfileRepositoryProvider.future);
    await profileRepo.recordDiagnostic(
      categoryTitle: widget.categoryTitle,
      correct: _score,
      total: _questions.length,
    );
    final profile = profileRepo.getProfile(widget.categoryTitle);

    if (!mounted) return;
    setState(() {
      _awaitingAdaptiveStart = true;
      _suggestedLevelLabel = profile.levelLabel;
      _isAnswered = false;
      _selectedAnswerIndex = null;
    });
  }

  Future<void> _startAdaptivePhase() async {
    final profileRepo = await ref.read(learningProfileRepositoryProvider.future);
    final profile = profileRepo.getProfile(widget.categoryTitle);
    final questions = await _fetchAdaptiveQuestions(profile);

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _questionsFuture = Future.value(questions);
      _awaitingAdaptiveStart = false;
      _isDiagnosticPhase = false;
      _adaptiveLevelLabel = profile.levelLabel;
      _currentQuestionIndex = 0;
      _score = 0;
      _isFinished = false;
    });
    _startTimer();
  }

  void _recordLightningQuestionResult(QuizRoom room, QuizQuestion question) {
    _recordedLightningQuestions.add(room.currentQuestionIndex);
  }

  void _ensureMultiplayerQuestionsFuture(QuizRoom room) {
    if (room.questionIds.isEmpty) return;

    final idsKey = room.questionIds.join('|');
    if (_loadedQuestionIdsKey == idsKey && _multiplayerQuestionsFuture != null) {
      return;
    }

    _loadedQuestionIdsKey = idsKey;
    _questions = [];
    _multiplayerQuestionsFuture = ref
        .read(quizRepositoryProvider)
        .fetchRoomQuestions(widget.roomId!);
  }

  int _displayCorrectIndex(QuizRoom? room, QuizQuestion question) {
    if (room != null &&
        room.isLightning &&
        room.correctAnswerIndex != null &&
        (room.phase == GamePhase.reveal ||
            room.phase == GamePhase.embasamento)) {
      return room.correctAnswerIndex!;
    }
    return question.correctAnswerIndex;
  }

  void _updateGlobalRemaining() {
    if (_roomStartTime == null) return;
    final endTime =
        _roomStartTime!.add(Duration(seconds: _roomMaxTimeSeconds));
    _globalSecondsRemaining =
        endTime.difference(DateTime.now()).inSeconds.clamp(0, _roomMaxTimeSeconds);
  }

  /// Inicia o Timer regressivo para a pergunta atual.
  void _startTimer({QuizRoom? room}) {
    unawaited(_logQuizStarted(room: room));
    _timer?.cancel();
    _timerRoom = room;

    if (room != null) {
      _roomStartTime = room.startTime;
      _roomMaxTimeSeconds = room.maxTimeSeconds;
    }

    final duration = _questionDurationForRoom(room);
    final initialSeconds = room != null && room.isLightning
        ? room.questionSecondsRemaining
        : duration;

    setState(() {
      _activeQuestionDurationSeconds = duration;
      _secondsRemaining = initialSeconds;
      if (!_isMultiplayer) {
        _isAnswered = false;
        _selectedAnswerIndex = null;
      }
      _updateGlobalRemaining();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final room = _timerRoom;
      if (room == null) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _handleTimeOut();
        }
        return;
      }

      setState(() {
        if (_isMultiplayer && room.isLightning) {
          _secondsRemaining = room.questionSecondsRemaining;
        } else if (_secondsRemaining > 0) {
          _secondsRemaining--;
        }
        if (_isMultiplayer) {
          _updateGlobalRemaining();
        }
      });

      if (_isMultiplayer && _globalSecondsRemaining <= 0) {
        timer.cancel();
        _handleGlobalTimeUp(room);
        return;
      }

      if (_isMultiplayer && room.isLightning) {
        _handleLightningPhaseTick(room);
        return;
      }

      if (_secondsRemaining <= 0) {
        timer.cancel();
        _handleTimeOut(room: room);
      }
    });
  }

  int _questionDurationForRoom(QuizRoom? room) {
    if (room != null && room.isLightning) {
      return room.questionTimeSeconds;
    }
    return _soloQuestionDurationSeconds;
  }

  Future<void> _handleLightningPhaseTick(QuizRoom room) async {
    if (_isProcessingPhase || room.status != 'playing') return;

    final shouldTick = (room.phase == GamePhase.question &&
            room.isQuestionDeadlineUp &&
            !room.allAnswersCollected) ||
        (room.phase == GamePhase.embasamento && room.isAutoAdvanceDue);

    if (!shouldTick) return;

    _isProcessingPhase = true;
    try {
      await ref.read(multiplayerRepositoryProvider).processLightningTick(
            roomId: widget.roomId!,
          );
    } finally {
      _isProcessingPhase = false;
    }
  }

  Future<void> _handleGlobalTimeUp(QuizRoom room) async {
    if (_isFinished) return;

    if (room.isLightning) {
      await ref.read(multiplayerRepositoryProvider).processLightningTick(
            roomId: widget.roomId!,
          );
    }
  }

  /// Lida com o esgotamento do tempo regulamentar.
  void _handleTimeOut({QuizRoom? room}) {
    if (_isMultiplayer && room != null && !room.isLightning) {
      return;
    }

    setState(() {
      _isAnswered = true;
      _selectedAnswerIndex = -1;
    });

    if (_isMultiplayer && room != null) {
      if (room.isLightning && room.phase == GamePhase.question) {
        ref.read(multiplayerRepositoryProvider).processLightningTick(
              roomId: widget.roomId!,
            );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.timer_off_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Tempo Esgotado!'),
          ],
        ),
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Registra a resposta selecionada pelo usuário.
  void _onAnswerSelected(int index, QuizRoom? room) {
    if (_isAnswered && !(room?.isLightning == true && room?.phase == GamePhase.question)) {
      return;
    }
    if (_isMultiplayer && room != null && room.isLightning) {
      if (room.phase != GamePhase.question || _hasSubmittedLightningAnswer) {
        return;
      }

      setState(() {
        _hasSubmittedLightningAnswer = true;
        _selectedAnswerIndex = index;
      });

      ref.read(multiplayerRepositoryProvider).submitLightningAnswer(
            roomId: widget.roomId!,
            playerId: ref.read(sessionPlayerIdProvider),
            answerIndex: index,
          );
      return;
    }

    if (_isMultiplayer) return;

    _timer?.cancel();
    final questionIndex =
        _isMultiplayer && room != null ? room.currentQuestionIndex : _currentQuestionIndex;
    final isCorrect =
        index == _questions[questionIndex].correctAnswerIndex;

    setState(() {
      _isAnswered = true;
      _selectedAnswerIndex = index;
      if (isCorrect) {
        _score++;
      }
    });

    if (_isMultiplayer && room != null) {
      return;
    }
  }

  int _localPlayerIndex(QuizRoom room) {
    final playerId = ref.read(sessionPlayerIdProvider);
    return room.players.indexWhere((player) => player.id == playerId);
  }

  void _syncRoomState(QuizRoom room) {
    if (!mounted) return;

    _timerRoom = room;

    if (room.isGlobalTimeUp && room.status == 'playing') {
      _handleGlobalTimeUp(room);
      return;
    }

    final playerId = ref.read(sessionPlayerIdProvider);
    final matching = room.players.where((p) => p.id == playerId);
    final player = matching.isEmpty ? null : matching.first;
    final syncedScore = player?.score ?? _score;
    final questionChanged = room.status == 'playing' &&
        room.currentQuestionIndex != _lastSyncedQuestionIndex;
    final phaseChanged =
        room.isLightning && room.phase != _lastSyncedPhase;
    final shouldFinish = room.status == 'finished';

    if (syncedScore == _score &&
        !questionChanged &&
        !phaseChanged &&
        (!shouldFinish || _isFinished) &&
        _globalSecondsRemaining == room.globalSecondsRemaining &&
        (!room.isLightning ||
            _secondsRemaining == room.questionSecondsRemaining ||
            room.phase != GamePhase.question)) {
      if (room.isLightning) {
        _handleLightningPhaseTick(room);
      }
      return;
    }

    setState(() {
      if (syncedScore != _score) {
        _score = syncedScore;
      }
      _globalSecondsRemaining = room.globalSecondsRemaining;
      _roomStartTime = room.startTime;
      _roomMaxTimeSeconds = room.maxTimeSeconds;

      if (questionChanged) {
        _currentQuestionIndex = room.currentQuestionIndex;
        _lastSyncedQuestionIndex = room.currentQuestionIndex;
        _lastSyncedPhase = room.phase;
        _isAnswered = false;
        _selectedAnswerIndex = null;
        _hasSubmittedLightningAnswer = false;
      } else if (phaseChanged) {
        _lastSyncedPhase = room.phase;
        if (room.phase == GamePhase.question) {
          _hasSubmittedLightningAnswer = false;
          _selectedAnswerIndex = null;
          _isAnswered = false;
        } else if (room.phase == GamePhase.reveal ||
            room.phase == GamePhase.embasamento) {
          _isAnswered = true;
          final localAnswer = room.playerAnswers[playerId];
          if (localAnswer != null) {
            _selectedAnswerIndex = localAnswer.answerIndex;
          }
          if (_questions.isNotEmpty) {
            final questionIndex =
                room.currentQuestionIndex.clamp(0, _questions.length - 1);
            _recordLightningQuestionResult(room, _questions[questionIndex]);
          }
        }
      } else if (room.isLightning &&
          room.playerAnswers.containsKey(playerId) &&
          room.phase == GamePhase.question) {
        _hasSubmittedLightningAnswer = true;
        _selectedAnswerIndex = room.playerAnswers[playerId]!.answerIndex;
      }

      if (room.isLightning) {
        _activeQuestionDurationSeconds = room.questionTimeSeconds;
        if (room.phase == GamePhase.question) {
          _secondsRemaining = room.questionSecondsRemaining;
        }
      }

      if (shouldFinish) {
        if (!_isFinished) {
          _completeSession(room: room);
        }
      }
    });

    if ((questionChanged ||
            (phaseChanged && room.phase == GamePhase.question)) &&
        !_isFinished &&
        room.isLightning &&
        room.phase == GamePhase.question) {
      _startTimer(room: room);
    } else if (room.isLightning &&
        !_isFinished &&
        room.status == 'playing' &&
        (_timer == null || !_timer!.isActive)) {
      _startTimer(room: room);
    }

    _handleLightningPhaseTick(room);
  }

  bool _isHost(QuizRoom room) {
    return room.hostId == ref.read(sessionPlayerIdProvider);
  }

  Future<void> _startMultiplayerGame() async {
    try {
      await ref.read(multiplayerRepositoryProvider).startGame(widget.roomId!);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _completeSession({QuizRoom? room}) async {
    await _finishSession(room: room);
    await _logQuizFinished(room);
    if (!mounted) return;
    setState(() => _isFinished = true);
  }

  Future<void> _logQuizStarted({QuizRoom? room}) async {
    if (_analyticsStartedLogged) return;
    _analyticsStartedLogged = true;

    final mode = room != null
        ? (room.isDuel ? 'duel' : 'lightning')
        : (widget.isAdaptiveMode ? 'adaptive' : 'solo');

    await ref.read(analyticsServiceProvider).logQuizStarted(
          mode: mode,
          category: widget.categoryTitle,
        );
  }

  Future<void> _logQuizFinished(QuizRoom? room) async {
    final mode = room != null
        ? (room.isDuel ? 'duel' : 'lightning')
        : (widget.isAdaptiveMode ? 'adaptive' : 'solo');

    await ref.read(analyticsServiceProvider).logQuizFinished(
          mode: mode,
          category: widget.categoryTitle,
          score: _score,
          total: _questions.isNotEmpty
              ? _questions.length
              : (room?.questionCount ?? 0),
        );
  }

  Future<void> _sendReaction(QuizRoom room, String emoji) async {
    final playerId = ref.read(sessionPlayerIdProvider);
    await ref.read(multiplayerRepositoryProvider).sendReaction(
          roomId: room.roomId,
          playerId: playerId,
          emoji: emoji,
        );
  }

  void _copyJoinLink(QuizRoom room) {
    final url = multiplayerJoinUrl(room.roomId, isDuel: room.isDuel);
    Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          room.isDuel
              ? 'Link do duelo copiado!'
              : 'Link da sala copiado!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLiveReactionsBar(
    BuildContext context,
    ThemeData theme,
    QuizRoom room,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Reagir:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        ...LiveReactionOptions.emojis.map(
          (emoji) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _sendReaction(room, emoji),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Avança para a próxima questão (apenas modo solo).
  Future<void> _advanceNextQuestion() async {
    if (!mounted || _isMultiplayer) return;

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _startTimer();
    } else if (widget.isAdaptiveMode && _isDiagnosticPhase) {
      await _finishDiagnosticPhase();
    } else {
      await _completeSession();
    }
  }

  Widget _buildResultsView({
    required VoidCallback onRestart,
    List<QuizPlayer>? players,
    String? categoryTitle,
  }) {
    return ResultsView(
      score: _score,
      totalQuestions: _questions.length,
      categoryTitle: categoryTitle ?? widget.categoryTitle,
      players: players,
      roomId: widget.roomId,
      isPointsBased: players != null && (_timerRoom?.isLightning ?? true),
      levelLabel: _adaptiveLevelLabel,
      isDiagnosticResult: false,
      onRestart: onRestart,
    );
  }

  Widget _buildDiagnosticSummary(BuildContext context, ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 56,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Diagnóstico concluído',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seu nível sugerido: $_suggestedLevelLabel',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Você acertou $_score de ${_questions.length}. '
                      'A trilha adaptativa vai ajustar as perguntas ao seu nível.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _startAdaptivePhase,
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      label: const Text(
                        'Iniciar Trilha (15 perguntas)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Voltar ao Início'),
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

  /// Exibe um modal de confirmação ao tentar sair prematuramente da tela.
  Future<bool> _showExitConfirmationDialog() async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 10),
            const Text('Abandonar Partida?'),
          ],
        ),
        content: const Text(
          'Todo o seu progresso nesta rodada será perdido. Deseja realmente sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Continuar',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    if (_isMultiplayer) {
      ref.listen(currentRoomProvider(widget.roomId!), (previous, next) {
        next.whenData((room) {
          final previousRoom = previous?.value;
          if (previousRoom?.status == 'waiting' && room.status == 'playing') {
            if (mounted) {
              setState(() {
                _lastSyncedQuestionIndex = -1;
                _isAnswered = false;
                _selectedAnswerIndex = null;
              });
            }
            if (!_isHost(room) && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    room.isDuel
                        ? 'Duelo iniciado! Boa sorte.'
                        : 'Arena Relâmpago iniciada! Todos respondem juntos.',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
          _syncRoomState(room);
        });
      });
    }

    final roomAsync = _isMultiplayer
        ? ref.watch(currentRoomProvider(widget.roomId!))
        : null;

    if (_isMultiplayer) {
      return _buildMultiplayerScreen(
        context: context,
        theme: theme,
        size: size,
        roomAsync: roomAsync!,
      );
    }

    return FutureBuilder<List<QuizQuestion>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        // A. Estado de Carregamento
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                     'Carregando perguntas...',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // B. Estado de Erro
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar o Quiz:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Voltar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // C. Sem perguntas encontradas
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_rounded,
                    color: theme.colorScheme.secondary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma pergunta disponível para esta categoria.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          );
        }

        // Inicializa as perguntas locais se for a primeira carga
        if (_questions.isEmpty) {
          _questions = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startTimer();
          });
        }

        if (_awaitingAdaptiveStart) {
          return _buildDiagnosticSummary(context, theme);
        }

        if (_isFinished) {
          return _buildResultsView(
            onRestart: () {
              setState(() {
                _currentQuestionIndex = 0;
                _score = 0;
                _isFinished = false;
                _historyRecorded = false;
                if (widget.isAdaptiveMode) {
                  _questionsFuture = _loadAdaptiveSession();
                  _questions = [];
                  _awaitingAdaptiveStart = false;
                  _isDiagnosticPhase = false;
                }
              });
              if (!widget.isAdaptiveMode) {
                _startTimer();
              }
            },
          );
        }

        return _buildQuizContent(
          context: context,
          theme: theme,
          size: size,
        );
      },
    );
  }

  Widget _buildMultiplayerScreen({
    required BuildContext context,
    required ThemeData theme,
    required Size size,
    required AsyncValue<QuizRoom> roomAsync,
  }) {
    return roomAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Conectando à sala ${widget.roomId}...',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (room) {
        if (room.isTurnBased) {
          return _buildDeprecatedModeScreen(context, theme);
        }

        if (room.status == 'waiting') {
          return _buildWaitingLobby(context, theme, room);
        }

        _ensureMultiplayerQuestionsFuture(room);

        if (room.questionIds.isEmpty) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Preparando o campeonato...',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<QuizQuestion>>(
          future: _multiplayerQuestionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: theme.colorScheme.surface,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preparando perguntas de ${room.categoryTitle}...',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('${snapshot.error}')),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Voltar'),
                  ),
                ),
              );
            }

            if (_questions.isEmpty) {
              _questions = snapshot.data!;
            }

            final activeIndex = room.currentQuestionIndex.clamp(
              0,
              _questions.length - 1,
            );

            if (_isFinished) {
              return _buildResultsView(
                onRestart: () => context.go('/'),
                players: room.players,
                categoryTitle: room.categoryTitle,
              );
            }

            return _buildQuizContent(
              context: context,
              theme: theme,
              size: size,
              room: room,
              questionIndex: activeIndex,
            );
          },
        );
      },
    );
  }

  Widget _buildDeprecatedModeScreen(BuildContext context, ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 64,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Modo Campeonato descontinuado',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Esta sala usa o formato antigo por turnos. '
                  'Crie uma nova sala Arena Relâmpago ou Duelo 1v1 na Home.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Voltar ao Início'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingLobby(
    BuildContext context,
    ThemeData theme,
    QuizRoom room,
  ) {
    final isHost = _isHost(room);
    final isInRoom = _localPlayerIndex(room) >= 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop && context.mounted) {
          ref.read(currentRoomIdProvider.notifier).state = null;
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          title: Text('Sala ${room.roomId}'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _showExitConfirmationDialog();
              if (shouldPop && context.mounted) {
                ref.read(currentRoomIdProvider.notifier).state = null;
                context.go('/');
              }
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isInRoom)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Você ainda não está nesta sala. Saia e entre novamente com o PIN.',
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ),
                if (!isInRoom) const SizedBox(height: 16),
                Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 56,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aguardando jogadores',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isHost
                            ? room.isDuel
                                ? 'Compartilhe o link do duelo. São necessários 2 jogadores.'
                                : 'Compartilhe o PIN ${room.roomId}. Quando todos estiverem prontos, inicie a disputa.'
                            : room.isLightning
                                ? room.isDuel
                                    ? 'Aguarde o oponente. Vocês responderão juntos!'
                                    : 'Aguarde o host iniciar. Todos responderão juntos em cada pergunta!'
                                : 'Aguarde o host iniciar. Cada jogador responderá em sua rodada.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (isHost) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _copyJoinLink(room),
                          icon: const Icon(Icons.link_rounded),
                          label: Text(
                            room.isDuel
                                ? 'Copiar link do duelo'
                                : 'Copiar link da sala',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      LobbySettingRow(
                        icon: Icons.sports_esports_outlined,
                        label: 'Modo',
                        value: room.gameMode.label,
                      ),
                      const Divider(height: 20),
                      LobbySettingRow(
                        icon: Icons.category_outlined,
                        label: 'Categoria',
                        value: room.categoryTitle,
                      ),
                      const Divider(height: 20),
                      LobbySettingRow(
                        icon: Icons.quiz_outlined,
                        label: 'Perguntas',
                        value: '${room.questionCount}',
                      ),
                      if (room.isLightning) ...[
                        const Divider(height: 20),
                        LobbySettingRow(
                          icon: Icons.timer_outlined,
                          label: 'Tempo por pergunta',
                          value: '${room.questionTimeSeconds} segundos',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Jogadores (${room.players.length}/${room.playerLimit})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: room.players.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = room.players[index];
                    final isRoomHost = player.id == room.hostId;
                    return ListTile(
                      tileColor: theme.colorScheme.primary.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          player.name.isNotEmpty
                              ? player.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(player.name),
                      trailing: isRoomHost
                          ? Chip(
                              label: const Text('Host'),
                              backgroundColor:
                                  theme.colorScheme.secondary.withValues(
                                alpha: 0.15,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              if (isHost)
                ElevatedButton.icon(
                  onPressed: room.players.isEmpty ||
                          room.players.length > room.playerLimit ||
                          (room.isDuel && room.players.length < 2)
                      ? null
                      : _startMultiplayerGame,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(
                    room.isDuel ? 'Iniciar Duelo' : 'Iniciar Arena Relâmpago',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildQuizContent({
    required BuildContext context,
    required ThemeData theme,
    required Size size,
    QuizRoom? room,
    int? questionIndex,
  }) {
    final displayIndex = questionIndex ?? _currentQuestionIndex;
    final currentQuestion = _questions[displayIndex.clamp(
      0,
      _questions.length - 1,
    )];
    final progressFraction = (displayIndex + 1) / _questions.length;
    final isLightning = room?.isLightning ?? false;
    final showAnswerReveal = _isMultiplayer && room != null
        ? isLightning
            ? room.phase == GamePhase.reveal ||
                room.phase == GamePhase.embasamento
            : _isAnswered
        : _isAnswered;
    final displayedSelectedIndex = _selectedAnswerIndex;
    final canSelectAnswer = !_isMultiplayer ||
        (room != null &&
            isLightning &&
            room.phase == GamePhase.question &&
            !_hasSubmittedLightningAnswer);
    final useWebArenaLayout = isLightning && size.width > 900;

    if (_isMultiplayer &&
        room != null &&
        room.status == 'playing' &&
        _lastSyncedQuestionIndex == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastSyncedQuestionIndex != -1) return;
        setState(() {
          _currentQuestionIndex = room.currentQuestionIndex;
          _lastSyncedQuestionIndex = room.currentQuestionIndex;
          _roomStartTime = room.startTime;
          _roomMaxTimeSeconds = room.maxTimeSeconds;
        });
        _startTimer(room: room);
      });
    }

    final headerQuestionNumber = _isMultiplayer && room != null
        ? room.currentQuestionIndex + 1
        : displayIndex + 1;

    Color timerColor = theme.colorScheme.secondary;
    if (_secondsRemaining <= 10) {
      timerColor = Colors.red.shade600;
    } else if (_secondsRemaining <= 20) {
      timerColor = Colors.orange;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop && context.mounted) {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _showExitConfirmationDialog();
              if (shouldPop && context.mounted) {
                context.go('/');
              }
            },
          ),
          title: Text(
            _isMultiplayer
                ? room?.isDuel == true
                    ? '⚔ Duelo ${widget.roomId}'
                    : '⚡ Arena ${widget.roomId}'
                : widget.isAdaptiveMode
                    ? _isDiagnosticPhase
                        ? 'Diagnóstico • ${widget.categoryTitle}'
                        : 'Trilha • ${widget.categoryTitle}'
                    : widget.categoryTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.secondary,
                ),
                minHeight: 6,
              ),
              if (room != null && !useWebArenaLayout)
                PlayerRankingPanel(
                  players: room.players,
                  currentPlayerId: ref.read(sessionPlayerIdProvider),
                  isLightning: isLightning,
                  responsesCount: room.responsesCount,
                  totalPlayers: room.players.length,
                ),
              Expanded(
                child: useWebArenaLayout
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildQuestionScrollArea(
                              context: context,
                              theme: theme,
                              size: size,
                              room: room,
                              currentQuestion: currentQuestion,
                              headerQuestionNumber: headerQuestionNumber,
                              progressFraction: progressFraction,
                              isLightning: isLightning,
                              showAnswerReveal: showAnswerReveal,
                              displayedSelectedIndex: displayedSelectedIndex,
                              canSelectAnswer: canSelectAnswer,
                              timerColor: timerColor,
                            ),
                          ),
                          PlayerRankingSidebar(
                            players: room!.players,
                            currentPlayerId: ref.read(sessionPlayerIdProvider),
                            responsesCount: room.responsesCount,
                            totalPlayers: room.players.length,
                            streaks: room.streaks,
                          ),
                        ],
                      )
                    : _buildQuestionScrollArea(
                        context: context,
                        theme: theme,
                        size: size,
                        room: room,
                        currentQuestion: currentQuestion,
                        headerQuestionNumber: headerQuestionNumber,
                        progressFraction: progressFraction,
                        isLightning: isLightning,
                        showAnswerReveal: showAnswerReveal,
                        displayedSelectedIndex: displayedSelectedIndex,
                        canSelectAnswer: canSelectAnswer,
                        timerColor: timerColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionScrollArea({
    required BuildContext context,
    required ThemeData theme,
    required Size size,
    required QuizRoom? room,
    required QuizQuestion currentQuestion,
    required int headerQuestionNumber,
    required double progressFraction,
    required bool isLightning,
    required bool showAnswerReveal,
    required int? displayedSelectedIndex,
    required bool canSelectAnswer,
    required Color timerColor,
  }) {
    return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 800 ? size.width * 0.2 : 20.0,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.isAdaptiveMode && _isDiagnosticPhase)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insights_outlined,
                                size: 18,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Diagnóstico rápido — ${_questions.length} perguntas para calibrar seu nível',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.isAdaptiveMode &&
                          !_isDiagnosticPhase &&
                          _adaptiveLevelLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 18,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Trilha adaptativa • Nível $_adaptiveLevelLabel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.isAdaptiveMode) const SizedBox(height: 16),
                      if (_isMultiplayer && isLightning)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                room!.phase == GamePhase.question
                                    ? Icons.bolt_rounded
                                    : Icons.menu_book_rounded,
                                size: 18,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  room.phase == GamePhase.question
                                      ? _hasSubmittedLightningAnswer
                                          ? room.isDuel
                                              ? 'Resposta enviada! Aguardando o oponente...'
                                              : 'Resposta enviada! Aguardando os outros...'
                                          : room.isDuel
                                              ? 'Duelo ao vivo — responda antes do oponente!'
                                              : 'Todos respondem agora — seja rápido!'
                                      : room.phase == GamePhase.reveal
                                          ? 'Gabarito revelado!'
                                          : 'Estude o embasamento — próxima em ${room.autoAdvanceSecondsRemaining}s',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isMultiplayer &&
                          isLightning &&
                          room != null &&
                          room.status == 'playing')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildLiveReactionsBar(context, theme, room),
                        ),
                      if (_isMultiplayer &&
                          isLightning &&
                          room != null &&
                          room.activeReactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: room.activeReactions.entries.map((entry) {
                              QuizPlayer? matched;
                              for (final player in room.players) {
                                if (player.id == entry.key) {
                                  matched = player;
                                  break;
                                }
                              }
                              final name = matched?.name ?? 'Jogador';
                              return Chip(
                                avatar: Text(
                                  entry.value,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                label: Text(
                                  name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: theme.colorScheme.secondary
                                    .withValues(alpha: 0.12),
                              );
                            }).toList(),
                          ),
                        ),
                      if (_isMultiplayer && isLightning)
                        const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Pergunta $headerQuestionNumber/${_questions.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isLightning ? '$_score pts' : '$_score acertos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!isLightning ||
                          room == null ||
                          room.phase == GamePhase.question) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                _isMultiplayer
                                    ? 'Tempo da Pergunta'
                                    : 'Tempo Restante',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: _isMultiplayer ? 50 : 56,
                                    height: _isMultiplayer ? 50 : 56,
                                    child: CircularProgressIndicator(
                                      value: _activeQuestionDurationSeconds == 0
                                          ? 0
                                          : _secondsRemaining /
                                              _activeQuestionDurationSeconds,
                                      strokeWidth: _isMultiplayer ? 4 : 5,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        timerColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_secondsRemaining}s',
                                    style: TextStyle(
                                      fontSize: _isMultiplayer ? 13 : 15,
                                      fontWeight: FontWeight.w900,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        shadowColor: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                color: theme.colorScheme.secondary,
                                size: 24,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                currentQuestion.questionText,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  height: 1.4,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: List.generate(
                          currentQuestion.alternatives.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14.0),
                            child: AlternativeButton(
                              alternativeText:
                                  currentQuestion.alternatives[index],
                              index: index,
                              isSelected: displayedSelectedIndex == index,
                              isAnswered: showAnswerReveal,
                              isEnabled: canSelectAnswer,
                              correctIndex: _displayCorrectIndex(
                                room,
                                currentQuestion,
                              ),
                              onTap: () => _onAnswerSelected(index, room),
                            ),
                          ),
                        ),
                      ),
                      if (showAnswerReveal) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.04,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    color: theme.colorScheme.secondary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Entenda o Gabarito:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isLightning
                                    ? currentQuestion.embasamentoCurto
                                    : currentQuestion.embasamento,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              if (isLightning &&
                                  currentQuestion.embasamentoCurto !=
                                      currentQuestion.embasamento.trim()) ...[
                                const SizedBox(height: 8),
                                Theme(
                                  data: theme.copyWith(
                                    dividerColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      'Ver contexto completo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.secondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          currentQuestion.embasamento,
                                          style:
                                              theme.textTheme.bodyMedium?.copyWith(
                                            height: 1.5,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_isMultiplayer)
                          ElevatedButton(
                            onPressed: _advanceNextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                              child: Text(
                                _currentQuestionIndex < _questions.length - 1
                                    ? 'Próxima Pergunta'
                                    : 'Ver Resultados',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          )
                        else if (isLightning && room != null)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  room.phase == GamePhase.embasamento
                                      ? 'Próxima pergunta em ${room.autoAdvanceSecondsRemaining}s'
                                      : 'Aguarde — revelando gabarito...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                if (room.phase == GamePhase.embasamento &&
                                    _isHost(room)) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _isProcessingPhase
                                        ? null
                                        : () => ref
                                            .read(
                                              multiplayerRepositoryProvider,
                                            )
                                            .skipEmbasamento(
                                              roomId: widget.roomId!,
                                            ),
                                    icon: const Icon(Icons.skip_next_rounded),
                                    label: const Text('Pular explicação'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else if (!isLightning && room != null)
                          const SizedBox.shrink(),
                      ],
                    ],
                  ),
                );
  }
}

