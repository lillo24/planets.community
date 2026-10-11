import '../../../support/fake_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:planets_mobile/features/auth/presentation/google_sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';

void main() {
  testWidgets(
    'method choice uses bundled Google mark and explicit email navigation',
    (tester) async {
      final auth = FakeAuthGateway();
      final provider = FakeProviderAuthAdapter();
      addTearDown(auth.close);
      final app = await _pumpApp(
        tester,
        auth,
        FakeProfileAnchorGateway(),
        provider: provider,
      );
      final router = app.read(appRouterProvider);
      router.go('/auth?returnTo=%2Fmessages%2Fchats%2Fchat-9');
      await tester.pumpAndSettle();
      final mark = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('auth-google-button')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (mark.image as AssetImage).assetName,
        GoogleSignInButton.markAsset,
      );
      expect(mark.width, 18);
      expect(mark.height, 18);
      expect(
        tester.getSize(find.byKey(const Key('auth-google-button'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byKey(const Key('auth-email-field')), findsNothing);
      expect(find.byKey(const Key('auth-request-button')), findsNothing);
      expect(find.textContaining('6-digit'), findsNothing);
      await tester.tap(find.byKey(const Key('auth-email-method-button')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/auth/email');
      expect(
        router.state.uri.queryParameters['returnTo'],
        '/messages/chats/chat-9',
      );
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-google-button')), findsNothing);
      expect(auth.requestCount, 0);
      expect(provider.signInCount, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/auth');
      expect(
        router.state.uri.queryParameters['returnTo'],
        '/messages/chats/chat-9',
      );
      await tester.tap(find.byKey(const Key('auth-close-button')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/messages');
    },
  );

  for (final google in [false, true]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'verify returns to email: Google=$google systemBack=$systemBack',
        (tester) async {
          final auth = FakeAuthGateway();
          final provider = FakeProviderAuthAdapter();
          addTearDown(auth.close);
          final app = await _pumpApp(
            tester,
            auth,
            FakeProfileAnchorGateway(),
            provider: google ? provider : null,
          );
          final router = app.read(appRouterProvider);
          router.go('/auth/email?returnTo=%2Fmessages%2Fchats%2Fchat-9');
          await tester.pumpAndSettle();
          expect(auth.requestCount, 0);
          await tester.enterText(
            find.byKey(const Key('auth-email-field')),
            'synthetic@planets.invalid',
          );
          await tester.tap(find.byKey(const Key('auth-request-button')));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/auth/verify');
          expect(
            app.read(pendingEmailOtpProvider)?.returnTo,
            '/messages/chats/chat-9',
          );
          expect(app.read(authCommandProvider).resendAvailableAt, isNotNull);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            final back = find.byKey(const Key('auth-verify-back-button'));
            await tester.ensureVisible(back);
            await tester.tap(back);
          }
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/auth/email');
          expect(
            router.state.uri.queryParameters['returnTo'],
            '/messages/chats/chat-9',
          );
          expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
          expect(find.byKey(const Key('auth-google-button')), findsNothing);
          expect(app.read(pendingEmailOtpProvider), isNull);
          expect(app.read(authCommandProvider).resendAvailableAt, isNull);
          expect(auth.requestCount, 1);
          expect(auth.verifyCount, 0);
          expect(provider.signInCount, 0);
          await tester.tap(find.byKey(const Key('auth-close-button')));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/messages');
        },
      );
    }
  }

  testWidgets(
    'email Back abandons in-flight request and ignores its late completion',
    (tester) async {
      final pending = Completer<void>();
      final auth = FakeAuthGateway()..requestDelay = pending.future;
      addTearDown(auth.close);
      final app = await _pumpApp(
        tester,
        auth,
        FakeProfileAnchorGateway(),
        provider: FakeProviderAuthAdapter(),
      );
      final router = app.read(appRouterProvider);
      router.go('/auth/email?returnTo=%2Fsettings');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'synthetic@planets.invalid',
      );
      await tester.tap(find.byKey(const Key('auth-request-button')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/auth');
      pending.complete();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/auth');
      expect(app.read(pendingEmailOtpProvider), isNull);
    },
  );

  testWidgets(
    'OTP-only direct email Back cancels; hostile returnTo stays internal',
    (tester) async {
      final auth = FakeAuthGateway();
      addTearDown(auth.close);
      final app = await _pumpApp(tester, auth, FakeProfileAnchorGateway());
      final router = app.read(appRouterProvider);
      router.go('/auth/email?returnTo=https%3A%2F%2Fattacker.invalid');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-email-back-button')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/welcome');
      expect(auth.requestCount, 0);
    },
  );

  for (final language in ['en', 'it']) {
    for (final brightness in Brightness.values) {
      testWidgets('chooser is accessible at 320dp/2x: $language $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.localesTestValue = [Locale(language)];
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
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
        final googleLabel = language == 'it'
            ? 'Continua con Google'
            : 'Continue with Google';
        final emailLabel = language == 'it'
            ? 'oppure accedi con email e codice OTP'
            : 'or sign in with your email + OTP';
        expect(find.text(googleLabel), findsOneWidget);
        expect(
          tester.getSemantics(button),
          matchesSemantics(
            label: googleLabel,
            isButton: true,
            hasTapAction: true,
            hasFocusAction: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
          ),
        );
        final email = find.byKey(const Key('auth-email-method-button'));
        expect(tester.getSize(email).height, greaterThanOrEqualTo(48));
        expect(
          tester.getSemantics(email),
          matchesSemantics(
            label: emailLabel,
            isButton: true,
            hasTapAction: true,
            hasFocusAction: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
          ),
        );
        final mark = find.descendant(of: button, matching: find.byType(Image));
        expect(tester.getSize(mark), const Size(18, 18));
        expect(tester.getRect(button).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(button).right, lessThanOrEqualTo(320));
        Focus.of(tester.element(find.text(googleLabel))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text(emailLabel))).hasFocus,
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
        final emailBack = find.byKey(const Key('auth-email-back-button'));
        await tester.ensureVisible(emailBack);
        await tester.pumpAndSettle();
        await tester.tap(emailBack);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('auth-google-button')), findsOneWidget);
        expect(auth.requestCount, 0);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets(
    'direct email waits for restoration recovery without starting auth',
    (tester) async {
      final auth = FakeAuthGateway()
        ..snapshotError = StateError('synthetic restore failure');
      addTearDown(auth.close);
      final app = await _pumpApp(tester, auth, FakeProfileAnchorGateway());
      final router = app.read(appRouterProvider);
      router.go('/auth/email?returnTo=%2Fprofile%2Fedit');
      await tester.pumpAndSettle();
      expect(
        app.read(authSessionProvider).phase,
        AuthSessionPhase.restorationFailed,
      );
      expect(find.byKey(const Key('auth-email-field')), findsNothing);
      auth.snapshotError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/auth/email');
      expect(router.state.uri.queryParameters['returnTo'], '/profile/edit');
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(auth.requestCount, 0);
    },
  );

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
      expect(find.text('or sign in with your email + OTP'), findsOneWidget);
      expect(find.byKey(const Key('auth-email-field')), findsNothing);
      expect(find.byKey(const Key('auth-request-button')), findsNothing);
      final button = find.byKey(const Key('auth-google-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(provider.lastProvider, AuthProvider.google);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('auth-email-method-button')),
            )
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
    expect(router.routeInformationProvider.value.uri.path, '/auth/email');
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
