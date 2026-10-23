import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/external_activity.dart';

class ExternalActivityCursorExpired implements Exception {
  const ExternalActivityCursorExpired();
}

class ExternalActivityAreaTooBroad implements Exception {
  const ExternalActivityAreaTooBroad();
}

abstract interface class ExternalActivityGateway {
  Future<ExternalActivityPage> list(
    ExternalActivityFilter filter, {
    Map<String, dynamic>? cursor,
  });
  Future<ExternalActivity?> get(String id);
}

class SupabaseExternalActivityGateway implements ExternalActivityGateway {
  const SupabaseExternalActivityGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<ExternalActivityPage> list(
    ExternalActivityFilter filter, {
    Map<String, dynamic>? cursor,
  }) async {
    Object? result;
    try {
      result = await _client.rpc(
        'list_external_activities_v3',
        params: {
          'p_category': filter.category,
          'p_query': filter.query,
          'p_discipline': filter.discipline,
          'p_kind': filter.kind?.name,
          'p_from': filter.from,
          'p_to': filter.to,
          'p_limit': 20,
          'p_cursor': cursor,
          'p_area': filter.area?.toJson(),
          'p_map_only': filter.mappedOnly,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == '54000') throw const ExternalActivityAreaTooBroad();
      if (cursor != null && error.code == '22023') {
        throw const ExternalActivityCursorExpired();
      }
      rethrow;
    }
    if (activityObject(result)['scope'] != 'external_activities') {
      throw const FormatException('Invalid external catalogue scope.');
    }
    final page = ExternalActivityPage.parse(result);
    if (filter.mappedOnly && page.items.any((item) => item.geometry == null)) {
      throw const FormatException(
        'Mapped catalogue returned an unlocated item.',
      );
    }
    if (cursor != null &&
        page.health != ExternalCatalogueHealth.unconfigured &&
        page.asOf != DateTime.parse(cursor['as_of'] as String).toUtc()) {
      throw const FormatException(
        'External catalogue reference changed within a page sequence.',
      );
    }
    return page;
  }

  @override
  Future<ExternalActivity?> get(String id) async {
    final result = await _client.rpc(
      'get_external_activity_v2',
      params: {'p_activity_id': id},
    );
    return result == null ? null : ExternalActivity.parse(result);
  }
}

final externalActivityGatewayProvider = Provider<ExternalActivityGateway>(
  (ref) => SupabaseExternalActivityGateway(ref.watch(supabaseClientProvider)),
);
