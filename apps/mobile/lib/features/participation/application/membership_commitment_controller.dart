import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/membership_commitment_gateway.dart';
import '../domain/membership_commitment_models.dart';
import '../domain/participation_models.dart';

enum MembershipCommitmentReadPhase { idle, loading, ready, failure }

enum MembershipCommitmentOptionsPhase {
  notRequested,
  loading,
  ready,
  failure,
  noLongerEditable,
}

enum MembershipCommitmentFailureKind {
  staleEdit,
  optionsChanged,
  forbidden,
  noLongerEditable,
  notFound,
  unavailable,
}

const _unchanged = Object();

class MembershipCommitmentState {
  const MembershipCommitmentState({
    required this.membershipId,
    this.expectedProfileId,
    this.readPhase = MembershipCommitmentReadPhase.idle,
    this.optionsPhase = MembershipCommitmentOptionsPhase.notRequested,
    this.commitments = const [],
    this.options = const [],
    this.expectedSkillIds = const {},
    this.expectedResourceNeedIds = const {},
    this.desiredSkillIds = const {},
    this.desiredResourceNeedIds = const {},
    this.readFailure,
    this.optionsFailure,
    this.actionFailure,
    this.limitReachedKind,
    this.isSaving = false,
  });

  final String membershipId;
  final String? expectedProfileId;
  final MembershipCommitmentReadPhase readPhase;
  final MembershipCommitmentOptionsPhase optionsPhase;
  final List<MembershipCommitment> commitments;
  final List<MembershipCommitmentOption> options;
  final Set<String> expectedSkillIds;
  final Set<String> expectedResourceNeedIds;
  final Set<String> desiredSkillIds;
  final Set<String> desiredResourceNeedIds;
  final MembershipCommitmentFailureKind? readFailure;
  final MembershipCommitmentFailureKind? optionsFailure;
  final MembershipCommitmentFailureKind? actionFailure;
  final MembershipCommitmentKind? limitReachedKind;
  final bool isSaving;

  bool get isEditable =>
      readPhase == MembershipCommitmentReadPhase.ready &&
      optionsPhase == MembershipCommitmentOptionsPhase.ready;

  bool get isDirty =>
      !_sameSet(expectedSkillIds, desiredSkillIds) ||
      !_sameSet(expectedResourceNeedIds, desiredResourceNeedIds);

  Iterable<MembershipCommitmentEditorItem> itemsFor(
    MembershipCommitmentKind kind,
  ) sync* {
    final optionKeys = {for (final option in options) option.key};
    final emitted = <String>{};
    for (final commitment in commitments.where((item) => item.kind == kind)) {
      emitted.add(commitment.key);
      yield MembershipCommitmentEditorItem(
        id: commitment.id,
        kind: commitment.kind,
        label: commitment.label,
        isSelected: isSelected(commitment.kind, commitment.id),
        isRetained: !optionKeys.contains(commitment.key),
      );
    }
    for (final option in options.where((item) => item.kind == kind)) {
      if (!emitted.add(option.key)) continue;
      yield MembershipCommitmentEditorItem(
        id: option.id,
        kind: option.kind,
        label: option.label,
        isSelected: isSelected(option.kind, option.id),
        isRetained: false,
      );
    }
  }

  bool isSelected(MembershipCommitmentKind kind, String id) => switch (kind) {
    MembershipCommitmentKind.skill => desiredSkillIds.contains(id),
    MembershipCommitmentKind.resource => desiredResourceNeedIds.contains(id),
  };

  MembershipCommitmentState copyWith({
    String? expectedProfileId,
    MembershipCommitmentReadPhase? readPhase,
    MembershipCommitmentOptionsPhase? optionsPhase,
    List<MembershipCommitment>? commitments,
    List<MembershipCommitmentOption>? options,
    Set<String>? expectedSkillIds,
    Set<String>? expectedResourceNeedIds,
    Set<String>? desiredSkillIds,
    Set<String>? desiredResourceNeedIds,
    Object? readFailure = _unchanged,
    Object? optionsFailure = _unchanged,
    Object? actionFailure = _unchanged,
    Object? limitReachedKind = _unchanged,
    bool? isSaving,
  }) => MembershipCommitmentState(
    membershipId: membershipId,
    expectedProfileId: expectedProfileId ?? this.expectedProfileId,
    readPhase: readPhase ?? this.readPhase,
    optionsPhase: optionsPhase ?? this.optionsPhase,
    commitments: commitments ?? this.commitments,
    options: options ?? this.options,
    expectedSkillIds: expectedSkillIds ?? this.expectedSkillIds,
    expectedResourceNeedIds:
        expectedResourceNeedIds ?? this.expectedResourceNeedIds,
    desiredSkillIds: desiredSkillIds ?? this.desiredSkillIds,
    desiredResourceNeedIds:
        desiredResourceNeedIds ?? this.desiredResourceNeedIds,
    readFailure: identical(readFailure, _unchanged)
        ? this.readFailure
        : readFailure as MembershipCommitmentFailureKind?,
    optionsFailure: identical(optionsFailure, _unchanged)
        ? this.optionsFailure
        : optionsFailure as MembershipCommitmentFailureKind?,
    actionFailure: identical(actionFailure, _unchanged)
        ? this.actionFailure
        : actionFailure as MembershipCommitmentFailureKind?,
    limitReachedKind: identical(limitReachedKind, _unchanged)
        ? this.limitReachedKind
        : limitReachedKind as MembershipCommitmentKind?,
    isSaving: isSaving ?? this.isSaving,
  );
}

