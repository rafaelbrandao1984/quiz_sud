const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { computeLightningPoints, nextStreak } = require("./scoring");
const { callableOptions } = require("./callable_config");
const { enforceRateLimit, getClientIp } = require("./rate_limit");

admin.initializeApp();

const db = admin.firestore();
const SALAS = "salas";
const PERGUNTAS = "perguntas";
const SERVER_DOC = "server/state";

const CATEGORY_TAGS = {
  "Obras Padrão": "obras_padrao",
  "História da Igreja": "historia_igreja",
  "História da Igreja no Brasil": "historia_brasil",
};

const TAG_TO_TITLE = {
  obras_padrao: "Obras Padrão",
  historia_igreja: "História da Igreja",
  historia_brasil: "História da Igreja no Brasil",
};

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Autenticação necessária.");
  }
  return request.auth.uid;
}

function categoryTag(title) {
  return CATEGORY_TAGS[title] || "obras_padrao";
}

function titleFromTag(tag) {
  return TAG_TO_TITLE[tag] || "Desafio Geral";
}

function seededShuffle(array, seed) {
  const copy = [...array];
  let state = seed >>> 0;
  for (let i = copy.length - 1; i > 0; i--) {
    state = (state * 1664525 + 1013904223) >>> 0;
    const j = state % (i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

async function getRoom(roomId) {
  const snap = await db.collection(SALAS).doc(roomId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Sala não encontrada.");
  }
  return { id: roomId, ...snap.data() };
}

async function requireHost(room, uid) {
  if (room.hostId !== uid) {
    throw new HttpsError("permission-denied", "Apenas o host pode executar esta ação.");
  }
}

function isGlobalTimeUp(room) {
  if (!room.startTime || !room.maxTimeSeconds) return false;
  const endMs = room.startTime.toMillis() + room.maxTimeSeconds * 1000;
  return Date.now() >= endMs;
}

async function finishRoomInternal(roomId) {
  await db.collection(SALAS).doc(roomId).update({
    status: "finished",
    finishedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function getCorrectIndexFromQuestion(questionId) {
  const qSnap = await db.collection(PERGUNTAS).doc(questionId).get();
  if (!qSnap.exists) return 0;
  return qSnap.data().resposta_correta ?? 0;
}

async function getCorrectIndex(roomId, questionId) {
  const secretSnap = await db
    .collection(SALAS)
    .doc(roomId)
    .collection("server")
    .doc("state")
    .get();
  if (secretSnap.exists && secretSnap.data().questionId === questionId) {
    return secretSnap.data().correctAnswerIndex;
  }
  return getCorrectIndexFromQuestion(questionId);
}

async function setServerAnswer(roomId, questionId, correctAnswerIndex) {
  await db
    .collection(SALAS)
    .doc(roomId)
    .collection("server")
    .doc("state")
    .set({ questionId, correctAnswerIndex });
}

async function fetchQuestionIds(categoryTitle, limit, seed) {
  const isMixed = categoryTitle === "Desafio Geral";
  let query = db.collection(PERGUNTAS);
  if (!isMixed) {
    query = query.where("categoria", "==", categoryTag(categoryTitle));
  }
  const snap = await query.get();
  let docs = snap.docs.map((d) => d.id);
  docs = seededShuffle(docs, seed);
  return docs.slice(0, limit);
}

async function loadQuestionDataByIds(ids) {
  const byId = {};
  if (ids.length === 0) return byId;

  for (let i = 0; i < ids.length; i += 10) {
    const chunk = ids.slice(i, i + 10);
    const snap = await db
      .collection(PERGUNTAS)
      .where(admin.firestore.FieldPath.documentId(), "in", chunk)
      .get();
    for (const doc of snap.docs) {
      byId[doc.id] = doc.data();
    }
  }
  return byId;
}

function mapQuestionDoc(id, data, { includeCorrectAnswer, fallbackCategoryTitle }) {
  const tag = data.categoria || "obras_padrao";
  return {
    id,
    questionText: data.pergunta,
    alternatives: data.alternativas || [],
    embasamento:
      data.embasamento ||
      "Embasamento histórico não disponível para esta questão.",
    categoryTitle: fallbackCategoryTitle || titleFromTag(tag),
    correctAnswerIndex: includeCorrectAnswer ? (data.resposta_correta ?? 0) : -1,
  };
}

function isLightningMode(gameMode) {
  return gameMode === "lightning" || gameMode === "duel";
}

/** Solo / trilha adaptativa — gabarito incluído (somente via Function). */
exports.fetchSoloQuestions = onCall(callableOptions(), async (request) => {
  requireAuth(request);
  const { categoryTitle, limit, shuffleSeed } = request.data ?? {};

  if (!categoryTitle || typeof categoryTitle !== "string") {
    throw new HttpsError("invalid-argument", "categoryTitle obrigatório.");
  }

  const sessionLimit = Math.min(Math.max(Number(limit) || 15, 1), 50);
  const seed =
    shuffleSeed !== undefined && shuffleSeed !== null
      ? Number(shuffleSeed)
      : Date.now();

  const ids = await fetchQuestionIds(categoryTitle, sessionLimit, seed);
  const byId = await loadQuestionDataByIds(ids);
  const isMixed = categoryTitle === "Desafio Geral";

  const questions = ids
    .filter((id) => byId[id])
    .map((id) =>
      mapQuestionDoc(id, byId[id], {
        includeCorrectAnswer: true,
        fallbackCategoryTitle: isMixed ? null : categoryTitle,
      }),
    );

  return { questions };
});

/** Multijogador — gabarito omitido (lightning/duel); legado turn_based inclui. */
exports.fetchRoomQuestions = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  const isPlayer = (room.players ?? []).some((p) => p.id === uid);
  if (!isPlayer) {
    throw new HttpsError("permission-denied", "Você não está nesta sala.");
  }

  const ids = room.questionIds ?? [];
  if (ids.length === 0) return { questions: [] };

  const includeCorrectAnswer = room.gameMode === "turn_based";
  const byId = await loadQuestionDataByIds(ids);

  const questions = ids
    .filter((id) => byId[id])
    .map((id) =>
      mapQuestionDoc(id, byId[id], {
        includeCorrectAnswer,
        fallbackCategoryTitle: room.categoryTitle,
      }),
    );

  return { questions };
});

/** Fallback web: sessão anônima via custom token (App Check + rate limit). */
exports.createAnonymousSession = onCall(
  callableOptions({
    serviceAccount:
      "firebase-adminsdk-fbsvc@liahona-quiz.iam.gserviceaccount.com",
  }),
  async (request) => {
    const ip = getClientIp(request);
    await enforceRateLimit(db, `anon_${ip}`, 10, 60 * 60 * 1000);

    let uid = request.data?.existingUid;

    if (uid && typeof uid === "string") {
      try {
        await admin.auth().getUser(uid);
      } catch {
        uid = db.collection("_meta").doc().id;
      }
    } else {
      uid = db.collection("_meta").doc().id;
    }

    const customToken = await admin.auth().createCustomToken(uid);
    return { customToken, uid };
  },
);

/** Host inicia partida — gabarito fica só no subdoc server/ */
exports.startGame = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  await requireHost(room, uid);

  if (room.status !== "waiting") {
    throw new HttpsError("failed-precondition", "A sala já foi iniciada.");
  }

  if (room.gameMode === "duel" && (room.players ?? []).length < 2) {
    throw new HttpsError(
      "failed-precondition",
      "Duelo exige 2 jogadores antes de iniciar.",
    );
  }

  const questionIds = await fetchQuestionIds(
    room.categoryTitle,
    room.questionCount,
    roomId.split("").reduce((a, c) => a + c.charCodeAt(0), 0),
  );

  if (questionIds.length === 0) {
    throw new HttpsError("failed-precondition", "Nenhuma pergunta disponível.");
  }

  const now = admin.firestore.Timestamp.now();
  const update = {
    status: "playing",
    startTime: now,
    currentQuestionIndex: 0,
    currentPlayerTurnIndex: 0,
    allAnswersCollected: false,
    answeredPlayerIds: [],
    questionIds,
    currentTurnAnswerIndex: admin.firestore.FieldValue.delete(),
  };

  if (isLightningMode(room.gameMode)) {
    const correctIndex = await getCorrectIndexFromQuestion(questionIds[0]);
    await setServerAnswer(roomId, questionIds[0], correctIndex);

    Object.assign(update, {
      phase: "question",
      playerAnswers: {},
      streaks: {},
      correctAnswerIndex: admin.firestore.FieldValue.delete(),
      questionDeadline: admin.firestore.Timestamp.fromMillis(
        now.toMillis() + (room.questionTimeSeconds ?? 20) * 1000,
      ),
      autoAdvanceAt: admin.firestore.FieldValue.delete(),
    });
  }

  await db.collection(SALAS).doc(roomId).update(update);
  return { ok: true, questionCount: questionIds.length };
});

/** Jogador envia resposta relâmpago */
exports.submitLightningAnswer = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId, answerIndex } = request.data ?? {};
  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId obrigatório.");
  }
  if (answerIndex === undefined) {
    throw new HttpsError("invalid-argument", "answerIndex obrigatório.");
  }
  const idx = Number(answerIndex);
  if (!Number.isInteger(idx) || idx < 0 || idx > 3) {
    throw new HttpsError("invalid-argument", "answerIndex deve ser 0–3.");
  }

  const roomRef = db.collection(SALAS).doc(roomId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) throw new HttpsError("not-found", "Sala não encontrada.");
    const room = snap.data();

    if (room.status !== "playing" || !isLightningMode(room.gameMode)) return;
    if (room.phase !== "question") return;
    if (room.playerAnswers?.[uid]) return;

    const isPlayer = (room.players ?? []).some((p) => p.id === uid);
    if (!isPlayer) {
      throw new HttpsError("permission-denied", "Você não está nesta sala.");
    }

    tx.update(roomRef, {
      [`playerAnswers.${uid}`]: {
        answerIndex: idx,
        answeredAt: admin.firestore.Timestamp.now(),
      },
    });
  });

  const room = await getRoom(roomId);
  const allAnswered =
    (room.players ?? []).length > 0 &&
    (room.players ?? []).every((p) => room.playerAnswers?.[p.id]);

  if (allAnswered) {
    await revealLightningInternal(roomId);
  }

  return { ok: true, allAnswered };
});

