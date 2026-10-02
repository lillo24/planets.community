import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/application/messages_controllers.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../resource_listings/application/resource_listing_controllers.dart';
import '../data/resource_request_gateway.dart';
import '../domain/resource_request_models.dart';

enum ResourceRequestHistoryPhase { idle, loading, ready, failure }

class ResourceRequestHistoryState {
  const ResourceRequestHistoryState({
    this.phase = ResourceRequestHistoryPhase.idle,
    this.expectedRequesterProfileId,
    this.items = const [],
    this.failure,
  });

  final ResourceRequestHistoryPhase phase;
  final String? expectedRequesterProfileId;
  final List<OwnResourceRequest> items;
  final ResourceRequestFailureKind? failure;
}

class ResourceRequestHistoryController
    extends Notifier<ResourceRequestHistoryState> {
  var _revision = 0;

  @override
  ResourceRequestHistoryState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _revision++;
        state = const ResourceRequestHistoryState();
      },
    );
    ref.onDispose(() => _revision++);
    return const ResourceRequestHistoryState();
  }

  Future<bool> load(
    String expectedRequesterProfileId, {
    bool force = false,
  }) async {
    if (!force &&
        state.expectedRequesterProfileId == expectedRequesterProfileId &&
        state.phase == ResourceRequestHistoryPhase.ready) {
      return true;
    }
    if (!force &&
        state.expectedRequesterProfileId == expectedRequesterProfileId &&
        state.phase == ResourceRequestHistoryPhase.loading) {
      return false;
    }
    final revision = ++_revision;
    final previous =
        state.expectedRequesterProfileId == expectedRequesterProfileId
        ? state.items
        : const <OwnResourceRequest>[];
    state = ResourceRequestHistoryState(
      phase: ResourceRequestHistoryPhase.loading,
      expectedRequesterProfileId: expectedRequesterProfileId,
      items: previous,
    );
    try {
      _requireReadyIdentity(expectedRequesterProfileId);
      final items = await ref
          .read(resourceRequestGatewayProvider)
          .listOwn(expectedRequesterProfileId);
      if (!_isCurrent(revision, expectedRequesterProfileId)) return false;
      state = ResourceRequestHistoryState(
        phase: ResourceRequestHistoryPhase.ready,
        expectedRequesterProfileId: expectedRequesterProfileId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedRequesterProfileId)) return false;
      state = ResourceRequestHistoryState(
        phase: ResourceRequestHistoryPhase.failure,
        expectedRequesterProfileId: expectedRequesterProfileId,
        items: previous,
        failure: mapResourceRequestFailure(error),
      );
      return false;
    }
  }

  OwnResourceRequest? activeRequestForListing(String listingId) {
    if (state.phase != ResourceRequestHistoryPhase.ready) return null;
    for (final request in state.items) {
      if (request.listingId == listingId && request.isActive) return request;
    }
    return null;
  }

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const ResourceRequestIdentityChangedException();
    }
  }
}

final resourceRequestHistoryProvider =
    NotifierProvider<
      ResourceRequestHistoryController,
      ResourceRequestHistoryState
    >(ResourceRequestHistoryController.new);

enum ResourceRequestComposerPhase { idle, submitting, success, failure }

class ResourceRequestComposerState {
  const ResourceRequestComposerState({
    required this.listingId,
    this.phase = ResourceRequestComposerPhase.idle,
    this.expectedRequesterProfileId,
    this.requestId,
    this.canonicalActiveRequest,
    this.failure,
  });

  final String listingId;
  final ResourceRequestComposerPhase phase;
  final String? expectedRequesterProfileId;
  final String? requestId;
  final OwnResourceRequest? canonicalActiveRequest;
  final ResourceRequestFailureKind? failure;

  bool get isSubmitting => phase == ResourceRequestComposerPhase.submitting;
}

