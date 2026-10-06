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
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_request_chat.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  test('read-only pair keeps one subscription and reactivates on a new request hint', () async {
    final gateway = FakeProjectRequestChatGateway()
      ..summary = projectRequestChatSummaryFixture(
        status: JoinRequestStatus.rejected,
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectRequestChatProvider.notifier,
    );
    final requestId = gateway.summary.requestId;
    await controller.load(expectedProfileId: 'user-1', requestId: requestId);
    controller.startSignals('user-1', requestId);
    expect(gateway.subscriptions, hasLength(1));
    final repeat = projectRequestChatRequestFixture(
      requestId: '00000000-0000-4000-8000-000000000312',
    );
    gateway.items = [repeat, ...gateway.items];
    gateway.summary = projectRequestChatSummaryFixture(
      status: JoinRequestStatus.rejected,
      pendingCount: 1,
      pendingRequests: [repeat],
      writable: true,
    );
    gateway.emitSignal();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final state = session.container.read(projectRequestChatProvider);
    expect(state.summary?.hasSendEntitlement, isTrue);
    expect(
      state.items.whereType<ProjectRequestChatRequestItem>().map(
        (item) => item.requestId,
      ),
      contains(repeat.requestId),
    );
    expect(gateway.subscriptions, hasLength(1));
  });

  test('reconnect catches up across multiple pages and refreshes old request status in place', () async {
    final gateway = FakeProjectRequestChatGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectRequestChatProvider.notifier,
    );
    final requestId = gateway.summary.requestId;
    await controller.load(expectedProfileId: 'user-1', requestId: requestId);
    controller.startSignals('user-1', requestId);
    final originalCreatedAt = session.container
        .read(projectRequestChatProvider)
        .items
        .single
        .createdAt;
    gateway.summary = projectRequestChatSummaryFixture(
      status: JoinRequestStatus.rejected,
    );
    gateway.items = [
      for (var index = 65; index > 0; index--)
        projectRequestChatMessageFixture(
          itemId:
              '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          createdAt: DateTime.utc(2026, 9, 20, 11, index),
        ),
      ...gateway.items,
    ];
    gateway.subscriptions.single.onStatus(
      ProjectRequestChatConnectionStatus.disconnected,
    );
    gateway.subscriptions.single.onStatus(
      ProjectRequestChatConnectionStatus.connected,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final state = session.container.read(projectRequestChatProvider);
    expect(state.items, hasLength(66));
    expect(state.items.map((item) => item.canonicalKey).toSet(), hasLength(66));
    final request = state.items
        .whereType<ProjectRequestChatRequestItem>()
        .single;
    expect(request.createdAt, originalCreatedAt);
    expect(request.requestStatus, JoinRequestStatus.rejected);
    expect(
      gateway.calls.where((call) => call.startsWith('history:')).length,
      4,
    );
  });

  test('conflict recovery catches up every intervening page without resending', () async {
    final gateway = FakeProjectRequestChatGateway()
      ..sendError = const PostgrestException(
        message: 'Resolved',
        code: 'PT409',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      projectRequestChatProvider.notifier,
    );
    final requestId = gateway.summary.requestId;
    await controller.load(expectedProfileId: 'user-1', requestId: requestId);
    final originalCreatedAt = session.container
        .read(projectRequestChatProvider)
        .items
        .single
        .createdAt;
    gateway.onSendAttempt = () {
      gateway.summary = projectRequestChatSummaryFixture(
        status: JoinRequestStatus.rejected,
      );
      gateway.items = [
        for (var index = 65; index > 0; index--)
          projectRequestChatMessageFixture(
            itemId:
                '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
            createdAt: DateTime.utc(2026, 9, 20, 11, index),
          ),
        ...gateway.items,
      ];
    };
    expect(
      await controller.send(
        expectedProfileId: 'user-1',
        requestId: requestId,
        body: 'Draft',
      ),
      isFalse,
    );
    final state = session.container.read(projectRequestChatProvider);
    expect(state.items, hasLength(66));
    expect(state.items.map((item) => item.canonicalKey).toSet(), hasLength(66));
    expect(
      state.items.whereType<ProjectRequestChatRequestItem>().single.createdAt,
      originalCreatedAt,
    );
    expect(
      state.items
          .whereType<ProjectRequestChatRequestItem>()
          .single
          .requestStatus,
      JoinRequestStatus.rejected,
    );
    expect(state.failure, ProjectRequestChatFailureKind.conflict);
    expect(
      gateway.calls.where((call) => call.startsWith('send:')),
      hasLength(1),
    );
  });

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

  test(
    'detach is idempotent and ignores disconnect callbacks from close',
    () async {
      final gateway = FakeProjectRequestChatGateway()
        ..emitDisconnectedOnClose = true;
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

      expect(() => controller.stopSignals(), returnsNormally);
      expect(() => controller.stopSignals(), returnsNormally);
      subscription.onStatus(ProjectRequestChatConnectionStatus.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(subscription.closeCount, 1);
      expect(
        session.container.read(projectRequestChatProvider).hasConnectionIssue,
        isFalse,
      );
    },
  );

  test(
    'resolved request revalidates and clears a denied counterparty photo',
    () async {
      const requesterId = '00000000-0000-4000-8000-000000000102';
      final photos = FakeProfilePhotoGateway()
        ..visiblePhotos[requesterId] = VisibleProfilePhoto(
          profileId: requesterId,
          objectPath: '$requesterId/00000000-0000-4000-8000-000000000811.webp',
          updatedAt: DateTime.utc(2026, 10, 1),
        );
      final gateway = FakeProjectRequestChatGateway();
      final session = _readyContainer(gateway, photos: photos);
      addTearDown(session.dispose);
      final controller = session.container.read(
        projectRequestChatProvider.notifier,
      );
      await controller.load(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        session.container
            .read(visibleProfilePhotoProvider)
            .entryFor(requesterId)
            ?.imageBytes,
        isNotNull,
      );

      gateway.summary = projectRequestChatSummaryFixture(
        status: JoinRequestStatus.rejected,
      );
      photos.visiblePhotos.remove(requesterId);
      await controller.refresh(
        expectedProfileId: 'user-1',
        requestId: gateway.summary.requestId,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        session.container
            .read(visibleProfilePhotoProvider)
            .entryFor(requesterId),
        isNotNull,
      );
      expect(
        session.container
            .read(visibleProfilePhotoProvider)
            .entryFor(requesterId)
            ?.photo,
        isNull,
      );
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

_Session _readyContainer(
  FakeProjectRequestChatGateway gateway, {
  FakeProfilePhotoGateway? photos,
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
      projectRequestChatGatewayProvider.overrideWithValue(gateway),
      profilePhotoGatewayProvider.overrideWithValue(
        photos ?? FakeProfilePhotoGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return _Session(container, auth);
}
