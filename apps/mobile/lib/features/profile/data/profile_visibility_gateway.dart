import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/profile_models.dart';

abstract interface class ProfileVisibilityGateway {
  Future<Map<ProfileFieldKey, ProfileAudience>> load(String expectedProfileId);
  Future<void> update(
    String expectedProfileId,
    ProfileFieldKey field,
    ProfileAudience audience,
  );
}

class SupabaseProfileVisibilityGateway implements ProfileVisibilityGateway {
  const SupabaseProfileVisibilityGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<ProfileFieldKey, ProfileAudience>> load(
    String expectedProfileId,
  ) async {
    final rows = await _client
        .from('profile_field_visibility')
        .select('field_key,audience')
        .eq('profile_id', expectedProfileId);
    final values = <ProfileFieldKey, ProfileAudience>{};
    for (final row in rows) {
      final field = ProfileFieldKey.fromWire(row['field_key'] as String);
      if (values.containsKey(field)) {
        throw const FormatException('Duplicate profile visibility field.');
      }
      values[field] = ProfileAudience.fromWire(row['audience'] as String);
    }
    if (values.length != ProfileFieldKey.values.length) {
      throw const FormatException('Incomplete owner profile visibility.');
    }
    return Map.unmodifiable(values);
  }

  @override
  Future<void> update(
    String expectedProfileId,
    ProfileFieldKey field,
    ProfileAudience audience,
  ) async {
    // Existing owner SELECT/UPDATE RLS and audience-only column grants remain
    // authoritative. Zero affected rows is a failure, never a successful save.
    final rows = await _client
        .from('profile_field_visibility')
        .update({'audience': audience.wireValue})
        .eq('profile_id', expectedProfileId)
        .eq('field_key', field.wireValue)
        .select('field_key,audience');
    if (rows.length != 1 ||
        rows.single['field_key'] != field.wireValue ||
        rows.single['audience'] != audience.wireValue) {
      throw const FormatException(
        'Owner visibility update did not affect exactly one field.',
      );
    }
  }
}

final profileVisibilityGatewayProvider = Provider<ProfileVisibilityGateway>(
  (ref) => SupabaseProfileVisibilityGateway(ref.watch(supabaseClientProvider)),
);
