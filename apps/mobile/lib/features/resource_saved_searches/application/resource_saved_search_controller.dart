import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/resource_saved_search_gateway.dart';
import '../domain/resource_saved_search_models.dart';

enum ResourceSavedSearchPhase { idle, loading, ready, loadingMore, failure }

enum ResourceSavedSearchAction { creating, updating, deleting }

enum ResourceSavedSearchMutationOutcome {
  success,
  duplicate,
  invalidInput,
  forbidden,
  notFound,
  unavailable,
  staleIdentity,
  busy,
}

class ResourceSavedSearchState {
  const ResourceSavedSearchState({
    this.phase = ResourceSavedSearchPhase.idle,
    this.expectedProfileId,
    this.items = const [],
    this.hasMore = false,
    this.failure,
    this.action,
    this.actionTargetId,
  });

  final ResourceSavedSearchPhase phase;
  final String? expectedProfileId;
  final List<ResourceSavedSearch> items;
  final bool hasMore;
  final ResourceSavedSearchFailureKind? failure;
  final ResourceSavedSearchAction? action;
  final String? actionTargetId;

  bool get isLoading =>
      phase == ResourceSavedSearchPhase.loading ||
      phase == ResourceSavedSearchPhase.loadingMore;
  bool get isActing => action != null;
}

class ResourceSavedSearchIdentityChangedException implements Exception {
  const ResourceSavedSearchIdentityChangedException();
}

class ResourceSavedSearchNotFoundException implements Exception {
  const ResourceSavedSearchNotFoundException();
}

class ResourceSavedSearchController extends Notifier<ResourceSavedSearchState> {
  var _identityRevision = 0;
  var _loadRevision = 0;

