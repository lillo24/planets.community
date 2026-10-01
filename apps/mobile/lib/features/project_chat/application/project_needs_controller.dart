import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/project_needs_gateway.dart';
import '../domain/project_chat_models.dart';
import '../domain/project_needs_models.dart';
import 'project_chat_refresh.dart';

enum ProjectNeedsPhase { idle, loading, ready, failure }

enum ProjectNeedsFailureKind {
  invalidInput,
  forbidden,
  lifecycleEnded,
  notFound,
  unavailable,
}

enum ProjectNeedsActionKind { claim, markFound, markNeededAgain }

enum ProjectNeedsNotice { coveredElsewhere, requirementChanged }

class ProjectNeedsActionTarget {
  const ProjectNeedsActionTarget({
    required this.kind,
    required this.id,
    required this.action,
  });

  final ProjectRequirementKind kind;
  final String id;
  final ProjectNeedsActionKind action;

  String get canonicalKey => '${kind.wireValue}:$id';
}

class ProjectNeedsState {
  const ProjectNeedsState({
    this.expectedProfileId,
    this.projectId,
    this.chatId,
    this.viewerRole,
    this.coveragePhase = ProjectNeedsPhase.idle,
    this.requirements = const [],
    this.attentionPhase = ProjectNeedsPhase.idle,
    this.attention,
    this.actionTarget,
    this.failure,
    this.notice,
    this.isDrawerOpen = false,
    this.contentRevision = 0,
    this.attentionPulseRevision = 0,
  });

  final String? expectedProfileId;
  final String? projectId;
  final String? chatId;
  final ProjectChatViewerRole? viewerRole;
  final ProjectNeedsPhase coveragePhase;
  final List<ProjectLiveRequirement> requirements;
  final ProjectNeedsPhase attentionPhase;
  final ProjectRequirementAttention? attention;
  final ProjectNeedsActionTarget? actionTarget;
  final ProjectNeedsFailureKind? failure;
  final ProjectNeedsNotice? notice;
  final bool isDrawerOpen;

  /// Advances only after a canonical coverage payload is successfully loaded.
  final int contentRevision;

  /// Advances only for a false-to-true unseen-attention transition.
  final int attentionPulseRevision;

  bool get hasTarget =>
      expectedProfileId != null && projectId != null && chatId != null;
  bool get hasUnseenAttention => attention?.hasUnseenResurfacedNeed == true;
  int get uncoveredCount =>
      requirements.where((requirement) => !requirement.isCovered).length;
  List<ProjectLiveRequirement> get uncoveredRequirements => List.unmodifiable(
    requirements.where((requirement) => !requirement.isCovered),
  );
  List<ProjectLiveRequirement> get manuallyCoveredRequirements =>
      List.unmodifiable(
        requirements.where((requirement) => requirement.isManuallyCovered),
      );

  ProjectNeedsState copyWith({
    String? expectedProfileId,
    String? projectId,
    String? chatId,
    ProjectChatViewerRole? viewerRole,
    ProjectNeedsPhase? coveragePhase,
    List<ProjectLiveRequirement>? requirements,
    ProjectNeedsPhase? attentionPhase,
    Object? attention = _keep,
    Object? actionTarget = _keep,
    Object? failure = _keep,
    Object? notice = _keep,
    bool? isDrawerOpen,
    int? contentRevision,
    int? attentionPulseRevision,
  }) => ProjectNeedsState(
    expectedProfileId: expectedProfileId ?? this.expectedProfileId,
    projectId: projectId ?? this.projectId,
    chatId: chatId ?? this.chatId,
    viewerRole: viewerRole ?? this.viewerRole,
    coveragePhase: coveragePhase ?? this.coveragePhase,
    requirements: requirements ?? this.requirements,
    attentionPhase: attentionPhase ?? this.attentionPhase,
    attention: identical(attention, _keep)
        ? this.attention
        : attention as ProjectRequirementAttention?,
    actionTarget: identical(actionTarget, _keep)
        ? this.actionTarget
        : actionTarget as ProjectNeedsActionTarget?,
    failure: identical(failure, _keep)
        ? this.failure
        : failure as ProjectNeedsFailureKind?,
    notice: identical(notice, _keep)
        ? this.notice
        : notice as ProjectNeedsNotice?,
    isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
    contentRevision: contentRevision ?? this.contentRevision,
    attentionPulseRevision:
        attentionPulseRevision ?? this.attentionPulseRevision,
  );

