import '../../participation/domain/participation_models.dart';

const projectChatMessageMaxLength = 4000;

enum ProjectChatViewerRole {
  creator('creator'),
  currentMember('current_member'),
  formerMember('former_member');

  const ProjectChatViewerRole(this.wireValue);

  final String wireValue;

  static ProjectChatViewerRole fromWire(String value) => switch (value) {
    'creator' => ProjectChatViewerRole.creator,
    'current_member' => ProjectChatViewerRole.currentMember,
    'former_member' => ProjectChatViewerRole.formerMember,
    _ => throw const FormatException('Unsupported Project chat viewer role.'),
  };
}

class ProjectChatSummary {
  const ProjectChatSummary({
    required this.chatId,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required this.viewerRole,
    required this.hasCurrentEntitlement,
    required this.hasHistoryEntitlement,
    required this.activatedAt,
    required this.lastVisibleMessageId,
    required this.lastVisibleMessageBody,
    required this.lastVisibleMessageAt,
    required this.lastVisibleSenderProfileId,
    required this.lastVisibleSenderDisplayName,
    required this.activityAt,
  });

  final String chatId;
  final String projectId;
  final ProjectKind projectKind;
  final String projectTitle;
  final ProjectChatViewerRole viewerRole;
  final bool hasCurrentEntitlement;
  final bool hasHistoryEntitlement;
  final DateTime activatedAt;
  final String? lastVisibleMessageId;
  final String? lastVisibleMessageBody;
  final DateTime? lastVisibleMessageAt;
  final String? lastVisibleSenderProfileId;
  final String? lastVisibleSenderDisplayName;
  final DateTime activityAt;

  bool get isCreator => viewerRole == ProjectChatViewerRole.creator;
  bool get isReadOnly => !hasCurrentEntitlement;
}

class ProjectChatMessage {
  const ProjectChatMessage({
    required this.messageId,
    required this.chatId,
    required this.senderProfileId,
    required this.senderDisplayName,
    required this.body,
    required this.createdAt,
  });

  final String messageId;
  final String chatId;
  final String senderProfileId;

  /// Null only for the authenticated sender's immediate send-RPC receipt.
  /// History RPC rows always contain a strictly parsed display name.
  final String? senderDisplayName;
  final String body;
  final DateTime createdAt;
}

class ProjectChatListCursor {
  const ProjectChatListCursor({required this.activityAt, required this.chatId});

  final DateTime activityAt;
  final String chatId;
}

class ProjectChatMessageCursor {
  const ProjectChatMessageCursor({
    required this.createdAt,
    required this.messageId,
  });

  final DateTime createdAt;
  final String messageId;
}

class ProjectChatSummaryPage {
  const ProjectChatSummaryPage({required this.items, required this.hasMore});

  final List<ProjectChatSummary> items;
  final bool hasMore;
}

class ProjectChatMessagePage {
  const ProjectChatMessagePage({required this.items, required this.hasMore});

  /// Canonical backend order: newest first.
  final List<ProjectChatMessage> items;
  final bool hasMore;
}

class ProjectChatSignal {
  const ProjectChatSignal({
    required this.chatId,
    required this.messageId,
    required this.createdAt,
  });

  final String chatId;
  final String messageId;
  final DateTime createdAt;
}

enum ProjectChatConnectionStatus { connected, disconnected }
