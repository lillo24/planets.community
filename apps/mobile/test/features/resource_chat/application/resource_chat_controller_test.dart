import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/resource_exchange/application/resource_exchange_refresh.dart';
import 'package:planets_mobile/features/resource_chat/application/resource_chat_controller.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_resource_chat.dart';

void main() {
  test('maps canonical database failures without exposing diagnostics', () {
    expect(
      mapResourceChatFailure(
        const PostgrestException(message: 'private', code: '22023'),
      ),
      ResourceChatFailureKind.invalidInput,
    );
    expect(
      mapResourceChatFailure(
        const PostgrestException(message: 'private', code: '42501'),
      ),
      ResourceChatFailureKind.forbidden,
    );
    expect(
      mapResourceChatFailure(
        const PostgrestException(message: 'private', code: 'P0002'),
      ),
      ResourceChatFailureKind.notFound,
    );
    expect(
      mapResourceChatFailure(
        const PostgrestException(message: 'private', code: 'XX000'),
      ),
      ResourceChatFailureKind.unavailable,
    );
  });

  test('loads newest-first history into oldest-first UI order', () async {
    final gateway = FakeResourceChatGateway()
      ..histories[gatewayChatId] = [
        resourceChatMessageFixture(
          messageId: '00000000-0000-4000-8000-000000000902',
          createdAt: DateTime.utc(2026, 9, 20, 12),
        ),
        resourceChatMessageFixture(createdAt: DateTime.utc(2026, 9, 20, 11)),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    expect(
      await session.container
          .read(resourceChatDetailProvider.notifier)
          .load(expectedProfileId: 'user-1', chatId: gatewayChatId),
      isTrue,
    );
    final messages = session.container
        .read(resourceChatDetailProvider)
        .messages;
    expect(messages.first.messageId, endsWith('901'));
    expect(messages.last.messageId, endsWith('902'));
  });

  test('loads older history with cursor and deduplication', () async {
    final gateway = FakeResourceChatGateway()
      ..histories[gatewayChatId] = List.generate(
        31,
        (index) => resourceChatMessageFixture(
          messageId:
              '00000000-0000-4000-8000-${(index + 1000).toString().padLeft(12, '0')}',
          createdAt: DateTime.utc(
            2026,
            9,
            20,
            12,
          ).subtract(Duration(minutes: index)),
        ),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);

    expect(
      await controller.loadOlder(
        expectedProfileId: 'user-1',
        chatId: gatewayChatId,
      ),
      isTrue,
    );
    expect(gateway.lastCursor?.messageId, endsWith('1029'));
    expect(
      session.container.read(resourceChatDetailProvider).messages,
      hasLength(31),
    );
  });

  test('send merges once and sender echo does not duplicate', () async {
    final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
    controller.startSignals('user-1', gatewayChatId);

    expect(
      await controller.send(
        expectedProfileId: 'user-1',
        chatId: gatewayChatId,
        body: '  Hello  ',
      ),
      isTrue,
    );
    gateway.emitMessage(
      gatewayChatId,
      messageId: session.container
          .read(resourceChatDetailProvider)
          .messages
          .single
          .messageId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(gateway.lastSentBody, 'Hello');
    expect(
      session.container.read(resourceChatDetailProvider).messages,
      hasLength(1),
    );
  });

  test(
    'remote signal fetches canonical message rather than payload body',
    () async {
      final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      controller.startSignals('user-1', gatewayChatId);
      gateway.histories[gatewayChatId] = [
        resourceChatMessageFixture(body: 'Canonical remote body'),
      ];

      gateway.emitMessage(gatewayChatId);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        session.container.read(resourceChatDetailProvider).messages.single.body,
        'Canonical remote body',
      );
    },
  );

  test(
    'exchange completion becomes read-only and closes subscription',
    () async {
      final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      controller.startSignals('user-1', gatewayChatId);
      final subscription = gateway.subscriptions.single;
      gateway.summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.completed,
      );

      gateway.emitExchange(gatewayChatId);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        session.container
            .read(resourceChatDetailProvider)
            .summary
            ?.hasSendEntitlement,
        isFalse,
      );
      expect(subscription.isClosed, isTrue);
      expect(
        gateway.calls.where((call) => call.startsWith('history:')),
        hasLength(1),
      );
    },
  );

  test(
    'PT409 sends once, preserves conflict state, and reloads summary',
    () async {
      final gateway = FakeResourceChatGateway()
        ..histories[gatewayChatId] = []
        ..sendError = const PostgrestException(
          message: 'private closed details',
          code: 'PT409',
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      gateway.summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.cancelled,
      );

      expect(
        await controller.send(
          expectedProfileId: 'user-1',
          chatId: gatewayChatId,
          body: 'Unsent text',
        ),
        isFalse,
      );
      final state = session.container.read(resourceChatDetailProvider);
      expect(gateway.sendCount, 1);
      expect(state.failure, ResourceChatFailureKind.conflict);
      expect(state.summary?.hasSendEntitlement, isFalse);
    },
  );

  test('reconnect catches up summary and newest history', () async {
    final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceChatDetailProvider.notifier,
    );
    await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
    controller.startSignals('user-1', gatewayChatId);
    gateway.emitStatus(
      gatewayChatId,
      ResourceChatConnectionStatus.disconnected,
    );
    gateway.histories[gatewayChatId] = [resourceChatMessageFixture()];

    gateway.emitStatus(gatewayChatId, ResourceChatConnectionStatus.connected);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final state = session.container.read(resourceChatDetailProvider);
    expect(state.hasConnectionIssue, isFalse);
    expect(state.messages, hasLength(1));
  });

  test(
    'exchange signal reuses one channel and notifies agreement refresh',
    () async {
      final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      controller.startSignals('user-1', gatewayChatId);
      final before = session.container.read(resourceExchangeRefreshProvider);

      gateway.emitExchange(gatewayChatId);

      expect(
        session.container.read(resourceExchangeRefreshProvider),
        before + 1,
      );
      expect(gateway.subscriptions, hasLength(1));
    },
  );

  test(
    'app resume notifies agreement refresh without another channel',
    () async {
      final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      controller.startSignals('user-1', gatewayChatId);
      final before = session.container.read(resourceExchangeRefreshProvider);

      controller.handleAppResumed('user-1', gatewayChatId);

      expect(
        session.container.read(resourceExchangeRefreshProvider),
        before + 1,
      );
      expect(gateway.subscriptions, hasLength(1));
    },
  );

  test('account switch rejects a late read and clears private state', () async {
    final delay = Completer<void>();
    final gateway = FakeResourceChatGateway()
      ..histories[gatewayChatId] = []
      ..historyDelay = delay.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final load = session.container
        .read(resourceChatDetailProvider.notifier)
        .load(expectedProfileId: 'user-1', chatId: gatewayChatId);
    await Future<void>.delayed(Duration.zero);

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    delay.complete();

    expect(await load, isFalse);
    expect(
      session.container.read(resourceChatDetailProvider).messages,
      isEmpty,
    );
  });

  test(
    'open coordination loads the role-specific counterparty photo',
    () async {
      final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
      final photos = FakeProfilePhotoGateway()
        ..visiblePhotos[_requesterId] = _requesterPhoto;
      final session = _readyContainer(gateway, photos: photos);
      addTearDown(session.dispose);

      await session.container
          .read(resourceChatDetailProvider.notifier)
          .load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      await Future<void>.delayed(Duration.zero);

      expect(photos.visibleLoadIds, [_requesterId]);
      expect(
        session.container
            .read(visibleProfilePhotoProvider)
            .entryFor(_requesterId)
            ?.hasVisiblePhoto,
        isTrue,
      );
    },
  );

  test('requester loads the owner photo during open coordination', () async {
    final gateway = FakeResourceChatGateway()
      ..summary = resourceChatSummaryFixture(
        viewerRole: ResourceChatViewerRole.requester,
      )
      ..histories[gatewayChatId] = [];
    final photos = FakeProfilePhotoGateway()
      ..visiblePhotos[_ownerId] = _ownerPhoto;
    final session = _readyContainer(
      gateway,
      profileId: _requesterId,
      photos: photos,
    );
    addTearDown(session.dispose);

    await session.container
        .read(resourceChatDetailProvider.notifier)
        .load(expectedProfileId: _requesterId, chatId: gatewayChatId);
    await Future<void>.delayed(Duration.zero);

    expect(photos.visibleLoadIds, [_ownerId]);
    expect(
      session.container
          .read(visibleProfilePhotoProvider)
          .entryFor(_ownerId)
          ?.hasVisiblePhoto,
      isTrue,
    );
  });

  test('account switch clears loaded counterparty bytes', () async {
    final gateway = FakeResourceChatGateway()..histories[gatewayChatId] = [];
    final photos = FakeProfilePhotoGateway()
      ..visiblePhotos[_requesterId] = _requesterPhoto;
    final session = _readyContainer(gateway, photos: photos);
    addTearDown(session.dispose);

    await session.container
        .read(resourceChatDetailProvider.notifier)
        .load(expectedProfileId: 'user-1', chatId: gatewayChatId);
    await Future<void>.delayed(Duration.zero);
    expect(
      session.container
          .read(visibleProfilePhotoProvider)
          .entryFor(_requesterId)
          ?.hasVisiblePhoto,
      isTrue,
    );

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await Future<void>.delayed(Duration.zero);

    expect(
      session.container
          .read(visibleProfilePhotoProvider)
          .entryFor(_requesterId),
      isNull,
    );
  });

  test(
    'coordination closure invalidates counterpart bytes but keeps history',
    () async {
      final gateway = FakeResourceChatGateway()
        ..histories[gatewayChatId] = [resourceChatMessageFixture()];
      final photos = FakeProfilePhotoGateway()
        ..visiblePhotos[_requesterId] = _requesterPhoto;
      final session = _readyContainer(gateway, photos: photos);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceChatDetailProvider.notifier,
      );
      await controller.load(expectedProfileId: 'user-1', chatId: gatewayChatId);
      await Future<void>.delayed(Duration.zero);

      gateway.summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.cancelled,
      );
      expect(
        await controller.refreshSummary(
          expectedProfileId: 'user-1',
          chatId: gatewayChatId,
        ),
        isTrue,
      );

      expect(
        session.container
            .read(visibleProfilePhotoProvider)
            .entryFor(_requesterId),
        isNull,
      );
      expect(
        session.container.read(resourceChatDetailProvider).messages,
        hasLength(1),
      );
    },
  );
}

const gatewayChatId = '00000000-0000-4000-8000-000000000401';

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
  FakeResourceChatGateway gateway, {
  String profileId = 'user-1',
  FakeProfilePhotoGateway? photos,
}) {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: profileId)),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      resourceChatGatewayProvider.overrideWithValue(gateway),
      if (photos != null) profilePhotoGatewayProvider.overrideWithValue(photos),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(AuthIdentity(id: profileId));
  return _Session(container, auth);
}

const _requesterId = '00000000-0000-4000-8000-000000000102';
const _ownerId = '00000000-0000-4000-8000-000000000101';
const _requesterVersion = 'b6700000-0000-4000-8000-000000000001';
const _ownerVersion = 'b6700000-0000-4000-8000-000000000002';
final _requesterPhoto = VisibleProfilePhoto(
  profileId: _requesterId,
  objectPath: '$_requesterId/$_requesterVersion.webp',
  updatedAt: DateTime.utc(2026, 9, 27),
);
final _ownerPhoto = VisibleProfilePhoto(
  profileId: _ownerId,
  objectPath: '$_ownerId/$_ownerVersion.webp',
  updatedAt: DateTime.utc(2026, 9, 27),
);
