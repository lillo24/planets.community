import 'dart:typed_data';

final RegExp _profilePhotoUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final RegExp _visibleProfilePhotoPathPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$',
);

bool isProfilePhotoUuid(String value) =>
    _profilePhotoUuidPattern.hasMatch(value);

bool isVisibleProfilePhotoPath(String value, {String? profileId}) {
  return _visibleProfilePhotoPathPattern.hasMatch(value) &&
      (profileId == null || value.startsWith('$profileId/'));
}

class VisibleProfilePhoto {
  const VisibleProfilePhoto({
    required this.profileId,
    required this.objectPath,
    required this.updatedAt,
  });

  factory VisibleProfilePhoto.fromRpcRow(Map<String, dynamic> row) {
    const expectedKeys = {'profile_id', 'object_path', 'updated_at'};
    if (row.length != expectedKeys.length ||
        !row.keys.every(expectedKeys.contains)) {
      throw const FormatException(
        'Visible profile photo metadata has an unexpected shape.',
      );
    }

    final profileId = row['profile_id'];
    final objectPath = row['object_path'];
    final updatedAtValue = row['updated_at'];
    if (profileId is! String || !isProfilePhotoUuid(profileId)) {
      throw const FormatException('Invalid visible profile ID.');
    }
    if (objectPath is! String ||
        !isVisibleProfilePhotoPath(objectPath, profileId: profileId)) {
      throw const FormatException('Invalid visible profile photo path.');
    }
    if (updatedAtValue is! String) {
      throw const FormatException('Invalid visible profile photo timestamp.');
    }
    final updatedAt = DateTime.tryParse(updatedAtValue);
    if (updatedAt == null) {
      throw const FormatException('Invalid visible profile photo timestamp.');
    }

    return VisibleProfilePhoto(
      profileId: profileId,
      objectPath: objectPath,
      updatedAt: updatedAt,
    );
  }

  final String profileId;
  final String objectPath;
  final DateTime updatedAt;

  String get versionKey => '$objectPath|${updatedAt.toUtc().toIso8601String()}';
}

enum VisibleProfilePhotoPhase { loading, ready, failure }

class VisibleProfilePhotoEntry {
  const VisibleProfilePhotoEntry({
    required this.targetProfileId,
    required this.phase,
    this.photo,
    this.imageBytes,
  });

  final String targetProfileId;
  final VisibleProfilePhotoPhase phase;
  final VisibleProfilePhoto? photo;
  final Uint8List? imageBytes;

  bool get hasVisiblePhoto => photo != null && imageBytes != null;
}

class VisibleProfilePhotoState {
  const VisibleProfilePhotoState({
    this.viewerProfileId,
    this.entries = const {},
  });

  final String? viewerProfileId;
  final Map<String, VisibleProfilePhotoEntry> entries;

  VisibleProfilePhotoEntry? entryFor(String targetProfileId) {
    return entries[targetProfileId];
  }

  VisibleProfilePhotoState withEntry(VisibleProfilePhotoEntry entry) {
    return VisibleProfilePhotoState(
      viewerProfileId: viewerProfileId,
      entries: Map.unmodifiable({...entries, entry.targetProfileId: entry}),
    );
  }

  VisibleProfilePhotoState without(String targetProfileId) {
    final next = {...entries}..remove(targetProfileId);
    return VisibleProfilePhotoState(
      viewerProfileId: viewerProfileId,
      entries: Map.unmodifiable(next),
    );
  }
}