async function revealLightningInternal(roomId) {
  const roomRef = db.collection(SALAS).doc(roomId);
  const preSnap = await roomRef.get();
  if (!preSnap.exists) return;
  const preRoom = preSnap.data();

  if (preRoom.status !== "playing" || !isLightningMode(preRoom.gameMode)) return;
  if (preRoom.phase !== "question") return;

  const questionIds = preRoom.questionIds ?? [];
  const qIndex = preRoom.currentQuestionIndex ?? 0;
  const questionId = questionIds[qIndex];
  if (!questionId) return;

  const correctIndex = await getCorrectIndex(roomId, questionId);
  const questionStartMs =
    preRoom.questionDeadline.toMillis() -
    (preRoom.questionTimeSeconds ?? 20) * 1000;
  const questionTimeMs = (preRoom.questionTimeSeconds ?? 20) * 1000;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) return;
    const room = snap.data();

    if (room.status !== "playing" || !isLightningMode(room.gameMode)) return;
    if (room.phase !== "question") return;

    const streaks = { ...(room.streaks ?? {}) };
    const players = (room.players ?? []).map((player) => {
      const answer = room.playerAnswers?.[player.id];
      const answerIdx = answer?.answerIndex ?? -1;
      const isCorrect = answerIdx === correctIndex;
      const streakBefore = streaks[player.id] ?? 0;
      const responseTimeMs = answer
        ? Math.min(
            Math.max(0, answer.answeredAt.toMillis() - questionStartMs),
            questionTimeMs,
          )
        : questionTimeMs;

      const points = computeLightningPoints({
        isCorrect,
        responseTimeMs,
        questionTimeMs,
        streakBefore,
      });

      streaks[player.id] = nextStreak({
        isCorrect,
        currentStreak: streakBefore,
      });

      return { ...player, score: (player.score ?? 0) + points };
    });

    tx.update(roomRef, {
      phase: "embasamento",
      players,
      streaks,
      allAnswersCollected: true,
      correctAnswerIndex: correctIndex,
      autoAdvanceAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + (room.autoAdvanceSeconds ?? 12) * 1000,
      ),
    });
  });
}

