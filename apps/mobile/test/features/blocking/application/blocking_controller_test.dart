import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/application/blocking_controller.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/blocking/domain/blocking_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_blocking.dart';

void main() {
  test('caches exact outbound status and paginates independently', () async {
    final gateway = FakeBlockingGateway()
      ..items = List.generate(
        22,
        (index) => blockedProfileFixture(
          profileId:
              '10000000-0000-4000-8000-${(index + 20).toString().padLeft(12, '0')}',
          displayName: 'Person $index',
          blockedAt: DateTime.utc(
            2026,
            9,
            29,
          ).subtract(Duration(minutes: index)),
        ),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(blockingProvider.notifier);

    expect(
      await controller.loadStatus(blockerProfileId, gateway.items[0].profileId),
      isTrue,
    );
    expect(
      await controller.loadStatus(blockerProfileId, gateway.items[0].profileId),
      isFalse,
    );
    expect(gateway.statusCalls, 1);
    expect(await controller.loadList(blockerProfileId), isTrue);
    expect(
      session.container.read(blockingProvider).blockedProfiles,
      hasLength(20),
    );
    expect(await controller.loadMore(blockerProfileId), isTrue);
    expect(
      session.container.read(blockingProvider).blockedProfiles,
      hasLength(22),
    );
    expect(gateway.lastCursor?.displayName, 'Person 19');
  });

  test(
    'block and unblock update exact cache only after canonical success',
    () async {
      final gateway = FakeBlockingGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(blockingProvider.notifier);

      expect(
        await controller.block(blockerProfileId, blockedProfileId),
        BlockingMutationOutcome.success,
      );
      expect(
        session.container.read(blockingProvider).exactStatus(blockedProfileId),
        isNotNull,
      );
      expect(
        await controller.unblock(blockerProfileId, blockedProfileId),
        BlockingMutationOutcome.success,
      );
      expect(
        session.container.read(blockingProvider).exactStatus(blockedProfileId),
        isNull,
      );
    },
  );

  test('duplicate tap is ignored while mutation is pending', () async {
    final pending = Completer<void>();
    final gateway = FakeBlockingGateway()..delay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(blockingProvider.notifier);

    final first = controller.block(blockerProfileId, blockedProfileId);
    await Future<void>.delayed(Duration.zero);
    expect(
      await controller.block(blockerProfileId, blockedProfileId),
      BlockingMutationOutcome.busy,
    );
    pending.complete();
    expect(await first, BlockingMutationOutcome.success);
    expect(gateway.blockCalls, 1);
  });

  test('account switch clears cache and rejects late operation', () async {
    final pending = Completer<void>();
    final gateway = FakeBlockingGateway()..delay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(blockingProvider.notifier);
    final operation = controller.block(blockerProfileId, blockedProfileId);
    await Future<void>.delayed(Duration.zero);

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: anotherBlockedProfileId));
    pending.complete();
    expect(await operation, BlockingMutationOutcome.staleIdentity);
    final state = session.container.read(blockingProvider);
    expect(state.expectedProfileId, anotherBlockedProfileId);
    expect(state.blockedProfiles, isEmpty);
    expect(state.exactStatuses, isEmpty);
  });

  test('maps SQLSTATEs to safe direction-neutral failures', () {
    expect(
      mapBlockingFailure(
        const PostgrestException(message: 'private', code: 'PT409'),
      ),
      BlockingFailureKind.interactionUnavailable,
    );
    expect(
      mapBlockingFailure(
        const PostgrestException(message: 'private', code: 'P0002'),
      ),
      BlockingFailureKind.targetUnavailable,
    );
    expect(
      mapBlockingFailure(StateError('private')),
      BlockingFailureKind.unavailable,
    );
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeBlockingGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: blockerProfileId)),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      blockingGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: blockerProfileId));
  return (
    container: container,
    dispose: () {
      container.dispose();
      unawaited(auth.close());
    },
  );
}
