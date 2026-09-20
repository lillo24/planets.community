import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../resource_exchange/application/resource_exchange_refresh.dart';
import '../data/resource_chat_gateway.dart';
import '../domain/resource_chat_models.dart';
import 'resource_chat_refresh.dart';

const resourceChatHistoryPageSize = 30;

enum ResourceChatFailureKind {
  invalidInput,
  forbidden,
  notFound,
  conflict,
  sendUnavailable,
  unavailable,
}

enum ResourceChatDetailPhase { idle, loading, ready, failure }

class ResourceChatDetailState {
  const ResourceChatDetailState({
    this.phase = ResourceChatDetailPhase.idle,
    this.expectedProfileId,
    this.chatId,
    this.summary,
    this.messages = const [],
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.failure,
    this.hasConnectionIssue = false,
  });

  final ResourceChatDetailPhase phase;
  final String? expectedProfileId;
  final String? chatId;
  final ResourceChatSummary? summary;

  /// Natural UI order: oldest first.
  final List<ResourceChatMessage> messages;
  final bool hasMoreOlder;
  final bool isLoadingOlder;
  final bool isSending;
  final ResourceChatFailureKind? failure;
  final bool hasConnectionIssue;
}

class ResourceChatDetailController extends Notifier<ResourceChatDetailState> {
  ResourceChatSignalSubscription? _subscription;
  String? _subscriptionProfileId;
  String? _subscriptionChatId;
  Timer? _reconcileTimer;
  var _revision = 0;
  var _signalsEnabled = false;
  var _wasDisconnected = false;
  var _needsMessageReconcile = false;
  var _isReconciling = false;

