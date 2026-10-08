import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('complete backend-free guest tutorial on Android', (
    tester,
  ) async {
    final store = FakeStartupStore();
    await tour.pumpTutorialSmoke(tester, store: store);
    await tour.tap(tester, 'welcome-explore');
    for (final step in TutorialStep.values) {
      await tour.ready(tester);
      expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(store.writes, 0);
      await tour.tap(tester, 'tutorial-next');
    }
    expect(store.version, productionTutorial.version);
    expect(find.byKey(const Key('browse-proposals-button')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-screen')), findsNothing);
  });
}
