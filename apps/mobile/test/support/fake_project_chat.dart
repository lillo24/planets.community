import 'dart:async';

import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';

class FakeProjectChatGateway implements ProjectChatGateway {
  List<ProjectChatSummary> summaries = [];
  final Map<String, List<ProjectChatMessage>> histories = {};
  final List<String> calls = [];
  final List<FakeProjectChatSubscription> subscriptions = [];
  Future<void>? listDelay;
  Future<void>? historyDelay;
  Future<void>? sendDelay;
  Object? listError;
  Object? historyError;
  Object? sendError;
  ProjectChatListCursor? lastListCursor;
  ProjectChatMessageCursor? lastMessageCursor;
  String? lastExpectedProfileId;
  String? lastSentBody;

  @override
  Future<ProjectChatSummaryPage> listOwnProjectChats({
    required String expectedProfileId,
    required int limit,
    ProjectChatListCursor? cursor,
  }) async {
    calls.add('list');
    lastExpectedProfileId = expectedProfileId;
    lastListCursor = cursor;
    if (listDelay case final delay?) await delay;
    if (listError case final error?) throw error;
    final start = cursor == null
        ? 0
        : summaries.indexWhere((item) => item.chatId == cursor.chatId) + 1;
    final safeStart = start < 0 ? 0 : start;
    final page = summaries.skip(safeStart).take(limit).toList(growable: false);
    return ProjectChatSummaryPage(
      items: page,
      hasMore: safeStart + page.length < summaries.length,
    );
  }

  @override
  Future<ProjectChatMessagePage> listOwnProjectChatMessages({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ProjectChatMessageCursor? cursor,
  }) async {
    calls.add('history:$chatId');
    lastExpectedProfileId = expectedProfileId;
    lastMessageCursor = cursor;
    if (historyDelay case final delay?) await delay;
    if (historyError case final error?) throw error;
    final source = histories[chatId] ?? const [];
    final start = cursor == null
        ? 0
        : source.indexWhere((item) => item.messageId == cursor.messageId) + 1;
    final safeStart = start < 0 ? 0 : start;
    final page = source.skip(safeStart).take(limit).toList(growable: false);
    return ProjectChatMessagePage(
      items: page,
      hasMore: safeStart + page.length < source.length,
    );
  }

  @override
  Future<ProjectChatMessage> sendProjectChatMessage({
    required String expectedProfileId,
    required String chatId,
    required String body,
  }) async {
    calls.add('send:$chatId');
    lastExpectedProfileId = expectedProfileId;
    lastSentBody = body;
    if (sendDelay case final delay?) await delay;
    if (sendError case final error?) throw error;
    final sent = projectChatMessageFixture(
      messageId:
          'sent-${calls.where((call) => call.startsWith('send:')).length}',
      chatId: chatId,
      senderProfileId: expectedProfileId,
      senderDisplayName: null,
      body: body,
      createdAt: DateTime.utc(2026, 9, 14, 12),
    );
    histories.update(
      chatId,
      (messages) => [sent, ...messages],
      ifAbsent: () => [sent],
    );
    return sent;
  }

  @override
  ProjectChatSignalSubscription subscribeToProjectChatSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ProjectChatSignal signal) onSignal,
    required void Function(ProjectChatConnectionStatus status) onStatus,
  }) {
    calls.add('subscribe:$chatId');
    final subscription = FakeProjectChatSubscription(
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      onSignal: onSignal,
      onStatus: onStatus,
    );
    subscriptions.add(subscription);
    return subscription;
  }

  void emitSignal(String chatId, {String messageId = 'signal-message'}) {
    for (final subscription in subscriptions.where(
      (item) => item.chatId == chatId && !item.isClosed,
    )) {
      subscription.onSignal(
        ProjectChatSignal(
          chatId: chatId,
          messageId: messageId,
          createdAt: DateTime.utc(2026, 9, 14, 12),
        ),
      );
    }
  }

  void emitStatus(String chatId, ProjectChatConnectionStatus status) {
    for (final subscription in subscriptions.where(
      (item) => item.chatId == chatId && !item.isClosed,
    )) {
      subscription.onStatus(status);
    }
  }
}

class FakeProjectChatSubscription implements ProjectChatSignalSubscription {
  FakeProjectChatSubscription({
    required this.expectedProfileId,
    required this.chatId,
    required this.onSignal,
    required this.onStatus,
  });

  final String expectedProfileId;
  final String chatId;
  final void Function(ProjectChatSignal signal) onSignal;
  final void Function(ProjectChatConnectionStatus status) onStatus;
  bool isClosed = false;

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

ProjectChatSummary projectChatSummaryFixture({
  String chatId = 'chat-1',
  String projectId = 'proposal-1',
  ProjectKind projectKind = ProjectKind.oneTime,
  String projectTitle = 'Paint the square',
  ProjectChatViewerRole viewerRole = ProjectChatViewerRole.currentMember,
  bool? hasCurrentEntitlement,
  bool hasHistoryEntitlement = true,
  DateTime? activatedAt,
  String? lastVisibleMessageId = 'message-1',
  String? lastVisibleMessageBody = 'Bring a small brush.',
  DateTime? lastVisibleMessageAt,
  String? lastVisibleSenderProfileId = 'user-2',
  String? lastVisibleSenderDisplayName = 'Jordan',
  DateTime? activityAt,
}) {
  final activated = activatedAt ?? DateTime.utc(2026, 9, 10, 10);
  final messageAt = lastVisibleMessageId == null
      ? null
      : lastVisibleMessageAt ?? DateTime.utc(2026, 9, 14, 10);
  return ProjectChatSummary(
    chatId: chatId,
    projectId: projectId,
    projectKind: projectKind,
    projectTitle: projectTitle,
    viewerRole: viewerRole,
    hasCurrentEntitlement:
        hasCurrentEntitlement ??
        viewerRole != ProjectChatViewerRole.formerMember,
    hasHistoryEntitlement: hasHistoryEntitlement,
    activatedAt: activated,
    lastVisibleMessageId: lastVisibleMessageId,
    lastVisibleMessageBody: lastVisibleMessageId == null
        ? null
        : lastVisibleMessageBody,
    lastVisibleMessageAt: messageAt,
    lastVisibleSenderProfileId: lastVisibleMessageId == null
        ? null
        : lastVisibleSenderProfileId,
    lastVisibleSenderDisplayName: lastVisibleMessageId == null
        ? null
        : lastVisibleSenderDisplayName,
    activityAt: activityAt ?? messageAt ?? activated,
  );
}

ProjectChatMessage projectChatMessageFixture({
  String messageId = 'message-1',
  String chatId = 'chat-1',
  String senderProfileId = 'user-2',
  String? senderDisplayName = 'Jordan',
  String body = 'Bring a small brush.',
  DateTime? createdAt,
}) => ProjectChatMessage(
  messageId: messageId,
  chatId: chatId,
  senderProfileId: senderProfileId,
  senderDisplayName: senderDisplayName,
  body: body,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 14, 10),
);
