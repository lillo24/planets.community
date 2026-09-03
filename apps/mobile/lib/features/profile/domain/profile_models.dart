enum ProfileAudience {
  public('public'),
  private('private');

  const ProfileAudience(this.wireValue);

  final String wireValue;

  static ProfileAudience fromWire(String value) => switch (value) {
    'public' => ProfileAudience.public,
    'private' => ProfileAudience.private,
    _ => throw const FormatException('Unsupported profile audience.'),
  };
}

enum ProfileFieldKey {
  displayName('display_name'),
  bio('bio'),
  skills('skills');

  const ProfileFieldKey(this.wireValue);

  final String wireValue;

  static ProfileFieldKey fromWire(String value) => switch (value) {
    'display_name' => ProfileFieldKey.displayName,
    'bio' => ProfileFieldKey.bio,
    'skills' => ProfileFieldKey.skills,
    _ => throw const FormatException('Unsupported profile field.'),
  };
}

class ProfileSkill {
  const ProfileSkill({
    required this.id,
    required this.categoryId,
    required this.slug,
    required this.label,
    required this.sortOrder,
  });

  final String id;
  final String categoryId;
  final String slug;
  final String label;
  final int sortOrder;
}

class ProfileSkillCategory {
  const ProfileSkillCategory({
    required this.id,
    required this.slug,
    required this.label,
    required this.sortOrder,
    required this.skills,
  });

  final String id;
  final String slug;
  final String label;
  final int sortOrder;
  final List<ProfileSkill> skills;
}

class OwnProfile {
  const OwnProfile({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.updatedAt,
    required this.selectedSkillIds,
    required this.visibility,
  });

  final String id;
  final String? displayName;
  final String? bio;
  final DateTime updatedAt;
  final Set<String> selectedSkillIds;
  final Map<ProfileFieldKey, ProfileAudience> visibility;

  bool get isComplete => displayName != null;
}

class ProfileEditorData {
  const ProfileEditorData({required this.profile, required this.categories});

  final OwnProfile profile;
  final List<ProfileSkillCategory> categories;
}

class ProfileUpdate {
  const ProfileUpdate({
    required this.displayName,
    required this.bio,
    required this.selectedSkillIds,
    required this.visibility,
  });

  final String displayName;
  final String bio;
  final Set<String> selectedSkillIds;
  final Map<ProfileFieldKey, ProfileAudience> visibility;
}

enum ProfileFailureKind { invalidInput, unavailable, unexpected }

enum ProfilePhase { idle, loading, ready, saving, failure }

class ProfileState {
  const ProfileState({this.phase = ProfilePhase.idle, this.data, this.failure});

  final ProfilePhase phase;
  final ProfileEditorData? data;
  final ProfileFailureKind? failure;

  bool get isBusy =>
      phase == ProfilePhase.loading || phase == ProfilePhase.saving;
}

bool isValidDisplayName(String value) {
  final trimmed = value.trim();
  return trimmed.length >= 2 && trimmed.length <= 60;
}

bool isValidBio(String value) => value.trim().length <= 500;
