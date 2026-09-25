import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

typedef PublicResourceListingLoader =
    Future<List<PublicResourceListingSummary>> Function({
      required int limit,
      ResourceListingCursor? cursor,
      ResourceListingMode? mode,
      String? locality,
      String? query,
    });

typedef OwnResourceListingLoader = Future<List<OwnResourceListing>> Function(
  String expectedOwnerId,
);

class FakeResourceListingGateway implements ResourceListingGateway {
  List<PublicResourceListingSummary> publicItems = [];
  PublicResourceListingDetail? publicDetail;
  List<OwnResourceListing> ownItems = [];
  Object? error;
  Object? publicListError;
  Object? publicDetailError;
  Object? ownListError;
  Object? publishError;
  Object? closeError;
  PublicResourceListingLoader? publicLoader;
  OwnResourceListingLoader? ownLoader;
  Future<OwnResourceListing?>? ownResult;
  final List<String> calls = [];
  ResourceListingCursor? lastCursor;
  ResourceListingMode? lastMode;
  String? lastLocality;
  String? lastQuery;
  String? lastExpectedOwnerId;
  ResourceListingInput? lastInput;
  int createCount = 0;

  @override
  Future<List<PublicResourceListingSummary>> listPublicResourceListings({
    required int limit,
    ResourceListingCursor? cursor,
    ResourceListingMode? mode,
    String? locality,
    String? query,
  }) async {
    _throw(error ?? publicListError);
    calls.add('list-public');
    lastCursor = cursor;
    lastMode = mode;
    lastLocality = locality;
    lastQuery = query;
    if (publicLoader case final loader?) {
      return loader(
        limit: limit,
        cursor: cursor,
        mode: mode,
        locality: locality,
        query: query,
      );
    }
    return publicItems.take(limit).toList(growable: false);
  }

  @override
  Future<PublicResourceListingDetail?> getPublicResourceListing(
    String listingId,
  ) async {
    _throw(error ?? publicDetailError);
    calls.add('get-public:$listingId');
    return publicDetail;
  }

  @override
  Future<List<OwnResourceListing>> listOwnResourceListings(
    String expectedOwnerId,
  ) async {
    _throw(error ?? ownListError);
    calls.add('list-own:$expectedOwnerId');
    lastExpectedOwnerId = expectedOwnerId;
    if (ownLoader case final loader?) return loader(expectedOwnerId);
    return ownItems;
  }

  @override
  Future<OwnResourceListing?> getOwnResourceListing(
    String expectedOwnerId,
    String listingId,
  ) async {
    _throw(error);
    calls.add('get-own:$listingId');
    lastExpectedOwnerId = expectedOwnerId;
    return ownResult ??
        Future.value(
          ownItems.where((item) => item.id == listingId).firstOrNull,
        );
  }

  @override
  Future<String> createDraft(
    String expectedOwnerId,
    ResourceListingInput input,
  ) async {
    _throw(error);
    calls.add('create');
    createCount++;
    lastExpectedOwnerId = expectedOwnerId;
    lastInput = input;
    final created = ownResourceListingFixture(
      id: newResourceListingId,
      ownerProfileId: expectedOwnerId,
      lifecycle: ResourceListingLifecycle.draft,
      input: input,
    );
    ownItems = [created, ...ownItems];
    return created.id;
  }

  @override
  Future<void> updateOwnResourceListing(
    String expectedOwnerId,
    String listingId,
    ResourceListingInput input,
  ) async {
    _throw(error);
    calls.add('update:$listingId');
    lastExpectedOwnerId = expectedOwnerId;
    lastInput = input;
    ownItems = [
      for (final item in ownItems)
        if (item.id == listingId)
          ownResourceListingFixture(
            id: item.id,
            ownerProfileId: item.ownerProfileId,
            lifecycle: item.lifecycle,
            input: input,
          )
        else
          item,
    ];
  }

  @override
  Future<void> publishResourceListing(
    String expectedOwnerId,
    String listingId,
  ) async {
    _throw(error ?? publishError);
    calls.add('publish:$listingId');
    lastExpectedOwnerId = expectedOwnerId;
    ownItems = [
      for (final item in ownItems)
        if (item.id == listingId)
          copyOwnResourceListing(
            item,
            lifecycle: ResourceListingLifecycle.published,
            publishedAt: DateTime.utc(2026, 9, 14, 12),
          )
        else
          item,
    ];
    final published = ownItems
        .where((item) => item.id == listingId)
        .firstOrNull;
    if (published != null) {
      final summary = _publicSummary(published);
      publicItems = [
        summary,
        ...publicItems.where((item) => item.id != listingId),
      ];
      publicDetail = PublicResourceListingDetail(
        summary: summary,
        ownerProfileId: published.ownerProfileId,
        ownerDisplayName: publicDetail?.ownerDisplayName,
      );
    }
  }

  @override
  Future<void> closeResourceListing(
    String expectedOwnerId,
    String listingId,
  ) async {
    _throw(error ?? closeError);
    calls.add('close:$listingId');
    lastExpectedOwnerId = expectedOwnerId;
    ownItems = [
      for (final item in ownItems)
        if (item.id == listingId)
          copyOwnResourceListing(
            item,
            lifecycle: ResourceListingLifecycle.closed,
            closedAt: DateTime.utc(2026, 9, 15, 12),
          )
        else
          item,
    ];
    publicItems = publicItems
        .where((item) => item.id != listingId)
        .toList(growable: false);
    if (publicDetail?.summary.id == listingId) publicDetail = null;
  }

