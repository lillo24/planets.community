import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import '../../../support/eventful_auth.dart';

void main() {
  // Bound: five event positions x three canonical readiness states, followed
  // by focused failure/invalidation cases. No repeated-until-green campaign.
  test('same-account Auth event cannot manufacture a setup failure', () async {
    final release = Completer<void>();
    final auth = EventfulAuthGateway()..statusRelease = release.future;
    final profile = ControlledProfileAnchor()
      ..readiness = ProfileAnchorReadiness.complete;
    final app = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(app.dispose);
    addTearDown(auth.close);
    await app.read(authSessionProvider.notifier).start();
    final commands = app.read(authCommandProvider.notifier);
    await commands.requestCode(email: 'synthetic@example.test', returnTo: '/');
    final verification = commands.verifyCode('123456');
    await auth.statusEntered.future;
    auth.publish(auth.currentSnapshot);
    await auth.replacementEntered.future;
    release.complete();

    expect(await verification, isTrue);
    expect(app.read(authSessionProvider).identity?.id, 'user-1');
    expect(app.read(authSessionProvider).phase, AuthSessionPhase.ready);
    expect(app.read(authCommandProvider).failure, isNull);
    expect(app.read(pendingEmailOtpProvider), isNull);
    expect(profile.ensureCount, greaterThan(0));
  });

  for (final readiness in ProfileAnchorReadiness.values) {
    for (final position in _EventPosition.values) {
      test('$readiness / $position converges without losing anchor work', () async {
        final release = Completer<void>();
        final fixture = _Fixture(readiness);
        final auth = fixture.auth;
        final profile = fixture.profile;
        switch (position) {
          case _EventPosition.before:
            auth.eventBeforeReturn = true;
            auth.verifyRelease = release.future;
          case _EventPosition.account:
            auth.statusRelease = release.future;
          case _EventPosition.ensure:
            profile.ensureRelease = release.future;
          case _EventPosition.readiness:
            profile.readinessRelease = release.future;
          case _EventPosition.after:
            break;
        }
        await fixture.start();
        final verification = fixture.commands.verifyCode('123456');
        if (position == _EventPosition.before) {
          await profile.readinessEntered.future;
          release.complete();
        } else if (position == _EventPosition.after) {
          expect(await verification, isTrue);
          auth.publish(auth.currentSnapshot);
          await auth.replacementEntered.future;
        } else {
          await switch (position) {
            _EventPosition.account => auth.statusEntered.future,
            _EventPosition.ensure => profile.ensureEntered.future,
            _EventPosition.readiness => profile.readinessEntered.future,
            _ => throw StateError('Unexpected schedule'),
          };
          auth.publish(auth.currentSnapshot);
          await auth.replacementEntered.future;
          release.complete();
        }
        expect(await verification, isTrue);
        // Drain the scheduled stream/microtask work, not a coordination delay.
        await Future<void>.delayed(Duration.zero);
        expect(fixture.session.identity?.id, 'user-1');
        expect(
          fixture.session.phase,
          readiness == ProfileAnchorReadiness.complete
              ? AuthSessionPhase.ready
              : AuthSessionPhase.profileSetupRequired,
        );
        if (readiness != ProfileAnchorReadiness.complete) {
          expect(fixture.session.hasProfileAnchor, isTrue);
        }
        expect(profile.ensureCount, greaterThan(0));
        expect(fixture.app.read(authCommandProvider).failure, isNull);
        expect(fixture.app.read(pendingEmailOtpProvider), isNull);
      });
    }
  }

  for (final failure in ['status', 'ensure', 'readiness']) {
    test(
      'current $failure failure remains explicit after an Auth overlap',
      () async {
        final fixture = _Fixture(ProfileAnchorReadiness.complete);
        final release = Completer<void>();
        fixture.auth.statusRelease = release.future;
        await fixture.start();
        final verification = fixture.commands.verifyCode('123456');
        await fixture.auth.statusEntered.future;
        switch (failure) {
          case 'status':
            fixture.auth.suspensionError = StateError('synthetic');
          case 'ensure':
            fixture.profile.ensureError = StateError('synthetic');
          case 'readiness':
            fixture.profile.existsError = StateError('synthetic');
        }
        fixture.auth.publish(fixture.auth.currentSnapshot);
        await fixture.auth.replacementEntered.future;
        release.complete();
        expect(await verification, isFalse);
        expect(fixture.session.identity?.id, 'user-1');
        expect(
          fixture.session.phase,
          failure == 'status'
              ? AuthSessionPhase.accountCheckFailed
              : AuthSessionPhase.profileSetupRequired,
        );
        expect(
          fixture.app.read(authCommandProvider).failure,
          AuthFailureKind.profileSetup,
        );
        expect(fixture.app.read(pendingEmailOtpProvider)?.returnTo, '/profile');
      },
    );
  }

  test(
    'later suspension wins; pending anchor work cannot grant access',
    () async {
      final fixture = _Fixture(ProfileAnchorReadiness.missing);
      final release = Completer<void>();
      fixture.auth.statusRelease = release.future;
      await fixture.start();
      final verification = fixture.commands.verifyCode('123456');
      await fixture.auth.statusEntered.future;
      fixture.auth.suspension = AccountSuspensionStatus.active(
        consequenceId: 'synthetic',
        appliedAt: DateTime.utc(2026),
        userReason: 'Synthetic',
      );
      fixture.auth.publish(fixture.auth.currentSnapshot);
      await fixture.auth.replacementEntered.future;
      release.complete();
      expect(await verification, isTrue);
      expect(fixture.session.phase, AuthSessionPhase.suspended);
      expect(fixture.profile.ensureCount, 0);
      expect(fixture.app.read(authCommandProvider).failure, isNull);
    },
  );

  for (final action in ['cancel', 'signOut', 'switch']) {
    test('$action while SDK verification returns cannot revive A', () async {
      final fixture = _Fixture(ProfileAnchorReadiness.complete);
      final release = Completer<void>();
      fixture.auth.eventBeforeReturn = true;
      fixture.auth.verifyRelease = release.future;
      await fixture.start();
      final verification = fixture.commands.verifyCode('123456');
      await fixture.auth.verified.future;
      await Future<void>.delayed(Duration.zero);
      if (action == 'cancel') {
        fixture.commands.cancelFlow();
        await fixture.commands.requestCode(
          email: 'new@example.test',
          returnTo: '/settings',
        );
      } else {
        fixture.auth.publish(
          action == 'signOut'
              ? const AuthSnapshot()
              : const AuthSnapshot(identity: AuthIdentity(id: 'user-2')),
        );
        await Future<void>.delayed(Duration.zero);
      }
      release.complete();
      expect(await verification, isFalse);
      expect(fixture.app.read(authCommandProvider).failure, isNull);
      expect(fixture.profile.ensureCount, 0);
      if (action == 'cancel') {
        expect(
          fixture.app.read(pendingEmailOtpProvider)?.returnTo,
          '/settings',
        );
      } else {
        expect(
          fixture.session.identity?.id,
          action == 'switch' ? 'user-2' : null,
        );
        expect(
          fixture.session.phase,
          action == 'switch'
              ? AuthSessionPhase.ready
              : AuthSessionPhase.signedOut,
        );
        expect(fixture.app.read(pendingEmailOtpProvider), isNull);
      }
    });
    test('$action invalidates late command success and failure', () async {
      final fixture = _Fixture(ProfileAnchorReadiness.complete);
      final release = Completer<void>();
      fixture.auth.statusRelease = release.future;
      await fixture.start();
      final verification = fixture.commands.verifyCode('123456');
      await fixture.auth.statusEntered.future;
      if (action == 'cancel') {
        fixture.commands.cancelFlow();
        await fixture.commands.requestCode(
          email: 'new@example.test',
          returnTo: '/settings',
        );
      } else {
        fixture.auth.publish(
          action == 'signOut'
              ? const AuthSnapshot()
              : const AuthSnapshot(identity: AuthIdentity(id: 'user-2')),
        );
        await Future<void>.delayed(Duration.zero);
      }
      fixture.auth.suspensionError = StateError('obsolete synthetic failure');
      release.complete();
      expect(await verification, isFalse);
      expect(fixture.app.read(authCommandProvider).failure, isNull);
      if (action == 'cancel') {
        expect(
          fixture.app.read(pendingEmailOtpProvider)?.returnTo,
          '/settings',
        );
        expect(
          fixture.app.read(authCommandProvider).phase,
          AuthCommandPhase.codeSent,
        );
      } else {
        expect(
          fixture.session.identity?.id,
          action == 'switch' ? 'user-2' : null,
        );
        expect(
          fixture.session.phase,
          action == 'switch'
              ? AuthSessionPhase.ready
              : AuthSessionPhase.signedOut,
        );
        expect(fixture.app.read(pendingEmailOtpProvider), isNull);
      }
    });
  }

  for (final boundary in ['verification', 'bootstrap']) {
    test('A -> signed out -> A rejects the old $boundary completion', () async {
      final fixture = _Fixture(ProfileAnchorReadiness.complete);
      final release = Completer<void>();
      if (boundary == 'verification') {
        fixture.auth.eventBeforeReturn = true;
        fixture.auth.verifyRelease = release.future;
      } else {
        fixture.auth.statusRelease = release.future;
      }
      await fixture.start();
      final verification = fixture.commands.verifyCode('123456');
      await (boundary == 'verification'
          ? fixture.auth.verified.future
          : fixture.auth.statusEntered.future);
      await Future<void>.delayed(Duration.zero);
      fixture.auth.publish(const AuthSnapshot());
      await Future<void>.delayed(Duration.zero);
      fixture.auth.publish(
        const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      await Future<void>.delayed(Duration.zero);
      release.complete();
      expect(await verification, isFalse);
      expect(fixture.session.identity?.id, 'user-1');
      expect(fixture.session.phase, AuthSessionPhase.ready);
      expect(fixture.app.read(authCommandProvider).failure, isNull);
      expect(fixture.app.read(pendingEmailOtpProvider), isNull);
    });
  }

  for (final event in ['signOut', 'switch', 'sameAccountReturn']) {
    test('$event rejects a late SDK verification error', () async {
      final fixture = _Fixture(ProfileAnchorReadiness.complete);
      final release = Completer<void>();
      fixture.auth.eventBeforeReturn = true;
      fixture.auth.verifyRelease = release.future;
      fixture.auth.completionError = StateError('obsolete synthetic SDK error');
      await fixture.start();
      final verification = fixture.commands.verifyCode('123456');
      await fixture.auth.verified.future;
      await Future<void>.delayed(Duration.zero);
      fixture.auth.publish(const AuthSnapshot());
      await Future<void>.delayed(Duration.zero);
      if (event != 'signOut') {
        fixture.auth.publish(
          AuthSnapshot(
            identity: AuthIdentity(id: event == 'switch' ? 'user-2' : 'user-1'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
      release.complete();
      expect(await verification, isFalse);
      expect(fixture.app.read(authCommandProvider).failure, isNull);
      expect(fixture.app.read(pendingEmailOtpProvider), isNull);
      expect(
        fixture.session.identity?.id,
        event == 'switch'
            ? 'user-2'
            : event == 'sameAccountReturn'
            ? 'user-1'
            : null,
      );
    });
  }
}

enum _EventPosition { before, account, ensure, readiness, after }

class _Fixture {
  _Fixture(ProfileAnchorReadiness readiness) {
    profile.readiness = readiness;
    app = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(app.dispose);
    addTearDown(auth.close);
  }

  final auth = EventfulAuthGateway();
  final profile = ControlledProfileAnchor();
  late final ProviderContainer app;
  AuthCommandController get commands => app.read(authCommandProvider.notifier);
  AuthSessionState get session => app.read(authSessionProvider);

  Future<void> start() async {
    await app.read(authSessionProvider.notifier).start();
    await commands.requestCode(
      email: 'synthetic@example.test',
      returnTo: '/profile',
    );
  }
}
