import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';

abstract interface class OwnInteractionRestrictionGateway {
  Future<bool> isActive(String expectedProfileId);
}

class SupabaseOwnInteractionRestrictionGateway
    implements OwnInteractionRestrictionGateway {
  const SupabaseOwnInteractionRestrictionGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isActive(String expectedProfileId) async {
    final response = await _client
        .rpc<Object?>(
          'get_own_interaction_restriction_status',
          params: {'p_expected_profile_id': expectedProfileId},
        )
        .timeout(const Duration(seconds: 15));
    // Unknown/malformed transport is a failed explanation check, never inactive.
    if (response is! bool) {
      throw const FormatException('Invalid own restriction status.');
    }
    return response;
  }
}

final ownInteractionRestrictionGatewayProvider =
    Provider<OwnInteractionRestrictionGateway>(
      (ref) => SupabaseOwnInteractionRestrictionGateway(
        ref.watch(supabaseClientProvider),
      ),
    );