  void _throw(Object? failure) {
    if (failure != null) throw failure;
  }
}

PublicResourceListingSummary _publicSummary(OwnResourceListing listing) =>
    PublicResourceListingSummary(
      id: listing.id,
      mode: listing.mode,
      title: listing.title!,
      description: listing.description!,
      countryCode: listing.countryCode!,
      locality: listing.locality!,
      administrativeArea: listing.administrativeArea,
      publicLocationLabel: listing.publicLocationLabel!,
      publishedAt: listing.publishedAt!,
      activeRequestCount: 0,
    );

const resourceOwnerProfileId = '00000000-0000-4000-8000-000000000101';
const otherProfileId = '00000000-0000-4000-8000-000000000102';
const resourceListingId = '00000000-0000-4000-8000-000000000201';
const secondResourceListingId = '00000000-0000-4000-8000-000000000202';
const newResourceListingId = '00000000-0000-4000-8000-000000000203';

ResourceListingInput resourceListingInputFixture({
  ResourceListingMode mode = ResourceListingMode.donate,
  String title = 'Garden tools',
  String description = 'A rake and a shovel ready for a new garden.',
  String countryCode = 'IT',
  String locality = 'Bologna',
  String administrativeArea = 'Emilia-Romagna',
  String publicLocationLabel = 'Central Bologna',
}) => ResourceListingInput(
  mode: mode,
  title: title,
  description: description,
  countryCode: countryCode,
  locality: locality,
  administrativeArea: administrativeArea,
  publicLocationLabel: publicLocationLabel,
);

PublicResourceListingSummary publicResourceListingFixture({
  String id = resourceListingId,
  ResourceListingMode mode = ResourceListingMode.donate,
  String title = 'Garden tools',
  String description = 'A rake and a shovel ready for a new garden.',
  String countryCode = 'IT',
  String locality = 'Bologna',
  String? administrativeArea = 'Emilia-Romagna',
  String publicLocationLabel = 'Central Bologna',
  DateTime? publishedAt,
  int activeRequestCount = 0,
}) => PublicResourceListingSummary(
  id: id,
  mode: mode,
  title: title,
  description: description,
  countryCode: countryCode,
  locality: locality,
  administrativeArea: administrativeArea,
  publicLocationLabel: publicLocationLabel,
  publishedAt: publishedAt ?? DateTime.utc(2026, 9, 14, 12),
  activeRequestCount: activeRequestCount,
);

PublicResourceListingDetail publicResourceListingDetailFixture({
  String ownerId = resourceOwnerProfileId,
  String? ownerDisplayName = 'Casey',
  int activeRequestCount = 0,
  String locality = 'Bologna',
  String? administrativeArea = 'Emilia-Romagna',
  String publicLocationLabel = 'Central Bologna',
}) => PublicResourceListingDetail(
  summary: publicResourceListingFixture(
    activeRequestCount: activeRequestCount,
    locality: locality,
    administrativeArea: administrativeArea,
    publicLocationLabel: publicLocationLabel,
  ),
  ownerProfileId: ownerId,
  ownerDisplayName: ownerDisplayName,
);

OwnResourceListing ownResourceListingFixture({
  String id = resourceListingId,
  String ownerProfileId = resourceOwnerProfileId,
  ResourceListingLifecycle lifecycle = ResourceListingLifecycle.draft,
  ResourceListingInput? input,
}) {
  final value = input ?? resourceListingInputFixture();
  final published = lifecycle != ResourceListingLifecycle.draft
      ? DateTime.utc(2026, 9, 14, 12)
      : null;
  return OwnResourceListing(
    id: id,
    ownerProfileId: ownerProfileId,
    mode: value.mode,
    lifecycle: lifecycle,
    title: value.title.isEmpty ? null : value.title,
    description: value.description.isEmpty ? null : value.description,
    countryCode: value.countryCode.isEmpty ? null : value.countryCode,
    locality: value.locality.isEmpty ? null : value.locality,
    administrativeArea: value.administrativeArea.isEmpty
        ? null
        : value.administrativeArea,
    publicLocationLabel: value.publicLocationLabel.isEmpty
        ? null
        : value.publicLocationLabel,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 14),
    publishedAt: published,
    closedAt: lifecycle == ResourceListingLifecycle.closed
        ? DateTime.utc(2026, 9, 15, 12)
        : null,
  );
}

OwnResourceListing copyOwnResourceListing(
  OwnResourceListing item, {
  required ResourceListingLifecycle lifecycle,
  DateTime? publishedAt,
  DateTime? closedAt,
}) => OwnResourceListing(
  id: item.id,
  ownerProfileId: item.ownerProfileId,
  mode: item.mode,
  lifecycle: lifecycle,
  title: item.title,
  description: item.description,
  countryCode: item.countryCode,
  locality: item.locality,
  administrativeArea: item.administrativeArea,
  publicLocationLabel: item.publicLocationLabel,
  createdAt: item.createdAt,
  updatedAt: DateTime.utc(2026, 9, 15),
  publishedAt: publishedAt ?? item.publishedAt,
  closedAt: closedAt,
);
