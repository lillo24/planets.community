import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/moderation/application/own_consequence_controller.dart';
import 'package:planets_mobile/features/moderation/data/own_consequence_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/own_consequence_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_own_consequences.dart';

void main() {
  const identity = AuthIdentity(id: '00000000-0000-4000-8000-000000000001');
  late FakeOwnConsequenceGateway gateway;
  late FakeAuthGateway authGateway;
  late ProviderContainer container;
  late OwnConsequenceController controller;

  setUp(() {
    gateway = FakeOwnConsequenceGateway();
    authGateway = FakeAuthGateway();
    container = ProviderContainer(
      overrides: [
        ownConsequenceGatewayProvider.overrideWithValue(gateway),
        authGatewayProvider.overrideWithValue(authGateway),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
      ],
    );
    container.read(authSessionProvider.notifier).markProfileReady(identity);
    container.listen(ownConsequenceProvider, (_, _) {});
    controller = container.read(ownConsequenceProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await authGateway.close();
  });

  test('derives identity from ready verified session; empty is distinct from failure', () async {
    await controller.load();
    expect(gateway.identities, [identity.id]);
    expect(container.read(ownConsequenceProvider).phase, OwnHistoryPhase.ready);
    expect(container.read(ownConsequenceProvider).items, isEmpty);
    expect(container.read(ownConsequenceProvider).failure, isNull);
    gateway.error = const FormatException('Malformed projection.');
    await controller.load();
    expect(
      container.read(ownConsequenceProvider).phase,
      OwnHistoryPhase.failure,
    );
    expect(
      container.read(ownConsequenceProvider).failure,
      OwnHistoryFailure.malformed,
    );
  });

  test(
    'signed-out and profile-setup sessions never request private history',
    () async {
      container.read(authSessionProvider.notifier).markSignedOut();
      await controller.load();
      container
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(identity, hasProfileAnchor: true);
      await controller.load();
      expect(gateway.identities, isEmpty);
    },
  );

  test('pagination retains loaded rows, exact cursor, page error and explicit retry', () async {
    gateway.page = OwnConsequencePage([
      for (var id = 21; id > 1; id--) ownConsequence(id),
    ], hasMore: true);
    await controller.load();
    gateway.error = StateError('Synthetic transport failure');
    await controller.loadMore();
    var state = container.read(ownConsequenceProvider);
    expect(state.items, hasLength(20));
    expect(state.failure, OwnHistoryFailure.unavailable);
    expect(state.hasMore, isTrue);
    expect(gateway.cursors.last?.appliedAt, '2026-10-01T12:00:00.123456+00:00');
    expect(gateway.cursors.last?.consequenceId, ownConsequence(2).id);
    gateway.error = null;
    gateway.page = OwnConsequencePage([ownConsequence(1)], hasMore: false);
    await controller.loadMore();
    state = container.read(ownConsequenceProvider);
    expect(state.items, hasLength(21));
    expect(state.items.map((e) => e.id).toSet(), hasLength(21));
    expect(state.failure, isNull);
    expect(state.hasMore, isFalse);
    await controller.loadMore();
    expect(gateway.identities, hasLength(3));
  });

  test(
    'duplicate first-page and load-more actions create only one request each',
    () async {
      final first = Completer<OwnConsequencePage>();
      gateway.pending = first.future;
      final loading = controller.load();
      await controller.load();
      expect(gateway.identities, hasLength(1));
      first.complete(OwnConsequencePage([ownConsequence(2)], hasMore: true));
      await loading;
      final more = Completer<OwnConsequencePage>();
      gateway.pending = more.future;
      final paging = controller.loadMore();
      await controller.loadMore();
      expect(gateway.identities, hasLength(2));
      expect(container.read(ownConsequenceProvider).items, hasLength(1));
      more.complete(OwnConsequencePage([ownConsequence(1)], hasMore: false));
      await paging;
    },
  );

  test(
    'defensively avoids repeated IDs without merging episode types',
    () async {
      gateway.page = OwnConsequencePage([ownConsequence(2)], hasMore: true);
      await controller.load();
      gateway.page = OwnConsequencePage([
        ownConsequence(2),
        ownConsequence(1, type: 'content_hide'),
      ], hasMore: false);
      await controller.loadMore();
      expect(container.read(ownConsequenceProvider).items, hasLength(2));
      expect(
        container.read(ownConsequenceProvider).items.last.type,
        OwnConsequenceType.contentHide,
      );
    },
  );

  test(
    'refresh clears stale active rows and wins over a late older page',
    () async {
      gateway.page = OwnConsequencePage([ownConsequence(2)], hasMore: true);
      await controller.load();
      final older = Completer<OwnConsequencePage>();
      gateway.pending = older.future;
      final paging = controller.loadMore();
      final refreshed = Completer<OwnConsequencePage>();
      gateway.pending = refreshed.future;
      final refresh = controller.load();
      expect(container.read(ownConsequenceProvider).items, isEmpty);
      expect(
        container.read(ownConsequenceProvider).phase,
        OwnHistoryPhase.loading,
      );
      refreshed.complete(
        OwnConsequencePage([ownConsequence(2, active: false)], hasMore: false),
      );
      await refresh;
      older.complete(OwnConsequencePage([ownConsequence(1)], hasMore: false));
      await paging;
      expect(
        container.read(ownConsequenceProvider).items.single.isActive,
        isFalse,
      );
      expect(gateway.cursors.last, isNull);
    },
  );

  for (final transition in [
    'sign-out',
    'account-switch',
    'same-identity-session-revision',
  ]) {
    test('discards late private response after $transition', () async {
      final pending = Completer<OwnConsequencePage>();
      gateway.pending = pending.future;
      final loading = controller.load();
      final auth = container.read(authSessionProvider.notifier);
      if (transition == 'sign-out') {
        auth.markSignedOut();
      } else if (transition == 'account-switch') {
        auth.markProfileReady(
          const AuthIdentity(id: '00000000-0000-4000-8000-000000000099'),
        );
        auth.markProfileReady(
          identity,
        ); // Switching back must not revive A's old request.
      } else {
        auth.markProfileReady(identity);
      }
      pending.complete(OwnConsequencePage([ownConsequence(1)], hasMore: false));
      await loading;
      expect(container.read(ownConsequenceProvider).items, isEmpty);
      expect(
        container.read(ownConsequenceProvider).phase,
        OwnHistoryPhase.idle,
      );
    });
  }

  test(
    'late failure after sign-out does not replace the cleared state',
    () async {
      final pending = Completer<OwnConsequencePage>();
      gateway.pending = pending.future;
      final loading = controller.load();
      container.read(authSessionProvider.notifier).markSignedOut();
      pending.completeError(
        const FormatException('Synthetic malformed response'),
      );
      await loading;
      expect(container.read(ownConsequenceProvider).failure, isNull);
    },
  );

  test('disposal discards in-flight completion', () async {
    final pending = Completer<OwnConsequencePage>();
    gateway.pending = pending.future;
    final loading = controller.load();
    container.invalidate(ownConsequenceProvider);
    pending.complete(OwnConsequencePage([ownConsequence(1)], hasMore: false));
    await loading;
    expect(container.read(ownConsequenceProvider).items, isEmpty);
  });

  test('PT403 clears reasons and uses Auth status/guard instead of retrying history', () async {
    gateway.page = OwnConsequencePage([ownConsequence(1)], hasMore: true);
    await controller.load();
    authGateway.suspension = AccountSuspensionStatus.active(
      consequenceId: ownConsequence(9).id,
      appliedAt: DateTime.utc(2026, 10, 3),
      userReason: 'Synthetic suspension reason',
    );
    gateway.error = const PostgrestException(
      message: 'Account unavailable.',
      code: 'PT403',
    );
    await controller.loadMore();
    expect(authGateway.suspensionCheckCount, 1);
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.suspended,
    );
    expect(container.read(ownConsequenceProvider).items, isEmpty);
    await controller.load();
    expect(gateway.identities, hasLength(2));
  });

  test('status check failure stays fail-closed and clears history', () async {
    authGateway.suspensionError = StateError('Synthetic unavailable status');
    gateway.error = const PostgrestException(
      message: 'Account unavailable.',
      code: 'PT403',
    );
    await controller.load();
    expect(
      container.read(authSessionProvider).phase,
      AuthSessionPhase.accountCheckFailed,
    );
    expect(container.read(ownConsequenceProvider).items, isEmpty);
    expect(gateway.identities, hasLength(1));
  });

  test(
    'non-suspension permission denial clears retained private rows',
    () async {
      gateway.page = OwnConsequencePage([ownConsequence(1)], hasMore: true);
      await controller.load();
      gateway.error = const PostgrestException(
        message: 'Forbidden.',
        code: '42501',
      );
      await controller.loadMore();
      expect(container.read(ownConsequenceProvider).items, isEmpty);
      expect(
        container.read(ownConsequenceProvider).failure,
        OwnHistoryFailure.forbidden,
      );
      expect(authGateway.suspensionCheckCount, 0);
    },
  );

  test(
    'PT403 with inactive status remains an explicit failure, not a retry loop',
    () async {
      gateway.error = const PostgrestException(
        message: 'Unavailable.',
        code: 'PT403',
      );
      await controller.load();
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
      expect(
        container.read(ownConsequenceProvider).phase,
        OwnHistoryPhase.failure,
      );
      expect(gateway.identities, hasLength(1));
    },
  );
}
