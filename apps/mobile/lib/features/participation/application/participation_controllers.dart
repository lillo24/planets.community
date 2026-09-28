import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../data/participation_gateway.dart';
import '../domain/participation_models.dart';

enum ParticipationFailureKind {
  invalidInput,
  forbidden,
  conflict,
  notFound,
  unavailable,
}

enum ParticipationLoadPhase { idle, loading, ready, failure }

class OwnParticipationState {
  const OwnParticipationState({
    this.phase = ParticipationLoadPhase.idle,
    this.expectedProfileId,
    this.requests = const [],
    this.memberships = const [],
    this.failure,
  });

  final ParticipationLoadPhase phase;
  final String? expectedProfileId;
  final List<OwnProjectJoinRequest> requests;
  final List<OwnProjectMembership> memberships;
  final ParticipationFailureKind? failure;

  bool get isBusy => phase == ParticipationLoadPhase.loading;

  bool isReadyFor(String profileId) =>
      expectedProfileId == profileId && phase == ParticipationLoadPhase.ready;

  ProjectParticipationSnapshot forProject(
    String projectId,
    ProjectKind projectKind,
  ) => resolveProjectParticipation(
    projectId: projectId,
    projectKind: projectKind,
    requests: requests,
    memberships: memberships,
  );
}

class OwnParticipationController extends Notifier<OwnParticipationState> {
  var _revision = 0;

  @override
  OwnParticipationState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const OwnParticipationState();
    });
    ref.onDispose(() => _revision++);
    return const OwnParticipationState();
  }

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  Future<bool> load(String expectedProfileId) async {
    final revision = ++_revision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = OwnParticipationState(
      phase: ParticipationLoadPhase.loading,
      expectedProfileId: expectedProfileId,
      requests: preserve ? state.requests : const [],
      memberships: preserve ? state.memberships : const [],
    );
    try {
      _requireCurrentIdentity(expectedProfileId);
      final gateway = ref.read(participationGatewayProvider);
      final results = await Future.wait<dynamic>([
        gateway.listOwnJoinRequests(expectedProfileId),
        gateway.listOwnMemberships(expectedProfileId),
      ]);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = OwnParticipationState(
        phase: ParticipationLoadPhase.ready,
        expectedProfileId: expectedProfileId,
        requests: List.unmodifiable(results[0] as List<OwnProjectJoinRequest>),
        memberships: List.unmodifiable(
          results[1] as List<OwnProjectMembership>,
        ),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = OwnParticipationState(
        phase: ParticipationLoadPhase.failure,
        expectedProfileId: expectedProfileId,
        requests: state.requests,
        memberships: state.memberships,
        failure: mapParticipationFailure(error),
      );
      return false;
    }
  }

  void _requireCurrentIdentity(String expectedProfileId) {
    if (ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      throw const ParticipationIdentityChangedException();
    }
  }
}

final ownParticipationProvider =
    NotifierProvider<OwnParticipationController, OwnParticipationState>(
      OwnParticipationController.new,
    );

enum ParticipationCommandPhase {
  idle,
  requesting,
  withdrawing,
  leaving,
  failure,
}

class ParticipationCommandState {
  const ParticipationCommandState({
    this.phase = ParticipationCommandPhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.targetId,
    this.failure,
  });

  final ParticipationCommandPhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final String? targetId;
  final ParticipationFailureKind? failure;

  bool get isBusy => switch (phase) {
    ParticipationCommandPhase.requesting ||
    ParticipationCommandPhase.withdrawing ||
    ParticipationCommandPhase.leaving => true,
    ParticipationCommandPhase.idle ||
    ParticipationCommandPhase.failure => false,
  };
}

