import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/geographic_discovery.dart';

abstract interface class GeographicDiscoveryGateway {
  Future<GeoPage> search(GeoQuery query, {int limit = 20, GeoCursor? cursor});
}

class RpcGeographicDiscoveryGateway implements GeographicDiscoveryGateway {
  const RpcGeographicDiscoveryGateway(this.rpc);
  final Future<dynamic> Function(String, Map<String, dynamic>) rpc;
  @override
  Future<GeoPage> search(
    GeoQuery query, {
    int limit = 20,
    GeoCursor? cursor,
  }) async {
    Map<String, dynamic> args;
    try {
      if (limit < 1 || limit > 50) {
        throw const FormatException('Invalid page size.');
      }
      args = {
        'p_query': query.toJson(),
        'p_limit': limit,
        'p_cursor': cursor?.toJson(),
      };
    } on FormatException {
      throw const GeoFailure(GeoFailureKind.invalidInput);
    }
    try {
      final response = await rpc(
        'search_public_geography_v1',
        args,
      ).timeout(const Duration(seconds: 8));
      final page = GeoPage.fromJson(response, limit: limit);
      if (cursor != null &&
          (page.queryKey != cursor.queryKey ||
              page.referenceTime !=
                  DateTime.parse(cursor.referenceTime).toUtc() ||
              (page.items.isNotEmpty &&
                  page.items.first.identity.compareTo(
                        '${cursor.kind.wire}:${cursor.itemId}',
                      ) <=
                      0))) {
        throw const FormatException(
          'Geographic page scope or ordering drifted.',
        );
      }
      return page;
    } on PostgrestException catch (e) {
      throw GeoFailure(switch (e.code) {
        '22023' =>
          cursor == null
              ? GeoFailureKind.invalidInput
              : GeoFailureKind.expiredCursor,
        '54000' => GeoFailureKind.tooBroad,
        _ => GeoFailureKind.unavailable,
      });
    } on FormatException {
      throw const GeoFailure(GeoFailureKind.malformed);
    } catch (_) {
      // Explicit transport boundary: never log query centers, JWTs or raw SQL errors.
      throw const GeoFailure(GeoFailureKind.unavailable);
    }
  }
}

final geographicDiscoveryGatewayProvider = Provider<GeographicDiscoveryGateway>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return RpcGeographicDiscoveryGateway(
      (name, args) => client.rpc(name, params: args),
    );
  },
);
