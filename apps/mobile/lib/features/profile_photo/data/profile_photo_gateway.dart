import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/profile_photo_models.dart';
import '../domain/visible_profile_photo_models.dart';

const profilePhotoBucket = 'profile-photos';
const profilePhotoContentType = 'image/webp';
const profilePhotoMaxBytes = 256000;

abstract interface class ProfilePhotoGateway {
  Future<OwnProfilePhoto?> loadOwnPhoto(String expectedProfileId);

  Future<Uint8List> downloadOwnPhoto(String objectPath);

  Future<VisibleProfilePhoto?> loadVisiblePhoto(String profileId);

  Future<List<VisibleProfilePhoto>> loadVisiblePhotos(List<String> profileIds);

  Future<VisibleProfilePhoto?> loadProjectCreatorPhoto(String projectId);

  Future<Uint8List> downloadVisiblePhoto(String objectPath);

  Future<void> uploadNewPhoto(String objectPath, Uint8List webpBytes);

  Future<ProfilePhotoCommit> commitOwnPhoto(
    String expectedProfileId,
    String objectPath,
    ProfilePhotoAudience audience,
  );

  Future<ProfilePhotoAudienceChange> setAudience(
    String expectedProfileId,
    ProfilePhotoAudience audience,
  );

  Future<String?> clearOwnPhoto(String expectedProfileId);

  Future<void> deleteOwnObject(String objectPath);
}

abstract interface class ProfilePhotoRemoteApi {
  Future<Object?> rpc(String functionName, Map<String, dynamic> params);

  Future<Uint8List> download(String bucket, String objectPath);

  Future<void> upload(
    String bucket,
    String objectPath,
    Uint8List bytes, {
    required String contentType,
    required bool upsert,
  });

  Future<void> remove(String bucket, String objectPath);
}

class SupabaseProfilePhotoRemoteApi implements ProfilePhotoRemoteApi {
  const SupabaseProfilePhotoRemoteApi(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String functionName, Map<String, dynamic> params) async {
    return _client.rpc<dynamic>(functionName, params: params);
  }

  @override
  Future<Uint8List> download(String bucket, String objectPath) {
    return _client.storage.from(bucket).download(objectPath);
  }

  @override
  Future<void> upload(
    String bucket,
    String objectPath,
    Uint8List bytes, {
    required String contentType,
    required bool upsert,
  }) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: upsert),
        );
  }

  @override
  Future<void> remove(String bucket, String objectPath) async {
    await _client.storage.from(bucket).remove([objectPath]);
  }
}

class SupabaseProfilePhotoGateway implements ProfilePhotoGateway {
  const SupabaseProfilePhotoGateway(this._remote);

  final ProfilePhotoRemoteApi _remote;

  @override
  Future<OwnProfilePhoto?> loadOwnPhoto(String expectedProfileId) async {
    final response = await _remote.rpc('get_own_profile_photo', {
      'p_expected_profile_id': expectedProfileId,
    });
    final rows = _rows(response, operation: 'owner photo read');
    if (rows.isEmpty) return null;
    if (rows.length != 1) {
      throw const ProfilePhotoDataException(
        'Owner photo read returned multiple rows.',
      );
    }
    return OwnProfilePhoto.fromRpcRow(rows.single);
  }

  @override
  Future<Uint8List> downloadOwnPhoto(String objectPath) {
    return _remote.download(profilePhotoBucket, objectPath);
  }

  @override
  Future<VisibleProfilePhoto?> loadVisiblePhoto(String profileId) async {
    _requireProfileId(profileId);
    final response = await _remote.rpc('get_profile_photo_for_viewer', {
      'p_profile_id': profileId,
    });
    final rows = _rows(response, operation: 'viewer photo read');
    if (rows.isEmpty) return null;
    if (rows.length != 1) {
      throw const ProfilePhotoDataException(
        'Viewer photo read returned multiple rows.',
      );
    }
    final photo = VisibleProfilePhoto.fromRpcRow(rows.single);
    if (photo.profileId != profileId) {
      throw const ProfilePhotoDataException(
        'Viewer photo read returned another profile.',
      );
    }
    return photo;
  }

  @override
  Future<List<VisibleProfilePhoto>> loadVisiblePhotos(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty || profileIds.length > 50) {
      throw const ProfilePhotoDataException(
        'Viewer photo batches require between 1 and 50 target IDs.',
      );
    }
    for (final profileId in profileIds) {
      _requireProfileId(profileId);
    }

