import '../../participation/domain/participation_models.dart';
import '../../project_chat/domain/project_chat_models.dart';
import '../../resource_chat/domain/resource_chat_models.dart';

enum MessageChatItemKind {
  projectChat('project_chat'),
  resourceChat('resource_chat'),
  projectRequestChat('project_request_chat');

  const MessageChatItemKind(this.wireValue);

  final String wireValue;

  static MessageChatItemKind fromWire(String value) => switch (value) {
    'project_chat' => MessageChatItemKind.projectChat,
    'resource_chat' => MessageChatItemKind.resourceChat,
    'project_request_chat' => MessageChatItemKind.projectRequestChat,
    _ => throw const FormatException('Unsupported unified chat kind.'),
  };
}

enum MessageChatScope {
  private('private'),
  groups('groups');

  const MessageChatScope(this.wireValue);

  final String wireValue;
}

enum ProjectRequestChatViewerRole {
  requester('requester'),
  creator('creator'),
  delegate('delegate');

  const ProjectRequestChatViewerRole(this.wireValue);

  final String wireValue;

  static ProjectRequestChatViewerRole fromWire(String value) => switch (value) {
    'requester' => ProjectRequestChatViewerRole.requester,
    'creator' => ProjectRequestChatViewerRole.creator,
    'delegate' => ProjectRequestChatViewerRole.delegate,
    _ => throw const FormatException(
      'Unsupported participation-request chat viewer role.',
    ),
  };
}

sealed class MessageChatItem {
  const MessageChatItem({
    this.unreadCount = 0,
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

  final int unreadCount;
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
    super.unreadCount,
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
  bool get isDelegate => viewerRole == ProjectChatViewerRole.delegate;
  bool get isManager =>
      viewerRole == ProjectChatViewerRole.creator ||
      viewerRole == ProjectChatViewerRole.delegate;
}

final class ResourceMessageChatItem extends MessageChatItem {
  const ResourceMessageChatItem({
    super.unreadCount,
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
    required this.counterpartyProfileId,
    required this.counterpartyDisplayName,
    required this.viewerRole,
    required this.agreementLifecycle,
    required this.coordinationClosedAt,
  }) : super(kind: MessageChatItemKind.resourceChat);

  final String requestId;
  final String agreementId;
  final String listingId;
  final String counterpartyProfileId;
  final String counterpartyDisplayName;
  final ResourceChatViewerRole viewerRole;
  final ResourceExchangeLifecycle agreementLifecycle;
  final DateTime? coordinationClosedAt;
}

final class ProjectRequestMessageChatItem extends MessageChatItem {
  const ProjectRequestMessageChatItem({
    super.unreadCount,
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
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required this.counterpartyProfileId,
    required this.counterpartyDisplayName,
    required this.viewerRole,
    required this.requestStatus,
    required this.requestMessage,
    required this.resolvedAt,
    required this.acceptedProjectGroupChatId,
    this.pendingCount = 0,
  }) : super(kind: MessageChatItemKind.projectRequestChat);

  final String requestId;
  final String projectId;
  final ProjectKind projectKind;
  final String projectTitle;
  final String counterpartyProfileId;
  final String counterpartyDisplayName;
  final ProjectRequestChatViewerRole viewerRole;
  final JoinRequestStatus requestStatus;
  final String? requestMessage;
  final DateTime? resolvedAt;
  final String? acceptedProjectGroupChatId;

  /// Canonical total across the pair; request fields above are route context.
  final int pendingCount;

  String? get previewBody => lastVisibleMessageBody ?? requestMessage;
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
