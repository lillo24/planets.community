import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/external_activity.dart';

class ExternalActivityCursorExpired implements Exception {
  const ExternalActivityCursorExpired();
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
        'list_external_activities_v2',
        params: {
          'p_category': filter.category,
          'p_query': filter.query,
          'p_discipline': filter.discipline,
          'p_kind': filter.kind?.name,
          'p_from': filter.from,
          'p_to': filter.to,
          'p_limit': 20,
          'p_cursor': cursor,
        },
      );
    } on PostgrestException catch (error) {
      if (cursor != null && error.code == '22023') {
        throw const ExternalActivityCursorExpired();
      }
      rethrow;
    }
    final page = ExternalActivityPage.parse(result);
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
