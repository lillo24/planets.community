import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Welcome starfield and Home reservation on isolated Android', (
    tester,
  ) async {
    final store = FakeStartupStore()..version = productionTutorial.version;
    await tour.pumpTutorialSmoke(tester, store: store);
    // This widget harness bypasses bootstrap; restore its installation fixture
    // explicitly, as the real app does before launching PlanetsApp.
    final app = ProviderScope.containerOf(
      tester.element(find.byType(PlanetsApp)),
    );
    expect(await app.read(startupFlowProvider).retryRestore(), isTrue);
    await tester.pump(const Duration(seconds: 3));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('hero-polish-welcome');
    await tour.tap(tester, 'welcome-explore');
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('tutorial-screen')), findsNothing);
    expect(find.byKey(const Key('open-help-button')), findsOneWidget);
    expect(find.byKey(const Key('open-notifications-button')), findsOneWidget);
    expect(find.byKey(const Key('open-settings-button')), findsOneWidget);
    expect(find.byKey(const Key('browse-proposals-button')), findsOneWidget);
    await binding.takeScreenshot('hero-polish-home');
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });
}