class ParticipationCommandController
    extends Notifier<ParticipationCommandState> {
  var _revision = 0;

  @override
  ParticipationCommandState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ParticipationCommandState();
    });
    ref.onDispose(() => _revision++);
    return const ParticipationCommandState();
  }

  bool _isCurrent(int revision, String expectedProfileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedProfileId;

  Future<bool> requestToJoin({
    required String expectedProfileId,
    required String projectId,
    required ProjectKind projectKind,
    required String message,
    Set<String> skillIds = const {},
    Set<String> resourceNeedIds = const {},
  }) async {
    final normalizedMessage = message.trim();
    if (state.isBusy ||
        normalizedMessage.length > participationRequestMessageMaxLength ||
        skillIds.length > participationSkillSelectionMax ||
        resourceNeedIds.length > participationResourceNeedSelectionMax) {
      if (!state.isBusy) {
        state = ParticipationCommandState(
          phase: ParticipationCommandPhase.failure,
          expectedProfileId: expectedProfileId,
          projectId: projectId,
          failure: ParticipationFailureKind.invalidInput,
        );
      }
      return false;
    }
    final revision = ++_revision;
    state = ParticipationCommandState(
      phase: ParticipationCommandPhase.requesting,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await ref
          .read(participationGatewayProvider)
          .requestToJoin(
            expectedRequesterProfileId: expectedProfileId,
            projectId: projectId,
            message: normalizedMessage.isEmpty ? null : normalizedMessage,
            skillIds: skillIds,
            resourceNeedIds: resourceNeedIds,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      await ref.read(ownParticipationProvider.notifier).load(expectedProfileId);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ParticipationCommandState(
        expectedProfileId: expectedProfileId,
        projectId: projectId,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ParticipationCommandState(
        phase: ParticipationCommandPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        failure: mapParticipationFailure(error),
      );
      return false;
    }
  }

  Future<bool> withdraw({
    required String expectedProfileId,
    required String projectId,
    required String requestId,
  }) async {
    if (state.isBusy) return false;
    final revision = ++_revision;
    state = ParticipationCommandState(
      phase: ParticipationCommandPhase.withdrawing,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      targetId: requestId,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await ref
          .read(participationGatewayProvider)
          .withdrawRequest(
            expectedRequesterProfileId: expectedProfileId,
            requestId: requestId,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      await ref.read(ownParticipationProvider.notifier).load(expectedProfileId);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ParticipationCommandState(
        expectedProfileId: expectedProfileId,
        projectId: projectId,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ParticipationCommandState(
        phase: ParticipationCommandPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        targetId: requestId,
        failure: mapParticipationFailure(error),
      );
      return false;
    }
  }

  Future<bool> leave({
    required String expectedProfileId,
    required String projectId,
    required String membershipId,
  }) async {
    if (state.isBusy) return false;
    final revision = ++_revision;
    state = ParticipationCommandState(
      phase: ParticipationCommandPhase.leaving,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      targetId: membershipId,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await ref
          .read(participationGatewayProvider)
          .leaveProject(
            expectedParticipantProfileId: expectedProfileId,
            membershipId: membershipId,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      ref
          .read(participantMeetingDetailsProvider.notifier)
          .clearProject(projectId);
      await ref.read(ownParticipationProvider.notifier).load(expectedProfileId);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ParticipationCommandState(
        expectedProfileId: expectedProfileId,
        projectId: projectId,
      );
      ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ParticipationCommandState(
        phase: ParticipationCommandPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        targetId: membershipId,
        failure: mapParticipationFailure(error),
      );
      return false;
    }
  }

  void _requireReadyIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      throw const ParticipationIdentityChangedException();
    }
  }
}

final participationCommandProvider =
    NotifierProvider<ParticipationCommandController, ParticipationCommandState>(
      ParticipationCommandController.new,
    );

class ParticipantMeetingDetailsState {
  const ParticipantMeetingDetailsState({
    this.phase = ParticipationLoadPhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.projectKind,
    this.details,
    this.failure,
  });

  final ParticipationLoadPhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final ProjectKind? projectKind;
  final ParticipantMeetingDetails? details;
  final ParticipationFailureKind? failure;

  bool isReadyFor(String profileId, String targetProjectId) =>
      phase == ParticipationLoadPhase.ready &&
      expectedProfileId == profileId &&
      projectId == targetProjectId;
}

class ParticipantMeetingDetailsController
    extends Notifier<ParticipantMeetingDetailsState> {
  var _revision = 0;

  @override
  ParticipantMeetingDetailsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ParticipantMeetingDetailsState();
    });
    ref.onDispose(() => _revision++);
    return const ParticipantMeetingDetailsState();
  }

  bool _isCurrent(int revision, String expectedProfileId, String projectId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedProfileId &&
      state.projectId == projectId;

  Future<void> load({
    required String expectedProfileId,
    required String projectId,
    required ProjectKind projectKind,
  }) async {
    if (state.expectedProfileId == expectedProfileId &&
        state.projectId == projectId &&
        (state.phase == ParticipationLoadPhase.loading ||
            state.phase == ParticipationLoadPhase.ready)) {
      return;
    }
    final revision = ++_revision;
    state = ParticipantMeetingDetailsState(
      phase: ParticipationLoadPhase.loading,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      projectKind: projectKind,
    );
    try {
      _requireCurrentIdentity(expectedProfileId);
      final details = await ref
          .read(participationGatewayProvider)
          .getParticipantMeetingDetails(
            expectedProfileId: expectedProfileId,
            projectId: projectId,
          );
      if (!_isCurrent(revision, expectedProfileId, projectId)) return;
      if (details == null ||
          details.projectId != projectId ||
          details.projectKind != projectKind) {
        throw const ParticipationNotFoundException();
      }
      state = ParticipantMeetingDetailsState(
        phase: ParticipationLoadPhase.ready,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        details: details,
      );
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, projectId)) return;
      state = ParticipantMeetingDetailsState(
        phase: ParticipationLoadPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        failure: mapParticipationFailure(error),
      );
    }
  }

  void clearProject(String projectId) {
    if (state.projectId != projectId) return;
    _revision++;
    state = const ParticipantMeetingDetailsState();
  }

  void _requireCurrentIdentity(String expectedProfileId) {
    if (ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      throw const ParticipationIdentityChangedException();
    }
  }
}

