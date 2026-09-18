import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../data/join_acceptance_triage_gateway.dart';
import '../domain/join_acceptance_triage_models.dart';

enum JoinAcceptanceTriageLoadPhase { idle, loading, ready, failure }

enum JoinAcceptanceTriageFailureKind {
  projectNeedsChanged,
  conflict,
  forbidden,
  unavailable,
}

enum JoinAcceptanceTriageSubmitResult {
  accepted,
  incompleteWithGuidance,
  incomplete,
  failed,
}

const _unchanged = Object();

class JoinAcceptanceTriageState {
  const JoinAcceptanceTriageState({
    required this.requestId,
    this.expectedCreatorProfileId,
    this.loadPhase = JoinAcceptanceTriageLoadPhase.idle,
    this.items = const [],
    this.validationAttempt = 0,
    this.hasShownFirstGuidance = false,
    this.isAccepting = false,
    this.failure,
  });

  final String requestId;
  final String? expectedCreatorProfileId;
  final JoinAcceptanceTriageLoadPhase loadPhase;
  final List<JoinAcceptanceTriageItem> items;
  final int validationAttempt;
  final bool hasShownFirstGuidance;
  final bool isAccepting;
  final JoinAcceptanceTriageFailureKind? failure;

  bool get isTerminal =>
      failure == JoinAcceptanceTriageFailureKind.conflict ||
      failure == JoinAcceptanceTriageFailureKind.forbidden;

  Set<JoinAcceptanceItemKey> get undecidedKeys => {
    for (final item in items)
      if (item.decision == null) item.key,
  };

  bool isInvalid(JoinAcceptanceItemKey key) =>
      validationAttempt > 0 && undecidedKeys.contains(key);

  JoinAcceptanceTriageState copyWith({
    String? expectedCreatorProfileId,
    JoinAcceptanceTriageLoadPhase? loadPhase,
    List<JoinAcceptanceTriageItem>? items,
    int? validationAttempt,
    bool? hasShownFirstGuidance,
    bool? isAccepting,
    Object? failure = _unchanged,
  }) => JoinAcceptanceTriageState(
    requestId: requestId,
    expectedCreatorProfileId:
        expectedCreatorProfileId ?? this.expectedCreatorProfileId,
    loadPhase: loadPhase ?? this.loadPhase,
    items: items ?? this.items,
    validationAttempt: validationAttempt ?? this.validationAttempt,
    hasShownFirstGuidance: hasShownFirstGuidance ?? this.hasShownFirstGuidance,
    isAccepting: isAccepting ?? this.isAccepting,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as JoinAcceptanceTriageFailureKind?,
  );
}

