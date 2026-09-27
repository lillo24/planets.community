import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_path_generator.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/profile_photo_models.dart';

void main() {
  test('UUID path generator creates fresh immutable owner paths', () {
    const generator = UuidProfilePhotoPathGenerator();
    final first = generator.newPath('profile-id');
    final second = generator.newPath('profile-id');

    expect(first, matches(RegExp(r'^profile-id/[0-9a-f-]{36}\.webp$')));
    expect(second, isNot(first));
  });

  group('SupabaseProfilePhotoGateway', () {
    late FakeProfilePhotoRemoteApi remote;
    late SupabaseProfilePhotoGateway gateway;

    setUp(() {
      remote = FakeProfilePhotoRemoteApi();
      gateway = SupabaseProfilePhotoGateway(remote);
    });

    test(
      'uses exact owner read RPC and downloads from private bucket',
      () async {
        remote.rpcResult = [_ownerRow()];

        final photo = await gateway.loadOwnPhoto('user-1');
        final bytes = await gateway.downloadOwnPhoto('user-1/version.webp');

        expect(photo?.audience, ProfilePhotoAudience.interactions);
        expect(remote.rpcNames, ['get_own_profile_photo']);
        expect(remote.rpcParams.single, {'p_expected_profile_id': 'user-1'});
        expect(bytes, remote.downloadResult);
        expect(remote.downloads, [('profile-photos', 'user-1/version.webp')]);
      },
    );

    test('empty owner read is the canonical no-photo state', () async {
      remote.rpcResult = [];
      expect(await gateway.loadOwnPhoto('user-1'), isNull);
    });

    test('uses the exact viewer RPC and treats zero rows as hidden', () async {
      remote.rpcResult = [_visibleRow(_viewerA)];

      final photo = await gateway.loadVisiblePhoto(_viewerA);

      expect(photo?.profileId, _viewerA);
      expect(photo?.objectPath, '$_viewerA/$_versionA.webp');
      expect(remote.rpcNames.single, 'get_profile_photo_for_viewer');
      expect(remote.rpcParams.single, {'p_profile_id': _viewerA});
      expect(remote.downloads, isEmpty);

      remote.rpcResult = [];
      expect(await gateway.loadVisiblePhoto(_viewerA), isNull);
    });

    test(
      'strict viewer rows reject cardinality and malformed metadata',
      () async {
        remote.rpcResult = [_visibleRow(_viewerA), _visibleRow(_viewerA)];
        await expectLater(
          gateway.loadVisiblePhoto(_viewerA),
          throwsA(isA<ProfilePhotoDataException>()),
        );

        for (final invalid in [
          {..._visibleRow(_viewerA), 'profile_id': 'not-a-uuid'},
          {..._visibleRow(_viewerA), 'object_path': '$_viewerA/avatar.webp'},
          {..._visibleRow(_viewerA), 'updated_at': 'not-a-timestamp'},
          {..._visibleRow(_viewerA), 'audience': 'public'},
        ]) {
          remote.rpcResult = [invalid];
          await expectLater(
            gateway.loadVisiblePhoto(_viewerA),
            throwsA(isA<FormatException>()),
          );
        }
      },
    );

    test(
      'batch keeps backend deduplication and authorized omissions',
      () async {
        remote.rpcResult = [_visibleRow(_viewerA), _visibleRow(_viewerB)];

        final photos = await gateway.loadVisiblePhotos([
          _viewerA,
          _viewerA,
          _viewerB,
          _viewerC,
        ]);

        expect(photos.map((photo) => photo.profileId), [_viewerA, _viewerB]);
        expect(remote.rpcNames.single, 'list_profile_photos_for_viewer');
        expect(remote.rpcParams.single, {
          'p_profile_ids': [_viewerA, _viewerA, _viewerB, _viewerC],
        });
        expect(remote.downloads, isEmpty);
      },
    );

    test('project creator read uses only the context project id', () async {
      remote.rpcResult = [_visibleRow(_viewerA)];

      final photo = await gateway.loadProjectCreatorPhoto(_viewerC);

      expect(photo?.profileId, _viewerA);
      expect(
        remote.rpcNames.single,
        'get_project_creator_profile_photo_for_viewer',
      );
      expect(remote.rpcParams.single, {'p_project_id': _viewerC});
      expect(remote.downloads, isEmpty);

      remote.rpcResult = [];
      expect(await gateway.loadProjectCreatorPhoto(_viewerC), isNull);
    });

    test('Resource owner read uses only the context listing id', () async {
      remote.rpcResult = [_visibleRow(_viewerA)];

      final photo = await gateway.loadResourceListingOwnerPhoto(_viewerC);

      expect(photo?.profileId, _viewerA);
      expect(
        remote.rpcNames.single,
        'get_resource_listing_owner_profile_photo_for_viewer',
      );
      expect(remote.rpcParams.single, {'p_listing_id': _viewerC});
      expect(remote.downloads, isEmpty);

      remote.rpcResult = [];
      expect(await gateway.loadResourceListingOwnerPhoto(_viewerC), isNull);
    });

    test(
      'batch rejects invalid bounds, targets, duplicates, and order',
      () async {
        await expectLater(
          gateway.loadVisiblePhotos([]),
          throwsA(isA<ProfilePhotoDataException>()),
        );
        await expectLater(
          gateway.loadVisiblePhotos(List.filled(51, _viewerA)),
          throwsA(isA<ProfilePhotoDataException>()),
        );
        await expectLater(
          gateway.loadVisiblePhotos(['bad-id']),
          throwsA(isA<ProfilePhotoDataException>()),
        );

        remote.rpcResult = [_visibleRow(_viewerA), _visibleRow(_viewerA)];
        await expectLater(
          gateway.loadVisiblePhotos([_viewerA]),
          throwsA(isA<ProfilePhotoDataException>()),
        );
        remote.rpcResult = [_visibleRow(_viewerB), _visibleRow(_viewerA)];
        await expectLater(
          gateway.loadVisiblePhotos([_viewerA, _viewerB]),
          throwsA(isA<ProfilePhotoDataException>()),
        );
        remote.rpcResult = [_visibleRow(_viewerC)];
        await expectLater(
          gateway.loadVisiblePhotos([_viewerA]),
          throwsA(isA<ProfilePhotoDataException>()),
        );
      },
    );

    test('downloads only well-formed authorized object paths', () async {
      final bytes = await gateway.downloadVisiblePhoto(
        '$_viewerA/$_versionA.webp',
      );

      expect(bytes, remote.downloadResult);
      expect(remote.downloads, [
        ('profile-photos', '$_viewerA/$_versionA.webp'),
      ]);
      expect(
        () => gateway.downloadVisiblePhoto('$_viewerA/avatar.webp'),
        throwsA(isA<ProfilePhotoDataException>()),
      );
    });

    test('strict owner read rejects invalid cardinality and fields', () async {
      remote.rpcResult = [_ownerRow(), _ownerRow()];
      await expectLater(
        gateway.loadOwnPhoto('user-1'),
        throwsA(isA<ProfilePhotoDataException>()),
      );
      remote.rpcResult = [
        {..._ownerRow(), 'audience': 'private'},
      ];
      await expectLater(
        gateway.loadOwnPhoto('user-1'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'uploads exact content type with upsert false and enforces guard',
      () async {
        final bytes = Uint8List(1024);
        await gateway.uploadNewPhoto('user-1/version.webp', bytes);

        expect(remote.uploads.single.bucket, 'profile-photos');
        expect(remote.uploads.single.path, 'user-1/version.webp');
        expect(remote.uploads.single.bytes, same(bytes));
        expect(remote.uploads.single.contentType, 'image/webp');
        expect(remote.uploads.single.upsert, isFalse);

        expect(
          () => gateway.uploadNewPhoto(
            'user-1/oversized.webp',
            Uint8List(profilePhotoMaxBytes + 1),
          ),
          throwsA(isA<ProfilePhotoDataException>()),
        );
        expect(remote.uploads, hasLength(1));
      },
    );

    test('uses exact commit RPC and strictly parses its one row', () async {
      remote.rpcResult = [
        {
          'current_object_path': 'user-1/new.webp',
          'previous_object_path': 'user-1/old.webp',
          'audience': 'public',
          'updated_at': '2026-09-26T12:00:00Z',
        },
      ];

      final commit = await gateway.commitOwnPhoto(
        'user-1',
        'user-1/new.webp',
        ProfilePhotoAudience.public,
      );

      expect(commit.previousObjectPath, 'user-1/old.webp');
      expect(remote.rpcNames.single, 'set_own_profile_photo');
      expect(remote.rpcParams.single, {
        'p_expected_profile_id': 'user-1',
        'p_object_path': 'user-1/new.webp',
        'p_audience': 'public',
      });

      remote.rpcResult = [];
      await expectLater(
        gateway.commitOwnPhoto(
          'user-1',
          'user-1/new.webp',
          ProfilePhotoAudience.public,
        ),
        throwsA(isA<ProfilePhotoDataException>()),
      );
    });

    test('uses exact audience and clear RPCs and owner delete', () async {
      remote.rpcResult = [
        {
          'profile_id': 'user-1',
          'object_path': 'user-1/version.webp',
          'audience': 'public',
          'updated_at': '2026-09-26T12:00:00Z',
        },
      ];
      final changed = await gateway.setAudience(
        'user-1',
        ProfilePhotoAudience.public,
      );
      expect(changed.audience, ProfilePhotoAudience.public);
      expect(remote.rpcNames.single, 'set_own_profile_photo_audience');
      expect(remote.rpcParams.single, {
        'p_expected_profile_id': 'user-1',
        'p_audience': 'public',
      });

      remote.rpcResult = 'user-1/version.webp';
      expect(await gateway.clearOwnPhoto('user-1'), 'user-1/version.webp');
      expect(remote.rpcNames.last, 'clear_own_profile_photo');
      expect(remote.rpcParams.last, {'p_expected_profile_id': 'user-1'});

      await gateway.deleteOwnObject('user-1/version.webp');
      expect(remote.removals, [('profile-photos', 'user-1/version.webp')]);
    });
  });
}

const _viewerA = 'a5000000-0000-4000-8000-000000000001';
const _viewerB = 'a5000000-0000-4000-8000-000000000002';
const _viewerC = 'a5000000-0000-4000-8000-000000000003';
const _versionA = 'a5100000-0000-4000-8000-000000000001';

Map<String, dynamic> _visibleRow(String profileId) => {
  'profile_id': profileId,
  'object_path': '$profileId/$_versionA.webp',
  'updated_at': '2026-09-26T12:00:00Z',
};

Map<String, dynamic> _ownerRow() => {
  'profile_id': 'user-1',
  'object_path': 'user-1/version.webp',
  'audience': 'interactions',
  'created_at': '2026-09-25T12:00:00Z',
  'updated_at': '2026-09-26T12:00:00Z',
};

class FakeProfilePhotoRemoteApi implements ProfilePhotoRemoteApi {
  Object? rpcResult;
  final downloadResult = Uint8List.fromList([1, 2, 3]);
  final List<String> rpcNames = [];
  final List<Map<String, dynamic>> rpcParams = [];
  final List<(String, String)> downloads = [];
  final List<UploadCall> uploads = [];
  final List<(String, String)> removals = [];

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
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    ));
  }

  @override
  Future<void> remove(String bucket, String objectPath) async {
    removals.add((bucket, objectPath));
  }
}

typedef UploadCall = ({
  String bucket,
  String path,
  Uint8List bytes,
  String contentType,
  bool upsert,
});
