import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/analytics/analytics_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();
  runApp(const _BootstrapRoot());
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (details) {
    return Material(
      child: Container(
        color: const Color(0xFFF4F6F9),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Erro ao renderizar o app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F2942),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
}

/// Mostra loading imediatamente; Firebase init roda depois do primeiro frame.
class _BootstrapRoot extends StatefulWidget {
  const _BootstrapRoot();

  @override
  State<_BootstrapRoot> createState() => _BootstrapRootState();
}

class _BootstrapRootState extends State<_BootstrapRoot> {
  late final Future<void> _initFuture = _initializeFirebase();

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseBootstrap.initialize().timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw TimeoutException(
          'Firebase demorou demais para responder. Verifique a conexão.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const _LoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is FirebaseAuthNotConfiguredException) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: _FirebaseSetupScreen(
                genericError: error.message,
              ),
            );
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: _FirebaseSetupScreen(genericError: '$error'),
          );
        }

        return const ProviderScope(child: _AnalyticsScope(child: MainApp()));
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.secondary),
            const SizedBox(height: 20),
            Text(
              'Conectando ao Firebase…',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guia o usuário a ativar Authentication no Console (passo único obrigatório).
class _FirebaseSetupScreen extends StatelessWidget {
  final String? genericError;

  const _FirebaseSetupScreen({this.genericError});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Configure o Firebase Authentication',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  genericError ??
                      'Ative o login anônimo no Console para o multijogador.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                _StepTile(
                  number: '1',
                  text:
                      'Authentication → "Começar" (se ainda não clicou)',
                ),
                const SizedBox(height: 12),
                _StepTile(
                  number: '2',
                  text:
                      'Sign-in method → Anônimo (Anonymous) → Habilitar',
                ),
                const SizedBox(height: 12),
                _StepTile(
                  number: '3',
                  text: 'Recarregue esta página (Ctrl+Shift+R)',
                ),
                const SizedBox(height: 28),
                SelectableText(
                  FirebaseBootstrap.consoleAuthUrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      const ClipboardData(
                        text: FirebaseBootstrap.consoleAuthUrl,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copiado! Cole no navegador.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar link do Console'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String text;

  const _StepTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.secondary,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Dispara app_open uma vez após Firebase inicializar.
class _AnalyticsScope extends ConsumerStatefulWidget {
  final Widget child;

  const _AnalyticsScope({required this.child});

  @override
  ConsumerState<_AnalyticsScope> createState() => _AnalyticsScopeState();
}

class _AnalyticsScopeState extends ConsumerState<_AnalyticsScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logAppOpen();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ponto de entrada do aplicativo que consome o Roteador e o Tema centralizados.
class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Liahona Quiz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