/** Host revela gabarito (timeout ou manual) */
exports.revealLightningQuestion = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  await requireHost(room, uid);

  await revealLightningInternal(roomId);
  return { ok: true };
});

/** Avança para próxima pergunta (interno — host ou scheduler) */
async function advanceLightningInternal(roomId, totalQuestionsOverride) {
  const roomRef = db.collection(SALAS).doc(roomId);
  const preSnap = await roomRef.get();
  if (!preSnap.exists) return { ok: false, reason: "not_found" };
  const room = preSnap.data();

  if (room.status !== "playing" || !isLightningMode(room.gameMode)) {
    return { ok: false, reason: "not_playing" };
  }
  if (room.phase !== "embasamento") return { ok: false, reason: "wrong_phase" };

  if (room.autoAdvanceAt && room.autoAdvanceAt.toMillis() > Date.now()) {
    return { ok: false, reason: "too_early" };
  }

  const nextIndex = (room.currentQuestionIndex ?? 0) + 1;
  const total =
    totalQuestionsOverride ?? (room.questionIds ?? []).length;

  if (nextIndex >= total) {
    await finishRoomInternal(roomId);
    return { ok: true, finished: true };
  }

  const nextQuestionId = room.questionIds[nextIndex];
  const correctIndex = await getCorrectIndexFromQuestion(nextQuestionId);
  await setServerAnswer(roomId, nextQuestionId, correctIndex);

  await roomRef.update({
    currentQuestionIndex: nextIndex,
    phase: "question",
    playerAnswers: {},
    allAnswersCollected: false,
    correctAnswerIndex: admin.firestore.FieldValue.delete(),
    activeReactions: {},
    questionDeadline: admin.firestore.Timestamp.fromMillis(
      Date.now() + (room.questionTimeSeconds ?? 20) * 1000,
    ),
    autoAdvanceAt: admin.firestore.FieldValue.delete(),
    currentTurnAnswerIndex: admin.firestore.FieldValue.delete(),
  });

  return { ok: true, finished: false, nextIndex };
}

