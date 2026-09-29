import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../data/blocking_gateway.dart';
import '../domain/blocking_models.dart';

class BlockingState {
  const BlockingState({
    this.expectedProfileId,
    this.listPhase = BlockingListPhase.idle,
    this.blockedProfiles = const [],
    this.hasMore = false,
    this.exactStatuses = const {},
    this.loadingTargets = const {},
    this.statusFailures = const {},
    this.mutation,
    this.mutationTargetId,
    this.failure,
  });

  final String? expectedProfileId;
  final BlockingListPhase listPhase;
  final List<BlockedProfile> blockedProfiles;
  final bool hasMore;
  final Map<String, BlockedProfile?> exactStatuses;
  final Set<String> loadingTargets;
  final Set<String> statusFailures;
  final BlockingMutation? mutation;
  final String? mutationTargetId;
  final BlockingFailureKind? failure;

  bool hasExactStatus(String targetProfileId) =>
      exactStatuses.containsKey(targetProfileId);
  BlockedProfile? exactStatus(String targetProfileId) =>
      exactStatuses[targetProfileId];
  bool isLoadingStatus(String targetProfileId) =>
      loadingTargets.contains(targetProfileId);
  bool hasStatusFailure(String targetProfileId) =>
      statusFailures.contains(targetProfileId);
  bool isMutating(String targetProfileId) =>
      mutationTargetId == targetProfileId && mutation != null;

