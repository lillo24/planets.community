import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../participation/domain/participation_models.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../data/project_request_chat_gateway.dart';
import '../domain/project_request_chat_models.dart';

const projectRequestChatHistoryPageSize = 30;

enum ProjectRequestChatFailureKind {
  invalidInput,
  forbidden,
  conflict,
  notFound,
  sendUnavailable,
  unavailable,
}

enum ProjectRequestChatPhase { idle, loading, ready, failure }

class ProjectRequestChatState {
  const ProjectRequestChatState({
    this.phase = ProjectRequestChatPhase.idle,
    this.expectedProfileId,
    this.requestId,
    this.summary,
    this.items = const [],
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.failure,
    this.hasConnectionIssue = false,
  });

  final ProjectRequestChatPhase phase;
  final String? expectedProfileId;
  final String? requestId;
  final ProjectRequestChatSummary? summary;
  final List<ProjectRequestChatFeedItem> items;
  final bool hasMoreOlder;
  final bool isLoadingOlder;
  final bool isSending;
  final ProjectRequestChatFailureKind? failure;
  final bool hasConnectionIssue;
}

class ProjectRequestChatController extends Notifier<ProjectRequestChatState> {
  ProjectRequestChatSignalSubscription? _subscription;
  String? _subscriptionProfileId;
  String? _subscriptionChatId;
  Timer? _reconcileTimer;
  var _revision = 0;
  var _subscriptionRevision = 0;
  var _signalsEnabled = false;
  var _isReconciling = false;
  var _needsReconcile = false;
  var _wasDisconnected = false;

