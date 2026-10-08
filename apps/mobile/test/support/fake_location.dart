import 'dart:async';

import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/data/place_search_gateway.dart';
import 'package:planets_mobile/features/locations/data/server_place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/item_location.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';

const syntheticArea = StoredPlace(
  label: 'Trento, Trentino',
  kind: PlaceKind.locality,
  locality: 'Trento',
  administrativeArea: 'Trentino',
);
const syntheticExact = StoredPlace(
  label: 'Synthetic side entrance, Trento',
  kind: PlaceKind.address,
  locality: 'Trento',
  administrativeArea: 'Trentino',
);

class FakeItemLocationGateway implements ItemLocationGateway {
  ItemLocation value = const ItemLocation(3);
  final calls = <String>[];
  final mutations = <(PlaceSearchScope, String, String, String?)>[];
  final accepted = <String, int>{};
  PlaceSearchProblem? readFailure, applyFailure;
  Future<void>? readDelay, applyDelay;
  bool loseNextResponse = false;
  @override
  Future<ItemLocation> read(String actor, String kind, String item) async {
    calls.add('read:$actor:$kind:$item');
    if (readDelay case final delay?) await delay;
    if (readFailure case final failure?) throw PlaceSearchFailure(failure);
    return value;
  }

  @override
  Future<int> apply(
    PlaceSearchScope scope, {
    required String requestId,
    required String action,
    String? receipt,
  }) async {
    calls.add('apply:${scope.slot}');
    mutations.add((scope, requestId, action, receipt));
    if (applyDelay case final delay?) await delay;
    if (applyFailure case final failure?) throw PlaceSearchFailure(failure);
    if (accepted[requestId] case final revision?) return revision;
    if (scope.revision != value.revision) {
      throw const PlaceSearchFailure(PlaceSearchProblem.stale);
    }
    value = ItemLocation(
      value.revision + 1,
      publicPlace: scope.slot == 'exact'
          ? value.publicPlace
          : action == 'clear'
          ? null
          : receipt == 'locality'
          ? syntheticArea
          : syntheticExact,
      exactPlace: scope.slot == 'exact'
          ? action == 'clear'
                ? null
                : syntheticExact
          : value.exactPlace,
    );
    accepted[requestId] = value.revision;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const PlaceSearchFailure(PlaceSearchProblem.offline);
    }
    return value.revision;
  }
}

class FakeEditorPlaceFactory implements EditorPlaceGatewayFactory {
  final FakePlaceSearchGateway gateway = FakePlaceSearchGateway();
  final scopes = <PlaceSearchScope>[];
  @override
  bool get available => gateway.available;
  @override
  PlaceSearchGateway create(PlaceSearchScope scope) {
    scopes.add(scope);
    return gateway;
  }
}

class FakePlaceSearchGateway implements PlaceSearchGateway {
  @override
  bool available = true;
  PlaceSearchProblem? failure;
  Future<List<PlaceSuggestion>>? searchReply;
  Future<ResolvedPlace>? resolveReply;
  final requests = <PlaceSearchRequest>[];
  int resolveCount = 0;
  @override
  Future<List<PlaceSuggestion>> search(PlaceSearchRequest request) async {
    requests.add(request);
    if (failure case final problem?) throw PlaceSearchFailure(problem);
    if (searchReply case final reply?) return reply;
    return [
      for (final kind in PlaceKind.values)
        PlaceSuggestion(
          id: kind.name,
          label: kind == PlaceKind.locality
              ? syntheticArea.label
              : syntheticExact.label,
          countryCode: 'IT',
          kind: kind,
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
    ];
  }

  @override
  Future<ResolvedPlace> resolve(PlaceSuggestion item, String session) async {
    resolveCount++;
    if (resolveReply case final reply?) return reply;
    return ResolvedPlace(
      suggestion: item,
      locality: 'Trento',
      administrativeArea: 'Trentino',
      point: PlacePoint(46, 11),
      selectionReceipt: item.id,
      attribution: 'Powered by Geoapify | © OpenStreetMap contributors',
      sourceLicense: 'https://www.openstreetmap.org/copyright',
      verifiedAt: DateTime.now(),
    );
  }
}
