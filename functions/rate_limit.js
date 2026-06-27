const { HttpsError } = require("firebase-functions/v2/https");

/**
 * Rate limit simples via Firestore (_rateLimits/{key}).
 * @param {FirebaseFirestore.Firestore} db
 */
async function enforceRateLimit(db, key, maxRequests, windowMs) {
  const ref = db.collection("_rateLimits").doc(key);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);

    if (!snap.exists) {
      tx.set(ref, { count: 1, windowStart: now });
      return;
    }

    const data = snap.data();
    const windowStart = data.windowStart ?? now;
    const count = data.count ?? 0;

    if (now - windowStart > windowMs) {
      tx.set(ref, { count: 1, windowStart: now });
      return;
    }

    if (count >= maxRequests) {
      throw new HttpsError(
        "resource-exhausted",
        "Muitas tentativas. Aguarde alguns minutos e tente novamente.",
      );
    }

    tx.update(ref, { count: count + 1 });
  });
}

function getClientIp(request) {
  const raw = request.rawRequest;
  if (!raw) return "unknown";

  const forwarded = raw.headers?.["x-forwarded-for"];
  if (forwarded && typeof forwarded === "string") {
    return forwarded.split(",")[0].trim();
  }

  return raw.ip || "unknown";
}

module.exports = { enforceRateLimit, getClientIp };
