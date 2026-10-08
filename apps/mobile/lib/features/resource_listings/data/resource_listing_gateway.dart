import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/cover_media_path.dart';
import '../../../core/backend/supabase_backend.dart';
import '../../../core/backend/owner_collection.dart';
import '../domain/resource_listing_models.dart';

const resourceListingPageSize = 20;

abstract interface class ResourceListingGateway {
  Future<List<PublicResourceListingSummary>> listPublicResourceListings({
    required int limit,
    ResourceListingCursor? cursor,
    ResourceListingMode? mode,
    String? locality,
    String? query,
  });

  Future<PublicResourceListingDetail?> getPublicResourceListing(
    String listingId,
  );

  Future<List<OwnResourceListing>> listOwnResourceListings(
    String expectedOwnerId,
  );

  Future<OwnResourceListing?> getOwnResourceListing(
    String expectedOwnerId,
    String listingId,
  );

  Future<String> createDraft(
    String expectedOwnerId,
    ResourceListingInput input, {
    String? clientRequestId,
  });

  Future<void> updateOwnResourceListing(
    String expectedOwnerId,
    String listingId,
    ResourceListingInput input,
  );

  Future<void> publishResourceListing(String expectedOwnerId, String listingId);

  Future<void> closeResourceListing(String expectedOwnerId, String listingId);
}

class ResourceListingRpcContract {
  const ResourceListingRpcContract();

  Map<String, dynamic> publicListParams({
    required int limit,
    ResourceListingCursor? cursor,
    ResourceListingMode? mode,
    String? locality,
    String? query,
  }) => {
    'p_limit': limit,
    'p_cursor_published_at': cursor?.publishedAt.toUtc().toIso8601String(),
    'p_cursor_id': cursor?.id,
    'p_listing_mode': mode?.wireValue,
    'p_locality': locality,
    'p_query': query,
  };

  Map<String, dynamic> contentParams(
    String expectedOwnerId,
    ResourceListingInput input,
  ) => {
    'p_expected_owner_profile_id': expectedOwnerId,
    'p_listing_mode': input.mode.wireValue,
    'p_title': input.title,
    'p_description': input.description,
    'p_country_code': input.countryCode,
    'p_locality': input.locality,
    'p_administrative_area': input.administrativeArea,
    'p_public_location_label': input.publicLocationLabel,
  };

  Map<String, dynamic> ownerListingParams(
    String expectedOwnerId,
    String listingId,
  ) => {
    'p_expected_owner_profile_id': expectedOwnerId,
    'p_listing_id': listingId,
  };
}

class ResourceListingPayloadParser {
  const ResourceListingPayloadParser();

  PublicResourceListingSummary publicSummary(Map<String, dynamic> row) =>
      PublicResourceListingSummary(
        id: _uuid(row, 'listing_id'),
        coverObjectPath: parseCoverObjectPath(
          row['cover_object_path'],
          parentId: _uuid(row, 'listing_id'),
          parentSegment: 'resources',
        ),
        mode: ResourceListingMode.fromWire(_string(row, 'listing_mode')),
        title: _string(row, 'title'),
        description: _string(row, 'description'),
        countryCode: _string(row, 'country_code'),
        locality: _string(row, 'locality'),
        administrativeArea: _optionalString(row, 'administrative_area'),
        publicLocationLabel: _string(row, 'public_location_label'),
        publishedAt: _date(row, 'published_at'),
        activeRequestCount: _nonNegativeInteger(row, 'active_request_count'),
      );

  PublicResourceListingDetail publicDetail(Map<String, dynamic> row) =>
      PublicResourceListingDetail(
        summary: publicSummary(row),
        ownerProfileId: _uuid(row, 'owner_profile_id'),
        ownerDisplayName: _optionalString(row, 'owner_display_name'),
      );

