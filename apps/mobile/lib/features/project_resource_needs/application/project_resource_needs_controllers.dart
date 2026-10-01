import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/project_resource_needs_gateway.dart';
import '../domain/project_resource_need_models.dart';

enum ProjectResourceNeedsFailureKind {
  invalidInput,
  forbidden,
  conflict,
  notFound,
  unavailable,
}

enum PublicProjectResourceNeedsPhase { idle, loading, ready, failure }

class PublicProjectResourceNeedsState {
  const PublicProjectResourceNeedsState({
    this.phase = PublicProjectResourceNeedsPhase.idle,
    this.projectId,
    this.items = const [],
    this.failure,
  });

  final PublicProjectResourceNeedsPhase phase;
  final String? projectId;
  final List<PublicProjectResourceNeed> items;
  final ProjectResourceNeedsFailureKind? failure;
}

class PublicProjectResourceNeedsController
    extends Notifier<PublicProjectResourceNeedsState> {
  PublicProjectResourceNeedsController(this.projectId);

  final String projectId;
  var _revision = 0;

  @override
  PublicProjectResourceNeedsState build() {
    ref.onDispose(() => _revision++);
    return PublicProjectResourceNeedsState(projectId: projectId);
  }

  Future<bool> load() async {
    final revision = ++_revision;
    state = PublicProjectResourceNeedsState(
      phase: PublicProjectResourceNeedsPhase.loading,
      projectId: projectId,
      items: state.items,
    );
    try {
      final items = await ref
          .read(projectResourceNeedsGatewayProvider)
          .listPublic(projectId);
      if (!_isCurrent(revision)) return false;
      state = PublicProjectResourceNeedsState(
        phase: PublicProjectResourceNeedsPhase.ready,
        projectId: projectId,
        items: List.unmodifiable(items),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      state = PublicProjectResourceNeedsState(
        phase: PublicProjectResourceNeedsPhase.failure,
        projectId: projectId,
        items: state.items,
        failure: mapProjectResourceNeedsFailure(error),
      );
      return false;
    }
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;
}

final publicProjectResourceNeedsProvider =
    NotifierProvider.family<
      PublicProjectResourceNeedsController,
      PublicProjectResourceNeedsState,
      String
    >(PublicProjectResourceNeedsController.new);

enum OwnProjectResourceNeedsPhase {
  idle,
  loading,
  ready,
  creating,
  updating,
  closing,
  failure,
}

class OwnProjectResourceNeedsState {
  const OwnProjectResourceNeedsState({
    this.phase = OwnProjectResourceNeedsPhase.idle,
    this.expectedCreatorProfileId,
    this.projectId,
    this.items = const [],
    this.actionTargetId,
    this.failure,
  });

  final OwnProjectResourceNeedsPhase phase;
  final String? expectedCreatorProfileId;
  final String? projectId;
  final List<ProjectResourceNeed> items;
  final String? actionTargetId;
  final ProjectResourceNeedsFailureKind? failure;

  bool get isBusy => switch (phase) {
    OwnProjectResourceNeedsPhase.loading ||
    OwnProjectResourceNeedsPhase.creating ||
    OwnProjectResourceNeedsPhase.updating ||
    OwnProjectResourceNeedsPhase.closing => true,
    _ => false,
  };
}

class OwnProjectResourceNeedsController
    extends Notifier<OwnProjectResourceNeedsState> {
  OwnProjectResourceNeedsController(this.projectId);

  final String projectId;
  var _revision = 0;

  @override
  OwnProjectResourceNeedsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = OwnProjectResourceNeedsState(projectId: projectId);
    });
    ref.onDispose(() => _revision++);
    return OwnProjectResourceNeedsState(projectId: projectId);
  }

  Future<bool> load(String expectedCreatorProfileId) async {
    final revision = ++_revision;
    final preserve = state.expectedCreatorProfileId == expectedCreatorProfileId;
    state = OwnProjectResourceNeedsState(
      phase: OwnProjectResourceNeedsPhase.loading,
      expectedCreatorProfileId: expectedCreatorProfileId,
      projectId: projectId,
      items: preserve ? state.items : const [],
    );
    try {
      _requireReadyIdentity(expectedCreatorProfileId);
      final items = await _fetch(expectedCreatorProfileId);
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      state = OwnProjectResourceNeedsState(
        phase: OwnProjectResourceNeedsPhase.ready,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: projectId,
        items: items,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      state = OwnProjectResourceNeedsState(
        phase: OwnProjectResourceNeedsPhase.failure,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: projectId,
        items: state.items,
        failure: mapProjectResourceNeedsFailure(error),
      );
      return false;
    }
  }

  Future<bool> create({
    required String expectedCreatorProfileId,
    required ProjectResourceNeedInput input,
  }) => _mutate(
    phase: OwnProjectResourceNeedsPhase.creating,
    expectedCreatorProfileId: expectedCreatorProfileId,
    input: input,
    command: (gateway) => gateway.create(
      expectedCreatorProfileId: expectedCreatorProfileId,
      projectId: projectId,
      title: input.title.trim(),
      details: _optional(input.details),
    ),
  );

  Future<bool> update({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required ProjectResourceNeedInput input,
  }) => _mutate(
    phase: OwnProjectResourceNeedsPhase.updating,
    expectedCreatorProfileId: expectedCreatorProfileId,
    targetId: resourceNeedId,
    input: input,
    command: (gateway) => gateway.update(
      expectedCreatorProfileId: expectedCreatorProfileId,
      resourceNeedId: resourceNeedId,
      title: input.title.trim(),
      details: _optional(input.details),
    ),
  );

  Future<bool> close({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
  }) => _mutate(
    phase: OwnProjectResourceNeedsPhase.closing,
    expectedCreatorProfileId: expectedCreatorProfileId,
    targetId: resourceNeedId,
    command: (gateway) => gateway.close(
      expectedCreatorProfileId: expectedCreatorProfileId,
      resourceNeedId: resourceNeedId,
    ),
  );

  Future<bool> _mutate({
    required OwnProjectResourceNeedsPhase phase,
    required String expectedCreatorProfileId,
    required Future<void> Function(ProjectResourceNeedsGateway gateway) command,
    String? targetId,
    ProjectResourceNeedInput? input,
  }) async {
    if (state.isBusy) return false;
    if (input != null && !input.isValid) {
      state = OwnProjectResourceNeedsState(
        phase: OwnProjectResourceNeedsPhase.failure,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: projectId,
        items: state.items,
        actionTargetId: targetId,
        failure: ProjectResourceNeedsFailureKind.invalidInput,
      );
      return false;
    }
    final revision = ++_revision;
    state = OwnProjectResourceNeedsState(
      phase: phase,
      expectedCreatorProfileId: expectedCreatorProfileId,
      projectId: projectId,
      items: state.items,
      actionTargetId: targetId,
    );
    try {
      _requireReadyIdentity(expectedCreatorProfileId);
      await command(ref.read(projectResourceNeedsGatewayProvider));
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      final items = await _fetch(expectedCreatorProfileId);
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      state = OwnProjectResourceNeedsState(
        phase: OwnProjectResourceNeedsPhase.ready,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: projectId,
        items: items,
      );
      await ref
          .read(publicProjectResourceNeedsProvider(projectId).notifier)
          .load();
      return _isCurrent(revision, expectedCreatorProfileId);
    } catch (error) {
      if (!_isCurrent(revision, expectedCreatorProfileId)) return false;
      state = OwnProjectResourceNeedsState(
        phase: OwnProjectResourceNeedsPhase.failure,
        expectedCreatorProfileId: expectedCreatorProfileId,
        projectId: projectId,
        items: state.items,
        actionTargetId: targetId,
        failure: mapProjectResourceNeedsFailure(error),
      );
      return false;
    }
  }

  Future<List<ProjectResourceNeed>> _fetch(
    String expectedCreatorProfileId,
  ) async {
    final items = await ref
        .read(projectResourceNeedsGatewayProvider)
        .listOwn(
          expectedCreatorProfileId: expectedCreatorProfileId,
          projectId: projectId,
        );
    return List.unmodifiable(items);
  }

  bool _isCurrent(int revision, String expectedCreatorProfileId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == expectedCreatorProfileId;

  void _requireReadyIdentity(String expectedCreatorProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedCreatorProfileId) {
      throw const ProjectResourceNeedsIdentityChangedException();
    }
  }

  String? _optional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

final ownProjectResourceNeedsProvider =
    NotifierProvider.family<
      OwnProjectResourceNeedsController,
      OwnProjectResourceNeedsState,
      String
    >(OwnProjectResourceNeedsController.new);

ProjectResourceNeedsFailureKind mapProjectResourceNeedsFailure(Object error) {
  if (error is ProjectResourceNeedsIdentityChangedException) {
    return ProjectResourceNeedsFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ProjectResourceNeedsFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectResourceNeedsFailureKind.invalidInput,
      '42501' => ProjectResourceNeedsFailureKind.forbidden,
      '55000' => ProjectResourceNeedsFailureKind.conflict,
      'P0002' => ProjectResourceNeedsFailureKind.notFound,
      _ => ProjectResourceNeedsFailureKind.unavailable,
    };
  }
  return ProjectResourceNeedsFailureKind.unavailable;
}

class ProjectResourceNeedsIdentityChangedException implements Exception {
  const ProjectResourceNeedsIdentityChangedException();
}
