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

enum ProjectRequirementKind {
  skill('skill'),
  resource('resource');

  const ProjectRequirementKind(this.wireValue);

  final String wireValue;

  static ProjectRequirementKind fromWire(String value) => switch (value) {
    'skill' => ProjectRequirementKind.skill,
    'resource' => ProjectRequirementKind.resource,
    _ => throw const FormatException('Unsupported Project requirement kind.'),
  };
}

enum ProjectChatFeedItemKind {
  message('message', 1),
  requirementNeededAgain('system_requirement_needed_again', 0);

  const ProjectChatFeedItemKind(this.wireValue, this.canonicalOrder);

  final String wireValue;

  /// Backend tie order uses message before system in newest-first pages.
  final int canonicalOrder;

  static ProjectChatFeedItemKind fromWire(String value) => switch (value) {
    'message' => ProjectChatFeedItemKind.message,
    'system_requirement_needed_again' =>
      ProjectChatFeedItemKind.requirementNeededAgain,
    _ => throw const FormatException(
      'Unsupported Project chat feed item kind.',
    ),
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

sealed class ProjectChatFeedItem {
  const ProjectChatFeedItem({
    required this.itemId,
    required this.chatId,
    required this.createdAt,
  });

  final String itemId;
  final String chatId;
  final DateTime createdAt;
  ProjectChatFeedItemKind get itemKind;
  String get canonicalKey => '${itemKind.wireValue}:$itemId';
}

final class ProjectChatHumanMessage extends ProjectChatFeedItem {
  const ProjectChatHumanMessage({
    required super.itemId,
    required super.chatId,
    required this.senderProfileId,
    required this.senderDisplayName,
    required this.body,
    required super.createdAt,
  });

  final String senderProfileId;

  /// Null only for the authenticated sender's immediate send-RPC receipt.
  /// Mixed-feed rows always contain a strictly parsed display name.
  final String? senderDisplayName;
  final String body;

  @override
  ProjectChatFeedItemKind get itemKind => ProjectChatFeedItemKind.message;
}

final class ProjectChatRequirementNeededAgain extends ProjectChatFeedItem {
  const ProjectChatRequirementNeededAgain({
    required super.itemId,
    required super.chatId,
    required this.requirementKind,
    required this.requirementId,
    required this.requirementLabel,
    required super.createdAt,
  });

  final ProjectRequirementKind requirementKind;
  final String requirementId;
  final String requirementLabel;

  @override
  ProjectChatFeedItemKind get itemKind =>
      ProjectChatFeedItemKind.requirementNeededAgain;
}

class ProjectChatListCursor {
  const ProjectChatListCursor({required this.activityAt, required this.chatId});

  final DateTime activityAt;
  final String chatId;
}

class ProjectChatFeedCursor {
  const ProjectChatFeedCursor({
    required this.createdAt,
    required this.itemKind,
    required this.itemId,
  });

  final DateTime createdAt;
  final ProjectChatFeedItemKind itemKind;
  final String itemId;
}

class ProjectChatSummaryPage {
  const ProjectChatSummaryPage({required this.items, required this.hasMore});

  final List<ProjectChatSummary> items;
  final bool hasMore;
}

class ProjectChatFeedPage {
  const ProjectChatFeedPage({required this.items, required this.hasMore});

  /// Canonical backend order: newest first.
  final List<ProjectChatFeedItem> items;
  final bool hasMore;
}

sealed class ProjectChatSignal {
  const ProjectChatSignal({required this.chatId, required this.createdAt});

  final String chatId;
  final DateTime createdAt;
}

final class ProjectChatMessageSentSignal extends ProjectChatSignal {
  const ProjectChatMessageSentSignal({
    required super.chatId,
    required super.createdAt,
    required this.messageId,
  });

  final String messageId;
}

sealed class ProjectChatRequirementSignal extends ProjectChatSignal {
  const ProjectChatRequirementSignal({
    required super.chatId,
    required super.createdAt,
    required this.projectId,
    required this.requirementKind,
    required this.requirementId,
  });

  final String projectId;
  final ProjectRequirementKind requirementKind;
  final String requirementId;
}

final class ProjectChatRequirementNeededAgainSignal
    extends ProjectChatRequirementSignal {
  const ProjectChatRequirementNeededAgainSignal({
    required super.chatId,
    required super.createdAt,
    required super.projectId,
    required super.requirementKind,
    required super.requirementId,
    required this.systemEventId,
  });

  final String systemEventId;
}

final class ProjectChatRequirementCoveredSignal
    extends ProjectChatRequirementSignal {
  const ProjectChatRequirementCoveredSignal({
    required super.chatId,
    required super.createdAt,
    required super.projectId,
    required super.requirementKind,
    required super.requirementId,
  });
}

enum ProjectChatConnectionStatus { connected, disconnected }
