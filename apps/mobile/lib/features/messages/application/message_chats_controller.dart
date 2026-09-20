import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../../project_chat/data/project_chat_gateway.dart';
import '../../project_chat/domain/project_chat_models.dart';
import '../../resource_chat/data/resource_chat_gateway.dart';
import '../../resource_chat/domain/resource_chat_models.dart';
import '../data/message_chats_gateway.dart';
import '../domain/message_chat_models.dart';
import 'message_chats_refresh.dart';

const messageChatsPageSize = 20;

enum MessageChatsFailureKind { invalidInput, forbidden, notFound, unavailable }

enum MessageChatsPhase { idle, loading, ready, loadingMore, failure }

class MessageChatsState {
  const MessageChatsState({
    this.phase = MessageChatsPhase.idle,
    this.expectedProfileId,
    this.items = const [],
    this.hasMore = false,
    this.failure,
    this.hasConnectionIssue = false,
  });

  final MessageChatsPhase phase;
  final String? expectedProfileId;
  final List<MessageChatItem> items;
  final bool hasMore;
  final MessageChatsFailureKind? failure;
  final bool hasConnectionIssue;

  bool get isBusy =>
      phase == MessageChatsPhase.loading ||
      phase == MessageChatsPhase.loadingMore;
}

class MessageChatsController extends Notifier<MessageChatsState> {
  final Map<String, ProjectChatSignalSubscription> _projectSubscriptions = {};
  final Map<String, ResourceChatSignalSubscription> _resourceSubscriptions = {};
  final Set<String> _disconnectedChats = {};
  Timer? _refreshTimer;
  var _revision = 0;
  var _signalsEnabled = false;

