import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/help/application/support_mail.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../app/startup/interactive_tutorial_test.dart' as tour;
import '../../support/fake_auth.dart';
import '../../support/fake_message_chats.dart';
import '../../support/fake_messages.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_resource_listing.dart';
import '../../support/fake_startup.dart';
import '../../support/help_test_harness.dart';

void main() {
  test(
    'mail URI round-trips unicode and delimiters without adding private fields',
    () {
      final uri = supportMailUri(
        'support@example.test',
        subject: 'Caffè & + ? #',
        body: 'A B\nOTP? no & + é',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@example.test');
      expect(uri.queryParameters, {
        'subject': 'Caffè & + ? #',
        'body': 'A B\nOTP? no & + é',
      });
      expect(uri.toString(), contains('A%20B'));
      expect(
        () => supportMailUri('support@example.test?bcc=other', subject: 'Hi'),
        throwsFormatException,
      );
    },
  );

  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    for (final narrow in [false, true]) {
      testWidgets(
        'Home help bell gear and menu work: $language narrow=$narrow',
        (tester) async {
          if (narrow) {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(320, 780);
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearAllTestValues);
          }
          final app = await pumpHelp(tester, language: language);
          for (final key in [
            'open-help-button',
            'open-notifications-button',
            'open-settings-button',
          ]) {
            final finder = find.byKey(Key(key)).hitTestable();
            expect(finder, findsOneWidget);
            expect(tester.getSize(finder).width, greaterThanOrEqualTo(48));
          }
          expect(find.byKey(const Key('home-planets-hero')), findsOneWidget);
          await helpTap(tester, 'open-notifications-button');
          expect(find.byType(SnackBar), findsOneWidget);
          await helpTap(tester, 'open-help-button');
          expect(
            app.read(appRouterProvider).routerDelegate.state.uri.path,
            '/help',
          );
          expect(
            find.text(
              language == LanguagePreference.italian
                  ? 'Contatta i creatori'
                  : 'Contact the creators',
            ),
            findsOneWidget,
          );
          await helpTap(tester, 'help-person-action');
          expect(find.byKey(const Key('help-person-screen')), findsOneWidget);
          expect(find.byType(TextFormField), findsNothing);
          expect(
            find.textContaining(
              language == LanguagePreference.italian
                  ? 'non è ancora disponibile'
                  : 'not yet available',
            ),
            findsOneWidget,
          );
          await helpTap(tester, 'help-back');
          await helpTap(tester, 'help-back');
          expect(
            app.read(appRouterProvider).routerDelegate.state.uri.path,
            '/',
          );
          expect(tester.takeException(), isNull);
          await helpTap(tester, 'open-settings-button');
          expect(
            app.read(appRouterProvider).routerDelegate.state.uri.path,
            '/settings',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final readiness in [
    ProfileAnchorReadiness.complete,
    ProfileAnchorReadiness.incomplete,
  ]) {
    testWidgets('Help stays public with signed-in readiness $readiness', (
      tester,
    ) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
      );
      final app = await pumpHelp(tester, auth: auth, readiness: readiness);
      await helpTap(tester, 'open-help-button');
      await helpTap(tester, 'help-contact-action');
      expect(
        app.read(appRouterProvider).routerDelegate.state.uri.path,
        '/help/contact',
      );
      expect(find.byKey(const Key('help-mail-open')), findsOneWidget);
      await helpTap(tester, 'help-back');
      await helpTap(tester, 'help-back');
      expect(find.byKey(const Key('open-help-button')), findsOneWidget);
      expect(auth.signOutCount, 0);
    });
  }

  testWidgets('direct Help entry has safe Home Back', (tester) async {
    final app = await pumpHelp(tester);
    app.read(appRouterProvider).go('/help');
    await tester.pumpAndSettle();
    await helpTap(tester, 'help-back');
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
  });

  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    testWidgets('bug review and creator contact fit at 320px / 2x: $language', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final app = await pumpHelp(
        tester,
        language: language,
        launcher: FakeSupportMailLauncher(),
      );
      await openBug(tester, app);
      await reviewBug(tester);
      await helpTap(tester, 'help-mail-open');
      expect(find.byKey(const Key('help-mail-status')), findsOneWidget);
      expect(tester.takeException(), isNull);
      app.read(appRouterProvider).go('/help/contact');
      await tester.pumpAndSettle();
      await helpTap(tester, 'help-mail-open');
      expect(find.byKey(const Key('help-mail-status')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final email in <String?>[null, 'not an approved address']) {
    testWidgets('unconfigured contact and bug allow draft/copy only: $email', (
      tester,
    ) async {
      final launcher = FakeSupportMailLauncher();
      final app = await pumpHelp(tester, email: email, launcher: launcher);
      app.read(appRouterProvider).go('/help/contact');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-mail-unconfigured')), findsOneWidget);
      expect(find.byKey(const Key('help-mail-open')), findsNothing);
      await openBug(tester, app);
      await reviewBug(tester);
      expect(find.byKey(const Key('help-mail-unconfigured')), findsOneWidget);
      expect(find.byKey(const Key('help-mail-open')), findsNothing);
      expect(find.byKey(const Key('help-bug-copy')), findsOneWidget);
      expect(launcher.opened, isEmpty);
    });
  }

  for (final fail in [false, true]) {
    testWidgets(
      'contact handles ${fail ? 'platform exception' : 'missing mail client'} honestly',
      (tester) async {
        final launcher = FakeSupportMailLauncher()..result = false;
        if (fail) launcher.error = PlatformException(code: 'unavailable');
        final app = await pumpHelp(tester, launcher: launcher);
        app.read(appRouterProvider).go('/help/contact');
        await tester.pumpAndSettle();
        await helpTap(tester, 'help-mail-open');
        expect(find.textContaining('could not be opened'), findsOneWidget);
        expect(find.textContaining('Mail app opened.'), findsNothing);
        expect(
          launcher.opened.single.path,
          'developer.planets.community@gmail.com',
        );
      },
    );
  }

  testWidgets(
    'bug validates description, reviews exact entered text and retains cancelled composer draft',
    (tester) async {
      final launcher = FakeSupportMailLauncher();
      final app = await pumpHelp(tester, launcher: launcher);
      await openBug(tester, app);
      await tester.enterText(
        find.byKey(const Key('help-bug-description')),
        '   ',
      );
      await helpTap(tester, 'help-bug-review');
      expect(
        find.text('Describe the problem before reviewing the draft.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('help-bug-steps')),
        'Tap + & café\nthen wait',
      );
      await tester.enterText(
        find.byKey(const Key('help-bug-expected')),
        'A usable screen',
      );
      await reviewBug(tester, description: '  White screen? #  ');
      final draft = tester
          .widget<SelectableText>(find.byKey(const Key('help-bug-draft')))
          .data!;
      expect(
        draft,
        'Problem description (required):\nWhite screen? #\n\nSteps to reproduce (optional):\nTap + & café\nthen wait\n\nExpected result (optional):\nA usable screen',
      );
      await helpTap(tester, 'help-mail-open');
      expect(launcher.opened.single.queryParameters['body'], draft);
      expect(
        launcher.opened.single.queryParameters.keys,
        unorderedEquals(['subject', 'body']),
      );
      expect(
        find.text('Mail app opened. You choose whether to send.'),
        findsOneWidget,
      );
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('help-bug-draft')))
            .data,
        draft,
      );
      await helpTap(tester, 'help-bug-edit');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('help-bug-description')),
            )
            .controller!
            .text,
        '  White screen? #  ',
      );
      expect(launcher.opened.length, 1);
    },
  );

  testWidgets(
    'explicit copy includes only reviewed input and clipboard failure is visible',
    (tester) async {
      final copied = <String>[];
      bool fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (fail) throw PlatformException(code: 'clipboard-unavailable');
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final app = await pumpHelp(tester, email: null);
      await openBug(tester, app);
      await reviewBug(tester, description: 'Only my text');
      expect(copied, isEmpty);
      await helpTap(tester, 'help-bug-copy');
      expect(copied, ['Problem description (required):\nOnly my text']);
      expect(find.text('Draft copied.'), findsOneWidget);
      fail = true;
      await helpTap(tester, 'help-bug-copy');
      expect(
        find.text('The draft could not be copied. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'account replacement clears draft and ignores pending mail completion',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
      );
      final completion = Completer<bool>();
      final launcher = FakeSupportMailLauncher()..delay = completion.future;
      final app = await pumpHelp(tester, auth: auth, launcher: launcher);
      await openBug(tester, app);
      await reviewBug(tester, description: 'Alice private note');
      await helpTap(tester, 'help-mail-open');
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'bob')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-bug-draft')), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('help-bug-description')),
            )
            .controller!
            .text,
        isEmpty,
      );
      completion.complete(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-mail-status')), findsNothing);
      expect(find.textContaining('Alice private note'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same-owner token refresh retains draft; sign-out clears it', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
    );
    final app = await pumpHelp(tester, auth: auth);
    await openBug(tester, app);
    await reviewBug(tester);
    auth.emit(
      const AuthSnapshot(
        identity: AuthIdentity(id: 'alice'),
        isTokenRefresh: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-bug-draft')), findsOneWidget);
    auth.emit(const AuthSnapshot());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-bug-draft')), findsNothing);
    expect(find.byKey(const Key('help-bug-description')), findsOneWidget);
  });

  for (final exit in ['finish', 'skip', 'back']) {
    for (final signedIn in [false, true]) {
      testWidgets(
        'Help replay $exit preserves ${signedIn ? 'completed ready' : 'dismissed guest'} state and returns',
        (tester) async {
          final store = FakeStartupStore()
            ..version = signedIn
                ? productionTutorial.version
                : 'dismissed:${productionTutorial.version}';
          final original = store.version;
          final auth = FakeAuthGateway(
            snapshot: signedIn
                ? const AuthSnapshot(identity: AuthIdentity(id: 'alice'))
                : const AuthSnapshot(),
          );
          final proposals = FakeProposalGateway();
          final resources = FakeResourceListingGateway();
          final chats = FakeMessageChatsGateway();
          final messages = FakeMessagesGateway();
          final app = await pumpHelp(
            tester,
            auth: auth,
            store: store,
            proposals: proposals,
            resources: resources,
            chats: chats,
            messages: messages,
          );
          await helpTap(tester, 'open-help-button');
          // This route starts a timed tutorial; bounded pumps preserve determinism.
          await tester.tap(find.byKey(const Key('help-tutorial-action')));
          await tour.frames(tester, 6);
          expect(find.byKey(const Key('tutorial-screen')), findsOneWidget);
          if (exit == 'finish') {
            for (final step in TutorialStep.values) {
              await tour.ready(tester);
              expect(
                find.byKey(Key('tutorial-copy-${step.name}')),
                findsOneWidget,
              );
              await tour.tap(tester, 'tutorial-next');
            }
          } else if (exit == 'skip') {
            await tour.tap(tester, 'tutorial-skip');
          } else {
            await tester.binding.handlePopRoute();
            await tour.frames(tester, 6);
          }
          expect(
            app.read(appRouterProvider).routerDelegate.state.uri.path,
            '/help',
          );
          expect(find.byKey(const Key('help-screen')), findsOneWidget);
          expect(store.version, original);
          expect(store.writes, 0);
          expect(store.resets, 0);
          expect(auth.signOutCount, 0);
          expect(
            proposals.calls.every(
              (call) =>
                  call.startsWith('list-') || call.startsWith('public-detail'),
            ),
            isTrue,
          );
          expect(resources.createCount, 0);
          expect(chats.calls, isEmpty);
          expect(messages.calls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
