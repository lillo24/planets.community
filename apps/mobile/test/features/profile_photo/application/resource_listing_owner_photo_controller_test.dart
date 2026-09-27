import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile_photo/application/resource_listing_owner_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';

import '../../../support/fake_profile_photo.dart';

void main() {
  test('anonymous listing context loads owner metadata and bytes', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.gateway.resourceListingOwnerPhotos[_listingA] = _photo;

    await harness.controller.load(_listingA);

    expect(harness.state.viewerProfileId, isNull);
    expect(harness.state.entryFor(_listingA)?.hasVisiblePhoto, isTrue);
    expect(harness.gateway.resourceListingOwnerLoadIds, [_listingA]);
    expect(harness.gateway.visibleLoadIds, isEmpty);
    expect(harness.gateway.visibleDownloadPaths, [_photo.objectPath]);
  });

  test('missing or failed context stays a neutral placeholder', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.load(_listingA);
    expect(
      harness.state.entryFor(_listingA)?.phase,
      VisibleProfilePhotoPhase.ready,
    );

    harness.gateway.resourceListingOwnerPhotos[_listingB] = _photo;
    harness.gateway.visibleDownloadError = StateError('denied');
    await harness.controller.load(_listingB);
    expect(
      harness.state.entryFor(_listingB)?.phase,
      VisibleProfilePhotoPhase.failure,
    );
    expect(harness.state.entryFor(_listingB)?.imageBytes, isNull);
  });

  test('account switch clears contextual metadata and bytes', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.gateway.resourceListingOwnerPhotos[_listingA] = _photo;
    await harness.controller.load(_listingA);

    harness.session.markProfileReady(const AuthIdentity(id: _viewer));

    expect(harness.state.viewerProfileId, _viewer);
    expect(harness.state.entries, isEmpty);
  });
}

class _Harness {
  final gateway = FakeProfilePhotoGateway();
  late final ProviderContainer container = ProviderContainer(
    overrides: [profilePhotoGatewayProvider.overrideWithValue(gateway)],
  )..read(authSessionProvider.notifier).markSignedOut();

  AuthSessionController get session =>
      container.read(authSessionProvider.notifier);
  ResourceListingOwnerPhotoController get controller =>
      container.read(resourceListingOwnerPhotoProvider.notifier);
  ResourceListingOwnerPhotoState get state =>
      container.read(resourceListingOwnerPhotoProvider);

  void dispose() => container.dispose();
}

const _listingA = 'b6300000-0000-4000-8000-000000000001';
const _listingB = 'b6300000-0000-4000-8000-000000000002';
const _owner = 'b6400000-0000-4000-8000-000000000001';
const _version = 'b6500000-0000-4000-8000-000000000001';
const _viewer = 'b6600000-0000-4000-8000-000000000001';
final _photo = VisibleProfilePhoto(
  profileId: _owner,
  objectPath: '$_owner/$_version.webp',
  updatedAt: DateTime.utc(2026, 9, 27),
);