final participantMeetingDetailsProvider =
    NotifierProvider<
      ParticipantMeetingDetailsController,
      ParticipantMeetingDetailsState
    >(ParticipantMeetingDetailsController.new);

enum CreatorParticipationPhase {
  idle,
  loading,
  ready,
  rejecting,
  removing,
  failure,
}

class CreatorParticipationState {
  const CreatorParticipationState({
    this.phase = CreatorParticipationPhase.idle,
    this.expectedManagerId,
    this.projectId,
    this.requests = const [],
    this.members = const [],
    this.actionTargetId,
    this.failure,
  });

  final CreatorParticipationPhase phase;
  final String? expectedManagerId;
  final String? projectId;
  final List<ManagerProjectJoinRequest> requests;
  final List<ManagerProjectMember> members;
  final String? actionTargetId;
  final ParticipationFailureKind? failure;

  bool get isBusy => switch (phase) {
    CreatorParticipationPhase.loading ||
    CreatorParticipationPhase.rejecting ||
    CreatorParticipationPhase.removing => true,
    CreatorParticipationPhase.idle ||
    CreatorParticipationPhase.ready ||
    CreatorParticipationPhase.failure => false,
  };
}

class CreatorParticipationController
    extends Notifier<CreatorParticipationState> {
  var _revision = 0;

  @override
  CreatorParticipationState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const CreatorParticipationState();
    });
    ref.onDispose(() => _revision++);
    return const CreatorParticipationState();
  }

  bool _isCurrent(int revision, String expectedManagerId, String projectId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedManagerId &&
      state.projectId == projectId;

  Future<void> load(String expectedManagerId, String projectId) async {
    if (state.isBusy &&
        state.expectedManagerId == expectedManagerId &&
        state.projectId == projectId) {
      return;
    }
    final revision = ++_revision;
    final preserve =
        state.expectedManagerId == expectedManagerId &&
        state.projectId == projectId;
    state = CreatorParticipationState(
      phase: CreatorParticipationPhase.loading,
      expectedManagerId: expectedManagerId,
      projectId: projectId,
      requests: preserve ? state.requests : const [],
      members: preserve ? state.members : const [],
    );
    try {
      _requireReadyIdentity(expectedManagerId);
      final result = await _fetch(expectedManagerId, projectId);
      if (!_isCurrent(revision, expectedManagerId, projectId)) return;
      state = CreatorParticipationState(
        phase: CreatorParticipationPhase.ready,
        expectedManagerId: expectedManagerId,
        projectId: projectId,
        requests: result.requests,
        members: result.members,
      );
    } catch (error) {
      if (!_isCurrent(revision, expectedManagerId, projectId)) return;
      state = CreatorParticipationState(
        phase: CreatorParticipationPhase.failure,
        expectedManagerId: expectedManagerId,
        projectId: projectId,
        requests: state.requests,
        members: state.members,
        failure: mapParticipationFailure(error),
      );
    }
  }

  Future<bool> reject({
    required String expectedManagerId,
    required String projectId,
    required String requestId,
  }) => _requestMutation(
    phase: CreatorParticipationPhase.rejecting,
    expectedManagerId: expectedManagerId,
    projectId: projectId,
    targetId: requestId,
    refreshProjectChats: false,
    command: (gateway) => gateway.rejectRequest(
      expectedManagerProfileId: expectedManagerId,
      requestId: requestId,
    ),
  );

  Future<bool> remove({
    required String expectedManagerId,
    required String projectId,
    required String membershipId,
  }) => _requestMutation(
    phase: CreatorParticipationPhase.removing,
    expectedManagerId: expectedManagerId,
    projectId: projectId,
    targetId: membershipId,
    refreshProjectChats: true,
    command: (gateway) => gateway.removeMember(
      expectedManagerProfileId: expectedManagerId,
      membershipId: membershipId,
    ),
  );

  Future<bool> _requestMutation({
    required CreatorParticipationPhase phase,
    required String expectedManagerId,
    required String projectId,
    required String targetId,
    required bool refreshProjectChats,
    required Future<void> Function(ParticipationGateway gateway) command,
  }) async {
    if (state.isBusy) return false;
    final revision = ++_revision;
    state = CreatorParticipationState(
      phase: phase,
      expectedManagerId: expectedManagerId,
      projectId: projectId,
      requests: state.requests,
      members: state.members,
      actionTargetId: targetId,
    );
    try {
      _requireReadyIdentity(expectedManagerId);
      await command(ref.read(participationGatewayProvider));
      if (!_isCurrent(revision, expectedManagerId, projectId)) return false;
      final result = await _fetch(expectedManagerId, projectId);
      if (!_isCurrent(revision, expectedManagerId, projectId)) return false;
      state = CreatorParticipationState(
        phase: CreatorParticipationPhase.ready,
        expectedManagerId: expectedManagerId,
        projectId: projectId,
        requests: result.requests,
        members: result.members,
      );
      if (refreshProjectChats) {
        ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      }
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedManagerId, projectId)) return false;
      state = CreatorParticipationState(
        phase: CreatorParticipationPhase.failure,
        expectedManagerId: expectedManagerId,
        projectId: projectId,
        requests: state.requests,
        members: state.members,
        actionTargetId: targetId,
        failure: mapParticipationFailure(error),
      );
      return false;
    }
  }

  Future<
    ({
      List<ManagerProjectJoinRequest> requests,
      List<ManagerProjectMember> members,
    })
  >
  _fetch(String expectedManagerId, String projectId) async {
    final gateway = ref.read(participationGatewayProvider);
    final values = await Future.wait<dynamic>([
      gateway.listProjectJoinRequests(
        expectedManagerProfileId: expectedManagerId,
        projectId: projectId,
      ),
      gateway.listProjectMembers(
        expectedManagerProfileId: expectedManagerId,
        projectId: projectId,
      ),
    ]);
    final requests = [...values[0] as List<ManagerProjectJoinRequest>]
      ..sort((left, right) {
        if (left.isPending != right.isPending) return left.isPending ? -1 : 1;
        return right.createdAt.compareTo(left.createdAt);
      });
    final members = [...values[1] as List<ManagerProjectMember>]
      ..sort((left, right) {
        if (left.isCurrent != right.isCurrent) {
          return left.isCurrent ? -1 : 1;
        }
        return right.joinedAt.compareTo(left.joinedAt);
      });
    return (
      requests: List<ManagerProjectJoinRequest>.unmodifiable(requests),
      members: List<ManagerProjectMember>.unmodifiable(members),
    );
  }

  void _requireReadyIdentity(String expectedManagerId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedManagerId) {
      throw const ParticipationIdentityChangedException();
    }
  }
}

final creatorParticipationProvider =
    NotifierProvider<CreatorParticipationController, CreatorParticipationState>(
      CreatorParticipationController.new,
    );

ParticipationFailureKind mapParticipationFailure(Object error) {
  if (error is ParticipationIdentityChangedException) {
    return ParticipationFailureKind.forbidden;
  }
  if (error is ParticipationNotFoundException) {
    return ParticipationFailureKind.notFound;
  }
  if (error is FormatException || error is TypeError) {
    return ParticipationFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ParticipationFailureKind.invalidInput,
      '42501' => ParticipationFailureKind.forbidden,
      '55000' => ParticipationFailureKind.conflict,
      'P0002' => ParticipationFailureKind.notFound,
      _ => ParticipationFailureKind.unavailable,
    };
  }
  return ParticipationFailureKind.unavailable;
}

class ParticipationIdentityChangedException implements Exception {
  const ParticipationIdentityChangedException();
}

class ParticipationNotFoundException implements Exception {
  const ParticipationNotFoundException();
}
