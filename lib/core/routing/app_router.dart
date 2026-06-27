import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import 'category_routes.dart';

String? _globalRedirect(BuildContext context, GoRouterState state) {
  try {
    final location = state.uri.toString();
    final path = state.uri.path;

    final roomId = state.uri.queryParameters['roomId'] ??
        extractRoomIdFromLocation(location);
    if (roomId != null && roomId.isNotEmpty) {
      return '/sala/$roomId';
    }

    final legacy = redirectLegacyPath(path);
    if (legacy != null) return legacy;
  } catch (_) {
    // Caso ocorra erro de percent encoding na URL analisada pelo GoRouterState
    try {
      final browserUrl = Uri.base.toString();
      final roomId = extractRoomIdFromLocation(browserUrl);
      if (roomId != null && roomId.isNotEmpty) {
        return '/sala/$roomId';
      }
      final fragment = Uri.base.fragment;
      if (fragment.isNotEmpty) {
        final cleanPath = fragment.split('?').first;
        final legacy = redirectLegacyPath(cleanPath);
        if (legacy != null) return legacy;
      }
    } catch (_) {}
  }

  return null;
}

/// Configuração do GoRouter para navegação do aplicativo, injetado via Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: _globalRedirect,
    onException: (context, state, router) {
      String? roomId;
      String? legacyPath;
      String? locationFallback;

      try {
        final location = state.uri.toString();
        locationFallback = location;
        roomId = extractRoomIdFromLocation(location);
        legacyPath = redirectLegacyPath(state.uri.path);
      } catch (_) {
        try {
          final browserUrl = Uri.base.toString();
          locationFallback = browserUrl;
          roomId = extractRoomIdFromLocation(browserUrl);
          final fragment = Uri.base.fragment;
          if (fragment.isNotEmpty) {
            final cleanPath = fragment.split('?').first;
            legacyPath = redirectLegacyPath(cleanPath);
          }
        } catch (_) {}
      }

      if (roomId != null && roomId.isNotEmpty) {
        router.go('/sala/$roomId');
        return;
      }
      if (legacyPath != null) {
        router.go(legacyPath);
        return;
      }
      
      final errorUri = locationFallback ?? '';
      router.go('/404?uri=${Uri.encodeComponent(errorUri)}');
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/404',
        builder: (context, state) {
          final theme = Theme.of(context);
          final uri = state.uri.queryParameters['uri'] ?? '';
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.explore_off_rounded,
                      size: 64,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Página não encontrada',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      uri,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
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
          );
        },
      ),
      GoRoute(
        path: '/join/:pin',
        redirect: (context, state) {
          final pin = state.pathParameters['pin'];
          if (pin == null || pin.isEmpty) return '/';
          return '/?join=$pin';
        },
      ),
      GoRoute(
        path: '/duelo/:pin',
        redirect: (context, state) {
          final pin = state.pathParameters['pin'];
          if (pin == null || pin.isEmpty) return '/';
          return '/?join=$pin';
        },
      ),
      GoRoute(
        path: '/estatisticas',
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: '/sala/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'];
          return QuizScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/trilha/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug'];
          return QuizScreen(
            categoryTitle: CategoryRoutes.titleForSlug(slug),
            isAdaptiveMode: true,
          );
        },
      ),
      GoRoute(
        path: '/quiz/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug'];
          return QuizScreen(categoryTitle: CategoryRoutes.titleForSlug(slug));
        },
      ),
    ],
  );
});
