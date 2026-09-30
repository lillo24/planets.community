import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../data/project_chat_gateway.dart';
import '../domain/project_chat_models.dart';
import 'project_chat_refresh.dart';
import 'project_needs_controller.dart';

const projectChatListPageSize = 20;
const projectChatHistoryPageSize = 30;
// The backend accepts at most 50 rows. Gateways request one sentinel row to
// determine whether another keyset page exists, leaving 49 usable rows here.
const _projectChatLookupPageSize = 49;

enum ProjectChatFailureKind { invalidInput, forbidden, notFound, unavailable }

enum ProjectChatListPhase { idle, loading, ready, loadingMore, failure }

class ProjectChatListState {
  const ProjectChatListState({
    this.phase = ProjectChatListPhase.idle,
    this.expectedProfileId,
    this.items = const [],
    this.hasMore = false,
    this.failure,
    this.hasConnectionIssue = false,
  });

  final ProjectChatListPhase phase;
  final String? expectedProfileId;
  final List<ProjectChatSummary> items;
  final bool hasMore;
  final ProjectChatFailureKind? failure;
  final bool hasConnectionIssue;

  bool get isBusy =>
      phase == ProjectChatListPhase.loading ||
      phase == ProjectChatListPhase.loadingMore;
}

class ProjectChatListController extends Notifier<ProjectChatListState> {
  final Map<String, ProjectChatSignalSubscription> _subscriptions = {};
  final Set<String> _disconnectedChats = {};
  Timer? _refreshTimer;
  var _revision = 0;
  var _signalsEnabled = false;

