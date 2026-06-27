# Deploy produção — Liahona Quiz

## Pré-requisitos (Console Firebase) — OBRIGATÓRIO

1. Abra [Authentication](https://console.firebase.google.com/project/liahona-quiz/authentication) e clique em **Começar / Get started** (primeira vez).
2. Vá em **Sign-in method → Anônimo (Anonymous) → Habilitar → Salvar**.
3. Recarregue o app.

Sem o passo 1, o erro `configuration-not-found` aparece.

### Opcional (App Check)

- **Web:** App Check → reCAPTCHA Enterprise → registrar app web
- **Play Store:** App Check → Play Integrity → registrar app Android

## Deploy backend

```bash
cd quiz_sud
firebase deploy --only firestore:rules,firestore:indexes,functions
```

**Functions (segurança):**
- `fetchSoloQuestions` / `fetchRoomQuestions` — perguntas sem leitura direta do Firestore
- `processLightningTick` — reveal/avance/fim por tempo global (qualquer jogador)
- `tickLightningRooms` — scheduler a cada 1 min (fallback)
- `createAnonymousSession` — App Check + rate limit (10/h por IP)

**App Check (obrigatório em produção):**
1. Console → App Check → registrar apps (web reCAPTCHA Enterprise, Android Play Integrity)
2. Console → App Check → **Enforce** nas APIs Cloud Functions e Firestore
3. Build web com site key:
   ```bash
   flutter build web --dart-define=RECAPTCHA_SITE_KEY=SUA_SITE_KEY
   ```

**Emulador local:** defina `FIREBASE_APP_CHECK_ENFORCE=false` ao rodar Functions.

Região das Functions: `southamerica-east1` (São Paulo).

## Analytics (GA4)

Eventos automáticos: `app_open`, `quiz_started`, `quiz_finished`, `room_created`, `room_joined`.

Console: [Firebase Analytics](https://console.firebase.google.com/project/liahona-quiz/analytics) → DebugView (dev) ou Relatórios (prod).

## Deploy web

```bash
flutter build web
firebase deploy --only hosting
```

## O que mudou (segurança)

| Recurso | Antes | Agora |
|---------|-------|-------|
| Jogador | ID aleatório no client | Firebase Auth Anonymous (`uid`) |
| Perguntas | Leitura direta `perguntas` | Cloud Functions (`fetchSoloQuestions` / `fetchRoomQuestions`) |
| Gabarito relâmpago | `correctAnswerIndex` no doc da sala | Subdoc `server/state` + reveal via Function |
| Avanço de fase | Qualquer client | Cloud Functions (host ou auto-reveal) |
| Rules | Estrutura básica | Auth obrigatório + writes limitados + `perguntas` bloqueado |
| Salas antigas | Acumulavam | Cleanup diário (`finishedAt` > 24h) |
| App Check | Ausente | Enforced nas callables + rate limit em `createAnonymousSession` |

## Play Store (próximo passo)

- Mesmo projeto Firebase (`liahona-quiz`)
- `google-services.json` já configurado
- App Check: `AndroidPlayIntegrityProvider` em release
- Auth Anonymous funciona igual no Android

## App Check debug (dev)

No log do Android aparece token debug — registre em Console → App Check → Manage debug tokens.
