import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';

void main() {
  testWidgets('requests a code once and shows only a masked email', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, profile);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'Person@Example.com',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pumpAndSettle();

    expect(auth.requestCount, 1);
    expect(find.textContaining('p•••@example.com'), findsOneWidget);
    expect(find.textContaining('Person@Example.com'), findsNothing);
    expect(find.byKey(const Key('auth-code-field')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disables duplicate submission while a request is active', (
    tester,
  ) async {
    final completer = Completer<void>();
    final auth = FakeAuthGateway()..requestDelay = completer.future;
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, profile);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );

    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-request-button')));
    expect(auth.requestCount, 1);
    completer.complete();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders a safe message instead of backend details', (
    tester,
  ) async {
    const rawDetail = 'raw backend stack and private diagnostic';
    final auth = FakeAuthGateway()
      ..requestError = const AuthException(rawDetail, code: 'unexpected_error');
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, profile);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't complete sign-in. Please try again."),
      findsOneWidget,
    );
    expect(find.textContaining(rawDetail), findsNothing);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  FakeAuthGateway auth,
  FakeProfileAnchorGateway profile,
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
        profileAnchorGatewayProvider.overrideWithValue(profile),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
}
