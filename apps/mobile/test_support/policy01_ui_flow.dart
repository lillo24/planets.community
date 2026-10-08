import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../test/support/fake_auth.dart';
import '../test/support/fake_policy.dart';
import '../test/support/help_test_harness.dart';

/// Production screens/router with synthetic accounts and no backend writes.
Future<void> policy01UiFlow(
  WidgetTester tester, {
  LanguagePreference language = LanguagePreference.english,
  Future<void> Function(String name)? capture,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'policy-qa')),
  );
  final store = FakePolicyAcceptanceStore();
  final launcher = FakeSupportMailLauncher();
  final app = await pumpHelp(
    tester,
    auth: auth,
    policyStore: store,
    launcher: launcher,
    language: language,
  );
  final router = app.read(appRouterProvider);
  router.go('$policyAcceptancePath?returnTo=%2Fsettings');
  await helpFrames(tester, 10);
  await helpVisible(tester, 'policy-version');
  expect(find.byKey(const Key('policy-version')), findsOneWidget);
  await capture?.call('policy01-acceptance');
  await helpVisible(tester, 'policy-acceptance-continue');
  expect(
    tester
        .widget<FilledButton>(
          find.byKey(const Key('policy-acceptance-continue')),
        )
        .onPressed,
    isNull,
  );
  await helpTap(tester, 'policy-acceptance-checkbox');
  await helpTap(tester, 'policy-acceptance-continue');
  expect(store.writes, 1);
  expect(router.state.uri.path, '/settings');
  await helpTap(tester, 'settings-privacy-policy-row');
  expect(launcher.opened.last.path, '/privacy');
  await helpVisible(tester, 'settings-delete-account-row');
  await capture?.call('policy01-settings');
  await helpTap(tester, 'settings-delete-account-row');
  expect(router.state.uri.path, accountDeletionPath);
  await helpVisible(tester, 'deletion-account-email');
  await tester.enterText(
    find.byKey(const Key('deletion-account-email')),
    'qa+café@example.test',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await helpTap(tester, 'help-mail-open');
  final uri = launcher.opened.last;
  expect(uri.scheme, 'mailto');
  expect(uri.path, 'developer.planets.community@gmail.com');
  expect(
    uri.queryParameters['subject'],
    'PLANETS — Richiesta eliminazione account',
  );
  expect(uri.queryParameters['body'], contains('qa+café@example.test'));
  expect(uri.toString(), contains('%20'));
  expect(uri.queryParameters.keys, unorderedEquals(['subject', 'body']));
  expect(app.read(authSessionProvider).identity?.id, 'policy-qa');
  expect(auth.signOutCount, 0);
  await capture?.call('policy01-deletion-review');
  await helpTap(tester, 'deletion-copy-address');
  expect(
    (await tester.runAsync(() => Clipboard.getData('text/plain')))?.text,
    'developer.planets.community@gmail.com',
  );
  await helpTap(tester, 'deletion-copy-draft');
  expect(
    (await tester.runAsync(() => Clipboard.getData('text/plain')))?.text,
    contains('qa+café@example.test'),
  );
  await helpTap(tester, 'help-back');
  expect(router.state.uri.path, '/settings');
  expect(tester.takeException(), isNull);
}
