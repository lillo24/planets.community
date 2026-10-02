import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/profile_photo_gateway.dart';
import '../domain/visible_profile_photo_models.dart';

class ProjectCreatorPhotoState {
  const ProjectCreatorPhotoState({
    this.viewerProfileId,
    this.entries = const {},
  });

  final String? viewerProfileId;
  final Map<String, VisibleProfilePhotoEntry> entries;

  VisibleProfilePhotoEntry? entryFor(String projectId) => entries[projectId];

  ProjectCreatorPhotoState withEntry(
    String projectId,
    VisibleProfilePhotoEntry entry,
  ) {
    return ProjectCreatorPhotoState(
      viewerProfileId: viewerProfileId,
      entries: Map.unmodifiable({...entries, projectId: entry}),
    );
  }

  ProjectCreatorPhotoState without(String projectId) {
    final next = {...entries}..remove(projectId);
    return ProjectCreatorPhotoState(
      viewerProfileId: viewerProfileId,
      entries: Map.unmodifiable(next),
    );
  }
}

class ProjectCreatorPhotoController extends Notifier<ProjectCreatorPhotoState> {
  var _identityRevision = 0;
  final Map<String, int> _projectRevisions = {};

  @override
  ProjectCreatorPhotoState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, nextViewerProfileId) {
        _identityRevision++;
        _projectRevisions.clear();
        state = ProjectCreatorPhotoState(viewerProfileId: nextViewerProfileId);
      },
    );
    ref.onDispose(() {
      _identityRevision++;
      _projectRevisions.clear();
    });
    return ProjectCreatorPhotoState(
      viewerProfileId: ref.read(authSessionProvider).identity?.id,
    );
  }

  Future<void> load(String projectId, {bool force = false}) async {
    final existing = state.entryFor(projectId);
    if (existing?.phase == VisibleProfilePhotoPhase.loading ||
        (!force && existing?.phase == VisibleProfilePhotoPhase.ready)) {
      return;
    }

    final viewerProfileId = state.viewerProfileId;
    final identityRevision = _identityRevision;
    final projectRevision = _nextProjectRevision(projectId);
    state = state.withEntry(
      projectId,
      VisibleProfilePhotoEntry(
        targetProfileId: projectId,
        phase: VisibleProfilePhotoPhase.loading,
      ),
    );

    late final VisibleProfilePhoto? photo;
    try {
      photo = await ref
          .read(profilePhotoGatewayProvider)
          .loadProjectCreatorPhoto(projectId);
    } catch (_) {
      _setFailureIfCurrent(
        projectId,
        viewerProfileId,
        identityRevision,
        projectRevision,
      );
      return;
    }
    if (!_isCurrent(
      projectId,
      viewerProfileId,
      identityRevision,
      projectRevision,
    )) {
      return;
    }
    if (photo == null) {
      state = state.withEntry(
        projectId,
        VisibleProfilePhotoEntry(
          targetProfileId: projectId,
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
        projectId,
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
      projectId,
      photo,
      viewerProfileId,
      identityRevision,
      projectRevision,
    );
  }

  void invalidate(String projectId) {
    _nextProjectRevision(projectId);
    state = state.without(projectId);
  }

  Future<void> _download(
    String projectId,
    VisibleProfilePhoto photo,
    String? viewerProfileId,
    int identityRevision,
    int projectRevision,
  ) async {
    late final Uint8List bytes;
    try {
      bytes = await ref
          .read(profilePhotoGatewayProvider)
          .downloadVisiblePhoto(photo.objectPath);
    } catch (_) {
      _setFailureIfCurrent(
        projectId,
        viewerProfileId,
        identityRevision,
        projectRevision,
      );
      return;
    }
    if (!_isCurrent(
      projectId,
      viewerProfileId,
      identityRevision,
      projectRevision,
    )) {
      return;
    }
    state = state.withEntry(
      projectId,
      VisibleProfilePhotoEntry(
        targetProfileId: photo.profileId,
        phase: VisibleProfilePhotoPhase.ready,
        photo: photo,
        imageBytes: bytes,
      ),
    );
  }

  int _nextProjectRevision(String projectId) {
    final next = (_projectRevisions[projectId] ?? 0) + 1;
    _projectRevisions[projectId] = next;
    return next;
  }

  bool _isCurrent(
    String projectId,
    String? viewerProfileId,
    int identityRevision,
    int projectRevision,
  ) {
    return ref.mounted &&
        identityRevision == _identityRevision &&
        projectRevision == _projectRevisions[projectId] &&
        viewerProfileId == ref.read(authSessionProvider).identity?.id;
  }

  void _setFailureIfCurrent(
    String projectId,
    String? viewerProfileId,
    int identityRevision,
    int projectRevision,
  ) {
    if (!_isCurrent(
      projectId,
      viewerProfileId,
      identityRevision,
      projectRevision,
    )) {
      return;
    }
    state = state.withEntry(
      projectId,
      VisibleProfilePhotoEntry(
        targetProfileId: projectId,
        phase: VisibleProfilePhotoPhase.failure,
      ),
    );
  }
}

final projectCreatorPhotoProvider =
    NotifierProvider<ProjectCreatorPhotoController, ProjectCreatorPhotoState>(
      ProjectCreatorPhotoController.new,
    );
