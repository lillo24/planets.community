import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile_photo/application/project_creator_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';

import '../../../support/fake_profile_photo.dart';

void main() {
  test(
    'anonymous project context loads organizer metadata and bytes',
    () async {
      final harness = ProjectCreatorPhotoHarness();
      addTearDown(harness.dispose);
      harness.gateway.projectCreatorPhotos[_projectA] = _photo;

      await harness.controller.load(_projectA);

      expect(harness.state.viewerProfileId, isNull);
      expect(harness.state.entryFor(_projectA)?.hasVisiblePhoto, isTrue);
      expect(harness.gateway.projectCreatorLoadIds, [_projectA]);
      expect(harness.gateway.visibleLoadIds, isEmpty);
      expect(harness.gateway.visibleDownloadPaths, [_photo.objectPath]);
    },
  );

  test(
    'context denial or download failure stays a neutral placeholder',
    () async {
      final harness = ProjectCreatorPhotoHarness();
      addTearDown(harness.dispose);

      await harness.controller.load(_projectA);
      expect(
        harness.state.entryFor(_projectA)?.phase,
        VisibleProfilePhotoPhase.ready,
      );

      harness.gateway.projectCreatorPhotos[_projectB] = _photo;
      harness.gateway.visibleDownloadError = StateError('denied');
      await harness.controller.load(_projectB);
      expect(
        harness.state.entryFor(_projectB)?.phase,
        VisibleProfilePhotoPhase.failure,
      );
      expect(harness.state.entryFor(_projectB)?.imageBytes, isNull);
    },
  );

  test('account switch clears all contextual metadata and bytes', () async {
    final harness = ProjectCreatorPhotoHarness();
    addTearDown(harness.dispose);
    harness.gateway.projectCreatorPhotos[_projectA] = _photo;
    await harness.controller.load(_projectA);

    harness.session.markProfileReady(const AuthIdentity(id: _viewer));

    expect(harness.state.viewerProfileId, _viewer);
    expect(harness.state.entries, isEmpty);
  });
}

class ProjectCreatorPhotoHarness {
  final gateway = FakeProfilePhotoGateway();
  late final ProviderContainer container = ProviderContainer(
    overrides: [profilePhotoGatewayProvider.overrideWithValue(gateway)],
  )..read(authSessionProvider.notifier).markSignedOut();

  AuthSessionController get session =>
      container.read(authSessionProvider.notifier);
  ProjectCreatorPhotoController get controller =>
      container.read(projectCreatorPhotoProvider.notifier);
  ProjectCreatorPhotoState get state =>
      container.read(projectCreatorPhotoProvider);

  void dispose() => container.dispose();
}

const _projectA = 'a6300000-0000-4000-8000-000000000001';
const _projectB = 'a6300000-0000-4000-8000-000000000002';
const _organizer = 'a6400000-0000-4000-8000-000000000001';
const _version = 'a6500000-0000-4000-8000-000000000001';
const _viewer = 'a6600000-0000-4000-8000-000000000001';
final _photo = VisibleProfilePhoto(
  profileId: _organizer,
  objectPath: '$_organizer/$_version.webp',
  updatedAt: DateTime.utc(2026, 9, 27),
);
