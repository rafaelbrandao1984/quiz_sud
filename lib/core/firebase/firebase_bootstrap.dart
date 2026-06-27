import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Erro quando Authentication ainda não foi configurado no Console.
class FirebaseAuthNotConfiguredException implements Exception {
  final String message;
  const FirebaseAuthNotConfiguredException(this.message);

  @override
  String toString() => message;
}

/// Inicializa App Check, Auth anônimo e fallback web via Cloud Function.
class FirebaseBootstrap {
  static const String consoleAuthUrl =
      'https://console.firebase.google.com/project/liahona-quiz/authentication/providers';

  static const String authorizedDomainsUrl =
      'https://console.firebase.google.com/project/liahona-quiz/authentication/settings';

  static const String appCheckConsoleUrl =
      'https://console.firebase.google.com/project/liahona-quiz/appcheck';

  static Future<void> initialize() async {
    await _activateAppCheck();

    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }

    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      debugPrint('Erro na autenticação anônima padrão: ${e.code} — ${e.message}');

      if (kIsWeb) {
        try {
          debugPrint('Iniciando fallback de custom token no Web...');
          final functions =
              FirebaseFunctions.instanceFor(region: 'southamerica-east1');
          final result =
              await functions.httpsCallable('createAnonymousSession').call({});
          final data = Map<String, dynamic>.from(result.data as Map);
          final token = data['customToken'] as String?;
          if (token == null || token.isEmpty) {
            throw FirebaseAuthNotConfiguredException(
              'Resposta inválida ao obter sessão customizada.',
            );
          }
          await FirebaseAuth.instance.signInWithCustomToken(token);
          return;
        } catch (fallbackError) {
          debugPrint('Falha no fallback de custom token: $fallbackError');
          throw FirebaseAuthNotConfiguredException(
            'Não foi possível conectar. Verifique login anônimo, App Check e Cloud Functions.\nErro: $e',
          );
        }
      }

      if (e.code == 'configuration-not-found' ||
          e.code == 'auth/configuration-not-found') {
        throw FirebaseAuthNotConfiguredException(
          'Firebase Authentication ainda não foi ativado no projeto liahona-quiz.',
        );
      }
      if (e.code == 'operation-not-allowed' ||
          e.code == 'auth/operation-not-allowed') {
        throw FirebaseAuthNotConfiguredException(
          'Login anônimo não está habilitado. Ative em Sign-in method → Anonymous.',
        );
      }
      rethrow;
    }
  }

  static Future<void> _activateAppCheck() async {
    try {
      if (kIsWeb) {
        const webSiteKey = String.fromEnvironment(
          'RECAPTCHA_SITE_KEY',
          defaultValue: '',
        );
        if (webSiteKey.isEmpty) {
          debugPrint(
            'App Check web: configure RECAPTCHA_SITE_KEY no build '
            '(Console → App Check → reCAPTCHA Enterprise). '
            'Temporário: acesse ?appCheckDebug=1 e registre o debug token em $appCheckConsoleUrl',
          );
          return;
        }
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaEnterpriseProvider(webSiteKey),
        );
        if (kDebugMode) {
          final token = await FirebaseAppCheck.instance.getToken();
          debugPrint('App Check web token obtido (${token?.length ?? 0} chars)');
        }
        return;
      }

      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? AndroidDebugProvider()
            : AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? AppleDebugProvider()
            : AppleAppAttestProvider(),
      );
    } catch (error) {
      debugPrint('App Check não ativado (configure no Console): $error');
    }
  }

  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
}
