import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/own_consequence_models.dart';

const ownConsequencePageSize = 20;

abstract interface class OwnConsequenceGateway {
  Future<OwnConsequencePage> listOwn({
    required String expectedProfileId,
    OwnConsequenceCursor? cursor,
  });
}

class OwnConsequenceRpcContract {
  const OwnConsequenceRpcContract();

  Map<String, dynamic> params(String profileId, OwnConsequenceCursor? cursor) =>
      {
        'p_expected_profile_id': profileId,
        'p_limit': ownConsequencePageSize,
        'p_before_applied_at': cursor?.appliedAt,
        'p_before_consequence_id': cursor?.consequenceId,
      };

  OwnConsequencePage parse(Object? response, {OwnConsequenceCursor? cursor}) {
    if (response is! List || response.length > ownConsequencePageSize) {
      throw const FormatException('Invalid notice page.');
    }
    final items = <OwnConsequence>[];
    final ids = <String>{};
    var beforeTime = cursor == null ? null : DateTime.parse(cursor.appliedAt);
    var beforeId = cursor?.consequenceId;
    for (final row in response) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid notice row.');
      }
      final item = OwnConsequence.fromJson(row);
      if (!ids.add(item.id) ||
          (beforeTime != null &&
              (item.appliedAt.isAfter(beforeTime) ||
                  (item.appliedAt.isAtSameMomentAs(beforeTime) &&
                      item.id.compareTo(beforeId!) >= 0)))) {
        throw const FormatException('Invalid notice page order.');
      }
      items.add(item);
      beforeTime = item.appliedAt;
      beforeId = item.id;
    }
    return OwnConsequencePage(
      List.unmodifiable(items),
      hasMore: items.length == ownConsequencePageSize,
    );
  }
}

class SupabaseOwnConsequenceGateway implements OwnConsequenceGateway {
  const SupabaseOwnConsequenceGateway(
    this._client, {
    this.contract = const OwnConsequenceRpcContract(),
  });

  final SupabaseClient _client;
  final OwnConsequenceRpcContract contract;

  @override
  Future<OwnConsequencePage> listOwn({
    required String expectedProfileId,
    OwnConsequenceCursor? cursor,
  }) async {
    final response = await _client
        .rpc<Object?>(
          'list_own_moderation_consequences',
          params: contract.params(expectedProfileId, cursor),
        )
        .timeout(const Duration(seconds: 15));
    return contract.parse(response, cursor: cursor);
  }
}

final ownConsequenceGatewayProvider = Provider<OwnConsequenceGateway>(
  (ref) => SupabaseOwnConsequenceGateway(ref.watch(supabaseClientProvider)),
);
