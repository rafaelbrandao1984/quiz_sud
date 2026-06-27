/** Opções compartilhadas para Cloud Functions callable (região + App Check). */
const region = "southamerica-east1";

/** Ative com FIREBASE_APP_CHECK_ENFORCE=true após configurar reCAPTCHA no client. */
const enforceAppCheck = process.env.FIREBASE_APP_CHECK_ENFORCE === "true";

function callableOptions(extra = {}) {
  return { region, enforceAppCheck, ...extra };
}

module.exports = { region, enforceAppCheck, callableOptions };
