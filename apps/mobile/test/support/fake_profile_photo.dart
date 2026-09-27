import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/profile_photo/application/profile_photo_path_generator.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_processor.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_picker.dart';
import 'package:planets_mobile/features/profile_photo/domain/profile_photo_models.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';

class FakeProfilePhotoGateway implements ProfilePhotoGateway {
  OwnProfilePhoto? photo;
  Uint8List downloadBytes = avatarPngBytes();
  Object? loadError;
  Object? downloadError;
  Object? uploadError;
  Object? commitError;
  Object? audienceError;
  Object? clearError;
  Object? deleteError;
  Future<OwnProfilePhoto?> Function(String profileId)? loadResult;
  Future<void>? uploadDelay;
  Future<ProfilePhotoCommit>? commitResult;
  final Map<String, VisibleProfilePhoto> visiblePhotos = {};
  final Map<String, VisibleProfilePhoto> projectCreatorPhotos = {};
  Object? visibleLoadError;
  Object? visibleDownloadError;
  Future<VisibleProfilePhoto?> Function(String profileId)? visibleLoadResult;
  Future<List<VisibleProfilePhoto>> Function(List<String> profileIds)?
  visibleBatchLoadResult;
  Future<Uint8List> Function(String objectPath)? visibleDownloadResult;
  final List<String> loadIds = [];
  final List<String> downloadPaths = [];
  final List<String> uploadPaths = [];
  final List<Uint8List> uploadedBytes = [];
  final List<String> commitIds = [];
  final List<ProfilePhotoAudience> committedAudiences = [];
  final List<ProfilePhotoAudience> audienceUpdates = [];
  final List<String> clearIds = [];
  final List<String> deletedPaths = [];
  final List<String> visibleLoadIds = [];
  final List<List<String>> visibleBatchLoadIds = [];
  final List<String> visibleDownloadPaths = [];
  final List<String> projectCreatorLoadIds = [];

  @override
  Future<OwnProfilePhoto?> loadOwnPhoto(String expectedProfileId) async {
    loadIds.add(expectedProfileId);
    final result = loadResult;
    if (result != null) return result(expectedProfileId);
    if (loadError case final error?) throw error;
    return photo;
  }

  @override
  Future<Uint8List> downloadOwnPhoto(String objectPath) async {
    downloadPaths.add(objectPath);
    if (downloadError case final error?) throw error;
    return downloadBytes;
  }

  @override
  Future<VisibleProfilePhoto?> loadVisiblePhoto(String profileId) async {
    visibleLoadIds.add(profileId);
    final result = visibleLoadResult;
    if (result != null) return result(profileId);
    if (visibleLoadError case final error?) throw error;
    return visiblePhotos[profileId];
  }

  @override
  Future<List<VisibleProfilePhoto>> loadVisiblePhotos(
    List<String> profileIds,
  ) async {
    visibleBatchLoadIds.add(List.unmodifiable(profileIds));
    final result = visibleBatchLoadResult;
    if (result != null) return result(profileIds);
    if (visibleLoadError case final error?) throw error;
    final photos = profileIds
        .map((profileId) => visiblePhotos[profileId])
        .whereType<VisibleProfilePhoto>()
        .toList();
    photos.sort((left, right) => left.profileId.compareTo(right.profileId));
    return List.unmodifiable(photos);
  }

  @override
  Future<VisibleProfilePhoto?> loadProjectCreatorPhoto(String projectId) async {
    projectCreatorLoadIds.add(projectId);
    if (visibleLoadError case final error?) throw error;
    return projectCreatorPhotos[projectId];
  }

  @override
  Future<Uint8List> downloadVisiblePhoto(String objectPath) async {
    visibleDownloadPaths.add(objectPath);
    final result = visibleDownloadResult;
    if (result != null) return result(objectPath);
    if (visibleDownloadError case final error?) throw error;
    return downloadBytes;
  }

