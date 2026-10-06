import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';

class FakeMessageChatsGateway implements MessageChatsGateway {
  List<MessageChatItem> items = [];
  Object? error;
  Future<void>? delay;
  final List<String> calls = [];
  MessageChatCursor? lastCursor;
  MessageChatScope? lastScope;

  @override
  Future<MessageChatPage> listItems({
    required String expectedProfileId,
    required MessageChatScope scope,
    required int limit,
    MessageChatCursor? cursor,
  }) async {
    calls.add('list');
    lastScope = scope;
    lastCursor = cursor;
    if (delay case final wait?) await wait;
    if (error case final value?) throw value;
    final scopedItems = items
        .where(
          (item) => switch (scope) {
            MessageChatScope.private =>
              item.kind != MessageChatItemKind.projectChat,
            MessageChatScope.groups =>
              item.kind == MessageChatItemKind.projectChat,
          },
        )
        .toList(growable: false);
    final start = cursor == null
        ? 0
        : scopedItems.indexWhere(
                (item) =>
                    item.kind == cursor.itemKind &&
                    item.chatId == cursor.chatId,
              ) +
              1;
    final safeStart = start < 0 ? 0 : start;
    final page = scopedItems
        .skip(safeStart)
        .take(limit)
        .toList(growable: false);
    return MessageChatPage(
      items: page,
      hasMore: safeStart + page.length < scopedItems.length,
    );
  }
}

ProjectRequestMessageChatItem projectRequestMessageChatFixture({
  String chatId = '00000000-0000-4000-8000-000000000411',
  String requestId = '00000000-0000-4000-8000-000000000311',
  String projectId = '00000000-0000-4000-8000-000000000711',
  String projectTitle = 'Riverside mural',
  String counterpartyProfileId = '00000000-0000-4000-8000-000000000102',
  String counterpartyDisplayName = 'Bob',
  ProjectRequestChatViewerRole viewerRole =
      ProjectRequestChatViewerRole.creator,
  JoinRequestStatus status = JoinRequestStatus.pending,
  String? messageId = '00000000-0000-4000-8000-000000000911',
  String? messageBody = 'Yes, Sunday works for me.',
  DateTime? activityAt,
}) {
  final messageAt = messageId == null ? null : DateTime.utc(2026, 9, 20, 12);
  final resolved = status == JoinRequestStatus.pending
      ? null
      : DateTime.utc(2026, 9, 20, 13);
  return ProjectRequestMessageChatItem(
    chatId: chatId,
    activityAt:
        activityAt ?? resolved ?? messageAt ?? DateTime.utc(2026, 9, 19, 12),
    displayTitle: counterpartyDisplayName,
    isReadOnly: status != JoinRequestStatus.pending,
    lastVisibleMessageId: messageId,
    lastVisibleMessageBody: messageId == null ? null : messageBody,
    lastVisibleMessageAt: messageAt,
    lastVisibleSenderProfileId: messageId == null
        ? null
        : '00000000-0000-4000-8000-000000000102',
    lastVisibleSenderDisplayName: messageId == null ? null : 'Bob',
    requestId: requestId,
    projectId: projectId,
    projectKind: ProjectKind.oneTime,
    projectTitle: projectTitle,
    counterpartyProfileId: counterpartyProfileId,
    counterpartyDisplayName: counterpartyDisplayName,
    viewerRole: viewerRole,
    requestStatus: status,
    pendingCount: status == JoinRequestStatus.pending ? 1 : 0,
    requestMessage: 'I can help Sunday afternoon.',
    resolvedAt: resolved,
    acceptedProjectGroupChatId: status == JoinRequestStatus.accepted
        ? '00000000-0000-4000-8000-000000000601'
        : null,
  );
}

ProjectMessageChatItem projectMessageChatFixture({
  String chatId = '00000000-0000-4000-8000-000000000601',
  String projectId = '00000000-0000-4000-8000-000000000701',
  String title = 'Paint the square',
  ProjectKind projectKind = ProjectKind.oneTime,
  ProjectChatViewerRole viewerRole = ProjectChatViewerRole.currentMember,
  bool isReadOnly = false,
  String? messageId = '00000000-0000-4000-8000-000000000801',
  String? messageBody = 'Bring a small brush.',
  DateTime? activityAt,
}) {
  final messageAt = messageId == null ? null : DateTime.utc(2026, 9, 20, 10);
  return ProjectMessageChatItem(
    chatId: chatId,
    activityAt: activityAt ?? messageAt ?? DateTime.utc(2026, 9, 19, 10),
    displayTitle: title,
    viewerRole: viewerRole,
    isReadOnly: isReadOnly,
    lastVisibleMessageId: messageId,
    lastVisibleMessageBody: messageId == null ? null : messageBody,
    lastVisibleMessageAt: messageAt,
    lastVisibleSenderProfileId: messageId == null
        ? null
        : '00000000-0000-4000-8000-000000000102',
    lastVisibleSenderDisplayName: messageId == null ? null : 'Jordan',
    projectId: projectId,
    projectKind: projectKind,
  );
}

ResourceMessageChatItem resourceMessageChatFixture({
  String chatId = '00000000-0000-4000-8000-000000000401',
  String requestId = '00000000-0000-4000-8000-000000000301',
  String agreementId = '00000000-0000-4000-8000-000000000501',
  String listingId = '00000000-0000-4000-8000-000000000201',
  String title = 'Garden tools',
  String counterpartyProfileId = '00000000-0000-4000-8000-000000000102',
  String counterpartyDisplayName = 'Jordan',
  ResourceChatViewerRole viewerRole = ResourceChatViewerRole.owner,
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  bool isReadOnly = false,
  String? messageId = '00000000-0000-4000-8000-000000000901',
  String? messageBody = 'When can we meet?',
  DateTime? activityAt,
}) {
  final messageAt = messageId == null ? null : DateTime.utc(2026, 9, 20, 11);
  return ResourceMessageChatItem(
    chatId: chatId,
    activityAt: activityAt ?? messageAt ?? DateTime.utc(2026, 9, 19, 11),
    displayTitle: title,
    viewerRole: viewerRole,
    isReadOnly: isReadOnly,
    lastVisibleMessageId: messageId,
    lastVisibleMessageBody: messageId == null ? null : messageBody,
    lastVisibleMessageAt: messageAt,
    lastVisibleSenderProfileId: messageId == null
        ? null
        : '00000000-0000-4000-8000-000000000102',
    lastVisibleSenderDisplayName: messageId == null ? null : 'Jordan',
    requestId: requestId,
    agreementId: agreementId,
    listingId: listingId,
    counterpartyProfileId: counterpartyProfileId,
    counterpartyDisplayName: counterpartyDisplayName,
    agreementLifecycle: lifecycle,
    coordinationClosedAt: lifecycle.isClosed
        ? DateTime.utc(2026, 9, 20, 12)
        : null,
  );
}
