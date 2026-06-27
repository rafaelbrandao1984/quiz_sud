import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_sud/main.dart';
import 'package:quiz_sud/core/routing/app_router.dart';

void main() {
  testWidgets('Quiz SUD load smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MainApp(),
      ),
    );

    // Verify that our app renders and contains the title 'Liahona Quiz'.
    expect(find.text('Liahona Quiz'), findsAtLeast(1));
  });

  testWidgets('Legacy URL Obras Padrao redirect test', (WidgetTester tester) async {
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);

    // Navigate to the legacy URL
    router.go('/quiz/Obras%20Padrão?roomId=660782');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MainApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that GoRouter routed us to the Sala screen path
    expect(router.routeInformationProvider.value.uri.path, equals('/sala/660782'));

    // Clean up container resources to avoid pending timers/streams error
    container.dispose();
  });
}
