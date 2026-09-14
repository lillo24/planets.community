import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/resource_listing_gateway.dart';
import '../domain/resource_listing_models.dart';

class PublicResourceListingsController
    extends Notifier<PublicResourceListingsState> {
  var _revision = 0;

  @override
  PublicResourceListingsState build() {
    ref.onDispose(() => _revision++);
    return const PublicResourceListingsState();
  }

  Future<void> load({bool reset = true, bool force = false}) async {
    if (state.isBusy && !force) return;
    final revision = ++_revision;
    final previousItems = state.items;
    final mode = state.modeFilter;
    final locality = state.locality;
    final query = state.query;
    final previousCursor = state.cursor;
    state = PublicResourceListingsState(
      phase: reset
          ? ResourceListingLoadPhase.loading
          : ResourceListingLoadPhase.loadingMore,
      items: previousItems,
      modeFilter: mode,
      locality: locality,
      query: query,
      cursor: previousCursor,
      hasMore: state.hasMore,
    );

    try {
      final cursor = reset ? null : previousCursor;
      final page = await ref
          .read(resourceListingGatewayProvider)
          .listPublicResourceListings(
            limit: resourceListingPageSize,
            cursor: cursor,
            mode: mode,
            locality: locality.isEmpty ? null : locality,
            query: query.isEmpty ? null : query,
          );
      if (!_isCurrent(revision, mode, locality, query)) return;

      final nextItems = reset
          ? List<PublicResourceListingSummary>.of(page)
          : _appendDeduplicated(previousItems, page);
      state = PublicResourceListingsState(
        phase: ResourceListingLoadPhase.ready,
        items: List.unmodifiable(nextItems),
        modeFilter: mode,
        locality: locality,
        query: query,
        cursor: page.isEmpty
            ? (reset ? null : previousCursor)
            : page.last.cursor,
        hasMore: page.length == resourceListingPageSize,
      );
    } catch (error) {
      if (_isCurrent(revision, mode, locality, query)) {
        state = PublicResourceListingsState(
          phase: ResourceListingLoadPhase.failure,
          items: previousItems,
          modeFilter: mode,
          locality: locality,
          query: query,
          cursor: previousCursor,
          hasMore: state.hasMore,
          failure: mapResourceListingFailure(error),
        );
      }
    }
  }

  Future<void> applyFilters({
    required ResourceListingMode? mode,
    required String locality,
    required String query,
  }) async {
    _revision++;
    state = PublicResourceListingsState(
      modeFilter: mode,
      locality: locality.trim(),
      query: query.trim(),
    );
    await load();
  }

  bool _isCurrent(
    int revision,
    ResourceListingMode? mode,
    String locality,
    String query,
  ) =>
      ref.mounted &&
      revision == _revision &&
      state.modeFilter == mode &&
      state.locality == locality &&
      state.query == query;

  List<PublicResourceListingSummary> _appendDeduplicated(
    List<PublicResourceListingSummary> current,
    List<PublicResourceListingSummary> page,
  ) {
    final seen = current.map((item) => item.id).toSet();
    return [
      ...current,
      for (final item in page)
        if (seen.add(item.id)) item,
    ];
  }
}

final publicResourceListingsProvider =
    NotifierProvider<
      PublicResourceListingsController,
      PublicResourceListingsState
    >(PublicResourceListingsController.new);

class PublicResourceListingDetailController
    extends Notifier<PublicResourceListingDetailState> {
  var _revision = 0;

  @override
  PublicResourceListingDetailState build() {
    ref.onDispose(() => _revision++);
    return const PublicResourceListingDetailState();
  }

  Future<void> load(String listingId) async {
    final revision = ++_revision;
    final previous = state.listingId == listingId ? state.detail : null;
    state = PublicResourceListingDetailState(
      phase: ResourceListingLoadPhase.loading,
      listingId: listingId,
      detail: previous,
    );
    try {
      final detail = await ref
          .read(resourceListingGatewayProvider)
          .getPublicResourceListing(listingId);
      if (ref.mounted && revision == _revision) {
        state = PublicResourceListingDetailState(
          phase: ResourceListingLoadPhase.ready,
          listingId: listingId,
          detail: detail,
        );
      }
    } catch (error) {
      if (ref.mounted && revision == _revision) {
        state = PublicResourceListingDetailState(
          phase: ResourceListingLoadPhase.failure,
          listingId: listingId,
          detail: previous,
          failure: mapResourceListingFailure(error),
        );
      }
    }
  }

  void refreshIfLoaded(String listingId) {
    if (state.listingId == listingId) {
      unawaited(load(listingId));
    }
  }
}