  @override
  ProjectRequestChatState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _signalsEnabled = false;
      _reconcileTimer?.cancel();
      _closeSubscription();
      state = const ProjectRequestChatState();
    });
    ref.onDispose(() {
      _revision++;
      _reconcileTimer?.cancel();
      _closeSubscription();
    });
    return const ProjectRequestChatState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final revision = ++_revision;
    final sameTarget = _sameTarget(expectedProfileId, requestId);
    final previousSummary = sameTarget ? state.summary : null;
    state = ProjectRequestChatState(
      phase: ProjectRequestChatPhase.loading,
      expectedProfileId: expectedProfileId,
      requestId: requestId,
      summary: sameTarget ? state.summary : null,
      items: sameTarget ? state.items : const [],
      hasMoreOlder: sameTarget && state.hasMoreOlder,
      hasConnectionIssue: sameTarget && state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final gateway = ref.read(projectRequestChatGatewayProvider);
      final summary = await gateway.getChat(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      );
      _validateSummary(summary, requestId);
      final page = await gateway.listItems(
        expectedProfileId: expectedProfileId,
        chatId: summary.chatId,
        limit: projectRequestChatHistoryPageSize,
      );
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _validateItems(page.items, summary);
      state = ProjectRequestChatState(
        phase: ProjectRequestChatPhase.ready,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        summary: summary,
        items: List.unmodifiable(page.items.reversed),
        hasMoreOlder: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscription(expectedProfileId, summary);
      _reconcileCounterpartyPhoto(previousSummary, summary);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      state = ProjectRequestChatState(
        phase: ProjectRequestChatPhase.failure,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        summary: state.summary,
        items: state.items,
        hasMoreOlder: state.hasMoreOlder,
        failure: mapProjectRequestChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    }
  }

  Future<bool> refresh({
    required String expectedProfileId,
    required String requestId,
  }) async {
    if (!_sameTarget(expectedProfileId, requestId) ||
        state.phase != ProjectRequestChatPhase.ready) {
      return load(expectedProfileId: expectedProfileId, requestId: requestId);
    }
    if (_isReconciling || state.isLoadingOlder || state.isSending) {
      _scheduleReconcile(expectedProfileId, requestId);
      return false;
    }
    _isReconciling = true;
    final revision = _revision;
    final previousSummary = state.summary;
    try {
      _requireReadyIdentity(expectedProfileId);
      final gateway = ref.read(projectRequestChatGatewayProvider);
      final summary = await gateway.getChat(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      );
      _validateSummary(summary, requestId);
      final page = await gateway.listItems(
        expectedProfileId: expectedProfileId,
        chatId: summary.chatId,
        limit: projectRequestChatHistoryPageSize,
      );
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _validateItems(page.items, summary);
      state = ProjectRequestChatState(
        phase: ProjectRequestChatPhase.ready,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        summary: summary,
        items: List.unmodifiable(_mergeItems(state.items, page.items)),
        hasMoreOlder: state.hasMoreOlder,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscription(expectedProfileId, summary);
      _reconcileCounterpartyPhoto(previousSummary, summary);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _setFailure(mapProjectRequestChatFailure(error));
      return false;
    } finally {
      _isReconciling = false;
      _drainReconcile(expectedProfileId, requestId);
    }
  }

  Future<bool> loadOlder({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final summary = state.summary;
    if (!_sameTarget(expectedProfileId, requestId) ||
        state.phase != ProjectRequestChatPhase.ready ||
        state.isLoadingOlder ||
        !state.hasMoreOlder ||
        state.items.isEmpty ||
        summary == null) {
      return false;
    }
    final revision = _revision;
    final existing = state.items;
    final oldest = existing.first;
    _replace(isLoadingOlder: true, clearFailure: true);
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(projectRequestChatGatewayProvider)
          .listItems(
            expectedProfileId: expectedProfileId,
            chatId: summary.chatId,
            limit: projectRequestChatHistoryPageSize,
            cursor: ProjectRequestChatFeedCursor(
              createdAt: oldest.createdAt,
              itemKind: oldest.itemKind,
              itemId: oldest.itemId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _validateItems(page.items, summary);
      state = ProjectRequestChatState(
        phase: ProjectRequestChatPhase.ready,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        summary: summary,
        items: List.unmodifiable(_mergeItems(existing, page.items)),
        hasMoreOlder: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _replace(failure: mapProjectRequestChatFailure(error));
      return false;
    } finally {
      if (_isCurrent(revision, expectedProfileId, requestId) &&
          state.isLoadingOlder) {
        _replace(isLoadingOlder: false);
      }
      _drainReconcile(expectedProfileId, requestId);
    }
  }

  Future<bool> send({
    required String expectedProfileId,
    required String requestId,
    required String body,
  }) async {
    final canonicalBody = body.trim();
    final summary = state.summary;
    if (!_sameTarget(expectedProfileId, requestId) ||
        state.phase != ProjectRequestChatPhase.ready ||
        state.isSending ||
        summary?.hasSendEntitlement != true) {
      return false;
    }
    if (canonicalBody.isEmpty ||
        canonicalBody.length > projectRequestChatMessageMaxLength) {
      _setFailure(ProjectRequestChatFailureKind.invalidInput);
      return false;
    }
    final revision = _revision;
    _replace(isSending: true, clearFailure: true);
    try {
      _requireReadyIdentity(expectedProfileId);
      final sent = await ref
          .read(projectRequestChatGatewayProvider)
          .sendMessage(
            expectedProfileId: expectedProfileId,
            requestId: requestId,
            chatId: summary!.chatId,
            body: canonicalBody,
          );
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      _validateItems([sent], summary);
      _replace(items: List.unmodifiable(_mergeItems(state.items, [sent])));
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      if (error is PostgrestException && error.code == 'PT409') {
        await _recoverConflict(expectedProfileId, requestId, revision);
      } else {
        final failure = mapProjectRequestChatFailure(error);
        _setFailure(
          failure == ProjectRequestChatFailureKind.unavailable
              ? ProjectRequestChatFailureKind.sendUnavailable
              : failure,
        );
      }
      return false;
    } finally {
      if (_isCurrent(revision, expectedProfileId, requestId) &&
          state.isSending) {
        _replace(isSending: false);
      }
      _drainReconcile(expectedProfileId, requestId);
    }
  }

  void startSignals(String expectedProfileId, String requestId) {
    if (!_sameTarget(expectedProfileId, requestId)) return;
    _signalsEnabled = true;
    final summary = state.summary;
    if (summary != null) _syncSubscription(expectedProfileId, summary);
  }

  void stopSignals() {
    _revision++;
    _signalsEnabled = false;
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _needsReconcile = false;
    _closeSubscription();
  }

  void handleAppResumed(String expectedProfileId, String requestId) {
    if (_sameTarget(expectedProfileId, requestId)) {
      _scheduleReconcile(expectedProfileId, requestId);
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    }
  }

  Future<void> _recoverConflict(
    String expectedProfileId,
    String requestId,
    int revision,
  ) async {
    final previousSummary = state.summary;
    try {
      final gateway = ref.read(projectRequestChatGatewayProvider);
      final summary = await gateway.getChat(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      );
      final page = await gateway.listItems(
        expectedProfileId: expectedProfileId,
        chatId: summary.chatId,
        limit: projectRequestChatHistoryPageSize,
      );
      if (!_isCurrent(revision, expectedProfileId, requestId)) return;
      _validateSummary(summary, requestId);
      _validateItems(page.items, summary);
      state = ProjectRequestChatState(
        phase: ProjectRequestChatPhase.ready,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        summary: summary,
        items: List.unmodifiable(_mergeItems(state.items, page.items)),
        hasMoreOlder: state.hasMoreOlder,
        isSending: true,
        failure: ProjectRequestChatFailureKind.conflict,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscription(expectedProfileId, summary);
      _reconcileCounterpartyPhoto(previousSummary, summary);
    } catch (_) {
      if (_isCurrent(revision, expectedProfileId, requestId)) {
        _setFailure(ProjectRequestChatFailureKind.conflict);
      }
    }
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    ref.read(projectChatRefreshProvider.notifier).notifyChanged();
  }

  void _syncSubscription(
    String expectedProfileId,
    ProjectRequestChatSummary summary,
  ) {
    final shouldSubscribe = _signalsEnabled && summary.hasSendEntitlement;
    final matches =
        _subscription != null &&
        _subscriptionProfileId == expectedProfileId &&
        _subscriptionChatId == summary.chatId;
    if (!shouldSubscribe) {
      _closeSubscription();
      return;
    }
    if (matches) return;
    _closeSubscription();
    _subscriptionProfileId = expectedProfileId;
    _subscriptionChatId = summary.chatId;
    final subscriptionRevision = ++_subscriptionRevision;
    try {
      _subscription = ref
          .read(projectRequestChatGatewayProvider)
          .subscribeToSignals(
            expectedProfileId: expectedProfileId,
            chatId: summary.chatId,
            onSignal: (signal) {
              if (_isAttached(
                    expectedProfileId,
                    summary.requestId,
                    summary.chatId,
                    subscriptionRevision,
                  ) &&
                  signal.requestId == summary.requestId) {
                ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
                _scheduleReconcile(expectedProfileId, summary.requestId);
              }
            },
            onStatus: (status) => _handleStatus(
              expectedProfileId,
              summary.requestId,
              summary.chatId,
              subscriptionRevision,
              status,
            ),
          );
    } catch (_) {
      _wasDisconnected = true;
      _replace(hasConnectionIssue: true);
    }
  }

  void _handleStatus(
    String expectedProfileId,
    String requestId,
    String chatId,
    int subscriptionRevision,
    ProjectRequestChatConnectionStatus status,
  ) {
    if (!_isAttached(
      expectedProfileId,
      requestId,
      chatId,
      subscriptionRevision,
    )) {
      return;
    }
    if (status == ProjectRequestChatConnectionStatus.disconnected) {
      _wasDisconnected = true;
      _replace(hasConnectionIssue: true);
      return;
    }
    final catchUp = _wasDisconnected;
    _wasDisconnected = false;
    _replace(hasConnectionIssue: false);
    if (catchUp) _scheduleReconcile(expectedProfileId, requestId);
  }

  void _scheduleReconcile(String expectedProfileId, String requestId) {
    if (!_signalsEnabled || !_sameTarget(expectedProfileId, requestId)) return;
    _needsReconcile = true;
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_signalsEnabled || !_sameTarget(expectedProfileId, requestId)) {
        return;
      }
      if (_isReconciling || state.isLoadingOlder || state.isSending) {
        _scheduleReconcile(expectedProfileId, requestId);
        return;
      }
      _needsReconcile = false;
      unawaited(
        refresh(expectedProfileId: expectedProfileId, requestId: requestId),
      );
    });
  }

  void _drainReconcile(String expectedProfileId, String requestId) {
    if (_signalsEnabled && _needsReconcile) {
      _scheduleReconcile(expectedProfileId, requestId);
    }
  }

  void _reconcileCounterpartyPhoto(
    ProjectRequestChatSummary? previous,
    ProjectRequestChatSummary current,
  ) {
    final photos = ref.read(visibleProfilePhotoProvider.notifier);
    if (previous != null &&
        previous.counterpartyProfileId != current.counterpartyProfileId) {
      photos.invalidate(previous.counterpartyProfileId);
    }
    if (current.requestStatus == JoinRequestStatus.rejected ||
        current.requestStatus == JoinRequestStatus.withdrawn) {
      photos.invalidate(current.counterpartyProfileId);
      unawaited(photos.load(current.counterpartyProfileId, force: true));
      return;
    }
    unawaited(
      photos.load(current.counterpartyProfileId, force: previous != null),
    );
  }

  void _replace({
    List<ProjectRequestChatFeedItem>? items,
    bool? isLoadingOlder,
    bool? isSending,
    ProjectRequestChatFailureKind? failure,
    bool clearFailure = false,
    bool? hasConnectionIssue,
  }) {
    state = ProjectRequestChatState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      requestId: state.requestId,
      summary: state.summary,
      items: items ?? state.items,
      hasMoreOlder: state.hasMoreOlder,
      isLoadingOlder: isLoadingOlder ?? state.isLoadingOlder,
      isSending: isSending ?? state.isSending,
      failure: clearFailure ? null : failure ?? state.failure,
      hasConnectionIssue: hasConnectionIssue ?? state.hasConnectionIssue,
    );
  }

  void _setFailure(ProjectRequestChatFailureKind failure) {
    _replace(failure: failure);
  }

  void _closeSubscription() {
    final subscription = _subscription;
    _subscriptionRevision++;
    _subscription = null;
    _subscriptionProfileId = null;
    _subscriptionChatId = null;
    _wasDisconnected = false;
    if (subscription != null) unawaited(subscription.close());
  }

  bool _isAttached(
    String expectedProfileId,
    String requestId,
    String chatId,
    int subscriptionRevision,
  ) =>
      _signalsEnabled &&
      subscriptionRevision == _subscriptionRevision &&
      _subscriptionProfileId == expectedProfileId &&
      _subscriptionChatId == chatId &&
      _sameTarget(expectedProfileId, requestId);

  List<ProjectRequestChatFeedItem> _mergeItems(
    Iterable<ProjectRequestChatFeedItem> existing,
    Iterable<ProjectRequestChatFeedItem> incoming,
  ) {
    final byKey = <String, ProjectRequestChatFeedItem>{
      for (final item in existing) item.canonicalKey: item,
      for (final item in incoming) item.canonicalKey: item,
    };
    final values = byKey.values.toList();
    values.sort((left, right) {
      final time = left.createdAt.compareTo(right.createdAt);
      if (time != 0) return time;
      final kind = left.itemKind.canonicalOrder.compareTo(
        right.itemKind.canonicalOrder,
      );
      return kind != 0 ? kind : left.itemId.compareTo(right.itemId);
    });
    return values;
  }

  void _validateSummary(ProjectRequestChatSummary summary, String requestId) {
    if (summary.requestId != requestId) {
      throw const FormatException(
        'Participation-request chat summary mismatched.',
      );
    }
  }

  void _validateItems(
    Iterable<ProjectRequestChatFeedItem> items,
    ProjectRequestChatSummary summary,
  ) {
    if (items.any(
      (item) =>
          item.chatId != summary.chatId || item.requestId != summary.requestId,
    )) {
      throw const FormatException(
        'Participation-request chat history mismatched.',
      );
    }
  }

  bool _sameTarget(String expectedProfileId, String requestId) =>
      ref.mounted &&
      state.expectedProfileId == expectedProfileId &&
      state.requestId == requestId &&
      _isReadyIdentity(expectedProfileId);

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  bool _isCurrent(int revision, String profileId, String requestId) =>
      revision == _revision && _sameTarget(profileId, requestId);

  void _requireReadyIdentity(String profileId) {
    if (!_isReadyIdentity(profileId)) {
      throw const ProjectRequestChatIdentityChangedException();
    }
  }
}

final projectRequestChatProvider =
    NotifierProvider<ProjectRequestChatController, ProjectRequestChatState>(
      ProjectRequestChatController.new,
    );

ProjectRequestChatFailureKind mapProjectRequestChatFailure(Object error) {
  if (error is ProjectRequestChatIdentityChangedException) {
    return ProjectRequestChatFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ProjectRequestChatFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectRequestChatFailureKind.invalidInput,
      '42501' => ProjectRequestChatFailureKind.forbidden,
      'P0002' => ProjectRequestChatFailureKind.notFound,
      'PT409' => ProjectRequestChatFailureKind.conflict,
      _ => ProjectRequestChatFailureKind.unavailable,
    };
  }
  return ProjectRequestChatFailureKind.unavailable;
}

class ProjectRequestChatIdentityChangedException implements Exception {
  const ProjectRequestChatIdentityChangedException();
}