class JoinAcceptanceTriageController
    extends Notifier<JoinAcceptanceTriageState> {
  JoinAcceptanceTriageController(this.requestId);

  final String requestId;
  var _revision = 0;

  @override
  JoinAcceptanceTriageState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      final previousIdentity = state.expectedCreatorProfileId;
      state = previousIdentity == null
          ? JoinAcceptanceTriageState(requestId: requestId)
          : JoinAcceptanceTriageState(
              requestId: requestId,
              expectedCreatorProfileId: previousIdentity,
              loadPhase: JoinAcceptanceTriageLoadPhase.failure,
              failure: JoinAcceptanceTriageFailureKind.forbidden,
            );
    });
    ref.onDispose(() => _revision++);
    return JoinAcceptanceTriageState(requestId: requestId);
  }

  Future<bool> load(String expectedCreatorProfileId) async {
    final revision = ++_revision;
    state = JoinAcceptanceTriageState(
      requestId: requestId,
      expectedCreatorProfileId: expectedCreatorProfileId,
      loadPhase: JoinAcceptanceTriageLoadPhase.loading,
    );
    try {
      _requireReadyIdentity(expectedCreatorProfileId);
      final items = await ref
          .read(joinAcceptanceTriageGatewayProvider)
          .listSelections(
            expectedCreatorProfileId: expectedCreatorProfileId,
            requestId: requestId,
          );
      _ensureUniqueKeys(items);
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      state = JoinAcceptanceTriageState(
        requestId: requestId,
        expectedCreatorProfileId: expectedCreatorProfileId,
        loadPhase: JoinAcceptanceTriageLoadPhase.ready,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      final failure = mapJoinAcceptanceTriageFailure(error);
      state = JoinAcceptanceTriageState(
        requestId: requestId,
        expectedCreatorProfileId: expectedCreatorProfileId,
        loadPhase: JoinAcceptanceTriageLoadPhase.failure,
        failure: failure,
      );
      return false;
    }
  }

  void decide(JoinAcceptanceItemKey key, JoinAcceptanceDecision decision) {
    if (state.loadPhase != JoinAcceptanceTriageLoadPhase.ready ||
        state.isAccepting ||
        state.isTerminal) {
      return;
    }
    var matched = false;
    final nextItems = [
      for (final item in state.items)
        if (item.key == key) ...[item.withDecision(decision)] else ...[item],
    ];
    for (final item in state.items) {
      if (item.key == key) matched = true;
    }
    if (!matched) return;
    state = state.copyWith(items: List.unmodifiable(nextItems));
  }

  Future<JoinAcceptanceTriageSubmitResult> accept() async {
    final expectedCreatorProfileId = state.expectedCreatorProfileId;
    if (expectedCreatorProfileId == null ||
        state.loadPhase != JoinAcceptanceTriageLoadPhase.ready ||
        state.isAccepting ||
        state.isTerminal) {
      return JoinAcceptanceTriageSubmitResult.failed;
    }
    if (state.undecidedKeys.isNotEmpty) {
      final showGuidance = !state.hasShownFirstGuidance;
      state = state.copyWith(
        validationAttempt: state.validationAttempt + 1,
        hasShownFirstGuidance: true,
        failure: null,
      );
      return showGuidance
          ? JoinAcceptanceTriageSubmitResult.incompleteWithGuidance
          : JoinAcceptanceTriageSubmitResult.incomplete;
    }

    final partition = _partition(state.items);
    final revision = ++_revision;
    state = state.copyWith(isAccepting: true, failure: null);
    try {
      _requireReadyIdentity(expectedCreatorProfileId);
      await ref
          .read(joinAcceptanceTriageGatewayProvider)
          .acceptWithTriage(
            expectedCreatorProfileId: expectedCreatorProfileId,
            requestId: requestId,
            neededSkillIds: partition.neededSkillIds,
            alreadyFoundSkillIds: partition.alreadyFoundSkillIds,
            extraSkillIds: partition.extraSkillIds,
            neededResourceNeedIds: partition.neededResourceNeedIds,
            alreadyFoundResourceNeedIds: partition.alreadyFoundResourceNeedIds,
            extraResourceNeedIds: partition.extraResourceNeedIds,
          );
      if (!_isCurrent(revision, expectedCreatorProfileId)) {
        return JoinAcceptanceTriageSubmitResult.failed;
      }
      state = state.copyWith(isAccepting: false);
      ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      return JoinAcceptanceTriageSubmitResult.accepted;
    } catch (error) {
      if (!_isCurrent(revision, expectedCreatorProfileId)) {
        return JoinAcceptanceTriageSubmitResult.failed;
      }
      final failure = mapJoinAcceptanceTriageFailure(error);
      if (failure == JoinAcceptanceTriageFailureKind.forbidden) {
        state = JoinAcceptanceTriageState(
          requestId: requestId,
          expectedCreatorProfileId: expectedCreatorProfileId,
          loadPhase: JoinAcceptanceTriageLoadPhase.failure,
          failure: failure,
        );
      } else {
        state = state.copyWith(isAccepting: false, failure: failure);
      }
      return JoinAcceptanceTriageSubmitResult.failed;
    }
  }

  void clear() {
    _revision++;
    state = JoinAcceptanceTriageState(requestId: requestId);
  }

  bool _isCurrent(int revision, String expectedCreatorProfileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedCreatorProfileId &&
      state.requestId == requestId &&
      state.expectedCreatorProfileId == expectedCreatorProfileId;

  void _requireReadyIdentity(String expectedCreatorProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedCreatorProfileId) {
      throw const JoinAcceptanceIdentityChangedException();
    }
  }

  void _ensureUniqueKeys(Iterable<JoinAcceptanceTriageItem> items) {
    final keys = <JoinAcceptanceItemKey>{};
    for (final item in items) {
      if (!keys.add(item.key)) {
        throw const FormatException(
          'Join-acceptance selections contained a duplicate key.',
        );
      }
    }
  }

  _JoinAcceptancePartition _partition(
    Iterable<JoinAcceptanceTriageItem> items,
  ) {
    final neededSkillIds = <String>{};
    final alreadyFoundSkillIds = <String>{};
    final extraSkillIds = <String>{};
    final neededResourceNeedIds = <String>{};
    final alreadyFoundResourceNeedIds = <String>{};
    final extraResourceNeedIds = <String>{};
    for (final item in items) {
      final decision = item.decision;
      if (decision == null) {
        throw StateError('Cannot partition an undecided join-acceptance item.');
      }
      switch ((item.kind, decision)) {
        case (JoinAcceptanceSelectionKind.skill, JoinAcceptanceDecision.needed):
          neededSkillIds.add(item.id);
        case (
          JoinAcceptanceSelectionKind.skill,
          JoinAcceptanceDecision.alreadyFound,
        ):
          alreadyFoundSkillIds.add(item.id);
        case (JoinAcceptanceSelectionKind.skill, JoinAcceptanceDecision.extra):
          extraSkillIds.add(item.id);
        case (
          JoinAcceptanceSelectionKind.resource,
          JoinAcceptanceDecision.needed,
        ):
          neededResourceNeedIds.add(item.id);
        case (
          JoinAcceptanceSelectionKind.resource,
          JoinAcceptanceDecision.alreadyFound,
        ):
          alreadyFoundResourceNeedIds.add(item.id);
        case (
          JoinAcceptanceSelectionKind.resource,
          JoinAcceptanceDecision.extra,
        ):
          extraResourceNeedIds.add(item.id);
      }
    }
    return (
      neededSkillIds: neededSkillIds,
      alreadyFoundSkillIds: alreadyFoundSkillIds,
      extraSkillIds: extraSkillIds,
      neededResourceNeedIds: neededResourceNeedIds,
      alreadyFoundResourceNeedIds: alreadyFoundResourceNeedIds,
      extraResourceNeedIds: extraResourceNeedIds,
    );
  }
}

