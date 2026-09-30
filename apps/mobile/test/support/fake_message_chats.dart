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

  @override
  Future<MessageChatPage> listItems({
    required String expectedProfileId,
    required int limit,
    MessageChatCursor? cursor,
  }) async {
    calls.add('list');
    lastCursor = cursor;
    if (delay case final wait?) await wait;
    if (error case final value?) throw value;
    final start = cursor == null
        ? 0
        : items.indexWhere(
                (item) =>
                    item.kind == cursor.itemKind &&
                    item.chatId == cursor.chatId,
              ) +
              1;
    final safeStart = start < 0 ? 0 : start;
    final page = items.skip(safeStart).take(limit).toList(growable: false);
    return MessageChatPage(
      items: page,
      hasMore: safeStart + page.length < items.length,
    );
  }
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
    agreementLifecycle: lifecycle,
    coordinationClosedAt: lifecycle.isClosed
        ? DateTime.utc(2026, 9, 20, 12)
        : null,
  );
}
