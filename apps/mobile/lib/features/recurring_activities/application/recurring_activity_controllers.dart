import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../data/recurring_activity_gateway.dart';
import '../domain/recurring_activity_models.dart';

final recurringActivityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class PublicRecurringActivitiesController
    extends Notifier<PublicRecurringActivitiesState> {
  var _publicRevision = 0;
  var _requestedRevision = 0;

  @override
  PublicRecurringActivitiesState build() {
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
    return const PublicRecurringActivitiesState();
  }

  Future<void> load({bool reset = true}) async {
    if (state.isBusy) return;
    final revision = ++_publicRevision;
    final currentItems = reset
        ? const <PublicRecurringActivitySummary>[]
        : state.items;
    final referenceTime = reset || state.referenceTime == null
        ? ref.read(recurringActivityClockProvider)().toUtc()
        : state.referenceTime!;
    final locality = state.locality;
    final profileId = reset ? _readyProfileId() : null;
    final requestedRevision = reset ? ++_requestedRevision : null;
    state = PublicRecurringActivitiesState(
      phase: reset
          ? RecurringActivityLoadPhase.loading
          : RecurringActivityLoadPhase.loadingMore,
      items: currentItems,
      requestedItems: state.requestedItems,
      locality: locality,
      referenceTime: referenceTime,
      hasMore: state.hasMore,
    );
    try {
      final gateway = ref.read(recurringActivityGatewayProvider);
      final results = await Future.wait<dynamic>([
        gateway.listPublicActivities(
          referenceTime: referenceTime,
          limit: recurringActivityPageSize,
          cursor: reset || currentItems.isEmpty
              ? null
              : currentItems.last.cursor,
          locality: locality.isEmpty ? null : locality,
        ),
        if (profileId != null)
          gateway
              .listOwnPendingRequestedActivities(
                profileId,
                referenceTime: referenceTime,
                locality: locality.isEmpty ? null : locality,
              )
              .catchError((_) => const <RequestedRecurringActivitySummary>[])
        else
          Future.value(const <RequestedRecurringActivitySummary>[]),
      ]);
      if (revision != _publicRevision ||
          state.referenceTime != referenceTime ||
          state.locality != locality) {
        return;
      }
      final page = results[0] as List<PublicRecurringActivitySummary>;
      final requested = results[1] as List<RequestedRecurringActivitySummary>;
      final acceptRequested =
          reset &&
          requestedRevision == _requestedRevision &&
          _readyProfileId() == profileId;
      state = PublicRecurringActivitiesState(
        phase: RecurringActivityLoadPhase.ready,
        items: List.unmodifiable([...currentItems, ...page]),
        requestedItems: acceptRequested
            ? List.unmodifiable(requested)
            : state.requestedItems,
        locality: locality,
        referenceTime: referenceTime,
        hasMore: page.length == recurringActivityPageSize,
      );
    } catch (error) {
      if (revision == _publicRevision) {
        state = PublicRecurringActivitiesState(
          phase: RecurringActivityLoadPhase.failure,
          items: currentItems,
          requestedItems: state.requestedItems,
          locality: locality,
          referenceTime: referenceTime,
          hasMore: state.hasMore,
          failure: mapRecurringActivityFailure(error),
        );
      }
    }
  }

  Future<void> applyLocality(String locality) async {
    _publicRevision++;
    _requestedRevision++;
    state = PublicRecurringActivitiesState(locality: locality.trim());
    await load();
  }

  Future<void> refreshRequested() async {
    final profileId = _readyProfileId();
    final locality = state.locality;
    final referenceTime = state.referenceTime;
    final revision = ++_requestedRevision;
    if (profileId == null || referenceTime == null) {
      state = _stateWithRequested(const []);
      return;
    }
    try {
      final requested = await ref
          .read(recurringActivityGatewayProvider)
          .listOwnPendingRequestedActivities(
            profileId,
            referenceTime: referenceTime,
            locality: locality.isEmpty ? null : locality,
          );
      if (_isRequestedCurrent(revision, profileId, referenceTime, locality)) {
        state = _stateWithRequested(List.unmodifiable(requested));
      }
    } catch (_) {
      if (_isRequestedCurrent(revision, profileId, referenceTime, locality)) {
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

  bool _isRequestedCurrent(
    int revision,
    String profileId,
    DateTime referenceTime,
    String locality,
  ) =>
      ref.mounted &&
      revision == _requestedRevision &&
      _readyProfileId() == profileId &&
      state.referenceTime == referenceTime &&
      state.locality == locality;

  PublicRecurringActivitiesState _stateWithRequested(
    List<RequestedRecurringActivitySummary> requested,
  ) => PublicRecurringActivitiesState(
    phase: state.phase,
    items: state.items,
    requestedItems: requested,
    locality: state.locality,
    referenceTime: state.referenceTime,
    hasMore: state.hasMore,
    failure: state.failure,
  );
}

final publicRecurringActivitiesProvider =
    NotifierProvider<
      PublicRecurringActivitiesController,
      PublicRecurringActivitiesState
    >(PublicRecurringActivitiesController.new);

class PublicRecurringActivityDetailController
    extends Notifier<PublicRecurringActivityDetailState> {
  var _revision = 0;

  @override
  PublicRecurringActivityDetailState build() =>
      const PublicRecurringActivityDetailState();

  Future<void> load(String activityId) async {
    final revision = ++_revision;
    final current = state.activityId == activityId ? state.detail : null;
    state = PublicRecurringActivityDetailState(
      phase: RecurringActivityLoadPhase.loading,
      activityId: activityId,
      detail: current,
    );
    try {
      final detail = await ref
          .read(recurringActivityGatewayProvider)
          .getPublicActivity(
            activityId,
            referenceTime: ref.read(recurringActivityClockProvider)().toUtc(),
          );
      if (revision != _revision) return;
      state = PublicRecurringActivityDetailState(
        phase: RecurringActivityLoadPhase.ready,
        activityId: activityId,
        detail: detail,
      );
    } catch (error) {
      if (revision == _revision) {
        state = PublicRecurringActivityDetailState(
          phase: RecurringActivityLoadPhase.failure,
          activityId: activityId,
          detail: current,
          failure: mapRecurringActivityFailure(error),
        );
      }
    }
  }
}

final publicRecurringActivityDetailProvider =
    NotifierProvider<
      PublicRecurringActivityDetailController,
      PublicRecurringActivityDetailState
    >(PublicRecurringActivityDetailController.new);

class OwnRecurringActivitiesController
    extends Notifier<OwnRecurringActivitiesState> {
  var _revision = 0;

  @override
  OwnRecurringActivitiesState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const OwnRecurringActivitiesState();
    });
    ref.onDispose(() => _revision++);
    return const OwnRecurringActivitiesState();
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  Future<void> load(String expectedCreatorId) async {
    final revision = ++_revision;
    state = OwnRecurringActivitiesState(
      phase: RecurringActivityLoadPhase.loading,
      expectedCreatorId: expectedCreatorId,
      items: state.expectedCreatorId == expectedCreatorId
          ? state.items
          : const [],
    );
    try {
      _requireCurrentIdentity(expectedCreatorId, requireReady: false);
      final items = await ref
          .read(recurringActivityGatewayProvider)
          .listOwnActivities(expectedCreatorId);
      if (!_isCurrent(revision)) return;
      state = OwnRecurringActivitiesState(
        phase: RecurringActivityLoadPhase.ready,
        expectedCreatorId: expectedCreatorId,
        items: List.unmodifiable(items),
      );
    } catch (error) {
      if (_isCurrent(revision)) {
        state = OwnRecurringActivitiesState(
          phase: RecurringActivityLoadPhase.failure,
          expectedCreatorId: expectedCreatorId,
          items: state.items,
          failure: mapRecurringActivityFailure(error),
        );
      }
    }
  }

  Future<bool> publish(String creatorId, String activityId) =>
      _mutate(creatorId, (gateway) => gateway.publish(creatorId, activityId));

  Future<bool> pause(String creatorId, String activityId) =>
      _mutate(creatorId, (gateway) => gateway.pause(creatorId, activityId));

  Future<bool> resume(String creatorId, String activityId) =>
      _mutate(creatorId, (gateway) => gateway.resume(creatorId, activityId));

  Future<bool> end(String creatorId, String activityId) =>
      _mutate(creatorId, (gateway) => gateway.end(creatorId, activityId));

  Future<bool> _mutate(
    String expectedCreatorId,
    Future<void> Function(RecurringActivityGateway gateway) operation,
  ) async {
    if (state.isBusy) return false;
    final revision = ++_revision;
    state = OwnRecurringActivitiesState(
      phase: RecurringActivityLoadPhase.loading,
      expectedCreatorId: expectedCreatorId,
      items: state.items,
    );
    try {
      _requireCurrentIdentity(expectedCreatorId);
      final gateway = ref.read(recurringActivityGatewayProvider);
      await operation(gateway);
      if (!_isCurrent(revision)) return false;
      _requireCurrentIdentity(expectedCreatorId);
      ref.invalidate(publicRecurringActivitiesProvider);
      ref.invalidate(publicRecurringActivityDetailProvider);
      final items = await gateway.listOwnActivities(expectedCreatorId);
      if (!_isCurrent(revision)) return false;
      state = OwnRecurringActivitiesState(
        phase: RecurringActivityLoadPhase.ready,
        expectedCreatorId: expectedCreatorId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      state = OwnRecurringActivitiesState(
        phase: RecurringActivityLoadPhase.failure,
        expectedCreatorId: expectedCreatorId,
        items: state.items,
        failure: mapRecurringActivityFailure(error),
      );
      return false;
    }
  }

  void _requireCurrentIdentity(
    String expectedCreatorId, {
    bool requireReady = true,
  }) {
    final session = ref.read(authSessionProvider);
    if (session.identity?.id != expectedCreatorId ||
        (requireReady && session.phase != AuthSessionPhase.ready)) {
      throw const RecurringActivityIdentityChangedException();
    }
  }
}

final ownRecurringActivitiesProvider =
    NotifierProvider<
      OwnRecurringActivitiesController,
      OwnRecurringActivitiesState
    >(OwnRecurringActivitiesController.new);

class RecurringActivityEditorController
    extends Notifier<RecurringActivityEditorState> {
  var _revision = 0;

  @override
  RecurringActivityEditorState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const RecurringActivityEditorState();
    });
    ref.onDispose(() => _revision++);
    return const RecurringActivityEditorState();
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  Future<void> load(String expectedCreatorId, String? activityId) async {
    final revision = ++_revision;
    state = RecurringActivityEditorState(
      phase: RecurringActivityEditorPhase.loading,
      expectedCreatorId: expectedCreatorId,
      activity:
          state.expectedCreatorId == expectedCreatorId &&
              state.activity?.id == activityId
          ? state.activity
          : null,
    );
    try {
      _requireReadyIdentity(expectedCreatorId);
      final activity = activityId == null
          ? null
          : await ref
                .read(recurringActivityGatewayProvider)
                .getOwnActivity(expectedCreatorId, activityId);
      if (!_isCurrent(revision)) return;
      if (activityId != null && activity == null) {
        throw const RecurringActivityNotFoundException();
      }
      state = RecurringActivityEditorState(
        phase: RecurringActivityEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        activity: activity,
      );
    } catch (error) {
      if (_isCurrent(revision)) {
        final failure = mapRecurringActivityFailure(error);
        if (failure == RecurringActivityFailureKind.forbidden &&
            activityId != null) {
          _invalidateStructuralAuthority();
        }
        state = RecurringActivityEditorState(
          phase: RecurringActivityEditorPhase.failure,
          expectedCreatorId: expectedCreatorId,
          activity: state.activity,
          failure: failure,
        );
      }
    }
  }

  Future<String?> saveDraft(
    String expectedCreatorId,
    RecurringActivityInput input,
  ) {
    if (state.isBusy) return Future<String?>.value();
    final existing = state.activity;
    if (existing != null &&
        existing.lifecycle != RecurringActivityLifecycle.draft) {
      return _reject(
        expectedCreatorId,
        RecurringActivityFailureKind.invalidState,
      );
    }
    if (!isValidRecurringActivityDraft(input) ||
        !isValidRecurringScheduleTransition(
          state.activity,
          input,
          ref.read(recurringActivityClockProvider)(),
        )) {
      return _reject(expectedCreatorId);
    }
    return _save(expectedCreatorId, input, publishAfterSave: false);
  }

  Future<String?> publish(
    String expectedCreatorId,
    RecurringActivityInput input,
  ) {
    if (state.isBusy) return Future<String?>.value();
    final existing = state.activity;
    if (existing != null &&
        existing.lifecycle != RecurringActivityLifecycle.draft) {
      return _reject(
        expectedCreatorId,
        RecurringActivityFailureKind.invalidState,
      );
    }
    if (!isPublishableRecurringActivityInput(input) ||
        !isValidRecurringScheduleTransition(
          state.activity,
          input,
          ref.read(recurringActivityClockProvider)(),
        )) {
      return _reject(expectedCreatorId);
    }
    return _save(expectedCreatorId, input, publishAfterSave: true);
  }

  Future<String?> saveChanges(
    String expectedStructuralActorId,
    RecurringActivityInput input,
  ) {
    if (state.isBusy) return Future<String?>.value();
    final existing = state.activity;
    if (existing == null ||
        (existing.lifecycle != RecurringActivityLifecycle.published &&
            existing.lifecycle != RecurringActivityLifecycle.paused)) {
      return _reject(
        expectedStructuralActorId,
        RecurringActivityFailureKind.invalidState,
      );
    }
    if (!isPublishableRecurringActivityInput(input) ||
        input.peopleCapacity! < existing.capacity.currentPeopleCount ||
        !isValidRecurringScheduleTransition(
          existing,
          input,
          ref.read(recurringActivityClockProvider)(),
        )) {
      return _reject(
        expectedStructuralActorId,
        RecurringActivityFailureKind.invalidInput,
      );
    }
    return _save(expectedStructuralActorId, input, publishAfterSave: false);
  }

  Future<String?> _reject(
    String expectedCreatorId, [
    RecurringActivityFailureKind failure =
        RecurringActivityFailureKind.invalidInput,
  ]) async {
    state = RecurringActivityEditorState(
      phase: RecurringActivityEditorPhase.failure,
      expectedCreatorId: expectedCreatorId,
      activity: state.activity,
      failure: failure,
    );
    return null;
  }

  Future<String?> _save(
    String expectedCreatorId,
    RecurringActivityInput input, {
    required bool publishAfterSave,
  }) async {
    if (state.isBusy) return null;
    final revision = ++_revision;
    final existing = state.activity;
    state = RecurringActivityEditorState(
      phase: publishAfterSave
          ? RecurringActivityEditorPhase.publishing
          : RecurringActivityEditorPhase.saving,
      expectedCreatorId: expectedCreatorId,
      activity: existing,
    );
    try {
      _requireReadyIdentity(expectedCreatorId);
      final gateway = ref.read(recurringActivityGatewayProvider);
      final id = existing == null
          ? await gateway.createDraft(expectedCreatorId, input)
          : existing.isEditable
          ? existing.id
          : throw const RecurringActivityInvalidStateException();
      if (!_isCurrent(revision)) return null;
      _requireReadyIdentity(expectedCreatorId);
      if (existing != null) {
        await gateway.updateOwnActivity(expectedCreatorId, id, input);
        if (!_isCurrent(revision)) return null;
        _requireReadyIdentity(expectedCreatorId);
      }
      if (publishAfterSave) {
        if (existing?.lifecycle == RecurringActivityLifecycle.paused ||
            existing?.lifecycle == RecurringActivityLifecycle.published) {
          // Saving active/paused edits must not invoke the draft-only publish RPC.
        } else {
          await gateway.publish(expectedCreatorId, id);
          if (!_isCurrent(revision)) return null;
          _requireReadyIdentity(expectedCreatorId);
        }
      }
      final updated = await gateway.getOwnActivity(expectedCreatorId, id);
      if (!_isCurrent(revision)) return null;
      if (updated == null) throw const RecurringActivityNotFoundException();
      state = RecurringActivityEditorState(
        phase: RecurringActivityEditorPhase.ready,
        expectedCreatorId: expectedCreatorId,
        activity: updated,
      );
      _refreshRecurringSurfaces(
        expectedCreatorId,
        id,
        refreshPublic:
            publishAfterSave ||
            (existing != null &&
                existing.lifecycle != RecurringActivityLifecycle.draft),
      );
      return id;
    } catch (error) {
      if (!_isCurrent(revision)) return null;
      final failure = mapRecurringActivityFailure(error);
      var authoritativeActivity = existing;
      if (failure == RecurringActivityFailureKind.invalidState &&
          existing != null) {
        try {
          authoritativeActivity = await ref
              .read(recurringActivityGatewayProvider)
              .getOwnActivity(expectedCreatorId, existing.id);
        } catch (_) {
          // Preserve the original safe failure when the recovery read fails.
        }
      }
      if (!_isCurrent(revision)) return null;
      if (failure == RecurringActivityFailureKind.forbidden) {
        _invalidateStructuralAuthority();
      }
      state = RecurringActivityEditorState(
        phase: RecurringActivityEditorPhase.failure,
        expectedCreatorId: expectedCreatorId,
        activity: authoritativeActivity,
        failure: failure,
      );
      return null;
    }
  }

  Future<bool> pause(String expectedStructuralActorId) => _mutateLifecycle(
    expectedStructuralActorId,
    canRun: (activity) => activity.canPause,
    operation: (gateway, activityId) =>
        gateway.pause(expectedStructuralActorId, activityId),
  );

  Future<bool> resume(String expectedStructuralActorId) => _mutateLifecycle(
    expectedStructuralActorId,
    canRun: (activity) => activity.canResume,
    operation: (gateway, activityId) =>
        gateway.resume(expectedStructuralActorId, activityId),
  );

  Future<bool> end(String expectedStructuralActorId) => _mutateLifecycle(
    expectedStructuralActorId,
    canRun: (activity) => activity.canEnd,
    operation: (gateway, activityId) =>
        gateway.end(expectedStructuralActorId, activityId),
  );

  Future<bool> _mutateLifecycle(
    String expectedStructuralActorId, {
    required bool Function(OwnRecurringActivity activity) canRun,
    required Future<void> Function(
      RecurringActivityGateway gateway,
      String activityId,
    )
    operation,
  }) async {
    final existing = state.activity;
    if (state.isBusy || existing == null || !canRun(existing)) return false;
    final revision = ++_revision;
    state = RecurringActivityEditorState(
      phase: RecurringActivityEditorPhase.mutatingLifecycle,
      expectedCreatorId: expectedStructuralActorId,
      activity: existing,
    );
    try {
      _requireReadyIdentity(expectedStructuralActorId);
      final gateway = ref.read(recurringActivityGatewayProvider);
      await operation(gateway, existing.id);
      if (!_isCurrent(revision)) return false;
      _requireReadyIdentity(expectedStructuralActorId);
      final updated = await gateway.getOwnActivity(
        expectedStructuralActorId,
        existing.id,
      );
      if (!_isCurrent(revision)) return false;
      if (updated == null) throw const RecurringActivityNotFoundException();
      state = RecurringActivityEditorState(
        phase: RecurringActivityEditorPhase.ready,
        expectedCreatorId: expectedStructuralActorId,
        activity: updated,
      );
      _refreshRecurringSurfaces(
        expectedStructuralActorId,
        existing.id,
        refreshPublic: true,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      final failure = mapRecurringActivityFailure(error);
      var authoritativeActivity = existing;
      if (failure == RecurringActivityFailureKind.invalidState) {
        try {
          authoritativeActivity =
              await ref
                  .read(recurringActivityGatewayProvider)
                  .getOwnActivity(expectedStructuralActorId, existing.id) ??
              existing;
        } catch (_) {
          // Keep the prior record and the safe mapped failure.
        }
      }
      if (!_isCurrent(revision)) return false;
      if (failure == RecurringActivityFailureKind.forbidden) {
        _invalidateStructuralAuthority();
      }
      state = RecurringActivityEditorState(
        phase: RecurringActivityEditorPhase.failure,
        expectedCreatorId: expectedStructuralActorId,
        activity: authoritativeActivity,
        failure: failure,
      );
      return false;
    }
  }

  void _refreshRecurringSurfaces(
    String expectedProfileId,
    String activityId, {
    required bool refreshPublic,
  }) {
    ref.invalidate(delegatedProjectsProvider);
    unawaited(
      ref.read(ownRecurringActivitiesProvider.notifier).load(expectedProfileId),
    );
    if (refreshPublic) {
      unawaited(ref.read(publicRecurringActivitiesProvider.notifier).load());
      unawaited(
        ref
            .read(publicRecurringActivityDetailProvider.notifier)
            .load(activityId),
      );
    }
  }

  void _invalidateStructuralAuthority() {
    ref.invalidate(projectManagementRoleProvider);
    ref.invalidate(delegatedProjectsProvider);
  }

  void _requireReadyIdentity(String expectedCreatorId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedCreatorId) {
      throw const RecurringActivityIdentityChangedException();
    }
  }
}

final recurringActivityEditorProvider =
    NotifierProvider<
      RecurringActivityEditorController,
      RecurringActivityEditorState
    >(RecurringActivityEditorController.new);

RecurringActivityFailureKind mapRecurringActivityFailure(Object error) {
  if (error is RecurringActivityIdentityChangedException) {
    return RecurringActivityFailureKind.forbidden;
  }
  if (error is RecurringActivityInvalidStateException ||
      error is RecurringActivityNotFoundException) {
    return RecurringActivityFailureKind.invalidState;
  }
  if (error is FormatException || error is TypeError) {
    return RecurringActivityFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' ||
      '23514' ||
      '23502' => RecurringActivityFailureKind.invalidInput,
      '42501' => RecurringActivityFailureKind.forbidden,
      '55000' => RecurringActivityFailureKind.invalidState,
      _ => RecurringActivityFailureKind.unavailable,
    };
  }
  return RecurringActivityFailureKind.unavailable;
}

class RecurringActivityIdentityChangedException implements Exception {
  const RecurringActivityIdentityChangedException();
}

class RecurringActivityInvalidStateException implements Exception {
  const RecurringActivityInvalidStateException();
}

class RecurringActivityNotFoundException implements Exception {
  const RecurringActivityNotFoundException();
}
