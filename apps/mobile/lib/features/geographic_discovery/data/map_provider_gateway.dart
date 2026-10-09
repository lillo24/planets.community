import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';

class MapProviderFailure implements Exception {
  const MapProviderFailure(this.status);
  final String status;
}

class MapSearchCenter {
  const MapSearchCenter(this.label, this.latitude, this.longitude);
  final String label;
  final double latitude, longitude;
  factory MapSearchCenter.fromJson(Object? value) {
    final row = _object(value, {
      'label',
      'latitude',
      'longitude',
      'country_code',
    });
    final lat = row['latitude'], lon = row['longitude'];
    if (row['country_code'] != 'it' ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw const MapProviderFailure('malformed');
    }
    return MapSearchCenter(
      _label(row['label']),
      lat.toDouble(),
      lon.toDouble(),
    );
  }
}

class MapCenterSuggestion {
  const MapCenterSuggestion(this.id, this.label, this.expiresAt);
  final String id, label;
  final DateTime expiresAt;
  factory MapCenterSuggestion.fromJson(Object? value) {
    final row = _object(value, {'id', 'label', 'expires_at'});
    final id = row['id'], expiry = row['expires_at'];
    if (id is! String ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        ).hasMatch(id) ||
        expiry is! String ||
        DateTime.tryParse(expiry) == null) {
      throw const MapProviderFailure('malformed');
    }
    return MapCenterSuggestion(
      id,
      _label(row['label']),
      DateTime.parse(expiry).toUtc(),
    );
  }
}

Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.keys.toSet().difference(keys).isNotEmpty ||
      !keys.every(value.containsKey)) {
    throw const MapProviderFailure('malformed');
  }
  return Map<String, dynamic>.from(value);
}

String _label(Object? value) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > 240 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const MapProviderFailure('malformed');
  }
  return value;
}

abstract interface class MapProviderGateway {
  bool get tilesEnabled;
  bool get centerEnabled;
  bool get requiresAuthentication;
  bool get isFixture;
  Future<List<MapCenterSuggestion>> search(String query, String language);
  Future<MapSearchCenter> resolve(String id);
  Future<Uint8List> tile(int z, int x, int y);
}

class DisabledMapProviderGateway implements MapProviderGateway {
  const DisabledMapProviderGateway();
  @override
  bool get tilesEnabled => false;
  @override
  bool get centerEnabled => false;
  @override
  bool get requiresAuthentication => true;
  @override
  bool get isFixture => false;
  @override
  Future<List<MapCenterSuggestion>> search(String query, String language) =>
      Future.error(const MapProviderFailure('disabled'));
  @override
  Future<MapSearchCenter> resolve(String id) =>
      Future.error(const MapProviderFailure('disabled'));
  @override
  Future<Uint8List> tile(int z, int x, int y) =>
      Future.error(const MapProviderFailure('disabled'));
}

class ServerMapProviderGateway implements MapProviderGateway {
  const ServerMapProviderGateway(
    this.client, {
    required this.tilesEnabled,
    required this.centerEnabled,
  });
  final SupabaseClient client;
  @override
  final bool tilesEnabled, centerEnabled;
  @override
  bool get requiresAuthentication => true;
  @override
  bool get isFixture => false;

  Future<Object?> _call(
    Map<String, dynamic> body, {
    required bool enabled,
  }) async {
    if (!enabled) throw const MapProviderFailure('disabled');
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw const MapProviderFailure('guest_disabled');
    try {
      final response = await client.functions
          .invoke('map-provider', body: {...body, 'expected_profile_id': actor})
          .timeout(const Duration(seconds: 8));
      if (client.auth.currentUser?.id != actor) {
        throw const MapProviderFailure('stale');
      }
      final data = response.data;
      if (data is Map && data['status'] != 'ok') {
        const allowed = {
          'disabled',
          'guest_disabled',
          'unconfigured',
          'rate_limited',
          'budget_exhausted',
          'pending',
          'expired',
          'unavailable',
        };
        throw MapProviderFailure(
          allowed.contains(data['status'])
              ? data['status'] as String
              : 'unavailable',
        );
      }
      return data;
    } on MapProviderFailure {
      rethrow;
    } catch (_) {
      // Transport boundary: no raw URLs, request text, tokens or errors are logged.
      throw const MapProviderFailure('unavailable');
    }
  }

  @override
  Future<List<MapCenterSuggestion>> search(
    String query,
    String language,
  ) async {
    if (query.trim().runes.length < 2 ||
        query.runes.length > 160 ||
        !{'it', 'en'}.contains(language)) {
      throw const MapProviderFailure('invalid_request');
    }
    final row = _object(
      await _call({
        'operation': 'search',
        'query': query,
        'language': language,
      }, enabled: centerEnabled),
      {'status', 'suggestions'},
    );
    final suggestions = row['suggestions'];
    if (suggestions is! List || suggestions.length > 5) {
      throw const MapProviderFailure('malformed');
    }
    return List.unmodifiable(suggestions.map(MapCenterSuggestion.fromJson));
  }

  @override
  Future<MapSearchCenter> resolve(String id) async {
    final row = _object(
      await _call({
        'operation': 'resolve',
        'suggestion_id': id,
      }, enabled: centerEnabled),
      {'status', 'center'},
    );
    return MapSearchCenter.fromJson(row['center']);
  }

  @override
  Future<Uint8List> tile(int z, int x, int y) async {
    if (z < 7 || z > 18 || x < 0 || y < 0 || x >= 1 << z || y >= 1 << z) {
      throw const MapProviderFailure('invalid_request');
    }
    final data = await _call({
      'operation': 'tile',
      'z': z,
      'x': x,
      'y': y,
      'style': 'osm-carto',
      'version': 1,
    }, enabled: tilesEnabled);
    if (data is! Uint8List ||
        data.length < 45 ||
        data.length > 262144 ||
        data[0] != 137 ||
        data[1] != 80 ||
        data[2] != 78 ||
        data[3] != 71) {
      throw const MapProviderFailure('malformed');
    }
    return data;
  }
}

final mapProviderGatewayProvider = Provider<MapProviderGateway>((ref) {
  const tiles = bool.fromEnvironment('LOCATION_MAP_TILES_ENABLED');
  const centers = bool.fromEnvironment('LOCATION_MAP_CENTERS_ENABLED');
  if (!tiles && !centers) return const DisabledMapProviderGateway();
  return ServerMapProviderGateway(
    ref.watch(supabaseClientProvider),
    tilesEnabled: tiles,
    centerEnabled: centers,
  );
});
