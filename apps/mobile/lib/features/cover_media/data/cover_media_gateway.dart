import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/cover_media_path.dart';
import '../../../core/backend/supabase_backend.dart';
import '../domain/cover_media_models.dart';

const coverMediaBucket = 'cover-images';
const coverMediaContentType = 'image/webp';
const coverMediaMaxBytes = 512 * 1024;

abstract interface class CoverMediaGateway {
  Future<OwnProjectCover?> loadOwnProjectCover(
    String expectedProfileId,
    String projectId,
  );

  Future<Uint8List> downloadCover(String objectPath);

  Future<void> uploadProjectCover(String objectPath, Uint8List webpBytes);

  Future<ProjectCoverCommit> setOwnProjectCover(
    String expectedProfileId,
    String projectId,
    String objectPath,
  );

  Future<String?> clearOwnProjectCover(
    String expectedProfileId,
    String projectId,
  );

  Future<void> deleteOwnObject(String objectPath);
}

abstract interface class CoverMediaRemoteApi {
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

class SupabaseCoverMediaRemoteApi implements CoverMediaRemoteApi {
  const SupabaseCoverMediaRemoteApi(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String functionName, Map<String, dynamic> params) {
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

class SupabaseCoverMediaGateway implements CoverMediaGateway {
  const SupabaseCoverMediaGateway(this._remote);

  final CoverMediaRemoteApi _remote;

  @override
  Future<OwnProjectCover?> loadOwnProjectCover(
    String expectedProfileId,
    String projectId,
  ) async {
    final response = await _remote.rpc('get_own_project_cover', {
      'p_expected_creator_profile_id': expectedProfileId,
      'p_project_id': projectId,
    });
    final rows = _rows(response, operation: 'Owner Project cover read');
    if (rows.isEmpty) return null;
    if (rows.length != 1) {
      throw const CoverMediaDataException(
        'Owner Project cover read returned multiple rows.',
      );
    }
    final cover = OwnProjectCover.fromRpcRow(rows.single);
    if (cover.projectId != projectId) {
      throw const CoverMediaDataException(
        'Owner Project cover read returned another Project.',
      );
    }
    return cover;
  }

  @override
  Future<Uint8List> downloadCover(String objectPath) {
    return _remote.download(coverMediaBucket, objectPath);
  }

  @override
  Future<void> uploadProjectCover(String objectPath, Uint8List webpBytes) {
    if (webpBytes.length > coverMediaMaxBytes) {
      throw const CoverMediaDataException(
        'Processed cover image exceeds the client limit.',
      );
    }
    return _remote.upload(
      coverMediaBucket,
      objectPath,
      webpBytes,
      contentType: coverMediaContentType,
      upsert: false,
    );
  }

  @override
  Future<ProjectCoverCommit> setOwnProjectCover(
    String expectedProfileId,
    String projectId,
    String objectPath,
  ) async {
    final response = await _remote.rpc('set_own_project_cover', {
      'p_expected_creator_profile_id': expectedProfileId,
      'p_project_id': projectId,
      'p_object_path': objectPath,
    });
    return ProjectCoverCommit.fromRpcRow(
      _singleRow(response, operation: 'Project cover commit'),
      projectId: projectId,
    );
  }

  @override
  Future<String?> clearOwnProjectCover(
    String expectedProfileId,
    String projectId,
  ) async {
    final response = await _remote.rpc('clear_own_project_cover', {
      'p_expected_creator_profile_id': expectedProfileId,
      'p_project_id': projectId,
    });
    try {
      return parseCoverObjectPath(
        response,
        parentId: projectId,
        parentSegment: 'projects',
      );
    } on FormatException {
      throw const CoverMediaDataException(
        'Project cover clear returned an invalid object path.',
      );
    }
  }

  @override
  Future<void> deleteOwnObject(String objectPath) {
    return _remote.remove(coverMediaBucket, objectPath);
  }

  static List<Map<String, dynamic>> _rows(
    Object? response, {
    required String operation,
  }) {
    if (response is! List) {
      throw CoverMediaDataException('$operation returned an invalid result.');
    }
    try {
      return response
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (_) {
      throw CoverMediaDataException('$operation returned an invalid row.');
    }
  }

  static Map<String, dynamic> _singleRow(
    Object? response, {
    required String operation,
  }) {
    final rows = _rows(response, operation: operation);
    if (rows.length != 1) {
      throw CoverMediaDataException(
        '$operation did not return exactly one row.',
      );
    }
    return rows.single;
  }
}

final coverMediaGatewayProvider = Provider<CoverMediaGateway>((ref) {
  return SupabaseCoverMediaGateway(
    SupabaseCoverMediaRemoteApi(ref.watch(supabaseClientProvider)),
  );
});
