import 'profile_models.dart';

/// Only the sanitized exact-ID projection; never owner records or context data.
class PublicProfile {
  const PublicProfile({
    required this.profileId,
    this.displayName,
    this.bio,
    this.skills = const [],
  });
  final String profileId;
  final String? displayName;
  final String? bio;
  final List<ProfileSkill> skills;

  factory PublicProfile.fromRow(Map<String, dynamic> row) {
    const keys = {'profile_id', 'display_name', 'bio', 'skills'};
    if (row.length != keys.length ||
        !row.keys.every(keys.contains) ||
        row['profile_id'] is! String ||
        row['skills'] is! List ||
        (row['display_name'] != null && row['display_name'] is! String) ||
        (row['bio'] != null && row['bio'] is! String)) {
      throw const FormatException('Invalid sanitized public profile.');
    }
    final skills = <ProfileSkill>[];
    final seen = <String>{};
    for (final value in row['skills'] as List) {
      if (value is! Map ||
          [
            'id',
            'slug',
            'label',
            'category_id',
          ].any((key) => value[key] is! String) ||
          !seen.add(value['id'] as String)) {
        throw const FormatException('Invalid public profile skill.');
      }
      skills.add(
        ProfileSkill(
          id: value['id'] as String,
          categoryId: value['category_id'] as String,
          slug: value['slug'] as String,
          label: value['label'] as String,
          sortOrder: skills.length,
        ),
      );
    }
    return PublicProfile(
      profileId: row['profile_id'] as String,
      displayName: row['display_name'] as String?,
      bio: row['bio'] as String?,
      skills: List.unmodifiable(skills),
    );
  }
}