    final response = await _remote.rpc('list_profile_photos_for_viewer', {
      'p_profile_ids': profileIds,
    });
    final rows = _rows(response, operation: 'viewer photo batch read');
    final requested = profileIds.toSet();
    final seen = <String>{};
    String? previousProfileId;
    final photos = <VisibleProfilePhoto>[];
    for (final row in rows) {
      final photo = VisibleProfilePhoto.fromRpcRow(row);
      if (!requested.contains(photo.profileId) ||
          !seen.add(photo.profileId) ||
          (previousProfileId != null &&
              previousProfileId.compareTo(photo.profileId) >= 0)) {
        throw const ProfilePhotoDataException(
          'Viewer photo batch returned invalid targets or ordering.',
        );
      }
      previousProfileId = photo.profileId;
      photos.add(photo);
    }
    return List.unmodifiable(photos);
  }

  @override
  Future<VisibleProfilePhoto?> loadProjectCreatorPhoto(String projectId) async {
    _requireProfileId(projectId);
    final response = await _remote.rpc(
      'get_project_creator_profile_photo_for_viewer',
      {'p_project_id': projectId},
    );
    final rows = _rows(response, operation: 'project creator photo read');
    if (rows.isEmpty) return null;
    if (rows.length != 1) {
      throw const ProfilePhotoDataException(
        'Project creator photo read returned multiple rows.',
      );
    }
    return VisibleProfilePhoto.fromRpcRow(rows.single);
  }

  @override
  Future<Uint8List> downloadVisiblePhoto(String objectPath) {
    if (!isVisibleProfilePhotoPath(objectPath)) {
      throw const ProfilePhotoDataException(
        'Visible profile photo download path is invalid.',
      );
    }
    return _remote.download(profilePhotoBucket, objectPath);
  }

  @override
  Future<void> uploadNewPhoto(String objectPath, Uint8List webpBytes) {
    if (webpBytes.length > profilePhotoMaxBytes) {
      throw const ProfilePhotoDataException(
        'Processed profile photo exceeds the client limit.',
      );
    }
    return _remote.upload(
      profilePhotoBucket,
      objectPath,
      webpBytes,
      contentType: profilePhotoContentType,
      upsert: false,
    );
  }

  @override
  Future<ProfilePhotoCommit> commitOwnPhoto(
    String expectedProfileId,
    String objectPath,
    ProfilePhotoAudience audience,
  ) async {
    final response = await _remote.rpc('set_own_profile_photo', {
      'p_expected_profile_id': expectedProfileId,
      'p_object_path': objectPath,
      'p_audience': audience.wireValue,
    });
    return ProfilePhotoCommit.fromRpcRow(
      _singleRow(response, operation: 'owner photo commit'),
    );
  }

  @override
  Future<ProfilePhotoAudienceChange> setAudience(
    String expectedProfileId,
    ProfilePhotoAudience audience,
  ) async {
    final response = await _remote.rpc('set_own_profile_photo_audience', {
      'p_expected_profile_id': expectedProfileId,
      'p_audience': audience.wireValue,
    });
    return ProfilePhotoAudienceChange.fromRpcRow(
      _singleRow(response, operation: 'owner photo audience update'),
    );
  }

  @override
  Future<String?> clearOwnPhoto(String expectedProfileId) async {
    final response = await _remote.rpc('clear_own_profile_photo', {
      'p_expected_profile_id': expectedProfileId,
    });
    if (response == null || response is String) return response as String?;
    throw const ProfilePhotoDataException(
      'Owner photo clear returned an invalid response.',
    );
  }

  @override
  Future<void> deleteOwnObject(String objectPath) {
    return _remote.remove(profilePhotoBucket, objectPath);
  }

  static List<Map<String, dynamic>> _rows(
    Object? response, {
    required String operation,
  }) {
    if (response is! List) {
      throw ProfilePhotoDataException('$operation returned an invalid result.');
    }
    try {
      return response
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (_) {
      throw ProfilePhotoDataException('$operation returned an invalid row.');
    }
  }

  static Map<String, dynamic> _singleRow(
    Object? response, {
    required String operation,
  }) {
    final rows = _rows(response, operation: operation);
    if (rows.length != 1) {
      throw ProfilePhotoDataException(
        '$operation did not return exactly one row.',
      );
    }
    return rows.single;
  }

  static void _requireProfileId(String profileId) {
    if (!isProfilePhotoUuid(profileId)) {
      throw const ProfilePhotoDataException(
        'Viewer photo target must be a UUID.',
      );
    }
  }
}

class ProfilePhotoDataException implements Exception {
  const ProfilePhotoDataException(this.message);

  final String message;
}

final profilePhotoGatewayProvider = Provider<ProfilePhotoGateway>((ref) {
  final remote = SupabaseProfilePhotoRemoteApi(
    ref.watch(supabaseClientProvider),
  );
  return SupabaseProfilePhotoGateway(remote);
});
