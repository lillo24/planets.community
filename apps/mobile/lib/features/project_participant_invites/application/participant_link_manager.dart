import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/data/project_delegate_gateway.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../data/participant_invitation_gateway.dart';
import '../domain/participant_invitation_models.dart';

class ParticipantLinkManagerState {
  const ParticipantLinkManagerState({
    this.account,
    this.projectId,
    this.kind,
    this.role = ProjectManagementRole.none,
    this.link,
    this.history = const [],
    this.hasMore = false,
    this.busy = false,
    this.ready = false,
    this.failure,
    this.joinable,
    this.previewFailure,
  });
  final String? account;
  final String? projectId;
  final ProjectKind? kind;
  final ProjectManagementRole role;
  final ParticipantLink? link;
  final List<ParticipantLinkHistory> history;
  final bool hasMore;
  final bool busy;
  final bool ready;
  final ParticipantInviteFailure? failure;
  final bool? joinable;
  final ParticipantInviteFailure? previewFailure;
  bool isFor(String account, String project, ProjectKind kind) =>
      this.account == account && projectId == project && this.kind == kind;
  @override
  String toString() => 'ParticipantLinkManagerState(redacted)';
}

enum ParticipantLinkOperation { create, regenerate, revoke }

class ParticipantLinkManager extends Notifier<ParticipantLinkManagerState> {
  var _revision = 0;
  @override
  ParticipantLinkManagerState build() {
    ref.listen(
      authSessionProvider.select(
        (s) => (s.identity?.id, s.accountAccessIdentityId),
      ),
      (_, _) => _clear(),
    );
    ref.listen(projectManagementRoleProvider, (_, role) {
      if (role.expectedProfileId == state.account &&
          role.projectId == state.projectId &&
          ((role.phase == ProjectDelegateLoadPhase.ready &&
                  role.role == ProjectManagementRole.none) ||
              role.failure == ProjectDelegateFailureKind.forbidden)) {
        _revision++;
        state = ParticipantLinkManagerState(
          account: state.account,
          projectId: state.projectId,
          kind: state.kind,
          failure: ParticipantInviteFailure.forbidden,
        );
      }
    });
    ref.onDispose(() => _revision++);
    return const ParticipantLinkManagerState();
  }

  void _clear() {
    _revision++;
    state = const ParticipantLinkManagerState();
  }

  void discard(String? account, String project) {
    if (state.account == account && state.projectId == project) _clear();
  }

  bool _current(
    int revision,
    String account,
    String project,
    ProjectKind kind,
  ) =>
      ref.mounted &&
      revision == _revision &&
      state.isFor(account, project, kind) &&
      ref.read(authSessionProvider).accountAccessIdentityId == account;
  Future<ProjectManagementRole> _role(String account, String project) async {
    final session = ref.read(authSessionProvider);
    if (session.identity?.id != account ||
        session.phase != AuthSessionPhase.ready) {
      throw const PostgrestException(
        message: 'Participant link account changed.',
        code: '42501',
      );
    }
    final role = await ref
        .read(projectDelegateGatewayProvider)
        .getOwnManagementRole(expectedProfileId: account, projectId: project);
    if (!role.isManager) {
      throw const PostgrestException(
        message: 'Participant link management is unavailable.',
        code: '42501',
      );
    }
    return role;
  }

  Future<({bool? available, ParticipantInviteFailure? failure})> _availability(
    ParticipantLink? link,
  ) async {
    if (link == null) return (available: null, failure: null);
    try {
      final preview = await ref
          .read(participantInvitationGatewayProvider)
          .preview(link.token);
      return (available: preview.available, failure: null);
    } catch (error) {
      // This independent read cannot conceal failure or prevent useful revocation.
      return (available: null, failure: participantInviteFailure(error));
    }
  }

