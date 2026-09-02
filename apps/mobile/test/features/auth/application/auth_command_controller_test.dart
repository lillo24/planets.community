import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';

void main() {
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
  FakeProfileAnchorGateway profile,
) {
  return ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(profile),
      authClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 2)),
    ],
  );
}