  @override
  ProjectChatListState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _signalsEnabled = false;
      _refreshTimer?.cancel();
      _closeAllSubscriptions();
      state = const ProjectChatListState();
    });
    ref.listen(projectChatRefreshProvider, (_, _) {
      final profileId = state.expectedProfileId;
      if (profileId != null && _isReadyIdentity(profileId)) {
        unawaited(load(profileId, refresh: true));
      }
    });
    ref.onDispose(() {
      _revision++;
      _refreshTimer?.cancel();
      _closeAllSubscriptions();
    });
    return const ProjectChatListState();
  }

  Future<bool> load(String expectedProfileId, {bool refresh = false}) async {
    if (state.isBusy && !refresh) return false;
    final revision = ++_revision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = ProjectChatListState(
      phase: ProjectChatListPhase.loading,
      expectedProfileId: expectedProfileId,
      items: preserve ? state.items : const [],
      hasMore: preserve && state.hasMore,
      hasConnectionIssue: preserve && state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(projectChatGatewayProvider)
          .listOwnProjectChats(
            expectedProfileId: expectedProfileId,
            limit: projectChatListPageSize,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ProjectChatListState(
        phase: ProjectChatListPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(_dedupeSummaries(page.items)),
        hasMore: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscriptions(expectedProfileId);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ProjectChatListState(
        phase: ProjectChatListPhase.failure,
        expectedProfileId: expectedProfileId,
        items: state.items,
        hasMore: state.hasMore,
        failure: mapProjectChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    }
  }

  Future<bool> loadMore(String expectedProfileId) async {
    if (state.isBusy ||
        state.expectedProfileId != expectedProfileId ||
        !state.hasMore ||
        state.items.isEmpty) {
      return false;
    }
    final revision = ++_revision;
    final existing = state.items;
    final last = existing.last;
    state = ProjectChatListState(
      phase: ProjectChatListPhase.loadingMore,
      expectedProfileId: expectedProfileId,
      items: existing,
      hasMore: true,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(projectChatGatewayProvider)
          .listOwnProjectChats(
            expectedProfileId: expectedProfileId,
            limit: projectChatListPageSize,
            cursor: ProjectChatListCursor(
              activityAt: last.activityAt,
              chatId: last.chatId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ProjectChatListState(
        phase: ProjectChatListPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(
          _dedupeSummaries([...existing, ...page.items]),
        ),
        hasMore: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscriptions(expectedProfileId);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ProjectChatListState(
        phase: ProjectChatListPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: true,
        failure: mapProjectChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    }
  }

  void startSignals(String expectedProfileId) {
    if (!_isReadyIdentity(expectedProfileId)) return;
    _signalsEnabled = true;
    _syncSubscriptions(expectedProfileId);
  }

  void stopSignals() {
    _signalsEnabled = false;
    _refreshTimer?.cancel();
    _closeAllSubscriptions();
    if (ref.mounted && state.hasConnectionIssue) {
      state = ProjectChatListState(
        phase: state.phase,
        expectedProfileId: state.expectedProfileId,
        items: state.items,
        hasMore: state.hasMore,
        failure: state.failure,
      );
    }
  }

  List<ProjectChatSummary> _dedupeSummaries(
    Iterable<ProjectChatSummary> values,
  ) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (seen.add(value.chatId)) value,
    ];
  }

  void _syncSubscriptions(String expectedProfileId) {
    if (!_signalsEnabled ||
        state.expectedProfileId != expectedProfileId ||
        !_isReadyIdentity(expectedProfileId)) {
      return;
    }
    final desired = {
      for (final item in state.items)
        if (item.hasCurrentEntitlement) item.chatId,
    };
    for (final chatId in _subscriptions.keys.toList()) {
      if (!desired.contains(chatId)) {
        final subscription = _subscriptions.remove(chatId);
        _disconnectedChats.remove(chatId);
        if (subscription != null) unawaited(subscription.close());
      }
    }
    for (final chatId in desired) {
      if (_subscriptions.containsKey(chatId)) continue;
      _subscriptions[chatId] = ref
          .read(projectChatGatewayProvider)
          .subscribeToProjectChatSignals(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            onSignal: (signal) {
              if (signal is! ProjectChatRequirementCoveredSignal) {
                _scheduleRefresh(expectedProfileId);
              }
            },
            onStatus: (status) =>
                _handleStatus(expectedProfileId, chatId, status),
          );
    }
  }

  void _handleStatus(
    String expectedProfileId,
    String chatId,
    ProjectChatConnectionStatus status,
  ) {
    if (!ref.mounted ||
        !_signalsEnabled ||
        state.expectedProfileId != expectedProfileId ||
        !_isReadyIdentity(expectedProfileId) ||
        !_subscriptions.containsKey(chatId)) {
      return;
    }
    if (status == ProjectChatConnectionStatus.disconnected) {
      _disconnectedChats.add(chatId);
      state = ProjectChatListState(
        phase: state.phase,
        expectedProfileId: state.expectedProfileId,
        items: state.items,
        hasMore: state.hasMore,
        failure: state.failure,
        hasConnectionIssue: true,
      );
      return;
    }
    final shouldCatchUp = _disconnectedChats.remove(chatId);
    state = ProjectChatListState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      items: state.items,
      hasMore: state.hasMore,
      failure: state.failure,
      hasConnectionIssue: _disconnectedChats.isNotEmpty,
    );
    if (shouldCatchUp) _scheduleRefresh(expectedProfileId);
  }

  void _scheduleRefresh(String expectedProfileId) {
    if (!_signalsEnabled || !_isReadyIdentity(expectedProfileId)) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (ref.mounted &&
          _signalsEnabled &&
          _isReadyIdentity(expectedProfileId)) {
        unawaited(load(expectedProfileId, refresh: true));
      }
    });
  }

  void _closeAllSubscriptions() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.close());
    }
    _subscriptions.clear();
    _disconnectedChats.clear();
  }

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted && revision == _revision && _isReadyIdentity(profileId);

  void _requireReadyIdentity(String profileId) {
    if (!_isReadyIdentity(profileId)) {
      throw const ProjectChatIdentityChangedException();
    }
  }
}

final projectChatListProvider =
    NotifierProvider<ProjectChatListController, ProjectChatListState>(
      ProjectChatListController.new,
    );

enum ProjectChatDetailPhase { idle, loading, ready, failure }

class ProjectChatDetailState {
  const ProjectChatDetailState({
    this.phase = ProjectChatDetailPhase.idle,
    this.expectedProfileId,
    this.chatId,
    this.summary,
    this.feedItems = const [],
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.failure,
    this.hasConnectionIssue = false,
  });