  BlockingState copyWith({
    String? expectedProfileId,
    BlockingListPhase? listPhase,
    List<BlockedProfile>? blockedProfiles,
    bool? hasMore,
    Map<String, BlockedProfile?>? exactStatuses,
    Set<String>? loadingTargets,
    Set<String>? statusFailures,
    BlockingMutation? mutation,
    String? mutationTargetId,
    BlockingFailureKind? failure,
    bool clearMutation = false,
    bool clearFailure = false,
  }) => BlockingState(
    expectedProfileId: expectedProfileId ?? this.expectedProfileId,
    listPhase: listPhase ?? this.listPhase,
    blockedProfiles: blockedProfiles ?? this.blockedProfiles,
    hasMore: hasMore ?? this.hasMore,
    exactStatuses: exactStatuses ?? this.exactStatuses,
    loadingTargets: loadingTargets ?? this.loadingTargets,
    statusFailures: statusFailures ?? this.statusFailures,
    mutation: clearMutation ? null : mutation ?? this.mutation,
    mutationTargetId: clearMutation
        ? null
        : mutationTargetId ?? this.mutationTargetId,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

class BlockingIdentityChangedException implements Exception {
  const BlockingIdentityChangedException();
}

class BlockingController extends Notifier<BlockingState> {
  var _identityRevision = 0;
  var _listRevision = 0;
  final Map<String, int> _targetRevisions = {};

  @override
  BlockingState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      nextProfileId,
    ) {
      _identityRevision++;
      _listRevision++;
      _targetRevisions.clear();
      state = BlockingState(expectedProfileId: nextProfileId);
    });
    ref.onDispose(() {
      _identityRevision++;
      _listRevision++;
      _targetRevisions.clear();
    });
    return BlockingState(
      expectedProfileId: ref.read(authSessionProvider).identity?.id,
    );
  }

  Future<bool> loadStatus(
    String expectedProfileId,
    String targetProfileId, {
    bool force = false,
  }) async {
    if (state.isLoadingStatus(targetProfileId) ||
        (!force && state.hasExactStatus(targetProfileId))) {
      return false;
    }
    final identityRevision = _identityRevision;
    final targetRevision = _nextTargetRevision(targetProfileId);
    state = state.copyWith(
      expectedProfileId: expectedProfileId,
      loadingTargets: {...state.loadingTargets, targetProfileId},
      statusFailures: {...state.statusFailures}..remove(targetProfileId),
      clearFailure: true,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final status = await ref
          .read(blockingGatewayProvider)
          .getOwnStatus(
            expectedBlockerProfileId: expectedProfileId,
            targetProfileId: targetProfileId,
          );
      if (!_isCurrentTarget(
        identityRevision,
        targetRevision,
        expectedProfileId,
        targetProfileId,
      )) {
        return false;
      }
      state = state.copyWith(
        exactStatuses: {...state.exactStatuses, targetProfileId: status},
        loadingTargets: {...state.loadingTargets}..remove(targetProfileId),
        statusFailures: {...state.statusFailures}..remove(targetProfileId),
      );
      return true;
    } catch (error) {
      if (!_isCurrentTarget(
        identityRevision,
        targetRevision,
        expectedProfileId,
        targetProfileId,
      )) {
        return false;
      }
      state = state.copyWith(
        loadingTargets: {...state.loadingTargets}..remove(targetProfileId),
        statusFailures: {...state.statusFailures, targetProfileId},
        failure: mapBlockingFailure(error),
      );
      return false;
    }
  }

  Future<bool> loadList(
    String expectedProfileId, {
    bool refresh = false,
  }) async {
    if (state.mutation != null ||
        (state.listPhase == BlockingListPhase.loading && !refresh)) {
      return false;
    }
    final identityRevision = _identityRevision;
    final listRevision = ++_listRevision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = state.copyWith(
      expectedProfileId: expectedProfileId,
      listPhase: BlockingListPhase.loading,
      blockedProfiles: preserve ? state.blockedProfiles : const [],
      hasMore: preserve && state.hasMore,
      clearFailure: true,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(blockingGatewayProvider)
          .listOwn(expectedBlockerProfileId: expectedProfileId);
      if (!_isCurrentList(identityRevision, listRevision, expectedProfileId)) {
        return false;
      }
      state = state.copyWith(
        listPhase: BlockingListPhase.ready,
        blockedProfiles: List.unmodifiable(page.items),
        hasMore: page.hasMore,
        exactStatuses: {
          ...state.exactStatuses,
          for (final item in page.items) item.profileId: item,
        },
      );
      return true;
    } catch (error) {
      if (!_isCurrentList(identityRevision, listRevision, expectedProfileId)) {
        return false;
      }
      state = state.copyWith(
        listPhase: state.blockedProfiles.isEmpty
            ? BlockingListPhase.failure
            : BlockingListPhase.ready,
        failure: mapBlockingFailure(error),
      );
      return false;
    }
  }

  Future<bool> loadMore(String expectedProfileId) async {
    if (state.listPhase == BlockingListPhase.loading ||
        state.listPhase == BlockingListPhase.loadingMore ||
        state.mutation != null ||
        state.expectedProfileId != expectedProfileId ||
        !state.hasMore ||
        state.blockedProfiles.isEmpty) {
      return false;
    }
    final identityRevision = _identityRevision;
    final listRevision = ++_listRevision;
    final existing = state.blockedProfiles;
    state = state.copyWith(
      listPhase: BlockingListPhase.loadingMore,
      clearFailure: true,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(blockingGatewayProvider)
          .listOwn(
            expectedBlockerProfileId: expectedProfileId,
            cursor: existing.last,
          );
      if (!_isCurrentList(identityRevision, listRevision, expectedProfileId)) {
        return false;
      }
      final known = existing.map((item) => item.blockEpisodeId).toSet();
      final combined = [
        ...existing,
        ...page.items.where((item) => known.add(item.blockEpisodeId)),
      ];
      state = state.copyWith(
        listPhase: BlockingListPhase.ready,
        blockedProfiles: List.unmodifiable(combined),
        hasMore: page.hasMore,
        exactStatuses: {
          ...state.exactStatuses,
          for (final item in page.items) item.profileId: item,
        },
      );
      return true;
    } catch (error) {
      if (!_isCurrentList(identityRevision, listRevision, expectedProfileId)) {
        return false;
      }
      state = state.copyWith(
        listPhase: BlockingListPhase.ready,
        failure: mapBlockingFailure(error),
      );
      return false;
    }
  }

  Future<BlockingMutationOutcome> block(
    String expectedProfileId,
    String targetProfileId,
  ) => _mutate(
    expectedProfileId: expectedProfileId,
    targetProfileId: targetProfileId,
    mutation: BlockingMutation.blocking,
    operation: (gateway) => gateway.block(
      expectedBlockerProfileId: expectedProfileId,
      targetProfileId: targetProfileId,
    ),
  );

  Future<BlockingMutationOutcome> unblock(
    String expectedProfileId,
    String targetProfileId,
  ) => _mutate(
    expectedProfileId: expectedProfileId,
    targetProfileId: targetProfileId,
    mutation: BlockingMutation.unblocking,
    operation: (gateway) => gateway.unblock(
      expectedBlockerProfileId: expectedProfileId,
      targetProfileId: targetProfileId,
    ),
  );

  Future<BlockingMutationOutcome> _mutate({
    required String expectedProfileId,
    required String targetProfileId,
    required BlockingMutation mutation,
    required Future<void> Function(BlockingGateway gateway) operation,
  }) async {
    if (state.mutation != null || state.isLoadingStatus(targetProfileId)) {
      return BlockingMutationOutcome.busy;
    }
    final identityRevision = _identityRevision;
    final targetRevision = _nextTargetRevision(targetProfileId);
    state = state.copyWith(
      expectedProfileId: expectedProfileId,
      mutation: mutation,
      mutationTargetId: targetProfileId,
      clearFailure: true,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await operation(ref.read(blockingGatewayProvider));
      if (!_isCurrentTarget(
        identityRevision,
        targetRevision,
        expectedProfileId,
        targetProfileId,
      )) {
        return BlockingMutationOutcome.staleIdentity;
      }
      final refreshed = await ref
          .read(blockingGatewayProvider)
          .getOwnStatus(
            expectedBlockerProfileId: expectedProfileId,
            targetProfileId: targetProfileId,
          );
      if (!_isCurrentTarget(
        identityRevision,
        targetRevision,
        expectedProfileId,
        targetProfileId,
      )) {
        return BlockingMutationOutcome.staleIdentity;
      }
      final list = [...state.blockedProfiles]
        ..removeWhere((item) => item.profileId == targetProfileId);
      if (refreshed != null) list.insert(0, refreshed);
      state = state.copyWith(
        listPhase: state.listPhase == BlockingListPhase.idle
            ? BlockingListPhase.idle
            : BlockingListPhase.ready,
        blockedProfiles: List.unmodifiable(list),
        exactStatuses: {...state.exactStatuses, targetProfileId: refreshed},
        clearMutation: true,
      );
      ref
          .read(visibleProfilePhotoProvider.notifier)
          .invalidate(targetProfileId);
      return BlockingMutationOutcome.success;
    } catch (error) {
      if (!_isCurrentTarget(
        identityRevision,
        targetRevision,
        expectedProfileId,
        targetProfileId,
      )) {
        return BlockingMutationOutcome.staleIdentity;
      }
      final failure = mapBlockingFailure(error);
      state = state.copyWith(clearMutation: true, failure: failure);
      return outcomeForBlockingFailure(failure);
    }
  }

  int _nextTargetRevision(String targetProfileId) {
    final next = (_targetRevisions[targetProfileId] ?? 0) + 1;
    _targetRevisions[targetProfileId] = next;
    return next;
  }

  bool _isCurrentTarget(
    int identityRevision,
    int targetRevision,
    String expectedProfileId,
    String targetProfileId,
  ) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      targetRevision == _targetRevisions[targetProfileId] &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == expectedProfileId;

  bool _isCurrentList(
    int identityRevision,
    int listRevision,
    String expectedProfileId,
  ) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      listRevision == _listRevision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == expectedProfileId;

  void _requireReadyIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      throw const BlockingIdentityChangedException();
    }
  }
}

BlockingFailureKind mapBlockingFailure(Object error) {
  if (error is BlockingIdentityChangedException) {
    return BlockingFailureKind.forbidden;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => BlockingFailureKind.invalidInput,
      '42501' => BlockingFailureKind.forbidden,
      'P0002' => BlockingFailureKind.targetUnavailable,
      'PT409' => BlockingFailureKind.interactionUnavailable,
      _ => BlockingFailureKind.unavailable,
    };
  }
  return BlockingFailureKind.unavailable;
}

BlockingMutationOutcome outcomeForBlockingFailure(
  BlockingFailureKind failure,
) => switch (failure) {
  BlockingFailureKind.invalidInput => BlockingMutationOutcome.invalidInput,
  BlockingFailureKind.forbidden => BlockingMutationOutcome.forbidden,
  BlockingFailureKind.targetUnavailable =>
    BlockingMutationOutcome.targetUnavailable,
  BlockingFailureKind.interactionUnavailable =>
    BlockingMutationOutcome.interactionUnavailable,
  BlockingFailureKind.unavailable => BlockingMutationOutcome.unavailable,
};

final blockingProvider = NotifierProvider<BlockingController, BlockingState>(
  BlockingController.new,
);
