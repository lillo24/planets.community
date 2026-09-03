import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/profile_gateway.dart';
import '../domain/profile_models.dart';

class ProfileController extends Notifier<ProfileState> {
  var _revision = 0;

  @override
  ProfileState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProfileState();
    });
    ref.onDispose(() => _revision++);
    return const ProfileState();
  }

  bool _isCurrent(int revision, String userId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == userId;

  Future<void> load(String userId) async {
    if (state.isBusy) {
      return;
    }
    final revision = ++_revision;
    if (!_isCurrent(revision, userId)) return;
    final currentData = state.data?.profile.id == userId ? state.data : null;
    state = ProfileState(phase: ProfilePhase.loading, data: currentData);
    try {
      final data = await ref
          .read(profileGatewayProvider)
          .loadOwnProfile(userId);
      if (!_isCurrent(revision, userId)) return;
      state = ProfileState(phase: ProfilePhase.ready, data: data);
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
    if (!isValidDisplayName(update.displayName) ||
        !isValidBio(update.bio) ||
        update.visibility.length != ProfileFieldKey.values.length) {
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
      final data = await ref
          .read(profileGatewayProvider)
          .loadOwnProfile(identity.id);
      if (!_isCurrent(revision, identity.id)) return false;
      ref.read(authSessionProvider.notifier).markProfileReady(identity);
      state = ProfileState(phase: ProfilePhase.ready, data: data);
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
