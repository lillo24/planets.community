import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/place_search.dart';

/// Future adapters must enforce request limits, country restriction, retention
/// and attribution. No production adapter is approved or registered yet.
abstract interface class PlaceSearchGateway {
  bool get available;
  Future<List<PlaceSuggestion>> search(PlaceSearchRequest request);
  Future<ResolvedPlace> resolve(
    PlaceSuggestion suggestion,
    String sessionToken,
  );
}

class DisabledPlaceSearchGateway implements PlaceSearchGateway {
  const DisabledPlaceSearchGateway();
  @override
  bool get available => false;
  @override
  Future<List<PlaceSuggestion>> search(PlaceSearchRequest request) async =>
      throw const PlaceSearchFailure(PlaceSearchProblem.disabled);
  @override
  Future<ResolvedPlace> resolve(
    PlaceSuggestion suggestion,
    String sessionToken,
  ) async => throw const PlaceSearchFailure(PlaceSearchProblem.disabled);
}

// No flag/key silently activates paid traffic. Activation requires reviewed code.
final placeSearchGatewayProvider = Provider<PlaceSearchGateway>(
  (ref) => const DisabledPlaceSearchGateway(),
);
