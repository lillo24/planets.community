import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/project_organization_gateway.dart';
import '../domain/project_organization.dart';

enum OrganizationFailure {
  changed,
  invalid,
  forbidden,
  readOnly,
  photo,
  unavailable,
}

class ProjectOrganizationState {
  const ProjectOrganizationState({
    this.actor,
    this.projectId,
    this.snapshot,
    this.busy = false,
    this.failure,
  });
  final String? actor, projectId;
  final ProjectOrganization? snapshot;
  final bool busy;
  final OrganizationFailure? failure;
}

class ProjectOrganizationController extends Notifier<ProjectOrganizationState> {
  var _generation = 0;
  @override
  ProjectOrganizationState build() {
    // Include profile/account readiness, not just the user ID. A lost entitlement
    // must not retain private data even when the same account remains signed in.
    ref.listen(authSessionProvider, (_, _) => clear());
    ref.onDispose(() => _generation++);
    return const ProjectOrganizationState();
  }

  void clear() {
    _generation++;
    if (ref.mounted) state = const ProjectOrganizationState();
  }

  bool _current(int generation, String actor) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(authSessionProvider).identity?.id == actor;

  Future<void> load(
    String actor,
    String projectId, {
    bool background = false,
  }) async {
    final generation = ++_generation;
    if (!background) {
      state = ProjectOrganizationState(
        actor: actor,
        projectId: projectId,
        busy: true,
      );
    }
    try {
      if (ref.read(authSessionProvider).identity?.id != actor) return;
      final snapshot = await ref
          .read(projectOrganizationGatewayProvider)
          .read(actor, projectId);
      if (!_current(generation, actor)) return;
      state = ProjectOrganizationState(
        actor: actor,
        projectId: projectId,
        snapshot: snapshot,
      );
    } catch (error) {
      if (!_current(generation, actor)) return;
      state = ProjectOrganizationState(
        actor: actor,
        projectId: projectId,
        failure: _failure(error),
      );
    }
  }

  Future<bool> mutate(
    Map<String, dynamic> command, {
    required int expectedRevision,
  }) async {
    final prior = state;
    final snapshot = prior.snapshot;
    final actor = prior.actor;
    if (prior.busy ||
        actor == null ||
        snapshot == null ||
        !snapshot.canMutate ||
        ref.read(authSessionProvider).identity?.id != actor) {
      return false;
    }
    if (snapshot.revision != expectedRevision) {
      state = ProjectOrganizationState(
        actor: actor,
        projectId: snapshot.projectId,
        failure: OrganizationFailure.changed,
      );
      return false;
    }
    final generation = ++_generation;
    state = ProjectOrganizationState(
      actor: actor,
      projectId: snapshot.projectId,
      snapshot: snapshot,
      busy: true,
    );
    try {
      final result = await ref
          .read(projectOrganizationGatewayProvider)
          .mutate(
            actor,
            snapshot.projectId,
            snapshot.revision,
            const Uuid().v4(),
            command,
          );
      if (!_current(generation, actor)) return false;
      state = ProjectOrganizationState(
        actor: actor,
        projectId: snapshot.projectId,
        snapshot: result,
      );
      return true;
    } catch (error) {
      if (!_current(generation, actor)) return false;
      // No optimistic success or stale private fallback on role loss, conflict or
      // a lost response. Reload reads the actual result; it does not resend.
      state = ProjectOrganizationState(
        actor: actor,
        projectId: snapshot.projectId,
        failure: _failure(error),
      );
      return false;
    }
  }

  OrganizationFailure _failure(Object error) => error is PostgrestException
      ? switch (error.code) {
          'PT409' || '40001' => OrganizationFailure.changed,
          '42501' => OrganizationFailure.forbidden,
          '55000' => OrganizationFailure.readOnly,
          'PT422' => OrganizationFailure.photo,
          '22023' || '22007' || '23514' => OrganizationFailure.invalid,
          _ => OrganizationFailure.unavailable,
        }
      : OrganizationFailure.unavailable;
}

final projectOrganizationProvider =
    NotifierProvider<ProjectOrganizationController, ProjectOrganizationState>(
      ProjectOrganizationController.new,
    );
