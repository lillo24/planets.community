import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_delegates/data/project_delegate_gateway.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../data/proposal_gateway.dart';
import '../domain/proposal_models.dart';
import 'proposal_controllers.dart';

enum ProposalSkillsFailure {
  unavailable,
  forbidden,
  conflict,
  readOnly,
  invalid,
}

class ProposalSkillsState {
  const ProposalSkillsState({
    this.actorId,
    this.proposal,
    this.role = ProjectManagementRole.none,
    this.categories = const [],
    this.baseline = const {},
    this.edits = const {},
    this.busy = false,
    this.savedUnverified = false,
    this.failure,
  });

  final String? actorId;
  final OwnProposal? proposal;
  final ProjectManagementRole role;
  final List<ProposalSkillCategory> categories;
  final Map<String, ProposalSkillImportance> baseline, edits;
  final bool busy, savedUnverified;
  final ProposalSkillsFailure? failure;
  bool get dirty => !mapEquals(baseline, edits);
  bool editableAt(DateTime now) =>
      !busy &&
      !savedUnverified &&
      role.hasStructuralAuthority &&
      proposal?.isEditableAt(now) == true &&
      failure != ProposalSkillsFailure.forbidden &&
      failure != ProposalSkillsFailure.readOnly &&
      failure != ProposalSkillsFailure.conflict;
}

/// One Proposal and rendered identity; no full editor content is ever written.
class ProposalSkillsController extends Notifier<ProposalSkillsState> {
  ProposalSkillsController(this.projectId);
  final String projectId;
  int _revision = 0;

  @override
  ProposalSkillsState build() {
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      _,
    ) {
      _revision++;
      state = const ProposalSkillsState();
    });
    ref.onDispose(() => _revision++);
    return const ProposalSkillsState();
  }

  bool _current(int revision, String actor) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == actor;

  ProposalSkillsState _copy({
    bool busy = false,
    bool? savedUnverified,
    ProposalSkillsFailure? failure,
    Map<String, ProposalSkillImportance>? edits,
    Map<String, ProposalSkillImportance>? baseline,
  }) => ProposalSkillsState(
    actorId: state.actorId,
    proposal: state.proposal,
    role: state.role,
    categories: state.categories,
    baseline: baseline ?? state.baseline,
    edits: edits ?? state.edits,
    busy: busy,
    savedUnverified: savedUnverified ?? state.savedUnverified,
    failure: failure,
  );

  Future<bool> load(String actor, {bool discardEdits = false}) async {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != actor) {
      state = const ProposalSkillsState(
        failure: ProposalSkillsFailure.forbidden,
      );
      return false;
    }
    final revision = ++_revision;
    final previous = state.actorId == actor
        ? state
        : const ProposalSkillsState();
    state = ProposalSkillsState(
      actorId: actor,
      proposal: previous.proposal,
      role: previous.role,
      categories: previous.categories,
      baseline: previous.baseline,
      edits: previous.edits,
      busy: true,
      savedUnverified: previous.savedUnverified,
    );
    try {
      if (!_current(revision, actor)) {
        throw const ProposalIdentityChangedException();
      }
      final role = await ref
          .read(projectDelegateGatewayProvider)
          .getOwnManagementRole(expectedProfileId: actor, projectId: projectId);
      if (!_current(revision, actor)) return false;
      if (!role.hasStructuralAuthority) {
        throw const ProposalIdentityChangedException();
      }
      final gateway = ref.read(proposalGatewayProvider);
      final results = await Future.wait<dynamic>([
        gateway.getOwnProposal(actor, projectId),
        gateway.loadSkillCatalog(),
      ]);
      if (!_current(revision, actor)) return false;
      final proposal = results[0] as OwnProposal?;
      if (proposal == null) throw const ProposalNotFoundException();
      final canonical = {for (final s in proposal.skills) s.id: s.importance};
      final preserve = previous.dirty && !discardEdits;
      state = ProposalSkillsState(
        actorId: actor,
        role: role,
        proposal: proposal,
        categories: List.unmodifiable(
          results[1] as List<ProposalSkillCategory>,
        ),
        baseline: Map.unmodifiable(preserve ? previous.baseline : canonical),
        edits: Map.unmodifiable(preserve ? previous.edits : canonical),
        failure: !proposal.isEditableAt(ref.read(proposalClockProvider)())
            ? ProposalSkillsFailure.readOnly
            : preserve && !mapEquals(previous.baseline, canonical)
            ? ProposalSkillsFailure.conflict
            : null,
      );
      return true;
    } catch (error) {
      if (_current(revision, actor)) state = _copy(failure: _failure(error));
      return false;
    }
  }

  void change(Map<String, ProposalSkillImportance> values) {
    if (!state.editableAt(ref.read(proposalClockProvider)())) return;
    state = _copy(edits: Map.unmodifiable(values));
  }

  void discard() =>
      state = _copy(edits: state.baseline, failure: state.failure);

  Future<bool> save() async {
    final actor = state.actorId;
    if (actor == null ||
        !state.dirty ||
        !state.editableAt(ref.read(proposalClockProvider)())) {
      return false;
    }
    final revision = ++_revision;
    final edits = state.edits;
    state = _copy(busy: true);
    var committed = false;
    try {
      if (!_current(revision, actor)) return false;
      final gateway = ref.read(proposalGatewayProvider);
      await gateway.updateProposalSkills(
        actor,
        projectId,
        expectedSkills: state.baseline,
        skills: edits,
      );
      committed = true;
      if (!_current(revision, actor)) return false;
      // Acknowledged writes refresh existing detail/list consumers immediately.
      unawaited(ref.read(proposalDetailProvider.notifier).load(projectId));
      unawaited(ref.read(publicProposalsProvider.notifier).load());
      unawaited(ref.read(ownProposalsProvider.notifier).load(actor));
      final proposal = await gateway.getOwnProposal(actor, projectId);
      if (!_current(revision, actor)) return false;
      if (proposal == null) throw const ProposalNotFoundException();
      final canonical = {for (final s in proposal.skills) s.id: s.importance};
      state = ProposalSkillsState(
        actorId: actor,
        role: state.role,
        proposal: proposal,
        categories: state.categories,
        baseline: Map.unmodifiable(canonical),
        edits: Map.unmodifiable(canonical),
      );
      return true;
    } catch (error) {
      if (_current(revision, actor)) {
        state = _copy(
          failure: _failure(error),
          savedUnverified: committed,
          baseline: committed ? edits : null,
        );
      }
      return false;
    }
  }
}

ProposalSkillsFailure _failure(Object error) {
  if (error is ProposalIdentityChangedException) {
    return ProposalSkillsFailure.forbidden;
  }
  if (error is ProposalNotFoundException) return ProposalSkillsFailure.readOnly;
  if (error is PostgrestException) {
    return switch (error.code) {
      '42501' => ProposalSkillsFailure.forbidden,
      '40001' => ProposalSkillsFailure.conflict,
      '55000' => ProposalSkillsFailure.readOnly,
      '22023' => ProposalSkillsFailure.invalid,
      _ => ProposalSkillsFailure.unavailable,
    };
  }
  return ProposalSkillsFailure.unavailable;
}

final proposalSkillsProvider = NotifierProvider.autoDispose
    .family<ProposalSkillsController, ProposalSkillsState, String>(
      ProposalSkillsController.new,
    );
