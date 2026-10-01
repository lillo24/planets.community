import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_needs.dart';

void main() {
  test('chat list uses keyset pagination and dedupes IDs', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [
        ...List.generate(
          20,
          (index) => projectChatSummaryFixture(
            chatId: 'chat-$index',
            projectId: 'proposal-$index',
            activityAt: DateTime.utc(
              2026,
              9,
              14,
            ).subtract(Duration(minutes: index)),
          ),
        ),
        projectChatSummaryFixture(
          chatId: 'chat-19',
          projectId: 'proposal-19',
          activityAt: DateTime.utc(2026, 9, 14, 0, 41),
        ),
        projectChatSummaryFixture(
          chatId: 'chat-20',
          projectId: 'proposal-20',
          activityAt: DateTime.utc(2026, 9, 14, 0, 40),
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(projectChatListProvider.notifier);

    expect(await controller.load('user-1'), isTrue);
    expect(
      session.container.read(projectChatListProvider).items,
      hasLength(20),
    );
    expect(
      session.container.read(projectChatListProvider).items.first.chatId,
      'chat-0',
    );
    expect(await controller.loadMore('user-1'), isTrue);
    expect(gateway.lastListCursor?.chatId, 'chat-19');
    expect(
      session.container.read(projectChatListProvider).items,
      hasLength(21),
    );
  });

  test(
    'chat-list account switch clears state and rejects late refresh',
    () async {
      final delay = Completer<void>();
      final gateway = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectChatListProvider.notifier,
      );
      await controller.load('user-1');
      controller.startSignals('user-1');
      final subscription = gateway.subscriptions.single;
      gateway.listDelay = delay.future;

      final refresh = controller.load('user-1', refresh: true);
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      delay.complete();

      expect(await refresh, isFalse);
      expect(session.container.read(projectChatListProvider).items, isEmpty);
      expect(subscription.isClosed, isTrue);
    },
  );

  test('history reverses newest-first pages and prepends older rows', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [
        ...List.generate(
          30,
          (index) => projectChatMessageFixture(
            messageId: 'message-$index',
            createdAt: DateTime.utc(
              2026,
              9,
              14,
              12,
            ).subtract(Duration(minutes: index)),
          ),
        ),
        projectChatMessageFixture(
          messageId: 'message-29',
          createdAt: DateTime.utc(2026, 9, 14, 11, 31),
        ),
        projectChatMessageFixture(
          messageId: 'message-30',
          createdAt: DateTime.utc(2026, 9, 14, 11, 30),
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );

    expect(
      await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1'),
      isTrue,
    );
    var state = session.container.read(projectChatDetailProvider);
    expect(state.feedItems.first.itemId, 'message-29');
    expect(state.feedItems.last.itemId, 'message-0');
    expect(state.hasMoreOlder, isTrue);

    expect(
      await controller.loadOlder(expectedProfileId: 'user-1', chatId: 'chat-1'),
      isTrue,
    );
    state = session.container.read(projectChatDetailProvider);
    expect(gateway.lastFeedCursor?.itemId, 'message-29');
    expect(state.feedItems.first.itemId, 'message-30');
    expect(state.feedItems, hasLength(31));
  });

  test('same-timestamp history has stable message-ID order', () async {
    final timestamp = DateTime.utc(2026, 9, 14, 12);
    final gateway = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [
        projectChatMessageFixture(messageId: 'message-b', createdAt: timestamp),
        projectChatMessageFixture(messageId: 'message-a', createdAt: timestamp),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    await session.container
        .read(projectChatDetailProvider.notifier)
        .load(expectedProfileId: 'user-1', chatId: 'chat-1');

    expect(
      session.container
          .read(projectChatDetailProvider)
          .feedItems
          .map((item) => item.itemId),
      ['message-a', 'message-b'],
    );
  });

  test(
    'same-timestamp mixed feed reverses the canonical kind tie order',
    () async {
      final timestamp = DateTime.utc(2026, 9, 14, 12);
      final gateway = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [
          projectChatMessageFixture(
            messageId: 'message-a',
            createdAt: timestamp,
          ),
          projectChatSystemEventFixture(
            eventId: 'event-a',
            createdAt: timestamp,
          ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      await session.container
          .read(projectChatDetailProvider.notifier)
          .load(expectedProfileId: 'user-1', chatId: 'chat-1');

      final items = session.container.read(projectChatDetailProvider).feedItems;
      expect(items.first, isA<ProjectChatRequirementNeededAgain>());
      expect(items.last, isA<ProjectChatHumanMessage>());
    },
  );

  test('own send plus canonical signal remains one message', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
    controller.startSignals('user-1', 'chat-1');

    expect(
      await controller.send(
        expectedProfileId: 'user-1',
        chatId: 'chat-1',
        body: '  Hello team  ',
      ),
      isTrue,
    );
    gateway.emitSignal('chat-1', messageId: 'sent-1');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = session.container.read(projectChatDetailProvider);
    expect(state.feedItems, hasLength(1));
    expect(
      (state.feedItems.single as ProjectChatHumanMessage).body,
      'Hello team',
    );
    expect(gateway.lastSentBody, 'Hello team');
  });

  test('send rejects blank and oversized text before the RPC', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');

    expect(
      await controller.send(
        expectedProfileId: 'user-1',
        chatId: 'chat-1',
        body: '   ',
      ),
      isFalse,
    );
    expect(
      await controller.send(
        expectedProfileId: 'user-1',
        chatId: 'chat-1',
        body: List.filled(projectChatMessageMaxLength + 1, 'x').join(),
      ),
      isFalse,
    );
    expect(gateway.calls.where((call) => call.startsWith('send:')), isEmpty);
    expect(
      session.container.read(projectChatDetailProvider).failure,
      ProjectChatFailureKind.invalidInput,
    );
  });

  test(
    'signal during a load is reconciled after the durable response',
    () async {
      final delay = Completer<void>();
      final gateway = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [projectChatMessageFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
      controller.startSignals('user-1', 'chat-1');
      gateway.historyDelay = delay.future;

      final refresh = controller.refresh(
        expectedProfileId: 'user-1',
        chatId: 'chat-1',
      );
      gateway.emitSignal('chat-1');
      gateway.histories['chat-1'] = [
        projectChatMessageFixture(messageId: 'message-2'),
        projectChatMessageFixture(),
      ];
      delay.complete();
      await refresh;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        session.container.read(projectChatDetailProvider).feedItems,
        hasLength(2),
      );
    },
  );

  test('reconnect catches up durable history', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [projectChatMessageFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
    controller.startSignals('user-1', 'chat-1');
    gateway.emitStatus('chat-1', ProjectChatConnectionStatus.disconnected);
    gateway.histories['chat-1'] = [
      projectChatMessageFixture(messageId: 'message-2'),
      projectChatMessageFixture(),
    ];
    gateway.emitStatus('chat-1', ProjectChatConnectionStatus.connected);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      session.container.read(projectChatDetailProvider).feedItems,
      hasLength(2),
    );
    expect(
      session.container.read(projectChatDetailProvider).hasConnectionIssue,
      isFalse,
    );
  });

  test(
    'requirement signals coordinate feed and Needs without a second channel',
    () async {
      final needs = FakeProjectNeedsGateway()
        ..requirements = [projectRequirementFixture()];
      final gateway = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [projectChatMessageFixture()];
      final session = _readyContainer(gateway, needs: needs);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
      controller.startSignals('user-1', 'chat-1');
      await Future<void>.delayed(Duration.zero);
      final historyCallsBefore = gateway.calls
          .where((call) => call == 'history:chat-1')
          .length;
      final coverageCallsBefore = needs.calls
          .where((call) => call == 'coverage:proposal-1')
          .length;

      gateway.emitCovered();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        gateway.calls.where((call) => call == 'history:chat-1').length,
        historyCallsBefore,
      );
      expect(
        needs.calls.where((call) => call == 'coverage:proposal-1').length,
        greaterThan(coverageCallsBefore),
      );

      gateway.histories['chat-1'] = [
        projectChatSystemEventFixture(createdAt: DateTime.utc(2026, 9, 14, 12)),
        projectChatMessageFixture(),
      ];
      gateway.emitNeededAgain();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        session.container
            .read(projectChatDetailProvider)
            .feedItems
            .whereType<ProjectChatRequirementNeededAgain>(),
        hasLength(1),
      );
      expect(gateway.subscriptions, hasLength(1));
    },
  );

  test('canonical current to former transition unsubscribes', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [projectChatMessageFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
    controller.startSignals('user-1', 'chat-1');
    final subscription = gateway.subscriptions.single;
    gateway.summaries = [
      projectChatSummaryFixture(viewerRole: ProjectChatViewerRole.formerMember),
    ];

    await controller.refresh(expectedProfileId: 'user-1', chatId: 'chat-1');

    expect(subscription.isClosed, isTrue);
    expect(
      session.container.read(projectChatDetailProvider).summary?.isReadOnly,
      isTrue,
    );
  });

  test('screen stop closes the live subscription', () async {
    final gateway = FakeProjectChatGateway()
      ..emitDisconnectedOnClose = true
      ..summaries = [projectChatSummaryFixture()]
      ..histories['chat-1'] = [];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
    controller.startSignals('user-1', 'chat-1');

    controller.stopSignals();
    controller.stopSignals();
    gateway.subscriptions.single.onStatus(
      ProjectChatConnectionStatus.disconnected,
    );
    await Future<void>.delayed(Duration.zero);

    expect(gateway.subscriptions.single.isClosed, isTrue);
    expect(gateway.subscriptions.single.closeCount, 1);
    expect(
      session.container.read(projectChatDetailProvider).hasConnectionIssue,
      isFalse,
    );
  });

  test('rejoin restores composer entitlement and subscription', () async {
    final gateway = FakeProjectChatGateway()
      ..summaries = [
        projectChatSummaryFixture(
          viewerRole: ProjectChatViewerRole.formerMember,
        ),
      ]
      ..histories['chat-1'] = [projectChatMessageFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
    controller.startSignals('user-1', 'chat-1');
    expect(gateway.subscriptions, isEmpty);
    gateway.summaries = [projectChatSummaryFixture()];

    await controller.refresh(expectedProfileId: 'user-1', chatId: 'chat-1');

    expect(gateway.subscriptions, hasLength(1));
    expect(
      session.container
          .read(projectChatDetailProvider)
          .summary
          ?.hasCurrentEntitlement,
      isTrue,
    );
  });

  test(
    'account switch clears state, rejects late response and unsubscribes',
    () async {
      final delay = Completer<void>();
      final gateway = FakeProjectChatGateway()
        ..summaries = [projectChatSummaryFixture()]
        ..histories['chat-1'] = [projectChatMessageFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: 'chat-1');
      controller.startSignals('user-1', 'chat-1');
      final subscription = gateway.subscriptions.single;
      gateway.historyDelay = delay.future;
      final refresh = controller.refresh(
        expectedProfileId: 'user-1',
        chatId: 'chat-1',
      );

      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      delay.complete();

      expect(await refresh, isFalse);
      expect(
        session.container.read(projectChatDetailProvider).feedItems,
        isEmpty,
      );
      expect(subscription.isClosed, isTrue);
    },
  );
}

class _TestSession {
  _TestSession(this.container, this.auth);

  final ProviderContainer container;
  final FakeAuthGateway auth;

  void dispose() {
    container.dispose();
    auth.close();
  }
}

_TestSession _readyContainer(
  FakeProjectChatGateway gateway, {
  FakeProjectNeedsGateway? needs,
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
      participationGatewayProvider.overrideWithValue(
        FakeParticipationGateway(),
      ),
      projectChatGatewayProvider.overrideWithValue(gateway),
      projectNeedsGatewayProvider.overrideWithValue(
        needs ?? FakeProjectNeedsGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return _TestSession(container, auth);
}
