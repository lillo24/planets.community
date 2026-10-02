import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/project_resource_matches_gateway.dart';
import '../domain/project_resource_match_models.dart';

enum ProjectResourceMatchesPhase { idle, loading, ready, loadingMore, failure }

enum ProjectResourceMatchesFailureKind {
  invalidInput,
  forbidden,
  projectStateUnavailable,
  notFound,
  unavailable,
}

class ProjectResourceMatchesState {
  const ProjectResourceMatchesState({
    required this.projectId,
    required this.resourceNeedId,
    this.phase = ProjectResourceMatchesPhase.idle,
    this.expectedCreatorProfileId,
    this.locationScope = ProjectResourceLocationScope.anywhere,
    this.listingMode = ProjectResourceListingModeFilter.all,
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.failure,
  });

  final ProjectResourceMatchesPhase phase;
  final String? expectedCreatorProfileId;
  final String projectId;
  final String resourceNeedId;
  final ProjectResourceLocationScope locationScope;
  final ProjectResourceListingModeFilter listingMode;
  final List<ProjectResourceListingMatch> items;
  final ProjectResourceMatchCursor? cursor;
  final bool hasMore;
  final ProjectResourceMatchesFailureKind? failure;

  bool get isBusy =>
      phase == ProjectResourceMatchesPhase.loading ||
      phase == ProjectResourceMatchesPhase.loadingMore;

  bool get hasFilters =>
      locationScope != ProjectResourceLocationScope.anywhere ||
      listingMode != ProjectResourceListingModeFilter.all;
}

class ProjectResourceMatchesKey {
  const ProjectResourceMatchesKey({
    required this.projectId,
    required this.resourceNeedId,
  });

  final String projectId;
  final String resourceNeedId;

  @override
  bool operator ==(Object other) =>
      other is ProjectResourceMatchesKey &&
      other.projectId == projectId &&
      other.resourceNeedId == resourceNeedId;

  @override
  int get hashCode => Object.hash(projectId, resourceNeedId);
}

