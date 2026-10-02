import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/data/project_delegate_gateway.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../data/participation_gateway.dart';
import '../data/project_people_gateway.dart';
import '../domain/participation_models.dart';
import '../domain/project_capacity.dart';
import '../domain/project_people_models.dart';
import 'participation_controllers.dart';

class ProjectPeopleState {
  const ProjectPeopleState({
    this.profileId,
    this.projectId,
    this.role = ProjectManagementRole.none,
    this.people = const PeoplePage(),
    this.requests = const PeoplePage(),
    this.history = const PeoplePage(),
    this.offers = const PeoplePage(),
    this.capacity,
    this.loading = false,
    this.mutating = false,
    this.failure,
  });
  final String? profileId;
  final String? projectId;
  final ProjectManagementRole role;
  final PeoplePage<ProjectPerson> people;
  final PeoplePage<ManagerProjectJoinRequest> requests;
  final PeoplePage<ManagerProjectMember> history;
  final PeoplePage<ProjectRoleOffer> offers;
  final ProjectCapacitySnapshot? capacity;
  final bool loading;
  final bool mutating;
  final PeopleFailure? failure;
  ProjectPeopleState copy({
    PeoplePage<ProjectPerson>? people,
    PeoplePage<ManagerProjectJoinRequest>? requests,
    PeoplePage<ManagerProjectMember>? history,
    PeoplePage<ProjectRoleOffer>? offers,
    bool? loading,
    bool? mutating,
    PeopleFailure? failure,
  }) => ProjectPeopleState(
    profileId: profileId,
    projectId: projectId,
    role: role,
    people: people ?? this.people,
    requests: requests ?? this.requests,
    history: history ?? this.history,
    offers: offers ?? this.offers,
    capacity: capacity,
    loading: loading ?? this.loading,
    mutating: mutating ?? this.mutating,
    failure: failure,
  );
}

