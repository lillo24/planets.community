import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/proposal_gateway.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

final proposalClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class PublicProposalsController extends Notifier<PublicProposalsState> {
  var _revision = 0;

  @override
  PublicProposalsState build() => const PublicProposalsState();

  Future<void> load({bool reset = true}) async {
    if (state.isBusy) {
      return;
    }
    final revision = ++_revision;
    final currentItems = reset ? const <ProposalSummary>[] : state.items;
    state = PublicProposalsState(
      phase: reset ? ProposalLoadPhase.loading : ProposalLoadPhase.loadingMore,
      items: currentItems,
      categories: state.categories,
      locality: state.locality,
      selectedSkillIds: state.selectedSkillIds,
      hasMore: state.hasMore,
    );

    try {
      final gateway = ref.read(proposalGatewayProvider);
      final cursor = reset || currentItems.isEmpty
          ? null
          : currentItems.last.cursor;
      final results = await Future.wait<dynamic>([
        gateway.listPublicProposals(
          limit: proposalPageSize,
          cursor: cursor,
          locality: state.locality.trim().isEmpty ? null : state.locality,
          skillIds: state.selectedSkillIds.isEmpty
              ? null
              : state.selectedSkillIds,
        ),
        if (state.categories.isEmpty)
          gateway.loadSkillCatalog()
        else
          Future.value(state.categories),
      ]);
      if (revision != _revision) {
        return;
      }
      final page = results[0] as List<ProposalSummary>;
      final categories = results[1] as List<ProposalSkillCategory>;
      state = PublicProposalsState(
        phase: ProposalLoadPhase.ready,
        items: List.unmodifiable([...currentItems, ...page]),
        categories: List.unmodifiable(categories),
        locality: state.locality,
        selectedSkillIds: state.selectedSkillIds,
        hasMore: page.length == proposalPageSize,
      );
    } catch (error) {
      if (revision == _revision) {
        state = PublicProposalsState(
          phase: ProposalLoadPhase.failure,
          items: currentItems,
          categories: state.categories,
          locality: state.locality,
          selectedSkillIds: state.selectedSkillIds,
          hasMore: state.hasMore,
          failure: mapProposalFailure(error),
        );
      }
    }
  }

  Future<void> applyFilters({
    required String locality,
    required Set<String> skillIds,
  }) async {
    _revision += 1;
    state = PublicProposalsState(
      items: const [],
      categories: state.categories,
      locality: locality.trim(),
      selectedSkillIds: Set.unmodifiable(skillIds),
    );
    await load();
  }
}

final publicProposalsProvider =
    NotifierProvider<PublicProposalsController, PublicProposalsState>(
      PublicProposalsController.new,
    );

class ProposalDetailController extends Notifier<ProposalDetailState> {
  var _revision = 0;

  @override
  ProposalDetailState build() => const ProposalDetailState();

  Future<void> load(String proposalId) async {
    final revision = ++_revision;
    final current = state.proposalId == proposalId ? state.detail : null;
    state = ProposalDetailState(
      phase: ProposalLoadPhase.loading,
      proposalId: proposalId,
      detail: current,
    );
    try {
      final detail = await ref
          .read(proposalGatewayProvider)
          .getPublicProposal(proposalId);
      if (revision != _revision) {
        return;
      }
      state = ProposalDetailState(
        phase: ProposalLoadPhase.ready,
        proposalId: proposalId,
        detail: detail,
      );
    } catch (error) {
      if (revision == _revision) {
        state = ProposalDetailState(
          phase: ProposalLoadPhase.failure,
          proposalId: proposalId,
          detail: current,
          failure: mapProposalFailure(error),
        );
      }
    }
  }
}

final proposalDetailProvider =
    NotifierProvider<ProposalDetailController, ProposalDetailState>(
      ProposalDetailController.new,
    );

class OwnProposalsController extends Notifier<OwnProposalsState> {
  var _revision = 0;

  @override
  OwnProposalsState build() => const OwnProposalsState();

  Future<void> load(String expectedCreatorId) async {
    if (state.isBusy) {
      return;
    }
    final revision = ++_revision;
    state = OwnProposalsState(
      phase: ProposalLoadPhase.loading,
      expectedCreatorId: expectedCreatorId,
      items: state.expectedCreatorId == expectedCreatorId
          ? state.items
          : const [],
    );
    try {
      _requireCurrentIdentity(expectedCreatorId);
      final items = await ref
          .read(proposalGatewayProvider)
          .listOwnProposals(expectedCreatorId);
      if (revision == _revision) {
        state = OwnProposalsState(
          phase: ProposalLoadPhase.ready,
          expectedCreatorId: expectedCreatorId,
          items: List.unmodifiable(items),
        );
      }
    } catch (error) {
      if (revision == _revision) {
        state = OwnProposalsState(
          phase: ProposalLoadPhase.failure,
          expectedCreatorId: expectedCreatorId,
          items: state.items,
          failure: mapProposalFailure(error),
        );
      }
    }
  }

