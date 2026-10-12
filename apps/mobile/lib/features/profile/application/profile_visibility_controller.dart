import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/profile_visibility_gateway.dart';
import '../domain/profile_models.dart';
import 'profile_controller.dart';

class ProfileVisibilityState {
  const ProfileVisibilityState({
    this.profileId,
    this.values,
    this.busy = false,
    this.failed = false,
    this.saved = false,
  });
  final String? profileId;
  final Map<ProfileFieldKey, ProfileAudience>? values;
  final bool busy, failed, saved;
}

class ProfileVisibilityController extends Notifier<ProfileVisibilityState> {
  var _revision = 0;
  @override
  ProfileVisibilityState build() {
    ref.listen(
      authSessionProvider.select(
        (s) => (s.identity?.id, s.phase == AuthSessionPhase.ready),
      ),
      (_, _) {
        _revision++;
        state = const ProfileVisibilityState();
      },
    );
    ref.onDispose(() => _revision++);
    return const ProfileVisibilityState();
  }

  bool _current(int revision, String id) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == id;

  Future<bool> load(String id) async {
    if (state.busy || !_current(_revision, id)) return false;
    final revision = ++_revision;
    state = ProfileVisibilityState(
      profileId: id,
      values: state.profileId == id ? state.values : null,
      busy: true,
    );
    try {
      final values = await ref.read(profileVisibilityGatewayProvider).load(id);
      if (!_current(revision, id)) return false;
      ref.read(profileProvider.notifier).acceptVisibility(id, values);
      state = ProfileVisibilityState(profileId: id, values: values);
      return true;
    } catch (_) {
      if (!_current(revision, id)) return false;
      state = ProfileVisibilityState(
        profileId: id,
        values: state.values,
        failed: true,
      );
      return false;
    }
  }

  Future<bool> select(
    String id,
    ProfileFieldKey field,
    ProfileAudience audience,
  ) async {
    if (state.busy ||
        state.profileId != id ||
        state.values == null ||
        !_current(_revision, id)) {
      return false;
    }
    if (state.values![field] == audience) return true;
    final revision = ++_revision;
    state = ProfileVisibilityState(
      profileId: id,
      values: state.values,
      busy: true,
    );
    try {
      await ref
          .read(profileVisibilityGatewayProvider)
          .update(id, field, audience);
      if (!_current(revision, id)) return false;
      final values = await ref.read(profileVisibilityGatewayProvider).load(id);
      if (!_current(revision, id)) return false;
      ref.read(profileProvider.notifier).acceptVisibility(id, values);
      state = ProfileVisibilityState(
        profileId: id,
        values: values,
        saved: true,
      );
      return true;
    } catch (_) {
      if (!_current(revision, id)) return false;
      state = ProfileVisibilityState(
        profileId: id,
        values: state.values,
        failed: true,
      );
      return false;
    }
  }
}

final profileVisibilityProvider =
    NotifierProvider<ProfileVisibilityController, ProfileVisibilityState>(
      ProfileVisibilityController.new,
    );