final publicResourceListingDetailProvider =
    NotifierProvider<
      PublicResourceListingDetailController,
      PublicResourceListingDetailState
    >(PublicResourceListingDetailController.new);

class OwnResourceListingsController extends Notifier<OwnResourceListingsState> {
  var _revision = 0;

  @override
  OwnResourceListingsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const OwnResourceListingsState();
    });
    ref.onDispose(() => _revision++);
    return const OwnResourceListingsState();
  }

  Future<void> load(String expectedOwnerId) async {
    final revision = ++_revision;
    final previous = state.expectedOwnerId == expectedOwnerId
        ? state.items
        : const <OwnResourceListing>[];
    state = OwnResourceListingsState(
      phase: ResourceListingLoadPhase.loading,
      expectedOwnerId: expectedOwnerId,
      items: previous,
    );
    try {
      _requireReadyIdentity(expectedOwnerId);
      final items = await ref
          .read(resourceListingGatewayProvider)
          .listOwnResourceListings(expectedOwnerId);
      if (_isCurrent(revision, expectedOwnerId)) {
        state = OwnResourceListingsState(
          phase: ResourceListingLoadPhase.ready,
          expectedOwnerId: expectedOwnerId,
          items: List.unmodifiable(items),
        );
      }
    } catch (error) {
      if (_isCurrent(revision, expectedOwnerId)) {
        state = OwnResourceListingsState(
          phase: ResourceListingLoadPhase.failure,
          expectedOwnerId: expectedOwnerId,
          items: previous,
          failure: mapResourceListingFailure(error),
        );
      }
    }
  }

  bool _isCurrent(int revision, String expectedOwnerId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedOwnerId;

  void _requireReadyIdentity(String expectedOwnerId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedOwnerId) {
      throw const ResourceListingIdentityChangedException();
    }
  }
}

final ownResourceListingsProvider =
    NotifierProvider<OwnResourceListingsController, OwnResourceListingsState>(
      OwnResourceListingsController.new,
    );