class ProjectPeopleController extends Notifier<ProjectPeopleState> {
  var _revision = 0;
  @override
  ProjectPeopleState build() {
    ref.listen(authSessionProvider.select((s) => (s.identity?.id, s.phase)), (
      _,
      _,
    ) {
      _revision++;
      state = const ProjectPeopleState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectPeopleState();
  }

  bool _current(int revision, String profileId, String projectId) =>
      ref.mounted &&
      revision == _revision &&
      state.profileId == profileId &&
      state.projectId == projectId &&
      ref.read(authSessionProvider).identity?.id == profileId;
  void _identity(String profileId) {
    final s = ref.read(authSessionProvider);
    if (s.phase != AuthSessionPhase.ready || s.identity?.id != profileId) {
      throw const ParticipationIdentityChangedException();
    }
  }

  Future<void> load(String profileId, String projectId) async {
    final revision = ++_revision;
    // Clear privileged rows up front; a refresh always revalidates the current viewer.
    state = ProjectPeopleState(
      profileId: profileId,
      projectId: projectId,
      loading: true,
    );
    try {
      _identity(profileId);
      final role = await ref
          .read(projectDelegateGatewayProvider)
          .getOwnManagementRole(
            expectedProfileId: profileId,
            projectId: projectId,
          );
      if (!_current(revision, profileId, projectId)) return;
      state = ProjectPeopleState(
        profileId: profileId,
        projectId: projectId,
        role: role,
        loading: true,
      );
      await Future.wait([
        loadMore(PeopleSection.people),
        loadMore(PeopleSection.offers),
        if (role.isManager) loadMore(PeopleSection.requests),
        if (role.isManager) loadMore(PeopleSection.history),
      ]);
      if (!_current(revision, profileId, projectId)) return;
      final capacity = role.isManager
          ? await ref
                .read(participationGatewayProvider)
                .getProjectCapacityForManager(
                  expectedManagerProfileId: profileId,
                  projectId: projectId,
                )
          : null;
      if (!_current(revision, profileId, projectId)) return;
      state = ProjectPeopleState(
        profileId: profileId,
        projectId: projectId,
        role: role,
        people: state.people,
        requests: state.requests,
        history: state.history,
        offers: state.offers,
        capacity: capacity,
        failure: state.failure,
      );
    } catch (error) {
      if (!_current(revision, profileId, projectId)) return;
      state = ProjectPeopleState(
        profileId: profileId,
        projectId: projectId,
        failure: peopleFailure(error),
      );
    }
  }

  Future<void> loadMore(PeopleSection section) async {
    final profileId = state.profileId, projectId = state.projectId;
    if (profileId == null || projectId == null) return;
    if ((section == PeopleSection.requests ||
            section == PeopleSection.history) &&
        !state.role.isManager) {
      return;
    }
    final revision = _revision;
    final gateway = ref.read(projectPeopleGatewayProvider);
    switch (section) {
      case PeopleSection.people:
        await _page(
          section,
          state.people,
          (after) => gateway.people(profileId, projectId, after),
          (page) => state = state.copy(people: page),
          (p) => p.profileId,
          revision,
          profileId,
          projectId,
        );
      case PeopleSection.requests:
        await _page(
          section,
          state.requests,
          (after) => gateway.requests(profileId, projectId, after),
          (page) => state = state.copy(requests: page),
          (p) => p.id,
          revision,
          profileId,
          projectId,
        );
      case PeopleSection.history:
        await _page(
          section,
          state.history,
          (after) => gateway.history(profileId, projectId, after),
          (page) => state = state.copy(history: page),
          (p) => p.id,
          revision,
          profileId,
          projectId,
        );
      case PeopleSection.offers:
        await _page(
          section,
          state.offers,
          (after) => gateway.offers(profileId, projectId, after),
          (page) => state = state.copy(offers: page),
          (p) => p.id,
          revision,
          profileId,
          projectId,
        );
    }
  }

  Future<void> _page<T>(
    PeopleSection section,
    PeoplePage<T> old,
    Future<List<T>> Function(T?) fetch,
    void Function(PeoplePage<T>) set,
    String Function(T) id,
    int revision,
    String profileId,
    String projectId,
  ) async {
    if (old.loading || !old.hasMore) return;
    set(PeoplePage(items: old.items, loading: true, cursor: old.cursor));
    try {
      _identity(profileId);
      final next = await fetch(old.cursor);
      if (!_current(revision, profileId, projectId)) return;
      final unique = {
        for (final row in [...old.items, ...next]) id(row): row,
      };
      set(
        PeoplePage(
          items: List.unmodifiable(unique.values),
          hasMore: next.length == SupabaseProjectPeopleGateway.pageSize,
          cursor: next.lastOrNull ?? old.cursor,
        ),
      );
      if (section == PeopleSection.requests) {
        final ids = next
            .whereType<ManagerProjectJoinRequest>()
            .where((r) => r.isPending)
            .map((r) => r.requesterProfileId)
            .toSet()
            .toList();
        if (ids.isNotEmpty && _current(revision, profileId, projectId)) {
          await ref.read(visibleProfilePhotoProvider.notifier).loadBatch(ids);
        }
      }
    } catch (error) {
      if (!_current(revision, profileId, projectId)) return;
      final failure = peopleFailure(error);
      if (failure == PeopleFailure.forbidden) {
        _revision++;
        state = ProjectPeopleState(
          profileId: profileId,
          projectId: projectId,
          failure: failure,
        );
        return;
      }
      set(
        PeoplePage(
          items: old.items,
          hasMore: old.hasMore,
          failure: failure,
          cursor: old.cursor,
        ),
      );
    }
  }

  Future<bool> mutate(
    Future<void> Function(String profileId, String projectId) operation,
  ) async {
    final profileId = state.profileId, projectId = state.projectId;
    if (profileId == null ||
        projectId == null ||
        state.loading ||
        state.mutating) {
      return false;
    }
    final revision = _revision;
    state = state.copy(mutating: true);
    Object? failure;
    try {
      _identity(profileId);
      await operation(profileId, projectId);
    } catch (error) {
      failure = error;
    }
    if (!_current(revision, profileId, projectId)) return false;
    ref.invalidate(projectManagementRoleProvider);
    ref.invalidate(projectTeamProvider);
    ref.invalidate(creatorParticipationProvider);
    ref.read(visibleProfilePhotoProvider.notifier).invalidateAll();
    ref.read(projectChatRefreshProvider.notifier).notifyChanged();
    final refresh = load(profileId, projectId);
    final refreshRevision = _revision;
    await refresh;
    if (!_current(refreshRevision, profileId, projectId)) {
      return false;
    }
    if (failure != null) state = state.copy(failure: peopleFailure(failure));
    await ref.read(ownParticipationProvider.notifier).load(profileId);
    return failure == null;
  }
}

PeopleFailure peopleFailure(Object error) {
  if (error is ParticipationIdentityChangedException) {
    return PeopleFailure.forbidden;
  }
  if (error is PostgrestException) {
    if (error.code == '42501') return PeopleFailure.forbidden;
    if (error.code == 'PT409' &&
        error.message.toLowerCase().contains('capacity')) {
      return PeopleFailure.capacity;
    }
    if (error.code == 'PT409' || error.code == '55000') {
      return PeopleFailure.conflict;
    }
  }
  return PeopleFailure.unavailable;
}

final projectPeopleProvider =
    NotifierProvider<ProjectPeopleController, ProjectPeopleState>(
      ProjectPeopleController.new,
    );
