import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/profile_models.dart';

abstract interface class ProfileGateway {
  Future<ProfileEditorData> loadOwnProfile(String userId);

  Future<void> updateOwnProfile(String expectedProfileId, ProfileUpdate update);
}

class SupabaseProfileGateway implements ProfileGateway {
  const SupabaseProfileGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileEditorData> loadOwnProfile(String userId) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('profiles')
          .select('id, display_name, bio, updated_at')
          .eq('id', userId)
          .maybeSingle(),
      _client
          .from('skill_categories')
          .select('id, slug, label, sort_order')
          .order('sort_order'),
      _client
          .from('skills')
          .select('id, category_id, slug, label, sort_order')
          .order('sort_order'),
      _client
          .from('profile_skills')
          .select('skill_id')
          .eq('profile_id', userId),
      _client
          .from('profile_field_visibility')
          .select('field_key, audience')
          .eq('profile_id', userId),
    ]);

    final profileRow = results[0] as Map<String, dynamic>?;
    if (profileRow == null) {
      throw const ProfileDataException('The profile anchor is unavailable.');
    }

    final categoryRows = (results[1] as List).cast<Map<String, dynamic>>();
    final skillRows = (results[2] as List).cast<Map<String, dynamic>>();
    final profileSkillRows = (results[3] as List).cast<Map<String, dynamic>>();
    final visibilityRows = (results[4] as List).cast<Map<String, dynamic>>();

    final skills = skillRows.map(_skillFromRow).toList(growable: false);
    final categories = categoryRows
        .map(
          (row) => ProfileSkillCategory(
            id: row['id'] as String,
            slug: row['slug'] as String,
            label: row['label'] as String,
            sortOrder: row['sort_order'] as int,
            skills: skills
                .where((skill) => skill.categoryId == row['id'])
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    final visibility = <ProfileFieldKey, ProfileAudience>{};
    for (final row in visibilityRows) {
      final field = ProfileFieldKey.fromWire(row['field_key'] as String);
      if (visibility.containsKey(field)) {
        throw const ProfileDataException('Profile visibility is inconsistent.');
      }
      visibility[field] = ProfileAudience.fromWire(row['audience'] as String);
    }
    if (visibility.length != ProfileFieldKey.values.length ||
        !visibility.keys.toSet().containsAll(ProfileFieldKey.values)) {
      throw const ProfileDataException('Profile visibility is incomplete.');
    }

    return ProfileEditorData(
      profile: OwnProfile(
        id: profileRow['id'] as String,
        displayName: profileRow['display_name'] as String?,
        bio: profileRow['bio'] as String?,
        updatedAt: DateTime.parse(profileRow['updated_at'] as String),
        selectedSkillIds: profileSkillRows
            .map((row) => row['skill_id'] as String)
            .toSet(),
        visibility: Map.unmodifiable(visibility),
      ),
      categories: List.unmodifiable(categories),
    );
  }

  @override
  Future<void> updateOwnProfile(
    String expectedProfileId,
    ProfileUpdate update,
  ) async {
    await _client.rpc<void>(
      'update_own_profile',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_display_name': update.displayName,
        'p_bio': update.bio,
        'p_skill_ids': update.selectedSkillIds.toList(growable: false),
        'p_display_name_audience':
            update.visibility[ProfileFieldKey.displayName]!.wireValue,
        'p_bio_audience': update.visibility[ProfileFieldKey.bio]!.wireValue,
        'p_skills_audience':
            update.visibility[ProfileFieldKey.skills]!.wireValue,
      },
    );
  }

  ProfileSkill _skillFromRow(Map<String, dynamic> row) => ProfileSkill(
    id: row['id'] as String,
    categoryId: row['category_id'] as String,
    slug: row['slug'] as String,
    label: row['label'] as String,
    sortOrder: row['sort_order'] as int,
  );
}

class ProfileDataException implements Exception {
  const ProfileDataException(this.message);

  final String message;
}

final profileGatewayProvider = Provider<ProfileGateway>((ref) {
  return SupabaseProfileGateway(ref.watch(supabaseClientProvider));
});