  @override
  ResourceSavedSearchState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _identityRevision++;
      _loadRevision++;
      state = const ResourceSavedSearchState();
    });
    ref.onDispose(() {
      _identityRevision++;
      _loadRevision++;
    });
    return const ResourceSavedSearchState();
  }

  Future<bool> load(String expectedProfileId, {bool refresh = false}) async {
    if (state.isActing || (state.isLoading && !refresh)) return false;
    final identityRevision = _identityRevision;
    final loadRevision = ++_loadRevision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = ResourceSavedSearchState(
      phase: ResourceSavedSearchPhase.loading,
      expectedProfileId: expectedProfileId,
      items: preserve ? state.items : const [],
      hasMore: preserve && state.hasMore,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(resourceSavedSearchGatewayProvider)
          .listOwn(
            expectedProfileId: expectedProfileId,
            pageSize: resourceSavedSearchPageSize,
          );
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      state = ResourceSavedSearchState(
        phase: ResourceSavedSearchPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(page.items),
        hasMore: page.hasMore,
      );
      return true;
    } catch (error) {
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      final items = state.items;
      state = ResourceSavedSearchState(
        phase: items.isEmpty
            ? ResourceSavedSearchPhase.failure
            : ResourceSavedSearchPhase.ready,
        expectedProfileId: expectedProfileId,
        items: items,
        hasMore: state.hasMore,
        failure: mapResourceSavedSearchFailure(error),
      );
      return false;
    }
  }

  Future<bool> loadMore(String expectedProfileId) async {
    if (state.isLoading ||
        state.isActing ||
        state.expectedProfileId != expectedProfileId ||
        !state.hasMore ||
        state.items.isEmpty) {
      return false;
    }
    final identityRevision = _identityRevision;
    final loadRevision = ++_loadRevision;
    final existing = state.items;
    state = ResourceSavedSearchState(
      phase: ResourceSavedSearchPhase.loadingMore,
      expectedProfileId: expectedProfileId,
      items: existing,
      hasMore: true,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(resourceSavedSearchGatewayProvider)
          .listOwn(
            expectedProfileId: expectedProfileId,
            pageSize: resourceSavedSearchPageSize,
            cursor: existing.last.cursor,
          );
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      final known = existing.map((item) => item.id).toSet();
      state = ResourceSavedSearchState(
        phase: ResourceSavedSearchPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable([
          ...existing,
          ...page.items.where((item) => known.add(item.id)),
        ]),
        hasMore: page.hasMore,
      );
      return true;
    } catch (error) {
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      state = ResourceSavedSearchState(
        phase: ResourceSavedSearchPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: true,
        failure: mapResourceSavedSearchFailure(error),
      );
      return false;
    }
  }

  Future<ResourceSavedSearchMutationOutcome> create(
    String expectedProfileId,
    ResourceSavedSearchInput input,
  ) => _mutate(
    expectedProfileId: expectedProfileId,
    input: input,
    action: ResourceSavedSearchAction.creating,
    operation: (gateway) => gateway.create(expectedProfileId, input),
  );

  Future<ResourceSavedSearchMutationOutcome> update(
    String expectedProfileId,
    String savedSearchId,
    ResourceSavedSearchInput input,
  ) => _mutate(
    expectedProfileId: expectedProfileId,
    input: input,
    action: ResourceSavedSearchAction.updating,
    actionTargetId: savedSearchId,
    operation: (gateway) =>
        gateway.update(expectedProfileId, savedSearchId, input),
  );

  Future<ResourceSavedSearchMutationOutcome> delete(
    String expectedProfileId,
    String savedSearchId,
  ) => _mutate(
    expectedProfileId: expectedProfileId,
    action: ResourceSavedSearchAction.deleting,
    actionTargetId: savedSearchId,
    operation: (gateway) => gateway.delete(expectedProfileId, savedSearchId),
  );

  Future<ResourceSavedSearchMutationOutcome> _mutate({
    required String expectedProfileId,
    required ResourceSavedSearchAction action,
    required Future<Object?> Function(ResourceSavedSearchGateway gateway)
    operation,
    ResourceSavedSearchInput? input,
    String? actionTargetId,
  }) async {
    if (state.isActing || state.isLoading) {
      return ResourceSavedSearchMutationOutcome.busy;
    }
    if (input != null && !input.isValid) {
      return ResourceSavedSearchMutationOutcome.invalidInput;
    }
    final identityRevision = _identityRevision;
    final loadRevision = ++_loadRevision;
    final existing = state.expectedProfileId == expectedProfileId
        ? state.items
        : const <ResourceSavedSearch>[];
    state = ResourceSavedSearchState(
      phase: ResourceSavedSearchPhase.ready,
      expectedProfileId: expectedProfileId,
      items: existing,
      hasMore: state.hasMore,
      action: action,
      actionTargetId: actionTargetId,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await operation(ref.read(resourceSavedSearchGatewayProvider));
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return ResourceSavedSearchMutationOutcome.staleIdentity;
      }
      final page = await ref
          .read(resourceSavedSearchGatewayProvider)
          .listOwn(
            expectedProfileId: expectedProfileId,
            pageSize: resourceSavedSearchPageSize,
          );
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return ResourceSavedSearchMutationOutcome.staleIdentity;
      }
      state = ResourceSavedSearchState(
        phase: ResourceSavedSearchPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(page.items),
        hasMore: page.hasMore,
      );
      return ResourceSavedSearchMutationOutcome.success;
    } catch (error) {
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return ResourceSavedSearchMutationOutcome.staleIdentity;
      }
      final failure = mapResourceSavedSearchFailure(error);
      state = ResourceSavedSearchState(
        phase: ResourceSavedSearchPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: state.hasMore,
        failure: failure,
      );
      return mutationOutcomeForFailure(failure);
    }
  }

  bool _isCurrentLoad(
    int identityRevision,
    int loadRevision,
    String expectedProfileId,
  ) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      loadRevision == _loadRevision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == expectedProfileId;

  void _requireReadyIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      throw const ResourceSavedSearchIdentityChangedException();
    }
  }
}

ResourceSavedSearchFailureKind mapResourceSavedSearchFailure(Object error) {
  if (error is ResourceSavedSearchNotFoundException) {
    return ResourceSavedSearchFailureKind.notFound;
  }
  if (error is ResourceSavedSearchIdentityChangedException) {
    return ResourceSavedSearchFailureKind.forbidden;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ResourceSavedSearchFailureKind.invalidInput,
      '42501' => ResourceSavedSearchFailureKind.forbidden,
      'PT409' => ResourceSavedSearchFailureKind.duplicate,
      _ => ResourceSavedSearchFailureKind.unavailable,
    };
  }
  return ResourceSavedSearchFailureKind.unavailable;
}

ResourceSavedSearchMutationOutcome mutationOutcomeForFailure(
  ResourceSavedSearchFailureKind failure,
) => switch (failure) {
  ResourceSavedSearchFailureKind.invalidInput =>
    ResourceSavedSearchMutationOutcome.invalidInput,
  ResourceSavedSearchFailureKind.forbidden =>
    ResourceSavedSearchMutationOutcome.forbidden,
  ResourceSavedSearchFailureKind.duplicate =>
    ResourceSavedSearchMutationOutcome.duplicate,
  ResourceSavedSearchFailureKind.notFound =>
    ResourceSavedSearchMutationOutcome.notFound,
  ResourceSavedSearchFailureKind.unavailable =>
    ResourceSavedSearchMutationOutcome.unavailable,
};

final resourceSavedSearchesProvider =
    NotifierProvider<ResourceSavedSearchController, ResourceSavedSearchState>(
      ResourceSavedSearchController.new,
    );
