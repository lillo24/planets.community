import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';

const _owner = 'c1000000-0000-4000-8000-000000000001';
const _project = 'c2000000-0000-4000-8000-000000000001';
const _version = 'c3000000-0000-4000-8000-000000000001';
const _path = '$_owner/projects/$_project/$_version.webp';

void main() {
  late FakeCoverMediaRemoteApi remote;
  late SupabaseCoverMediaGateway gateway;

  setUp(() {
    remote = FakeCoverMediaRemoteApi();
    gateway = SupabaseCoverMediaGateway(remote);
  });

  test('owner read maps the exact RPC and strict canonical row', () async {
    remote.rpcResult = [_ownerRow()];

    final cover = await gateway.loadOwnProjectCover(_owner, _project);

    expect(cover?.objectPath, _path);
    expect(remote.rpcNames.single, 'get_own_project_cover');
    expect(remote.rpcParams.single, {
      'p_expected_creator_profile_id': _owner,
      'p_project_id': _project,
    });
  });

  test(
    'owner read treats zero rows as no cover and rejects malformed rows',
    () async {
      remote.rpcResult = [];
      expect(await gateway.loadOwnProjectCover(_owner, _project), isNull);

      for (final invalid in [
        {..._ownerRow(), 'project_id': 'another-project'},
        {..._ownerRow(), 'object_path': 'unbound.webp'},
        {..._ownerRow(), 'updated_at': 'not-a-date'},
      ]) {
        remote.rpcResult = [invalid];
        await expectLater(
          gateway.loadOwnProjectCover(_owner, _project),
          throwsA(isA<CoverMediaDataException>()),
        );
      }
    },
  );

  test(
    'download and immutable upload use the private WebP bucket contract',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      expect(await gateway.downloadCover(_path), remote.downloadResult);
      await gateway.uploadProjectCover(_path, bytes);

      expect(remote.downloads.single, (coverMediaBucket, _path));
      expect(remote.uploads.single.bucket, coverMediaBucket);
      expect(remote.uploads.single.path, _path);
      expect(remote.uploads.single.contentType, coverMediaContentType);
      expect(remote.uploads.single.upsert, isFalse);
    },
  );

  test('upload rejects bytes above the backend hard limit', () async {
    expect(
      () =>
          gateway.uploadProjectCover(_path, Uint8List(coverMediaMaxBytes + 1)),
      throwsA(isA<CoverMediaDataException>()),
    );
    expect(remote.uploads, isEmpty);
  });

  test('set and clear map exact owner-bound RPC contracts', () async {
    remote.rpcResult = [
      {
        'current_object_path': _path,
        'previous_object_path': null,
        'updated_at': '2026-09-02T10:00:00Z',
      },
    ];

    final commit = await gateway.setOwnProjectCover(_owner, _project, _path);
    expect(commit.currentObjectPath, _path);
    expect(remote.rpcNames.last, 'set_own_project_cover');
    expect(remote.rpcParams.last, {
      'p_expected_creator_profile_id': _owner,
      'p_project_id': _project,
      'p_object_path': _path,
    });

    remote.rpcResult = _path;
    expect(await gateway.clearOwnProjectCover(_owner, _project), _path);
    expect(remote.rpcNames.last, 'clear_own_project_cover');
    expect(remote.rpcParams.last, {
      'p_expected_creator_profile_id': _owner,
      'p_project_id': _project,
    });
  });

  test('set rejects malformed current and previous paths', () async {
    for (final row in [
      {
        'current_object_path': 'wrong.webp',
        'previous_object_path': null,
        'updated_at': '2026-09-02T10:00:00Z',
      },
      {
        'current_object_path': _path,
        'previous_object_path':
            '$_owner/projects/another-project/$_version.webp',
        'updated_at': '2026-09-02T10:00:00Z',
      },
      {
        'current_object_path': _path,
        'previous_object_path': null,
        'updated_at': 'not-a-date',
      },
    ]) {
      remote.rpcResult = [row];
      await expectLater(
        gateway.setOwnProjectCover(_owner, _project, _path),
        throwsA(isA<CoverMediaDataException>()),
      );
    }
  });

  test('clear rejects a path bound to another Project', () async {
    remote.rpcResult = '$_owner/projects/another-project/$_version.webp';

    await expectLater(
      gateway.clearOwnProjectCover(_owner, _project),
      throwsA(isA<CoverMediaDataException>()),
    );
  });

  test('delete is scoped to the cover bucket', () async {
    await gateway.deleteOwnObject(_path);
    expect(remote.removals.single, (coverMediaBucket, _path));
  });
}

Map<String, dynamic> _ownerRow() => {
  'project_id': _project,
  'object_path': _path,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-02T10:00:00Z',
};

class FakeCoverMediaRemoteApi implements CoverMediaRemoteApi {
  Object? rpcResult;
  Uint8List downloadResult = Uint8List.fromList([9, 8, 7]);
  final rpcNames = <String>[];
  final rpcParams = <Map<String, dynamic>>[];
  final downloads = <(String, String)>[];
  final uploads =
      <({String bucket, String path, String contentType, bool upsert})>[];
  final removals = <(String, String)>[];

  @override
  Future<Object?> rpc(String functionName, Map<String, dynamic> params) async {
    rpcNames.add(functionName);
    rpcParams.add(params);
    return rpcResult;
  }

  @override
  Future<Uint8List> download(String bucket, String objectPath) async {
    downloads.add((bucket, objectPath));
    return downloadResult;
  }

  @override
  Future<void> upload(
    String bucket,
    String objectPath,
    Uint8List bytes, {
    required String contentType,
    required bool upsert,
  }) async {
    uploads.add((
      bucket: bucket,
      path: objectPath,
      contentType: contentType,
      upsert: upsert,
    ));
  }

  @override
  Future<void> remove(String bucket, String objectPath) async {
    removals.add((bucket, objectPath));
  }
}
