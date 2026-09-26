import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_request_chat/application/project_request_chat_controller.dart';
import 'package:planets_mobile/features/project_request_chat/data/project_request_chat_gateway.dart';
import 'package:planets_mobile/features/project_request_chat/domain/project_request_chat_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_request_chat.dart';

void main() {
  test('loads structured request, sends, and dedupes signal refresh', () async {
    final gateway = FakeProjectRequestChatGateway()
      ..items = [
        projectRequestChatMessageFixture(),
        projectRequestChatRequestFixture(),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectRequestChatProvider.notifier,
    );

    expect(
      await controller.load(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
      ),
      isTrue,
    );
    controller.startSignals('user-1', gateway.summary.requestId);
    expect(
      session.container.read(projectRequestChatProvider).items.first,
      isA<ProjectRequestChatRequestItem>(),
    );

    expect(
      await controller.send(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
        body: '  New reply  ',
      ),
      isTrue,
    );
    gateway.emitSignal();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final messages = session.container
        .read(projectRequestChatProvider)
        .items
        .whereType<ProjectRequestChatHumanMessage>();
    expect(gateway.lastSentBody, 'New reply');
    expect(messages.map((item) => item.itemId).toSet(), hasLength(2));
  });

  test(
    'PT409 refreshes canonical resolved summary without losing history',
    () async {
      final gateway = FakeProjectRequestChatGateway()
        ..items = [
          projectRequestChatMessageFixture(),
          projectRequestChatRequestFixture(),
        ]
        ..sendError = const PostgrestException(
          message: 'private resolution detail',
          code: 'PT409',
        );
      gateway.onSendAttempt = () {
        gateway.summary = projectRequestChatSummaryFixture(
          status: JoinRequestStatus.rejected,
        );
      };
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectRequestChatProvider.notifier,
      );
      await controller.load(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
      );
      final before = session.container.read(projectRequestChatProvider).items;

      expect(
        await controller.send(
          expectedProfileId: 'user-1',
          requestId: gateway.summary.requestId,
          body: 'Too late',
        ),
        isFalse,
      );

      final state = session.container.read(projectRequestChatProvider);
      expect(state.summary?.requestStatus, JoinRequestStatus.rejected);
      expect(state.summary?.hasSendEntitlement, isFalse);
      expect(state.failure, ProjectRequestChatFailureKind.conflict);
      expect(
        state.items.map((item) => item.canonicalKey),
        containsAll(before.map((item) => item.canonicalKey)),
      );
    },
  );

  test(
    'identity change clears state and closes private subscription',
    () async {
      final wait = Completer<void>();
      final gateway = FakeProjectRequestChatGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectRequestChatProvider.notifier,
      );
      await controller.load(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
      );
      controller.startSignals('user-1', gateway.summary.requestId);
      final subscription = gateway.subscriptions.single;
      gateway.historyDelay = wait.future;
      final refresh = controller.refresh(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
      );

      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      wait.complete();

      expect(await refresh, isFalse);
      expect(session.container.read(projectRequestChatProvider).items, isEmpty);
      expect(subscription.isClosed, isTrue);
    },
  );
}

class _Session {
  const _Session(this.container, this.auth);

  final ProviderContainer container;
  final FakeAuthGateway auth;

  void dispose() {
    container.dispose();
    auth.close();
  }
}

_Session _readyContainer(FakeProjectRequestChatGateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      projectRequestChatGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return _Session(container, auth);
}
