import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../messages/application/messages_controllers.dart';
import '../../resource_chat/application/resource_chat_refresh.dart';
import '../../resource_requests/application/resource_request_controllers.dart';
import '../data/resource_exchange_gateway.dart';
import '../domain/resource_exchange_models.dart';
import 'resource_exchange_refresh.dart';

enum ResourceExchangeFailureKind {
  invalidInput,
  forbidden,
  notFound,
  conflict,
  milestoneConflict,
  cancellationConflict,
  unavailable,
}

enum ResourceExchangePhase { idle, loading, ready, failure }

enum ResourceExchangeAction {
  proposing,
  accepting,
  rejecting,
  withdrawingProposal,
  cancellingAgreement,
}

class ResourceExchangeState {
  const ResourceExchangeState({
    this.phase = ResourceExchangePhase.idle,
    this.expectedProfileId,
    this.chatId,
    this.requestId,
    this.expectedAgreementId,
    this.expectedListingId,
    this.expectedOwnerProfileId,
    this.expectedRequesterProfileId,
    this.snapshot,
    this.draft,
    this.draftExpectedCurrentTermsId,
    this.draftExpectedPendingTermsId,
    this.draftIssues = const {},
    this.action,
    this.milestoneAction,
    this.failure,
    this.hasRefreshWarning = false,
    this.eventLoadFailure = false,
  });

  static const _unchanged = Object();

  final ResourceExchangePhase phase;
  final String? expectedProfileId;
  final String? chatId;
  final String? requestId;
  final String? expectedAgreementId;
  final String? expectedListingId;
  final String? expectedOwnerProfileId;
  final String? expectedRequesterProfileId;
  final ResourceExchangeSnapshot? snapshot;
  final ResourceExchangeTermsDraft? draft;
  final String? draftExpectedCurrentTermsId;
  final String? draftExpectedPendingTermsId;
  final Set<ResourceExchangeDraftIssue> draftIssues;
  final ResourceExchangeAction? action;
  final ResourceExchangeMilestoneAction? milestoneAction;
  final ResourceExchangeFailureKind? failure;
  final bool hasRefreshWarning;
  final bool eventLoadFailure;

  bool get isActing => action != null || milestoneAction != null;
  bool get isEditing => draft != null;

  ResourceExchangeState copyWith({
    ResourceExchangePhase? phase,
    Object? snapshot = _unchanged,
    Object? draft = _unchanged,
    Object? draftExpectedCurrentTermsId = _unchanged,
    Object? draftExpectedPendingTermsId = _unchanged,
    Set<ResourceExchangeDraftIssue>? draftIssues,
    Object? action = _unchanged,
    Object? milestoneAction = _unchanged,
    Object? failure = _unchanged,
    bool? hasRefreshWarning,
    bool? eventLoadFailure,
  }) => ResourceExchangeState(
    phase: phase ?? this.phase,
    expectedProfileId: expectedProfileId,
    chatId: chatId,
    requestId: requestId,
    expectedAgreementId: expectedAgreementId,
    expectedListingId: expectedListingId,
    expectedOwnerProfileId: expectedOwnerProfileId,
    expectedRequesterProfileId: expectedRequesterProfileId,
    snapshot: identical(snapshot, _unchanged)
        ? this.snapshot
        : snapshot as ResourceExchangeSnapshot?,
    draft: identical(draft, _unchanged)
        ? this.draft
        : draft as ResourceExchangeTermsDraft?,
    draftExpectedCurrentTermsId:
        identical(draftExpectedCurrentTermsId, _unchanged)
        ? this.draftExpectedCurrentTermsId
        : draftExpectedCurrentTermsId as String?,
    draftExpectedPendingTermsId:
        identical(draftExpectedPendingTermsId, _unchanged)
        ? this.draftExpectedPendingTermsId
        : draftExpectedPendingTermsId as String?,
    draftIssues: draftIssues ?? this.draftIssues,
    action: identical(action, _unchanged)
        ? this.action
        : action as ResourceExchangeAction?,
    milestoneAction: identical(milestoneAction, _unchanged)
        ? this.milestoneAction
        : milestoneAction as ResourceExchangeMilestoneAction?,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as ResourceExchangeFailureKind?,
    hasRefreshWarning: hasRefreshWarning ?? this.hasRefreshWarning,
    eventLoadFailure: eventLoadFailure ?? this.eventLoadFailure,
  );
}

