import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/profile_gateway.dart';
import '../domain/profile_models.dart';

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();

  Future<void> load(String userId) async {
    if (state.isBusy) {
      return;
    }
    final currentData = state.data?.profile.id == userId ? state.data : null;
    state = ProfileState(phase: ProfilePhase.loading, data: currentData);
    try {
      final data = await ref
          .read(profileGatewayProvider)
          .loadOwnProfile(userId);
      state = ProfileState(phase: ProfilePhase.ready, data: data);
    } catch (_) {
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

    state = ProfileState(phase: ProfilePhase.saving, data: state.data);
    try {
      await ref.read(profileGatewayProvider).updateOwnProfile(update);
      final data = await ref
          .read(profileGatewayProvider)
          .loadOwnProfile(identity.id);
      ref.read(authSessionProvider.notifier).markProfileReady(identity);
      state = ProfileState(phase: ProfilePhase.ready, data: data);
      return true;
    } catch (_) {
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
