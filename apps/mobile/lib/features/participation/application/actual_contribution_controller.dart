import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/actual_contribution_gateway.dart';
import '../domain/actual_contribution_models.dart';
import '../domain/participation_models.dart';

enum ActualContributionReadPhase { idle, loading, ready, failure }

enum ActualContributionOptionsPhase {
  notRequested,
  loading,
  ready,
  failure,
  notAvailable,
}

enum ActualContributionFailureKind {
  staleEdit,
  optionsChanged,
  forbidden,
  notAvailable,
  notFound,
  unavailable,
}

const _unchanged = Object();

class ActualContributionState {
  const ActualContributionState({
    required this.membershipId,
    this.expectedProfileId,
    this.readPhase = ActualContributionReadPhase.idle,
    this.optionsPhase = ActualContributionOptionsPhase.notRequested,
    this.contributions = const [],
    this.options = const [],
    this.expectedSkillIds = const {},
    this.expectedResourceNeedIds = const {},
    this.expectedSubstantialEffort = false,
    this.desiredSkillIds = const {},
    this.desiredResourceNeedIds = const {},
    this.desiredSubstantialEffort = false,
    this.readFailure,
    this.optionsFailure,
    this.actionFailure,
    this.limitReachedKind,
    this.isSaving = false,
  });

  final String membershipId;
  final String? expectedProfileId;
  final ActualContributionReadPhase readPhase;
  final ActualContributionOptionsPhase optionsPhase;
  final List<ActualContribution> contributions;
  final List<ActualContributionOption> options;
  final Set<String> expectedSkillIds;
  final Set<String> expectedResourceNeedIds;
  final bool expectedSubstantialEffort;
  final Set<String> desiredSkillIds;
  final Set<String> desiredResourceNeedIds;
  final bool desiredSubstantialEffort;
  final ActualContributionFailureKind? readFailure;
  final ActualContributionFailureKind? optionsFailure;
  final ActualContributionFailureKind? actionFailure;
  final ActualContributionKind? limitReachedKind;
  final bool isSaving;

  bool get isEditable =>
      readPhase == ActualContributionReadPhase.ready &&
      optionsPhase == ActualContributionOptionsPhase.ready;

  bool get isDirty =>
      !_sameSet(expectedSkillIds, desiredSkillIds) ||
      !_sameSet(expectedResourceNeedIds, desiredResourceNeedIds) ||
      expectedSubstantialEffort != desiredSubstantialEffort;

  Iterable<ActualContributionEditorItem> itemsFor(
    ActualContributionKind kind,
  ) sync* {
    if (kind == ActualContributionKind.substantialEffort) return;
    final currentByKey = {
      for (final contribution in contributions)
        if (contribution.kind == kind) contribution.key: contribution,
    };
    final emitted = <String>{};
    for (final contribution in currentByKey.values) {
      final id = contribution.id!;
      emitted.add(contribution.key);
      yield ActualContributionEditorItem(
        kind: kind,
        id: id,
        label: contribution.label!,
        isSelected: isSelected(kind, id),
        source: contribution.source,
      );
    }
    for (final option in options.where((item) => item.kind == kind)) {
      if (!emitted.add(option.key)) continue;
      yield ActualContributionEditorItem(
        kind: kind,
        id: option.id,
        label: option.label,
        isSelected: isSelected(kind, option.id),
        source: null,
      );
    }
  }

  bool isSelected(ActualContributionKind kind, String id) => switch (kind) {
    ActualContributionKind.skill => desiredSkillIds.contains(id),
    ActualContributionKind.resource => desiredResourceNeedIds.contains(id),
    ActualContributionKind.substantialEffort => desiredSubstantialEffort,
  };

  ActualContributionState copyWith({
    String? expectedProfileId,
    ActualContributionReadPhase? readPhase,
    ActualContributionOptionsPhase? optionsPhase,
    List<ActualContribution>? contributions,
    List<ActualContributionOption>? options,
    Set<String>? expectedSkillIds,
    Set<String>? expectedResourceNeedIds,
    bool? expectedSubstantialEffort,
    Set<String>? desiredSkillIds,
    Set<String>? desiredResourceNeedIds,
    bool? desiredSubstantialEffort,
    Object? readFailure = _unchanged,
    Object? optionsFailure = _unchanged,
    Object? actionFailure = _unchanged,
    Object? limitReachedKind = _unchanged,
    bool? isSaving,
  }) => ActualContributionState(
    membershipId: membershipId,
    expectedProfileId: expectedProfileId ?? this.expectedProfileId,
    readPhase: readPhase ?? this.readPhase,
    optionsPhase: optionsPhase ?? this.optionsPhase,
    contributions: contributions ?? this.contributions,
    options: options ?? this.options,
    expectedSkillIds: expectedSkillIds ?? this.expectedSkillIds,
    expectedResourceNeedIds:
        expectedResourceNeedIds ?? this.expectedResourceNeedIds,
    expectedSubstantialEffort:
        expectedSubstantialEffort ?? this.expectedSubstantialEffort,
    desiredSkillIds: desiredSkillIds ?? this.desiredSkillIds,
    desiredResourceNeedIds:
        desiredResourceNeedIds ?? this.desiredResourceNeedIds,
    desiredSubstantialEffort:
        desiredSubstantialEffort ?? this.desiredSubstantialEffort,
    readFailure: identical(readFailure, _unchanged)
        ? this.readFailure
        : readFailure as ActualContributionFailureKind?,
    optionsFailure: identical(optionsFailure, _unchanged)
        ? this.optionsFailure
        : optionsFailure as ActualContributionFailureKind?,
    actionFailure: identical(actionFailure, _unchanged)
        ? this.actionFailure
        : actionFailure as ActualContributionFailureKind?,
    limitReachedKind: identical(limitReachedKind, _unchanged)
        ? this.limitReachedKind
        : limitReachedKind as ActualContributionKind?,
    isSaving: isSaving ?? this.isSaving,
  );
}

