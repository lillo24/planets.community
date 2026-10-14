import '../../participation/domain/participation_models.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../../resource_requests/domain/resource_request_models.dart';
import '../../group_contact/domain/group_contact_models.dart';

enum StructuredRequestItemKind {
  participationRequest('participation_request'),
  resourceRequest('resource_request'),
  groupContactRequest('group_contact_request');

  const StructuredRequestItemKind(this.wireValue);

  final String wireValue;

  static StructuredRequestItemKind fromWire(String value) => switch (value) {
    'participation_request' => StructuredRequestItemKind.participationRequest,
    'resource_request' => StructuredRequestItemKind.resourceRequest,
    'group_contact_request' => StructuredRequestItemKind.groupContactRequest,
    _ => throw const FormatException('Unsupported structured request kind.'),
  };
}

enum MessageViewerRole {
  requester('requester'),
  creator('creator'),
  delegate('delegate'),
  owner('owner');

  const MessageViewerRole(this.wireValue);

  final String wireValue;

  static MessageViewerRole fromWire(String value) => switch (value) {
    'requester' => MessageViewerRole.requester,
    'creator' => MessageViewerRole.creator,
    'delegate' => MessageViewerRole.delegate,
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
  // D's resolved triage/own recovery may intentionally omit personal identity.
  // Legacy concrete variants keep their required non-null identity contract.
  final String? requesterProfileId;
  final String? requesterDisplayName;
  final String? requestMessage;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime activityAt;

  Object get refreshValue => (
    (
      kind,
      requestId,
      viewerRole,
      requesterProfileId,
      requesterDisplayName,
      requestMessage,
      createdAt,
      resolvedAt,
      activityAt,
    ),
    switch (this) {
      ParticipationRequestMessageItem item => (
        item.projectId,
        item.projectKind,
        item.projectTitle,
        item.creatorProfileId,
        item.creatorDisplayName,
        item.status,
      ),
      ResourceRequestMessageItem item => (
        item.listingId,
        item.listingMode,
        item.listingTitle,
        item.listingLifecycle,
        item.ownerProfileId,
        item.ownerDisplayName,
        item.status,
        item.chatId,
        item.agreementId,
        item.coordinationClosedAt,
      ),
      GroupContactRequestMessageItem item => (
        item.contact.status,
        item.contact.title,
        item.contact.purpose,
        item.contact.sourceGroupId,
        item.contact.targetGroupId,
        item.contact.sourceGroupName,
        item.contact.targetGroupName,
        item.contact.chatId,
        item.contact.canReview,
        item.contact.canWithdraw,
        item.contact.publicProjectId,
        item.contact.publicProjectKind,
        item.contact.publicProjectTitle,
      ),
    },
  );
  String get compositeId => '${kind.wireValue}:$requestId';
}

class ParticipationRequestMessageItem extends StructuredRequestMessageItem {
  const ParticipationRequestMessageItem({
    required super.requestId,
    required this.projectId,
    required this.projectKind,
    required this.projectTitle,
    required super.viewerRole,
    required String requesterProfileId,
    required String requesterDisplayName,
    required this.creatorProfileId,
    required this.creatorDisplayName,
    required super.requestMessage,
    required this.status,
    required super.createdAt,
    required super.resolvedAt,
    required super.activityAt,
  }) : super(
         kind: StructuredRequestItemKind.participationRequest,
         requesterProfileId: requesterProfileId,
         requesterDisplayName: requesterDisplayName,
       );

  @override
  String get requesterProfileId => super.requesterProfileId!;
  @override
  String get requesterDisplayName => super.requesterDisplayName!;

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
    required String requesterProfileId,
    required String requesterDisplayName,
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
  }) : super(
         kind: StructuredRequestItemKind.resourceRequest,
         requesterProfileId: requesterProfileId,
         requesterDisplayName: requesterDisplayName,
       );

  @override
  String get requesterProfileId => super.requesterProfileId!;
  @override
  String get requesterDisplayName => super.requesterDisplayName!;

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

final class GroupContactRequestMessageItem
    extends StructuredRequestMessageItem {
  GroupContactRequestMessageItem(this.contact)
    : super(
        kind: StructuredRequestItemKind.groupContactRequest,
        requestId: contact.id,
        viewerRole: MessageViewerRole.fromWire(contact.viewerRole),
        requesterProfileId: contact.submitterId,
        requesterDisplayName: contact.submitterName,
        requestMessage: contact.note,
        createdAt: contact.createdAt,
        resolvedAt: contact.resolvedAt,
        activityAt: contact.activityAt,
      );
  final GroupContactRequest contact;
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