/** Qualquer jogador pode disparar quando deadlines venceram (fallback se host sair) */
exports.processLightningTick = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  const isPlayer = (room.players ?? []).some((p) => p.id === uid);
  if (!isPlayer) {
    throw new HttpsError("permission-denied", "Você não está nesta sala.");
  }

  if (room.status !== "playing" || !isLightningMode(room.gameMode)) {
    return { ok: false, reason: "not_playing" };
  }

  if (isGlobalTimeUp(room)) {
    await finishRoomInternal(roomId);
    return { ok: true, action: "finished_global_time" };
  }

  if (
    room.phase === "question" &&
    room.questionDeadline &&
    room.questionDeadline.toMillis() <= Date.now() &&
    !room.allAnswersCollected
  ) {
    await revealLightningInternal(roomId);
    return { ok: true, action: "revealed" };
  }

  if (
    room.phase === "embasamento" &&
    room.autoAdvanceAt &&
    room.autoAdvanceAt.toMillis() <= Date.now()
  ) {
    const result = await advanceLightningInternal(roomId);
    return { ok: true, action: "advanced", ...result };
  }

  return { ok: false, reason: "nothing_due" };
});

/** Host avança para próxima pergunta */
exports.advanceLightningQuestion = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId, totalQuestions } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  await requireHost(room, uid);

  const result = await advanceLightningInternal(roomId, totalQuestions);
  if (!result.ok && result.reason === "too_early") {
    return { ok: false, reason: "too_early" };
  }
  return result;
});

/** Host encerra partida */
exports.finishGame = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  await requireHost(room, uid);

  await finishRoomInternal(roomId);
  return { ok: true };
});

/** Host pula embasamento */
exports.skipEmbasamento = onCall(callableOptions(), async (request) => {
  const uid = requireAuth(request);
  const { roomId } = request.data ?? {};
  if (!roomId) throw new HttpsError("invalid-argument", "roomId obrigatório.");

  const room = await getRoom(roomId);
  await requireHost(room, uid);

  if (room.phase !== "embasamento") return { ok: false };

  await db.collection(SALAS).doc(roomId).update({
    autoAdvanceAt: admin.firestore.Timestamp.now(),
  });
  return { ok: true };
});

/** Scheduler: partidas Relâmpago/Duelo não travam se o host sair */
exports.tickLightningRooms = onSchedule(
  {
    schedule: "every 1 minutes",
    region: "southamerica-east1",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const now = Date.now();
    const snap = await db
      .collection(SALAS)
      .where("status", "==", "playing")
      .where("gameMode", "in", ["lightning", "duel"])
      .limit(50)
      .get();

    for (const doc of snap.docs) {
      const room = doc.data();
      const roomId = doc.id;

      try {
        if (isGlobalTimeUp(room)) {
          await finishRoomInternal(roomId);
          continue;
        }

        if (
          room.phase === "question" &&
          room.questionDeadline &&
          room.questionDeadline.toMillis() <= now &&
          !room.allAnswersCollected
        ) {
          await revealLightningInternal(roomId);
          continue;
        }

        if (
          room.phase === "embasamento" &&
          room.autoAdvanceAt &&
          room.autoAdvanceAt.toMillis() <= now
        ) {
          await advanceLightningInternal(roomId);
        }
      } catch (err) {
        console.error(`tickLightningRooms ${roomId}:`, err);
      }
    }
  },
);

/** Remove salas finished há mais de 24h */
exports.cleanupFinishedRooms = onSchedule(
  {
    schedule: "every 24 hours",
    region: "southamerica-east1",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 24 * 60 * 60 * 1000,
    );

    const snap = await db
      .collection(SALAS)
      .where("status", "==", "finished")
      .where("finishedAt", "<", cutoff)
      .limit(200)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      const serverRef = doc.ref.collection("server").doc("state");
      batch.delete(serverRef);
    }
    await batch.commit();
    console.log(`Cleanup: ${snap.size} salas removidas.`);
  },
);
