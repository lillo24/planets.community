import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';

import '../../../support/fake_profile_photo.dart';

void main() {
  test('anonymous viewer loads an authorized public photo', () async {
    final harness = VisiblePhotoHarness();
    addTearDown(harness.dispose);
    harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(_targetA);

    await harness.controller.load(_targetA);

    final entry = harness.state.entryFor(_targetA);
    expect(harness.state.viewerProfileId, isNull);
    expect(entry?.phase, VisibleProfilePhotoPhase.ready);
    expect(entry?.hasVisiblePhoto, isTrue);
    expect(harness.gateway.visibleDownloadPaths, ['$_targetA/$_versionA.webp']);
  });

  test(
    'authenticated viewer loads public or interaction-authorized bytes',
    () async {
      final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
      addTearDown(harness.dispose);
      harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(_targetA);

      await harness.controller.load(_targetA);

      expect(harness.state.viewerProfileId, _viewerA);
      expect(harness.state.entryFor(_targetA)?.hasVisiblePhoto, isTrue);
    },
  );

  test('hidden photo is a ready absent state without a download', () async {
    final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
    addTearDown(harness.dispose);

    await harness.controller.load(_targetA);

    final entry = harness.state.entryFor(_targetA);
    expect(entry?.phase, VisibleProfilePhotoPhase.ready);
    expect(entry?.photo, isNull);
    expect(entry?.imageBytes, isNull);
    expect(harness.gateway.visibleDownloadPaths, isEmpty);
  });

  test('Storage failure degrades to a neutral failure state', () async {
    final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
    addTearDown(harness.dispose);
    harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(_targetA);
    harness.gateway.visibleDownloadError = StateError('Storage unavailable');

    await harness.controller.load(_targetA);

    final entry = harness.state.entryFor(_targetA);
    expect(entry?.phase, VisibleProfilePhotoPhase.failure);
    expect(entry?.imageBytes, isNull);
  });

  test('account switch clears cached metadata and private bytes', () async {
    final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
    addTearDown(harness.dispose);
    harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(_targetA);
    await harness.controller.load(_targetA);
    expect(harness.state.entryFor(_targetA)?.imageBytes, isNotNull);

    harness.session.markProfileReady(const AuthIdentity(id: _viewerB));

    expect(harness.state.viewerProfileId, _viewerB);
    expect(harness.state.entries, isEmpty);
  });

  test(
    'late metadata response from a previous identity is discarded',
    () async {
      final pending = Completer<VisibleProfilePhoto?>();
      final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
      addTearDown(harness.dispose);
      harness.gateway.visibleLoadResult = (_) => pending.future;

      final loading = harness.controller.load(_targetA);
      harness.session.markProfileReady(const AuthIdentity(id: _viewerB));
      pending.complete(visiblePhotoFixture(_targetA));
      await loading;

      expect(harness.state.viewerProfileId, _viewerB);
      expect(harness.state.entries, isEmpty);
      expect(harness.gateway.visibleDownloadPaths, isEmpty);
    },
  );

  test(
    'batch authorizes once, omits hidden targets, and downloads visible rows',
    () async {
      final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
      addTearDown(harness.dispose);
      harness.gateway.visiblePhotos
        ..[_targetA] = visiblePhotoFixture(_targetA)
        ..[_targetB] = visiblePhotoFixture(_targetB);

      await harness.controller.loadBatch([
        _targetB,
        _targetA,
        _targetA,
        _targetC,
      ]);

      expect(harness.gateway.visibleBatchLoadIds, [
        [_targetB, _targetA, _targetC],
      ]);
      expect(harness.gateway.visibleLoadIds, isEmpty);
      expect(harness.state.entryFor(_targetA)?.hasVisiblePhoto, isTrue);
      expect(harness.state.entryFor(_targetB)?.hasVisiblePhoto, isTrue);
      expect(
        harness.state.entryFor(_targetC)?.phase,
        VisibleProfilePhotoPhase.ready,
      );
      expect(harness.state.entryFor(_targetC)?.photo, isNull);
    },
  );

  test(
    'target invalidation clears one cached subject for participation handoff',
    () async {
      final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
      addTearDown(harness.dispose);
      harness.gateway.visiblePhotos
        ..[_targetA] = visiblePhotoFixture(_targetA)
        ..[_targetB] = visiblePhotoFixture(_targetB);
      await harness.controller.loadBatch([_targetA, _targetB]);

      harness.controller.invalidate(_targetA);

      expect(harness.state.entryFor(_targetA), isNull);
      expect(harness.state.entryFor(_targetB)?.hasVisiblePhoto, isTrue);
    },
  );

  test('a changed object version replaces cached bytes', () async {
    final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
    addTearDown(harness.dispose);
    harness.gateway.visibleDownloadResult = (path) async =>
        Uint8List.fromList(path.contains(_versionB) ? [9, 9] : [1, 1]);
    harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(_targetA);
    await harness.controller.load(_targetA);

    harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(
      _targetA,
      version: _versionB,
      updatedAt: DateTime.utc(2026, 9, 27),
    );
    await harness.controller.load(_targetA, force: true);

    expect(harness.state.entryFor(_targetA)?.imageBytes, [9, 9]);
    expect(harness.gateway.visibleDownloadPaths, [
      '$_targetA/$_versionA.webp',
      '$_targetA/$_versionB.webp',
    ]);
  });

  test(
    'unchanged path and timestamp reuse identity-bound memory bytes',
    () async {
      final harness = VisiblePhotoHarness(viewerProfileId: _viewerA);
      addTearDown(harness.dispose);
      harness.gateway.visiblePhotos[_targetA] = visiblePhotoFixture(_targetA);
      await harness.controller.load(_targetA);

      await harness.controller.load(_targetA, force: true);

      expect(harness.gateway.visibleDownloadPaths, [
        '$_targetA/$_versionA.webp',
      ]);
    },
  );
}

class VisiblePhotoHarness {
  VisiblePhotoHarness({String? viewerProfileId}) {
    if (viewerProfileId == null) {
      session.markSignedOut();
    } else {
      session.markProfileReady(AuthIdentity(id: viewerProfileId));
    }
  }

  final gateway = FakeProfilePhotoGateway();
  late final ProviderContainer container = ProviderContainer(
    overrides: [profilePhotoGatewayProvider.overrideWithValue(gateway)],
  );

  AuthSessionController get session =>
      container.read(authSessionProvider.notifier);
  VisibleProfilePhotoController get controller =>
      container.read(visibleProfilePhotoProvider.notifier);
  VisibleProfilePhotoState get state =>
      container.read(visibleProfilePhotoProvider);

  void dispose() => container.dispose();
}

const _viewerA = 'a6000000-0000-4000-8000-000000000001';
const _viewerB = 'a6000000-0000-4000-8000-000000000002';
const _targetA = 'a6100000-0000-4000-8000-000000000001';
const _targetB = 'a6100000-0000-4000-8000-000000000002';
const _targetC = 'a6100000-0000-4000-8000-000000000003';
const _versionA = 'a6200000-0000-4000-8000-000000000001';
const _versionB = 'a6200000-0000-4000-8000-000000000002';

VisibleProfilePhoto visiblePhotoFixture(
  String profileId, {
  String version = _versionA,
  DateTime? updatedAt,
}) {
  return VisibleProfilePhoto(
    profileId: profileId,
    objectPath: '$profileId/$version.webp',
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 26),
  );
}