  @override
  MessageChatsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      _signalsEnabled = false;
      _refreshTimer?.cancel();
      _closeAllSubscriptions();
      state = const MessageChatsState();
    });
    ref.listen(projectChatRefreshProvider, (_, _) => _scheduleCurrentRefresh());
    ref.listen(
      messageChatsRefreshProvider,
      (_, _) => _scheduleCurrentRefresh(),
    );
    ref.onDispose(() {
      _revision++;
      _refreshTimer?.cancel();
      _closeAllSubscriptions();
    });
    return const MessageChatsState();
  }

  Future<bool> load(String expectedProfileId, {bool refresh = false}) async {
    if (state.isBusy && !refresh) return false;
    final revision = ++_revision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = MessageChatsState(
      phase: MessageChatsPhase.loading,
      expectedProfileId: expectedProfileId,
      items: preserve ? state.items : const [],
      hasMore: preserve && state.hasMore,
      hasConnectionIssue: preserve && state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(messageChatsGatewayProvider)
          .listItems(
            expectedProfileId: expectedProfileId,
            limit: messageChatsPageSize,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessageChatsState(
        phase: MessageChatsPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(_dedupe(page.items)),
        hasMore: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscriptions(expectedProfileId);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessageChatsState(
        phase: MessageChatsPhase.failure,
        expectedProfileId: expectedProfileId,
        items: state.items,
        hasMore: state.hasMore,
        failure: mapMessageChatsFailure(error),
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
    state = MessageChatsState(
      phase: MessageChatsPhase.loadingMore,
      expectedProfileId: expectedProfileId,
      items: existing,
      hasMore: true,
      hasConnectionIssue: state.hasConnectionIssue,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(messageChatsGatewayProvider)
          .listItems(
            expectedProfileId: expectedProfileId,
            limit: messageChatsPageSize,
            cursor: MessageChatCursor(
              activityAt: last.activityAt,
              itemKind: last.kind,
              chatId: last.chatId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessageChatsState(
        phase: MessageChatsPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(_dedupe([...existing, ...page.items])),
        hasMore: page.hasMore,
        hasConnectionIssue: state.hasConnectionIssue,
      );
      _syncSubscriptions(expectedProfileId);
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessageChatsState(
        phase: MessageChatsPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: true,
        failure: mapMessageChatsFailure(error),
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
      state = MessageChatsState(
        phase: state.phase,
        expectedProfileId: state.expectedProfileId,
        items: state.items,
        hasMore: state.hasMore,
        failure: state.failure,
      );
    }
  }

  void handleAppResumed(String expectedProfileId) {
    if (_signalsEnabled &&
        state.expectedProfileId == expectedProfileId &&
        _isReadyIdentity(expectedProfileId)) {
      _scheduleRefresh(expectedProfileId);
    }
  }

  List<MessageChatItem> _dedupe(Iterable<MessageChatItem> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (seen.add(value.compositeId)) value,
    ];
  }

  void _syncSubscriptions(String expectedProfileId) {
    if (!_signalsEnabled ||
        state.expectedProfileId != expectedProfileId ||
        !_isReadyIdentity(expectedProfileId)) {
      return;
    }
    final desiredProjects = {
      for (final item in state.items)
        if (item case ProjectMessageChatItem(isReadOnly: false)) item.chatId,
    };
    final desiredResources = {
      for (final item in state.items)
        if (item case ResourceMessageChatItem(isReadOnly: false)) item.chatId,
    };
    _closeStaleProjectSubscriptions(desiredProjects);
    _closeStaleResourceSubscriptions(desiredResources);
    for (final chatId in desiredProjects) {
      if (_projectSubscriptions.containsKey(chatId)) continue;
      try {
        _projectSubscriptions[chatId] = ref
            .read(projectChatGatewayProvider)
            .subscribeToProjectChatSignals(
              expectedProfileId: expectedProfileId,
              chatId: chatId,
              onSignal: (_) => _scheduleRefresh(expectedProfileId),
              onStatus: (status) => _handleStatus(
                expectedProfileId,
                MessageChatItemKind.projectChat,
                chatId,
                status == ProjectChatConnectionStatus.connected,
              ),
            );
      } catch (_) {
        _setDisconnected(MessageChatItemKind.projectChat, chatId, true);
      }
    }
    for (final chatId in desiredResources) {
      if (_resourceSubscriptions.containsKey(chatId)) continue;
      try {
        _resourceSubscriptions[chatId] = ref
            .read(resourceChatGatewayProvider)
            .subscribeToSignals(
              expectedProfileId: expectedProfileId,
              chatId: chatId,
              onSignal: (_) => _scheduleRefresh(expectedProfileId),
              onStatus: (status) => _handleStatus(
                expectedProfileId,
                MessageChatItemKind.resourceChat,
                chatId,
                status == ResourceChatConnectionStatus.connected,
              ),
            );
      } catch (_) {
        _setDisconnected(MessageChatItemKind.resourceChat, chatId, true);
      }
    }
  }

  void _closeStaleProjectSubscriptions(Set<String> desired) {
    for (final chatId in _projectSubscriptions.keys.toList()) {
      if (desired.contains(chatId)) continue;
      final subscription = _projectSubscriptions.remove(chatId);
      _disconnectedChats.remove(_key(MessageChatItemKind.projectChat, chatId));
      if (subscription != null) unawaited(subscription.close());
    }
  }

  void _closeStaleResourceSubscriptions(Set<String> desired) {
    for (final chatId in _resourceSubscriptions.keys.toList()) {
      if (desired.contains(chatId)) continue;
      final subscription = _resourceSubscriptions.remove(chatId);
      _disconnectedChats.remove(_key(MessageChatItemKind.resourceChat, chatId));
      if (subscription != null) unawaited(subscription.close());
    }
  }

  void _handleStatus(
    String expectedProfileId,
    MessageChatItemKind kind,
    String chatId,
    bool connected,
  ) {
    if (!_signalsEnabled ||
        state.expectedProfileId != expectedProfileId ||
        !_isReadyIdentity(expectedProfileId)) {
      return;
    }
    final key = _key(kind, chatId);
    final wasDisconnected = _disconnectedChats.contains(key);
    _setDisconnected(kind, chatId, !connected);
    if (connected && wasDisconnected) _scheduleRefresh(expectedProfileId);
  }

  void _setDisconnected(
    MessageChatItemKind kind,
    String chatId,
    bool disconnected,
  ) {
    if (!ref.mounted) return;
    final key = _key(kind, chatId);
    if (disconnected) {
      _disconnectedChats.add(key);
    } else {
      _disconnectedChats.remove(key);
    }
    final value = _disconnectedChats.isNotEmpty;
    if (state.hasConnectionIssue == value) return;
    state = MessageChatsState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      items: state.items,
      hasMore: state.hasMore,
      failure: state.failure,
      hasConnectionIssue: value,
    );
  }

  void _scheduleCurrentRefresh() {
    final profileId = state.expectedProfileId;
    if (profileId != null) _scheduleRefresh(profileId);
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
    for (final subscription in _projectSubscriptions.values) {
      unawaited(subscription.close());
    }
    for (final subscription in _resourceSubscriptions.values) {
      unawaited(subscription.close());
    }
    _projectSubscriptions.clear();
    _resourceSubscriptions.clear();
    _disconnectedChats.clear();
  }

  String _key(MessageChatItemKind kind, String chatId) =>
      '${kind.wireValue}:$chatId';

  bool _isReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  bool _isCurrent(int revision, String profileId) =>
      ref.mounted && revision == _revision && _isReadyIdentity(profileId);

  void _requireReadyIdentity(String profileId) {
    if (!_isReadyIdentity(profileId)) {
      throw const MessageChatsIdentityChangedException();
    }
  }
}

final messageChatsProvider =
    NotifierProvider<MessageChatsController, MessageChatsState>(
      MessageChatsController.new,
    );

MessageChatsFailureKind mapMessageChatsFailure(Object error) {
  if (error is MessageChatsIdentityChangedException) {
    return MessageChatsFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return MessageChatsFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => MessageChatsFailureKind.invalidInput,
      '42501' => MessageChatsFailureKind.forbidden,
      'P0002' => MessageChatsFailureKind.notFound,
      _ => MessageChatsFailureKind.unavailable,
    };
  }
  return MessageChatsFailureKind.unavailable;
}

class MessageChatsIdentityChangedException implements Exception {
  const MessageChatsIdentityChangedException();
}
