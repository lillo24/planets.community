import '../../../support/fake_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/data/provider_auth_adapter.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/domain/provider_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';

void main() {
  testWidgets('Google action is accessible at 320dp with Italian large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.localesTestValue = const [Locale('it')];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final semantics = tester.ensureSemantics();
    final auth = FakeAuthGateway();
    addTearDown(auth.close);
    await _pumpApp(
      tester,
      auth,
      FakeProfileAnchorGateway(),
      provider: FakeProviderAuthAdapter(),
    );
    await _openAuth(tester);
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('auth-google-button'));
    await tester.ensureVisible(button);
    expect(find.text('Continua con Google'), findsOneWidget);
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Continua con Google',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'Google tap uses shared command; busy, cancellation and safe failure',
    (tester) async {
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway();
      final pending = Completer<void>();
      final provider = FakeProviderAuthAdapter()
        ..result = const ProviderAuthCancelled()
        ..signInDelay = pending.future;
      addTearDown(auth.close);
      final app = await _pumpApp(tester, auth, profile, provider: provider);
      await _openAuth(tester);
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.textContaining('Apple'), findsNothing);
      expect(find.text('or continue with email'), findsOneWidget);
      final button = find.byKey(const Key('auth-google-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(provider.lastProvider, AuthProvider.google);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('auth-email-field')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('auth-request-button')))
            .onPressed,
        isNull,
      );
      expect(find.text('Sending sign-in code…'), findsNothing);
      await tester.tap(button);
      expect(provider.signInCount, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      expect(app.read(appRouterProvider).state.uri.path, '/auth');
      expect(profile.ensureCount, 0);
      expect(auth.requestCount, 0);

      provider.signInError = StateError('private vendor diagnostic');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text("We couldn't complete sign-in. Please try again."),
        findsOneWidget,
      );
      expect(find.textContaining('private vendor diagnostic'), findsNothing);
      expect(provider.signInCount, 2);
    },
  );

  testWidgets('Google success preserves a protected return destination', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete;
    final provider = FakeProviderAuthAdapter();
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, profile, provider: provider);
    final router = app.read(appRouterProvider);
    router.go('/profile/edit');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/auth');
    expect(router.state.uri.queryParameters['returnTo'], '/profile/edit');
    await tester.tap(find.byKey(const Key('auth-google-button')));
    await tester.pumpAndSettle();
    expect(profile.ensureCount, 1);
    expect(profile.lastUserId, 'user-1');
    expect(app.read(authSessionProvider).phase, AuthSessionPhase.ready);
    expect(router.state.uri.path, '/profile/edit');
    expect(auth.verifyCount, 0);
  });

  testWidgets(
    'OTP Back retains the verified session after profile-anchor failure',
    (tester) async {
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway()
        ..ensureError = StateError('synthetic anchor failure');
      addTearDown(auth.close);
      final app = await _pumpApp(tester, auth, profile);
      await _openAuth(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'example@example.invalid',
      );
      await tester.tap(find.byKey(const Key('auth-request-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('auth-verify-button')));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      expect(app.read(appRouterProvider).state.uri.path, '/auth/verify');
      final changeEmail = find.byKey(const Key('auth-verify-back-button'));
      await tester.ensureVisible(changeEmail);
      await tester.tap(changeEmail);
      await tester.pumpAndSettle();
      expect(app.read(appRouterProvider).state.uri.path, '/intro');
      expect(app.read(authSessionProvider).isAuthenticated, isTrue);
      expect(app.read(pendingEmailOtpProvider), isNull);
      expect(auth.verifyCount, 1);
    },
  );

  testWidgets('requests a code once and shows only a masked email', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    await _pumpApp(tester, auth, profile);

    await _openAuth(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'Google|Apple')), findsNothing);
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'Person@Example.com',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pumpAndSettle();

    expect(auth.requestCount, 1);
    expect(find.textContaining('P•••@Example.com'), findsOneWidget);
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
    await _openAuth(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );

    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pump();
    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('auth-email-field')),
    );
    expect(emailField.enabled, isFalse);
    expect(emailField.controller?.text, 'person@example.com');
    expect(find.text('Sending sign-in code…'), findsOneWidget);
    expect(find.byKey(const Key('auth-request-progress')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-request-button')))
          .onPressed,
      isNull,
    );
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
    await _openAuth(tester);
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

  testWidgets('voluntary Auth close and system Back both return Home', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, profile);
    final router = app.read(appRouterProvider);

    await _openAuth(tester);
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/auth');
    await tester.tap(find.byKey(const Key('auth-close-button')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byKey(const Key('home-planets-hero')), findsOneWidget);

    await _openAuth(tester);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
  });

  testWidgets('protected Auth cancel escapes to public Home', (tester) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, profile);
    final router = app.read(appRouterProvider);

    router.go('/profile/edit');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/auth');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/profile/edit',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byKey(const Key('home-planets-hero')), findsOneWidget);
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
  });

  testWidgets('verification Back preserves the protected return destination', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, profile);
    final router = app.read(appRouterProvider);

    router.go('/profile/edit');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/auth/verify');
    expect(app.read(pendingEmailOtpProvider)?.returnTo, '/profile/edit');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/auth');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/profile/edit',
    );
    expect(app.read(pendingEmailOtpProvider), isNull);
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
  });

  testWidgets(
    'OTP request timeout restores the form and ignores late success',
    (tester) async {
      final completer = Completer<void>();
      final auth = FakeAuthGateway()..requestDelay = completer.future;
      final profile = FakeProfileAnchorGateway();
      addTearDown(auth.close);
      final app = await _pumpApp(
        tester,
        auth,
        profile,
        requestTimeout: const Duration(milliseconds: 10),
      );
      final router = app.read(appRouterProvider);

      await _openAuth(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'person@example.com',
      );
      await tester.tap(find.byKey(const Key('auth-request-button')));
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        find.text(
          'The sign-in request took too long. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('auth-email-field')))
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('auth-email-field')))
            .controller
            ?.text,
        'person@example.com',
      );
      expect(app.read(pendingEmailOtpProvider), isNull);

      completer.complete();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/auth');
      expect(find.byKey(const Key('auth-code-field')), findsNothing);
      expect(app.read(pendingEmailOtpProvider), isNull);
    },
  );

  testWidgets('closing Auth abandons an in-flight OTP request', (tester) async {
    final completer = Completer<void>();
    final auth = FakeAuthGateway()..requestDelay = completer.future;
    final profile = FakeProfileAnchorGateway();
    addTearDown(auth.close);
    final app = await _pumpApp(tester, auth, profile);
    final router = app.read(appRouterProvider);

    await _openAuth(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await tester.tap(find.byKey(const Key('auth-request-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-close-button')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');

    completer.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byKey(const Key('auth-code-field')), findsNothing);
    expect(app.read(pendingEmailOtpProvider), isNull);
  });
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeAuthGateway auth,
  FakeProfileAnchorGateway profile, {
  Duration? requestTimeout,
  ProviderAuthAdapter? provider,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preacceptedPolicyFixture,
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(profile),
        if (provider != null)
          providerAuthAdapterProvider.overrideWithValue(provider),
        if (requestTimeout != null)
          authOtpRequestTimeoutProvider.overrideWithValue(requestTimeout),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _openAuth(WidgetTester tester) async {
  final welcome = find.byKey(const Key('welcome-login'));
  if (welcome.evaluate().isNotEmpty) {
    await tester.tap(welcome);
  } else {
    final app = ProviderScope.containerOf(
      tester.element(find.byType(PlanetsApp)),
    );
    app.read(appRouterProvider).go('/profile');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('profile-example-sign-in-button')),
    );
    await tester.tap(find.byKey(const Key('profile-example-sign-in-button')));
  }
}
