enum ResourceListingMode {
  donate('donate'),
  exchange('exchange');

  const ResourceListingMode(this.wireValue);

  final String wireValue;

  static ResourceListingMode fromWire(String value) => switch (value) {
    'donate' => ResourceListingMode.donate,
    'exchange' => ResourceListingMode.exchange,
    _ => throw const FormatException('Unsupported resource listing mode.'),
  };
}

enum ResourceListingLifecycle {
  draft('draft'),
  published('published'),
  closed('closed');

  const ResourceListingLifecycle(this.wireValue);

  final String wireValue;

  static ResourceListingLifecycle fromWire(String value) => switch (value) {
    'draft' => ResourceListingLifecycle.draft,
    'published' => ResourceListingLifecycle.published,
    'closed' => ResourceListingLifecycle.closed,
    _ => throw const FormatException('Unsupported resource listing lifecycle.'),
  };
}

class ResourceListingCursor {
  const ResourceListingCursor({required this.publishedAt, required this.id});

  final DateTime publishedAt;
  final String id;
}

class PublicResourceListingSummary {
  const PublicResourceListingSummary({
    required this.id,
    required this.mode,
    required this.title,
    required this.description,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.publishedAt,
    required this.activeRequestCount,
  });

  final String id;
  final ResourceListingMode mode;
  final String title;
  final String description;
  final String countryCode;
  final String locality;
  final String? administrativeArea;
  final String publicLocationLabel;
  final DateTime publishedAt;
  final int activeRequestCount;

  ResourceListingCursor get cursor =>
      ResourceListingCursor(publishedAt: publishedAt, id: id);
}

class PublicResourceListingDetail {
  const PublicResourceListingDetail({
    required this.summary,
    required this.ownerProfileId,
    required this.ownerDisplayName,
  });

  final PublicResourceListingSummary summary;
  final String ownerProfileId;
  final String? ownerDisplayName;
}

class OwnResourceListing {
  const OwnResourceListing({
    required this.id,
    required this.ownerProfileId,
    required this.mode,
    required this.lifecycle,
    required this.title,
    required this.description,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.closedAt,
  });

  final String id;
  final String ownerProfileId;
  final ResourceListingMode mode;
  final ResourceListingLifecycle lifecycle;
  final String? title;
  final String? description;
  final String? countryCode;
  final String? locality;
  final String? administrativeArea;
  final String? publicLocationLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? closedAt;

  bool get isEditable => lifecycle != ResourceListingLifecycle.closed;
}

class ResourceListingInput {
  const ResourceListingInput({
    required this.mode,
    required this.title,
    required this.description,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
  });

  final ResourceListingMode mode;
  final String title;
  final String description;
  final String countryCode;
  final String locality;
  final String administrativeArea;
  final String publicLocationLabel;
}

bool isValidResourceListingDraft(ResourceListingInput input) {
  final titleLength = input.title.trim().length;
  final descriptionLength = input.description.trim().length;
  final countryCode = input.countryCode.trim();
  final localityLength = input.locality.trim().length;
  final administrativeAreaLength = input.administrativeArea.trim().length;
  final publicLocationLength = input.publicLocationLabel.trim().length;

  return (titleLength == 0 || (titleLength >= 2 && titleLength <= 120)) &&
      descriptionLength <= 5000 &&
      (countryCode.isEmpty || RegExp(r'^[A-Za-z]{2}$').hasMatch(countryCode)) &&
      localityLength <= 120 &&
      administrativeAreaLength <= 120 &&
      publicLocationLength <= 180;
}

bool isPublishableResourceListingInput(ResourceListingInput input) =>
    isValidResourceListingDraft(input) &&
    input.title.trim().isNotEmpty &&
    input.description.trim().isNotEmpty &&
    input.countryCode.trim().isNotEmpty &&
    input.locality.trim().isNotEmpty &&
    input.publicLocationLabel.trim().isNotEmpty;

enum ResourceListingFailureKind {
  invalidInput,
  unavailable,
  forbidden,
  invalidState,
  notFound,
}

enum ResourceListingLoadPhase { idle, loading, ready, loadingMore, failure }

class PublicResourceListingsState {
  const PublicResourceListingsState({
    this.phase = ResourceListingLoadPhase.idle,
    this.items = const [],
    this.modeFilter,
    this.locality = '',
    this.query = '',
    this.cursor,
    this.hasMore = true,
    this.failure,
  });

  final ResourceListingLoadPhase phase;
  final List<PublicResourceListingSummary> items;
  final ResourceListingMode? modeFilter;
  final String locality;
  final String query;
  final ResourceListingCursor? cursor;
  final bool hasMore;
  final ResourceListingFailureKind? failure;

  bool get isBusy =>
      phase == ResourceListingLoadPhase.loading ||
      phase == ResourceListingLoadPhase.loadingMore;

  bool get hasFilters =>
      modeFilter != null || locality.isNotEmpty || query.isNotEmpty;
}

class PublicResourceListingDetailState {
  const PublicResourceListingDetailState({
    this.phase = ResourceListingLoadPhase.idle,
    this.listingId,
    this.detail,
    this.failure,
  });

  final ResourceListingLoadPhase phase;
  final String? listingId;
  final PublicResourceListingDetail? detail;
  final ResourceListingFailureKind? failure;
}

class OwnResourceListingsState {
  const OwnResourceListingsState({
    this.phase = ResourceListingLoadPhase.idle,
    this.expectedOwnerId,
    this.items = const [],
    this.failure,
  });

  final ResourceListingLoadPhase phase;
  final String? expectedOwnerId;
  final List<OwnResourceListing> items;
  final ResourceListingFailureKind? failure;
}

enum ResourceListingEditorPhase {
  idle,
  loading,
  ready,
  saving,
  publishing,
  closing,
  failure,
}

class ResourceListingEditorState {
  const ResourceListingEditorState({
    this.phase = ResourceListingEditorPhase.idle,
    this.expectedOwnerId,
    this.listingId,
    this.listing,
    this.failure,
    this.draftSavedAfterPublishFailure = false,
  });

  final ResourceListingEditorPhase phase;
  final String? expectedOwnerId;
  final String? listingId;
  final OwnResourceListing? listing;
  final ResourceListingFailureKind? failure;
  final bool draftSavedAfterPublishFailure;

  bool get isBusy => switch (phase) {
    ResourceListingEditorPhase.loading ||
    ResourceListingEditorPhase.saving ||
    ResourceListingEditorPhase.publishing ||
    ResourceListingEditorPhase.closing => true,
    ResourceListingEditorPhase.idle ||
    ResourceListingEditorPhase.ready ||
    ResourceListingEditorPhase.failure => false,
  };
}
