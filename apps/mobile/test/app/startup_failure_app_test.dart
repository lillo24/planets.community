import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/startup_failure_app.dart';

void main() {
  testWidgets('configuration failure is actionable and does not show secrets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StartupFailureApp(kind: StartupFailureKind.configuration),
    );

    expect(find.text('The app could not start'), findsOneWidget);
    expect(
      find.text(
        'The app configuration is unavailable. Check the setup and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY'), findsNothing);
  });

  testWidgets('backend failure uses a production-safe message', (tester) async {
    await tester.pumpWidget(
      const StartupFailureApp(kind: StartupFailureKind.backendInitialization),
    );

    expect(
      find.text('A required service is unavailable. Please try again later.'),
      findsOneWidget,
    );
  });
}
