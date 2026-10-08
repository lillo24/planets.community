import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/data/provider_auth_adapter.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/domain/provider_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';

void main() {
  for (final provider in <AuthProvider?>[null, ...AuthProvider.values]) {
    final mechanism = provider?.name ?? 'email OTP';
    group('$mechanism shared completion', () {
      for (final readiness in ProfileAnchorReadiness.values) {
        test('resolves ${readiness.name} profile readiness', () async {
          final auth = FakeAuthGateway();
          final adapter = FakeProviderAuthAdapter();
          final profile = FakeProfileAnchorGateway()
            ..readiness = readiness
            ..createsAnchor = false;
          final container = _container(auth, profile, providerAdapter: adapter);
          addTearDown(container.dispose);
          addTearDown(auth.close);

          expect(await _signIn(container, provider), isTrue);
          final session = container.read(authSessionProvider);
          expect(session.identity?.id, 'user-1');
          expect(session.isAuthenticated, isTrue);
          expect(
            session.phase,
            readiness == ProfileAnchorReadiness.complete
                ? AuthSessionPhase.ready
                : AuthSessionPhase.profileSetupRequired,
          );
          expect(
            session.hasProfileAnchor,
            readiness == ProfileAnchorReadiness.incomplete,
          );
          expect(profile.ensureCount, 1);
          expect(profile.existsCount, 1);
          expect(profile.lastUserId, 'user-1');
          expect(container.read(pendingEmailOtpProvider), isNull);
          expect(container.read(authCommandProvider).failure, isNull);
          expect(auth.verifyCount, provider == null ? 1 : 0);
          expect(adapter.signInCount, provider == null ? 0 : 1);
          if (provider != null) expect(adapter.lastProvider, provider);
        });
      }

      for (final step in ['anchor creation', 'readiness']) {
        test('$step failure retains a safe retryable session', () async {
          final auth = FakeAuthGateway();
          final profile = FakeProfileAnchorGateway();
          if (step == 'anchor creation') {
            profile.ensureError = StateError('private database detail');
          } else {
            profile.existsError = StateError('private database detail');
          }
          final container = _container(
            auth,
            profile,
            providerAdapter: FakeProviderAuthAdapter(),
          );
          addTearDown(container.dispose);
          addTearDown(auth.close);

          expect(await _signIn(container, provider), isFalse);
          expect(
            container.read(authCommandProvider).failure,
            AuthFailureKind.profileSetup,
          );
          final session = container.read(authSessionProvider);
          expect(session.identity?.id, 'user-1');
          expect(session.phase, AuthSessionPhase.profileSetupRequired);
          expect(session.hasProfileAnchor, isFalse);
          profile.ensureError = null;
          profile.existsError = null;
          expect(
            await container
                .read(authCommandProvider.notifier)
                .retryProfileSetup(),
            isTrue,
          );
          expect(container.read(authSessionProvider).hasProfileAnchor, isTrue);
        });
      }

      for (final step in ['authentication', 'anchor creation', 'readiness']) {
        test('cancelling during $step ignores late completion', () async {
          final completion = Completer<void>();
          final auth = FakeAuthGateway();
          final adapter = FakeProviderAuthAdapter();
          final profile = FakeProfileAnchorGateway();
          switch (step) {
            case 'authentication':
              auth.verifyDelay = completion.future;
              adapter.signInDelay = completion.future;
            case 'anchor creation':
              profile.ensureDelay = completion.future;
            case 'readiness':
              profile.readinessDelay = completion.future;
          }
          final container = _container(auth, profile, providerAdapter: adapter);
          addTearDown(container.dispose);
          addTearDown(auth.close);
          final controller = container.read(authCommandProvider.notifier);

          final oldSignIn = _signIn(container, provider);
          await Future<void>.delayed(Duration.zero);
          expect(container.read(authCommandProvider).isBusy, isTrue);
          controller.cancelFlow();
          container
              .read(authSessionProvider.notifier)
              .markProfileReady(const AuthIdentity(id: 'new-user'));
          expect(
            await controller.requestCode(email: 'new@example.com'),
            isTrue,
          );

          completion.complete();
          expect(await oldSignIn, isFalse);
          expect(container.read(authSessionProvider).identity?.id, 'new-user');
          expect(
            container.read(authSessionProvider).phase,
            AuthSessionPhase.ready,
          );
          expect(
            container.read(pendingEmailOtpProvider)?.email,
            'new@example.com',
          );
          expect(
            container.read(authCommandProvider).phase,
            AuthCommandPhase.codeSent,
          );
          expect(container.read(authCommandProvider).failure, isNull);
          if (step == 'authentication') expect(profile.ensureCount, 0);
          if (step == 'anchor creation') expect(profile.existsCount, 0);
        });
      }
    });
  }

  test(
    'both providers are unavailable by default without backend startup',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = container.read(providerAuthAdapterProvider);
      for (final provider in AuthProvider.values) {
        expect(adapter.isAvailable(provider), isFalse);
        expect(await adapter.signIn(provider), isA<ProviderAuthFailure>());
        expect(
          await container
              .read(authCommandProvider.notifier)
              .signInWithProvider(provider),
          isFalse,
        );
        expect(
          container.read(authCommandProvider).failure,
          AuthFailureKind.serviceUnavailable,
        );
        expect(container.read(authCommandProvider).isBusy, isFalse);
      }
    },
  );

  test('an unavailable injected provider is never called', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    final adapter = FakeProviderAuthAdapter()
      ..availableProviders = {AuthProvider.apple};
    final container = _container(auth, profile, providerAdapter: adapter);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    expect(
      await container
          .read(authCommandProvider.notifier)
          .signInWithProvider(AuthProvider.google),
      isFalse,
    );
    expect(adapter.signInCount, 0);
    expect(profile.ensureCount, 0);
    expect(
      container.read(authCommandProvider).failure,
      AuthFailureKind.serviceUnavailable,
    );
  });

  test(
    'provider dismissal preserves OTP pending state without an error',
    () async {
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway();
      final adapter = FakeProviderAuthAdapter()
        ..result = const ProviderAuthCancelled();
      final container = _container(auth, profile, providerAdapter: adapter);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final controller = container.read(authCommandProvider.notifier);
      await controller.requestCode(
        email: 'person@example.com',
        returnTo: '/profile',
      );
      final previousState = container.read(authCommandProvider);
      final previousSession = container.read(authSessionProvider);

      expect(await controller.signInWithProvider(AuthProvider.google), isFalse);
      expect(container.read(authCommandProvider).failure, isNull);
      expect(
        container.read(authCommandProvider).phase,
        AuthCommandPhase.codeSent,
      );
      expect(
        container.read(authCommandProvider).resendAvailableAt,
        previousState.resendAvailableAt,
      );
      expect(container.read(authSessionProvider), same(previousSession));
      expect(container.read(pendingEmailOtpProvider)?.returnTo, '/profile');
      expect(profile.ensureCount, 0);
      expect(await controller.verifyCode('123456'), isTrue);
    },
  );

  for (final throwsError in [false, true]) {
    test(
      'provider ${throwsError ? 'exception' : 'failure'} is safe and retryable',
      () async {
        final auth = FakeAuthGateway();
        final profile = FakeProfileAnchorGateway();
        final adapter = FakeProviderAuthAdapter();
        if (throwsError) {
          adapter.signInError = StateError('private provider diagnostic');
        } else {
          adapter.result = const ProviderAuthFailure(
            AuthFailureKind.networkUnavailable,
          );
        }
        final container = _container(auth, profile, providerAdapter: adapter);
        addTearDown(container.dispose);
        addTearDown(auth.close);
        final controller = container.read(authCommandProvider.notifier);
        expect(
          await controller.signInWithProvider(AuthProvider.apple),
          isFalse,
        );
        expect(
          container.read(authCommandProvider).failure,
          throwsError
              ? AuthFailureKind.unexpected
              : AuthFailureKind.networkUnavailable,
        );
        expect(container.read(authSessionProvider).isAuthenticated, isFalse);
        expect(profile.ensureCount, 0);

        adapter.signInError = null;
        adapter.result = const ProviderAuthSuccess(AuthIdentity(id: 'user-1'));
        expect(await controller.signInWithProvider(AuthProvider.apple), isTrue);
      },
    );
  }

  test('provider command blocks duplicate provider and OTP requests', () async {
    final completion = Completer<void>();
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    final adapter = FakeProviderAuthAdapter()..signInDelay = completion.future;
    final container = _container(auth, profile, providerAdapter: adapter);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    final controller = container.read(authCommandProvider.notifier);
    final signIn = controller.signInWithProvider(AuthProvider.google);
    expect(
      container.read(authCommandProvider).phase,
      AuthCommandPhase.signingInWithProvider,
    );
    expect(await controller.signInWithProvider(AuthProvider.apple), isFalse);
    expect(await controller.requestCode(email: 'person@example.com'), isFalse);
    await controller.signOut();
    expect(auth.signOutCount, 0);
    expect(adapter.signInCount, 1);
    completion.complete();
    expect(await signIn, isTrue);
    await controller.signOut();
    expect(auth.signOutCount, 1);
    expect(adapter.signInCount, 1);
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.signedOut,
    );
  });

  test(
    'an abandoned profile retry cannot restore a signed-out session',
    () async {
      final completion = Completer<void>();
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway()
        ..ensureDelay = completion.future;
      final container = _container(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(
            const AuthIdentity(id: 'old-user'),
            hasProfileAnchor: false,
          );
      final controller = container.read(authCommandProvider.notifier);
      final retry = controller.retryProfileSetup();
      controller.cancelFlow();
      await controller.signOut();
      completion.complete();
      expect(await retry, isFalse);
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.signedOut,
      );
      expect(container.read(authCommandProvider).phase, AuthCommandPhase.idle);
      expect(profile.existsCount, 0);
    },
  );

  test('a late provider failure cannot replace a newer OTP request', () async {
    final completion = Completer<void>();
    final auth = FakeAuthGateway();
    final adapter = FakeProviderAuthAdapter()
      ..signInDelay = completion.future
      ..result = const ProviderAuthFailure(AuthFailureKind.networkUnavailable);
    final container = _container(
      auth,
      FakeProfileAnchorGateway(),
      providerAdapter: adapter,
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);
    final controller = container.read(authCommandProvider.notifier);
    final signIn = controller.signInWithProvider(AuthProvider.google);
    controller.cancelFlow();
    await controller.requestCode(email: 'new@example.com');
    completion.complete();
    expect(await signIn, isFalse);
    expect(container.read(authCommandProvider).failure, isNull);
    expect(container.read(pendingEmailOtpProvider)?.email, 'new@example.com');
  });

  test('disposing the container ignores a late provider success', () async {
    final completion = Completer<void>();
    final auth = FakeAuthGateway();
    final adapter = FakeProviderAuthAdapter()..signInDelay = completion.future;
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile, providerAdapter: adapter);
    addTearDown(auth.close);
    final signIn = container
        .read(authCommandProvider.notifier)
        .signInWithProvider(AuthProvider.google);
    container.dispose();
    completion.complete();
    expect(await signIn, isFalse);
    expect(profile.ensureCount, 0);
  });

  for (final fails in [false, true]) {
    test(
      'late sign-out ${fails ? 'failure' : 'success'} preserves a newer flow',
      () async {
        final completion = Completer<void>();
        final auth = FakeAuthGateway()..signOutDelay = completion.future;
        if (fails) auth.signOutError = StateError('private backend detail');
        final container = _container(auth, FakeProfileAnchorGateway());
        addTearDown(container.dispose);
        addTearDown(auth.close);
        final controller = container.read(authCommandProvider.notifier);
        final signOut = controller.signOut();
        controller.cancelFlow();
        await controller.requestCode(email: 'new@example.com');
        completion.complete();
        await signOut;
        expect(
          container.read(authCommandProvider).phase,
          AuthCommandPhase.codeSent,
        );
        expect(container.read(authCommandProvider).failure, isNull);
        expect(
          container.read(pendingEmailOtpProvider)?.email,
          'new@example.com',
        );
        expect(container.read(authCommandProvider).didSignOut, isFalse);
      },
    );
  }

  test('validates email before requesting a code', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    final sent = await container
        .read(authCommandProvider.notifier)
        .requestCode(email: 'not-an-email');

    expect(sent, isFalse);
    expect(auth.requestCount, 0);
    expect(
      container.read(authCommandProvider).failure,
      AuthFailureKind.invalidEmail,
    );
  });

  test('trims email without changing casing', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    final sent = await container
        .read(authCommandProvider.notifier)
        .requestCode(
          email: '  Person@Example.COM ',
          returnTo: 'https://attacker.example/path',
        );

    expect(sent, isTrue);
    expect(auth.requestedEmail, 'Person@Example.COM');
    expect(
      container.read(pendingEmailOtpProvider)?.email,
      'Person@Example.COM',
    );
    expect(container.read(pendingEmailOtpProvider)?.returnTo, '/');
  });

  test('prevents duplicate code requests while one is active', () async {
    final completer = Completer<void>();
    final auth = FakeAuthGateway()..requestDelay = completer.future;
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    final first = container
        .read(authCommandProvider.notifier)
        .requestCode(email: 'person@example.com');
    await Future<void>.delayed(Duration.zero);
    final second = await container
        .read(authCommandProvider.notifier)
        .requestCode(email: 'person@example.com');
    completer.complete();

    expect(second, isFalse);
    expect(await first, isTrue);
    expect(auth.requestCount, 1);
  });

  test('times out an OTP request without installing pending state', () async {
    final completer = Completer<void>();
    final auth = FakeAuthGateway()..requestDelay = completer.future;
    final profile = FakeProfileAnchorGateway();
    final container = _container(
      auth,
      profile,
      requestTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    final sent = await container
        .read(authCommandProvider.notifier)
        .requestCode(email: 'person@example.com');

    expect(sent, isFalse);
    expect(container.read(authCommandProvider).isBusy, isFalse);
    expect(
      container.read(authCommandProvider).failure,
      AuthFailureKind.requestTimedOut,
    );
    expect(container.read(pendingEmailOtpProvider), isNull);
    completer.complete();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingEmailOtpProvider), isNull);
  });

  test(
    'an abandoned OTP completion cannot overwrite a newer request',
    () async {
      final firstCompletion = Completer<void>();
      final auth = FakeAuthGateway()..requestDelay = firstCompletion.future;
      final profile = FakeProfileAnchorGateway();
      final container = _container(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      final controller = container.read(authCommandProvider.notifier);

      final first = controller.requestCode(email: 'first@example.com');
      await Future<void>.delayed(Duration.zero);
      controller.cancelFlow();
      auth.requestDelay = null;
      expect(await controller.requestCode(email: 'second@example.com'), isTrue);

      firstCompletion.complete();
      expect(await first, isFalse);
      expect(
        container.read(pendingEmailOtpProvider)?.email,
        'second@example.com',
      );
    },
  );

  test(
    'verifies the code and recognizes a new skeletal profile as incomplete',
    () async {
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway();
      final container = _container(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      await container
          .read(authCommandProvider.notifier)
          .requestCode(email: 'person@example.com', returnTo: '/proposals');

      final verified = await container
          .read(authCommandProvider.notifier)
          .verifyCode('123456');

      expect(verified, isTrue);
      expect(auth.verifiedEmail, 'person@example.com');
      expect(auth.verifiedToken, '123456');
      expect(profile.ensureCount, 1);
      expect(profile.lastUserId, 'user-1');
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.profileSetupRequired,
      );
      expect(container.read(authSessionProvider).hasProfileAnchor, isTrue);
      expect(container.read(pendingEmailOtpProvider), isNull);
    },
  );

  test('keeps the valid session and supports profile setup retry', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway()
      ..ensureError = StateError('database detail');
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    await container
        .read(authCommandProvider.notifier)
        .requestCode(email: 'person@example.com');

    expect(
      await container.read(authCommandProvider.notifier).verifyCode('123456'),
      isFalse,
    );
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.profileSetupRequired,
    );
    expect(container.read(authSessionProvider).isAuthenticated, isTrue);

    profile.ensureError = null;
    expect(
      await container.read(authCommandProvider.notifier).retryProfileSetup(),
      isTrue,
    );
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.profileSetupRequired,
    );
    expect(container.read(authSessionProvider).hasProfileAnchor, isTrue);
    expect(auth.verifyCount, 1);
    expect(profile.ensureCount, 2);
  });

  test('maps backend details to a safe failure kind', () async {
    final auth = FakeAuthGateway()
      ..verifyError = const AuthException(
        'raw backend detail that must not reach the UI',
        code: 'otp_expired',
      );
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    await container
        .read(authCommandProvider.notifier)
        .requestCode(email: 'person@example.com');

    await container.read(authCommandProvider.notifier).verifyCode('123456');

    expect(
      container.read(authCommandProvider).failure,
      AuthFailureKind.expiredCode,
    );
  });

  test('maps an invalid backend code and signs out explicitly', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    final controller = container.read(authCommandProvider.notifier);
    await controller.requestCode(email: 'person@example.com');
    auth.verifyError = const AuthException(
      'raw invalid token detail',
      code: 'invalid_otp',
    );

    await controller.verifyCode('123456');
    expect(
      container.read(authCommandProvider).failure,
      AuthFailureKind.invalidCode,
    );

    auth.verifyError = null;
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
    await controller.signOut();
    expect(auth.signOutCount, 1);
    expect(container.read(pendingEmailOtpProvider), isNull);
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.signedOut,
    );
  });
}

ProviderContainer _container(
  FakeAuthGateway auth,
  FakeProfileAnchorGateway profile, {
  Duration? requestTimeout,
  ProviderAuthAdapter? providerAdapter,
}) {
  return ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(profile),
      if (providerAdapter != null)
        providerAuthAdapterProvider.overrideWithValue(providerAdapter),
      authClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 2)),
      if (requestTimeout != null)
        authOtpRequestTimeoutProvider.overrideWithValue(requestTimeout),
    ],
  );
}

Future<bool> _signIn(
  ProviderContainer container,
  AuthProvider? provider,
) async {
  final controller = container.read(authCommandProvider.notifier);
  if (provider != null) return controller.signInWithProvider(provider);
  await controller.requestCode(email: 'person@example.com');
  return controller.verifyCode('123456');
}
