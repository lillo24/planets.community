import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import '../../../support/fake_auth.dart';

void main() {
  test(
    'failed stream setup can retry restoration without faking sign-out',
    () async {
      final auth = FakeAuthGateway()
        ..streamError = StateError('stream unavailable');
      final container = _container(auth, FakeProfileAnchorGateway());
      addTearDown(container.dispose);
      addTearDown(auth.close);
      await container.read(authSessionProvider.notifier).start();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.restorationFailed,
      );
      auth.streamError = null;
      await container.read(authSessionProvider.notifier).retryRestoration();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.signedOut,
      );
    },
  );
  test(
    'warm token refresh preserves established readiness for the same actor',
    () async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final profile = FakeProfileAnchorGateway()
        ..readiness = ProfileAnchorReadiness.complete;
      final container = _container(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      await container.read(authSessionProvider.notifier).start();
      final ready = container.read(authSessionProvider);
      auth.emit(
        const AuthSnapshot(
          identity: AuthIdentity(id: 'user-1'),
          isTokenRefresh: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(identical(container.read(authSessionProvider), ready), isTrue);
      expect(profile.existsCount, 1);
      auth.emit(
        const AuthSnapshot(
          identity: AuthIdentity(id: 'user-2'),
          isTokenRefresh: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authSessionProvider).identity?.id, 'user-2');
      expect(profile.existsCount, 2);
    },
  );
  test(
    'snapshot restore failure stays distinct from signed out and retries',
    () async {
      final auth = FakeAuthGateway()
        ..snapshotError = StateError('restore unavailable');
      final profile = FakeProfileAnchorGateway();
      final container = _container(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);
      await container.read(authSessionProvider.notifier).start();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.restorationFailed,
      );
      expect(profile.existsCount, 0);
      auth.snapshotError = null;
      await container.read(authSessionProvider.notifier).retryRestoration();
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.signedOut,
      );
    },
  );
  test('restores a signed-out session', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway();
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.restoring,
    );
    await container.read(authSessionProvider.notifier).start();

    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.signedOut,
    );
    expect(profile.existsCount, 0);
  });

  test('restores a valid session and checks its profile anchor', () async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'restored-user')),
    );
    final profile = FakeProfileAnchorGateway()..exists = true;
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    await container.read(authSessionProvider.notifier).start();

    final state = container.read(authSessionProvider);
    expect(state.phase, AuthSessionPhase.ready);
    expect(state.identity?.id, 'restored-user');
    expect(profile.lastUserId, 'restored-user');
  });

  test(
    'keeps authentication and exposes retry when profile check fails',
    () async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final profile = FakeProfileAnchorGateway()
        ..existsError = StateError('database detail');
      final container = _container(auth, profile);
      addTearDown(container.dispose);
      addTearDown(auth.close);

      await container.read(authSessionProvider.notifier).start();

      final state = container.read(authSessionProvider);
      expect(state.phase, AuthSessionPhase.profileSetupRequired);
      expect(state.identity?.id, 'user-1');
      expect(state.isAuthenticated, isTrue);
      expect(state.hasProfileAnchor, isFalse);
    },
  );

  test('recognizes an existing skeletal profile as setup-required', () async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final profile = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);

    await container.read(authSessionProvider.notifier).start();

    final state = container.read(authSessionProvider);
    expect(state.phase, AuthSessionPhase.profileSetupRequired);
    expect(state.hasProfileAnchor, isTrue);
  });

  test('follows auth state transitions and treats an expired session as signed out', () async {
    final auth = FakeAuthGateway();
    final profile = FakeProfileAnchorGateway()..exists = true;
    final container = _container(auth, profile);
    addTearDown(container.dispose);
    addTearDown(auth.close);
    await container.read(authSessionProvider.notifier).start();

    auth.emit(
      const AuthSnapshot(
        identity: AuthIdentity(id: 'expired-user'),
        isExpired: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.signedOut,
    );

    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'active-user')));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
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
    ],
  );
}
