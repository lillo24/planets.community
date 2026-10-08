import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/item_location.dart';
import '../domain/place_search.dart';
import 'place_search_gateway.dart';
import 'server_place_search_gateway.dart';

abstract interface class ItemLocationGateway {
  Future<ItemLocation> read(String actor, String kind, String item);
  Future<int> apply(
    PlaceSearchScope scope, {
    required String requestId,
    required String action,
    String? receipt,
  });
}

typedef LocationRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> params,
);

class RpcItemLocationGateway implements ItemLocationGateway {
  const RpcItemLocationGateway(this.rpc);
  final LocationRpc rpc;
  Future<dynamic> _call(String name, Map<String, dynamic> params) async {
    try {
      return await rpc(name, params).timeout(const Duration(seconds: 10));
    } on PostgrestException catch (error) {
      // Only stable database codes cross the UI boundary; never its raw message.
      throw PlaceSearchFailure(switch (error.code) {
        '42501' || 'P0002' => PlaceSearchProblem.unauthorized,
        'PT409' || '40001' => PlaceSearchProblem.stale,
        '22023' => PlaceSearchProblem.expired,
        '55000' => PlaceSearchProblem.disabled,
        _ => PlaceSearchProblem.provider,
      });
    } on TimeoutException {
      throw const PlaceSearchFailure(PlaceSearchProblem.timeout);
    } on AuthException {
      throw const PlaceSearchFailure(PlaceSearchProblem.unauthorized);
    } catch (_) {
      throw const PlaceSearchFailure(PlaceSearchProblem.offline);
    }
  }

  @override
  Future<ItemLocation> read(String actor, String kind, String item) async =>
      ItemLocation.fromJson(
        Map<String, dynamic>.from(
          await _call('get_authorized_item_location_v1', {
            'p_expected_profile_id': actor,
            'p_kind': kind,
            'p_item': item,
          }) as Map,
        ),
      );
  @override
  Future<int> apply(
    PlaceSearchScope scope, {
    required String requestId,
    required String action,
    String? receipt,
  }) async {
    final revision = await _call('apply_item_location_v1', {
      'p_expected_profile_id': scope.actorId,
      'p_kind': scope.itemKind,
      'p_item': scope.itemId,
      'p_expected_revision': scope.revision,
      'p_request_id': requestId,
      'p_public_action': scope.slot == 'exact' ? 'unchanged' : action,
      'p_public_receipt': scope.slot == 'exact' ? null : receipt,
      'p_exact_action': scope.slot == 'exact' ? action : 'unchanged',
      'p_exact_receipt': scope.slot == 'exact' ? receipt : null,
    });
    return (revision as num).toInt();
  }
}

// Lazy client access permits disabled/manual editors without provider setup.
final itemLocationGatewayProvider = Provider<ItemLocationGateway>(
  (ref) => RpcItemLocationGateway(
    (name, params) =>
        ref.read(supabaseClientProvider).rpc<dynamic>(name, params: params),
  ),
);

abstract interface class EditorPlaceGatewayFactory {
  bool get available;
  PlaceSearchGateway create(PlaceSearchScope scope);
}

class FixedEditorPlaceGatewayFactory implements EditorPlaceGatewayFactory {
  const FixedEditorPlaceGatewayFactory(this.gateway);
  final PlaceSearchGateway gateway;
  @override
  bool get available => gateway.available;
  @override
  PlaceSearchGateway create(PlaceSearchScope scope) => gateway;
}

// Activation must deliberately replace this factory with a scoped server
// adapter. No key/flag silently enables traffic or bypasses server kill switches.
final editorPlaceGatewayFactoryProvider = Provider<EditorPlaceGatewayFactory>(
  (ref) =>
      FixedEditorPlaceGatewayFactory(ref.watch(placeSearchGatewayProvider)),
);
