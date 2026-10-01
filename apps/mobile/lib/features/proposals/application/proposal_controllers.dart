import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../cover_media/application/project_cover_reconciler.dart';
import '../../cover_media/domain/cover_media_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
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
    final query = state.query;
    final locality = state.locality;
    final skillIds = state.selectedSkillIds;
    final profileId = reset ? _readyProfileId() : null;
    final requestedRevision = reset ? ++_requestedRevision : null;
    state = PublicProposalsState(
      phase: reset ? ProposalLoadPhase.loading : ProposalLoadPhase.loadingMore,
      items: currentItems,
      requestedItems: state.requestedItems,
      categories: state.categories,
      query: query,
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
          query: query.isEmpty ? null : query,
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
                query: query.isEmpty ? null : query,
                locality: locality.isEmpty ? null : locality,
                skillIds: skillIds.isEmpty ? null : skillIds,
              )
              .catchError((_) => const <RequestedProposalSummary>[])
        else
          Future.value(const <RequestedProposalSummary>[]),
      ]);
      if (!_isPublicCurrent(revision, query, locality, skillIds)) {
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
        query: query,
        locality: locality,
        selectedSkillIds: skillIds,
        hasMore: page.length == proposalPageSize,
      );
    } catch (error) {
      if (_isPublicCurrent(revision, query, locality, skillIds)) {
        state = PublicProposalsState(
          phase: ProposalLoadPhase.failure,
          items: currentItems,
          requestedItems: state.requestedItems,
          categories: state.categories,
          query: state.query,
          locality: state.locality,
          selectedSkillIds: state.selectedSkillIds,
          hasMore: state.hasMore,
          failure: mapProposalFailure(error),
        );
      }
    }
  }

  Future<void> applyFilters({
    String? query,
    required String locality,
    required Set<String> skillIds,
  }) async {
    _publicRevision += 1;
    _requestedRevision += 1;
    state = PublicProposalsState(
      items: const [],
      categories: state.categories,
      query: (query ?? state.query).trim(),
      locality: locality.trim(),
      selectedSkillIds: Set.unmodifiable(skillIds),
    );
    await load();
  }

  Future<void> refreshRequested() async {
    final profileId = _readyProfileId();
    final query = state.query;
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
            query: query.isEmpty ? null : query,
            locality: locality.isEmpty ? null : locality,
            skillIds: skillIds.isEmpty ? null : skillIds,
          );
      if (_isRequestedCurrent(revision, profileId, query, locality, skillIds)) {
        state = _stateWithRequested(List.unmodifiable(requested));
      }
    } catch (_) {
      if (_isRequestedCurrent(revision, profileId, query, locality, skillIds)) {
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

  bool _isPublicCurrent(
    int revision,
    String query,
    String locality,
    Set<String> skillIds,
  ) =>
      ref.mounted &&
      revision == _publicRevision &&
      state.query == query &&
      state.locality == locality &&
      state.selectedSkillIds == skillIds;

  bool _isRequestedCurrent(
    int revision,
    String profileId,
    String query,
    String locality,
    Set<String> skillIds,
  ) =>
      ref.mounted &&
      revision == _requestedRevision &&
      _readyProfileId() == profileId &&
      state.query == query &&
      state.locality == locality &&
      state.selectedSkillIds == skillIds;

  PublicProposalsState _stateWithRequested(
    List<RequestedProposalSummary> requested,
  ) => PublicProposalsState(
    phase: state.phase,
    items: state.items,
    requestedItems: requested,
    categories: state.categories,
    query: state.query,
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
        final failure = mapProposalFailure(error);
        if (failure == ProposalFailureKind.forbidden && proposalId != null) {
          _invalidateStructuralAuthority();
        }
        state = ProposalEditorState(
          phase: ProposalEditorPhase.failure,
          expectedCreatorId: expectedCreatorId,
          proposal: state.proposal,
          categories: state.categories,
          failure: failure,
        );
      }
    }
  }

  Future<String?> saveDraft(
    String expectedCreatorId,
    ProposalInput input, {
    CoverChange coverChange = const CoverChange.unchanged(),
  }) async {
    if (state.isBusy) return null;
    final existing = state.proposal;
    if (existing != null && existing.lifecycle != ProposalLifecycle.draft) {
      return _reject(expectedCreatorId, ProposalFailureKind.invalidState);
    }
    if (!isValidProposalDraft(input) ||
        (input.eventTimezone.trim().isNotEmpty &&
            !isKnownProposalTimeZone(input.eventTimezone))) {
      return _reject(expectedCreatorId, ProposalFailureKind.invalidInput);
    }
    return _saveContent(
      expectedCreatorId,
      input,
      publish: false,
      coverChange: coverChange,
    );
  }

  Future<String?> publish(
    String expectedCreatorId,
    ProposalInput input, {
    CoverChange coverChange = const CoverChange.unchanged(),
  }) async {
    if (state.isBusy) return null;
    final existing = state.proposal;
    if (existing != null && existing.lifecycle != ProposalLifecycle.draft) {
      return _reject(expectedCreatorId, ProposalFailureKind.invalidState);
    }
    if (!isPublishableProposalInput(input) ||
        !isKnownProposalTimeZone(input.eventTimezone)) {
      return _reject(expectedCreatorId, ProposalFailureKind.invalidInput);
    }
    return _saveContent(
      expectedCreatorId,
      input,
      publish: true,
      coverChange: coverChange,
    );
  }

  Future<String?> saveChanges(
    String expectedStructuralActorId,
    ProposalInput input, {
    CoverChange coverChange = const CoverChange.unchanged(),
  }) async {
    if (state.isBusy) return null;
    final existing = state.proposal;
    if (existing == null ||
        existing.lifecycle != ProposalLifecycle.published ||
        !existing.isEditableAt(ref.read(proposalClockProvider)())) {
      return _reject(
        expectedStructuralActorId,
        ProposalFailureKind.invalidState,
      );
    }
    if (!isPublishableProposalInput(input) ||
        !existing.capacity.canUseSettings(
          input.registrationCapacity,
          input.countOrganizersTowardCapacity,
        ) ||
        !isKnownProposalTimeZone(input.eventTimezone)) {
      return _reject(
        expectedStructuralActorId,
        ProposalFailureKind.invalidInput,
      );
    }
    return _saveContent(
      expectedStructuralActorId,
      input,
      publish: false,
      coverChange: coverChange,
    );
  }

  Future<String?> _reject(
    String expectedCreatorId,
    ProposalFailureKind failure,
  ) async {
    state = ProposalEditorState(
      phase: ProposalEditorPhase.failure,
      expectedCreatorId: expectedCreatorId,
      proposal: state.proposal,
      categories: state.categories,
      failure: failure,
    );
    return null;
  }

  Future<String?> _saveContent(
    String expectedCreatorId,
    ProposalInput input, {
    required bool publish,
    required CoverChange coverChange,
  }) async {
    final revision = ++_revision;
    final existingProposal = state.proposal;
    String? persistedProposalId;
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
      persistedProposalId = proposalId;
      if (!_isCurrent(revision)) return null;
      if (existingProposal != null) {
        await gateway.updateOwnProposal(expectedCreatorId, proposalId, input);
        if (!_isCurrent(revision)) return null;
      }
      _requireReadyIdentity(expectedCreatorId);
      if (coverChange.kind != CoverChangeKind.unchanged) {
        try {
          await ref
              .read(projectCoverReconcilerProvider)
              .reconcile(
                ownerProfileId: expectedCreatorId,
                projectId: proposalId,
                change: coverChange,
              );
        } on CoverPersistenceException catch (error) {
          if (!_isCurrent(revision)) return null;
          final canonical = await _refreshAfterPartialSave(
            gateway,
            expectedCreatorId,
            proposalId,
            fallback: existingProposal,
          );
          if (!_isCurrent(revision)) return null;
          state = ProposalEditorState(
            phase: ProposalEditorPhase.failure,
            expectedCreatorId: expectedCreatorId,
            proposal: canonical,
            categories: state.categories,
            coverFailure: error.kind,
            coverPartialSave: existingProposal == null
                ? CoverPartialSaveKind.draftCreated
                : CoverPartialSaveKind.changesSaved,
          );
          return null;
        }
        if (!_isCurrent(revision)) return null;
        _requireReadyIdentity(expectedCreatorId);
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
      _refreshProposalSurfaces(
        expectedCreatorId,
        proposalId,
        refreshPublic:
            publish ||
            existingProposal?.lifecycle == ProposalLifecycle.published,
      );
      return proposalId;
    } catch (error) {
      if (!_isCurrent(revision)) return null;
      final failure = mapProposalFailure(error);
      var canonical = persistedProposalId == null
          ? existingProposal
          : await _refreshAfterPartialSave(
              ref.read(proposalGatewayProvider),
              expectedCreatorId,
              persistedProposalId,
              fallback: existingProposal,
            );
      if (failure == ProposalFailureKind.invalidState &&
          persistedProposalId == null &&
          existingProposal != null) {
        canonical = await _refreshAfterPartialSave(
          ref.read(proposalGatewayProvider),
          expectedCreatorId,
          existingProposal.id,
          fallback: existingProposal,
        );
      }
      if (!_isCurrent(revision)) return null;
      if (failure == ProposalFailureKind.forbidden &&
          existingProposal != null) {
        _invalidateStructuralAuthority();
      }
      state = ProposalEditorState(
        phase: ProposalEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        proposal: canonical,
        categories: state.categories,
        failure: failure,
      );
      return null;
    }
  }

  Future<OwnProposal?> _refreshAfterPartialSave(
    ProposalGateway gateway,
    String expectedCreatorId,
    String proposalId, {
    required OwnProposal? fallback,
  }) async {
    try {
      return await gateway.getOwnProposal(expectedCreatorId, proposalId) ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> cancel(String expectedCreatorId) async {
    final proposal = state.proposal;
    if (state.isBusy ||
        proposal == null ||
        !proposal.canCancelAt(ref.read(proposalClockProvider)())) {
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
      if (updated == null) throw const ProposalNotFoundException();
      state = ProposalEditorState(
        phase: ProposalEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        proposal: updated,
        categories: state.categories,
      );
      _refreshProposalSurfaces(
        expectedCreatorId,
        proposal.id,
        refreshPublic: true,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      final failure = mapProposalFailure(error);
      var authoritativeProposal = proposal;
      if (failure == ProposalFailureKind.invalidState) {
        try {
          authoritativeProposal =
              await ref
                  .read(proposalGatewayProvider)
                  .getOwnProposal(expectedCreatorId, proposal.id) ??
              proposal;
        } catch (_) {
          // Keep the previously loaded record with the safe failure state.
        }
      }
      if (!_isCurrent(revision)) return false;
      if (failure == ProposalFailureKind.forbidden) {
        _invalidateStructuralAuthority();
      }
      state = ProposalEditorState(
        phase: ProposalEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        proposal: authoritativeProposal,
        categories: state.categories,
        failure: failure,
      );
      return false;
    }
  }

  void _refreshProposalSurfaces(
    String expectedProfileId,
    String proposalId, {
    required bool refreshPublic,
  }) {
    ref.invalidate(delegatedProjectsProvider);
    unawaited(ref.read(ownProposalsProvider.notifier).load(expectedProfileId));
    if (refreshPublic) {
      unawaited(ref.read(publicProposalsProvider.notifier).load());
      unawaited(ref.read(proposalDetailProvider.notifier).load(proposalId));
    }
  }

  void _invalidateStructuralAuthority() {
    ref.invalidate(projectManagementRoleProvider);
    ref.invalidate(delegatedProjectsProvider);
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
      'PT422' => ProposalFailureKind.profilePhotoRequired,
      'PT409' => ProposalFailureKind.capacityConflict,
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
