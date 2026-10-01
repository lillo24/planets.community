import 'dart:typed_data';

enum ProfilePhotoAudience {
  public('public'),
  interactions('interactions');

  const ProfilePhotoAudience(this.wireValue);

  final String wireValue;

  static ProfilePhotoAudience fromWire(Object? value) => switch (value) {
    'public' => ProfilePhotoAudience.public,
    'interactions' => ProfilePhotoAudience.interactions,
    _ => throw const FormatException('Unsupported profile photo audience.'),
  };
}

class OwnProfilePhoto {
  const OwnProfilePhoto({
    required this.profileId,
    required this.objectPath,
    required this.audience,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OwnProfilePhoto.fromRpcRow(Map<String, dynamic> row) {
    return OwnProfilePhoto(
      profileId: _requiredString(row, 'profile_id'),
      objectPath: _requiredString(row, 'object_path'),
      audience: ProfilePhotoAudience.fromWire(row['audience']),
      createdAt: _requiredDateTime(row, 'created_at'),
      updatedAt: _requiredDateTime(row, 'updated_at'),
    );
  }

  final String profileId;
  final String objectPath;
  final ProfilePhotoAudience audience;
  final DateTime createdAt;
  final DateTime updatedAt;

  OwnProfilePhoto copyWith({
    ProfilePhotoAudience? audience,
    DateTime? updatedAt,
  }) {
    return OwnProfilePhoto(
      profileId: profileId,
      objectPath: objectPath,
      audience: audience ?? this.audience,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProfilePhotoCommit {
  const ProfilePhotoCommit({
    required this.currentObjectPath,
    required this.previousObjectPath,
    required this.audience,
    required this.updatedAt,
  });

  factory ProfilePhotoCommit.fromRpcRow(Map<String, dynamic> row) {
    final previousObjectPath = row['previous_object_path'];
    if (previousObjectPath != null && previousObjectPath is! String) {
      throw const FormatException('Invalid previous profile photo path.');
    }
    return ProfilePhotoCommit(
      currentObjectPath: _requiredString(row, 'current_object_path'),
      previousObjectPath: previousObjectPath as String?,
      audience: ProfilePhotoAudience.fromWire(row['audience']),
      updatedAt: _requiredDateTime(row, 'updated_at'),
    );
  }

  final String currentObjectPath;
  final String? previousObjectPath;
  final ProfilePhotoAudience audience;
  final DateTime updatedAt;
}

class ProfilePhotoAudienceChange {
  const ProfilePhotoAudienceChange({
    required this.profileId,
    required this.objectPath,
    required this.audience,
    required this.updatedAt,
  });

  factory ProfilePhotoAudienceChange.fromRpcRow(Map<String, dynamic> row) {
    return ProfilePhotoAudienceChange(
      profileId: _requiredString(row, 'profile_id'),
      objectPath: _requiredString(row, 'object_path'),
      audience: ProfilePhotoAudience.fromWire(row['audience']),
      updatedAt: _requiredDateTime(row, 'updated_at'),
    );
  }

  final String profileId;
  final String objectPath;
  final ProfilePhotoAudience audience;
  final DateTime updatedAt;
}

class ProcessedProfilePhoto {
  const ProcessedProfilePhoto({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
    required this.encodingAttempts,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;
  final int encodingAttempts;

  int get byteLength => bytes.length;
}

enum ProfilePhotoPhase {
  idle,
  loading,
  ready,
  picking,
  cropping,
  processing,
  uploading,
  updatingAudience,
  removing,
  failure,
}

enum ProfilePhotoFailureKind {
  read,
  sourceRead,
  prepare,
  tooLarge,
  upload,
  save,
  remove,
}

class ProfilePhotoState {
  const ProfilePhotoState({
    this.profileId,
    this.phase = ProfilePhotoPhase.idle,
    this.photo,
    this.imageBytes,
    this.failure,
  });

  final String? profileId;
  final ProfilePhotoPhase phase;
  final OwnProfilePhoto? photo;
  final Uint8List? imageBytes;
  final ProfilePhotoFailureKind? failure;

  bool get hasPhoto => photo != null;

  bool get isBusy => switch (phase) {
    ProfilePhotoPhase.loading ||
    ProfilePhotoPhase.picking ||
    ProfilePhotoPhase.cropping ||
    ProfilePhotoPhase.processing ||
    ProfilePhotoPhase.uploading ||
    ProfilePhotoPhase.updatingAudience ||
    ProfilePhotoPhase.removing => true,
    _ => false,
  };

  ProfilePhotoState copyWith({
    String? profileId,
    ProfilePhotoPhase? phase,
    OwnProfilePhoto? photo,
    Uint8List? imageBytes,
    ProfilePhotoFailureKind? failure,
    bool clearPhoto = false,
    bool clearImageBytes = false,
    bool clearFailure = false,
  }) {
    return ProfilePhotoState(
      profileId: profileId ?? this.profileId,
      phase: phase ?? this.phase,
      photo: clearPhoto ? null : photo ?? this.photo,
      imageBytes: clearImageBytes ? null : imageBytes ?? this.imageBytes,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> row, String key) {
  final value = _requiredString(row, key);
  return DateTime.parse(value);
}
