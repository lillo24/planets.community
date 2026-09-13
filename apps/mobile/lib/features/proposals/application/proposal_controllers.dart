import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../data/proposal_gateway.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

final proposalClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class PublicProposalsController extends Notifier<PublicProposalsState> {
  var _publicRevision = 0;
  var _requestedRevision = 0;

  @override
  PublicProposalsState build() {
    ref.listen(
      authSessionProvider.select(
        (session) => (session.phase, session.identity?.id),
      ),
      (_, next) {
        _requestedRevision++;
        state = _stateWithRequested(const []);
        if (next.$1 == AuthSessionPhase.ready && next.$2 != null) {
          unawaited(refreshRequested());
        }
      },
    );
    ref.listen(ownParticipationProvider, (_, next) {
      final profileId = _readyProfileId();
      if (profileId != null && next.isReadyFor(profileId)) {
        unawaited(refreshRequested());
      }
    });
    ref.onDispose(() {
      _publicRevision++;
      _requestedRevision++;
    });
    return const PublicProposalsState();
  }

  Future<void> load({bool reset = true}) async {
    if (state.isBusy) {
      return;
    }
    final revision = ++_publicRevision;
    final currentItems = reset ? const <ProposalSummary>[] : state.items;
    final locality = state.locality;
    final skillIds = state.selectedSkillIds;
    final profileId = reset ? _readyProfileId() : null;
    final requestedRevision = reset ? ++_requestedRevision : null;
    state = PublicProposalsState(
      phase: reset ? ProposalLoadPhase.loading : ProposalLoadPhase.loadingMore,
      items: currentItems,
      requestedItems: state.requestedItems,
      categories: state.categories,
      locality: locality,
      selectedSkillIds: skillIds,
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
          locality: locality.isEmpty ? null : locality,
          skillIds: skillIds.isEmpty ? null : skillIds,
        ),
        if (state.categories.isEmpty)
          gateway.loadSkillCatalog()
        else
          Future.value(state.categories),
        if (profileId != null)
          gateway
              .listOwnPendingRequestedProposals(
                profileId,
                locality: locality.isEmpty ? null : locality,
                skillIds: skillIds.isEmpty ? null : skillIds,
              )
              .catchError((_) => const <RequestedProposalSummary>[])
        else
          Future.value(const <RequestedProposalSummary>[]),
      ]);
      if (!_isPublicCurrent(revision, locality, skillIds)) {
        return;
      }
      final page = results[0] as List<ProposalSummary>;
      final categories = results[1] as List<ProposalSkillCategory>;
      final requested = results[2] as List<RequestedProposalSummary>;
      final acceptRequested =
          reset &&
          requestedRevision == _requestedRevision &&
          _readyProfileId() == profileId;
      state = PublicProposalsState(
        phase: ProposalLoadPhase.ready,
        items: List.unmodifiable([...currentItems, ...page]),
        requestedItems: acceptRequested
            ? List.unmodifiable(requested)
            : state.requestedItems,
        categories: List.unmodifiable(categories),
        locality: locality,
        selectedSkillIds: skillIds,
        hasMore: page.length == proposalPageSize,
      );
    } catch (error) {
      if (_isPublicCurrent(revision, locality, skillIds)) {
        state = PublicProposalsState(
          phase: ProposalLoadPhase.failure,
          items: currentItems,
          requestedItems: state.requestedItems,
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
    _publicRevision += 1;
    _requestedRevision += 1;
    state = PublicProposalsState(
      items: const [],
      categories: state.categories,
      locality: locality.trim(),
      selectedSkillIds: Set.unmodifiable(skillIds),
    );
    await load();
  }

  Future<void> refreshRequested() async {
    final profileId = _readyProfileId();
    final locality = state.locality;
    final skillIds = state.selectedSkillIds;
    final revision = ++_requestedRevision;
    if (profileId == null) {
      state = _stateWithRequested(const []);
      return;
    }
    try {
      final requested = await ref
          .read(proposalGatewayProvider)
          .listOwnPendingRequestedProposals(
            profileId,
            locality: locality.isEmpty ? null : locality,
            skillIds: skillIds.isEmpty ? null : skillIds,
          );
      if (_isRequestedCurrent(revision, profileId, locality, skillIds)) {
        state = _stateWithRequested(List.unmodifiable(requested));
      }
    } catch (_) {
      if (_isRequestedCurrent(revision, profileId, locality, skillIds)) {
        state = _stateWithRequested(const []);
      }
    }
  }

  String? _readyProfileId() {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
  }

  bool _isPublicCurrent(int revision, String locality, Set<String> skillIds) =>
      ref.mounted &&
      revision == _publicRevision &&
      state.locality == locality &&
      state.selectedSkillIds == skillIds;

  bool _isRequestedCurrent(
    int revision,
    String profileId,
    String locality,
    Set<String> skillIds,
  ) =>
      ref.mounted &&
      revision == _requestedRevision &&
      _readyProfileId() == profileId &&
      state.locality == locality &&
      state.selectedSkillIds == skillIds;

  PublicProposalsState _stateWithRequested(
    List<RequestedProposalSummary> requested,
  ) => PublicProposalsState(
    phase: state.phase,
    items: state.items,
    requestedItems: requested,
    categories: state.categories,
    locality: state.locality,
    selectedSkillIds: state.selectedSkillIds,
    hasMore: state.hasMore,
    failure: state.failure,
  );
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
  OwnProposalsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const OwnProposalsState();
    });
    ref.onDispose(() => _revision++);
    return const OwnProposalsState();
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  Future<void> load(String expectedCreatorId) async {
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
      if (_isCurrent(revision)) {
        state = OwnProposalsState(
          phase: ProposalLoadPhase.ready,
          expectedCreatorId: expectedCreatorId,
          items: List.unmodifiable(items),
        );
      }
    } catch (error) {
      if (_isCurrent(revision)) {
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
    final revision = ++_revision;
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
      if (!_isCurrent(revision)) return false;
      final items = await ref
          .read(proposalGatewayProvider)
          .listOwnProposals(expectedCreatorId);
      if (!_isCurrent(revision)) return false;
      state = OwnProposalsState(
        phase: ProposalLoadPhase.ready,
        expectedCreatorId: expectedCreatorId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
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
    final revision = ++_revision;
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
      if (!_isCurrent(revision)) return false;
      final items = await ref
          .read(proposalGatewayProvider)
          .listOwnProposals(expectedCreatorId);
      if (!_isCurrent(revision)) return false;
      state = OwnProposalsState(
        phase: ProposalLoadPhase.ready,
        expectedCreatorId: expectedCreatorId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
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
  ProposalEditorState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProposalEditorState();
    });
    ref.onDispose(() => _revision++);
    return const ProposalEditorState();
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

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
      if (!_isCurrent(revision)) {
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
      if (_isCurrent(revision)) {
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
    final revision = ++_revision;
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
      if (!_isCurrent(revision)) return null;
      if (existingProposal != null) {
        await gateway.updateOwnProposal(expectedCreatorId, proposalId, input);
        if (!_isCurrent(revision)) return null;
      }
      if (publish) {
        await gateway.publishProposal(expectedCreatorId, proposalId);
        if (!_isCurrent(revision)) return null;
      }
      final proposal = await gateway.getOwnProposal(
        expectedCreatorId,
        proposalId,
      );
      if (!_isCurrent(revision)) return null;
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
      if (!_isCurrent(revision)) return null;
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
    final revision = ++_revision;
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
      if (!_isCurrent(revision)) return false;
      final updated = await ref
          .read(proposalGatewayProvider)
          .getOwnProposal(expectedCreatorId, proposal.id);
      if (!_isCurrent(revision)) return false;
      state = ProposalEditorState(
        phase: ProposalEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        proposal: updated,
        categories: state.categories,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
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
