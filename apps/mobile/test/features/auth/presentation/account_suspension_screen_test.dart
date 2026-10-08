import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';

import '../../../support/fake_auth.dart';
import '../application/account_suspension_test.dart' show activeStatus;

void main() {
  testWidgets(
    'all routes and invite deep links stay on the safe screen without loops',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      )..suspension = activeStatus();
      addTearDown(auth.close);
      final container = await pumpApp(tester, auth);
      final router = container.read(appRouterProvider);
      expect(find.text('Account suspended'), findsOneWidget);
      expect(find.text('Synthetic subject reason'), findsOneWidget);
      for (final path in [
        '/welcome',
        '/intro',
        '/drafts',
        '/profile',
        '/profile/edit',
        '/settings',
        '/messages',
        '/notifications',
        '/resources',
        '/auth',
        '/auth/verify',
        '/invite/project/token',
        '/messages/chats/chat-1',
        '/account/suspended?returnTo=/account/suspended',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/account/suspended',
        );
      }
      await tester.tap(find.byKey(const Key('account-status-check')));
      await tester.pumpAndSettle();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.suspended,
      );
      await tester.tap(find.byKey(const Key('account-status-sign-out')));
      await tester.pumpAndSettle();
      expect(auth.signOutCount, 1);
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.signedOut,
      );
      expect(find.text('Synthetic subject reason'), findsNothing);
    },
  );

  testWidgets(
    'foreground refresh detects suspension and revocation; errors remain closed',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      addTearDown(auth.close);
      final container = await pumpApp(tester, auth);
      auth.suspension = activeStatus();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.suspended,
      );
      auth.suspensionError = StateError('PRIVATE diagnostics');
      await tester.tap(find.byKey(const Key('account-status-check')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Account access could not be verified. Try again or sign out.',
        ),
        findsOneWidget,
      );
      expect(find.text('PRIVATE diagnostics'), findsNothing);
      auth.suspensionError = null;
      auth.suspension = const AccountSuspensionStatus.inactive();
      await tester.tap(find.byKey(const Key('account-status-check')));
      await tester.pumpAndSettle();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.profileSetupRequired,
      );
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/',
      );
    },
  );

  testWidgets('private-link restoration failure can retry the stored session', (
    tester,
  ) async {
    final auth = FakeAuthGateway()
      ..snapshotError = StateError('private restore error');
    addTearDown(auth.close);
    final container = await pumpApp(tester, auth);
    final router = container.read(appRouterProvider);
    router.go('/settings/notices');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/account/suspended',
    );
    expect(
      find.text(
        'Private moderation notices and their history, with the reasons intended for you. This is not a public profile badge or a score.',
      ),
      findsNothing,
    );
    expect(
      find.text('Account access could not be verified. Try again or sign out.'),
      findsOneWidget,
    );
    expect(find.text('private restore error'), findsNothing);
    auth.snapshotError = null;
    await tester.tap(find.byKey(const Key('account-status-check')));
    await tester.pumpAndSettle();
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.signedOut,
    );
    expect(router.routeInformationProvider.value.uri.path, '/auth');
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
  });
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeAuthGateway auth,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}