typedef _JoinAcceptancePartition = ({
  Set<String> neededSkillIds,
  Set<String> alreadyFoundSkillIds,
  Set<String> extraSkillIds,
  Set<String> neededResourceNeedIds,
  Set<String> alreadyFoundResourceNeedIds,
  Set<String> extraResourceNeedIds,
});

final joinAcceptanceTriageProvider =
    NotifierProvider.family<
      JoinAcceptanceTriageController,
      JoinAcceptanceTriageState,
      String
    >(JoinAcceptanceTriageController.new);

JoinAcceptanceTriageFailureKind mapJoinAcceptanceTriageFailure(Object error) {
  if (error is JoinAcceptanceIdentityChangedException) {
    return JoinAcceptanceTriageFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError || error is StateError) {
    return JoinAcceptanceTriageFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => JoinAcceptanceTriageFailureKind.projectNeedsChanged,
      '42501' => JoinAcceptanceTriageFailureKind.forbidden,
      '55000' => JoinAcceptanceTriageFailureKind.conflict,
      _ => JoinAcceptanceTriageFailureKind.unavailable,
    };
  }
  return JoinAcceptanceTriageFailureKind.unavailable;
}

class JoinAcceptanceIdentityChangedException implements Exception {
  const JoinAcceptanceIdentityChangedException();
}