class ResourceListingEditorController
    extends Notifier<ResourceListingEditorState> {
  var _revision = 0;

  @override
  ResourceListingEditorState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ResourceListingEditorState();
    });
    ref.onDispose(() => _revision++);
    return const ResourceListingEditorState();
  }

  Future<void> load(String expectedOwnerId, String? listingId) async {
    final revision = ++_revision;
    if (listingId == null) {
      try {
        _requireReadyIdentity(expectedOwnerId);
        if (_isCurrent(revision, expectedOwnerId)) {
          state = ResourceListingEditorState(
            phase: ResourceListingEditorPhase.ready,
            expectedOwnerId: expectedOwnerId,
          );
        }
      } catch (error) {
        if (ref.mounted && revision == _revision) {
          state = ResourceListingEditorState(
            phase: ResourceListingEditorPhase.failure,
            expectedOwnerId: expectedOwnerId,
            failure: mapResourceListingFailure(error),
          );
        }
      }
      return;
    }

    final previous =
        state.expectedOwnerId == expectedOwnerId && state.listingId == listingId
        ? state.listing
        : null;
    state = ResourceListingEditorState(
      phase: ResourceListingEditorPhase.loading,
      expectedOwnerId: expectedOwnerId,
      listingId: listingId,
      listing: previous,
    );
    try {
      _requireReadyIdentity(expectedOwnerId);
      final listing = await ref
          .read(resourceListingGatewayProvider)
          .getOwnResourceListing(expectedOwnerId, listingId);
      if (!_isCurrent(revision, expectedOwnerId)) return;
      if (listing == null) throw const ResourceListingNotFoundException();
      state = ResourceListingEditorState(
        phase: ResourceListingEditorPhase.ready,
        expectedOwnerId: expectedOwnerId,
        listingId: listingId,
        listing: listing,
      );
    } catch (error) {
      if (_isCurrent(revision, expectedOwnerId)) {
        state = ResourceListingEditorState(
          phase: ResourceListingEditorPhase.failure,
          expectedOwnerId: expectedOwnerId,
          listingId: listingId,
          listing: previous,
          failure: mapResourceListingFailure(error),
        );
      }
    }
  }

  Future<String?> save(String expectedOwnerId, ResourceListingInput input) {
    final published =
        state.listing?.lifecycle == ResourceListingLifecycle.published;
    if (state.isBusy ||
        !isValidResourceListingDraft(input) ||
        (published && !isPublishableResourceListingInput(input))) {
      _setInvalidInput(expectedOwnerId);
      return Future.value(null);
    }
    return _saveContent(expectedOwnerId, input, publish: false);
  }

  Future<String?> publish(String expectedOwnerId, ResourceListingInput input) {
    if (state.isBusy || !isPublishableResourceListingInput(input)) {
      _setInvalidInput(expectedOwnerId);
      return Future.value(null);
    }
    return _saveContent(expectedOwnerId, input, publish: true);
  }

  Future<String?> _saveContent(
    String expectedOwnerId,
    ResourceListingInput input, {
    required bool publish,
  }) async {
    final existing = state.listing;
    if (existing?.lifecycle == ResourceListingLifecycle.closed) {
      state = ResourceListingEditorState(
        phase: ResourceListingEditorPhase.failure,
        expectedOwnerId: expectedOwnerId,
        listingId: existing!.id,
        listing: existing,
        failure: ResourceListingFailureKind.invalidState,
      );
      return null;
    }

    final revision = ++_revision;
    var retainedId = state.listingId;
    var createdNow = false;
    var publishCompleted = false;
    state = ResourceListingEditorState(
      phase: publish
          ? ResourceListingEditorPhase.publishing
          : ResourceListingEditorPhase.saving,
      expectedOwnerId: expectedOwnerId,
      listingId: retainedId,
      listing: existing,
    );
    try {
      _requireReadyIdentity(expectedOwnerId);
      final gateway = ref.read(resourceListingGatewayProvider);
      if (retainedId == null) {
        retainedId = await gateway.createDraft(expectedOwnerId, input);
        createdNow = true;
        if (!_isCurrent(revision, expectedOwnerId)) return null;
        state = ResourceListingEditorState(
          phase: publish
              ? ResourceListingEditorPhase.publishing
              : ResourceListingEditorPhase.saving,
          expectedOwnerId: expectedOwnerId,
          listingId: retainedId,
        );
      } else {
        await gateway.updateOwnResourceListing(
          expectedOwnerId,
          retainedId,
          input,
        );
        if (!_isCurrent(revision, expectedOwnerId)) return null;
      }
      if (publish) {
        await gateway.publishResourceListing(expectedOwnerId, retainedId);
        publishCompleted = true;
        if (!_isCurrent(revision, expectedOwnerId)) return null;
      }
      final canonical = await gateway.getOwnResourceListing(
        expectedOwnerId,
        retainedId,
      );
      if (!_isCurrent(revision, expectedOwnerId)) return null;
      if (canonical == null) throw const ResourceListingNotFoundException();
      state = ResourceListingEditorState(
        phase: ResourceListingEditorPhase.ready,
        expectedOwnerId: expectedOwnerId,
        listingId: retainedId,
        listing: canonical,
      );
      _refreshAfterMutation(
        expectedOwnerId,
        retainedId,
        publicChanged:
            publish ||
            canonical.lifecycle == ResourceListingLifecycle.published,
      );
      return retainedId;
    } catch (error) {
      if (!_isCurrent(revision, expectedOwnerId)) return null;
      state = ResourceListingEditorState(
        phase: ResourceListingEditorPhase.failure,
        expectedOwnerId: expectedOwnerId,
        listingId: retainedId,
        listing: existing,
        failure: mapResourceListingFailure(error),
        draftSavedAfterPublishFailure:
            publish && createdNow && !publishCompleted && retainedId != null,
      );
      if (createdNow && retainedId != null) {
        _refreshOwn(expectedOwnerId);
      }
      return null;
    }
  }

  Future<bool> close(String expectedOwnerId) async {
    final listing = state.listing;
    if (state.isBusy ||
        listing == null ||
        listing.lifecycle != ResourceListingLifecycle.published) {
      return false;
    }
    final revision = ++_revision;
    state = ResourceListingEditorState(
      phase: ResourceListingEditorPhase.closing,
      expectedOwnerId: expectedOwnerId,
      listingId: listing.id,
      listing: listing,
    );
    try {
      _requireReadyIdentity(expectedOwnerId);
      final gateway = ref.read(resourceListingGatewayProvider);
      await gateway.closeResourceListing(expectedOwnerId, listing.id);
      if (!_isCurrent(revision, expectedOwnerId)) return false;
      final canonical = await gateway.getOwnResourceListing(
        expectedOwnerId,
        listing.id,
      );
      if (!_isCurrent(revision, expectedOwnerId)) return false;
      if (canonical == null) throw const ResourceListingNotFoundException();
      state = ResourceListingEditorState(
        phase: ResourceListingEditorPhase.ready,
        expectedOwnerId: expectedOwnerId,
        listingId: listing.id,
        listing: canonical,
      );
      _refreshAfterMutation(expectedOwnerId, listing.id, publicChanged: true);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedOwnerId)) return false;
      state = ResourceListingEditorState(
        phase: ResourceListingEditorPhase.failure,
        expectedOwnerId: expectedOwnerId,
        listingId: listing.id,
        listing: listing,
        failure: mapResourceListingFailure(error),
      );
      return false;
    }
  }

  void _setInvalidInput(String expectedOwnerId) {
    state = ResourceListingEditorState(
      phase: ResourceListingEditorPhase.failure,
      expectedOwnerId: expectedOwnerId,
      listingId: state.listingId,
      listing: state.listing,
      failure: ResourceListingFailureKind.invalidInput,
    );
  }

  void _refreshOwn(String expectedOwnerId) {
    unawaited(
      ref.read(ownResourceListingsProvider.notifier).load(expectedOwnerId),
    );
  }

  void _refreshAfterMutation(
    String expectedOwnerId,
    String listingId, {
    required bool publicChanged,
  }) {
    _refreshOwn(expectedOwnerId);
    if (publicChanged) {
      unawaited(
        ref.read(publicResourceListingsProvider.notifier).load(force: true),
      );
      ref
          .read(publicResourceListingDetailProvider.notifier)
          .refreshIfLoaded(listingId);
    }
  }

  bool _isCurrent(int revision, String expectedOwnerId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedOwnerId;

  void _requireReadyIdentity(String expectedOwnerId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedOwnerId) {
      throw const ResourceListingIdentityChangedException();
    }
  }
}

final resourceListingEditorProvider =
    NotifierProvider<
      ResourceListingEditorController,
      ResourceListingEditorState
    >(ResourceListingEditorController.new);

ResourceListingFailureKind mapResourceListingFailure(Object error) {
  if (error is ResourceListingIdentityChangedException) {
    return ResourceListingFailureKind.forbidden;
  }
  if (error is ResourceListingInvalidStateException) {
    return ResourceListingFailureKind.invalidState;
  }
  if (error is ResourceListingNotFoundException) {
    return ResourceListingFailureKind.notFound;
  }
  if (error is FormatException) {
    return ResourceListingFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ResourceListingFailureKind.invalidInput,
      '42501' => ResourceListingFailureKind.forbidden,
      '55000' => ResourceListingFailureKind.invalidState,
      'P0002' => ResourceListingFailureKind.notFound,
      _ => ResourceListingFailureKind.unavailable,
    };
  }
  return ResourceListingFailureKind.unavailable;
}

class ResourceListingIdentityChangedException implements Exception {
  const ResourceListingIdentityChangedException();
}

class ResourceListingInvalidStateException implements Exception {
  const ResourceListingInvalidStateException();
}

class ResourceListingNotFoundException implements Exception {
  const ResourceListingNotFoundException();
}
