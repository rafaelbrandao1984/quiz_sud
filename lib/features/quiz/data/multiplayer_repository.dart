import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/firebase/firebase_functions_provider.dart';
import '../domain/game_mode.dart';
import '../domain/quiz_room.dart';
import '../domain/room_settings.dart';
import '../../../core/firebase/firestore_provider.dart';

/// Repositório para salas multijogador em tempo real via Firestore + Cloud Functions.
class MultiplayerRepository {
  static const String collectionName = 'salas';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  MultiplayerRepository(this._firestore, this._functions);

  Future<HttpsCallableResult<dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) {
    return _functions.httpsCallable(name).call(data);
  }

  /// Gera um PIN aleatório de 6 dígitos e cria o documento da sala.
  Future<String> createRoom({
    required String hostId,
    required String hostName,
    required RoomSettings settings,
  }) async {
    final random = Random();
    String roomId;
    DocumentSnapshot<Map<String, dynamic>> existing;

    do {
      roomId = (100000 + random.nextInt(900000)).toString();
      existing = await _firestore.collection(collectionName).doc(roomId).get();
    } while (existing.exists);

    final room = QuizRoom(
      roomId: roomId,
      hostId: hostId,
      players: [
        QuizPlayer(id: hostId, name: hostName),
      ],
      currentQuestionIndex: 0,
      status: 'waiting',
      createdAt: DateTime.now(),
      maxTimeSeconds: settings.maxTimeSeconds,
      categoryTitle: settings.categoryTitle,
      questionCount: settings.questionCount,
      currentPlayerTurnIndex: 0,
      allAnswersCollected: false,
      answeredPlayerIds: const [],
      gameMode: settings.gameMode,
      phase: GamePhase.question,
      questionTimeSeconds: settings.questionTimeSeconds,
      autoAdvanceSeconds: settings.autoAdvanceSeconds,
    );

    await _firestore.collection(collectionName).doc(roomId).set(room.toMap());
    return roomId;
  }

  Future<QuizRoom> getRoom(String roomId) async {
    final snapshot =
        await _firestore.collection(collectionName).doc(roomId).get();
    if (!snapshot.exists) {
      throw Exception('Sala não encontrada. Verifique o PIN informado.');
    }
    return QuizRoom.fromFirestore(snapshot);
  }

  Future<void> joinRoom({
    required String roomId,
    required String playerId,
    required String playerName,
  }) async {
    final docRef = _firestore.collection(collectionName).doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Sala não encontrada. Verifique o PIN informado.');
      }

      final room = QuizRoom.fromFirestore(snapshot);
      final alreadyJoined = room.players.any((player) => player.id == playerId);

      if (alreadyJoined) return;

      if (room.status == 'finished') {
        throw Exception('Esta sala já foi encerrada.');
      }

      final limit = room.playerLimit;
      if (room.players.length >= limit) {
        throw Exception(
          'Sala cheia. O limite é de $limit jogador${limit == 1 ? '' : 'es'}.',
        );
      }

      final updatedPlayers = [
        ...room.players,
        QuizPlayer(id: playerId, name: playerName),
      ];

      transaction.update(docRef, {
        'players': updatedPlayers.map((player) => player.toMap()).toList(),
      });
    });
  }

  Future<String> createDuelRoom({
    required String hostId,
    required String hostName,
    required String categoryTitle,
  }) {
    return createRoom(
      hostId: hostId,
      hostName: hostName,
      settings: RoomSettings(
        categoryTitle: categoryTitle,
        questionCount: RoomConfigOptions.duelQuestions,
        maxTimeSeconds: RoomConfigOptions.minutesToSeconds(15),
        gameMode: GameMode.duel,
      ),
    );
  }

  Future<void> sendReaction({
    required String roomId,
    required String playerId,
    required String emoji,
  }) async {
    await _firestore.collection(collectionName).doc(roomId).update({
      'activeReactions.$playerId': emoji,
    });

    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await _firestore.collection(collectionName).doc(roomId).update({
          'activeReactions.$playerId': FieldValue.delete(),
        });
      } catch (_) {}
    });
  }

  Stream<QuizRoom> streamRoom(String roomId) {
    return _firestore
        .collection(collectionName)
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Sala não encontrada.');
      }
      return QuizRoom.fromFirestore(snapshot);
    });
  }

  Future<void> updatePlayerScore(
    String roomId,
    String playerId,
    int score,
  ) async {
    final docRef = _firestore.collection(collectionName).doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final room = QuizRoom.fromFirestore(snapshot);
      final updatedPlayers = room.players
          .map(
            (player) => player.id == playerId
                ? player.copyWith(score: score)
                : player,
          )
          .toList();

      transaction.update(docRef, {
        'players': updatedPlayers.map((player) => player.toMap()).toList(),
      });
    });
  }

  Future<void> completeCurrentTurn({
    required String roomId,
    required String playerId,
    required int answerIndex,
  }) async {
    await _firestore.collection(collectionName).doc(roomId).update({
      'allAnswersCollected': true,
      'answeredPlayerIds': [playerId],
      'currentTurnAnswerIndex': answerIndex,
    });
  }

  Future<void> submitLightningAnswer({
    required String roomId,
    required String playerId,
    required int answerIndex,
  }) async {
    await _call('submitLightningAnswer', {
      'roomId': roomId,
      'answerIndex': answerIndex,
    });
  }

  Future<void> revealLightningQuestion({required String roomId}) async {
    await _call('revealLightningQuestion', {'roomId': roomId});
  }

  /// Qualquer jogador pode disparar quando deadlines venceram (host offline).
  Future<void> processLightningTick({required String roomId}) async {
    await _call('processLightningTick', {'roomId': roomId});
  }

  Future<void> ensureEmbasamentoPhase({required String roomId}) async {
    await revealLightningQuestion(roomId: roomId);
  }

  Future<void> advanceLightningQuestion({
    required String roomId,
    required int totalQuestions,
  }) async {
    if (totalQuestions <= 0) return;
    await _call('advanceLightningQuestion', {
      'roomId': roomId,
      'totalQuestions': totalQuestions,
    });
  }

  Future<void> skipEmbasamento({required String roomId}) async {
    await _call('skipEmbasamento', {'roomId': roomId});
  }

  Future<void> startGame(String roomId) async {
    await _call('startGame', {'roomId': roomId});
  }

  Future<void> advanceTurn({
    required String roomId,
    required int totalQuestions,
  }) async {
    final docRef = _firestore.collection(collectionName).doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final room = QuizRoom.fromFirestore(snapshot);
      final nextIndex = room.currentQuestionIndex + 1;

      if (nextIndex >= totalQuestions || room.isGlobalTimeUp) {
        transaction.update(docRef, {
          'status': 'finished',
          'finishedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final nextTurn =
          (room.currentPlayerTurnIndex + 1) % room.players.length;

      transaction.update(docRef, {
        'currentQuestionIndex': nextIndex,
        'currentPlayerTurnIndex': nextTurn,
        'allAnswersCollected': false,
        'answeredPlayerIds': <String>[],
        'currentTurnAnswerIndex': FieldValue.delete(),
      });
    });
  }

  Future<void> finishGame(String roomId) async {
    await _call('finishGame', {'roomId': roomId});
  }
}

/// UID do Firebase Auth (Anonymous) — estável por sessão/dispositivo.
final sessionPlayerIdProvider = Provider<String>((ref) {
  return FirebaseAuth.instance.currentUser?.uid ?? '';
});

final currentRoomIdProvider = StateProvider<String?>((ref) => null);

final sessionPlayerNameProvider = StateProvider<String>((ref) => 'Jogador');

final multiplayerRepositoryProvider = Provider<MultiplayerRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final functions = ref.watch(firebaseFunctionsProvider);
  return MultiplayerRepository(firestore, functions);
});

final currentRoomProvider = StreamProvider.family<QuizRoom, String>((ref, roomId) {
  final repository = ref.watch(multiplayerRepositoryProvider);
  return repository.streamRoom(roomId);
});
