#!/usr/bin/env bash
# Build e deploy web com App Check (reCAPTCHA Enterprise).
# Uso: ./scripts/deploy_web_appcheck.sh SUA_RECAPTCHA_SITE_KEY

set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "Uso: $0 <RECAPTCHA_SITE_KEY>"
  echo "Obtenha a site key em:"
  echo "  https://console.firebase.google.com/project/liahona-quiz/appcheck"
  exit 1
fi

SITE_KEY="$1"

echo "→ flutter build web --dart-define=RECAPTCHA_SITE_KEY=***"
flutter build web --release --dart-define=RECAPTCHA_SITE_KEY="$SITE_KEY"

echo "→ firebase deploy --only hosting"
firebase deploy --only hosting

echo "✓ Deploy concluído: https://liahona-quiz.web.app"
