import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/own_request_restriction_controller.dart';
import 'package:planets_mobile/features/moderation/data/own_interaction_restriction_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_own_interaction_restriction.dart';

void main() {
  const a = AuthIdentity(id: 'a');
  const b = AuthIdentity(id: 'b');
  final provider = ownRequestRestrictionProvider('project:synthetic');
  late FakeOwnInteractionRestrictionGateway gateway;
  late FakeAuthGateway auth;
  late ProviderContainer container;
  late OwnRequestRestrictionController controller;

  setUp(() {
    gateway = FakeOwnInteractionRestrictionGateway();
    auth = FakeAuthGateway(snapshot: const AuthSnapshot(identity: a));
    container = ProviderContainer(
      overrides: [
        ownInteractionRestrictionGatewayProvider.overrideWithValue(gateway),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
      ],
    );
    container.read(authSessionProvider.notifier).markProfileReady(a);
    container.listen(provider, (_, _) {});
    controller = container.read(provider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test(
    'each denial checks fresh own state, never history or cached eligibility',
    () async {
      gateway.active = true;
      await controller.checkAfterDenial(a.id);
      expect(container.read(provider), OwnRequestRestrictionState.active);
      gateway.active = false;
      await controller.checkAfterDenial(a.id);
      expect(container.read(provider), OwnRequestRestrictionState.unconfirmed);
      gateway.active = true;
      await controller.checkAfterDenial(a.id);
      expect(gateway.identities, ['a', 'a', 'a']);
      controller.clear();
      expect(container.read(provider), OwnRequestRestrictionState.unconfirmed);
    },
  );

  for (final error in [
    const FormatException('Malformed'),
    TimeoutException('Unavailable'),
    const PostgrestException(message: 'private reason', code: '42501'),
  ]) {
    test(
      'optional ${error.runtimeType} failure does not confirm or log status',
      () async {
        gateway.active = true;
        await controller.checkAfterDenial(a.id);
        gateway.error = error;
        await controller.checkAfterDenial(a.id);
        expect(
          container.read(provider),
          OwnRequestRestrictionState.unconfirmed,
        );
      },
    );
  }

  test(
    'wrong ID, signed out and incomplete access do not read status',
    () async {
      await controller.checkAfterDenial(b.id);
      container.read(authSessionProvider.notifier).markSignedOut();
      await controller.checkAfterDenial(a.id);
      container
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(a, hasProfileAnchor: true);
      await controller.checkAfterDenial(a.id);
      expect(gateway.identities, isEmpty);
    },
  );

  for (final transition in [
    'switch',
    'same-ID return',
    'session refresh',
    'suspended',
  ]) {
    test('rejects late status after $transition', () async {
      final pending = Completer<bool>();
      gateway.pending = pending.future;
      final result = controller.checkAfterDenial(a.id);
      expect(container.read(provider), OwnRequestRestrictionState.checking);
      final session = container.read(authSessionProvider.notifier);
      if (transition == 'switch') {
        session.markProfileReady(b);
      } else if (transition == 'same-ID return') {
        session.markSignedOut();
        session.markProfileReady(a);
      } else if (transition == 'session refresh') {
        await session.refresh();
      } else {
        auth.suspension = AccountSuspensionStatus.active(
          consequenceId: 'synthetic',
          appliedAt: DateTime.utc(2026),
          userReason: 'Synthetic own reason',
        );
        await session.refresh();
      }
      pending.complete(true);
      await result;
      expect(container.read(provider), OwnRequestRestrictionState.unconfirmed);
    });
  }

  test('new attempt wins over older late result', () async {
    final old = Completer<bool>();
    gateway.pending = old.future;
    final oldCheck = controller.checkAfterDenial(a.id);
    final fresh = Completer<bool>();
    gateway.pending = fresh.future;
    final newCheck = controller.checkAfterDenial(a.id);
    fresh.complete(false);
    await newCheck;
    old.complete(true);
    await oldCheck;
    expect(container.read(provider), OwnRequestRestrictionState.unconfirmed);
    expect(gateway.identities, ['a', 'a']);
  });

  test('disposal rejects a pending private response', () async {
    final pending = Completer<bool>();
    gateway.pending = pending.future;
    final result = controller.checkAfterDenial(a.id);
    container.invalidate(provider);
    pending.complete(true);
    await result;
    expect(container.read(provider), OwnRequestRestrictionState.unconfirmed);
  });

  test(
    'PT403 uses existing Auth status refresh and never confirms restriction',
    () async {
      auth.suspension = AccountSuspensionStatus.active(
        consequenceId: 'synthetic',
        appliedAt: DateTime.utc(2026),
        userReason: 'Synthetic own reason',
      );
      gateway.error = const PostgrestException(
        message: 'private',
        code: 'PT403',
      );
      await controller.checkAfterDenial(a.id);
      expect(auth.suspensionCheckCount, 1);
      expect(
        container.read(authSessionProvider).phase,
        AuthSessionPhase.suspended,
      );
      expect(container.read(provider), OwnRequestRestrictionState.unconfirmed);
    },
  );
}