class ResourceRequestComposerController
    extends Notifier<ResourceRequestComposerState> {
  ResourceRequestComposerController(this.listingId);

  final String listingId;
  var _revision = 0;

  @override
  ResourceRequestComposerState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _revision++;
        state = ResourceRequestComposerState(listingId: listingId);
      },
    );
    ref.onDispose(() => _revision++);
    return ResourceRequestComposerState(listingId: listingId);
  }

  void reset(String expectedRequesterProfileId) {
    if (state.isSubmitting) return;
    state = ResourceRequestComposerState(
      listingId: listingId,
      expectedRequesterProfileId: expectedRequesterProfileId,
    );
  }

  Future<bool> submit({
    required String expectedRequesterProfileId,
    required String message,
  }) async {
    if (state.isSubmitting) return false;
    if (!isValidResourceRequestMessage(message)) {
      state = ResourceRequestComposerState(
        listingId: listingId,
        expectedRequesterProfileId: expectedRequesterProfileId,
        failure: ResourceRequestFailureKind.invalidInput,
        phase: ResourceRequestComposerPhase.failure,
      );
      return false;
    }
    final revision = ++_revision;
    state = ResourceRequestComposerState(
      listingId: listingId,
      expectedRequesterProfileId: expectedRequesterProfileId,
      phase: ResourceRequestComposerPhase.submitting,
    );
    try {
      _requireReadyIdentity(expectedRequesterProfileId);
      final requestId = await ref
          .read(resourceRequestGatewayProvider)
          .create(
            expectedRequesterProfileId: expectedRequesterProfileId,
            listingId: listingId,
            message: message,
          );
      if (!_isCurrent(revision, expectedRequesterProfileId)) return false;
      await _refreshRequestSurfaces(
        ref,
        expectedProfileId: expectedRequesterProfileId,
        listingId: listingId,
        refreshRequesterHistory: true,
      );
      if (!_isCurrent(revision, expectedRequesterProfileId)) return false;
      final canonical = ref
          .read(resourceRequestHistoryProvider.notifier)
          .activeRequestForListing(listingId);
      state = ResourceRequestComposerState(
        listingId: listingId,
        expectedRequesterProfileId: expectedRequesterProfileId,
        phase: ResourceRequestComposerPhase.success,
        requestId: requestId,
        canonicalActiveRequest: canonical,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedRequesterProfileId)) return false;
      final failure = mapResourceRequestFailure(error);
      OwnResourceRequest? canonical;
      if (failure == ResourceRequestFailureKind.conflict ||
          failure == ResourceRequestFailureKind.interactionUnavailable ||
          failure == ResourceRequestFailureKind.listingUnavailable ||
          failure == ResourceRequestFailureKind.notFound) {
        await _refreshRequestSurfaces(
          ref,
          expectedProfileId: expectedRequesterProfileId,
          listingId: listingId,
          refreshRequesterHistory: true,
        );
        if (!_isCurrent(revision, expectedRequesterProfileId)) return false;
        canonical = ref
            .read(resourceRequestHistoryProvider.notifier)
            .activeRequestForListing(listingId);
      }
      state = ResourceRequestComposerState(
        listingId: listingId,
        expectedRequesterProfileId: expectedRequesterProfileId,
        phase: ResourceRequestComposerPhase.failure,
        canonicalActiveRequest: canonical,
        failure: failure,
      );
      return false;
    }
  }

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const ResourceRequestIdentityChangedException();
    }
  }
}

final resourceRequestComposerProvider =
    NotifierProvider.family<
      ResourceRequestComposerController,
      ResourceRequestComposerState,
      String
    >(ResourceRequestComposerController.new);

enum ResourceRequestDetailPhase { idle, loading, ready, failure }

class ResourceRequestDetailState {
  const ResourceRequestDetailState({
    required this.requestId,
    this.phase = ResourceRequestDetailPhase.idle,
    this.expectedProfileId,
    this.item,
    this.action,
    this.failure,
  });

  final String requestId;
  final ResourceRequestDetailPhase phase;
  final String? expectedProfileId;
  final ResourceRequest? item;
  final ResourceRequestMutation? action;
  final ResourceRequestFailureKind? failure;

  bool get isActing => action != null;
}

