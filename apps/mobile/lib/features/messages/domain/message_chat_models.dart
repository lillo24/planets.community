import '../../participation/domain/participation_models.dart';
import '../../project_chat/domain/project_chat_models.dart';
import '../../resource_chat/domain/resource_chat_models.dart';

enum MessageChatItemKind {
  projectChat('project_chat'),
  resourceChat('resource_chat');

  const MessageChatItemKind(this.wireValue);

  final String wireValue;

  static MessageChatItemKind fromWire(String value) => switch (value) {
    'project_chat' => MessageChatItemKind.projectChat,
    'resource_chat' => MessageChatItemKind.resourceChat,
    _ => throw const FormatException('Unsupported unified chat kind.'),
  };
}

sealed class MessageChatItem {
  const MessageChatItem({
    required this.kind,
    required this.chatId,
    required this.activityAt,
    required this.displayTitle,
    required this.isReadOnly,
    required this.lastVisibleMessageId,
    required this.lastVisibleMessageBody,
    required this.lastVisibleMessageAt,
    required this.lastVisibleSenderProfileId,
    required this.lastVisibleSenderDisplayName,
  });

  final MessageChatItemKind kind;
  final String chatId;
  final DateTime activityAt;
  final String displayTitle;
  final bool isReadOnly;
  final String? lastVisibleMessageId;
  final String? lastVisibleMessageBody;
  final DateTime? lastVisibleMessageAt;
  final String? lastVisibleSenderProfileId;
  final String? lastVisibleSenderDisplayName;

  String get compositeId => '${kind.wireValue}:$chatId';
}

final class ProjectMessageChatItem extends MessageChatItem {
  const ProjectMessageChatItem({
    required super.chatId,
    required super.activityAt,
    required super.displayTitle,
    required super.isReadOnly,
    required super.lastVisibleMessageId,
    required super.lastVisibleMessageBody,
    required super.lastVisibleMessageAt,
    required super.lastVisibleSenderProfileId,
    required super.lastVisibleSenderDisplayName,
    required this.projectId,
    required this.projectKind,
    required this.viewerRole,
  }) : super(kind: MessageChatItemKind.projectChat);

  final String projectId;
  final ProjectKind projectKind;
  final ProjectChatViewerRole viewerRole;

  bool get isCreator => viewerRole == ProjectChatViewerRole.creator;
}

final class ResourceMessageChatItem extends MessageChatItem {
  const ResourceMessageChatItem({
    required super.chatId,
    required super.activityAt,
    required super.displayTitle,
    required super.isReadOnly,
    required super.lastVisibleMessageId,
    required super.lastVisibleMessageBody,
    required super.lastVisibleMessageAt,
    required super.lastVisibleSenderProfileId,
    required super.lastVisibleSenderDisplayName,
    required this.requestId,
    required this.agreementId,
    required this.listingId,
    required this.viewerRole,
    required this.agreementLifecycle,
    required this.coordinationClosedAt,
  }) : super(kind: MessageChatItemKind.resourceChat);

  final String requestId;
  final String agreementId;
  final String listingId;
  final ResourceChatViewerRole viewerRole;
  final ResourceExchangeLifecycle agreementLifecycle;
  final DateTime? coordinationClosedAt;
}

class MessageChatCursor {
  const MessageChatCursor({
    required this.activityAt,
    required this.itemKind,
    required this.chatId,
  });

  final DateTime activityAt;
  final MessageChatItemKind itemKind;
  final String chatId;
}

class MessageChatPage {
  const MessageChatPage({required this.items, required this.hasMore});

  final List<MessageChatItem> items;
  final bool hasMore;
}
