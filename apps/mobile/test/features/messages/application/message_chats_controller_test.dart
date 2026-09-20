import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/application/message_chats_controller.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_resource_chat.dart';

void main() {
  test('loads mixed pages and dedupes by kind plus chat ID', () async {
    const shared = '00000000-0000-4000-8000-000000000401';
    final list = FakeMessageChatsGateway()
      ..items = [
        projectMessageChatFixture(chatId: shared),
        resourceMessageChatFixture(chatId: shared),
        ...List.generate(
          19,
          (index) => projectMessageChatFixture(
            chatId:
                '00000000-0000-4000-8000-${(index + 1000).toString().padLeft(12, '0')}',
          ),
        ),
        resourceMessageChatFixture(chatId: shared),
      ];
    final session = _readyContainer(list);
    addTearDown(session.dispose);
    final controller = session.container.read(messageChatsProvider.notifier);

    expect(await controller.load('user-1'), isTrue);
    expect(session.container.read(messageChatsProvider).items, hasLength(20));
    expect(await controller.loadMore('user-1'), isTrue);
    expect(list.lastCursor?.itemKind, isNotNull);
    expect(session.container.read(messageChatsProvider).items, hasLength(21));
  });

  test('subscribes only loaded writable rows and closes stale rows', () async {
    final project = FakeProjectChatGateway();
    final resource = FakeResourceChatGateway();
    final list = FakeMessageChatsGateway()
      ..items = [
        projectMessageChatFixture(),
        resourceMessageChatFixture(),
        resourceMessageChatFixture(
          chatId: '00000000-0000-4000-8000-000000000402',
          lifecycle: ResourceExchangeLifecycle.completed,
          isReadOnly: true,
        ),
      ];
    final session = _readyContainer(list, project: project, resource: resource);
    addTearDown(session.dispose);
    final controller = session.container.read(messageChatsProvider.notifier);
    await controller.load('user-1');
    controller.startSignals('user-1');

    expect(project.subscriptions, hasLength(1));
    expect(resource.subscriptions, hasLength(1));
    final resourceSubscription = resource.subscriptions.single;

    list.items = [projectMessageChatFixture()];
    await controller.load('user-1', refresh: true);
    await Future<void>.delayed(Duration.zero);

    expect(resourceSubscription.isClosed, isTrue);
  });

  test('signal bursts debounce one canonical list refresh', () async {
    final project = FakeProjectChatGateway();
    final resource = FakeResourceChatGateway();
    final list = FakeMessageChatsGateway()
      ..items = [projectMessageChatFixture(), resourceMessageChatFixture()];
    final session = _readyContainer(list, project: project, resource: resource);
    addTearDown(session.dispose);
    final controller = session.container.read(messageChatsProvider.notifier);
    await controller.load('user-1');
    controller.startSignals('user-1');

    project.emitSignal(project.subscriptions.single.chatId);
    resource.emitMessage(resource.subscriptions.single.chatId);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(list.calls.where((call) => call == 'list'), hasLength(2));
  });

  test('reconnect performs canonical catch-up and clears warning', () async {
    final resource = FakeResourceChatGateway();
    final list = FakeMessageChatsGateway()
      ..items = [resourceMessageChatFixture()];
    final session = _readyContainer(list, resource: resource);
    addTearDown(session.dispose);
    final controller = session.container.read(messageChatsProvider.notifier);
    await controller.load('user-1');
    controller.startSignals('user-1');
    final chatId = resource.subscriptions.single.chatId;

    resource.emitStatus(chatId, ResourceChatConnectionStatus.disconnected);
    expect(
      session.container.read(messageChatsProvider).hasConnectionIssue,
      isTrue,
    );
    resource.emitStatus(chatId, ResourceChatConnectionStatus.connected);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(
      session.container.read(messageChatsProvider).hasConnectionIssue,
      isFalse,
    );
    expect(list.calls.where((call) => call == 'list'), hasLength(2));
  });

  test(
    'account switch clears rows, closes subscriptions, rejects late read',
    () async {
      final delay = Completer<void>();
      final resource = FakeResourceChatGateway();
      final list = FakeMessageChatsGateway()
        ..items = [resourceMessageChatFixture()];
      final session = _readyContainer(list, resource: resource);
      addTearDown(session.dispose);
      final controller = session.container.read(messageChatsProvider.notifier);
      await controller.load('user-1');
      controller.startSignals('user-1');
      final subscription = resource.subscriptions.single;
      list.delay = delay.future;
      final refresh = controller.load('user-1', refresh: true);

      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      delay.complete();

      expect(await refresh, isFalse);
      expect(session.container.read(messageChatsProvider).items, isEmpty);
      expect(subscription.isClosed, isTrue);
    },
  );
}

class _Session {
  _Session(this.container, this.auth);

  final ProviderContainer container;
  final FakeAuthGateway auth;

  void dispose() {
    container.dispose();
    auth.close();
  }
}

_Session _readyContainer(
  FakeMessageChatsGateway list, {
  FakeProjectChatGateway? project,
  FakeResourceChatGateway? resource,
}) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      messageChatsGatewayProvider.overrideWithValue(list),
      projectChatGatewayProvider.overrideWithValue(
        project ?? FakeProjectChatGateway(),
      ),
      resourceChatGatewayProvider.overrideWithValue(
        resource ?? FakeResourceChatGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return _Session(container, auth);
}