  OwnResourceListing ownListing(Map<String, dynamic> row) {
    final lifecycle = ResourceListingLifecycle.fromWire(
      _string(row, 'lifecycle_state'),
    );
    final publishedAt = _optionalDate(row, 'published_at');
    final closedAt = _optionalDate(row, 'closed_at');
    final validTimestamps = switch (lifecycle) {
      ResourceListingLifecycle.draft => publishedAt == null && closedAt == null,
      ResourceListingLifecycle.published =>
        publishedAt != null && closedAt == null,
      ResourceListingLifecycle.closed =>
        publishedAt != null &&
            closedAt != null &&
            !closedAt.isBefore(publishedAt),
    };
    if (!validTimestamps) {
      throw const FormatException(
        'Resource listing lifecycle timestamps were inconsistent.',
      );
    }
    return OwnResourceListing(
      id: _uuid(row, 'listing_id'),
      coverObjectPath: parseCoverObjectPath(
        row['cover_object_path'],
        parentId: _uuid(row, 'listing_id'),
        parentSegment: 'resources',
      ),
      ownerProfileId: _uuid(row, 'owner_profile_id'),
      mode: ResourceListingMode.fromWire(_string(row, 'listing_mode')),
      lifecycle: lifecycle,
      title: _optionalString(row, 'title'),
      description: _optionalString(row, 'description'),
      countryCode: _optionalString(row, 'country_code'),
      locality: _optionalString(row, 'locality'),
      administrativeArea: _optionalString(row, 'administrative_area'),
      publicLocationLabel: _optionalString(row, 'public_location_label'),
      createdAt: _date(row, 'created_at'),
      updatedAt: _date(row, 'updated_at'),
      publishedAt: publishedAt,
      closedAt: closedAt,
    );
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Resource listing $key was not a string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Resource listing $key was malformed.');
    }
    return value;
  }

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Resource listing $key was not a UUID.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Resource listing $key was not a timestamp.');
    }
    return parsed;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);

  int _nonNegativeInteger(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int || value < 0) {
      throw FormatException('Resource listing $key was not non-negative.');
    }
    return value;
  }
}

class SupabaseResourceListingGateway implements ResourceListingGateway {
  const SupabaseResourceListingGateway(
    this._client, {
    this.contract = const ResourceListingRpcContract(),
    this.parser = const ResourceListingPayloadParser(),
  });

  final SupabaseClient _client;
  final ResourceListingRpcContract contract;
  final ResourceListingPayloadParser parser;

  @override
  Future<List<PublicResourceListingSummary>> listPublicResourceListings({
    required int limit,
    ResourceListingCursor? cursor,
    ResourceListingMode? mode,
    String? locality,
    String? query,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_public_resource_listings',
      params: contract.publicListParams(
        limit: limit,
        cursor: cursor,
        mode: mode,
        locality: locality,
        query: query,
      ),
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(parser.publicSummary)
        .toList(growable: false);
  }

  @override
  Future<PublicResourceListingDetail?> getPublicResourceListing(
    String listingId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_public_resource_listing',
      params: {'p_listing_id': listingId},
    );
    final rows = response.cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : parser.publicDetail(rows.single);
  }

  @override
  Future<List<OwnResourceListing>> listOwnResourceListings(
    String expectedOwnerId,
  ) async {
    final response = await readOwnerCollection(
      _client,
      'list_own_resource_listings',
      params: {'p_expected_owner_profile_id': expectedOwnerId},
      idColumn: 'listing_id',
      descendingIdTie: true,
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(parser.ownListing)
        .toList(growable: false);
  }

  @override
  Future<OwnResourceListing?> getOwnResourceListing(
    String expectedOwnerId,
    String listingId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_resource_listing',
      params: contract.ownerListingParams(expectedOwnerId, listingId),
    );
    final rows = response.cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : parser.ownListing(rows.single);
  }

  @override
  Future<String> createDraft(
    String expectedOwnerId,
    ResourceListingInput input, {
    String? clientRequestId,
  }) => _client.rpc<String>(
    clientRequestId == null
        ? 'create_resource_listing_draft'
        : 'create_editor_resource_listing_draft',
    params: {
      ...contract.contentParams(expectedOwnerId, input),
      'p_client_request_id': ?clientRequestId,
    },
  );

  @override
  Future<void> updateOwnResourceListing(
    String expectedOwnerId,
    String listingId,
    ResourceListingInput input,
  ) async {
    await _client.rpc<String>(
      'update_own_resource_listing',
      params: {
        ...contract.contentParams(expectedOwnerId, input),
        'p_listing_id': listingId,
      },
    );
  }

  @override
  Future<void> publishResourceListing(
    String expectedOwnerId,
    String listingId,
  ) async {
    await _client.rpc<String>(
      'publish_resource_listing',
      params: contract.ownerListingParams(expectedOwnerId, listingId),
    );
  }

  @override
  Future<void> closeResourceListing(
    String expectedOwnerId,
    String listingId,
  ) async {
    await _client.rpc<String>(
      'close_resource_listing',
      params: contract.ownerListingParams(expectedOwnerId, listingId),
    );
  }
}

final resourceListingGatewayProvider = Provider<ResourceListingGateway>((ref) {
  return SupabaseResourceListingGateway(ref.watch(supabaseClientProvider));
});
