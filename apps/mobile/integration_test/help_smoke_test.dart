import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/features/help/application/support_mail.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';
import '../test/support/help_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Home Help replay and reviewed bug draft on Android', (
    tester,
  ) async {
    // The real unavailable-handler branch is opt-in on an owned QA device with
    // no enabled mail app. Default smoke never opens another application.
    const noMailClient = bool.fromEnvironment('HELP01_NO_MAIL_CLIENT');
    final store = FakeStartupStore()..version = productionTutorial.version;
    await pumpHelp(
      tester,
      store: store,
      launcher: noMailClient
          ? const ExternalSupportMailLauncher()
          : FakeSupportMailLauncher(),
    );
    await helpTap(tester, 'open-help-button');
    await tester.tap(find.byKey(const Key('help-tutorial-action')));
    await tour.frames(tester, 6);
    for (final step in TutorialStep.values) {
      await tour.ready(tester);
      expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
      await tour.tap(tester, 'tutorial-next');
    }
    expect(find.byKey(const Key('help-screen')), findsOneWidget);
    expect(store.version, productionTutorial.version);
    expect(store.writes, 0);
    await helpTap(tester, 'help-person-action');
    expect(find.textContaining('not yet available'), findsOneWidget);
    await helpTap(tester, 'help-back');
    await helpTap(tester, 'help-contact-action');
    await helpTap(tester, 'help-mail-open');
    expect(
      find.textContaining(
        noMailClient ? 'could not be opened' : 'You choose whether to send.',
      ),
      findsWidgets,
    );
    await helpTap(tester, 'help-back');
    await helpTap(tester, 'help-bug-action');
    await reviewBug(
      tester,
      description: 'Android smoke: a screen freezes & + café',
    );
    await helpTap(tester, 'help-mail-open');
    expect(
      find.textContaining(
        noMailClient ? 'could not be opened' : 'Mail app opened.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('help-bug-draft')), findsOneWidget);
    await helpTap(tester, 'help-bug-copy');
    expect(find.text('Draft copied.'), findsOneWidget);
    await helpTap(tester, 'help-bug-edit');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('help-bug-description')))
          .controller!
          .text,
      contains('Android smoke:'),
    );
    expect(tester.takeException(), isNull);
  });
}
