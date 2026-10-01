import 'dart:async';

import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';

class FakeResourceChatGateway implements ResourceChatGateway {
  ResourceChatSummary summary = resourceChatSummaryFixture();
  final Map<String, List<ResourceChatMessage>> histories = {};
  final List<String> calls = [];
  final List<FakeResourceChatSubscription> subscriptions = [];
  Object? summaryError;
  Object? historyError;
  Object? sendError;
  Future<void>? summaryDelay;
  Future<void>? historyDelay;
  Future<void>? sendDelay;
  ResourceChatMessageCursor? lastCursor;
  String? lastSentBody;
  var sendCount = 0;
  void Function()? onSendAttempt;
  bool emitDisconnectedOnClose = false;

  @override
  Future<ResourceChatSummary> getChat({
    required String expectedProfileId,
    required String chatId,
  }) async {
    calls.add('summary:$chatId');
    if (summaryDelay case final delay?) await delay;
    if (summaryError case final error?) throw error;
    return summary;
  }

  @override
  Future<ResourceChatMessagePage> listMessages({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ResourceChatMessageCursor? cursor,
  }) async {
    calls.add('history:$chatId');
    lastCursor = cursor;
    if (historyDelay case final delay?) await delay;
    if (historyError case final error?) throw error;
    final source = histories[chatId] ?? const [];
    final start = cursor == null
        ? 0
        : source.indexWhere((item) => item.messageId == cursor.messageId) + 1;
    final safeStart = start < 0 ? 0 : start;
    final page = source.skip(safeStart).take(limit).toList(growable: false);
    return ResourceChatMessagePage(
      items: page,
      hasMore: safeStart + page.length < source.length,
    );
  }

  @override
  Future<ResourceChatMessage> sendMessage({
    required String expectedProfileId,
    required String chatId,
    required String body,
  }) async {
    calls.add('send:$chatId');
    sendCount++;
    lastSentBody = body;
    onSendAttempt?.call();
    if (sendDelay case final delay?) await delay;
    if (sendError case final error?) throw error;
    final sent = resourceChatMessageFixture(
      messageId:
          '00000000-0000-4000-8000-${sendCount.toString().padLeft(12, '0')}',
      chatId: chatId,
      senderProfileId: expectedProfileId,
      senderDisplayName: null,
      body: body,
      createdAt: DateTime.utc(2026, 9, 20, 12, sendCount),
    );
    histories.update(
      chatId,
      (messages) => [sent, ...messages],
      ifAbsent: () => [sent],
    );
    return sent;
  }

  @override
  ResourceChatSignalSubscription subscribeToSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ResourceChatSignal signal) onSignal,
    required void Function(ResourceChatConnectionStatus status) onStatus,
  }) {
    calls.add('subscribe:$chatId');
    final subscription = FakeResourceChatSubscription(
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      onSignal: onSignal,
      onStatus: onStatus,
      emitDisconnectedOnClose: emitDisconnectedOnClose,
    );
    subscriptions.add(subscription);
    return subscription;
  }

  void emitMessage(String chatId, {String? messageId}) {
    for (final item in subscriptions.where(
      (item) => item.chatId == chatId && !item.isClosed,
    )) {
      item.onSignal(
        ResourceChatMessageSentSignal(
          chatId: chatId,
          requestId: summary.requestId,
          messageId: messageId ?? '00000000-0000-4000-8000-000000000999',
          senderProfileId: summary.requesterProfileId,
          createdAt: DateTime.utc(2026, 9, 20, 12),
        ),
      );
    }
  }

  void emitExchange(String chatId) {
    for (final item in subscriptions.where(
      (item) => item.chatId == chatId && !item.isClosed,
    )) {
      item.onSignal(
        ResourceExchangeChangedSignal(
          chatId: chatId,
          requestId: summary.requestId,
          agreementId: summary.agreementId,
          agreementEventId: '00000000-0000-4000-8000-000000000998',
          termsId: null,
          createdAt: DateTime.utc(2026, 9, 20, 12),
        ),
      );
    }
  }

  void emitStatus(String chatId, ResourceChatConnectionStatus status) {
    for (final item in subscriptions.where(
      (item) => item.chatId == chatId && !item.isClosed,
    )) {
      item.onStatus(status);
    }
  }
}

class FakeResourceChatSubscription implements ResourceChatSignalSubscription {
  FakeResourceChatSubscription({
    required this.expectedProfileId,
    required this.chatId,
    required this.onSignal,
    required this.onStatus,
    required this.emitDisconnectedOnClose,
  });

  final String expectedProfileId;
  final String chatId;
  final void Function(ResourceChatSignal signal) onSignal;
  final void Function(ResourceChatConnectionStatus status) onStatus;
  final bool emitDisconnectedOnClose;
  bool isClosed = false;
  int closeCount = 0;

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    closeCount++;
    if (emitDisconnectedOnClose) {
      onStatus(ResourceChatConnectionStatus.disconnected);
    }
  }
}

ResourceChatSummary resourceChatSummaryFixture({
  String chatId = '00000000-0000-4000-8000-000000000401',
  ResourceChatViewerRole viewerRole = ResourceChatViewerRole.owner,
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  bool? hasSendEntitlement,
  String? lastMessageId = '00000000-0000-4000-8000-000000000901',
  String listingTitle = 'Garden tools',
}) {
  final closedAt = lifecycle.isClosed ? DateTime.utc(2026, 9, 20, 12) : null;
  final messageAt = lastMessageId == null
      ? null
      : DateTime.utc(2026, 9, 20, 11);
  return ResourceChatSummary(
    chatId: chatId,
    requestId: '00000000-0000-4000-8000-000000000301',
    agreementId: '00000000-0000-4000-8000-000000000501',
    listingId: '00000000-0000-4000-8000-000000000201',
    listingTitle: listingTitle,
    viewerRole: viewerRole,
    ownerProfileId: '00000000-0000-4000-8000-000000000101',
    ownerDisplayName: 'Casey',
    requesterProfileId: '00000000-0000-4000-8000-000000000102',
    requesterDisplayName: 'Jordan',
    agreementLifecycle: lifecycle,
    coordinationClosedAt: closedAt,
    hasSendEntitlement: hasSendEntitlement ?? !lifecycle.isClosed,
    activatedAt: DateTime.utc(2026, 9, 19, 10),
    activityAt: messageAt ?? DateTime.utc(2026, 9, 19, 10),
    lastVisibleMessageId: lastMessageId,
    lastVisibleMessageBody: lastMessageId == null ? null : 'When can we meet?',
    lastVisibleMessageAt: messageAt,
    lastVisibleSenderProfileId: lastMessageId == null
        ? null
        : '00000000-0000-4000-8000-000000000102',
    lastVisibleSenderDisplayName: lastMessageId == null ? null : 'Jordan',
  );
}

ResourceChatMessage resourceChatMessageFixture({
  String messageId = '00000000-0000-4000-8000-000000000901',
  String chatId = '00000000-0000-4000-8000-000000000401',
  String senderProfileId = '00000000-0000-4000-8000-000000000102',
  String? senderDisplayName = 'Jordan',
  String body = 'When can we meet?',
  DateTime? createdAt,
}) => ResourceChatMessage(
  messageId: messageId,
  chatId: chatId,
  senderProfileId: senderProfileId,
  senderDisplayName: senderDisplayName,
  body: body,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 20, 11),
);