  final ProjectChatDetailPhase phase;
  final String? expectedProfileId;
  final String? chatId;
  final ProjectChatSummary? summary;

  /// Natural UI order: oldest first.
  final List<ProjectChatFeedItem> feedItems;
  final bool hasMoreOlder;
  final bool isLoadingOlder;
  final bool isSending;
  final ProjectChatFailureKind? failure;
  final bool hasConnectionIssue;

  bool get belongsToCurrentTarget =>
      expectedProfileId != null && chatId != null;
}

class ProjectChatDetailController extends Notifier<ProjectChatDetailState> {
  ProjectChatSignalSubscription? _subscription;
  String? _subscriptionProfileId;
  String? _subscriptionChatId;
  var _revision = 0;
  var _isReconciling = false;
  var _reconcilePending = false;
  var _wasDisconnected = false;
  var _signalsEnabled = false;

  @override
  ProjectChatDetailState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _signalsEnabled = false;
      _reconcilePending = false;
      _isReconciling = false;
      _closeSubscription();
      state = const ProjectChatDetailState();
    });
    ref.listen(projectChatRefreshProvider, (_, _) {
      final profileId = state.expectedProfileId;
      final chatId = state.chatId;
      if (profileId != null && chatId != null && _isReadyIdentity(profileId)) {
        unawaited(refresh(expectedProfileId: profileId, chatId: chatId));
      }
    });
    ref.onDispose(() {
      _revision++;
      _closeSubscription();
    });
    return const ProjectChatDetailState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String chatId,
  }) async {
    final revision = ++_revision;
    final sameTarget =
        state.expectedProfileId == expectedProfileId && state.chatId == chatId;
    if (!sameTarget) _closeSubscription();
    state = ProjectChatDetailState(
      phase: ProjectChatDetailPhase.loading,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      summary: sameTarget ? state.summary : null,
      feedItems: sameTarget ? state.feedItems : const [],
      hasMoreOlder: sameTarget && state.hasMoreOlder,
      hasConnectionIssue: sameTarget && state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final summary = await _findSummary(expectedProfileId, chatId);
      final page = await ref
          .read(projectChatGatewayProvider)
          .listOwnProjectChatFeed(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            limit: projectChatHistoryPageSize,
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateFeedChat(page.items, chatId);
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        feedItems: List.unmodifiable(page.items.reversed),
        hasMoreOlder: page.hasMore,
      );
      if (!summary.hasCurrentEntitlement) {
        ref
            .read(participantMeetingDetailsProvider.notifier)
            .clearProject(summary.projectId);
        ref.read(projectNeedsProvider.notifier).clear();
      } else {
        unawaited(
          ref
              .read(projectNeedsProvider.notifier)
              .load(
                expectedProfileId: expectedProfileId,
                projectId: summary.projectId,
                chatId: chatId,
                viewerRole: summary.viewerRole,
              ),
        );
      }
      _syncSubscription(expectedProfileId, summary);
      _drainPendingReconciliation();
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.failure,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        feedItems: state.feedItems,
        hasMoreOlder: state.hasMoreOlder,
        failure: mapProjectChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    }
  }

  Future<bool> refresh({
    required String expectedProfileId,
    required String chatId,
  }) async {
    if (state.phase != ProjectChatDetailPhase.ready ||
        state.expectedProfileId != expectedProfileId ||
        state.chatId != chatId) {
      return load(expectedProfileId: expectedProfileId, chatId: chatId);
    }
    if (_isReconciling || state.isLoadingOlder || state.isSending) {
      _reconcilePending = true;
      return false;
    }
    _isReconciling = true;
    final revision = _revision;
    try {
      _requireReadyIdentity(expectedProfileId);
      final summary = await _findSummary(expectedProfileId, chatId);
      final page = await ref
          .read(projectChatGatewayProvider)
          .listOwnProjectChatFeed(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            limit: projectChatHistoryPageSize,
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateFeedChat(page.items, chatId);
      final becameReadOnly =
          state.summary?.hasCurrentEntitlement == true &&
          !summary.hasCurrentEntitlement;
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        feedItems: List.unmodifiable(
          _mergeFeedItems(state.feedItems, page.items),
        ),
        hasMoreOlder: state.hasMoreOlder,
        failure: null,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      if (becameReadOnly) {
        ref
            .read(participantMeetingDetailsProvider.notifier)
            .clearProject(summary.projectId);
        ref.read(projectNeedsProvider.notifier).clear();
      } else if (summary.hasCurrentEntitlement) {
        final needs = ref.read(projectNeedsProvider);
        if (needs.expectedProfileId != expectedProfileId ||
            needs.projectId != summary.projectId ||
            needs.chatId != chatId) {
          unawaited(
            ref
                .read(projectNeedsProvider.notifier)
                .load(
                  expectedProfileId: expectedProfileId,
                  projectId: summary.projectId,
                  chatId: chatId,
                  viewerRole: summary.viewerRole,
                ),
          );
        }
      }
      _syncSubscription(expectedProfileId, summary);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        feedItems: state.feedItems,
        hasMoreOlder: state.hasMoreOlder,
        failure: mapProjectChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    } finally {
      _isReconciling = false;
      _drainPendingReconciliation();
    }
  }

  Future<bool> loadOlder({
    required String expectedProfileId,
    required String chatId,
  }) async {
    if (state.phase != ProjectChatDetailPhase.ready ||
        state.expectedProfileId != expectedProfileId ||
        state.chatId != chatId ||
        state.isLoadingOlder ||
        !state.hasMoreOlder ||
        state.feedItems.isEmpty) {
      return false;
    }
    final revision = _revision;
    final existing = state.feedItems;
    final oldest = existing.first;
    state = ProjectChatDetailState(
      phase: ProjectChatDetailPhase.ready,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      summary: state.summary,
      feedItems: existing,
      hasMoreOlder: true,
      isLoadingOlder: true,
      failure: state.failure,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(projectChatGatewayProvider)
          .listOwnProjectChatFeed(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            limit: projectChatHistoryPageSize,
            cursor: ProjectChatFeedCursor(
              createdAt: oldest.createdAt,
              itemKind: oldest.itemKind,
              itemId: oldest.itemId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateFeedChat(page.items, chatId);
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        feedItems: List.unmodifiable(_mergeFeedItems(existing, page.items)),
        hasMoreOlder: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        feedItems: existing,
        hasMoreOlder: true,
        failure: mapProjectChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    } finally {
      if (_isCurrent(revision, expectedProfileId, chatId) &&
          state.isLoadingOlder) {
        state = ProjectChatDetailState(
          phase: state.phase,
          expectedProfileId: state.expectedProfileId,
          chatId: state.chatId,
          summary: state.summary,
          feedItems: state.feedItems,
          hasMoreOlder: state.hasMoreOlder,
          failure: state.failure,
          hasConnectionIssue: state.hasConnectionIssue,
        );
      }
      _drainPendingReconciliation();
    }
  }

  Future<bool> send({
    required String expectedProfileId,
    required String chatId,
    required String body,
  }) async {
    final canonicalBody = body.trim();
    final summary = state.summary;
    if (state.phase != ProjectChatDetailPhase.ready ||
        state.expectedProfileId != expectedProfileId ||
        state.chatId != chatId ||
        state.isSending ||
        summary?.hasCurrentEntitlement != true) {
      return false;
    }
    if (canonicalBody.isEmpty ||
        canonicalBody.length > projectChatMessageMaxLength) {
      state = ProjectChatDetailState(
        phase: state.phase,
        expectedProfileId: state.expectedProfileId,
        chatId: state.chatId,
        summary: state.summary,
        feedItems: state.feedItems,
        hasMoreOlder: state.hasMoreOlder,
        failure: ProjectChatFailureKind.invalidInput,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    }
    final revision = _revision;
    state = ProjectChatDetailState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      chatId: state.chatId,
      summary: summary,
      feedItems: state.feedItems,
      hasMoreOlder: state.hasMoreOlder,
      isSending: true,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final sent = await ref
          .read(projectChatGatewayProvider)
          .sendProjectChatMessage(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            body: canonicalBody,
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      if (sent.chatId != chatId || sent.senderProfileId != expectedProfileId) {
        throw const FormatException('Sent Project chat message mismatched.');
      }
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        feedItems: List.unmodifiable(_mergeFeedItems(state.feedItems, [sent])),
        hasMoreOlder: state.hasMoreOlder,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      _drainPendingReconciliation();
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      state = ProjectChatDetailState(
        phase: ProjectChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        feedItems: state.feedItems,
        hasMoreOlder: state.hasMoreOlder,
        failure: mapProjectChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    } finally {
      _drainPendingReconciliation();
    }
  }

  void handleAppResumed(String expectedProfileId, String chatId) {
    if (_isReadyIdentity(expectedProfileId) &&
        state.expectedProfileId == expectedProfileId &&
        state.chatId == chatId) {
      unawaited(refresh(expectedProfileId: expectedProfileId, chatId: chatId));
      if (state.summary?.hasCurrentEntitlement == true) {
        ref.read(projectNeedsProvider.notifier).handleAppResumed();
      }
    }
  }

  void startSignals(String expectedProfileId, String chatId) {
    if (!_matchesTarget(expectedProfileId, chatId)) return;
    _signalsEnabled = true;
    final summary = state.summary;
    if (summary != null) _syncSubscription(expectedProfileId, summary);
  }

  void stopSignals() {
    _signalsEnabled = false;
    _closeSubscription();
    if (ref.mounted && state.hasConnectionIssue) {
      _setConnectionIssue(
        state.expectedProfileId ?? '',
        state.chatId ?? '',
        false,
      );
    }
  }

  Future<ProjectChatSummary> _findSummary(
    String expectedProfileId,
    String chatId,
  ) async {
    ProjectChatListCursor? cursor;
    while (true) {
      final page = await ref
          .read(projectChatGatewayProvider)
          .listOwnProjectChats(
            expectedProfileId: expectedProfileId,
            limit: _projectChatLookupPageSize,
            cursor: cursor,
          );
      for (final item in page.items) {
        if (item.chatId == chatId) return item;
      }
      if (!page.hasMore) throw const ProjectChatNotFoundException();
      if (page.items.isEmpty) {
        throw const FormatException('Project chat lookup did not advance.');
      }
      final last = page.items.last;
      cursor = ProjectChatListCursor(
        activityAt: last.activityAt,
        chatId: last.chatId,
      );
    }
  }

  void _syncSubscription(String expectedProfileId, ProjectChatSummary summary) {
    final shouldSubscribe = _signalsEnabled && summary.hasCurrentEntitlement;
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
    try {
      _subscription = ref
          .read(projectChatGatewayProvider)
          .subscribeToProjectChatSignals(
            expectedProfileId: expectedProfileId,
            chatId: summary.chatId,
            onSignal: (signal) =>
                _handleSignal(expectedProfileId, summary.chatId, signal),
            onStatus: (status) =>
                _handleStatus(expectedProfileId, summary.chatId, status),
          );
    } catch (_) {
      _wasDisconnected = true;
      _setConnectionIssue(expectedProfileId, summary.chatId, true);
    }
  }

  void _handleSignal(
    String expectedProfileId,
    String chatId,
    ProjectChatSignal signal,
  ) {
    if (!_matchesTarget(expectedProfileId, chatId) || signal.chatId != chatId) {
      return;
    }
    switch (signal) {
      case ProjectChatMessageSentSignal():
        ref.read(projectChatRefreshProvider.notifier).notifyChanged();
      case ProjectChatRequirementNeededAgainSignal():
        ref.read(projectChatRefreshProvider.notifier).notifyChanged();
        ref.read(projectNeedsProvider.notifier).handleRequirementSignal();
      case ProjectChatRequirementCoveredSignal():
        ref.read(projectNeedsProvider.notifier).handleRequirementSignal();
    }
  }

  void _handleStatus(
    String expectedProfileId,
    String chatId,
    ProjectChatConnectionStatus status,
  ) {
    if (!_matchesTarget(expectedProfileId, chatId)) return;
    if (status == ProjectChatConnectionStatus.disconnected) {
      _wasDisconnected = true;
      _setConnectionIssue(expectedProfileId, chatId, true);
      return;
    }
    final shouldCatchUp = _wasDisconnected;
    _wasDisconnected = false;
    _setConnectionIssue(expectedProfileId, chatId, false);
    if (shouldCatchUp) {
      unawaited(refresh(expectedProfileId: expectedProfileId, chatId: chatId));
    }
  }

  void _setConnectionIssue(
    String expectedProfileId,
    String chatId,
    bool value,
  ) {
    if (!_matchesTarget(expectedProfileId, chatId) ||
        state.hasConnectionIssue == value) {
      return;
    }
    state = ProjectChatDetailState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      chatId: state.chatId,
      summary: state.summary,
      feedItems: state.feedItems,
      hasMoreOlder: state.hasMoreOlder,
      isLoadingOlder: state.isLoadingOlder,
      isSending: state.isSending,
      failure: state.failure,
      hasConnectionIssue: value,
    );
  }

  void _drainPendingReconciliation() {
    if (!_reconcilePending ||
        _isReconciling ||
        state.phase != ProjectChatDetailPhase.ready ||
        state.isLoadingOlder ||
        state.isSending) {
      return;
    }
    final profileId = state.expectedProfileId;
    final chatId = state.chatId;
    if (profileId == null || chatId == null) return;
    _reconcilePending = false;
    unawaited(refresh(expectedProfileId: profileId, chatId: chatId));
  }

  void _closeSubscription() {
    final subscription = _subscription;
    _subscription = null;
    _subscriptionProfileId = null;
    _subscriptionChatId = null;
    _wasDisconnected = false;
    if (subscription != null) unawaited(subscription.close());
  }

  List<ProjectChatFeedItem> _mergeFeedItems(
    Iterable<ProjectChatFeedItem> existing,
    Iterable<ProjectChatFeedItem> incoming,
  ) {
    final byId = <String, ProjectChatFeedItem>{
      for (final item in existing) item.canonicalKey: item,
      for (final item in incoming) item.canonicalKey: item,
    };
    final values = byId.values.toList();
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

  void _validateFeedChat(Iterable<ProjectChatFeedItem> items, String chatId) {
    if (items.any((item) => item.chatId != chatId)) {
      throw const FormatException('Project chat feed mismatched.');
    }
  }

  bool _matchesTarget(String expectedProfileId, String chatId) =>
      ref.mounted &&
      state.expectedProfileId == expectedProfileId &&
      state.chatId == chatId &&
      _isReadyIdentity(expectedProfileId);

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  bool _isCurrent(int revision, String profileId, String chatId) =>
      revision == _revision && _matchesTarget(profileId, chatId);

  void _requireReadyIdentity(String profileId) {
    if (!_isReadyIdentity(profileId)) {
      throw const ProjectChatIdentityChangedException();
    }
  }
}

final projectChatDetailProvider =
    NotifierProvider<ProjectChatDetailController, ProjectChatDetailState>(
      ProjectChatDetailController.new,
    );

ProjectChatFailureKind mapProjectChatFailure(Object error) {
  if (error is ProjectChatIdentityChangedException) {
    return ProjectChatFailureKind.forbidden;
  }
  if (error is ProjectChatNotFoundException) {
    return ProjectChatFailureKind.notFound;
  }
  if (error is FormatException || error is TypeError) {
    return ProjectChatFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectChatFailureKind.invalidInput,
      '42501' => ProjectChatFailureKind.forbidden,
      'P0002' => ProjectChatFailureKind.notFound,
      _ => ProjectChatFailureKind.unavailable,
    };
  }
  return ProjectChatFailureKind.unavailable;
}

class ProjectChatIdentityChangedException implements Exception {
  const ProjectChatIdentityChangedException();
}

class ProjectChatNotFoundException implements Exception {
  const ProjectChatNotFoundException();
}
