import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Eventos de produto para funis no GA4 / Firebase Analytics.
class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService(this._analytics);

  Future<void> logAppOpen() => _safeLog(() => _analytics.logAppOpen());

  Future<void> logQuizStarted({
    required String mode,
    required String category,
  }) =>
      _safeLog(
        () => _analytics.logEvent(
          name: 'quiz_started',
          parameters: {
            'mode': mode,
            'category': category,
          },
        ),
      );

  Future<void> logQuizFinished({
    required String mode,
    required String category,
    required int score,
    required int total,
  }) =>
      _safeLog(
        () => _analytics.logEvent(
          name: 'quiz_finished',
          parameters: {
            'mode': mode,
            'category': category,
            'score': score,
            'total': total,
          },
        ),
      );

  Future<void> logRoomCreated({required String gameMode}) => _safeLog(
        () => _analytics.logEvent(
          name: 'room_created',
          parameters: {'game_mode': gameMode},
        ),
      );

  Future<void> logRoomJoined({required String gameMode}) => _safeLog(
        () => _analytics.logEvent(
          name: 'room_joined',
          parameters: {'game_mode': gameMode},
        ),
      );

  Future<void> _safeLog(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Analytics: $error');
    }
  }
}

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(firebaseAnalyticsProvider));
});
