import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_resource_needs/data/project_resource_needs_gateway.dart';
import '../../proposals/data/proposal_gateway.dart';
import '../domain/participation_models.dart';

enum ContributionOptionsPhase { idle, loading, ready, failure }

class ContributionOptionsState {
  const ContributionOptionsState({
    this.phase = ContributionOptionsPhase.idle,
    this.expectedProfileId,
    this.projectId,
    this.projectKind,
    this.skillOptions = const [],
    this.resourceOptions = const [],
  });

  final ContributionOptionsPhase phase;
  final String? expectedProfileId;
  final String? projectId;
  final ProjectKind? projectKind;
  final List<ContributionOption> skillOptions;
  final List<ContributionOption> resourceOptions;

  bool isReadyFor(String profileId, String targetProjectId) =>
      phase == ContributionOptionsPhase.ready &&
      expectedProfileId == profileId &&
      projectId == targetProjectId;
}

class ContributionOptionsController extends Notifier<ContributionOptionsState> {
  var _revision = 0;

  @override
  ContributionOptionsState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _revision++;
        state = const ContributionOptionsState();
      },
    );
    ref.onDispose(() => _revision++);
    return const ContributionOptionsState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String projectId,
    required ProjectKind projectKind,
  }) async {
    final revision = ++_revision;
    final preserve =
        state.expectedProfileId == expectedProfileId &&
        state.projectId == projectId &&
        state.projectKind == projectKind;
    state = ContributionOptionsState(
      phase: ContributionOptionsPhase.loading,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      projectKind: projectKind,
      skillOptions: preserve ? state.skillOptions : const [],
      resourceOptions: preserve ? state.resourceOptions : const [],
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final resourcesFuture = ref
          .read(projectResourceNeedsGatewayProvider)
          .listPublic(projectId);
      final List<ContributionOption> skills;
      final resources = <ContributionOption>[];
      if (projectKind == ProjectKind.oneTime) {
        final results = await Future.wait<dynamic>([
          ref.read(proposalGatewayProvider).getPublicProposal(projectId),
          resourcesFuture,
        ]);
        final detail = results[0];
        if (detail == null) {
          throw const ContributionOptionsUnavailableException();
        }
        skills = [
          for (final skill in detail.summary.skills)
            ContributionOption(
              id: skill.id,
              kind: ContributionOptionKind.skill,
              label: skill.label,
            ),
        ];
        for (final need in results[1]) {
          resources.add(
            ContributionOption(
              id: need.id,
              kind: ContributionOptionKind.resource,
              label: need.title,
            ),
          );
        }
      } else {
        skills = const [];
        for (final need in await resourcesFuture) {
          resources.add(
            ContributionOption(
              id: need.id,
              kind: ContributionOptionKind.resource,
              label: need.title,
            ),
          );
        }
      }
      if (!_isCurrent(revision, expectedProfileId, projectId)) return false;
      state = ContributionOptionsState(
        phase: ContributionOptionsPhase.ready,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        skillOptions: List.unmodifiable(skills),
        resourceOptions: List.unmodifiable(resources),
      );
      return true;
    } catch (_) {
      if (!_isCurrent(revision, expectedProfileId, projectId)) return false;
      state = ContributionOptionsState(
        phase: ContributionOptionsPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        skillOptions: preserve ? state.skillOptions : const [],
        resourceOptions: preserve ? state.resourceOptions : const [],
      );
      return false;
    }
  }

  bool _isCurrent(int revision, String profileId, String projectId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId &&
      state.projectId == projectId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const ContributionOptionsUnavailableException();
    }
  }
}

final contributionOptionsProvider =
    NotifierProvider<ContributionOptionsController, ContributionOptionsState>(
      ContributionOptionsController.new,
    );

class ContributionOptionsUnavailableException implements Exception {
  const ContributionOptionsUnavailableException();
}
