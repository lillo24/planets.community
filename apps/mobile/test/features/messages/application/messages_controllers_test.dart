import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/application/messages_controllers.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_participation.dart';

void main() {
  test(
    'inbox uses an exact activity/id cursor and appends the next page',
    () async {
      final gateway = FakeMessagesGateway()
        ..items = List.generate(
          21,
          (index) => messageItemFixture(
            requestId: 'request-$index',
            createdAt: DateTime.utc(
              2026,
              9,
              9,
            ).subtract(Duration(minutes: index)),
          ),
        );
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);

      final controller = session.container.read(messagesInboxProvider.notifier);
      expect(await controller.load('user-1'), isTrue);
      expect(
        session.container.read(messagesInboxProvider).items,
        hasLength(20),
      );
      expect(session.container.read(messagesInboxProvider).hasMore, isTrue);
      expect(await controller.loadMore('user-1'), isTrue);
      expect(gateway.lastCursor?.requestId, 'request-19');
      expect(
        session.container.read(messagesInboxProvider).items,
        hasLength(21),
      );
      expect(session.container.read(messagesInboxProvider).hasMore, isFalse);
    },
  );

  test(
    'creator acceptance blocks duplicate taps and reloads canonical status',
    () async {
      final pending = Completer<void>();
      final gateway = FakeMessagesGateway()
        ..items = [messageItemFixture()]
        ..mutationDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        messagesDetailProvider.notifier,
      );
      await controller.load(
        expectedProfileId: 'user-1',
        requestId: 'request-1',
      );

      final first = controller.accept();
      expect(await controller.accept(), isFalse);
      expect(
        gateway.calls.where((call) => call == 'accept:request-1'),
        hasLength(1),
      );
      pending.complete();
      expect(await first, isTrue);
      expect(
        session.container.read(messagesDetailProvider).item?.status.name,
        'accepted',
      );
      expect(session.container.read(projectChatRefreshProvider), 1);
    },
  );

  test('requester cannot invoke creator actions', () async {
    final gateway = FakeMessagesGateway()
      ..items = [messageItemFixture(viewerRole: MessageViewerRole.requester)];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(messagesDetailProvider.notifier);
    await controller.load(expectedProfileId: 'user-1', requestId: 'request-1');

    expect(await controller.accept(), isFalse);
    expect(await controller.reject(), isFalse);
    expect(gateway.calls.where((call) => call.startsWith('accept:')), isEmpty);
  });

  test('creator can reject and reload the canonical resolved item', () async {
    final gateway = FakeMessagesGateway()..items = [messageItemFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(messagesDetailProvider.notifier);
    await controller.load(expectedProfileId: 'user-1', requestId: 'request-1');

    expect(await controller.reject(), isTrue);
    expect(gateway.calls, contains('reject:request-1'));
    expect(
      session.container.read(messagesDetailProvider).item?.status,
      JoinRequestStatus.rejected,
    );
  });

  test('an already-resolved conflict reloads canonical state', () async {
    final pending = Completer<void>();
    final gateway = FakeMessagesGateway()
      ..items = [messageItemFixture()]
      ..mutationDelay = pending.future
      ..mutationError = const PostgrestException(
        message: 'private database diagnostic',
        code: '55000',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(messagesDetailProvider.notifier);
    await controller.load(expectedProfileId: 'user-1', requestId: 'request-1');

    final action = controller.accept();
    gateway.items = [messageItemFixture(status: JoinRequestStatus.rejected)];
    pending.complete();

    expect(await action, isFalse);
    final state = session.container.read(messagesDetailProvider);
    expect(state.item?.status, JoinRequestStatus.rejected);
    expect(state.failure, MessagesFailureKind.conflict);
  });

  test('identity change discards a late mutation result', () async {
    final pending = Completer<void>();
    final gateway = FakeMessagesGateway()
      ..items = [messageItemFixture()]
      ..mutationDelay = pending.future;
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(messagesDetailProvider.notifier);
    await controller.load(expectedProfileId: 'user-1', requestId: 'request-1');

    final action = controller.accept();
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pending.complete();

    expect(await action, isFalse);
    expect(session.container.read(messagesDetailProvider).item, isNull);
  });

  test(
    'account switch discards late private inbox and detail responses',
    () async {
      final pending = Completer<void>();
      final gateway = FakeMessagesGateway()
        ..items = [messageItemFixture()]
        ..listDelay = pending.future
        ..detailDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final inboxLoad = session.container
          .read(messagesInboxProvider.notifier)
          .load('user-1');
      final detailLoad = session.container
          .read(messagesDetailProvider.notifier)
          .load(expectedProfileId: 'user-1', requestId: 'request-1');
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();

      expect(await inboxLoad, isFalse);
      expect(await detailLoad, isFalse);
      expect(session.container.read(messagesInboxProvider).items, isEmpty);
      expect(session.container.read(messagesDetailProvider).item, isNull);
    },
  );
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeMessagesGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      messagesGatewayProvider.overrideWithValue(gateway),
      participationGatewayProvider.overrideWithValue(
        FakeParticipationGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