class ActualContributionController extends Notifier<ActualContributionState> {
  ActualContributionController(this.membershipId);

  final String membershipId;
  var _revision = 0;

  @override
  ActualContributionState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _revision++;
        state = ActualContributionState(membershipId: membershipId);
      },
    );
    ref.onDispose(() => _revision++);
    return ActualContributionState(membershipId: membershipId);
  }

  Future<bool> load({
    required String expectedProfileId,
    required bool editable,
  }) async {
    final revision = ++_revision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = ActualContributionState(
      membershipId: membershipId,
      expectedProfileId: expectedProfileId,
      readPhase: ActualContributionReadPhase.loading,
      optionsPhase: editable
          ? ActualContributionOptionsPhase.loading
          : ActualContributionOptionsPhase.notRequested,
      contributions: preserve ? state.contributions : const [],
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final contributions = await ref
          .read(actualContributionGatewayProvider)
          .listActualContributions(
            expectedProfileId: expectedProfileId,
            membershipId: membershipId,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final skillIds = _contributionIds(
        contributions,
        ActualContributionKind.skill,
      );
      final resourceIds = _contributionIds(
        contributions,
        ActualContributionKind.resource,
      );
      final substantialEffort = contributions.any(
        (item) => item.kind == ActualContributionKind.substantialEffort,
      );
      state = ActualContributionState(
        membershipId: membershipId,
        expectedProfileId: expectedProfileId,
        readPhase: ActualContributionReadPhase.ready,
        optionsPhase: editable
            ? ActualContributionOptionsPhase.loading
            : ActualContributionOptionsPhase.notRequested,
        contributions: List.unmodifiable(contributions),
        expectedSkillIds: skillIds,
        expectedResourceNeedIds: resourceIds,
        expectedSubstantialEffort: substantialEffort,
        desiredSkillIds: skillIds,
        desiredResourceNeedIds: resourceIds,
        desiredSubstantialEffort: substantialEffort,
      );
      if (!editable) return true;
      return await _loadOptions(revision, expectedProfileId);
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapActualContributionFailure(error);
      state = ActualContributionState(
        membershipId: membershipId,
        expectedProfileId: expectedProfileId,
        readPhase: ActualContributionReadPhase.failure,
        readFailure: failure,
      );
      return false;
    }
  }

  Future<bool> retryOptions(String expectedProfileId) async {
    if (state.readPhase != ActualContributionReadPhase.ready ||
        state.expectedProfileId != expectedProfileId) {
      return false;
    }
    final revision = ++_revision;
    state = state.copyWith(
      optionsPhase: ActualContributionOptionsPhase.loading,
      options: const [],
      optionsFailure: null,
      actionFailure: null,
      limitReachedKind: null,
    );
    return _loadOptions(revision, expectedProfileId);
  }

  bool toggle(ActualContributionKind kind, String id) {
    if (!state.isEditable ||
        state.isSaving ||
        kind == ActualContributionKind.substantialEffort) {
      return false;
    }
    if (!state.itemsFor(kind).any((item) => item.id == id)) return false;
    final selected = switch (kind) {
      ActualContributionKind.skill => state.desiredSkillIds,
      ActualContributionKind.resource => state.desiredResourceNeedIds,
      ActualContributionKind.substantialEffort => const <String>{},
    };
    final next = {...selected};
    if (!next.remove(id)) {
      final limit = switch (kind) {
        ActualContributionKind.skill => participationSkillSelectionMax,
        ActualContributionKind.resource =>
          participationResourceNeedSelectionMax,
        ActualContributionKind.substantialEffort => 0,
      };
      if (next.length >= limit) {
        state = state.copyWith(limitReachedKind: kind, actionFailure: null);
        return false;
      }
      next.add(id);
    }
    state = switch (kind) {
      ActualContributionKind.skill => state.copyWith(
        desiredSkillIds: Set.unmodifiable(next),
        actionFailure: null,
        limitReachedKind: null,
      ),
      ActualContributionKind.resource => state.copyWith(
        desiredResourceNeedIds: Set.unmodifiable(next),
        actionFailure: null,
        limitReachedKind: null,
      ),
      ActualContributionKind.substantialEffort => state,
    };
    return true;
  }

  void toggleSubstantialEffort() {
    if (!state.isEditable || state.isSaving) return;
    state = state.copyWith(
      desiredSubstantialEffort: !state.desiredSubstantialEffort,
      actionFailure: null,
      limitReachedKind: null,
    );
  }

  void clearAll() {
    if (!state.isEditable || state.isSaving) return;
    state = state.copyWith(
      desiredSkillIds: const {},
      desiredResourceNeedIds: const {},
      desiredSubstantialEffort: false,
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
    final expectedEffort = state.expectedSubstantialEffort;
    final desiredSkillIds = state.desiredSkillIds;
    final desiredResourceIds = state.desiredResourceNeedIds;
    final desiredEffort = state.desiredSubstantialEffort;
    state = state.copyWith(
      isSaving: true,
      actionFailure: null,
      limitReachedKind: null,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await ref
          .read(actualContributionGatewayProvider)
          .replaceActualContributions(
            expectedManagerProfileId: expectedProfileId,
            membershipId: membershipId,
            expectedSkillIds: expectedSkillIds,
            expectedResourceNeedIds: expectedResourceIds,
            expectedSubstantialEffort: expectedEffort,
            skillIds: desiredSkillIds,
            resourceNeedIds: desiredResourceIds,
            substantialEffort: desiredEffort,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      return await load(expectedProfileId: expectedProfileId, editable: true);
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapActualContributionFailure(error);
      if (failure == ActualContributionFailureKind.forbidden) {
        state = ActualContributionState(
          membershipId: membershipId,
          expectedProfileId: expectedProfileId,
          readPhase: ActualContributionReadPhase.failure,
          readFailure: failure,
        );
        return false;
      }
      if (failure == ActualContributionFailureKind.staleEdit ||
          failure == ActualContributionFailureKind.optionsChanged) {
        await load(expectedProfileId: expectedProfileId, editable: true);
        if (_identityMatches(expectedProfileId) &&
            state.readPhase == ActualContributionReadPhase.ready &&
            state.optionsPhase != ActualContributionOptionsPhase.notAvailable) {
          state = state.copyWith(actionFailure: failure, isSaving: false);
        }
        return false;
      }
      if (failure == ActualContributionFailureKind.notAvailable) {
        state = ActualContributionState(
          membershipId: membershipId,
          expectedProfileId: expectedProfileId,
          readPhase: ActualContributionReadPhase.failure,
          readFailure: failure,
        );
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
          .read(actualContributionGatewayProvider)
          .listActualContributionOptions(
            expectedManagerProfileId: expectedProfileId,
            membershipId: membershipId,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = state.copyWith(
        optionsPhase: ActualContributionOptionsPhase.ready,
        options: List.unmodifiable(options),
        optionsFailure: null,
        isSaving: false,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapActualContributionFailure(error);
      if (failure == ActualContributionFailureKind.forbidden) {
        state = ActualContributionState(
          membershipId: membershipId,
          expectedProfileId: expectedProfileId,
          readPhase: ActualContributionReadPhase.failure,
          readFailure: failure,
        );
        return false;
      }
      if (failure == ActualContributionFailureKind.notAvailable) {
        state = state.copyWith(
          optionsPhase: ActualContributionOptionsPhase.notAvailable,
          options: const [],
          optionsFailure: failure,
          isSaving: false,
        );
        return true;
      }
      state = state.copyWith(
        optionsPhase: ActualContributionOptionsPhase.failure,
        options: const [],
        optionsFailure: failure,
        isSaving: false,
      );
      return false;
    }
  }

  Set<String> _contributionIds(
    Iterable<ActualContribution> contributions,
    ActualContributionKind kind,
  ) => Set.unmodifiable(
    contributions.where((item) => item.kind == kind).map((item) => item.id!),
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
      throw const ActualContributionIdentityChangedException();
    }
  }
}

final actualContributionProvider =
    NotifierProvider.family<
      ActualContributionController,
      ActualContributionState,
      String
    >(ActualContributionController.new);

ActualContributionFailureKind mapActualContributionFailure(Object error) {
  if (error is ActualContributionIdentityChangedException) {
    return ActualContributionFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ActualContributionFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      'PT409' => ActualContributionFailureKind.staleEdit,
      '22023' => ActualContributionFailureKind.optionsChanged,
      '42501' => ActualContributionFailureKind.forbidden,
      '55000' => ActualContributionFailureKind.notAvailable,
      'P0002' => ActualContributionFailureKind.notFound,
      _ => ActualContributionFailureKind.unavailable,
    };
  }
  return ActualContributionFailureKind.unavailable;
}

class ActualContributionIdentityChangedException implements Exception {
  const ActualContributionIdentityChangedException();
}

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