class ResourceExchangeController extends Notifier<ResourceExchangeState> {
  Timer? _refreshTimer;
  var _revision = 0;
  var _isRefreshing = false;

  @override
  ResourceExchangeState build() {
    ref.listen(resourceExchangeRefreshProvider, (_, _) {
      if (state.phase == ResourceExchangePhase.ready &&
          state.snapshot != null) {
        _scheduleRefresh();
      }
    });
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _refreshTimer?.cancel();
      _isRefreshing = false;
      state = const ResourceExchangeState();
    });
    ref.onDispose(() {
      _revision++;
      _refreshTimer?.cancel();
    });
    return const ResourceExchangeState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String chatId,
    required String requestId,
    required String agreementId,
    required String listingId,
    required String ownerProfileId,
    required String requesterProfileId,
  }) async {
    final revision = ++_revision;
    final sameTarget =
        state.expectedProfileId == expectedProfileId &&
        state.chatId == chatId &&
        state.requestId == requestId &&
        state.expectedAgreementId == agreementId;
    state = ResourceExchangeState(
      phase: ResourceExchangePhase.loading,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      requestId: requestId,
      expectedAgreementId: agreementId,
      expectedListingId: listingId,
      expectedOwnerProfileId: ownerProfileId,
      expectedRequesterProfileId: requesterProfileId,
      snapshot: sameTarget ? state.snapshot : null,
      draft: sameTarget ? state.draft : null,
      draftExpectedCurrentTermsId: sameTarget
          ? state.draftExpectedCurrentTermsId
          : null,
      draftExpectedPendingTermsId: sameTarget
          ? state.draftExpectedPendingTermsId
          : null,
      eventLoadFailure: sameTarget && state.eventLoadFailure,
      hasRefreshWarning: sameTarget && state.hasRefreshWarning,
    );
    try {
      final read = await _readCanonical(expectedProfileId);
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _validateContext(read.snapshot.agreement);
      state = state.copyWith(
        phase: ResourceExchangePhase.ready,
        snapshot: read.snapshot,
        failure: read.eventsCurrent
            ? null
            : ResourceExchangeFailureKind.unavailable,
        hasRefreshWarning: !read.eventsCurrent,
        eventLoadFailure: !read.eventsCurrent,
      );
      return read.eventsCurrent;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      state = state.copyWith(
        phase: state.snapshot == null
            ? ResourceExchangePhase.failure
            : ResourceExchangePhase.ready,
        failure: mapResourceExchangeFailure(error),
        hasRefreshWarning: state.snapshot != null,
        eventLoadFailure: state.snapshot != null,
      );
      return false;
    }
  }

  Future<bool> refresh() async {
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (profileId == null ||
        requestId == null ||
        state.snapshot == null ||
        state.isActing ||
        _isRefreshing ||
        !_matchesTarget(profileId, requestId)) {
      return false;
    }
    _isRefreshing = true;
    final revision = _revision;
    try {
      final read = await _readCanonical(profileId);
      if (!_isCurrent(revision, profileId, requestId)) return false;
      _validateContext(read.snapshot.agreement);
      state = state.copyWith(
        phase: ResourceExchangePhase.ready,
        snapshot: read.eventsCurrent ? read.snapshot : state.snapshot,
        failure: read.eventsCurrent
            ? null
            : ResourceExchangeFailureKind.unavailable,
        hasRefreshWarning: !read.eventsCurrent,
        eventLoadFailure: !read.eventsCurrent,
      );
      return read.eventsCurrent;
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = state.copyWith(
        phase: ResourceExchangePhase.ready,
        failure: mapResourceExchangeFailure(error),
        hasRefreshWarning: true,
        eventLoadFailure: true,
      );
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> retry() {
    final profileId = state.expectedProfileId;
    final chatId = state.chatId;
    final requestId = state.requestId;
    final agreementId = state.expectedAgreementId;
    final listingId = state.expectedListingId;
    final ownerProfileId = state.expectedOwnerProfileId;
    final requesterProfileId = state.expectedRequesterProfileId;
    if (profileId == null ||
        chatId == null ||
        requestId == null ||
        agreementId == null ||
        listingId == null ||
        ownerProfileId == null ||
        requesterProfileId == null) {
      return Future.value(false);
    }
    return load(
      expectedProfileId: profileId,
      chatId: chatId,
      requestId: requestId,
      agreementId: agreementId,
      listingId: listingId,
      ownerProfileId: ownerProfileId,
      requesterProfileId: requesterProfileId,
    );
  }

  void startDraft() {
    final snapshot = state.snapshot;
    if (snapshot == null ||
        state.isActing ||
        !snapshot.agreement.lifecycle.canNegotiate) {
      return;
    }
    final baseline = snapshot.pendingTerms ?? snapshot.currentTerms;
    state = state.copyWith(
      draft: baseline == null
          ? const ResourceExchangeTermsDraft()
          : ResourceExchangeTermsDraft.fromTerms(baseline),
      draftExpectedCurrentTermsId: snapshot.agreement.currentTermsId,
      draftExpectedPendingTermsId: snapshot.agreement.pendingTermsId,
      draftIssues: const {},
      failure: null,
    );
  }

  void discardDraft() {
    if (state.isActing) return;
    state = state.copyWith(
      draft: null,
      draftExpectedCurrentTermsId: null,
      draftExpectedPendingTermsId: null,
      draftIssues: const {},
      failure: null,
    );
  }

  void setOwnerTransferKind(ResourceOwnerTransferKind kind) {
    final draft = state.draft;
    if (draft == null || state.isActing) return;
    state = state.copyWith(
      draft: draft.copyWith(
        ownerTransferKind: kind,
        ownerLendStartsAt: kind == ResourceOwnerTransferKind.give
            ? null
            : draft.ownerLendStartsAt,
        ownerLendEndsAt: kind == ResourceOwnerTransferKind.give
            ? null
            : draft.ownerLendEndsAt,
      ),
      draftIssues: const {},
      failure: null,
    );
  }

  void setRequesterTransferKind(ResourceRequesterTransferKind kind) {
    final draft = state.draft;
    if (draft == null || state.isActing) return;
    state = state.copyWith(
      draft: draft.copyWith(
        requesterTransferKind: kind,
        requesterResourceDescription: kind == ResourceRequesterTransferKind.none
            ? ''
            : draft.requesterResourceDescription,
        requesterLendStartsAt: kind == ResourceRequesterTransferKind.lend
            ? draft.requesterLendStartsAt
            : null,
        requesterLendEndsAt: kind == ResourceRequesterTransferKind.lend
            ? draft.requesterLendEndsAt
            : null,
      ),
      draftIssues: const {},
      failure: null,
    );
  }

  void updateDraft({
    Object? ownerLendStartsAt = ResourceExchangeTermsDraft.noChange,
    Object? ownerLendEndsAt = ResourceExchangeTermsDraft.noChange,
    String? requesterResourceDescription,
    Object? requesterLendStartsAt = ResourceExchangeTermsDraft.noChange,
    Object? requesterLendEndsAt = ResourceExchangeTermsDraft.noChange,
    String? privateNote,
  }) {
    final draft = state.draft;
    if (draft == null || state.isActing) return;
    state = state.copyWith(
      draft: draft.copyWith(
        ownerLendStartsAt: ownerLendStartsAt,
        ownerLendEndsAt: ownerLendEndsAt,
        requesterResourceDescription: requesterResourceDescription,
        requesterLendStartsAt: requesterLendStartsAt,
        requesterLendEndsAt: requesterLendEndsAt,
        privateNote: privateNote,
      ),
      draftIssues: const {},
      failure: null,
    );
  }

  Future<bool> submitDraft() async {
    final draft = state.draft;
    final snapshot = state.snapshot;
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (draft == null ||
        snapshot == null ||
        profileId == null ||
        requestId == null ||
        state.isActing ||
        !snapshot.agreement.lifecycle.canNegotiate ||
        !_matchesTarget(profileId, requestId)) {
      return false;
    }
    final issues = draft.validate();
    if (issues.isNotEmpty) {
      state = state.copyWith(
        draftIssues: issues,
        failure: ResourceExchangeFailureKind.invalidInput,
      );
      return false;
    }
    final revision = ++_revision;
    state = state.copyWith(
      action: ResourceExchangeAction.proposing,
      draftIssues: const {},
      failure: null,
    );
    try {
      _requireReadyIdentity(profileId);
      await ref
          .read(resourceExchangeGatewayProvider)
          .proposeTerms(
            expectedProfileId: profileId,
            agreementId: snapshot.agreement.agreementId,
            expectedCurrentTermsId: state.draftExpectedCurrentTermsId,
            expectedPendingTermsId: state.draftExpectedPendingTermsId,
            input: draft.toInput(),
          );
      if (!_isCurrent(revision, profileId, requestId)) return false;
      return await _completeMutation(
        revision: revision,
        profileId: profileId,
        requestId: requestId,
        clearDraft: true,
      );
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      await _recoverMutationFailure(
        error: error,
        revision: revision,
        profileId: profileId,
        requestId: requestId,
        cancellation: false,
      );
      return false;
    }
  }

  Future<bool> acceptPendingTerms() => _pendingMutation(
    ResourceExchangeAction.accepting,
    requireProposer: false,
  );

  Future<bool> rejectPendingTerms() => _pendingMutation(
    ResourceExchangeAction.rejecting,
    requireProposer: false,
  );

  Future<bool> withdrawPendingTerms() => _pendingMutation(
    ResourceExchangeAction.withdrawingProposal,
    requireProposer: true,
  );

  Future<bool> recordMilestone(ResourceExchangeMilestoneAction action) async {
    final snapshot = state.snapshot;
    final current = snapshot?.currentTerms;
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (snapshot == null ||
        current == null ||
        profileId == null ||
        requestId == null ||
        state.isActing ||
        state.eventLoadFailure ||
        !snapshot.milestoneActionsFor(profileId).contains(action) ||
        !_matchesTarget(profileId, requestId)) {
      return false;
    }
    final revision = ++_revision;
    final wasCompleted =
        snapshot.agreement.lifecycle == ResourceExchangeLifecycle.completed;
    state = state.copyWith(
      milestoneAction: action,
      failure: null,
      hasRefreshWarning: false,
    );
    try {
      _requireReadyIdentity(profileId);
      await ref
          .read(resourceExchangeGatewayProvider)
          .recordMilestone(
            expectedProfileId: profileId,
            agreementId: snapshot.agreement.agreementId,
            expectedTermsId: current.termsId,
            legKind: action.legKind,
            eventKind: action.eventKind,
          );
      if (!_isCurrent(revision, profileId, requestId)) return false;
      final read = await _readCanonical(profileId);
      if (!_isCurrent(revision, profileId, requestId)) return false;
      if (!read.eventsCurrent) {
        state = state.copyWith(
          milestoneAction: null,
          failure: ResourceExchangeFailureKind.unavailable,
          hasRefreshWarning: true,
          eventLoadFailure: true,
        );
        _refreshDependentSurfaces();
        return false;
      }
      _validateContext(read.snapshot.agreement);
      final completedNow =
          !wasCompleted &&
          read.snapshot.agreement.lifecycle ==
              ResourceExchangeLifecycle.completed;
      state = state.copyWith(
        phase: ResourceExchangePhase.ready,
        snapshot: read.snapshot,
        milestoneAction: null,
        failure: null,
        hasRefreshWarning: false,
        eventLoadFailure: false,
      );
      _refreshDependentSurfaces(refreshRequest: completedNow);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      final failure = mapResourceExchangeFailure(error);
      ResourceExchangeSnapshot? canonical;
      var eventsCurrent = false;
      if (failure == ResourceExchangeFailureKind.conflict ||
          failure == ResourceExchangeFailureKind.forbidden) {
        try {
          final read = await _readCanonical(profileId);
          canonical = read.snapshot;
          eventsCurrent = read.eventsCurrent;
          _validateContext(canonical.agreement);
        } catch (_) {
          canonical = null;
        }
      }
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = state.copyWith(
        phase: ResourceExchangePhase.ready,
        snapshot: canonical ?? state.snapshot,
        milestoneAction: null,
        failure: failure == ResourceExchangeFailureKind.conflict
            ? ResourceExchangeFailureKind.milestoneConflict
            : failure,
        hasRefreshWarning:
            canonical == null ||
            ((failure == ResourceExchangeFailureKind.conflict ||
                    failure == ResourceExchangeFailureKind.forbidden) &&
                !eventsCurrent),
        eventLoadFailure: canonical == null
            ? state.eventLoadFailure
            : !eventsCurrent,
      );
      if (failure == ResourceExchangeFailureKind.conflict ||
          failure == ResourceExchangeFailureKind.forbidden) {
        _refreshDependentSurfaces();
      }
      return false;
    }
  }

  Future<bool> _pendingMutation(
    ResourceExchangeAction action, {
    required bool requireProposer,
  }) async {
    final snapshot = state.snapshot;
    final pending = snapshot?.pendingTerms;
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (snapshot == null ||
        pending == null ||
        profileId == null ||
        requestId == null ||
        state.isActing ||
        !snapshot.agreement.lifecycle.canNegotiate ||
        (pending.proposedByProfileId == profileId) != requireProposer ||
        !_matchesTarget(profileId, requestId)) {
      return false;
    }
    final revision = ++_revision;
    state = state.copyWith(action: action, failure: null);
    try {
      _requireReadyIdentity(profileId);
      final gateway = ref.read(resourceExchangeGatewayProvider);
      switch (action) {
        case ResourceExchangeAction.accepting:
          await gateway.acceptPendingTerms(
            expectedProfileId: profileId,
            agreementId: snapshot.agreement.agreementId,
            expectedPendingTermsId: pending.termsId,
          );
        case ResourceExchangeAction.rejecting:
          await gateway.rejectPendingTerms(
            expectedProfileId: profileId,
            agreementId: snapshot.agreement.agreementId,
            expectedPendingTermsId: pending.termsId,
          );
        case ResourceExchangeAction.withdrawingProposal:
          await gateway.withdrawPendingTerms(
            expectedProfileId: profileId,
            agreementId: snapshot.agreement.agreementId,
            expectedPendingTermsId: pending.termsId,
          );
        case ResourceExchangeAction.proposing ||
            ResourceExchangeAction.cancellingAgreement:
          throw StateError('Unsupported pending terms action.');
      }
      if (!_isCurrent(revision, profileId, requestId)) return false;
      return await _completeMutation(
        revision: revision,
        profileId: profileId,
        requestId: requestId,
        clearDraft: true,
      );
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      await _recoverMutationFailure(
        error: error,
        revision: revision,
        profileId: profileId,
        requestId: requestId,
        cancellation: false,
      );
      return false;
    }
  }

  Future<bool> cancelAgreement() async {
    final snapshot = state.snapshot;
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (snapshot == null ||
        profileId == null ||
        requestId == null ||
        state.isActing ||
        !snapshot.agreement.lifecycle.canNegotiate ||
        !_matchesTarget(profileId, requestId)) {
      return false;
    }
    final revision = ++_revision;
    state = state.copyWith(
      action: ResourceExchangeAction.cancellingAgreement,
      failure: null,
    );
    try {
      _requireReadyIdentity(profileId);
      await ref
          .read(resourceExchangeGatewayProvider)
          .cancelAgreement(
            expectedProfileId: profileId,
            agreementId: snapshot.agreement.agreementId,
          );
      if (!_isCurrent(revision, profileId, requestId)) return false;
      return await _completeMutation(
        revision: revision,
        profileId: profileId,
        requestId: requestId,
        clearDraft: true,
      );
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      await _recoverMutationFailure(
        error: error,
        revision: revision,
        profileId: profileId,
        requestId: requestId,
        cancellation: true,
      );
      return false;
    }
  }

  Future<bool> _completeMutation({
    required int revision,
    required String profileId,
    required String requestId,
    required bool clearDraft,
  }) async {
    try {
      final read = await _readCanonical(profileId);
      if (!_isCurrent(revision, profileId, requestId)) return false;
      if (!read.eventsCurrent) {
        throw const FormatException(
          'Resource exchange events were unavailable after mutation.',
        );
      }
      _validateContext(read.snapshot.agreement);
      state = state.copyWith(
        phase: ResourceExchangePhase.ready,
        snapshot: read.snapshot,
        draft: clearDraft ? null : state.draft,
        draftExpectedCurrentTermsId: clearDraft
            ? null
            : state.draftExpectedCurrentTermsId,
        draftExpectedPendingTermsId: clearDraft
            ? null
            : state.draftExpectedPendingTermsId,
        draftIssues: const {},
        action: null,
        failure: null,
        hasRefreshWarning: false,
        eventLoadFailure: false,
      );
      _refreshDependentSurfaces();
      return true;
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = state.copyWith(
        action: null,
        failure: mapResourceExchangeFailure(error),
        hasRefreshWarning: true,
      );
      _refreshDependentSurfaces();
      return false;
    }
  }

  Future<void> _recoverMutationFailure({
    required Object error,
    required int revision,
    required String profileId,
    required String requestId,
    required bool cancellation,
  }) async {
    final failure = mapResourceExchangeFailure(error);
    ResourceExchangeSnapshot? canonical;
    if (failure == ResourceExchangeFailureKind.conflict) {
      try {
        final read = await _readCanonical(profileId);
        canonical = read.eventsCurrent ? read.snapshot : null;
        if (canonical != null) _validateContext(canonical.agreement);
      } catch (_) {
        canonical = null;
      }
    }
    if (!_isCurrent(revision, profileId, requestId)) return;
    state = state.copyWith(
      phase: ResourceExchangePhase.ready,
      snapshot: canonical ?? state.snapshot,
      action: null,
      failure: failure == ResourceExchangeFailureKind.conflict && cancellation
          ? ResourceExchangeFailureKind.cancellationConflict
          : failure,
      hasRefreshWarning:
          failure == ResourceExchangeFailureKind.conflict && canonical == null,
      eventLoadFailure:
          failure == ResourceExchangeFailureKind.conflict && canonical == null
          ? true
          : state.eventLoadFailure,
    );
    if (failure == ResourceExchangeFailureKind.conflict) {
      _refreshDependentSurfaces();
    }
  }

  Future<_CanonicalResourceExchangeRead> _readCanonical(
    String profileId,
  ) async {
    _requireReadyIdentity(profileId);
    final requestId = state.requestId;
    final agreementId = state.expectedAgreementId;
    if (requestId == null || agreementId == null) {
      throw const FormatException('Resource exchange target was missing.');
    }
    _TimelineReadFailure? timelineFailure;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _readCanonicalOnce(
          profileId: profileId,
          requestId: requestId,
          agreementId: agreementId,
        );
      } on _TimelineReadFailure catch (error) {
        timelineFailure = error;
      } on FormatException {
        if (attempt == 1) rethrow;
      }
    }
    return _CanonicalResourceExchangeRead(
      snapshot: timelineFailure!.snapshot,
      eventsCurrent: false,
    );
  }

  Future<_CanonicalResourceExchangeRead> _readCanonicalOnce({
    required String profileId,
    required String requestId,
    required String agreementId,
  }) async {
    final gateway = ref.read(resourceExchangeGatewayProvider);
    final agreement = await gateway.getAgreement(
      expectedProfileId: profileId,
      requestId: requestId,
    );
    _validateContext(agreement);
    final terms = await gateway.listTerms(
      expectedProfileId: profileId,
      agreementId: agreementId,
    );
    final base = ResourceExchangeSnapshot.withoutEvents(
      agreement: agreement,
      terms: terms,
    );
    List<ResourceExchangeEvent> events;
    try {
      events = await gateway.listEvents(
        expectedProfileId: profileId,
        agreementId: agreementId,
      );
    } catch (error) {
      throw _TimelineReadFailure(base, error);
    }
    return _CanonicalResourceExchangeRead(
      snapshot: ResourceExchangeSnapshot.reconcile(
        agreement: agreement,
        terms: terms,
        events: events,
      ),
      eventsCurrent: true,
    );
  }

  void _validateContext(ResourceExchangeAgreement agreement) {
    if (agreement.agreementId != state.expectedAgreementId ||
        agreement.requestId != state.requestId ||
        agreement.listingId != state.expectedListingId ||
        agreement.ownerProfileId != state.expectedOwnerProfileId ||
        agreement.requesterProfileId != state.expectedRequesterProfileId) {
      throw const FormatException('Resource exchange context mismatched.');
    }
  }

  void _scheduleRefresh() {
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (profileId == null ||
        requestId == null ||
        !_matchesTarget(profileId, requestId)) {
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_matchesTarget(profileId, requestId)) return;
      if (state.isActing || _isRefreshing) {
        _scheduleRefresh();
        return;
      }
      unawaited(refresh());
    });
  }

  void _refreshDependentSurfaces({bool refreshRequest = false}) {
    ref.read(resourceChatRefreshProvider.notifier).notifyChanged();
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    final profileId = state.expectedProfileId;
    if (profileId == null) return;
    if (refreshRequest) {
      final requestId = state.requestId;
      if (requestId != null) {
        unawaited(
          ref
              .read(resourceRequestDetailProvider(requestId).notifier)
              .load(profileId),
        );
      }
      if (state.expectedRequesterProfileId == profileId) {
        unawaited(
          ref
              .read(resourceRequestHistoryProvider.notifier)
              .load(profileId, force: true),
        );
      }
    }
    final inbox = ref.read(messagesInboxProvider);
    if (inbox.expectedProfileId == profileId &&
        inbox.phase != MessagesInboxPhase.idle) {
      unawaited(
        ref.read(messagesInboxProvider.notifier).load(profileId, refresh: true),
      );
    }
  }

  bool _matchesTarget(String profileId, String requestId) =>
      ref.mounted &&
      state.expectedProfileId == profileId &&
      state.requestId == requestId &&
      _isReadyIdentity(profileId);

  bool _isCurrent(int revision, String profileId, String requestId) =>
      revision == _revision && _matchesTarget(profileId, requestId);

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  void _requireReadyIdentity(String profileId) {
    if (!_isReadyIdentity(profileId)) {
      throw const ResourceExchangeIdentityChangedException();
    }
  }
}

