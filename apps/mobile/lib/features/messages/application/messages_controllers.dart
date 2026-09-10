import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../data/messages_gateway.dart';
import '../domain/message_models.dart';

const messagesPageSize = 20;

enum MessagesFailureKind { forbidden, conflict, notFound, unavailable }

enum MessagesInboxPhase { idle, loading, ready, loadingMore, failure }

class MessagesInboxState {
  const MessagesInboxState({
    this.phase = MessagesInboxPhase.idle,
    this.expectedProfileId,
    this.items = const [],
    this.hasMore = false,
    this.failure,
  });

  final MessagesInboxPhase phase;
  final String? expectedProfileId;
  final List<ParticipationRequestMessageItem> items;
  final bool hasMore;
  final MessagesFailureKind? failure;

  bool get isBusy =>
      phase == MessagesInboxPhase.loading ||
      phase == MessagesInboxPhase.loadingMore;
}

class MessagesInboxController extends Notifier<MessagesInboxState> {
  var _revision = 0;

  @override
  MessagesInboxState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const MessagesInboxState();
    });
    ref.onDispose(() => _revision++);
    return const MessagesInboxState();
  }

  Future<bool> load(String expectedProfileId, {bool refresh = false}) async {
    if (state.isBusy && !refresh) return false;
    final revision = ++_revision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = MessagesInboxState(
      phase: MessagesInboxPhase.loading,
      expectedProfileId: expectedProfileId,
      items: preserve ? state.items : const [],
      hasMore: preserve && state.hasMore,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(messagesGatewayProvider)
          .listItems(
            expectedProfileId: expectedProfileId,
            limit: messagesPageSize,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessagesInboxState(
        phase: MessagesInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(page.items),
        hasMore: page.hasMore,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessagesInboxState(
        phase: MessagesInboxPhase.failure,
        expectedProfileId: expectedProfileId,
        items: state.items,
        hasMore: state.hasMore,
        failure: mapMessagesFailure(error),
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
    state = MessagesInboxState(
      phase: MessagesInboxPhase.loadingMore,
      expectedProfileId: expectedProfileId,
      items: existing,
      hasMore: true,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(messagesGatewayProvider)
          .listItems(
            expectedProfileId: expectedProfileId,
            limit: messagesPageSize,
            cursor: MessageCursor(
              activityAt: last.activityAt,
              requestId: last.requestId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final knownIds = existing.map((item) => item.requestId).toSet();
      state = MessagesInboxState(
        phase: MessagesInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable([
          ...existing,
          ...page.items.where((item) => knownIds.add(item.requestId)),
        ]),
        hasMore: page.hasMore,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = MessagesInboxState(
        phase: MessagesInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: true,
        failure: mapMessagesFailure(error),
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
      throw const MessagesIdentityChangedException();
    }
  }
}

final messagesInboxProvider =
    NotifierProvider<MessagesInboxController, MessagesInboxState>(
      MessagesInboxController.new,
    );

enum MessageAction { accepting, rejecting, withdrawing }

enum MessagesDetailPhase { idle, loading, ready, failure }

class MessagesDetailState {
  const MessagesDetailState({
    this.phase = MessagesDetailPhase.idle,
    this.expectedProfileId,
    this.requestId,
    this.item,
    this.action,
    this.failure,
  });

  final MessagesDetailPhase phase;
  final String? expectedProfileId;
  final String? requestId;
  final ParticipationRequestMessageItem? item;
  final MessageAction? action;
  final MessagesFailureKind? failure;

  bool get isActing => action != null;
}

class MessagesDetailController extends Notifier<MessagesDetailState> {
  var _revision = 0;

  @override
  MessagesDetailState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const MessagesDetailState();
    });
    ref.onDispose(() => _revision++);
    return const MessagesDetailState();
  }

  Future<bool> load({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final revision = ++_revision;
    final preserve =
        state.expectedProfileId == expectedProfileId &&
        state.requestId == requestId;
    state = MessagesDetailState(
      phase: MessagesDetailPhase.loading,
      expectedProfileId: expectedProfileId,
      requestId: requestId,
      item: preserve ? state.item : null,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final item = await ref
          .read(messagesGatewayProvider)
          .getItem(expectedProfileId: expectedProfileId, requestId: requestId);
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        item: item,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.failure,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        item: state.item,
        failure: mapMessagesFailure(error),
      );
      return false;
    }
  }

  Future<bool> accept() => _mutate(MessageAction.accepting);

  Future<bool> reject() => _mutate(MessageAction.rejecting);

  Future<bool> withdraw() => _mutate(MessageAction.withdrawing);

  Future<bool> _mutate(MessageAction action) async {
    final item = state.item;
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (item == null ||
        profileId == null ||
        requestId == null ||
        state.isActing ||
        !item.isPending ||
        !_roleAllows(item, action)) {
      return false;
    }
    final revision = ++_revision;
    state = MessagesDetailState(
      phase: MessagesDetailPhase.ready,
      expectedProfileId: profileId,
      requestId: requestId,
      item: item,
      action: action,
    );
    try {
      _requireReadyIdentity(profileId);
      final gateway = ref.read(messagesGatewayProvider);
      switch (action) {
        case MessageAction.accepting:
          await gateway.accept(
            expectedCreatorProfileId: profileId,
            requestId: requestId,
          );
        case MessageAction.rejecting:
          await gateway.reject(
            expectedCreatorProfileId: profileId,
            requestId: requestId,
          );
        case MessageAction.withdrawing:
          await gateway.withdraw(
            expectedRequesterProfileId: profileId,
            requestId: requestId,
          );
      }
      if (!_isCurrent(revision, profileId, requestId)) return false;
      final canonical = await gateway.getItem(
        expectedProfileId: profileId,
        requestId: requestId,
      );
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: profileId,
        requestId: requestId,
        item: canonical,
      );
      await _synchronize(action, canonical, profileId);
      return _isCurrent(revision, profileId, requestId);
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      final failure = mapMessagesFailure(error);
      if (failure == MessagesFailureKind.conflict) {
        try {
          final canonical = await ref
              .read(messagesGatewayProvider)
              .getItem(expectedProfileId: profileId, requestId: requestId);
          if (!_isCurrent(revision, profileId, requestId)) return false;
          state = MessagesDetailState(
            phase: MessagesDetailPhase.ready,
            expectedProfileId: profileId,
            requestId: requestId,
            item: canonical,
            failure: failure,
          );
          await ref
              .read(messagesInboxProvider.notifier)
              .load(profileId, refresh: true);
          return false;
        } catch (_) {
          if (!_isCurrent(revision, profileId, requestId)) return false;
        }
      }
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: profileId,
        requestId: requestId,
        item: item,
        failure: failure,
      );
      return false;
    }
  }

  bool _roleAllows(
    ParticipationRequestMessageItem item,
    MessageAction action,
  ) => switch ((item.viewerRole, action)) {
    (MessageViewerRole.creator, MessageAction.accepting) ||
    (MessageViewerRole.creator, MessageAction.rejecting) ||
    (MessageViewerRole.requester, MessageAction.withdrawing) => true,
    _ => false,
  };

  Future<void> _synchronize(
    MessageAction action,
    ParticipationRequestMessageItem item,
    String profileId,
  ) async {
    await ref
        .read(messagesInboxProvider.notifier)
        .load(profileId, refresh: true);
    if (action == MessageAction.withdrawing) {
      await ref.read(ownParticipationProvider.notifier).load(profileId);
      return;
    }
    final creatorState = ref.read(creatorParticipationProvider);
    if (creatorState.expectedCreatorId == profileId &&
        creatorState.projectId == item.projectId) {
      await ref
          .read(creatorParticipationProvider.notifier)
          .load(profileId, item.projectId);
    }
  }

  bool _isCurrent(int revision, String profileId, String requestId) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId &&
      state.requestId == requestId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const MessagesIdentityChangedException();
    }
  }
}

final messagesDetailProvider =
    NotifierProvider<MessagesDetailController, MessagesDetailState>(
      MessagesDetailController.new,
    );

MessagesFailureKind mapMessagesFailure(Object error) {
  if (error is MessagesIdentityChangedException) {
    return MessagesFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return MessagesFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '42501' => MessagesFailureKind.forbidden,
      '55000' => MessagesFailureKind.conflict,
      'P0002' => MessagesFailureKind.notFound,
      _ => MessagesFailureKind.unavailable,
    };
  }
  return MessagesFailureKind.unavailable;
}

class MessagesIdentityChangedException implements Exception {
  const MessagesIdentityChangedException();
}
