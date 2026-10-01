import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../domain/resource_saved_search_models.dart';

const resourceSavedSearchPageSize = 20;

abstract interface class ResourceSavedSearchGateway {
  Future<String> create(
    String expectedProfileId,
    ResourceSavedSearchInput input,
  );

  Future<void> update(
    String expectedProfileId,
    String savedSearchId,
    ResourceSavedSearchInput input,
  );

  Future<void> delete(String expectedProfileId, String savedSearchId);

  Future<ResourceSavedSearch?> getOwn(
    String expectedProfileId,
    String savedSearchId,
  );

  Future<ResourceSavedSearchPage> listOwn({
    required String expectedProfileId,
    required int pageSize,
    ResourceSavedSearchCursor? cursor,
  });
}

class ResourceSavedSearchRpcContract {
  const ResourceSavedSearchRpcContract();

  Map<String, dynamic> inputParams(
    String expectedProfileId,
    ResourceSavedSearchInput input,
  ) => {
    'p_expected_profile_id': expectedProfileId,
    'p_query': input.query,
    'p_listing_mode': input.mode?.wireValue,
    'p_locality': input.locality,
  };

  Map<String, dynamic> targetParams(
    String expectedProfileId,
    String savedSearchId,
  ) => {
    'p_expected_profile_id': expectedProfileId,
    'p_saved_search_id': savedSearchId,
  };

  Map<String, dynamic> listParams({
    required String expectedProfileId,
    required int pageSize,
    ResourceSavedSearchCursor? cursor,
  }) => {
    'p_expected_profile_id': expectedProfileId,
    'p_limit': pageSize + 1,
    'p_cursor_updated_at': cursor?.updatedAt.toUtc().toIso8601String(),
    'p_cursor_id': cursor?.id,
  };
}

class ResourceSavedSearchPayloadParser {
  const ResourceSavedSearchPayloadParser();

  ResourceSavedSearch savedSearch(Map<String, dynamic> row) {
    final query = _optionalBoundedString(row, 'query');
    final locality = _optionalBoundedString(row, 'locality');
    final modeValue = _optionalBoundedString(row, 'listing_mode');
    final mode = modeValue == null
        ? null
        : ResourceListingMode.fromWire(modeValue);
    if (query == null && mode == null && locality == null) {
      throw const FormatException(
        'Resource saved search contained no filters.',
      );
    }
    final createdAt = _date(row, 'created_at');
    final updatedAt = _date(row, 'updated_at');
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException(
        'Resource saved search timestamps were inconsistent.',
      );
    }
    return ResourceSavedSearch(
      id: _uuid(row, 'saved_search_id'),
      query: query,
      mode: mode,
      locality: locality,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Resource saved search $key was malformed.');
    }
    return value;
  }

  String? _optionalBoundedString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String ||
        value.trim() != value ||
        value.isEmpty ||
        value.length > resourceSavedSearchTextMaxLength) {
      throw FormatException('Resource saved search $key was malformed.');
    }
    return value;
  }

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Resource saved search $key was not a UUID.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final parsed = DateTime.tryParse(_string(row, key));
    if (parsed == null) {
      throw FormatException('Resource saved search $key was not a timestamp.');
    }
    return parsed;
  }
}

class SupabaseResourceSavedSearchGateway implements ResourceSavedSearchGateway {
  const SupabaseResourceSavedSearchGateway(
    this._client, {
    this.contract = const ResourceSavedSearchRpcContract(),
    this.parser = const ResourceSavedSearchPayloadParser(),
  });

  final SupabaseClient _client;
  final ResourceSavedSearchRpcContract contract;
  final ResourceSavedSearchPayloadParser parser;

  @override
  Future<String> create(
    String expectedProfileId,
    ResourceSavedSearchInput input,
  ) => _client.rpc<String>(
    'create_resource_saved_search',
    params: contract.inputParams(expectedProfileId, input),
  );

  @override
  Future<void> update(
    String expectedProfileId,
    String savedSearchId,
    ResourceSavedSearchInput input,
  ) async {
    await _client.rpc<String>(
      'update_resource_saved_search',
      params: {
        ...contract.inputParams(expectedProfileId, input),
        'p_saved_search_id': savedSearchId,
      },
    );
  }

  @override
  Future<void> delete(String expectedProfileId, String savedSearchId) async {
    await _client.rpc<String>(
      'delete_resource_saved_search',
      params: contract.targetParams(expectedProfileId, savedSearchId),
    );
  }

  @override
  Future<ResourceSavedSearch?> getOwn(
    String expectedProfileId,
    String savedSearchId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_resource_saved_search',
      params: contract.targetParams(expectedProfileId, savedSearchId),
    );
    final rows = response.cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : parser.savedSearch(rows.single);
  }

  @override
  Future<ResourceSavedSearchPage> listOwn({
    required String expectedProfileId,
    required int pageSize,
    ResourceSavedSearchCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_resource_saved_searches',
      params: contract.listParams(
        expectedProfileId: expectedProfileId,
        pageSize: pageSize,
        cursor: cursor,
      ),
    );
    final rows = response
        .cast<Map<String, dynamic>>()
        .map(parser.savedSearch)
        .toList(growable: false);
    final hasMore = rows.length > pageSize;
    return ResourceSavedSearchPage(
      items: List.unmodifiable(rows.take(pageSize)),
      hasMore: hasMore,
    );
  }
}

final resourceSavedSearchGatewayProvider = Provider<ResourceSavedSearchGateway>(
  (ref) {
    return SupabaseResourceSavedSearchGateway(
      ref.watch(supabaseClientProvider),
    );
  },
);
