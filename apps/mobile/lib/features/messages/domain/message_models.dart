import '../../participation/domain/participation_models.dart';

enum MessageViewerRole {
  requester('requester'),
  creator('creator');

  const MessageViewerRole(this.wireValue);

  final String wireValue;

  static MessageViewerRole fromWire(String value) => switch (value) {
    'requester' => MessageViewerRole.requester,
    'creator' => MessageViewerRole.creator,
    _ => throw const FormatException('Unsupported message viewer role.'),
  };
}

enum RequestContributionSelectionKind {
  skill('skill'),
  resource('resource');

  const RequestContributionSelectionKind(this.wireValue);

  final String wireValue;

  static RequestContributionSelectionKind fromWire(String value) =>
      switch (value) {
        'skill' => RequestContributionSelectionKind.skill,
        'resource' => RequestContributionSelectionKind.resource,
        _ => throw const FormatException(
          'Unsupported request contribution-selection kind.',
        ),
      };
}

class RequestContributionSelection {
  const RequestContributionSelection({
    required this.kind,
    required this.id,
    required this.label,
  });

  final RequestContributionSelectionKind kind;
  final String id;
  final String label;
}

class ParticipationRequestMessageItem {
  const ParticipationRequestMessageItem({
    required this.requestId,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required this.viewerRole,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required this.creatorProfileId,
    required this.creatorDisplayName,
    required this.requestMessage,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
    required this.activityAt,
  });

  final String requestId;
  final String projectId;
  final ProjectKind projectKind;
  final String projectTitle;
  final MessageViewerRole viewerRole;
  final String requesterProfileId;
  final String requesterDisplayName;
  final String creatorProfileId;
  final String creatorDisplayName;
  final String? requestMessage;
  final JoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime activityAt;

  bool get isPending => status == JoinRequestStatus.pending;
}

class MessageCursor {
  const MessageCursor({required this.activityAt, required this.requestId});

  final DateTime activityAt;
  final String requestId;
}

class ParticipationRequestMessagePage {
  const ParticipationRequestMessagePage({
    required this.items,
    required this.hasMore,
  });

  final List<ParticipationRequestMessageItem> items;
  final bool hasMore;
}