  @override
  Future<void> uploadNewPhoto(String objectPath, Uint8List webpBytes) async {
    uploadPaths.add(objectPath);
    uploadedBytes.add(webpBytes);
    if (uploadDelay case final delay?) await delay;
    if (uploadError case final error?) throw error;
  }

  @override
  Future<ProfilePhotoCommit> commitOwnPhoto(
    String expectedProfileId,
    String objectPath,
    ProfilePhotoAudience audience,
  ) async {
    commitIds.add(expectedProfileId);
    committedAudiences.add(audience);
    if (commitError case final error?) throw error;
    final pending = commitResult;
    if (pending != null) return pending;
    final now = DateTime.utc(2026, 9, 26, 12);
    final result = ProfilePhotoCommit(
      currentObjectPath: objectPath,
      previousObjectPath: photo?.objectPath,
      audience: audience,
      updatedAt: now,
    );
    photo = OwnProfilePhoto(
      profileId: expectedProfileId,
      objectPath: objectPath,
      audience: audience,
      createdAt: photo?.createdAt ?? now,
      updatedAt: now,
    );
    return result;
  }

  @override
  Future<ProfilePhotoAudienceChange> setAudience(
    String expectedProfileId,
    ProfilePhotoAudience audience,
  ) async {
    audienceUpdates.add(audience);
    if (audienceError case final error?) throw error;
    final current = photo!;
    final now = DateTime.utc(2026, 9, 26, 13);
    photo = current.copyWith(audience: audience, updatedAt: now);
    return ProfilePhotoAudienceChange(
      profileId: expectedProfileId,
      objectPath: current.objectPath,
      audience: audience,
      updatedAt: now,
    );
  }

  @override
  Future<String?> clearOwnPhoto(String expectedProfileId) async {
    clearIds.add(expectedProfileId);
    if (clearError case final error?) throw error;
    final oldPath = photo?.objectPath;
    photo = null;
    return oldPath;
  }

  @override
  Future<void> deleteOwnObject(String objectPath) async {
    deletedPaths.add(objectPath);
    if (deleteError case final error?) throw error;
  }
}

class FakeProfilePhotoPicker implements ProfilePhotoPicker {
  Uint8List? result = Uint8List.fromList([1, 2, 3]);
  Object? error;
  int calls = 0;

  @override
  Future<Uint8List?> pickFromGallery() async {
    calls++;
    if (error case final value?) throw value;
    return result;
  }
}

class FakeProfilePhotoProcessor implements ProfilePhotoProcessor {
  ProcessedProfilePhoto result = ProcessedProfilePhoto(
    bytes: avatarPngBytes(),
    width: 512,
    height: 512,
    quality: 82,
    encodingAttempts: 1,
  );
  Object? error;
  Future<ProcessedProfilePhoto>? pendingResult;
  int calls = 0;

  @override
  Future<ProcessedProfilePhoto> process(Uint8List croppedBytes) async {
    calls++;
    final pending = pendingResult;
    if (pending != null) return pending;
    if (error case final value?) throw value;
    return result;
  }
}

class FakeProfilePhotoPathGenerator implements ProfilePhotoPathGenerator {
  FakeProfilePhotoPathGenerator({this.path = 'user-1/new-version.webp'});

  String path;
  int calls = 0;

  @override
  String newPath(String profileId) {
    calls++;
    return path;
  }
}

OwnProfilePhoto profilePhotoFixture({
  String profileId = 'user-1',
  String objectPath = 'user-1/current.webp',
  ProfilePhotoAudience audience = ProfilePhotoAudience.interactions,
}) {
  return OwnProfilePhoto(
    profileId: profileId,
    objectPath: objectPath,
    audience: audience,
    createdAt: DateTime.utc(2026, 9, 25),
    updatedAt: DateTime.utc(2026, 9, 26),
  );
}

Uint8List avatarPngBytes() {
  final avatar = image.Image(width: 4, height: 4);
  image.fill(avatar, color: image.ColorRgb8(40, 100, 180));
  return image.encodePng(avatar);
}