class MembershipCommitmentController
    extends Notifier<MembershipCommitmentState> {
  MembershipCommitmentController(this.membershipId);

  final String membershipId;
  var _revision = 0;

  @override
  MembershipCommitmentState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = MembershipCommitmentState(membershipId: membershipId);
    });
    ref.onDispose(() => _revision++);
    return MembershipCommitmentState(membershipId: membershipId);
  }

  Future<bool> load({
    required String expectedProfileId,
    required bool editable,
  }) async {
    final revision = ++_revision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = MembershipCommitmentState(
      membershipId: membershipId,
      expectedProfileId: expectedProfileId,
      readPhase: MembershipCommitmentReadPhase.loading,
      optionsPhase: editable
          ? MembershipCommitmentOptionsPhase.loading
          : MembershipCommitmentOptionsPhase.notRequested,
      commitments: preserve ? state.commitments : const [],
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final commitments = await ref
          .read(membershipCommitmentGatewayProvider)
          .listCommitments(
            expectedProfileId: expectedProfileId,
            membershipId: membershipId,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final skillIds = _commitmentIds(
        commitments,
        MembershipCommitmentKind.skill,
      );
      final resourceIds = _commitmentIds(
        commitments,
        MembershipCommitmentKind.resource,
      );
      state = MembershipCommitmentState(
        membershipId: membershipId,
        expectedProfileId: expectedProfileId,
        readPhase: MembershipCommitmentReadPhase.ready,
        optionsPhase: editable
            ? MembershipCommitmentOptionsPhase.loading
            : MembershipCommitmentOptionsPhase.notRequested,
        commitments: List.unmodifiable(commitments),
        expectedSkillIds: skillIds,
        expectedResourceNeedIds: resourceIds,
        desiredSkillIds: skillIds,
        desiredResourceNeedIds: resourceIds,
      );
      if (!editable) return true;
      return await _loadOptions(revision, expectedProfileId);
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapMembershipCommitmentFailure(error);
      state = MembershipCommitmentState(
        membershipId: membershipId,
        expectedProfileId: expectedProfileId,
        readPhase: MembershipCommitmentReadPhase.failure,
        optionsPhase: MembershipCommitmentOptionsPhase.notRequested,
        readFailure: failure,
      );
      return false;
    }
  }

  Future<bool> retryOptions(String expectedProfileId) async {
    if (state.readPhase != MembershipCommitmentReadPhase.ready ||
        state.expectedProfileId != expectedProfileId) {
      return false;
    }
    final revision = ++_revision;
    state = state.copyWith(
      optionsPhase: MembershipCommitmentOptionsPhase.loading,
      options: const [],
      optionsFailure: null,
      actionFailure: null,
      limitReachedKind: null,
    );
    return _loadOptions(revision, expectedProfileId);
  }

  bool toggle(MembershipCommitmentKind kind, String id) {
    if (!state.isEditable || state.isSaving) return false;
    final available = state.itemsFor(kind).any((item) => item.id == id);
    if (!available) return false;
    final selected = switch (kind) {
      MembershipCommitmentKind.skill => state.desiredSkillIds,
      MembershipCommitmentKind.resource => state.desiredResourceNeedIds,
    };
    final next = {...selected};
    if (!next.remove(id)) {
      final limit = switch (kind) {
        MembershipCommitmentKind.skill => participationSkillSelectionMax,
        MembershipCommitmentKind.resource =>
          participationResourceNeedSelectionMax,
      };
      if (next.length >= limit) {
        state = state.copyWith(limitReachedKind: kind, actionFailure: null);
        return false;
      }
      next.add(id);
    }
    state = switch (kind) {
      MembershipCommitmentKind.skill => state.copyWith(
        desiredSkillIds: Set.unmodifiable(next),
        actionFailure: null,
        limitReachedKind: null,
      ),
      MembershipCommitmentKind.resource => state.copyWith(
        desiredResourceNeedIds: Set.unmodifiable(next),
        actionFailure: null,
        limitReachedKind: null,
      ),
    };
    return true;
  }

  void clearAll() {
    if (!state.isEditable || state.isSaving) return;
    state = state.copyWith(
      desiredSkillIds: const {},
      desiredResourceNeedIds: const {},
      actionFailure: null,
      limitReachedKind: null,
    );
  }

  Future<bool> save(String expectedProfileId) async {
    if (!state.isEditable ||
        state.isSaving ||
        !state.isDirty ||
        state.expectedProfileId != expectedProfileId) {
      return false;
    }
    final revision = ++_revision;
    final expectedSkillIds = state.expectedSkillIds;
    final expectedResourceIds = state.expectedResourceNeedIds;
    final desiredSkillIds = state.desiredSkillIds;
    final desiredResourceIds = state.desiredResourceNeedIds;
    state = state.copyWith(
      isSaving: true,
      actionFailure: null,
      limitReachedKind: null,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await ref
          .read(membershipCommitmentGatewayProvider)
          .replaceCommitments(
            expectedActorProfileId: expectedProfileId,
            membershipId: membershipId,
            expectedSkillIds: expectedSkillIds,
            expectedResourceNeedIds: expectedResourceIds,
            skillIds: desiredSkillIds,
            resourceNeedIds: desiredResourceIds,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      return await load(expectedProfileId: expectedProfileId, editable: true);
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapMembershipCommitmentFailure(error);
      if (failure == MembershipCommitmentFailureKind.forbidden) {
        state = MembershipCommitmentState(
          membershipId: membershipId,
          expectedProfileId: expectedProfileId,
          readPhase: MembershipCommitmentReadPhase.failure,
          readFailure: failure,
        );
        return false;
      }
      if (failure == MembershipCommitmentFailureKind.staleEdit ||
          failure == MembershipCommitmentFailureKind.optionsChanged) {
        await load(expectedProfileId: expectedProfileId, editable: true);
        if (_identityMatches(expectedProfileId) &&
            state.readPhase == MembershipCommitmentReadPhase.ready &&
            state.optionsPhase !=
                MembershipCommitmentOptionsPhase.noLongerEditable) {
          state = state.copyWith(actionFailure: failure, isSaving: false);
        }
        return false;
      }
      if (failure == MembershipCommitmentFailureKind.noLongerEditable) {
        await load(expectedProfileId: expectedProfileId, editable: false);
        if (_identityMatches(expectedProfileId) &&
            state.readPhase == MembershipCommitmentReadPhase.ready) {
          state = state.copyWith(
            optionsPhase: MembershipCommitmentOptionsPhase.noLongerEditable,
            actionFailure: failure,
            isSaving: false,
          );
        }
        return false;
      }
      state = state.copyWith(actionFailure: failure, isSaving: false);
      return false;
    }
  }

  Future<bool> _loadOptions(int revision, String expectedProfileId) async {
    try {
      _requireReadyIdentity(expectedProfileId);
      final options = await ref
          .read(membershipCommitmentGatewayProvider)
          .listOptions(
            expectedProfileId: expectedProfileId,
            membershipId: membershipId,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = state.copyWith(
        optionsPhase: MembershipCommitmentOptionsPhase.ready,
        options: List.unmodifiable(options),
        optionsFailure: null,
        isSaving: false,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapMembershipCommitmentFailure(error);
      if (failure == MembershipCommitmentFailureKind.forbidden) {
        state = MembershipCommitmentState(
          membershipId: membershipId,
          expectedProfileId: expectedProfileId,
          readPhase: MembershipCommitmentReadPhase.failure,
          readFailure: failure,
        );
        return false;
      }
      if (failure == MembershipCommitmentFailureKind.noLongerEditable) {
        state = state.copyWith(
          optionsPhase: MembershipCommitmentOptionsPhase.noLongerEditable,
          options: const [],
          optionsFailure: failure,
          isSaving: false,
        );
        return true;
      }
      state = state.copyWith(
        optionsPhase: MembershipCommitmentOptionsPhase.failure,
        options: const [],
        optionsFailure: failure,
        isSaving: false,
      );
      return false;
    }
  }

  Set<String> _commitmentIds(
    Iterable<MembershipCommitment> commitments,
    MembershipCommitmentKind kind,
  ) => Set.unmodifiable(
    commitments.where((item) => item.kind == kind).map((item) => item.id),
  );

  bool _isCurrent(int revision, String expectedProfileId) =>
      ref.mounted &&
      revision == _revision &&
      _identityMatches(expectedProfileId);

  bool _identityMatches(String expectedProfileId) =>
      ref.read(authSessionProvider).identity?.id == expectedProfileId;

  void _requireReadyIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      throw const MembershipCommitmentIdentityChangedException();
    }
  }
}

final membershipCommitmentProvider =
    NotifierProvider.family<
      MembershipCommitmentController,
      MembershipCommitmentState,
      String
    >(MembershipCommitmentController.new);

MembershipCommitmentFailureKind mapMembershipCommitmentFailure(Object error) {
  if (error is MembershipCommitmentIdentityChangedException) {
    return MembershipCommitmentFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return MembershipCommitmentFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '40001' => MembershipCommitmentFailureKind.staleEdit,
      '22023' => MembershipCommitmentFailureKind.optionsChanged,
      '42501' => MembershipCommitmentFailureKind.forbidden,
      '55000' => MembershipCommitmentFailureKind.noLongerEditable,
      'P0002' => MembershipCommitmentFailureKind.notFound,
      _ => MembershipCommitmentFailureKind.unavailable,
    };
  }
  return MembershipCommitmentFailureKind.unavailable;
}

class MembershipCommitmentIdentityChangedException implements Exception {
  const MembershipCommitmentIdentityChangedException();
}

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
