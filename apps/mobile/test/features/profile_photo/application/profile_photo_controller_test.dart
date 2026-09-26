import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_path_generator.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_processor.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_picker.dart';
import 'package:planets_mobile/features/profile_photo/domain/profile_photo_models.dart';

import '../../../support/fake_profile_photo.dart';

void main() {
  test('initial absent photo becomes ready without photo', () async {
    final harness = PhotoHarness();
    addTearDown(harness.dispose);

    await harness.load();

    expect(harness.state.phase, ProfilePhotoPhase.ready);
    expect(harness.state.photo, isNull);
    expect(harness.gateway.downloadPaths, isEmpty);
  });

  test('existing metadata downloads authenticated owner bytes', () async {
    final harness = PhotoHarness()..gateway.photo = profilePhotoFixture();
    addTearDown(harness.dispose);

    await harness.load();

    expect(harness.state.phase, ProfilePhotoPhase.ready);
    expect(harness.state.photo?.objectPath, 'user-1/current.webp');
    expect(harness.state.imageBytes, harness.gateway.downloadBytes);
    expect(harness.gateway.downloadPaths, ['user-1/current.webp']);
  });

  test(
    'download failure keeps metadata and degrades to safe placeholder',
    () async {
      final harness = PhotoHarness()
        ..gateway.photo = profilePhotoFixture()
        ..gateway.downloadError = StateError('private Storage error');
      addTearDown(harness.dispose);

      await harness.load();

      expect(harness.state.photo, isNotNull);
      expect(harness.state.imageBytes, isNull);
      expect(harness.state.failure, ProfilePhotoFailureKind.read);
    },
  );

  test('first upload defaults to interactions', () async {
    final harness = PhotoHarness();
    addTearDown(harness.dispose);
    await harness.readyToCrop();

    expect(await harness.save(), isTrue);

    expect(harness.gateway.committedAudiences, [
      ProfilePhotoAudience.interactions,
    ]);
    expect(harness.state.photo?.audience, ProfilePhotoAudience.interactions);
    expect(harness.gateway.uploadPaths, ['user-1/new-version.webp']);
  });

  test('replacement preserves public and cleans the previous path', () async {
    final harness = PhotoHarness()
      ..gateway.photo = profilePhotoFixture(
        audience: ProfilePhotoAudience.public,
      );
    addTearDown(harness.dispose);
    await harness.readyToCrop();

    expect(await harness.save(), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(harness.gateway.committedAudiences, [ProfilePhotoAudience.public]);
    expect(harness.gateway.deletedPaths, ['user-1/current.webp']);
    expect(harness.state.photo?.objectPath, 'user-1/new-version.webp');
  });

  test('upload failure leaves previous canonical state unchanged', () async {
    final harness = PhotoHarness()
      ..gateway.photo = profilePhotoFixture()
      ..gateway.uploadError = StateError('raw upload failure');
    addTearDown(harness.dispose);
    await harness.readyToCrop();

    expect(await harness.save(), isFalse);

    expect(harness.state.photo?.objectPath, 'user-1/current.webp');
    expect(harness.state.failure, ProfilePhotoFailureKind.upload);
    expect(harness.gateway.commitIds, isEmpty);
  });

  test(
    'commit failure deletes new object and preserves previous photo',
    () async {
      final harness = PhotoHarness()
        ..gateway.photo = profilePhotoFixture()
        ..gateway.commitError = StateError('raw RPC failure');
      addTearDown(harness.dispose);
      await harness.readyToCrop();

      expect(await harness.save(), isFalse);

      expect(harness.gateway.deletedPaths, ['user-1/new-version.webp']);
      expect(harness.state.photo?.objectPath, 'user-1/current.webp');
      expect(harness.state.failure, ProfilePhotoFailureKind.save);
    },
  );

  test('old-object delete failure does not roll back commit success', () async {
    final harness = PhotoHarness()
      ..gateway.photo = profilePhotoFixture()
      ..gateway.deleteError = StateError('cleanup unavailable');
    addTearDown(harness.dispose);
    await harness.readyToCrop();

    expect(await harness.save(), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(harness.state.photo?.objectPath, 'user-1/new-version.webp');
    expect(harness.state.failure, isNull);
    expect(harness.gateway.deletedPaths, ['user-1/current.webp']);
  });

  test('audience changes both ways without uploading bytes', () async {
    final harness = PhotoHarness()
      ..gateway.photo = profilePhotoFixture(
        audience: ProfilePhotoAudience.public,
      );
    addTearDown(harness.dispose);
    await harness.load();

    expect(
      await harness.controller.updateAudience(
        'user-1',
        ProfilePhotoAudience.interactions,
      ),
      isTrue,
    );
    expect(
      await harness.controller.updateAudience(
        'user-1',
        ProfilePhotoAudience.public,
      ),
      isTrue,
    );

    expect(harness.gateway.audienceUpdates, [
      ProfilePhotoAudience.interactions,
      ProfilePhotoAudience.public,
    ]);
    expect(harness.gateway.uploadPaths, isEmpty);
    expect(harness.state.imageBytes, isNotNull);
  });

  test('remove clears canonical state then cleans returned object', () async {
    final harness = PhotoHarness()..gateway.photo = profilePhotoFixture();
    addTearDown(harness.dispose);
    await harness.load();

    expect(await harness.controller.remove('user-1'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(harness.state.photo, isNull);
    expect(harness.state.phase, ProfilePhotoPhase.ready);
    expect(harness.gateway.deletedPaths, ['user-1/current.webp']);
  });

  test('clear failure leaves existing photo visible', () async {
    final harness = PhotoHarness()
      ..gateway.photo = profilePhotoFixture()
      ..gateway.clearError = StateError('raw clear failure');
    addTearDown(harness.dispose);
    await harness.load();

    expect(await harness.controller.remove('user-1'), isFalse);

    expect(harness.state.photo?.objectPath, 'user-1/current.webp');
    expect(harness.state.failure, ProfilePhotoFailureKind.remove);
  });

  test('delete-after-clear failure leaves photo removed', () async {
    final harness = PhotoHarness()
      ..gateway.photo = profilePhotoFixture()
      ..gateway.deleteError = StateError('cleanup unavailable');
    addTearDown(harness.dispose);
    await harness.load();

    expect(await harness.controller.remove('user-1'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(harness.state.photo, isNull);
    expect(harness.state.failure, isNull);
  });

  test('duplicate save is rejected while processing is pending', () async {
    final pending = Completer<ProcessedProfilePhoto>();
    final harness = PhotoHarness();
    harness.processor.pendingResult = pending.future;
    addTearDown(harness.dispose);
    await harness.readyToCrop();

    final first = harness.save();
    expect(harness.state.phase, ProfilePhotoPhase.processing);
    expect(await harness.save(), isFalse);
    pending.complete(harness.processor.result);
    expect(await first, isTrue);

    expect(harness.processor.calls, 1);
    expect(harness.gateway.uploadPaths, hasLength(1));
  });

  test('picker cancellation is not an error', () async {
    final harness = PhotoHarness()..picker.result = null;
    addTearDown(harness.dispose);
    await harness.load();

    expect(await harness.controller.pickFromGallery('user-1'), isNull);

    expect(harness.state.phase, ProfilePhotoPhase.ready);
    expect(harness.state.failure, isNull);
  });

  test('account switch rejects stale owner load', () async {
    final oldLoad = Completer<OwnProfilePhoto?>();
    final harness = PhotoHarness();
    harness.gateway.loadResult = (id) =>
        id == 'user-1' ? oldLoad.future : Future<OwnProfilePhoto?>.value(null);
    addTearDown(harness.dispose);

    final loading = harness.controller.load('user-1');
    harness.session.markProfileReady(const AuthIdentity(id: 'user-2'));
    await harness.controller.load('user-2');
    oldLoad.complete(profilePhotoFixture());
    await loading;

    expect(harness.state.profileId, 'user-2');
    expect(harness.state.photo, isNull);
  });

  test('identity change after upload triggers cleanup and no commit', () async {
    final upload = Completer<void>();
    final harness = PhotoHarness()..gateway.uploadDelay = upload.future;
    addTearDown(harness.dispose);
    await harness.readyToCrop();

    final saving = harness.save();
    await Future<void>.delayed(Duration.zero);
    expect(harness.gateway.uploadPaths, ['user-1/new-version.webp']);
    harness.session.markProfileReady(const AuthIdentity(id: 'user-2'));
    upload.complete();
    expect(await saving, isFalse);

    expect(harness.gateway.commitIds, isEmpty);
    expect(harness.gateway.deletedPaths, ['user-1/new-version.webp']);
    expect(harness.state.profileId, isNull);
  });
}

class PhotoHarness {
  PhotoHarness() {
    session.markProfileReady(const AuthIdentity(id: 'user-1'));
  }

  final gateway = FakeProfilePhotoGateway();
  final picker = FakeProfilePhotoPicker();
  final processor = FakeProfilePhotoProcessor();
  final pathGenerator = FakeProfilePhotoPathGenerator();
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      profilePhotoGatewayProvider.overrideWithValue(gateway),
      profilePhotoPickerProvider.overrideWithValue(picker),
      profilePhotoProcessorProvider.overrideWithValue(processor),
      profilePhotoPathGeneratorProvider.overrideWithValue(pathGenerator),
    ],
  );

  AuthSessionController get session =>
      container.read(authSessionProvider.notifier);
  ProfilePhotoController get controller =>
      container.read(profilePhotoProvider.notifier);
  ProfilePhotoState get state => container.read(profilePhotoProvider);

  Future<void> load() => controller.load('user-1');

  Future<void> readyToCrop() async {
    await load();
    await controller.pickFromGallery('user-1');
  }

  Future<bool> save() =>
      controller.saveCroppedPhoto('user-1', Uint8List.fromList([4, 5, 6]));

  void dispose() {
    container.dispose();
    gateway
      ..photo = null
      ..downloadBytes = avatarPngBytes()
      ..loadError = null
      ..downloadError = null
      ..uploadError = null
      ..commitError = null
      ..audienceError = null
      ..clearError = null
      ..deleteError = null
      ..loadResult = null
      ..uploadDelay = null
      ..commitResult = null
      ..loadIds.clear()
      ..downloadPaths.clear()
      ..uploadPaths.clear()
      ..uploadedBytes.clear()
      ..commitIds.clear()
      ..committedAudiences.clear()
      ..audienceUpdates.clear()
      ..clearIds.clear()
      ..deletedPaths.clear();
    picker
      ..result = Uint8List.fromList([1, 2, 3])
      ..error = null
      ..calls = 0;
    processor
      ..result = ProcessedProfilePhoto(
        bytes: avatarPngBytes(),
        width: 512,
        height: 512,
        quality: 82,
        encodingAttempts: 1,
      )
      ..error = null
      ..pendingResult = null
      ..calls = 0;
    pathGenerator
      ..path = 'user-1/new-version.webp'
      ..calls = 0;
  }
}
