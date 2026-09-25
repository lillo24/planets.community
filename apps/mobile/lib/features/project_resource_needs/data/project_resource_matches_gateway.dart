import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../domain/project_resource_match_models.dart';

const projectResourceMatchPageSize = 20;

abstract interface class ProjectResourceMatchesGateway {
  Future<ProjectResourceMatchPage> listMatches({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required ProjectResourceLocationScope locationScope,
    required ProjectResourceListingModeFilter listingMode,
    required int limit,
    ProjectResourceMatchCursor? cursor,
  });
}

class ProjectResourceMatchesRpcContract {
  const ProjectResourceMatchesRpcContract();

  Map<String, dynamic> listParams({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required ProjectResourceLocationScope locationScope,
    required ProjectResourceListingModeFilter listingMode,
    required int limit,
    ProjectResourceMatchCursor? cursor,
  }) => {
    'p_expected_creator_profile_id': expectedCreatorProfileId,
    'p_resource_need_id': resourceNeedId,
    'p_location_scope': locationScope.wireValue,
    'p_limit': limit + 1,
    'p_listing_mode': listingMode.wireValue,
    'p_cursor_text_match_kind': cursor?.textMatchKind.wireValue,
    'p_cursor_location_match_kind': cursor?.locationMatchKind.wireValue,
    'p_cursor_published_at': cursor?.publishedAt.toUtc().toIso8601String(),
    'p_cursor_listing_id': cursor?.listingId,
  };
}

class ProjectResourceMatchPayloadParser {
  const ProjectResourceMatchPayloadParser();

  ProjectResourceListingMatch match(
    Object? value, {
    required String expectedResourceNeedId,
  }) {
    final row = _row(value);
    final resourceNeedId = _uuid(row, 'resource_need_id');
    if (resourceNeedId != expectedResourceNeedId) {
      throw const FormatException(
        'Project resource match belonged to another need.',
      );
    }
    return ProjectResourceListingMatch(
      resourceNeedId: resourceNeedId,
      listingId: _uuid(row, 'listing_id'),
      listingMode: ResourceListingMode.fromWire(
        _requiredString(row, 'listing_mode'),
      ),
      title: _requiredString(row, 'title'),
      description: _requiredString(row, 'description'),
      countryCode: _countryCode(row, 'country_code'),
      locality: _boundedString(row, 'locality', maxLength: 120),
      administrativeArea: _optionalBoundedString(
        row,
        'administrative_area',
        maxLength: 120,
      ),
      publicLocationLabel: _boundedString(
        row,
        'public_location_label',
        maxLength: 180,
      ),
      publishedAt: _date(row, 'published_at'),
      activeRequestCount: _nonNegativeInteger(row, 'active_request_count'),
      textMatchKind: ProjectResourceTextMatchKind.fromWire(
        _requiredString(row, 'text_match_kind'),
      ),
      locationMatchKind: ProjectResourceLocationMatchKind.fromWire(
        _requiredString(row, 'location_match_kind'),
      ),
    );
  }

  Map<String, dynamic> _row(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Project resource match payload was not an object.',
      );
    }
    return value.cast<String, dynamic>();
  }

  String _requiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Project resource match $key was malformed.');
    }
    return value;
  }

  String _boundedString(
    Map<String, dynamic> row,
    String key, {
    required int maxLength,
  }) {
    final value = _requiredString(row, key);
    if (value.length > maxLength) {
      throw FormatException('Project resource match $key was too long.');
    }
    return value;
  }

  String? _optionalBoundedString(
    Map<String, dynamic> row,
    String key, {
    required int maxLength,
  }) {
    if (row[key] == null) return null;
    return _boundedString(row, key, maxLength: maxLength);
  }

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _requiredString(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Project resource match $key was not a UUID.');
    }
    return value;
  }

  String _countryCode(Map<String, dynamic> row, String key) {
    final value = _requiredString(row, key);
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value)) {
      throw const FormatException(
        'Project resource match country code was malformed.',
      );
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = _requiredString(row, key);
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Project resource match $key was malformed.');
    }
    return date;
  }

  int _nonNegativeInteger(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int || value < 0) {
      throw FormatException('Project resource match $key was malformed.');
    }
    return value;
  }
}

class SupabaseProjectResourceMatchesGateway
    implements ProjectResourceMatchesGateway {
  const SupabaseProjectResourceMatchesGateway(
    this._client, {
    this.contract = const ProjectResourceMatchesRpcContract(),
    this.parser = const ProjectResourceMatchPayloadParser(),
  });

  final SupabaseClient _client;
  final ProjectResourceMatchesRpcContract contract;
  final ProjectResourceMatchPayloadParser parser;

  @override
  Future<ProjectResourceMatchPage> listMatches({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required ProjectResourceLocationScope locationScope,
    required ProjectResourceListingModeFilter listingMode,
    required int limit,
    ProjectResourceMatchCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_resource_need_listing_matches',
      params: contract.listParams(
        expectedCreatorProfileId: expectedCreatorProfileId,
        resourceNeedId: resourceNeedId,
        locationScope: locationScope,
        listingMode: listingMode,
        limit: limit,
        cursor: cursor,
      ),
    );
    final parsed = response
        .map((row) => parser.match(row, expectedResourceNeedId: resourceNeedId))
        .toList(growable: false);
    final hasMore = parsed.length > limit;
    return ProjectResourceMatchPage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: hasMore,
    );
  }
}

final projectResourceMatchesGatewayProvider =
    Provider<ProjectResourceMatchesGateway>(
      (ref) => SupabaseProjectResourceMatchesGateway(
        ref.watch(supabaseClientProvider),
      ),
    );
