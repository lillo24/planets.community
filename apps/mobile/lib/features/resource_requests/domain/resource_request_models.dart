import '../../resource_listings/domain/resource_listing_models.dart';

enum ResourceRequestStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  withdrawn('withdrawn'),
  listingClosed('listing_closed');

  const ResourceRequestStatus(this.wireValue);

  final String wireValue;

  static ResourceRequestStatus fromWire(String value) => switch (value) {
    'pending' => ResourceRequestStatus.pending,
    'accepted' => ResourceRequestStatus.accepted,
    'rejected' => ResourceRequestStatus.rejected,
    'withdrawn' => ResourceRequestStatus.withdrawn,
    'listing_closed' => ResourceRequestStatus.listingClosed,
    _ => throw const FormatException('Unsupported resource request status.'),
  };
}

enum ResourceRequestViewerRole {
  requester('requester'),
  owner('owner');

  const ResourceRequestViewerRole(this.wireValue);

  final String wireValue;

  static ResourceRequestViewerRole fromWire(String value) => switch (value) {
    'requester' => ResourceRequestViewerRole.requester,
    'owner' => ResourceRequestViewerRole.owner,
    _ => throw const FormatException(
      'Unsupported resource request viewer role.',
    ),
  };
}

class OwnResourceRequest {
  const OwnResourceRequest({
    required this.id,
    required this.listingId,
    required this.listingMode,
    required this.listingTitle,
    required this.listingLifecycle,
    required this.ownerProfileId,
    required this.ownerDisplayName,
    required this.status,
    required this.requestMessage,
    required this.createdAt,
    required this.resolvedAt,
    required this.coordinationClosedAt,
  });

  final String id;
  final String listingId;
  final ResourceListingMode listingMode;
  final String listingTitle;
  final ResourceListingLifecycle listingLifecycle;
  final String ownerProfileId;
  final String ownerDisplayName;
  final ResourceRequestStatus status;
  final String? requestMessage;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? coordinationClosedAt;

  bool get isActive => switch (status) {
    ResourceRequestStatus.pending => true,
    ResourceRequestStatus.accepted => coordinationClosedAt == null,
    ResourceRequestStatus.rejected ||
    ResourceRequestStatus.withdrawn ||
    ResourceRequestStatus.listingClosed => false,
  };
}

class ResourceRequest extends OwnResourceRequest {
  const ResourceRequest({
    required super.id,
    required super.listingId,
    required super.listingMode,
    required super.listingTitle,
    required super.listingLifecycle,
    required super.ownerProfileId,
    required super.ownerDisplayName,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required super.status,
    required super.requestMessage,
    required super.createdAt,
    required super.resolvedAt,
    required super.coordinationClosedAt,
  });

  final String requesterProfileId;
  final String requesterDisplayName;

  ResourceRequestViewerRole viewerRoleFor(String profileId) {
    if (profileId == requesterProfileId) {
      return ResourceRequestViewerRole.requester;
    }
    if (profileId == ownerProfileId) return ResourceRequestViewerRole.owner;
    throw StateError('Profile is not a Resource request counterparty.');
  }
}

bool isValidResourceRequestMessage(String value) => value.trim().length <= 500;

enum ResourceRequestFailureKind {
  invalidInput,
  forbidden,
  conflict,
  listingUnavailable,
  notFound,
  unavailable,
}

enum ResourceRequestMutation { accepting, rejecting, withdrawing }
