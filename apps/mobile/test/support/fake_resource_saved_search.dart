import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';
import 'package:planets_mobile/features/resource_saved_searches/domain/resource_saved_search_models.dart';

typedef ResourceSavedSearchPageLoader =
    Future<ResourceSavedSearchPage> Function({
      required String expectedProfileId,
      required int pageSize,
      ResourceSavedSearchCursor? cursor,
    });

class FakeResourceSavedSearchGateway implements ResourceSavedSearchGateway {
  List<ResourceSavedSearch> items = [];
  Object? listError;
  Object? mutationError;
  Object? getError;
  Future<void>? listDelay;
  Future<void>? mutationDelay;
  ResourceSavedSearchPageLoader? pageLoader;
  final List<String> calls = [];
  String? lastExpectedProfileId;
  String? lastSavedSearchId;
  ResourceSavedSearchInput? lastInput;
  ResourceSavedSearchCursor? lastCursor;
  int? lastPageSize;

  @override
  Future<String> create(
    String expectedProfileId,
    ResourceSavedSearchInput input,
  ) async {
    calls.add('create');
    lastExpectedProfileId = expectedProfileId;
    lastInput = input;
    await mutationDelay;
    _throw(mutationError);
    final created = resourceSavedSearchFixture(
      id: createdResourceSavedSearchId,
      query: input.query,
      mode: input.mode,
      locality: input.locality,
      updatedAt: DateTime.utc(2026, 9, 25, 14),
    );
    items = [created, ...items];
    return created.id;
  }

  @override
  Future<void> update(
    String expectedProfileId,
    String savedSearchId,
    ResourceSavedSearchInput input,
  ) async {
    calls.add('update:$savedSearchId');
    lastExpectedProfileId = expectedProfileId;
    lastSavedSearchId = savedSearchId;
    lastInput = input;
    await mutationDelay;
    _throw(mutationError);
    items = [
      for (final item in items)
        if (item.id == savedSearchId)
          ResourceSavedSearch(
            id: item.id,
            query: input.query,
            mode: input.mode,
            locality: input.locality,
            createdAt: item.createdAt,
            updatedAt: DateTime.utc(2026, 9, 25, 15),
          )
        else
          item,
    ];
  }

  @override
  Future<void> delete(String expectedProfileId, String savedSearchId) async {
    calls.add('delete:$savedSearchId');
    lastExpectedProfileId = expectedProfileId;
    lastSavedSearchId = savedSearchId;
    await mutationDelay;
    _throw(mutationError);
    items = items.where((item) => item.id != savedSearchId).toList();
  }

  @override
  Future<ResourceSavedSearch?> getOwn(
    String expectedProfileId,
    String savedSearchId,
  ) async {
    _throw(getError);
    calls.add('get:$savedSearchId');
    lastExpectedProfileId = expectedProfileId;
    lastSavedSearchId = savedSearchId;
    return items.where((item) => item.id == savedSearchId).firstOrNull;
  }

  @override
  Future<ResourceSavedSearchPage> listOwn({
    required String expectedProfileId,
    required int pageSize,
    ResourceSavedSearchCursor? cursor,
  }) async {
    await listDelay;
    _throw(listError);
    calls.add(cursor == null ? 'list' : 'list-more');
    lastExpectedProfileId = expectedProfileId;
    lastPageSize = pageSize;
    lastCursor = cursor;
    if (pageLoader case final loader?) {
      return loader(
        expectedProfileId: expectedProfileId,
        pageSize: pageSize,
        cursor: cursor,
      );
    }
    final start = cursor == null
        ? 0
        : items.indexWhere((item) => item.id == cursor.id) + 1;
    final page = items.skip(start).take(pageSize).toList(growable: false);
    return ResourceSavedSearchPage(
      items: page,
      hasMore: start + page.length < items.length,
    );
  }

  void _throw(Object? error) {
    if (error != null) throw error;
  }
}

const resourceSavedSearchId = '00000000-0000-4000-8000-000000000601';
const secondResourceSavedSearchId = '00000000-0000-4000-8000-000000000602';
const createdResourceSavedSearchId = '00000000-0000-4000-8000-000000000603';

ResourceSavedSearch resourceSavedSearchFixture({
  String id = resourceSavedSearchId,
  String? query = 'garden tools',
  ResourceListingMode? mode = ResourceListingMode.donate,
  String? locality = 'Bologna',
  DateTime? createdAt,
  DateTime? updatedAt,
}) => ResourceSavedSearch(
  id: id,
  query: query,
  mode: mode,
  locality: locality,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 24, 10),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 25, 10),
);
