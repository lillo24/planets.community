import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../../test_support/policy01_ui_flow.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_policy.dart';
import '../../support/help_test_harness.dart';

void main() {
  setUp(() {
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    testWidgets('review, Settings and manual deletion at 320px/2x: $language', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await policy01UiFlow(tester, language: language);
    });
  }
  for (final readiness in [
    null,
    ProfileAnchorReadiness.missing,
    ProfileAnchorReadiness.incomplete,
    ProfileAnchorReadiness.complete,
  ]) {
    testWidgets('public privacy and final deletion action: $readiness', (
      tester,
    ) async {
      final auth = FakeAuthGateway(
        snapshot: AuthSnapshot(
          identity: readiness == null ? null : const AuthIdentity(id: 'alice'),
        ),
      );
      final app = await pumpHelp(
        tester,
        auth: auth,
        readiness: readiness ?? ProfileAnchorReadiness.missing,
      );
      app.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-privacy-policy-row')),
        findsOneWidget,
      );
      if (readiness == null) {
        expect(
          find.byKey(const Key('settings-delete-account-row')),
          findsNothing,
        );
        app.read(appRouterProvider).go(accountDeletionPath);
        await tester.pumpAndSettle();
        await helpVisible(tester, 'deletion-mail-review');
        expect(find.byKey(const Key('deletion-mail-review')), findsOneWidget);
      } else {
        await helpVisible(tester, 'settings-delete-account-row');
        final list = tester.widget<ListView>(find.byType(ListView).last);
        final delegate = list.childrenDelegate as SliverChildListDelegate;
        expect(
          delegate.children.last.key,
          const Key('settings-delete-account-row'),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'link failures and unavailable email retain explicit copy and account state',
    (tester) async {
      final launcher = FakeSupportMailLauncher()..result = false;
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
      );
      final app = await pumpHelp(tester, auth: auth, launcher: launcher);
      final router = app.read(appRouterProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      await helpTap(tester, 'settings-privacy-policy-row');
      expect(find.textContaining('Could not open the page.'), findsOneWidget);
      final copy = find.text('Copy link');
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(
        (await Clipboard.getData('text/plain'))?.text,
        endsWith('/privacy'),
      );
      router.go(accountDeletionPath);
      await tester.pumpAndSettle();
      await helpTap(tester, 'help-mail-open');
      expect(find.textContaining('could not be opened'), findsOneWidget);
      expect(find.byKey(const Key('deletion-mail-review')), findsOneWidget);
      expect(app.read(authSessionProvider).identity?.id, 'alice');
      expect(auth.signOutCount, 0);
    },
  );
  testWidgets('acceptance write error supports retry without continuing', (
    tester,
  ) async {
    final store = FakePolicyAcceptanceStore()
      ..writeError = StateError('sensitive error');
    final app = await pumpHelp(
      tester,
      auth: FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
      ),
      policyStore: store,
    );
    final router = app.read(appRouterProvider);
    router.go('$policyAcceptancePath?returnTo=%2Fsettings');
    await tester.pumpAndSettle();
    await helpTap(tester, 'policy-acceptance-checkbox');
    await helpTap(tester, 'policy-acceptance-continue');
    expect(router.state.uri.path, policyAcceptancePath);
    expect(find.textContaining('sensitive error'), findsNothing);
    expect(
      app.read(policyAcceptanceProvider).phase,
      PolicyAcceptancePhase.writeFailed,
    );
    store.writeError = null;
    await helpTap(tester, 'policy-acceptance-continue');
    expect(router.state.uri.path, '/settings');
  });
  testWidgets(
    'router gates writes but preserves public/support/safety access and continuations',
    (tester) async {
      final app = await pumpHelp(
        tester,
        auth: FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
        ),
        policyStore: FakePolicyAcceptanceStore(),
        readiness: ProfileAnchorReadiness.incomplete,
      );
      final router = app.read(appRouterProvider);
      for (final path in [
        '/profile/edit?returnTo=%2Fsettings',
        '/proposals/create',
        '/resources/create',
        '/messages/chats/qa',
        "/join/project/${'a' * 43}",
        "/invite/project/${'b' * 43}",
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, policyAcceptancePath);
        expect(router.state.uri.queryParameters['returnTo'], path);
        await helpTap(tester, 'help-back');
        expect(router.state.uri.path, '/');
      }
      router.go("/auth?returnTo=%2Fjoin%2Fproject%2F${'a' * 43}");
      await tester.pumpAndSettle();
      expect(router.state.uri.path, policyAcceptancePath);
      final continuation = Uri.parse(
        router.state.uri.queryParameters['returnTo']!,
      );
      expect(continuation.path, '/profile/edit');
      expect(
        continuation.queryParameters['returnTo'],
        "/join/project/${'a' * 43}",
      );
      final pendingPolicyUri = router.state.uri;
      await helpTap(tester, 'policy-acceptance-checkbox');
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {
            'location': "https://planets.community/join/project/${'a' * 43}",
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(router.state.uri, pendingPolicyUri);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('policy-acceptance-checkbox')),
            )
            .value,
        isTrue,
      );
      for (final path in [
        '/settings',
        '/help',
        '/help/bug',
        accountDeletionPath,
        '/proposals',
        '/resources',
        '/profile/reports',
        '/profile/blocked-users',
      ]) {
        router.go(path);
        await helpFrames(tester, 6);
        expect(
          router.state.uri.path,
          isNot(policyAcceptancePath),
          reason: path,
        );
      }
      router.go('/auth?returnTo=%2Fprofile%2Freports');
      await helpFrames(tester, 6);
      expect(router.state.uri.path, '/profile/reports');
      router.go('/settings');
      await tester.pumpAndSettle();
      await helpTap(tester, 'account-sign-out-button');
      expect(app.read(authSessionProvider).isAuthenticated, isFalse);
    },
  );
  testWidgets('identity changes clear draft and ignore old mail handoff', (
    tester,
  ) async {
    final delay = Completer<bool>();
    final launcher = FakeSupportMailLauncher()..delay = delay.future;
    final app = await pumpHelp(
      tester,
      auth: FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'alice')),
      ),
      launcher: launcher,
    );
    app.read(appRouterProvider).go(accountDeletionPath);
    await tester.pumpAndSettle();
    await helpVisible(tester, 'deletion-account-email');
    await tester.enterText(
      find.byKey(const Key('deletion-account-email')),
      'alice@example.test',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await helpVisible(tester, 'help-mail-open');
    await tester.tap(find.byKey(const Key('help-mail-open')));
    await tester.pump();
    app
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'bob'));
    await tester.pumpAndSettle();
    delay.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('alice@example.test'), findsNothing);
    expect(find.byKey(const Key('help-mail-status')), findsNothing);
  });
}
