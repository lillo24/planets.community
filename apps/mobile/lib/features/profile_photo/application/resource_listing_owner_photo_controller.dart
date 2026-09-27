import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/profile_photo_gateway.dart';
import '../domain/visible_profile_photo_models.dart';

class ResourceListingOwnerPhotoState {
  const ResourceListingOwnerPhotoState({
    this.viewerProfileId,
    this.entries = const {},
  });

  final String? viewerProfileId;
  final Map<String, VisibleProfilePhotoEntry> entries;

  VisibleProfilePhotoEntry? entryFor(String listingId) => entries[listingId];

  ResourceListingOwnerPhotoState withEntry(
    String listingId,
    VisibleProfilePhotoEntry entry,
  ) => ResourceListingOwnerPhotoState(
    viewerProfileId: viewerProfileId,
    entries: Map.unmodifiable({...entries, listingId: entry}),
  );

  ResourceListingOwnerPhotoState without(String listingId) {
    final next = {...entries}..remove(listingId);
    return ResourceListingOwnerPhotoState(
      viewerProfileId: viewerProfileId,
      entries: Map.unmodifiable(next),
    );
  }
}

class ResourceListingOwnerPhotoController
    extends Notifier<ResourceListingOwnerPhotoState> {
  var _identityRevision = 0;
  final Map<String, int> _listingRevisions = {};

  @override
  ResourceListingOwnerPhotoState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      nextViewerProfileId,
    ) {
      _identityRevision++;
      _listingRevisions.clear();
      state = ResourceListingOwnerPhotoState(
        viewerProfileId: nextViewerProfileId,
      );
    });
    ref.onDispose(() {
      _identityRevision++;
      _listingRevisions.clear();
    });
    return ResourceListingOwnerPhotoState(
      viewerProfileId: ref.read(authSessionProvider).identity?.id,
    );
  }

  Future<void> load(String listingId, {bool force = false}) async {
    final existing = state.entryFor(listingId);
    if (existing?.phase == VisibleProfilePhotoPhase.loading ||
        (!force && existing?.phase == VisibleProfilePhotoPhase.ready)) {
      return;
    }

    final viewerProfileId = state.viewerProfileId;
    final identityRevision = _identityRevision;
    final listingRevision = _nextListingRevision(listingId);
    state = state.withEntry(
      listingId,
      VisibleProfilePhotoEntry(
        targetProfileId: listingId,
        phase: VisibleProfilePhotoPhase.loading,
      ),
    );

    late final VisibleProfilePhoto? photo;
    try {
      photo = await ref
          .read(profilePhotoGatewayProvider)
          .loadResourceListingOwnerPhoto(listingId);
    } catch (_) {
      _setFailureIfCurrent(
        listingId,
        viewerProfileId,
        identityRevision,
        listingRevision,
      );
      return;
    }
    if (!_isCurrent(
      listingId,
      viewerProfileId,
      identityRevision,
      listingRevision,
    )) {
      return;
    }
    if (photo == null) {
      state = state.withEntry(
        listingId,
        VisibleProfilePhotoEntry(
          targetProfileId: listingId,
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
        listingId,
        VisibleProfilePhotoEntry(
          targetProfileId: photo.profileId,
          phase: VisibleProfilePhotoPhase.ready,
          photo: photo,
          imageBytes: cachedBytes,
        ),
      );
      return;
    }
    await _download(
      listingId,
      photo,
      viewerProfileId,
      identityRevision,
      listingRevision,
    );
  }

  void invalidate(String listingId) {
    _nextListingRevision(listingId);
    state = state.without(listingId);
  }

  Future<void> _download(
    String listingId,
    VisibleProfilePhoto photo,
    String? viewerProfileId,
    int identityRevision,
    int listingRevision,
  ) async {
    late final Uint8List bytes;
    try {
      bytes = await ref
          .read(profilePhotoGatewayProvider)
          .downloadVisiblePhoto(photo.objectPath);
    } catch (_) {
      _setFailureIfCurrent(
        listingId,
        viewerProfileId,
        identityRevision,
        listingRevision,
      );
      return;
    }
    if (!_isCurrent(
      listingId,
      viewerProfileId,
      identityRevision,
      listingRevision,
    )) {
      return;
    }
    state = state.withEntry(
      listingId,
      VisibleProfilePhotoEntry(
        targetProfileId: photo.profileId,
        phase: VisibleProfilePhotoPhase.ready,
        photo: photo,
        imageBytes: bytes,
      ),
    );
  }

  int _nextListingRevision(String listingId) {
    final next = (_listingRevisions[listingId] ?? 0) + 1;
    _listingRevisions[listingId] = next;
    return next;
  }

  bool _isCurrent(
    String listingId,
    String? viewerProfileId,
    int identityRevision,
    int listingRevision,
  ) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      listingRevision == _listingRevisions[listingId] &&
      viewerProfileId == ref.read(authSessionProvider).identity?.id;

  void _setFailureIfCurrent(
    String listingId,
    String? viewerProfileId,
    int identityRevision,
    int listingRevision,
  ) {
    if (!_isCurrent(
      listingId,
      viewerProfileId,
      identityRevision,
      listingRevision,
    )) {
      return;
    }
    state = state.withEntry(
      listingId,
      VisibleProfilePhotoEntry(
        targetProfileId: listingId,
        phase: VisibleProfilePhotoPhase.failure,
      ),
    );
  }
}

final resourceListingOwnerPhotoProvider =
    NotifierProvider<
      ResourceListingOwnerPhotoController,
      ResourceListingOwnerPhotoState
    >(ResourceListingOwnerPhotoController.new);