  @override
  ResourceChatDetailState build() {
    ref.listen(resourceChatRefreshProvider, (_, _) {
      final profileId = state.expectedProfileId;
      final chatId = state.chatId;
      if (profileId != null &&
          chatId != null &&
          state.phase == ResourceChatDetailPhase.ready) {
        _scheduleReconcile(profileId, chatId, includeMessages: false);
      }
    });
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _signalsEnabled = false;
      _reconcileTimer?.cancel();
      _needsMessageReconcile = false;
      _isReconciling = false;
      _closeSubscription();
      state = const ResourceChatDetailState();
    });
    ref.onDispose(() {
      _revision++;
      _reconcileTimer?.cancel();
      _closeSubscription();
    });
    return const ResourceChatDetailState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String chatId,
  }) async {
    final revision = ++_revision;
    final sameTarget =
        state.expectedProfileId == expectedProfileId && state.chatId == chatId;
    if (!sameTarget) _closeSubscription();
    state = ResourceChatDetailState(
      phase: ResourceChatDetailPhase.loading,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      summary: sameTarget ? state.summary : null,
      messages: sameTarget ? state.messages : const [],
      hasMoreOlder: sameTarget && state.hasMoreOlder,
      hasConnectionIssue: sameTarget && state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final summary = await ref
          .read(resourceChatGatewayProvider)
          .getChat(expectedProfileId: expectedProfileId, chatId: chatId);
      _validateSummary(summary, chatId);
      final page = await ref
          .read(resourceChatGatewayProvider)
          .listMessages(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            limit: resourceChatHistoryPageSize,
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateMessages(page.items, chatId);
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        messages: List.unmodifiable(page.items.reversed),
        hasMoreOlder: page.hasMore,
      );
      _syncSubscription(expectedProfileId, summary);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.failure,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        messages: state.messages,
        hasMoreOlder: state.hasMoreOlder,
        failure: mapResourceChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    }
  }

  Future<bool> refresh({
    required String expectedProfileId,
    required String chatId,
  }) async {
    if (!_matchesTarget(expectedProfileId, chatId) ||
        state.phase != ResourceChatDetailPhase.ready) {
      return load(expectedProfileId: expectedProfileId, chatId: chatId);
    }
    if (_isReconciling || state.isLoadingOlder || state.isSending) {
      _scheduleReconcile(expectedProfileId, chatId, includeMessages: true);
      return false;
    }
    _isReconciling = true;
    final revision = _revision;
    try {
      final gateway = ref.read(resourceChatGatewayProvider);
      _requireReadyIdentity(expectedProfileId);
      final summary = await gateway.getChat(
        expectedProfileId: expectedProfileId,
        chatId: chatId,
      );
      _validateSummary(summary, chatId);
      final page = await gateway.listMessages(
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        limit: resourceChatHistoryPageSize,
      );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateMessages(page.items, chatId);
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        messages: List.unmodifiable(_mergeMessages(state.messages, page.items)),
        hasMoreOlder: state.hasMoreOlder,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscription(expectedProfileId, summary);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _setFailure(mapResourceChatFailure(error));
      return false;
    } finally {
      _isReconciling = false;
      _drainPendingReconcile(expectedProfileId, chatId);
    }
  }

  Future<bool> refreshSummary({
    required String expectedProfileId,
    required String chatId,
  }) async {
    if (!_matchesTarget(expectedProfileId, chatId) ||
        state.phase != ResourceChatDetailPhase.ready) {
      return false;
    }
    if (_isReconciling || state.isLoadingOlder || state.isSending) {
      _scheduleReconcile(expectedProfileId, chatId, includeMessages: false);
      return false;
    }
    _isReconciling = true;
    final revision = _revision;
    try {
      _requireReadyIdentity(expectedProfileId);
      final summary = await ref
          .read(resourceChatGatewayProvider)
          .getChat(expectedProfileId: expectedProfileId, chatId: chatId);
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateSummary(summary, chatId);
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        messages: state.messages,
        hasMoreOlder: state.hasMoreOlder,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscription(expectedProfileId, summary);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _setFailure(mapResourceChatFailure(error));
      return false;
    } finally {
      _isReconciling = false;
      _drainPendingReconcile(expectedProfileId, chatId);
    }
  }

  Future<bool> loadOlder({
    required String expectedProfileId,
    required String chatId,
  }) async {
    if (!_matchesTarget(expectedProfileId, chatId) ||
        state.phase != ResourceChatDetailPhase.ready ||
        state.isLoadingOlder ||
        !state.hasMoreOlder ||
        state.messages.isEmpty) {
      return false;
    }
    final revision = _revision;
    final existing = state.messages;
    final oldest = existing.first;
    state = ResourceChatDetailState(
      phase: state.phase,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      summary: state.summary,
      messages: existing,
      hasMoreOlder: true,
      isLoadingOlder: true,
      failure: state.failure,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(resourceChatGatewayProvider)
          .listMessages(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            limit: resourceChatHistoryPageSize,
            cursor: ResourceChatMessageCursor(
              createdAt: oldest.createdAt,
              messageId: oldest.messageId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      _validateMessages(page.items, chatId);
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        messages: List.unmodifiable(_mergeMessages(existing, page.items)),
        hasMoreOlder: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: state.summary,
        messages: existing,
        hasMoreOlder: true,
        failure: mapResourceChatFailure(error),
        hasConnectionIssue: state.hasConnectionIssue,
      );
      return false;
    } finally {
      if (_isCurrent(revision, expectedProfileId, chatId) &&
          state.isLoadingOlder) {
        state = ResourceChatDetailState(
          phase: state.phase,
          expectedProfileId: state.expectedProfileId,
          chatId: state.chatId,
          summary: state.summary,
          messages: state.messages,
          hasMoreOlder: state.hasMoreOlder,
          failure: state.failure,
          hasConnectionIssue: state.hasConnectionIssue,
        );
      }
      _drainPendingReconcile(expectedProfileId, chatId);
    }
  }

  Future<bool> send({
    required String expectedProfileId,
    required String chatId,
    required String body,
  }) async {
    final canonicalBody = body.trim();
    final summary = state.summary;
    if (!_matchesTarget(expectedProfileId, chatId) ||
        state.phase != ResourceChatDetailPhase.ready ||
        state.isSending ||
        summary?.hasSendEntitlement != true) {
      return false;
    }
    if (canonicalBody.isEmpty ||
        canonicalBody.length > resourceChatMessageMaxLength) {
      _setFailure(ResourceChatFailureKind.invalidInput);
      return false;
    }
    final revision = _revision;
    state = ResourceChatDetailState(
      phase: state.phase,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      summary: summary,
      messages: state.messages,
      hasMoreOlder: state.hasMoreOlder,
      isSending: true,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final sent = await ref
          .read(resourceChatGatewayProvider)
          .sendMessage(
            expectedProfileId: expectedProfileId,
            chatId: chatId,
            body: canonicalBody,
          );
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      if (sent.chatId != chatId || sent.senderProfileId != expectedProfileId) {
        throw const FormatException('Sent Resource chat message mismatched.');
      }
      state = ResourceChatDetailState(
        phase: ResourceChatDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        chatId: chatId,
        summary: summary,
        messages: List.unmodifiable(_mergeMessages(state.messages, [sent])),
        hasMoreOlder: state.hasMoreOlder,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, chatId)) return false;
      if (error is PostgrestException && error.code == 'PT409') {
        await _recoverSendConflict(expectedProfileId, chatId, revision);
      } else {
        final failure = mapResourceChatFailure(error);
        _setFailure(
          failure == ResourceChatFailureKind.unavailable
              ? ResourceChatFailureKind.sendUnavailable
              : failure,
        );
      }
      return false;
    } finally {
      if (_isCurrent(revision, expectedProfileId, chatId) && state.isSending) {
        state = ResourceChatDetailState(
          phase: state.phase,
          expectedProfileId: state.expectedProfileId,
          chatId: state.chatId,
          summary: state.summary,
          messages: state.messages,
          hasMoreOlder: state.hasMoreOlder,
          failure: state.failure,
          hasConnectionIssue: state.hasConnectionIssue,
        );
      }
      _drainPendingReconcile(expectedProfileId, chatId);
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
    _reconcileTimer?.cancel();
    _closeSubscription();
    if (ref.mounted && state.hasConnectionIssue) {
      _setConnectionIssue(false);
    }
  }

  void handleAppResumed(String expectedProfileId, String chatId) {
    if (_matchesTarget(expectedProfileId, chatId)) {
      _scheduleReconcile(expectedProfileId, chatId, includeMessages: true);
      ref.read(resourceExchangeRefreshProvider.notifier).notifyChanged();
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    }
  }

  Future<void> _recoverSendConflict(
    String expectedProfileId,
    String chatId,
    int revision,
  ) async {
    ResourceChatSummary? summary;
    try {
      summary = await ref
          .read(resourceChatGatewayProvider)
          .getChat(expectedProfileId: expectedProfileId, chatId: chatId);
      _validateSummary(summary, chatId);
    } catch (_) {
      // The conflict itself remains the actionable result. A later manual
      // refresh can recover if the canonical summary read was unavailable.
    }
    if (!_isCurrent(revision, expectedProfileId, chatId)) return;
    state = ResourceChatDetailState(
      phase: ResourceChatDetailPhase.ready,
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      summary: summary ?? state.summary,
      messages: state.messages,
      hasMoreOlder: state.hasMoreOlder,
      isSending: true,
      failure: ResourceChatFailureKind.conflict,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    if (summary != null) _syncSubscription(expectedProfileId, summary);
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
  }

  void _handleSignal(
    String expectedProfileId,
    String chatId,
    ResourceChatSignal signal,
  ) {
    if (!_matchesTarget(expectedProfileId, chatId) || signal.chatId != chatId) {
      return;
    }
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    if (signal is ResourceExchangeChangedSignal) {
      ref.read(resourceExchangeRefreshProvider.notifier).notifyChanged();
    }
    _scheduleReconcile(
      expectedProfileId,
      chatId,
      includeMessages: signal is ResourceChatMessageSentSignal,
    );
  }

  void _scheduleReconcile(
    String expectedProfileId,
    String chatId, {
    required bool includeMessages,
  }) {
    if (!_matchesTarget(expectedProfileId, chatId)) return;
    _needsMessageReconcile = _needsMessageReconcile || includeMessages;
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_matchesTarget(expectedProfileId, chatId)) return;
      if (_isReconciling || state.isLoadingOlder || state.isSending) {
        _scheduleReconcile(
          expectedProfileId,
          chatId,
          includeMessages: _needsMessageReconcile,
        );
        return;
      }
      final withMessages = _needsMessageReconcile;
      _needsMessageReconcile = false;
      if (withMessages) {
        unawaited(
          refresh(expectedProfileId: expectedProfileId, chatId: chatId),
        );
      } else {
        unawaited(
          refreshSummary(expectedProfileId: expectedProfileId, chatId: chatId),
        );
      }
    });
  }

  void _drainPendingReconcile(String expectedProfileId, String chatId) {
    if (_needsMessageReconcile) {
      _scheduleReconcile(expectedProfileId, chatId, includeMessages: true);
    }
  }

  void _syncSubscription(
    String expectedProfileId,
    ResourceChatSummary summary,
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
    try {
      _subscription = ref
          .read(resourceChatGatewayProvider)
          .subscribeToSignals(
            expectedProfileId: expectedProfileId,
            chatId: summary.chatId,
            onSignal: (signal) =>
                _handleSignal(expectedProfileId, summary.chatId, signal),
            onStatus: (status) =>
                _handleStatus(expectedProfileId, summary.chatId, status),
          );
    } catch (_) {
      _wasDisconnected = true;
      _setConnectionIssue(true);
    }
  }

  void _handleStatus(
    String expectedProfileId,
    String chatId,
    ResourceChatConnectionStatus status,
  ) {
    if (!_matchesTarget(expectedProfileId, chatId)) return;
    if (status == ResourceChatConnectionStatus.disconnected) {
      _wasDisconnected = true;
      _setConnectionIssue(true);
      return;
    }
    final shouldCatchUp = _wasDisconnected;
    _wasDisconnected = false;
    _setConnectionIssue(false);
    if (shouldCatchUp) {
      _scheduleReconcile(expectedProfileId, chatId, includeMessages: true);
      ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    }
  }

  void _setFailure(ResourceChatFailureKind failure) {
    state = ResourceChatDetailState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      chatId: state.chatId,
      summary: state.summary,
      messages: state.messages,
      hasMoreOlder: state.hasMoreOlder,
      isLoadingOlder: state.isLoadingOlder,
      isSending: state.isSending,
      failure: failure,
      hasConnectionIssue: state.hasConnectionIssue,
    );
  }

  void _setConnectionIssue(bool value) {
    if (state.hasConnectionIssue == value) return;
    state = ResourceChatDetailState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      chatId: state.chatId,
      summary: state.summary,
      messages: state.messages,
      hasMoreOlder: state.hasMoreOlder,
      isLoadingOlder: state.isLoadingOlder,
      isSending: state.isSending,
      failure: state.failure,
      hasConnectionIssue: value,
    );
  }

  void _closeSubscription() {
    final subscription = _subscription;
    _subscription = null;
    _subscriptionProfileId = null;
    _subscriptionChatId = null;
    _wasDisconnected = false;
    if (subscription != null) unawaited(subscription.close());
  }

  List<ResourceChatMessage> _mergeMessages(
    Iterable<ResourceChatMessage> existing,
    Iterable<ResourceChatMessage> incoming,
  ) {
    final byId = <String, ResourceChatMessage>{
      for (final message in existing) message.messageId: message,
      for (final message in incoming) message.messageId: message,
    };
    final values = byId.values.toList();
    values.sort((left, right) {
      final time = left.createdAt.compareTo(right.createdAt);
      return time != 0 ? time : left.messageId.compareTo(right.messageId);
    });
    return values;
  }

  void _validateSummary(ResourceChatSummary summary, String chatId) {
    if (summary.chatId != chatId) {
      throw const FormatException('Resource chat summary mismatched.');
    }
  }

  void _validateMessages(
    Iterable<ResourceChatMessage> messages,
    String chatId,
  ) {
    if (messages.any((message) => message.chatId != chatId)) {
      throw const FormatException('Resource chat history mismatched.');
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
      throw const ResourceChatIdentityChangedException();
    }
  }
}

final resourceChatDetailProvider =
    NotifierProvider<ResourceChatDetailController, ResourceChatDetailState>(
      ResourceChatDetailController.new,
    );

ResourceChatFailureKind mapResourceChatFailure(Object error) {
  if (error is ResourceChatIdentityChangedException) {
    return ResourceChatFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ResourceChatFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ResourceChatFailureKind.invalidInput,
      '42501' => ResourceChatFailureKind.forbidden,
      'P0002' => ResourceChatFailureKind.notFound,
      'PT409' => ResourceChatFailureKind.conflict,
      _ => ResourceChatFailureKind.unavailable,
    };
  }
  return ResourceChatFailureKind.unavailable;
}

class ResourceChatIdentityChangedException implements Exception {
  const ResourceChatIdentityChangedException();
}