  static const _keep = Object();
}

class ProjectNeedsController extends Notifier<ProjectNeedsState> {
  var _revision = 0;
  var _refreshing = false;
  var _refreshPending = false;

  @override
  ProjectNeedsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _refreshing = false;
      _refreshPending = false;
      state = const ProjectNeedsState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectNeedsState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String projectId,
    required String chatId,
    required ProjectChatViewerRole viewerRole,
  }) async {
    if (viewerRole == ProjectChatViewerRole.formerMember) {
      clear();
      return false;
    }
    final sameTarget = _matchesIds(expectedProfileId, projectId, chatId);
    final revision = ++_revision;
    state = ProjectNeedsState(
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      chatId: chatId,
      viewerRole: viewerRole,
      coveragePhase: ProjectNeedsPhase.loading,
      requirements: sameTarget ? state.requirements : const [],
      attentionPhase: ProjectNeedsPhase.loading,
      attention: sameTarget ? state.attention : null,
      isDrawerOpen: sameTarget && state.isDrawerOpen,
      contentRevision: sameTarget ? state.contentRevision : 0,
      attentionPulseRevision: sameTarget ? state.attentionPulseRevision : 0,
    );
    final results = await Future.wait([
      _loadCoverage(revision),
      _loadAttention(revision, allowPulse: false),
    ]);
    return results.every((result) => result);
  }

  Future<bool> refresh({bool allowAttentionPulse = false}) async {
    if (!state.hasTarget || !_isReadyIdentity(state.expectedProfileId!)) {
      return false;
    }
    if (_refreshing) {
      _refreshPending = true;
      return false;
    }
    _refreshing = true;
    final revision = _revision;
    try {
      final results = await Future.wait([
        _loadCoverage(revision),
        _loadAttention(revision, allowPulse: allowAttentionPulse),
      ]);
      return results.every((result) => result);
    } finally {
      _refreshing = false;
      if (_refreshPending && ref.mounted && state.hasTarget) {
        _refreshPending = false;
        unawaited(refresh(allowAttentionPulse: true));
      }
    }
  }

  void handleRequirementSignal() {
    if (!state.hasTarget) return;
    unawaited(refresh(allowAttentionPulse: true));
  }

  void handleAppResumed() {
    if (state.hasTarget) unawaited(refresh(allowAttentionPulse: true));
  }

  Future<bool> openDrawerAndRefresh() async {
    if (!state.hasTarget) return false;
    state = state.copyWith(isDrawerOpen: true, failure: null, notice: null);
    return refresh(allowAttentionPulse: true);
  }

  void closeDrawer() {
    if (state.isDrawerOpen) state = state.copyWith(isDrawerOpen: false);
  }

  Future<bool> claim(ProjectLiveRequirement requirement) async {
    if (!_canAct(ProjectChatViewerRole.currentMember) ||
        requirement.isCovered) {
      return false;
    }
    return _runAction(
      requirement,
      ProjectNeedsActionKind.claim,
      () => ref
          .read(projectNeedsGatewayProvider)
          .claimRequirement(
            expectedParticipantProfileId: state.expectedProfileId!,
            projectId: state.projectId!,
            kind: requirement.kind,
            id: requirement.id,
          ),
    );
  }

  Future<bool> setManualCoverage(
    ProjectLiveRequirement requirement,
    bool isCovered,
  ) async {
    if (!_canManage ||
        (isCovered ? requirement.isCovered : !requirement.isManuallyCovered)) {
      return false;
    }
    return _runAction(
      requirement,
      isCovered
          ? ProjectNeedsActionKind.markFound
          : ProjectNeedsActionKind.markNeededAgain,
      () => ref
          .read(projectNeedsGatewayProvider)
          .setManualCoverage(
            expectedManagerProfileId: state.expectedProfileId!,
            projectId: state.projectId!,
            kind: requirement.kind,
            id: requirement.id,
            isCovered: isCovered,
          ),
    );
  }

  Future<bool> acknowledgeVisible(String throughSystemEventId) async {
    final attention = state.attention;
    if (!state.isDrawerOpen ||
        state.coveragePhase != ProjectNeedsPhase.ready ||
        state.attentionPhase != ProjectNeedsPhase.ready ||
        attention?.hasUnseenResurfacedNeed != true ||
        attention?.latestUnseenEventId != throughSystemEventId ||
        !_isReadyIdentity(state.expectedProfileId!)) {
      return false;
    }
    final revision = _revision;
    try {
      await ref
          .read(projectNeedsGatewayProvider)
          .acknowledgeAttention(
            expectedProfileId: state.expectedProfileId!,
            projectId: state.projectId!,
            throughSystemEventId: throughSystemEventId,
          );
      if (!_isCurrent(revision)) return false;
      await _loadAttention(revision, allowPulse: true);
      return true;
    } catch (error) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
          attentionPhase: ProjectNeedsPhase.failure,
          failure: mapProjectNeedsFailure(error),
        );
      }
      return false;
    }
  }

  void clear() {
    _revision++;
    _refreshing = false;
    _refreshPending = false;
    state = const ProjectNeedsState();
  }

  Future<bool> _loadCoverage(int revision) async {
    final profileId = state.expectedProfileId!;
    final projectId = state.projectId!;
    state = state.copyWith(coveragePhase: ProjectNeedsPhase.loading);
    try {
      _requireReadyIdentity(profileId);
      final requirements = await ref
          .read(projectNeedsGatewayProvider)
          .listCoverage(expectedProfileId: profileId, projectId: projectId);
      if (!_isCurrent(revision)) return false;
      final seen = <String>{};
      if (requirements.any(
        (requirement) => !seen.add(requirement.canonicalKey),
      )) {
        throw const FormatException('Project Needs contained duplicates.');
      }
      state = state.copyWith(
        coveragePhase: ProjectNeedsPhase.ready,
        requirements: List.unmodifiable(requirements),
        failure: state.attentionPhase == ProjectNeedsPhase.failure
            ? state.failure
            : null,
        contentRevision: state.contentRevision + 1,
      );
      return true;
    } catch (error) {
      if (_isCurrent(revision)) {
        final failure = mapProjectNeedsFailure(error);
        state = state.copyWith(
          coveragePhase: ProjectNeedsPhase.failure,
          requirements:
              failure == ProjectNeedsFailureKind.forbidden ||
                  failure == ProjectNeedsFailureKind.lifecycleEnded ||
                  failure == ProjectNeedsFailureKind.notFound
              ? const []
              : state.requirements,
          failure: failure,
        );
        if (failure == ProjectNeedsFailureKind.forbidden) {
          ref.read(projectChatRefreshProvider.notifier).notifyChanged();
        }
      }
      return false;
    }
  }

  Future<bool> _loadAttention(int revision, {required bool allowPulse}) async {
    final profileId = state.expectedProfileId!;
    final projectId = state.projectId!;
    final wasUnseen = state.attention?.hasUnseenResurfacedNeed;
    state = state.copyWith(attentionPhase: ProjectNeedsPhase.loading);
    try {
      _requireReadyIdentity(profileId);
      final attention = await ref
          .read(projectNeedsGatewayProvider)
          .getAttention(expectedProfileId: profileId, projectId: projectId);
      if (!_isCurrent(revision)) return false;
      if (attention.chatId != state.chatId) {
        throw const FormatException('Project Needs attention mismatched chat.');
      }
      final shouldPulse =
          allowPulse && wasUnseen == false && attention.hasUnseenResurfacedNeed;
      state = state.copyWith(
        attentionPhase: ProjectNeedsPhase.ready,
        attention: attention,
        failure: state.coveragePhase == ProjectNeedsPhase.failure
            ? state.failure
            : null,
        attentionPulseRevision: shouldPulse
            ? state.attentionPulseRevision + 1
            : state.attentionPulseRevision,
      );
      return true;
    } catch (error) {
      if (_isCurrent(revision)) {
        final failure = mapProjectNeedsFailure(error);
        state = state.copyWith(
          attentionPhase: ProjectNeedsPhase.failure,
          attention:
              failure == ProjectNeedsFailureKind.forbidden ||
                  failure == ProjectNeedsFailureKind.lifecycleEnded ||
                  failure == ProjectNeedsFailureKind.notFound
              ? null
              : state.attention,
          failure: failure,
        );
        if (failure == ProjectNeedsFailureKind.forbidden) {
          ref.read(projectChatRefreshProvider.notifier).notifyChanged();
        }
      }
      return false;
    }
  }

  Future<bool> _runAction(
    ProjectLiveRequirement requirement,
    ProjectNeedsActionKind action,
    Future<void> Function() mutation,
  ) async {
    if (state.actionTarget != null) return false;
    final revision = _revision;
    state = state.copyWith(
      actionTarget: ProjectNeedsActionTarget(
        kind: requirement.kind,
        id: requirement.id,
        action: action,
      ),
      failure: null,
      notice: null,
    );
    try {
      _requireReadyIdentity(state.expectedProfileId!);
      await mutation();
      if (!_isCurrent(revision)) return false;
      state = state.copyWith(actionTarget: null);
      await refresh(allowAttentionPulse: true);
      if (_isCurrent(revision)) {
        ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      }
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      final code = error is PostgrestException ? error.code : null;
      final failure = mapProjectNeedsFailure(error);
      final terminal =
          failure == ProjectNeedsFailureKind.forbidden ||
          failure == ProjectNeedsFailureKind.lifecycleEnded ||
          failure == ProjectNeedsFailureKind.notFound;
      state = state.copyWith(
        actionTarget: null,
        coveragePhase: terminal
            ? ProjectNeedsPhase.failure
            : state.coveragePhase,
        requirements: terminal ? const [] : state.requirements,
        attentionPhase: terminal
            ? ProjectNeedsPhase.failure
            : state.attentionPhase,
        attention: terminal ? null : state.attention,
        failure: failure,
        notice: code == 'PT409'
            ? ProjectNeedsNotice.coveredElsewhere
            : code == '22023'
            ? ProjectNeedsNotice.requirementChanged
            : null,
      );
      if (code == 'PT409' || code == '22023') {
        await refresh(allowAttentionPulse: true);
        if (_isCurrent(revision)) {
          state = state.copyWith(
            notice: code == 'PT409'
                ? ProjectNeedsNotice.coveredElsewhere
                : ProjectNeedsNotice.requirementChanged,
          );
        }
      } else if (failure == ProjectNeedsFailureKind.forbidden) {
        ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      }
      return false;
    }
  }

  bool get _canManage =>
      state.viewerRole == ProjectChatViewerRole.creator ||
      state.viewerRole == ProjectChatViewerRole.delegate;

  bool _canAct(ProjectChatViewerRole role) =>
      state.hasTarget &&
      state.viewerRole == role &&
      state.actionTarget == null &&
      _isReadyIdentity(state.expectedProfileId!);

  bool _matchesIds(String profileId, String projectId, String chatId) =>
      state.expectedProfileId == profileId &&
      state.projectId == projectId &&
      state.chatId == chatId;

  bool _isCurrent(int revision) =>
      ref.mounted &&
      revision == _revision &&
      state.hasTarget &&
      _isReadyIdentity(state.expectedProfileId!);

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  void _requireReadyIdentity(String profileId) {
    if (!_isReadyIdentity(profileId)) {
      throw const ProjectNeedsIdentityChangedException();
    }
  }
}

final projectNeedsProvider =
    NotifierProvider<ProjectNeedsController, ProjectNeedsState>(
      ProjectNeedsController.new,
    );

ProjectNeedsFailureKind mapProjectNeedsFailure(Object error) {
  if (error is ProjectNeedsIdentityChangedException) {
    return ProjectNeedsFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ProjectNeedsFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectNeedsFailureKind.invalidInput,
      '42501' => ProjectNeedsFailureKind.forbidden,
      '55000' => ProjectNeedsFailureKind.lifecycleEnded,
      'P0002' => ProjectNeedsFailureKind.notFound,
      _ => ProjectNeedsFailureKind.unavailable,
    };
  }
  return ProjectNeedsFailureKind.unavailable;
}

class ProjectNeedsIdentityChangedException implements Exception {
  const ProjectNeedsIdentityChangedException();
}