class ProjectResourceMatchesController
    extends Notifier<ProjectResourceMatchesState> {
  ProjectResourceMatchesController(this.key);

  final ProjectResourceMatchesKey key;
  var _revision = 0;

  @override
  ProjectResourceMatchesState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _revision++;
        state = _initialState();
      },
    );
    ref.onDispose(() => _revision++);
    return _initialState();
  }

  Future<bool> load(String expectedCreatorProfileId) =>
      _fetch(expectedCreatorProfileId: expectedCreatorProfileId, reset: true);

  Future<bool> refresh(String expectedCreatorProfileId) => _fetch(
    expectedCreatorProfileId: expectedCreatorProfileId,
    reset: true,
    preserveItems: true,
  );

  Future<bool> loadMore(String expectedCreatorProfileId) async {
    if (state.isBusy || !state.hasMore || state.items.isEmpty) return false;
    return _fetch(
      expectedCreatorProfileId: expectedCreatorProfileId,
      reset: false,
    );
  }

  Future<bool> setLocationScope({
    required String expectedCreatorProfileId,
    required ProjectResourceLocationScope locationScope,
  }) async {
    if (state.locationScope == locationScope &&
        state.expectedCreatorProfileId == expectedCreatorProfileId) {
      return true;
    }
    _revision++;
    state = ProjectResourceMatchesState(
      projectId: key.projectId,
      resourceNeedId: key.resourceNeedId,
      expectedCreatorProfileId: expectedCreatorProfileId,
      locationScope: locationScope,
      listingMode: state.listingMode,
    );
    return load(expectedCreatorProfileId);
  }

  Future<bool> setListingMode({
    required String expectedCreatorProfileId,
    required ProjectResourceListingModeFilter listingMode,
  }) async {
    if (state.listingMode == listingMode &&
        state.expectedCreatorProfileId == expectedCreatorProfileId) {
      return true;
    }
    _revision++;
    state = ProjectResourceMatchesState(
      projectId: key.projectId,
      resourceNeedId: key.resourceNeedId,
      expectedCreatorProfileId: expectedCreatorProfileId,
      locationScope: state.locationScope,
      listingMode: listingMode,
    );
    return load(expectedCreatorProfileId);
  }

  Future<bool> _fetch({
    required String expectedCreatorProfileId,
    required bool reset,
    bool preserveItems = false,
  }) async {
    if (state.isBusy && !preserveItems) return false;
    final revision = ++_revision;
    final locationScope = state.locationScope;
    final listingMode = state.listingMode;
    final previousItems = state.items;
    final previousCursor = state.cursor;
    state = ProjectResourceMatchesState(
      phase: reset
          ? ProjectResourceMatchesPhase.loading
          : ProjectResourceMatchesPhase.loadingMore,
      expectedCreatorProfileId: expectedCreatorProfileId,
      projectId: key.projectId,
      resourceNeedId: key.resourceNeedId,
      locationScope: locationScope,
      listingMode: listingMode,
      items: reset && !preserveItems ? const [] : previousItems,
      cursor: reset ? null : previousCursor,
      hasMore: reset ? true : state.hasMore,
    );

    try {
      _requireReadyIdentity(expectedCreatorProfileId);
      final page = await ref
          .read(projectResourceMatchesGatewayProvider)
          .listMatches(
            expectedCreatorProfileId: expectedCreatorProfileId,
            resourceNeedId: key.resourceNeedId,
            locationScope: locationScope,
            listingMode: listingMode,
            limit: projectResourceMatchPageSize,
            cursor: reset ? null : previousCursor,
          );
      if (!_isCurrent(
        revision,
        expectedCreatorProfileId,
        locationScope,
        listingMode,
      )) {
        return false;
      }
      final items = reset
          ? page.items
          : _appendDeduplicated(previousItems, page.items);
      state = ProjectResourceMatchesState(
        phase: ProjectResourceMatchesPhase.ready,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: key.projectId,
        resourceNeedId: key.resourceNeedId,
        locationScope: locationScope,
        listingMode: listingMode,
        items: List.unmodifiable(items),
        cursor: page.cursor ?? (reset ? null : previousCursor),
        hasMore: page.hasMore,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(
        revision,
        expectedCreatorProfileId,
        locationScope,
        listingMode,
      )) {
        return false;
      }
      final failure = mapProjectResourceMatchesFailure(error);
      final clearPrivateOrStale =
          failure == ProjectResourceMatchesFailureKind.forbidden ||
          failure ==
              ProjectResourceMatchesFailureKind.projectStateUnavailable ||
          failure == ProjectResourceMatchesFailureKind.notFound;
      final safeItems = clearPrivateOrStale
          ? const <ProjectResourceListingMatch>[]
          : (reset && !preserveItems
                ? const <ProjectResourceListingMatch>[]
                : previousItems);
      state = ProjectResourceMatchesState(
        phase: ProjectResourceMatchesPhase.failure,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: key.projectId,
        resourceNeedId: key.resourceNeedId,
        locationScope: locationScope,
        listingMode: listingMode,
        items: safeItems,
        cursor: safeItems.isEmpty ? null : previousCursor,
        hasMore: safeItems.isEmpty ? false : state.hasMore,
        failure: failure,
      );
      return false;
    }
  }

  List<ProjectResourceListingMatch> _appendDeduplicated(
    List<ProjectResourceListingMatch> current,
    List<ProjectResourceListingMatch> page,
  ) {
    final seen = current.map((item) => item.listingId).toSet();
    return [
      ...current,
      for (final item in page)
        if (seen.add(item.listingId)) item,
    ];
  }

  bool _isCurrent(
    int revision,
    String expectedCreatorProfileId,
    ProjectResourceLocationScope locationScope,
    ProjectResourceListingModeFilter listingMode,
  ) =>
      ref.mounted &&
      revision == _revision &&
      state.expectedCreatorProfileId == expectedCreatorProfileId &&
      state.locationScope == locationScope &&
      state.listingMode == listingMode &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == expectedCreatorProfileId;

  void _requireReadyIdentity(String expectedCreatorProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedCreatorProfileId) {
      throw const ProjectResourceMatchesIdentityChangedException();
    }
  }

  ProjectResourceMatchesState _initialState() => ProjectResourceMatchesState(
    projectId: key.projectId,
    resourceNeedId: key.resourceNeedId,
  );
}

final projectResourceMatchesProvider =
    NotifierProvider.family<
      ProjectResourceMatchesController,
      ProjectResourceMatchesState,
      ProjectResourceMatchesKey
    >(ProjectResourceMatchesController.new);

ProjectResourceMatchesFailureKind mapProjectResourceMatchesFailure(
  Object error,
) {
  if (error is ProjectResourceMatchesIdentityChangedException) {
    return ProjectResourceMatchesFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ProjectResourceMatchesFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectResourceMatchesFailureKind.invalidInput,
      '42501' => ProjectResourceMatchesFailureKind.forbidden,
      '55000' => ProjectResourceMatchesFailureKind.projectStateUnavailable,
      'P0002' => ProjectResourceMatchesFailureKind.notFound,
      _ => ProjectResourceMatchesFailureKind.unavailable,
    };
  }
  return ProjectResourceMatchesFailureKind.unavailable;
}

class ProjectResourceMatchesIdentityChangedException implements Exception {
  const ProjectResourceMatchesIdentityChangedException();
}