  Future<bool> publish(String expectedCreatorId, String proposalId) async {
    if (state.isBusy) {
      return false;
    }
    state = OwnProposalsState(
      phase: ProposalLoadPhase.loading,
      expectedCreatorId: expectedCreatorId,
      items: state.items,
    );
    try {
      _requireReadyIdentity(expectedCreatorId);
      await ref
          .read(proposalGatewayProvider)
          .publishProposal(expectedCreatorId, proposalId);
      final items = await ref
          .read(proposalGatewayProvider)
          .listOwnProposals(expectedCreatorId);
      state = OwnProposalsState(
        phase: ProposalLoadPhase.ready,
        expectedCreatorId: expectedCreatorId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      state = OwnProposalsState(
        phase: ProposalLoadPhase.failure,
        expectedCreatorId: expectedCreatorId,
        items: state.items,
        failure: mapProposalFailure(error),
      );
      return false;
    }
  }

  Future<bool> cancel(String expectedCreatorId, String proposalId) async {
    if (state.isBusy) {
      return false;
    }
    state = OwnProposalsState(
      phase: ProposalLoadPhase.loading,
      expectedCreatorId: expectedCreatorId,
      items: state.items,
    );
    try {
      _requireCurrentIdentity(expectedCreatorId);
      await ref
          .read(proposalGatewayProvider)
          .cancelProposal(expectedCreatorId, proposalId);
      final items = await ref
          .read(proposalGatewayProvider)
          .listOwnProposals(expectedCreatorId);
      state = OwnProposalsState(
        phase: ProposalLoadPhase.ready,
        expectedCreatorId: expectedCreatorId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      state = OwnProposalsState(
        phase: ProposalLoadPhase.failure,
        expectedCreatorId: expectedCreatorId,
        items: state.items,
        failure: mapProposalFailure(error),
      );
      return false;
    }
  }

  void _requireCurrentIdentity(String expectedCreatorId) {
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null || identity.id != expectedCreatorId) {
      throw const ProposalIdentityChangedException();
    }
  }

  void _requireReadyIdentity(String expectedCreatorId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedCreatorId) {
      throw const ProposalIdentityChangedException();
    }
  }
}

final ownProposalsProvider =
    NotifierProvider<OwnProposalsController, OwnProposalsState>(
      OwnProposalsController.new,
    );

class ProposalEditorController extends Notifier<ProposalEditorState> {
  var _revision = 0;

  @override
  ProposalEditorState build() => const ProposalEditorState();

  Future<void> load(String expectedCreatorId, String? proposalId) async {
    final revision = ++_revision;
    state = ProposalEditorState(
      phase: ProposalEditorPhase.loading,
      expectedCreatorId: expectedCreatorId,
      proposal:
          state.expectedCreatorId == expectedCreatorId &&
              state.proposal?.id == proposalId
          ? state.proposal
          : null,
      categories: state.categories,
    );
    try {
      _requireReadyIdentity(expectedCreatorId);
      final results = await Future.wait<dynamic>([
        ref.read(proposalGatewayProvider).loadSkillCatalog(),
        if (proposalId == null)
          Future<OwnProposal?>.value(null)
        else
          ref
              .read(proposalGatewayProvider)
              .getOwnProposal(expectedCreatorId, proposalId),
      ]);
      if (revision != _revision) {
        return;
      }
      final proposal = results[1] as OwnProposal?;
      if (proposalId != null && proposal == null) {
        throw const ProposalNotFoundException();
      }
      state = ProposalEditorState(
        phase: ProposalEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        proposal: proposal,
        categories: List.unmodifiable(
          results[0] as List<ProposalSkillCategory>,
        ),
      );
    } catch (error) {
      if (revision == _revision) {
        state = ProposalEditorState(
          phase: ProposalEditorPhase.failure,
          expectedCreatorId: expectedCreatorId,
          proposal: state.proposal,
          categories: state.categories,
          failure: mapProposalFailure(error),
        );
      }
    }
  }

