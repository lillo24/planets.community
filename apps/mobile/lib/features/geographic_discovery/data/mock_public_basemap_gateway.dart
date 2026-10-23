import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/config/app_config.dart';
import '../../mock_mode/application/mock_mode_coordinator.dart';
import 'budget_basemap_gateway.dart';
import 'map_provider_gateway.dart';
import '../domain/basemap_tile.dart';
import '../domain/basemap_fallback.dart';

/// The only cross-realm client transport: a fixed public-image endpoint. It has
/// no Supabase client, RPC selector, redirects, product payload or disk cache.
class MockPublicBasemapGateway implements BudgetBasemapGateway {
  MockPublicBasemapGateway({
    required this.client,
    required this.endpoint,
    required this.allowed,
    http.Client? transport,
  }) : _transport = transport ?? http.Client() {
    _auth = client.auth.onAuthStateChange.listen((_) => _revoke());
  }
  final SupabaseClient client;
  final Uri endpoint;
  final bool Function() allowed;
  final http.Client _transport;
  late final StreamSubscription<AuthState> _auth;
  final _pending = <Completer<void>>{};
  int _epoch = 0;
  bool _disposed = false;

  void _revoke() {
    _epoch++;
    for (final abort in _pending) {
      if (!abort.isCompleted) abort.complete();
    }
    _pending.clear();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revoke();
    unawaited(_auth.cancel());
    _transport.close();
  }

  @override
  Future<BudgetBasemapFrame> tile(
    BasemapTileId id, {
    required bool cacheOnly,
    required Future<void> cancellation,
  }) async {
    if (_disposed || !allowed()) throw const BudgetBasemapFailure('disabled');
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
    final session = client.auth.currentSession;
    if (session == null) throw const BudgetBasemapFailure('guest_disabled');
    final epoch = _epoch;
    final abort = Completer<void>();
    _pending.add(abort);
    final deadline = Timer(const Duration(seconds: 8), () {
      if (!abort.isCompleted) abort.complete();
    });
    unawaited(
      cancellation.then((_) {
        if (!abort.isCompleted) abort.complete();
      }),
    );
    final transit = Stopwatch()..start();
    try {
      final request =
          http.AbortableRequest('POST', endpoint, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'operation': 'basemap_tile_v2',
              'z': id.z,
              'x': id.x,
              'y': id.y,
              'style': id.style,
              'version': id.version,
              'cache_only': cacheOnly,
            });
      final response = await _transport.send(request);
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw BudgetBasemapFailure(
          response.statusCode == 401 || response.statusCode == 403
              ? 'unauthorized'
              : 'unavailable',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 400000) {
          throw const BudgetBasemapFailure('malformed');
        }
        bytes.add(chunk);
      }
      if (_disposed ||
          epoch != _epoch ||
          abort.isCompleted ||
          !allowed() ||
          client.auth.currentSession?.accessToken != session.accessToken) {
        throw const BudgetBasemapFailure('stale');
      }
      final frame = parseBudgetBasemapFrame(
        jsonDecode(utf8.decode(bytes.takeBytes())),
        id,
      );
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
    } catch (_) {
      throw BudgetBasemapFailure(abort.isCompleted ? 'stale' : 'unavailable');
    } finally {
      deadline.cancel();
      _pending.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }
}

class MockMapProviderGateway extends DisabledMapProviderGateway {
  const MockMapProviderGateway(this.images);
  final MockPublicBasemapGateway images;
  @override
  bool get tilesEnabled => true;
  @override
  Future<Uint8List> tile(
    int z,
    int x,
    int y, {
    Future<void>? cancellation,
  }) async => (await images.tile(
    BasemapTileId(z, x, y),
    cacheOnly: false,
    cancellation: cancellation ?? Completer<void>().future,
  )).bytes;
}

final mockPublicBasemapGatewayProvider = Provider<MockPublicBasemapGateway?>((
  ref,
) {
  if (!ref.watch(activeMockRealmProvider)) return null;
  final config = ref.watch(appConfigProvider);
  final mock = config.mockEnvironment;
  if (!config.closedTestMockEnabled ||
      mock == null ||
      !const bool.fromEnvironment('LOCATION_MAP_TILES_ENABLED')) {
    return null;
  }
  final coordinator = ref.watch(mockModeCoordinatorProvider);
  final gateway = MockPublicBasemapGateway(
    client: ref.watch(supabaseClientProvider),
    endpoint: mock.normalOrigin.resolve('/functions/v1/mock-basemap'),
    allowed: () =>
        coordinator?.phase == MockModePhase.mock && !coordinator!.fencing,
  );
  void changed() {
    if (coordinator?.phase != MockModePhase.mock || coordinator!.fencing) {
      gateway.dispose();
    }
    ref.invalidateSelf();
  }

  coordinator?.addListener(changed);
  ref.onDispose(() {
    coordinator?.removeListener(changed);
    gateway.dispose();
  });
  return gateway;
});
