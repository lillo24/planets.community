import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../resource_exchange/application/resource_exchange_controller.dart';
import '../../resource_exchange/domain/resource_exchange_models.dart';
import '../data/resource_loan_gateway.dart';
import '../domain/resource_loan_models.dart';

enum ResourceLoanPhase { idle, loading, ready, failure }

enum ResourceLoanFailure { forbidden, stale, unavailable }

ResourceLoanFailure mapResourceLoanFailure(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      '42501' => ResourceLoanFailure.forbidden,
      'PT409' => ResourceLoanFailure.stale,
      _ => ResourceLoanFailure.unavailable,
    };
  }
  return ResourceLoanFailure.unavailable;
}

class ResourceLoanScheduleState {
  const ResourceLoanScheduleState({
    this.phase = ResourceLoanPhase.idle,
    this.expectedOwnerProfileId,
    this.listingId,
    this.items = const [],
    this.failure,
  });

  final ResourceLoanPhase phase;
  final String? expectedOwnerProfileId;
  final String? listingId;
  final List<ResourceLoanReservation> items;
  final ResourceLoanFailure? failure;
}

class ResourceLoanScheduleController
    extends Notifier<ResourceLoanScheduleState> {
  var _revision = 0;

  @override
  ResourceLoanScheduleState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ResourceLoanScheduleState();
    });
    ref.onDispose(() => _revision++);
    return const ResourceLoanScheduleState();
  }

  Future<void> load({
    required String expectedOwnerProfileId,
    required String listingId,
  }) async {
    final revision = ++_revision;
    final previous =
        state.expectedOwnerProfileId == expectedOwnerProfileId &&
            state.listingId == listingId
        ? state.items
        : const <ResourceLoanReservation>[];
    state = ResourceLoanScheduleState(
      phase: ResourceLoanPhase.loading,
      expectedOwnerProfileId: expectedOwnerProfileId,
      listingId: listingId,
      items: previous,
    );
    try {
      if (!_isReadyIdentity(expectedOwnerProfileId)) {
        throw const ResourceLoanIdentityChangedException();
      }
      final items = await ref
          .read(resourceLoanGatewayProvider)
          .listOwnedSchedule(
            expectedOwnerProfileId: expectedOwnerProfileId,
            listingId: listingId,
          );
      if (_isCurrent(revision, expectedOwnerProfileId, listingId)) {
        state = ResourceLoanScheduleState(
          phase: ResourceLoanPhase.ready,
          expectedOwnerProfileId: expectedOwnerProfileId,
          listingId: listingId,
          items: List.unmodifiable(items),
        );
      }
    } catch (error) {
      if (_isCurrent(revision, expectedOwnerProfileId, listingId)) {
        state = ResourceLoanScheduleState(
          phase: ResourceLoanPhase.failure,
          expectedOwnerProfileId: expectedOwnerProfileId,
          listingId: listingId,
          items: previous,
          failure: error is ResourceLoanIdentityChangedException
              ? ResourceLoanFailure.forbidden
              : mapResourceLoanFailure(error),
        );
      }
    }
  }

  Future<void> refresh() async {
    final ownerId = state.expectedOwnerProfileId;
    final listingId = state.listingId;
    if (ownerId != null && listingId != null) {
      await load(expectedOwnerProfileId: ownerId, listingId: listingId);
    }
  }

  void handleAppResumed(String expectedOwnerProfileId, String listingId) {
    if (state.expectedOwnerProfileId == expectedOwnerProfileId &&
        state.listingId == listingId &&
        _isReadyIdentity(expectedOwnerProfileId)) {
      unawaited(refresh());
    }
  }

  bool _isCurrent(int revision, String ownerId, String listingId) =>
      ref.mounted &&
      revision == _revision &&
      state.expectedOwnerProfileId == ownerId &&
      state.listingId == listingId &&
      _isReadyIdentity(ownerId);

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }
}

final resourceLoanScheduleProvider =
    NotifierProvider<ResourceLoanScheduleController, ResourceLoanScheduleState>(
      ResourceLoanScheduleController.new,
    );

class PendingLoanAvailabilityState {
  const PendingLoanAvailabilityState({
    this.phase = ResourceLoanPhase.idle,
    this.expectedProfileId,
    this.agreementId,
    this.pendingTermsId,
    this.availability,
    this.failure,
    this.acceptanceConflictTermsId,
  });

  final ResourceLoanPhase phase;
  final String? expectedProfileId;
  final String? agreementId;
  final String? pendingTermsId;
  final PendingLoanAvailability? availability;
  final ResourceLoanFailure? failure;
  final String? acceptanceConflictTermsId;

  bool matches(String profileId, String agreement, String termsId) =>
      expectedProfileId == profileId &&
      agreementId == agreement &&
      pendingTermsId == termsId;