  Future<String?> saveDraft(
    String expectedCreatorId,
    ProposalInput input,
  ) async {
    if (state.isBusy ||
        !isValidProposalDraft(input) ||
        (input.eventTimezone.trim().isNotEmpty &&
            !isKnownProposalTimeZone(input.eventTimezone))) {
      state = ProposalEditorState(
        phase: ProposalEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        proposal: state.proposal,
        categories: state.categories,
        failure: ProposalFailureKind.invalidInput,
      );
      return null;
    }
    return _saveContent(expectedCreatorId, input, publish: false);
  }

  Future<String?> publish(String expectedCreatorId, ProposalInput input) async {
    if (state.isBusy ||
        !isPublishableProposalInput(input) ||
        !isKnownProposalTimeZone(input.eventTimezone)) {
      state = ProposalEditorState(
        phase: ProposalEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        proposal: state.proposal,
        categories: state.categories,
        failure: ProposalFailureKind.invalidInput,
      );
      return null;
    }
    return _saveContent(expectedCreatorId, input, publish: true);
  }

  Future<String?> _saveContent(
    String expectedCreatorId,
    ProposalInput input, {
    required bool publish,
  }) async {
    final existingProposal = state.proposal;
    state = ProposalEditorState(
      phase: publish
          ? ProposalEditorPhase.publishing
          : ProposalEditorPhase.saving,
      expectedCreatorId: expectedCreatorId,
      proposal: existingProposal,
      categories: state.categories,
    );
    try {
      _requireReadyIdentity(expectedCreatorId);
      final gateway = ref.read(proposalGatewayProvider);
      final proposalId = existingProposal == null
          ? await gateway.createDraft(expectedCreatorId, input)
          : existingProposal.isEditableAt(ref.read(proposalClockProvider)())
          ? existingProposal.id
          : throw const ProposalInvalidStateException();
      if (existingProposal != null) {
        await gateway.updateOwnProposal(expectedCreatorId, proposalId, input);
      }
      if (publish) {
        await gateway.publishProposal(expectedCreatorId, proposalId);
      }
      final proposal = await gateway.getOwnProposal(
        expectedCreatorId,
        proposalId,
      );
      if (proposal == null) {
        throw const ProposalNotFoundException();
      }
      state = ProposalEditorState(
        phase: ProposalEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        proposal: proposal,
        categories: state.categories,
      );
      return proposalId;
    } catch (error) {
      state = ProposalEditorState(
        phase: ProposalEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        proposal: existingProposal,
        categories: state.categories,
        failure: mapProposalFailure(error),
      );
      return null;
    }
  }

  Future<bool> cancel(String expectedCreatorId) async {
    final proposal = state.proposal;
    if (state.isBusy || proposal == null) {
      return false;
    }
    state = ProposalEditorState(
      phase: ProposalEditorPhase.cancelling,
      expectedCreatorId: expectedCreatorId,
      proposal: proposal,
      categories: state.categories,
    );
    try {
      _requireCurrentIdentity(expectedCreatorId);
      await ref
          .read(proposalGatewayProvider)
          .cancelProposal(expectedCreatorId, proposal.id);
      final updated = await ref
          .read(proposalGatewayProvider)
          .getOwnProposal(expectedCreatorId, proposal.id);
      state = ProposalEditorState(
        phase: ProposalEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        proposal: updated,
        categories: state.categories,
      );
      return true;
    } catch (error) {
      state = ProposalEditorState(
        phase: ProposalEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        proposal: proposal,
        categories: state.categories,
        failure: mapProposalFailure(error),
      );
      return false;
    }
  }

  void _requireCurrentIdentity(String expectedCreatorId) {
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null || identity.id != expectedCreatorId) {
      throw const ProposalIdentityChangedException();
    }
  }

  void _requireReadyIdentity(String expectedCreatorId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedCreatorId) {
      throw const ProposalIdentityChangedException();
    }
  }
}

final proposalEditorProvider =
    NotifierProvider<ProposalEditorController, ProposalEditorState>(
      ProposalEditorController.new,
    );

ProposalFailureKind mapProposalFailure(Object error) {
  if (error is ProposalIdentityChangedException) {
    return ProposalFailureKind.forbidden;
  }
  if (error is ProposalInvalidStateException ||
      error is ProposalNotFoundException) {
    return ProposalFailureKind.invalidState;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProposalFailureKind.invalidInput,
      '42501' => ProposalFailureKind.forbidden,
      '55000' => ProposalFailureKind.invalidState,
      _ => ProposalFailureKind.unavailable,
    };
  }
  return ProposalFailureKind.unavailable;
}

class ProposalIdentityChangedException implements Exception {
  const ProposalIdentityChangedException();
}

class ProposalInvalidStateException implements Exception {
  const ProposalInvalidStateException();
}

class ProposalNotFoundException implements Exception {
  const ProposalNotFoundException();
}
