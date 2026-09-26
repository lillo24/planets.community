import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/application/participation_controllers.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../data/messages_gateway.dart';
import '../domain/message_models.dart';
import 'message_chats_refresh.dart';

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
  final List<StructuredRequestMessageItem> items;
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
              itemKind: last.kind,
              requestId: last.requestId,
            ),
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      final knownIds = existing.map((item) => item.compositeId).toSet();
      state = MessagesInboxState(
        phase: MessagesInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable([
          ...existing,
          ...page.items.where((item) => knownIds.add(item.compositeId)),
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

enum MessageAction { rejecting, withdrawing }

enum MessagesDetailPhase { idle, loading, ready, failure }

enum MessagesSelectionPhase { idle, loading, ready, failure }

class MessagesDetailState {
  const MessagesDetailState({
    this.phase = MessagesDetailPhase.idle,
    this.expectedProfileId,
    this.requestId,
    this.item,
    this.selectionPhase = MessagesSelectionPhase.idle,
    this.selections = const [],
    this.selectionFailure,
    this.action,
    this.failure,
  });

  final MessagesDetailPhase phase;
  final String? expectedProfileId;
  final String? requestId;
  final ParticipationRequestMessageItem? item;
  final MessagesSelectionPhase selectionPhase;
  final List<RequestContributionSelection> selections;
  final MessagesFailureKind? selectionFailure;
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
      selectionPhase: preserve
          ? state.selectionPhase
          : MessagesSelectionPhase.idle,
      selections: preserve ? state.selections : const [],
      selectionFailure: preserve ? state.selectionFailure : null,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final structuredItem = await ref
          .read(messagesGatewayProvider)
          .getItem(
            expectedProfileId: expectedProfileId,
            itemKind: StructuredRequestItemKind.participationRequest,
            requestId: requestId,
          );
      if (structuredItem is! ParticipationRequestMessageItem) {
        throw const FormatException(
          'Project request route returned another request kind.',
        );
      }
      final item = structuredItem;
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        item: item,
        selectionPhase: MessagesSelectionPhase.loading,
        selections: preserve ? state.selections : const [],
      );
      try {
        final selections = await ref
            .read(messagesGatewayProvider)
            .listContributionSelections(
              expectedProfileId: expectedProfileId,
              requestId: requestId,
            );
        if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
        state = MessagesDetailState(
          phase: MessagesDetailPhase.ready,
          expectedProfileId: expectedProfileId,
          requestId: requestId,
          item: item,
          selectionPhase: MessagesSelectionPhase.ready,
          selections: List.unmodifiable(selections),
        );
      } catch (error) {
        if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
        state = MessagesDetailState(
          phase: MessagesDetailPhase.ready,
          expectedProfileId: expectedProfileId,
          requestId: requestId,
          item: item,
          selectionPhase: MessagesSelectionPhase.failure,
          selections: preserve ? state.selections : const [],
          selectionFailure: mapMessagesFailure(error),
        );
      }
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.failure,
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        item: state.item,
        selectionPhase: state.selectionPhase,
        selections: state.selections,
        selectionFailure: state.selectionFailure,
        failure: mapMessagesFailure(error),
      );
      return false;
    }
  }

  Future<bool> reject() => _mutate(MessageAction.rejecting);

  Future<bool> withdraw() => _mutate(MessageAction.withdrawing);

  Future<bool> retryContributionSelections() async {
    final item = state.item;
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    if (item == null || profileId == null || requestId == null) return false;
    final revision = ++_revision;
    state = MessagesDetailState(
      phase: MessagesDetailPhase.ready,
      expectedProfileId: profileId,
      requestId: requestId,
      item: item,
      selectionPhase: MessagesSelectionPhase.loading,
      selections: state.selections,
    );
    try {
      _requireReadyIdentity(profileId);
      final selections = await ref
          .read(messagesGatewayProvider)
          .listContributionSelections(
            expectedProfileId: profileId,
            requestId: requestId,
          );
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: profileId,
        requestId: requestId,
        item: item,
        selectionPhase: MessagesSelectionPhase.ready,
        selections: List.unmodifiable(selections),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: profileId,
        requestId: requestId,
        item: item,
        selectionPhase: MessagesSelectionPhase.failure,
        selections: state.selections,
        selectionFailure: mapMessagesFailure(error),
      );
      return false;
    }
  }

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
      selectionPhase: state.selectionPhase,
      selections: state.selections,
      selectionFailure: state.selectionFailure,
      action: action,
    );
    try {
      _requireReadyIdentity(profileId);
      final gateway = ref.read(messagesGatewayProvider);
      switch (action) {
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
      final structuredCanonical = await gateway.getItem(
        expectedProfileId: profileId,
        itemKind: StructuredRequestItemKind.participationRequest,
        requestId: requestId,
      );
      if (structuredCanonical is! ParticipationRequestMessageItem) {
        throw const FormatException(
          'Project request mutation returned another request kind.',
        );
      }
      final canonical = structuredCanonical;
      if (!_isCurrent(revision, profileId, requestId)) return false;
      state = MessagesDetailState(
        phase: MessagesDetailPhase.ready,
        expectedProfileId: profileId,
        requestId: requestId,
        item: canonical,
        selectionPhase: state.selectionPhase,
        selections: state.selections,
        selectionFailure: state.selectionFailure,
      );
      await _synchronize(action, canonical, profileId);
      return _isCurrent(revision, profileId, requestId);
    } catch (error) {
      if (!_isCurrent(revision, profileId, requestId)) return false;
      final failure = mapMessagesFailure(error);
      if (failure == MessagesFailureKind.conflict) {
        try {
          final structuredCanonical = await ref
              .read(messagesGatewayProvider)
              .getItem(
                expectedProfileId: profileId,
                itemKind: StructuredRequestItemKind.participationRequest,
                requestId: requestId,
              );
          if (structuredCanonical is! ParticipationRequestMessageItem) {
            throw const FormatException(
              'Project request conflict returned another request kind.',
            );
          }
          final canonical = structuredCanonical;
          if (!_isCurrent(revision, profileId, requestId)) return false;
          state = MessagesDetailState(
            phase: MessagesDetailPhase.ready,
            expectedProfileId: profileId,
            requestId: requestId,
            item: canonical,
            selectionPhase: state.selectionPhase,
            selections: state.selections,
            selectionFailure: state.selectionFailure,
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
        selectionPhase: state.selectionPhase,
        selections: state.selections,
        selectionFailure: state.selectionFailure,
        failure: failure,
      );
      return false;
    }
  }

  bool _roleAllows(
    ParticipationRequestMessageItem item,
    MessageAction action,
  ) => switch ((item.viewerRole, action)) {
    (MessageViewerRole.creator, MessageAction.rejecting) ||
    (MessageViewerRole.requester, MessageAction.withdrawing) => true,
    _ => false,
  };

  Future<void> _synchronize(
    MessageAction action,
    ParticipationRequestMessageItem item,
    String profileId,
  ) async {
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    ref.read(projectChatRefreshProvider.notifier).notifyChanged();
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

  Future<bool> reloadAfterJoinAcceptanceTriage() async {
    final profileId = state.expectedProfileId;
    final requestId = state.requestId;
    final previousItem = state.item;
    if (profileId == null || requestId == null || previousItem == null) {
      return false;
    }
    final loaded = await load(
      expectedProfileId: profileId,
      requestId: requestId,
    );
    if (!loaded ||
        ref.read(authSessionProvider).identity?.id != profileId ||
        state.requestId != requestId) {
      return false;
    }
    await ref
        .read(messagesInboxProvider.notifier)
        .load(profileId, refresh: true);
    ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
    if (ref.read(authSessionProvider).identity?.id != profileId ||
        state.requestId != requestId) {
      return false;
    }
    final canonical = state.item;
    final creatorState = ref.read(creatorParticipationProvider);
    if (canonical != null &&
        creatorState.expectedCreatorId == profileId &&
        creatorState.projectId == canonical.projectId) {
      await ref
          .read(creatorParticipationProvider.notifier)
          .load(profileId, canonical.projectId);
    }
    return ref.read(authSessionProvider).identity?.id == profileId &&
        state.requestId == requestId;
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
