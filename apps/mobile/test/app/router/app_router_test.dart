import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_profile.dart';

void main() {
  testWidgets('shows a safe localized screen for an unknown route', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    final router = createAppRouter(initialLocation: '/private/raw-path');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This page is not available.'), findsOneWidget);
    expect(find.textContaining('/private/raw-path'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('redirects verification without a pending email to request', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    final router = createAppRouter(initialLocation: '/auth/verify');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in with email'), findsWidgets);
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
  });

  testWidgets('redirects an authenticated user away from auth routes', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final profile = FakeProfileAnchorGateway()..exists = true;
    addTearDown(auth.close);
    final session = const AuthSessionState.ready(AuthIdentity(id: 'user-1'));
    final router = createAppRouter(
      initialLocation: '/auth?returnTo=https://attacker.example',
      readAuthSession: () => session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mobile foundation ready'), findsOneWidget);
    expect(find.text('This page is not available.'), findsNothing);
  });

  testWidgets('requires Auth for profile editing with a safe return path', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    const session = AuthSessionState.signedOut();
    final router = createAppRouter(
      initialLocation: '/profile/edit',
      readAuthSession: () => session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/profile/edit',
    );
  });

  testWidgets('Messages routes preserve the exact sign-in return path', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    const session = AuthSessionState.signedOut();
    const destination = '/messages/chats/chat-9/info';
    final router = createAppRouter(
      initialLocation: destination,
      readAuthSession: () => session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      destination,
    );
  });

  testWidgets('incomplete profile keeps the exact Messages completion path', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final profile = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    addTearDown(auth.close);
    const session = AuthSessionState.profileSetupRequired(
      AuthIdentity(id: 'user-1'),
      hasProfileAnchor: true,
    );
    const destination = '/messages/chats/chat-9';
    final router = createAppRouter(
      initialLocation: destination,
      readAuthSession: () => session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          appRouterProvider.overrideWithValue(router),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
          profileGatewayProvider.overrideWithValue(
            FakeProfileGateway(data: profileFixture(complete: false)),
          ),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-display-name-field')), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      destination,
    );
  });
}

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
