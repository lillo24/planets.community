import '../../participation/domain/participation_models.dart';

const projectRequestChatMessageMaxLength = 4000;

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

class ProjectRequestChatSummary {
  const ProjectRequestChatSummary({
    required this.chatId,
    required this.requestId,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required this.viewerRole,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required this.creatorProfileId,
    required this.creatorDisplayName,
    required this.requestStatus,
    required this.requestMessage,
    required this.requestCreatedAt,
    required this.resolvedAt,
    required this.activatedAt,
    required this.isReadOnly,
    required this.hasSendEntitlement,
    required this.acceptedProjectGroupChatId,
    this.pendingCount = 0,
    this.pendingRequests = const [],
  });

  final String chatId;
  final String requestId;
  final String projectId;
  final ProjectKind projectKind;
  final String projectTitle;
  final ProjectRequestChatViewerRole viewerRole;
  final String requesterProfileId;
  final String requesterDisplayName;
  final String creatorProfileId;
  final String creatorDisplayName;
  final JoinRequestStatus requestStatus;
  final String? requestMessage;
  final DateTime requestCreatedAt;
  final DateTime? resolvedAt;
  final DateTime activatedAt;
  final bool isReadOnly;
  final bool hasSendEntitlement;
  final int pendingCount;
  final List<ProjectRequestChatRequestItem> pendingRequests;
  final String? acceptedProjectGroupChatId;

  String get counterpartyDisplayName =>
      viewerRole == ProjectRequestChatViewerRole.requester
      ? creatorDisplayName
      : requesterDisplayName;

  String get counterpartyProfileId =>
      viewerRole == ProjectRequestChatViewerRole.requester
      ? creatorProfileId
      : requesterProfileId;
}

enum ProjectRequestChatFeedItemKind {
  request('request', 0),
  legacyMessage('legacy_message', 1),
  message('message', 2);

  const ProjectRequestChatFeedItemKind(this.wireValue, this.canonicalOrder);

  final String wireValue;
  final int canonicalOrder;

  static ProjectRequestChatFeedItemKind fromWire(String value) =>
      switch (value) {
        'request' => ProjectRequestChatFeedItemKind.request,
        'message' => ProjectRequestChatFeedItemKind.message,
        'legacy_message' => ProjectRequestChatFeedItemKind.legacyMessage,
        _ => throw const FormatException(
          'Unsupported participation-request chat feed item kind.',
        ),
      };
}

sealed class ProjectRequestChatFeedItem {
  const ProjectRequestChatFeedItem({
    required this.itemId,
    required this.chatId,
    required this.requestId,
    required this.createdAt,
  });

  final String itemId;
  final String chatId;
  final String? requestId;
  final DateTime createdAt;
  ProjectRequestChatFeedItemKind get itemKind;
  String get canonicalKey => '${itemKind.wireValue}:$itemId';
}

final class ProjectRequestChatRequestItem extends ProjectRequestChatFeedItem {
  const ProjectRequestChatRequestItem({
    required super.itemId,
    required super.chatId,
    required super.requestId,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required this.requestStatus,
    required this.requestMessage,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    this.resolvedAt,
    this.acceptedProjectGroupChatId,
    required super.createdAt,
  });

  final String projectId;
  final ProjectKind projectKind;
  final String projectTitle;
  final JoinRequestStatus requestStatus;
  final String? requestMessage;
  final String requesterProfileId;
  final String requesterDisplayName;
  final DateTime? resolvedAt;
  final String? acceptedProjectGroupChatId;

  @override
  String get requestId => super.requestId!;

  @override
  ProjectRequestChatFeedItemKind get itemKind =>
      ProjectRequestChatFeedItemKind.request;
}

final class ProjectRequestChatHumanMessage extends ProjectRequestChatFeedItem {
  const ProjectRequestChatHumanMessage({
    required super.itemId,
    required super.chatId,
    required super.requestId,
    required this.senderProfileId,
    required this.senderDisplayName,
    required this.body,
    this.isLegacy = false,
    required super.createdAt,
  });

  final String senderProfileId;
  final String? senderDisplayName;
  final String body;
  final bool isLegacy;

  @override
  ProjectRequestChatFeedItemKind get itemKind => isLegacy
      ? ProjectRequestChatFeedItemKind.legacyMessage
      : ProjectRequestChatFeedItemKind.message;
}

class ProjectRequestChatFeedCursor {
  const ProjectRequestChatFeedCursor({
    required this.createdAt,
    required this.itemKind,
    required this.itemId,
  });

  final DateTime createdAt;
  final ProjectRequestChatFeedItemKind itemKind;
  final String itemId;
}

class ProjectRequestChatFeedPage {
  const ProjectRequestChatFeedPage({
    this.readBoundary,
    required this.items,
    required this.hasMore,
  });

  final List<ProjectRequestChatFeedItem> items;
  final bool hasMore;
  final String? readBoundary;
}

class ProjectRequestChatMessageSentSignal {
  const ProjectRequestChatMessageSentSignal({
    required this.chatId,
    this.requestId,
    this.messageId,
    this.createdAt,
  });

  final String chatId;
  final String? requestId;
  final String? messageId;
  final DateTime? createdAt;
}

enum ProjectRequestChatConnectionStatus { connected, disconnected }
