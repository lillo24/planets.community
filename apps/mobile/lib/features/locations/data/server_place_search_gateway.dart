import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/place_search.dart';
import 'place_search_gateway.dart';

typedef LocationEndpoint = Future<dynamic> Function(Map<String, dynamic> body);

/// An editor captures this scope after saving its manual draft. Any subsequent
/// content save requires a fresh revision/gateway and controller cancellation.
class PlaceSearchScope {
  const PlaceSearchScope({
    required this.actorId,
    required this.itemKind,
    required this.itemId,
    required this.revision,
    required this.slot,
  });
  final String actorId, itemKind, itemId, slot;
  final int revision;
}

/// Server-only Geoapify adapter for the existing controller. MAP02 owns form
/// wiring; production registration deliberately remains disabled in MAP01.
class ServerPlaceSearchGateway implements PlaceSearchGateway {
  ServerPlaceSearchGateway(
    SupabaseClient client, {
    required this.scope,
    this.enabled = false,
  }) : actor = (() => client.auth.currentUser?.id),
       invoke = ((body) async =>
           (await client.functions.invoke('location-search', body: body)).data);

  ServerPlaceSearchGateway.withEndpoint({
    required this.scope,
    required this.actor,
    required this.invoke,
    this.enabled = false,
  });

  final PlaceSearchScope scope;
  final bool enabled;
  final String? Function() actor;
  final LocationEndpoint invoke;

  @override
  bool get available => enabled && actor() == scope.actorId;

  void _checkActor() {
    if (actor() != scope.actorId) {
      throw const PlaceSearchFailure(PlaceSearchProblem.unauthorized);
    }
    if (!enabled) {
      throw const PlaceSearchFailure(PlaceSearchProblem.disabled);
    }
  }

  Future<Map<String, dynamic>> _call(
    String operation,
    String sessionToken,
    Map<String, dynamic> fields,
  ) async {
    _checkActor();
    final dynamic response;
    try {
      response = await invoke({
        'operation': operation,
        'expected_profile_id': scope.actorId,
        'item_kind': scope.itemKind,
        'item_id': scope.itemId,
        'revision': scope.revision,
        'slot': scope.slot,
        'session_token': sessionToken,
        ...fields,
      });
    } on FunctionException catch (error) {
      // The SDK throws for non-2xx responses before returning our envelope.
      // Never propagate its response body or reason phrase into UI/logs.
      throw PlaceSearchFailure(
        error.status == 0
            ? PlaceSearchProblem.offline
            : error.status == 401 || error.status == 403
            ? PlaceSearchProblem.unauthorized
            : PlaceSearchProblem.provider,
      );
    }
    _checkActor(); // Reject late data after account replacement.
    if (response is! Map<String, dynamic> || response['status'] is! String) {
      throw const FormatException('Invalid location endpoint envelope.');
    }
    if (response['status'] != 'ok') {
      throw PlaceSearchFailure(switch (response['status']) {
        'disabled' => PlaceSearchProblem.disabled,
        'unconfigured' => PlaceSearchProblem.unconfigured,
        'offline' => PlaceSearchProblem.offline,
        'timeout' => PlaceSearchProblem.timeout,
        'provider_quota' ||
        'budget_exhausted' ||
        'rate_limited' => PlaceSearchProblem.quota,
        'invalid_credentials' => PlaceSearchProblem.credentials,
        'metering_unavailable' => PlaceSearchProblem.metering,
        'expired_selection' => PlaceSearchProblem.expired,
        'stale_selection' => PlaceSearchProblem.stale,
        'unauthorized' => PlaceSearchProblem.unauthorized,
        'unsupported_source' ||
        'unsupported_place' => PlaceSearchProblem.unsupported,
        _ => PlaceSearchProblem.provider,
      });
    }
    return response;
  }

  @override
  Future<List<PlaceSuggestion>> search(PlaceSearchRequest request) async {
    final result = await _call('search', request.sessionToken, {
      'query': request.query,
      'language': request.language,
    });
    final rows = result['suggestions'];
    if (rows is! List || rows.length > 5) {
      throw const FormatException('Invalid bounded location suggestions.');
    }
    final parsed = rows.map(_parse).toList(growable: false);
    if (parsed.map((p) => p.suggestion.id).toSet().length != parsed.length) {
      throw const FormatException('Duplicate location receipts.');
    }
    return List.unmodifiable(parsed.map((p) => p.suggestion));
  }

  @override
  Future<ResolvedPlace> resolve(
    PlaceSuggestion suggestion,
    String sessionToken,
  ) async {
    final result = await _call('resolve', sessionToken, {
      'receipt_id': suggestion.id,
    });
    final place = _parse(result['selection']);
    if (place.suggestion.id != suggestion.id ||
        place.suggestion.label != suggestion.label ||
        place.suggestion.kind != suggestion.kind ||
        place.suggestion.expiresAt != suggestion.expiresAt) {
      throw const FormatException('Selection receipt changed.');
    }
    return place;
  }

  ResolvedPlace _parse(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['place'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid location selection.');
    }
    final place = value['place'] as Map<String, dynamic>;
    final kind = switch (place['kind']) {
      'locality' => PlaceKind.locality,
      'address' => PlaceKind.address,
      'amenity' => PlaceKind.amenity,
      _ => throw const FormatException('Invalid location precision.'),
    };
    if (place['country_code'] != 'IT' ||
        place['provider'] != 'geoapify' ||
        place['source'] != 'openstreetmap' ||
        place['latitude'] is! num ||
        place['longitude'] is! num ||
        place['locality'] is! String ||
        (place['administrative_area'] != null &&
            place['administrative_area'] is! String) ||
        place['source_license'] != 'https://www.openstreetmap.org/copyright' ||
        place['attribution'] !=
            'Powered by Geoapify | © OpenStreetMap contributors') {
      throw const FormatException('Invalid verified location provenance.');
    }
    final expiresAt = DateTime.parse(value['expires_at'] as String).toUtc();
    final verifiedAt = DateTime.parse(place['verified_at'] as String).toUtc();
    if (!expiresAt.isAfter(verifiedAt)) {
      throw const FormatException('Invalid selection lifetime.');
    }
    return ResolvedPlace(
      suggestion: PlaceSuggestion(
        id: value['id'] as String,
        label: place['label'] as String,
        countryCode: 'IT',
        kind: kind,
        expiresAt: expiresAt,
      ),
      locality: place['locality'] as String,
      administrativeArea: place['administrative_area'] as String?,
      point: PlacePoint(
        (place['latitude'] as num).toDouble(),
        (place['longitude'] as num).toDouble(),
      ),
      selectionReceipt: value['id'] as String,
      attribution: place['attribution'] as String,
      sourceLicense: place['source_license'] as String,
      verifiedAt: verifiedAt,
    );
  }
}
