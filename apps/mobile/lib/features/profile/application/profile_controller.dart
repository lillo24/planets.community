import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/profile_gateway.dart';
import '../domain/profile_models.dart';

class ProfileController extends Notifier<ProfileState> {
  var _revision = 0;
  var _visibilityRevision = 0;
  (String, Map<ProfileFieldKey, ProfileAudience>)? _visibilitySnapshot;

  @override
  ProfileState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _visibilitySnapshot = null;
      state = const ProfileState();
    });
    ref.onDispose(() => _revision++);
    return const ProfileState();
  }

  bool _isCurrent(int revision, String userId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == userId;

  // A targeted canonical visibility reread can arrive during a content read.
  // Preserve that newer independent result without changing content-save state.
  void acceptVisibility(
    String id,
    Map<ProfileFieldKey, ProfileAudience> values,
  ) {
    final data = state.data;
    if (ref.read(authSessionProvider).identity?.id != id) return;
    _visibilityRevision++;
    _visibilitySnapshot = (id, Map.unmodifiable(values));
    if (data?.profile.id != id) return;
    state = ProfileState(
      phase: state.phase,
      failure: state.failure,
      data: _withVisibility(data!, values),
    );
  }

  ProfileEditorData _withVisibility(
    ProfileEditorData data,
    Map<ProfileFieldKey, ProfileAudience> values,
  ) => ProfileEditorData(
    profile: OwnProfile(
      id: data.profile.id,
      displayName: data.profile.displayName,
      bio: data.profile.bio,
      updatedAt: data.profile.updatedAt,
      selectedSkillIds: data.profile.selectedSkillIds,
      visibility: Map.unmodifiable(values),
    ),
    categories: data.categories,
  );

  ProfileEditorData _latestVisibility(ProfileEditorData data, int revision) {
    final current = _visibilitySnapshot;
    return revision != _visibilityRevision && current?.$1 == data.profile.id
        ? _withVisibility(data, current!.$2)
        : data;
  }

  Future<void> load(String userId) async {
    if (state.isBusy) {
      return;
    }
    final revision = ++_revision;
    if (!_isCurrent(revision, userId)) return;
    final currentData = state.data?.profile.id == userId ? state.data : null;
    state = ProfileState(phase: ProfilePhase.loading, data: currentData);
    try {
      final visibilityRevision = _visibilityRevision;
      final data = await ref
          .read(profileGatewayProvider)
          .loadOwnProfile(userId);
      if (!_isCurrent(revision, userId)) return;
      state = ProfileState(
        phase: ProfilePhase.ready,
        data: _latestVisibility(data, visibilityRevision),
      );
    } catch (_) {
      if (!_isCurrent(revision, userId)) return;
      state = ProfileState(
        phase: ProfilePhase.failure,
        data: state.data,
        failure: ProfileFailureKind.unavailable,
      );
    }
  }

  Future<bool> save(AuthIdentity identity, ProfileUpdate update) async {
    if (state.isBusy) {
      return false;
    }
    if (!isValidDisplayName(update.displayName) || !isValidBio(update.bio)) {
      state = ProfileState(
        phase: ProfilePhase.failure,
        data: state.data,
        failure: ProfileFailureKind.invalidInput,
      );
      return false;
    }

    final revision = ++_revision;
    if (!_isCurrent(revision, identity.id)) return false;
    state = ProfileState(phase: ProfilePhase.saving, data: state.data);
    try {
      await ref
          .read(profileGatewayProvider)
          .updateOwnProfile(identity.id, update);
      if (!_isCurrent(revision, identity.id)) return false;
      final visibilityRevision = _visibilityRevision;
      final data = await ref
          .read(profileGatewayProvider)
          .loadOwnProfile(identity.id);
      if (!_isCurrent(revision, identity.id)) return false;
      ref.read(authSessionProvider.notifier).markProfileReady(identity);
      state = ProfileState(
        phase: ProfilePhase.ready,
        data: _latestVisibility(data, visibilityRevision),
      );
      return true;
    } catch (_) {
      if (!_isCurrent(revision, identity.id)) return false;
      state = ProfileState(
        phase: ProfilePhase.failure,
        data: state.data,
        failure: ProfileFailureKind.unavailable,
      );
      return false;
    }
  }
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);