class ResourceRequestDetailController
    extends Notifier<ResourceRequestDetailState> {
  ResourceRequestDetailController(this.requestId);

  final String requestId;
  var _revision = 0;

  @override
  ResourceRequestDetailState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _revision++;
        state = ResourceRequestDetailState(requestId: requestId);
      },
    );
    ref.onDispose(() => _revision++);
    return ResourceRequestDetailState(requestId: requestId);
  }

  Future<bool> load(String expectedProfileId) async {
    final revision = ++_revision;
    final previous = state.expectedProfileId == expectedProfileId
        ? state.item
        : null;
    state = ResourceRequestDetailState(
      requestId: requestId,
      expectedProfileId: expectedProfileId,
      phase: ResourceRequestDetailPhase.loading,
      item: previous,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final item = await ref
          .read(resourceRequestGatewayProvider)
          .get(expectedProfileId: expectedProfileId, requestId: requestId);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      if (item == null) throw const ResourceRequestNotFoundException();
      state = ResourceRequestDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        phase: ResourceRequestDetailPhase.ready,
        item: item,
      );
      _reconcileRequesterPhoto(previous, item, expectedProfileId);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ResourceRequestDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        phase: ResourceRequestDetailPhase.failure,
        item: previous,
        failure: mapResourceRequestFailure(error),
      );
      return false;
    }
  }

  Future<bool> accept(String expectedProfileId) =>
      _mutate(expectedProfileId, ResourceRequestMutation.accepting);

  Future<bool> reject(String expectedProfileId) =>
      _mutate(expectedProfileId, ResourceRequestMutation.rejecting);

  Future<bool> withdraw(String expectedProfileId) =>
      _mutate(expectedProfileId, ResourceRequestMutation.withdrawing);

  Future<bool> reloadAfterBlocking(String expectedProfileId) async {
    final previous = state.expectedProfileId == expectedProfileId
        ? state.item
        : null;
    if (previous == null) return load(expectedProfileId);
    final loaded = await load(expectedProfileId);
    final revision = _revision;
    if (!_isCurrent(revision, expectedProfileId)) return false;
    await _refreshRequestSurfaces(
      ref,
      expectedProfileId: expectedProfileId,
      listingId: previous.listingId,
      refreshRequesterHistory: previous.requesterProfileId == expectedProfileId,
    );
    return loaded && _isCurrent(revision, expectedProfileId);
  }

  Future<bool> withdrawFromHistory({
    required String expectedProfileId,
    required OwnResourceRequest request,
  }) async {
    if (!request.isActive || request.status != ResourceRequestStatus.pending) {
      return false;
    }
    if (state.item?.id != requestId ||
        state.expectedProfileId != expectedProfileId) {
      if (!await load(expectedProfileId)) return false;
    }
    return withdraw(expectedProfileId);
  }

  Future<bool> _mutate(
    String expectedProfileId,
    ResourceRequestMutation action,
  ) async {
    final item = state.item;
    if (item == null ||
        state.isActing ||
        item.status != ResourceRequestStatus.pending ||
        !_roleAllows(item, expectedProfileId, action)) {
      return false;
    }
    final revision = ++_revision;
    state = ResourceRequestDetailState(
      requestId: requestId,
      expectedProfileId: expectedProfileId,
      phase: ResourceRequestDetailPhase.ready,
      item: item,
      action: action,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final gateway = ref.read(resourceRequestGatewayProvider);
      switch (action) {
        case ResourceRequestMutation.accepting:
          await gateway.accept(
            expectedOwnerProfileId: expectedProfileId,
            requestId: requestId,
          );
        case ResourceRequestMutation.rejecting:
          await gateway.reject(
            expectedOwnerProfileId: expectedProfileId,
            requestId: requestId,
          );
        case ResourceRequestMutation.withdrawing:
          await gateway.withdraw(
            expectedRequesterProfileId: expectedProfileId,
            requestId: requestId,
          );
      }
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final canonical = await gateway.get(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      if (canonical == null) throw const ResourceRequestNotFoundException();
      state = ResourceRequestDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        phase: ResourceRequestDetailPhase.ready,
        item: canonical,
      );
      _reconcileRequesterPhoto(item, canonical, expectedProfileId);
      await _refreshRequestSurfaces(
        ref,
        expectedProfileId: expectedProfileId,
        listingId: canonical.listingId,
        refreshRequesterHistory:
            canonical.requesterProfileId == expectedProfileId,
      );
      return _isCurrent(revision, expectedProfileId);
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final failure = mapResourceRequestFailure(error);
      ResourceRequest? canonical = item;
      if (failure == ResourceRequestFailureKind.conflict ||
          failure == ResourceRequestFailureKind.interactionUnavailable) {
        try {
          canonical = await ref
              .read(resourceRequestGatewayProvider)
              .get(expectedProfileId: expectedProfileId, requestId: requestId);
        } catch (_) {
          canonical = null;
        }
        if (!_isCurrent(revision, expectedProfileId)) return false;
        await _refreshRequestSurfaces(
          ref,
          expectedProfileId: expectedProfileId,
          listingId: canonical?.listingId ?? item.listingId,
          refreshRequesterHistory:
              (canonical ?? item).requesterProfileId == expectedProfileId,
        );
        if (!_isCurrent(revision, expectedProfileId)) return false;
      }
      state = ResourceRequestDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        phase: canonical == null
            ? ResourceRequestDetailPhase.failure
            : ResourceRequestDetailPhase.ready,
        item: canonical,
        failure: failure,
      );
      if (canonical != null) {
        _reconcileRequesterPhoto(item, canonical, expectedProfileId);
      }
      return false;
    }
  }

  bool _roleAllows(
    ResourceRequest item,
    String profileId,
    ResourceRequestMutation action,
  ) => switch ((item.viewerRoleFor(profileId), action)) {
    (ResourceRequestViewerRole.owner, ResourceRequestMutation.accepting) ||
    (ResourceRequestViewerRole.owner, ResourceRequestMutation.rejecting) ||
    (
      ResourceRequestViewerRole.requester,
      ResourceRequestMutation.withdrawing,
    ) => true,
    _ => false,
  };

  void _reconcileRequesterPhoto(
    ResourceRequest? previous,
    ResourceRequest current,
    String viewerProfileId,
  ) {
    final wasAuthorized =
        previous != null &&
        _ownerCanSeeRequesterPhoto(previous, viewerProfileId);
    final isAuthorized = _ownerCanSeeRequesterPhoto(current, viewerProfileId);
    final photos = ref.read(visibleProfilePhotoProvider.notifier);
    if (!isAuthorized &&
        (wasAuthorized || current.ownerProfileId == viewerProfileId)) {
      photos.invalidate(current.requesterProfileId);
      return;
    }
    if (isAuthorized) {
      unawaited(photos.load(current.requesterProfileId));
    }
  }

  bool _ownerCanSeeRequesterPhoto(
    ResourceRequest item,
    String viewerProfileId,
  ) =>
      item.ownerProfileId == viewerProfileId &&
      (item.status == ResourceRequestStatus.pending ||
          (item.status == ResourceRequestStatus.accepted &&
              item.coordinationClosedAt == null));

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const ResourceRequestIdentityChangedException();
    }
  }
}

