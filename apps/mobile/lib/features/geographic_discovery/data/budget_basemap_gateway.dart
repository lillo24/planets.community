import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/basemap_fallback.dart';
import '../domain/basemap_tile.dart';
import 'map_provider_gateway.dart';
import 'mock_public_basemap_gateway.dart';

class BudgetBasemapFailure extends MapProviderFailure {
  const BudgetBasemapFailure(super.status, {this.retryAfter = Duration.zero});
  final Duration retryAfter;
}

abstract interface class BudgetBasemapGateway {
  Future<BudgetBasemapFrame> tile(
    BasemapTileId id, {
    required bool cacheOnly,
    required Future<void> cancellation,
  });
}

class ServerBudgetBasemapGateway implements BudgetBasemapGateway {
  const ServerBudgetBasemapGateway(this.client);
  final SupabaseClient client;
  @override
  Future<BudgetBasemapFrame> tile(
    BasemapTileId id, {
    required bool cacheOnly,
    required Future<void> cancellation,
  }) async {
    if (id.provider != 'geoapify' ||
        id.style != 'osm-carto' ||
        id.version != 1 ||
        id.dimension != 256 ||
        id.density != 1 ||
        id.z < 7 ||
        id.z > 18 ||
        id.x < 0 ||
        id.y < 0 ||
        id.x >= 1 << id.z ||
        id.y >= 1 << id.z) {
      throw const BudgetBasemapFailure('invalid_request');
    }
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw const BudgetBasemapFailure('guest_disabled');
    try {
      final transit = Stopwatch()..start();
      final response = await client.functions
          .invoke(
            'map-provider',
            body: {
              'operation': 'basemap_tile_v2',
              'expected_profile_id': actor,
              'z': id.z,
              'x': id.x,
              'y': id.y,
              'style': id.style,
              'version': id.version,
              'cache_only': cacheOnly,
            },
            abortSignal: cancellation,
          )
          .timeout(const Duration(seconds: 8));
      if (client.auth.currentUser?.id != actor) {
        throw const BudgetBasemapFailure('stale');
      }
      final frame = parseBudgetBasemapFrame(response.data, id);
      // Subtract the whole round trip conservatively. Receipt of cached bytes
      // cannot extend the source lifetime by transport latency or clock skew.
      final remaining = frame.validFor - transit.elapsed;
      if (remaining <= Duration.zero) {
        throw const BudgetBasemapFailure('expired');
      }
      return BudgetBasemapFrame(
        source: frame.source,
        bytes: frame.bytes,
        acquiredAt: frame.acquiredAt,
        expiresAt: frame.expiresAt,
        validFor: remaining,
        cached: frame.cached,
        budgetExhausted: frame.budgetExhausted,
        retryAfter: frame.retryAfter,
      );
    } on MapProviderFailure {
      rethrow;
    } on FunctionException catch (error) {
      throw BudgetBasemapFailure(switch (error.status) {
        401 => 'guest_disabled',
        403 => 'unauthorized',
        _ => 'unavailable',
      });
    } catch (_) {
      // Explicit transport boundary; never log JWTs, coordinates or raw failures.
      throw const BudgetBasemapFailure('unavailable');
    }
  }
}

BudgetBasemapFrame parseBudgetBasemapFrame(
  Object? value,
  BasemapTileId requested,
) {
  try {
    if (value is! Map) throw const FormatException();
    final retry = value['retry_after_seconds'] ?? 0;
    if (retry is! int || retry < 0 || retry > 86400) {
      throw const FormatException();
    }
    final delay = Duration(seconds: retry);
    if (value['status'] == 'budget_exhausted' && retry == 0 ||
        value['budget_exhausted'] == true && retry == 0) {
      throw const FormatException();
    }
    if (value['status'] != 'ok') {
      const statuses = {
        'disabled',
        'unconfigured',
        'guest_disabled',
        'unauthorized',
        'rate_limited',
        'budget_exhausted',
        'pending',
        'expired',
        'cache_miss',
        'unavailable',
        'provider_failure',
        'invalid_image',
        'timeout',
      };
      throw BudgetBasemapFailure(
        statuses.contains(value['status'])
            ? value['status'] as String
            : 'unavailable',
        retryAfter: delay,
      );
    }
    const keys = {
      'status',
      'cached',
      'source',
      'acquired_at',
      'expires_at',
      'server_time',
      'budget_exhausted',
      'retry_after_seconds',
      'image_base64',
    };
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(value.containsKey)) {
      throw const FormatException();
    }
    final source = value['source'];
    if (source is! Map ||
        source.length != 7 ||
        source['style'] != 'osm-carto' ||
        source['version'] != 1 ||
        source['dimension'] != 256 ||
        source['density'] != 1 ||
        source['z'] is! int ||
        source['x'] is! int ||
        source['y'] is! int) {
      throw const FormatException();
    }
    final id = BasemapTileId(
      source['z'] as int,
      source['x'] as int,
      source['y'] as int,
    );
    if (!tileCovers(id, requested) ||
        id.z != requested.z && trentoBaselineAncestor(requested) != id) {
      throw const FormatException();
    }
    final server = DateTime.parse(value['server_time'] as String).toUtc();
    final expiry = DateTime.parse(value['expires_at'] as String).toUtc();
    final acquired = value['acquired_at'] == null
        ? null
        : DateTime.parse(value['acquired_at'] as String).toUtc();
    final remaining = expiry.difference(server);
    if (remaining <= Duration.zero ||
        remaining > const Duration(days: 7) ||
        acquired != null &&
            (acquired.isAfter(server) || !acquired.isBefore(expiry)) ||
        value['cached'] is! bool ||
        value['budget_exhausted'] is! bool) {
      throw const FormatException();
    }
    final encoded = value['image_base64'];
    if (encoded is! String || encoded.length > 350000) {
      throw const FormatException();
    }
    final bytes = base64Decode(encoded.replaceAll(RegExp(r'\s'), ''));
    if (!validBasemapTilePng(bytes)) throw const FormatException();
    return BudgetBasemapFrame(
      source: id,
      bytes: bytes,
      expiresAt: expiry,
      acquiredAt: acquired,
      validFor: remaining,
      cached: value['cached'] as bool,
      budgetExhausted: value['budget_exhausted'] as bool,
      retryAfter: delay,
    );
  } on BudgetBasemapFailure {
    rethrow;
  } catch (_) {
    throw const BudgetBasemapFailure('malformed');
  }
}

/// Coordinated opt-in only after v2 migration/Edge deployment is verified.
final budgetBasemapEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('LOCATION_BASEMAP_BUDGET_ENABLED'),
);
final budgetBasemapGatewayProvider = Provider<BudgetBasemapGateway>(
  (ref) =>
      ref.watch(mockPublicBasemapGatewayProvider) ??
      ServerBudgetBasemapGateway(ref.watch(supabaseClientProvider)),
);