  Future<void> load(
    String account,
    String project,
    ProjectKind kind, {
    bool more = false,
  }) async {
    if (state.busy && state.isFor(account, project, kind)) return;
    final previous = state;
    if (more &&
        (!previous.isFor(account, project, kind) ||
            !previous.hasMore ||
            previous.history.isEmpty)) {
      return;
    }
    final revision = ++_revision;
    state = ParticipantLinkManagerState(
      account: account,
      projectId: project,
      kind: kind,
      busy: true,
    );
    try {
      final role = await _role(account, project);
      if (!_current(revision, account, project, kind)) return;
      final gateway = ref.read(participantInvitationGatewayProvider);
      final link = await gateway.current(account, project);
      if (!_current(revision, account, project, kind)) return;
      final page = await gateway.history(
        account,
        project,
        before: more ? previous.history.last : null,
      );
      if (!_current(revision, account, project, kind)) return;
      final availability = await _availability(link);
      if (!_current(revision, account, project, kind)) return;
      state = ParticipantLinkManagerState(
        account: account,
        projectId: project,
        kind: kind,
        role: role,
        link: link,
        ready: true,
        history: List.unmodifiable(
          more ? [...previous.history, ...page] : page,
        ),
        hasMore: page.length == 20,
        joinable: availability.available,
        previewFailure: availability.failure,
      );
    } catch (error) {
      if (_current(revision, account, project, kind)) {
        state = ParticipantLinkManagerState(
          account: account,
          projectId: project,
          kind: kind,
          failure: participantInviteFailure(error),
        );
      }
    }
  }

  Future<void> mutate(
    String account,
    String project,
    ProjectKind kind,
    ParticipantLinkOperation operation, {
    String? displayedInvitationId,
  }) async {
    if (state.busy) return;
    // Destructive actions require a retrieved canonical state. Create is an explicit get-or-create.
    if (operation != ParticipantLinkOperation.create &&
        (!state.isFor(account, project, kind) || !state.ready)) {
      return;
    }
    if (operation == ParticipantLinkOperation.revoke &&
        (displayedInvitationId == null ||
            displayedInvitationId != state.link?.id)) {
      return;
    }
    final revision = ++_revision;
    state = ParticipantLinkManagerState(
      account: account,
      projectId: project,
      kind: kind,
      busy: true,
    );
    ParticipantInviteFailure? failure;
    try {
      await _role(account, project);
      if (!_current(revision, account, project, kind)) return;
      final gateway = ref.read(participantInvitationGatewayProvider);
      switch (operation) {
        case ParticipantLinkOperation.create:
          await gateway.create(account, project);
        case ParticipantLinkOperation.regenerate:
          await gateway.regenerate(account, project);
        case ParticipantLinkOperation.revoke:
          await gateway.revoke(account, project, displayedInvitationId!);
      }
    } catch (error) {
      failure = participantInviteFailure(error);
    }
    if (!_current(revision, account, project, kind)) return;
    if (failure == ParticipantInviteFailure.forbidden) {
      state = ParticipantLinkManagerState(
        account: account,
        projectId: project,
        kind: kind,
        failure: failure,
      );
      return;
    }
    // Also after uncertain transport: retrieve, never blindly repeat rotation/revocation.
    try {
      final role = await _role(account, project);
      if (!_current(revision, account, project, kind)) return;
      final gateway = ref.read(participantInvitationGatewayProvider);
      final link = await gateway.current(account, project);
      if (!_current(revision, account, project, kind)) return;
      final history = await gateway.history(account, project);
      if (!_current(revision, account, project, kind)) return;
      final availability = await _availability(link);
      if (!_current(revision, account, project, kind)) return;
      state = ParticipantLinkManagerState(
        account: account,
        projectId: project,
        kind: kind,
        role: role,
        link: link,
        ready: true,
        history: List.unmodifiable(history),
        hasMore: history.length == 20,
        failure: failure,
        joinable: availability.available,
        previewFailure: availability.failure,
      );
    } catch (error) {
      if (_current(revision, account, project, kind)) {
        state = ParticipantLinkManagerState(
          account: account,
          projectId: project,
          kind: kind,
          failure: participantInviteFailure(error),
        );
      }
    }
  }

  /// Revalidate role and retrieve a fresh secret immediately before intentional disclosure.
  Future<ParticipantLink?> forSharing(
    String account,
    String project,
    ProjectKind kind,
  ) async {
    await load(account, project, kind);
    if (!state.isFor(account, project, kind) ||
        state.busy ||
        !state.ready ||
        !state.role.isManager) {
      return null;
    }
    return state.link;
  }
}

final participantLinkManagerProvider =
    NotifierProvider<ParticipantLinkManager, ParticipantLinkManagerState>(
      ParticipantLinkManager.new,
    );
