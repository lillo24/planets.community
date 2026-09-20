import '../../participation/domain/participation_models.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../../resource_requests/domain/resource_request_models.dart';

enum StructuredRequestItemKind {
  participationRequest('participation_request'),
  resourceRequest('resource_request');

  const StructuredRequestItemKind(this.wireValue);

  final String wireValue;

  static StructuredRequestItemKind fromWire(String value) => switch (value) {
    'participation_request' => StructuredRequestItemKind.participationRequest,
    'resource_request' => StructuredRequestItemKind.resourceRequest,
    _ => throw const FormatException('Unsupported structured request kind.'),
  };
}

enum MessageViewerRole {
  requester('requester'),
  creator('creator'),
  owner('owner');

  const MessageViewerRole(this.wireValue);

  final String wireValue;

  static MessageViewerRole fromWire(String value) => switch (value) {
    'requester' => MessageViewerRole.requester,
    'creator' => MessageViewerRole.creator,
    'owner' => MessageViewerRole.owner,
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

sealed class StructuredRequestMessageItem {
  const StructuredRequestMessageItem({
    required this.kind,
    required this.requestId,
    required this.viewerRole,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required this.requestMessage,
    required this.createdAt,
    required this.resolvedAt,
    required this.activityAt,
  });

  final StructuredRequestItemKind kind;
  final String requestId;
  final MessageViewerRole viewerRole;
  final String requesterProfileId;
  final String requesterDisplayName;
  final String? requestMessage;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime activityAt;

  String get compositeId => '${kind.wireValue}:$requestId';
}

class ParticipationRequestMessageItem extends StructuredRequestMessageItem {
  const ParticipationRequestMessageItem({
    required super.requestId,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required super.viewerRole,
    required super.requesterProfileId,
    required super.requesterDisplayName,
    required this.creatorProfileId,
    required this.creatorDisplayName,
    required super.requestMessage,
    required this.status,
    required super.createdAt,
    required super.resolvedAt,
    required super.activityAt,
  }) : super(kind: StructuredRequestItemKind.participationRequest);

  final String projectId;
  final ProjectKind projectKind;
  final String projectTitle;
  final String creatorProfileId;
  final String creatorDisplayName;
  final JoinRequestStatus status;

  bool get isPending => status == JoinRequestStatus.pending;
}

class ResourceRequestMessageItem extends StructuredRequestMessageItem {
  const ResourceRequestMessageItem({
    required super.requestId,
    required super.viewerRole,
    required super.requesterProfileId,
    required super.requesterDisplayName,
    required super.requestMessage,
    required super.createdAt,
    required super.resolvedAt,
    required super.activityAt,
    required this.listingId,
    required this.listingMode,
    required this.listingTitle,
    required this.listingLifecycle,
    required this.ownerProfileId,
    required this.ownerDisplayName,
    required this.status,
    required this.chatId,
    required this.agreementId,
    required this.coordinationClosedAt,
  }) : super(kind: StructuredRequestItemKind.resourceRequest);

  final String listingId;
  final ResourceListingMode listingMode;
  final String listingTitle;
  final ResourceListingLifecycle listingLifecycle;
  final String ownerProfileId;
  final String ownerDisplayName;
  final ResourceRequestStatus status;
  final String? chatId;
  final String? agreementId;
  final DateTime? coordinationClosedAt;

  bool get isPending => status == ResourceRequestStatus.pending;
  bool get isCoordinationOpen =>
      status == ResourceRequestStatus.accepted && coordinationClosedAt == null;
}

class MessageCursor {
  const MessageCursor({
    required this.activityAt,
    required this.itemKind,
    required this.requestId,
  });

  final DateTime activityAt;
  final StructuredRequestItemKind itemKind;
  final String requestId;
}

class StructuredRequestMessagePage {
  const StructuredRequestMessagePage({
    required this.items,
    required this.hasMore,
  });

  final List<StructuredRequestMessageItem> items;
  final bool hasMore;
}