final resourceRequestDetailProvider =
    NotifierProvider.family<
      ResourceRequestDetailController,
      ResourceRequestDetailState,
      String
    >(ResourceRequestDetailController.new);

Future<void> _refreshRequestSurfaces(
  Ref ref, {
  required String expectedProfileId,
  required String listingId,
  required bool refreshRequesterHistory,
}) async {
  if (refreshRequesterHistory) {
    await ref
        .read(resourceRequestHistoryProvider.notifier)
        .load(expectedProfileId, force: true);
  }
  await Future.wait([
    ref.read(publicResourceListingDetailProvider.notifier).load(listingId),
    ref.read(publicResourceListingsProvider.notifier).load(force: true),
    ref
        .read(messagesInboxProvider.notifier)
        .load(expectedProfileId, refresh: true),
  ]);
}

ResourceRequestFailureKind mapResourceRequestFailure(Object error) {
  if (error is ResourceRequestIdentityChangedException) {
    return ResourceRequestFailureKind.forbidden;
  }
  if (error is ResourceRequestNotFoundException) {
    return ResourceRequestFailureKind.notFound;
  }
  if (error is FormatException || error is TypeError || error is StateError) {
    return ResourceRequestFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ResourceRequestFailureKind.invalidInput,
      'PT422' => ResourceRequestFailureKind.profilePhotoRequired,
      '42501' => ResourceRequestFailureKind.forbidden,
      '55000' => ResourceRequestFailureKind.listingUnavailable,
      'P0002' => ResourceRequestFailureKind.notFound,
      'PT409' => ResourceRequestFailureKind.interactionUnavailable,
      _ => ResourceRequestFailureKind.unavailable,
    };
  }
  return ResourceRequestFailureKind.unavailable;
}

class ResourceRequestIdentityChangedException implements Exception {
  const ResourceRequestIdentityChangedException();
}

class ResourceRequestNotFoundException implements Exception {
  const ResourceRequestNotFoundException();
}
