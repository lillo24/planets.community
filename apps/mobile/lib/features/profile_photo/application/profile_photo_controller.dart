import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/profile_photo_gateway.dart';
import '../data/profile_photo_picker.dart';
import '../domain/profile_photo_models.dart';
import 'profile_photo_path_generator.dart';
import 'profile_photo_processor.dart';

class ProfilePhotoController extends Notifier<ProfilePhotoState> {
  var _revision = 0;

  @override
  ProfilePhotoState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProfilePhotoState();
    });
    ref.onDispose(() => _revision++);
    return const ProfilePhotoState();
  }

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  Future<void> load(String profileId, {bool force = false}) async {
    if (state.isBusy ||
        (!force &&
            state.profileId == profileId &&
            state.phase == ProfilePhotoPhase.ready)) {
      return;
    }
    final revision = ++_revision;
    if (!_isCurrent(revision, profileId)) return;
    state = ProfilePhotoState(
      profileId: profileId,
      phase: ProfilePhotoPhase.loading,
      photo: state.profileId == profileId ? state.photo : null,
      imageBytes: state.profileId == profileId ? state.imageBytes : null,
    );
    try {
      final gateway = ref.read(profilePhotoGatewayProvider);
      final photo = await gateway.loadOwnPhoto(profileId);
      if (!_isCurrent(revision, profileId)) return;
      if (photo == null) {
        state = ProfilePhotoState(
          profileId: profileId,
          phase: ProfilePhotoPhase.ready,
        );
        return;
      }
      if (photo.profileId != profileId) {
        throw const ProfilePhotoDataException(
          'Owner photo belongs to another profile.',
        );
      }
      try {
        final bytes = await gateway.downloadOwnPhoto(photo.objectPath);
        if (!_isCurrent(revision, profileId)) return;
        state = ProfilePhotoState(
          profileId: profileId,
          phase: ProfilePhotoPhase.ready,
          photo: photo,
          imageBytes: bytes,
        );
      } catch (_) {
        if (!_isCurrent(revision, profileId)) return;
        state = ProfilePhotoState(
          profileId: profileId,
          phase: ProfilePhotoPhase.failure,
          photo: photo,
          failure: ProfilePhotoFailureKind.read,
        );
      }
    } catch (_) {
      if (!_isCurrent(revision, profileId)) return;
      state = ProfilePhotoState(
        profileId: profileId,
        phase: ProfilePhotoPhase.failure,
        photo: state.photo,
        imageBytes: state.imageBytes,
        failure: ProfilePhotoFailureKind.read,
      );
    }
  }

  Future<Uint8List?> pickFromGallery(String profileId) async {
    if (state.isBusy || state.profileId != profileId) return null;
    final revision = ++_revision;
    if (!_isCurrent(revision, profileId)) return null;
    final previous = state;
    state = previous.copyWith(
      phase: ProfilePhotoPhase.picking,
      clearFailure: true,
    );
    try {
      final selected = await ref
          .read(profilePhotoPickerProvider)
          .pickFromGallery();
      if (!_isCurrent(revision, profileId)) return null;
      if (selected == null) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.ready,
          clearFailure: true,
        );
        return null;
      }
      state = previous.copyWith(
        phase: ProfilePhotoPhase.cropping,
        clearFailure: true,
      );
      return selected;
    } catch (_) {
      if (!_isCurrent(revision, profileId)) return null;
      state = previous.copyWith(
        phase: ProfilePhotoPhase.failure,
        failure: ProfilePhotoFailureKind.sourceRead,
      );
      return null;
    }
  }

  void cancelCrop(String profileId) {
    if (state.profileId != profileId ||
        state.phase != ProfilePhotoPhase.cropping) {
      return;
    }
    _revision++;
    state = state.copyWith(phase: ProfilePhotoPhase.ready, clearFailure: true);
  }

  Future<bool> saveCroppedPhoto(
    String profileId,
    Uint8List croppedBytes,
  ) async {
    if (state.profileId != profileId ||
        state.phase != ProfilePhotoPhase.cropping) {
      return false;
    }
    final revision = ++_revision;
    if (!_isCurrent(revision, profileId)) return false;
    final previous = state;
    state = previous.copyWith(
      phase: ProfilePhotoPhase.processing,
      clearFailure: true,
    );

    late final ProcessedProfilePhoto processed;
    try {
      processed = await ref
          .read(profilePhotoProcessorProvider)
          .process(croppedBytes);
    } on ProfilePhotoTooLargeException {
      if (_isCurrent(revision, profileId)) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.failure,
          failure: ProfilePhotoFailureKind.tooLarge,
        );
      }
      return false;
    } catch (_) {
      if (_isCurrent(revision, profileId)) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.failure,
          failure: ProfilePhotoFailureKind.prepare,
        );
      }
      return false;
    }
    if (!_isCurrent(revision, profileId)) return false;
    if (processed.width != 512 ||
        processed.height != 512 ||
        processed.byteLength > profilePhotoMaxBytes) {
      state = previous.copyWith(
        phase: ProfilePhotoPhase.failure,
        failure: ProfilePhotoFailureKind.tooLarge,
      );
      return false;
    }

    final path = ref.read(profilePhotoPathGeneratorProvider).newPath(profileId);
    final gateway = ref.read(profilePhotoGatewayProvider);
    state = previous.copyWith(
      phase: ProfilePhotoPhase.uploading,
      clearFailure: true,
    );
    try {
      await gateway.uploadNewPhoto(path, processed.bytes);
    } catch (_) {
      if (_isCurrent(revision, profileId)) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.failure,
          failure: ProfilePhotoFailureKind.upload,
        );
      }
      return false;
    }
    if (!_isCurrent(revision, profileId)) {
      await _deleteBestEffort(gateway, path);
      return false;
    }

    final audience =
        previous.photo?.audience ?? ProfilePhotoAudience.interactions;
    late final ProfilePhotoCommit commit;
    try {
      commit = await gateway.commitOwnPhoto(profileId, path, audience);
      if (commit.currentObjectPath != path) {
        throw const ProfilePhotoDataException(
          'Owner photo commit returned another path.',
        );
      }
    } catch (_) {
      await _deleteBestEffort(gateway, path);
      if (_isCurrent(revision, profileId)) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.failure,
          failure: ProfilePhotoFailureKind.save,
        );
      }
      return false;
    }
    if (!_isCurrent(revision, profileId)) return false;

    state = ProfilePhotoState(
      profileId: profileId,
      phase: ProfilePhotoPhase.ready,
      photo: OwnProfilePhoto(
        profileId: profileId,
        objectPath: commit.currentObjectPath,
        audience: commit.audience,
        createdAt: previous.photo?.createdAt ?? commit.updatedAt,
        updatedAt: commit.updatedAt,
      ),
      imageBytes: processed.bytes,
    );
    final oldPath = commit.previousObjectPath;
    if (oldPath != null && oldPath != commit.currentObjectPath) {
      unawaited(_deleteBestEffort(gateway, oldPath));
    }
    return true;
  }

  Future<bool> updateAudience(
    String profileId,
    ProfilePhotoAudience audience,
  ) async {
    final photo = state.photo;
    if (state.isBusy ||
        state.profileId != profileId ||
        photo == null ||
        photo.audience == audience) {
      return false;
    }
    final revision = ++_revision;
    if (!_isCurrent(revision, profileId)) return false;
    final previous = state;
    state = previous.copyWith(
      phase: ProfilePhotoPhase.updatingAudience,
      clearFailure: true,
    );
    try {
      final change = await ref
          .read(profilePhotoGatewayProvider)
          .setAudience(profileId, audience);
      if (!_isCurrent(revision, profileId)) return false;
      if (change.profileId != profileId ||
          change.objectPath != photo.objectPath ||
          change.audience != audience) {
        throw const ProfilePhotoDataException(
          'Owner photo audience update returned invalid metadata.',
        );
      }
      state = previous.copyWith(
        phase: ProfilePhotoPhase.ready,
        photo: photo.copyWith(
          audience: change.audience,
          updatedAt: change.updatedAt,
        ),
        clearFailure: true,
      );
      return true;
    } catch (_) {
      if (_isCurrent(revision, profileId)) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.failure,
          failure: ProfilePhotoFailureKind.save,
        );
      }
      return false;
    }
  }

  Future<bool> remove(String profileId) async {
    if (state.isBusy || state.profileId != profileId || state.photo == null) {
      return false;
    }
    final revision = ++_revision;
    if (!_isCurrent(revision, profileId)) return false;
    final previous = state;
    state = previous.copyWith(
      phase: ProfilePhotoPhase.removing,
      clearFailure: true,
    );
    final gateway = ref.read(profilePhotoGatewayProvider);
    late final String? oldPath;
    try {
      oldPath = await gateway.clearOwnPhoto(profileId);
    } catch (_) {
      if (_isCurrent(revision, profileId)) {
        state = previous.copyWith(
          phase: ProfilePhotoPhase.failure,
          failure: ProfilePhotoFailureKind.remove,
        );
      }
      return false;
    }
    if (!_isCurrent(revision, profileId)) return false;
    state = ProfilePhotoState(
      profileId: profileId,
      phase: ProfilePhotoPhase.ready,
    );
    if (oldPath != null) {
      unawaited(_deleteBestEffort(gateway, oldPath));
    }
    return true;
  }

  Future<void> _deleteBestEffort(
    ProfilePhotoGateway gateway,
    String objectPath,
  ) async {
    try {
      await gateway.deleteOwnObject(objectPath);
    } catch (_) {
      // Canonical database state wins. Private orphan cleanup is best effort.
    }
  }
}

final profilePhotoProvider =
    NotifierProvider<ProfilePhotoController, ProfilePhotoState>(
      ProfilePhotoController.new,
    );
