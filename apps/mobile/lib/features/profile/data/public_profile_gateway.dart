import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/public_profile.dart';

abstract interface class PublicProfileGateway {
  Future<PublicProfile?> load(String profileId);
}

class SupabasePublicProfileGateway implements PublicProfileGateway {
  const SupabasePublicProfileGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<PublicProfile?> load(String profileId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_public_profile',
      params: {'p_profile_id': profileId},
    );
    if (rows.isEmpty) return null;
    if (rows.length != 1 || rows.single is! Map<String, dynamic>) {
      throw const FormatException(
        'Public profile read did not return one sanitized row.',
      );
    }
    final profile = PublicProfile.fromRow(rows.single as Map<String, dynamic>);
    if (profile.profileId != profileId) {
      throw const FormatException(
        'Public profile read returned another identity.',
      );
    }
    return profile;
  }
}

final publicProfileGatewayProvider = Provider<PublicProfileGateway>(
  (ref) => SupabasePublicProfileGateway(ref.watch(supabaseClientProvider)),
);