class _CanonicalResourceExchangeRead {
  const _CanonicalResourceExchangeRead({
    required this.snapshot,
    required this.eventsCurrent,
  });

  final ResourceExchangeSnapshot snapshot;
  final bool eventsCurrent;
}

class _TimelineReadFailure implements Exception {
  const _TimelineReadFailure(this.snapshot, this.cause);

  final ResourceExchangeSnapshot snapshot;
  final Object cause;
}

final resourceExchangeProvider =
    NotifierProvider<ResourceExchangeController, ResourceExchangeState>(
      ResourceExchangeController.new,
    );

ResourceExchangeFailureKind mapResourceExchangeFailure(Object error) {
  if (error is ResourceExchangeIdentityChangedException) {
    return ResourceExchangeFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError || error is StateError) {
    return ResourceExchangeFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ResourceExchangeFailureKind.invalidInput,
      '42501' => ResourceExchangeFailureKind.forbidden,
      'P0002' => ResourceExchangeFailureKind.notFound,
      'PT409' => ResourceExchangeFailureKind.conflict,
      _ => ResourceExchangeFailureKind.unavailable,
    };
  }
  return ResourceExchangeFailureKind.unavailable;
}

class ResourceExchangeIdentityChangedException implements Exception {
  const ResourceExchangeIdentityChangedException();
}