  bool get isKnownConflict =>
      phase == ResourceLoanPhase.ready &&
      availability?.isLend == true &&
      availability?.isAvailable == false;

  bool get isAcceptanceConflict =>
      isKnownConflict && acceptanceConflictTermsId == pendingTermsId;
}

class PendingLoanAvailabilityController
    extends Notifier<PendingLoanAvailabilityState> {
  var _revision = 0;
  String? _staleKey;

  @override
  PendingLoanAvailabilityState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _staleKey = null;
      state = const PendingLoanAvailabilityState();
    });
    ref.listen(resourceExchangeProvider, (previous, next) {
      _sync(previous, next);
    });
    ref.onDispose(() => _revision++);
    Future<void>.microtask(() {
      if (ref.mounted) _sync(null, ref.read(resourceExchangeProvider));
    });
    return const PendingLoanAvailabilityState();
  }

  void _sync(ResourceExchangeState? previous, ResourceExchangeState next) {
    final pending = next.snapshot?.pendingTerms;
    final profileId = next.expectedProfileId;
    final agreementId = next.snapshot?.agreement.agreementId;
    final eligible =
        next.phase == ResourceExchangePhase.ready &&
        profileId != null &&
        agreementId != null &&
        pending != null &&
        pending.ownerTransferKind == ResourceOwnerTransferKind.lend &&
        next.snapshot!.agreement.pendingTermsId == pending.termsId &&
        _isReadyIdentity(profileId);
    if (!eligible) {
      if (state.phase != ResourceLoanPhase.idle) {
        _revision++;
        state = const PendingLoanAvailabilityState();
      }
      return;
    }
    final termsId = pending.termsId;
    final key = '$profileId/$agreementId/$termsId';
    final sameTarget = state.matches(profileId, agreementId, termsId);
    final acceptedConflict =
        previous?.action == ResourceExchangeAction.accepting &&
        next.action == null &&
        next.failure == ResourceExchangeFailureKind.conflict &&
        previous?.snapshot?.pendingTerms?.termsId == termsId;
    if (sameTarget && !acceptedConflict) return;
    if (_staleKey == key) return;
    if (_staleKey != key) _staleKey = null;
    unawaited(
      _check(
        profileId: profileId,
        agreementId: agreementId,
        termsId: termsId,
        acceptanceConflictTermsId: acceptedConflict ? termsId : null,
      ),
    );
  }

  Future<void> _check({
    required String profileId,
    required String agreementId,
    required String termsId,
    required String? acceptanceConflictTermsId,
  }) async {
    final revision = ++_revision;
    state = PendingLoanAvailabilityState(
      phase: ResourceLoanPhase.loading,
      expectedProfileId: profileId,
      agreementId: agreementId,
      pendingTermsId: termsId,
      acceptanceConflictTermsId: acceptanceConflictTermsId,
    );
    try {
      final availability = await ref
          .read(resourceLoanGatewayProvider)
          .checkPendingAvailability(
            expectedProfileId: profileId,
            agreementId: agreementId,
            expectedPendingTermsId: termsId,
          );
      if (_isCurrent(revision, profileId, agreementId, termsId)) {
        state = PendingLoanAvailabilityState(
          phase: ResourceLoanPhase.ready,
          expectedProfileId: profileId,
          agreementId: agreementId,
          pendingTermsId: termsId,
          availability: availability,
          acceptanceConflictTermsId: acceptanceConflictTermsId,
        );
      }
    } catch (error) {
      if (!_isCurrent(revision, profileId, agreementId, termsId)) return;
      final failure = mapResourceLoanFailure(error);
      if (failure == ResourceLoanFailure.stale) {
        _staleKey = '$profileId/$agreementId/$termsId';
        _revision++;
        state = const PendingLoanAvailabilityState();
        // A stale exact-version read cannot be retried. Canonical refresh
        // decides whether a new pending version needs a fresh check.
        unawaited(ref.read(resourceExchangeProvider.notifier).refresh());
      } else {
        state = PendingLoanAvailabilityState(
          phase: ResourceLoanPhase.failure,
          expectedProfileId: profileId,
          agreementId: agreementId,
          pendingTermsId: termsId,
          failure: failure,
        );
      }
    }
  }

  bool _isCurrent(
    int revision,
    String profileId,
    String agreementId,
    String termsId,
  ) =>
      ref.mounted &&
      revision == _revision &&
      state.matches(profileId, agreementId, termsId) &&
      _isReadyIdentity(profileId);

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }
}

final pendingLoanAvailabilityProvider =
    NotifierProvider<
      PendingLoanAvailabilityController,
      PendingLoanAvailabilityState
    >(PendingLoanAvailabilityController.new);

class ResourceLoanIdentityChangedException implements Exception {
  const ResourceLoanIdentityChangedException();
}
