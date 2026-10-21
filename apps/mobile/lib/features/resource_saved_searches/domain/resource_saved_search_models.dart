import '../../resource_listings/domain/resource_listing_models.dart';

const resourceSavedSearchTextMaxLength = 120;

class ResourceSavedSearch {
  const ResourceSavedSearch({
    required this.id,
    required this.query,
    required this.mode,
    required this.locality,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  final String id;
  final String? query;
  final ResourceListingMode? mode;
  final ResourceCategory? category;
  final String? locality;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResourceSavedSearchCursor get cursor =>
      ResourceSavedSearchCursor(updatedAt: updatedAt, id: id);

  ResourceSavedSearchInput get input => ResourceSavedSearchInput(
    query: query,
    mode: mode,
    locality: locality,
    category: category,
  );
}

class ResourceSavedSearchInput {
  const ResourceSavedSearchInput({
    required this.query,
    required this.mode,
    required this.locality,
    this.category,
  });

  factory ResourceSavedSearchInput.normalized({
    required String query,
    required ResourceListingMode? mode,
    required String locality,
    ResourceCategory? category,
  }) => ResourceSavedSearchInput(
    query: _trimmedOrNull(query),
    mode: mode,
    locality: _trimmedOrNull(locality),
    category: category,
  );

  final String? query;
  final ResourceListingMode? mode;
  final ResourceCategory? category;
  final String? locality;

  bool get isValid =>
      (query == null ||
          (query!.trim() == query &&
              query!.isNotEmpty &&
              query!.length <= resourceSavedSearchTextMaxLength)) &&
      (locality == null ||
          (locality!.trim() == locality &&
              locality!.isNotEmpty &&
              locality!.length <= resourceSavedSearchTextMaxLength)) &&
      (query != null || mode != null || locality != null || category != null);
}

class ResourceSavedSearchCursor {
  const ResourceSavedSearchCursor({required this.updatedAt, required this.id});

  final DateTime updatedAt;
  final String id;
}

class ResourceSavedSearchPage {
  const ResourceSavedSearchPage({required this.items, required this.hasMore});

  final List<ResourceSavedSearch> items;
  final bool hasMore;
}

enum ResourceSavedSearchFailureKind {
  invalidInput,
  forbidden,
  duplicate,
  notFound,
  unavailable,
}

String? _trimmedOrNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
