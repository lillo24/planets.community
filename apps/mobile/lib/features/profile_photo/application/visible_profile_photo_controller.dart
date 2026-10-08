import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/profile_photo_gateway.dart';
import '../domain/visible_profile_photo_models.dart';

class VisibleProfilePhotoController extends Notifier<VisibleProfilePhotoState> {
  var _identityRevision = 0;
  final Map<String, int> _targetRevisions = {};

  @override
  VisibleProfilePhotoState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, nextViewerProfileId) {
        _identityRevision++;
        _targetRevisions.clear();
        state = VisibleProfilePhotoState(viewerProfileId: nextViewerProfileId);
      },
    );
    ref.onDispose(() {
      _identityRevision++;
      _targetRevisions.clear();
    });
    return VisibleProfilePhotoState(
      viewerProfileId: ref.read(authSessionProvider).identity?.id,
    );
  }

  Future<void> load(String targetProfileId, {bool force = false}) async {
    final existing = state.entryFor(targetProfileId);
    if (existing?.phase == VisibleProfilePhotoPhase.loading ||
        (!force && existing?.phase == VisibleProfilePhotoPhase.ready)) {
      return;
    }

    final viewerProfileId = state.viewerProfileId;
    final identityRevision = _identityRevision;
    final targetRevision = _nextTargetRevision(targetProfileId);
    state = state.withEntry(
      VisibleProfilePhotoEntry(
        targetProfileId: targetProfileId,
        phase: VisibleProfilePhotoPhase.loading,
        // Same-viewer revalidation retains authorized bytes until completion.
        photo: existing?.photo,
        imageBytes: existing?.imageBytes,
      ),
    );

    late final VisibleProfilePhoto? photo;
    try {
      photo = await ref
          .read(profilePhotoGatewayProvider)
          .loadVisiblePhoto(targetProfileId);
    } catch (_) {
      _setFailureIfCurrent(
        targetProfileId,
        viewerProfileId,
        identityRevision,
        targetRevision,
      );
      return;
    }
    if (!_isCurrent(
      targetProfileId,
      viewerProfileId,
      identityRevision,
      targetRevision,
    )) {
      return;
    }
    if (photo == null) {
      state = state.withEntry(
        VisibleProfilePhotoEntry(
          targetProfileId: targetProfileId,
          phase: VisibleProfilePhotoPhase.ready,
        ),
      );
      return;
    }

    final cachedBytes = existing?.photo?.versionKey == photo.versionKey
        ? existing?.imageBytes
        : null;
    if (cachedBytes != null) {
      state = state.withEntry(
        VisibleProfilePhotoEntry(
          targetProfileId: targetProfileId,
          phase: VisibleProfilePhotoPhase.ready,
          photo: photo,
          imageBytes: cachedBytes,
        ),
      );
      return;
    }
    await _download(photo, viewerProfileId, identityRevision, targetRevision);
  }

  Future<void> loadBatch(
    List<String> targetProfileIds, {
    bool force = false,
  }) async {
    if (targetProfileIds.isEmpty || targetProfileIds.length > 50) {
      throw const ProfilePhotoDataException(
        'Viewer photo batches require between 1 and 50 target IDs.',
      );
    }
    final targets = targetProfileIds.toSet().toList(growable: false);
    final pendingTargets = targets
        .where((target) {
          final existing = state.entryFor(target);
          return existing?.phase != VisibleProfilePhotoPhase.loading &&
              (force || existing?.phase != VisibleProfilePhotoPhase.ready);
        })
        .toList(growable: false);
    if (pendingTargets.isEmpty) return;

    final viewerProfileId = state.viewerProfileId;
    final identityRevision = _identityRevision;
    final targetRevisions = <String, int>{};
    final previousEntries = <String, VisibleProfilePhotoEntry?>{};
    for (final target in pendingTargets) {
      previousEntries[target] = state.entryFor(target);
      targetRevisions[target] = _nextTargetRevision(target);
      state = state.withEntry(
        VisibleProfilePhotoEntry(
          targetProfileId: target,
          phase: VisibleProfilePhotoPhase.loading,
          photo: previousEntries[target]?.photo,
          imageBytes: previousEntries[target]?.imageBytes,
        ),
      );
    }

    late final List<VisibleProfilePhoto> photos;
    try {
      photos = await ref
          .read(profilePhotoGatewayProvider)
          .loadVisiblePhotos(pendingTargets);
    } catch (_) {
      for (final target in pendingTargets) {
        _setFailureIfCurrent(
          target,
          viewerProfileId,
          identityRevision,
          targetRevisions[target]!,
        );
      }
      return;
    }
    final visibleByTarget = {
      for (final photo in photos) photo.profileId: photo,
    };
    await Future.wait(
      pendingTargets.map((target) async {
        final targetRevision = targetRevisions[target]!;
        if (!_isCurrent(
          target,
          viewerProfileId,
          identityRevision,
          targetRevision,
        )) {
          return;
        }
        final photo = visibleByTarget[target];
        if (photo == null) {
          state = state.withEntry(
            VisibleProfilePhotoEntry(
              targetProfileId: target,
              phase: VisibleProfilePhotoPhase.ready,
            ),
          );
          return;
        }
        final previous = previousEntries[target];
        final cachedBytes = previous?.photo?.versionKey == photo.versionKey
            ? previous?.imageBytes
            : null;
        if (cachedBytes != null) {
          state = state.withEntry(
            VisibleProfilePhotoEntry(
              targetProfileId: target,
              phase: VisibleProfilePhotoPhase.ready,
              photo: photo,
              imageBytes: cachedBytes,
            ),
          );
          return;
        }
        await _download(
          photo,
          viewerProfileId,
          identityRevision,
          targetRevision,
        );
      }),
    );
  }

  void invalidate(String targetProfileId) {
    _nextTargetRevision(targetProfileId);
    state = state.without(targetProfileId);
  }

  void invalidateAll() {
    _identityRevision++;
    _targetRevisions.clear();
    state = VisibleProfilePhotoState(viewerProfileId: state.viewerProfileId);
  }

  Future<void> _download(
    VisibleProfilePhoto photo,
    String? viewerProfileId,
    int identityRevision,
    int targetRevision,
  ) async {
    late final Uint8List bytes;
    try {
      bytes = await ref
          .read(profilePhotoGatewayProvider)
          .downloadVisiblePhoto(photo.objectPath);
    } catch (_) {
      _setFailureIfCurrent(
        photo.profileId,
        viewerProfileId,
        identityRevision,
        targetRevision,
      );
      return;
    }
    if (!_isCurrent(
      photo.profileId,
      viewerProfileId,
      identityRevision,
      targetRevision,
    )) {
      return;
    }
    state = state.withEntry(
      VisibleProfilePhotoEntry(
        targetProfileId: photo.profileId,
        phase: VisibleProfilePhotoPhase.ready,
        photo: photo,
        imageBytes: bytes,
      ),
    );
  }

  int _nextTargetRevision(String targetProfileId) {
    final next = (_targetRevisions[targetProfileId] ?? 0) + 1;
    _targetRevisions[targetProfileId] = next;
    return next;
  }

  bool _isCurrent(
    String targetProfileId,
    String? viewerProfileId,
    int identityRevision,
    int targetRevision,
  ) {
    return ref.mounted &&
        identityRevision == _identityRevision &&
        targetRevision == _targetRevisions[targetProfileId] &&
        viewerProfileId == ref.read(authSessionProvider).identity?.id;
  }

  void _setFailureIfCurrent(
    String targetProfileId,
    String? viewerProfileId,
    int identityRevision,
    int targetRevision,
  ) {
    if (!_isCurrent(
      targetProfileId,
      viewerProfileId,
      identityRevision,
      targetRevision,
    )) {
      return;
    }
    state = state.withEntry(
      VisibleProfilePhotoEntry(
        targetProfileId: targetProfileId,
        phase: VisibleProfilePhotoPhase.failure,
      ),
    );
  }
}

final visibleProfilePhotoProvider =
    NotifierProvider<VisibleProfilePhotoController, VisibleProfilePhotoState>(
      VisibleProfilePhotoController.new,
    );
