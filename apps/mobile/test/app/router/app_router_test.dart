import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import '../../support/fake_auth.dart';

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
}

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
