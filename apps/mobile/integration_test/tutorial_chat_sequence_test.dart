import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';

/// Native layout evidence with fake gateways, never a live account/backend.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    testWidgets('Project chat to Messages to Scambio ${language.name}', (
      tester,
    ) async {
      final store = FakeStartupStore();
      await tour.pumpTutorialSmoke(tester, store: store, language: language);
      const screenshots = bool.fromEnvironment('TUT06_SCREENSHOTS');
      if (screenshots) await binding.convertFlutterSurfaceToImage();
      await tour.tap(tester, 'welcome-explore');
      for (final step in TutorialStep.values) {
        await tour.ready(tester);
        expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
        if (step == TutorialStep.projectGroupChatExample) {
          tour.expectFocus(tester, 'tutorial-project-chat-label');
          tour.expectFocus(
            tester,
            'tutorial-project-chat-conversation',
            index: 1,
          );
          expect(
            find.byKey(const Key('tutorial-chat-message-giulia')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('project-chat-composer')), findsNothing);
        } else {
          expect(
            find.byKey(const Key('tutorial-project-chat-example')),
            findsNothing,
          );
        }
        if (screenshots &&
            const {
              TutorialStep.projectGroupChatExample,
              TutorialStep.messagesTabs,
              TutorialStep.messagesScopes,
              TutorialStep.homeResources,
              TutorialStep.resources,
            }.contains(step)) {
          await tester.pump();
          await binding.takeScreenshot('tut06-${language.name}-${step.name}');
        }
        expect(tester.takeException(), isNull);
        await tour.tap(tester, 'tutorial-next');
      }
      expect(store.version, productionTutorial.version);
      expect(
        find.byKey(const Key('tutorial-project-chat-example')),
        findsNothing,
      );
    });
  }
}
