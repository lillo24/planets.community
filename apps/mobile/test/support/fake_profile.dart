import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';

class FakeProfileGateway implements ProfileGateway {
  FakeProfileGateway({ProfileEditorData? data})
    : data = data ?? profileFixture();

  ProfileEditorData data;
  Object? loadError;
  Object? updateError;
  Future<void>? updateDelay;
  ProfileEditorData Function(String userId)? loadData;
  Future<ProfileEditorData> Function(String userId)? loadResult;
  int loadCount = 0;
  int updateCount = 0;
  String? lastExpectedProfileId;
  ProfileUpdate? lastUpdate;

  @override
  Future<ProfileEditorData> loadOwnProfile(String userId) async {
    loadCount += 1;
    if (loadResult case final result?) return result(userId);
    if (loadError case final error?) {
      throw error;
    }
    return loadData?.call(userId) ?? data;
  }

  @override
  Future<void> updateOwnProfile(
    String expectedProfileId,
    ProfileUpdate update,
  ) async {
    updateCount += 1;
    lastExpectedProfileId = expectedProfileId;
    lastUpdate = update;
    if (updateDelay case final delay?) await delay;
    if (updateError case final error?) {
      throw error;
    }
    data = ProfileEditorData(
      profile: OwnProfile(
        id: data.profile.id,
        displayName: update.displayName.trim(),
        bio: update.bio.trim().isEmpty ? null : update.bio.trim(),
        updatedAt: DateTime.utc(2026, 9, 2, 20),
        selectedSkillIds: {...update.selectedSkillIds},
        visibility: {...update.visibility},
      ),
      categories: data.categories,
    );
  }
}

ProfileEditorData profileFixture({
  bool complete = false,
  String id = 'user-1',
  String displayName = 'Casey',
}) {
  const mural = ProfileSkill(
    id: 'skill-mural',
    categoryId: 'category-art',
    slug: 'mural-painting',
    label: 'Mural painting',
    sortOrder: 1,
  );
  const musician = ProfileSkill(
    id: 'skill-musician',
    categoryId: 'category-music',
    slug: 'musician',
    label: 'Musician',
    sortOrder: 1,
  );
  return ProfileEditorData(
    profile: OwnProfile(
      id: id,
      displayName: complete ? displayName : null,
      bio: complete ? 'Ready to help.' : null,
      updatedAt: DateTime.utc(2026, 9, 2),
      selectedSkillIds: complete ? {'skill-musician'} : {},
      visibility: const {
        ProfileFieldKey.displayName: ProfileAudience.public,
        ProfileFieldKey.bio: ProfileAudience.public,
        ProfileFieldKey.skills: ProfileAudience.public,
      },
    ),
    categories: const [
      ProfileSkillCategory(
        id: 'category-art',
        slug: 'art-creativity',
        label: 'Art & Creativity',
        sortOrder: 1,
        skills: [mural],
      ),
      ProfileSkillCategory(
        id: 'category-music',
        slug: 'music',
        label: 'Music',
        sortOrder: 2,
        skills: [musician],
      ),
    ],
  );
}
