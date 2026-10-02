import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/notifications_gateway.dart';
import '../domain/notification_models.dart';

const notificationsPageSize = 20;

enum NotificationsFailureKind { forbidden, unavailable }

enum NotificationsUnreadPhase { idle, loading, ready, failure }

class NotificationsUnreadState {
  const NotificationsUnreadState({
    this.phase = NotificationsUnreadPhase.idle,
    this.expectedProfileId,
    this.count,
    this.failure,
  });

  final NotificationsUnreadPhase phase;
  final String? expectedProfileId;
  final int? count;
  final NotificationsFailureKind? failure;
}

class NotificationsUnreadController extends Notifier<NotificationsUnreadState> {
  var _identityRevision = 0;
  var _loadRevision = 0;

  @override
  NotificationsUnreadState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _identityRevision++;
        _loadRevision++;
        state = const NotificationsUnreadState();
      },
    );
    ref.onDispose(() {
      _identityRevision++;
      _loadRevision++;
    });
    return const NotificationsUnreadState();
  }

  Future<bool> load(String expectedProfileId, {bool refresh = false}) async {
    if (state.phase == NotificationsUnreadPhase.loading && !refresh) {
      return false;
    }
    final identityRevision = _identityRevision;
    final loadRevision = ++_loadRevision;
    state = NotificationsUnreadState(
      phase: NotificationsUnreadPhase.loading,
      expectedProfileId: expectedProfileId,
      count: state.expectedProfileId == expectedProfileId ? state.count : null,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final count = await ref
          .read(notificationsGatewayProvider)
          .getUnreadCount(expectedProfileId: expectedProfileId);
      if (!_isCurrent(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationsUnreadState(
        phase: NotificationsUnreadPhase.ready,
        expectedProfileId: expectedProfileId,
        count: count,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationsUnreadState(
        phase: NotificationsUnreadPhase.failure,
        expectedProfileId: expectedProfileId,
        failure: mapNotificationsFailure(error),
      );
      return false;
    }
  }

  void noteOneRead(String expectedProfileId) {
    if (state.expectedProfileId != expectedProfileId || state.count == null) {
      return;
    }
    state = NotificationsUnreadState(
      phase: NotificationsUnreadPhase.ready,
      expectedProfileId: expectedProfileId,
      count: state.count! > 0 ? state.count! - 1 : 0,
    );
  }

  void noteAllRead(String expectedProfileId) {
    if (state.expectedProfileId != expectedProfileId) return;
    state = NotificationsUnreadState(
      phase: NotificationsUnreadPhase.ready,
      expectedProfileId: expectedProfileId,
      count: 0,
    );
  }

  bool _isCurrent(int identityRevision, int loadRevision, String profileId) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      loadRevision == _loadRevision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const NotificationsIdentityChangedException();
    }
  }
}

final notificationsUnreadProvider =
    NotifierProvider<NotificationsUnreadController, NotificationsUnreadState>(
      NotificationsUnreadController.new,
    );

enum NotificationsInboxPhase { idle, loading, ready, loadingMore, failure }

class NotificationsInboxState {
  const NotificationsInboxState({
    this.phase = NotificationsInboxPhase.idle,
    this.expectedProfileId,
    this.items = const [],
    this.hasMore = false,
    this.pendingReadIds = const {},
    this.isMarkingAll = false,
    this.failure,
  });

  final NotificationsInboxPhase phase;
  final String? expectedProfileId;
  final List<AppNotification> items;
  final bool hasMore;
  final Set<String> pendingReadIds;
  final bool isMarkingAll;
  final NotificationsFailureKind? failure;

  bool get isLoading =>
      phase == NotificationsInboxPhase.loading ||
      phase == NotificationsInboxPhase.loadingMore;
  bool get hasUnread => items.any((item) => item.isUnread);
}

enum NotificationTapOutcome { ready, readFailed, duplicate, staleIdentity }

class NotificationsInboxController extends Notifier<NotificationsInboxState> {
  var _identityRevision = 0;
  var _loadRevision = 0;
  final Set<String> _pendingReadIds = {};

  @override
  NotificationsInboxState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _identityRevision++;
        _loadRevision++;
        _pendingReadIds.clear();
        state = const NotificationsInboxState();
      },
    );
    ref.onDispose(() {
      _identityRevision++;
      _loadRevision++;
      _pendingReadIds.clear();
    });
    return const NotificationsInboxState();
  }

  Future<bool> load(String expectedProfileId, {bool refresh = false}) async {
    if (state.isMarkingAll || (state.isLoading && !refresh)) return false;
    final identityRevision = _identityRevision;
    final loadRevision = ++_loadRevision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = NotificationsInboxState(
      phase: NotificationsInboxPhase.loading,
      expectedProfileId: expectedProfileId,
      items: preserve ? state.items : const [],
      hasMore: preserve && state.hasMore,
      pendingReadIds: Set.unmodifiable(_pendingReadIds),
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(notificationsGatewayProvider)
          .listNotifications(
            expectedProfileId: expectedProfileId,
            limit: notificationsPageSize,
          );
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationsInboxState(
        phase: NotificationsInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(page.items),
        hasMore: page.hasMore,
        pendingReadIds: Set.unmodifiable(_pendingReadIds),
      );
      return true;
    } catch (error) {
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      final existing = state.items;
      state = NotificationsInboxState(
        phase: existing.isEmpty
            ? NotificationsInboxPhase.failure
            : NotificationsInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: state.hasMore,
        pendingReadIds: Set.unmodifiable(_pendingReadIds),
        failure: mapNotificationsFailure(error),
      );
      return false;
    }
  }

  Future<bool> loadMore(String expectedProfileId) async {
    if (state.isLoading ||
        state.isMarkingAll ||
        state.expectedProfileId != expectedProfileId ||
        !state.hasMore ||
        state.items.isEmpty) {
      return false;
    }
    final identityRevision = _identityRevision;
    final loadRevision = ++_loadRevision;
    final existing = state.items;
    final last = existing.last;
    state = NotificationsInboxState(
      phase: NotificationsInboxPhase.loadingMore,
      expectedProfileId: expectedProfileId,
      items: existing,
      hasMore: true,
      pendingReadIds: Set.unmodifiable(_pendingReadIds),
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final page = await ref
          .read(notificationsGatewayProvider)
          .listNotifications(
            expectedProfileId: expectedProfileId,
            limit: notificationsPageSize,
            cursor: NotificationCursor(
              createdAt: last.createdAt,
              notificationId: last.notificationId,
            ),
          );
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      final knownIds = existing.map((item) => item.notificationId).toSet();
      state = NotificationsInboxState(
        phase: NotificationsInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable([
          ...existing,
          ...page.items.where((item) => knownIds.add(item.notificationId)),
        ]),
        hasMore: page.hasMore,
        pendingReadIds: Set.unmodifiable(_pendingReadIds),
      );
      return true;
    } catch (error) {
      if (!_isCurrentLoad(identityRevision, loadRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationsInboxState(
        phase: NotificationsInboxPhase.ready,
        expectedProfileId: expectedProfileId,
        items: existing,
        hasMore: true,
        pendingReadIds: Set.unmodifiable(_pendingReadIds),
        failure: mapNotificationsFailure(error),
      );
      return false;
    }
  }

  Future<NotificationTapOutcome> prepareTap({
    required String expectedProfileId,
    required AppNotification notification,
  }) async {
    if (!_hasReadyIdentity(expectedProfileId) ||
        state.expectedProfileId != expectedProfileId) {
      return NotificationTapOutcome.staleIdentity;
    }
    if (!notification.isUnread) return NotificationTapOutcome.ready;
    if (!_pendingReadIds.add(notification.notificationId)) {
      return NotificationTapOutcome.duplicate;
    }

    _loadRevision++;
    final identityRevision = _identityRevision;
    final originalItems = state.items;
    final optimisticReadAt = DateTime.now().toUtc();
    state = _currentStateWith(
      items: _replaceReadAt(
        state.items,
        notification.notificationId,
        optimisticReadAt,
      ),
    );
    ref
        .read(notificationsUnreadProvider.notifier)
        .noteOneRead(expectedProfileId);

    try {
      _requireReadyIdentity(expectedProfileId);
      final readAt = await ref
          .read(notificationsGatewayProvider)
          .markRead(
            expectedProfileId: expectedProfileId,
            notificationId: notification.notificationId,
          );
      if (!_isCurrentIdentity(identityRevision, expectedProfileId)) {
        return NotificationTapOutcome.staleIdentity;
      }
      _pendingReadIds.remove(notification.notificationId);
      state = _currentStateWith(
        items: _replaceReadAt(state.items, notification.notificationId, readAt),
      );
      unawaited(
        ref
            .read(notificationsUnreadProvider.notifier)
            .load(expectedProfileId, refresh: true),
      );
      return _isCurrentIdentity(identityRevision, expectedProfileId)
          ? NotificationTapOutcome.ready
          : NotificationTapOutcome.staleIdentity;
    } catch (error) {
      if (!_isCurrentIdentity(identityRevision, expectedProfileId)) {
        return NotificationTapOutcome.staleIdentity;
      }
      _pendingReadIds.remove(notification.notificationId);
      state = _currentStateWith(
        items: originalItems,
        failure: mapNotificationsFailure(error),
      );
      unawaited(
        ref
            .read(notificationsUnreadProvider.notifier)
            .load(expectedProfileId, refresh: true),
      );
      return _isCurrentIdentity(identityRevision, expectedProfileId)
          ? NotificationTapOutcome.readFailed
          : NotificationTapOutcome.staleIdentity;
    }
  }

  Future<bool> markAllRead(String expectedProfileId) async {
    if (state.isMarkingAll ||
        state.expectedProfileId != expectedProfileId ||
        !_hasReadyIdentity(expectedProfileId)) {
      return false;
    }
    final identityRevision = _identityRevision;
    _loadRevision++;
    final originalItems = state.items;
    final now = DateTime.now().toUtc();
    state = NotificationsInboxState(
      phase: NotificationsInboxPhase.ready,
      expectedProfileId: expectedProfileId,
      items: List.unmodifiable(
        state.items.map((item) => item.isUnread ? item.withReadAt(now) : item),
      ),
      hasMore: state.hasMore,
      pendingReadIds: Set.unmodifiable(_pendingReadIds),
      isMarkingAll: true,
    );
    ref
        .read(notificationsUnreadProvider.notifier)
        .noteAllRead(expectedProfileId);
    try {
      _requireReadyIdentity(expectedProfileId);
      await ref
          .read(notificationsGatewayProvider)
          .markAllRead(expectedProfileId: expectedProfileId);
      if (!_isCurrentIdentity(identityRevision, expectedProfileId)) {
        return false;
      }
      state = _currentStateWith(items: state.items);
      await ref
          .read(notificationsUnreadProvider.notifier)
          .load(expectedProfileId, refresh: true);
      return _isCurrentIdentity(identityRevision, expectedProfileId);
    } catch (error) {
      if (!_isCurrentIdentity(identityRevision, expectedProfileId)) {
        return false;
      }
      state = _currentStateWith(
        items: originalItems,
        failure: mapNotificationsFailure(error),
      );
      await ref
          .read(notificationsUnreadProvider.notifier)
          .load(expectedProfileId, refresh: true);
      return false;
    }
  }

  NotificationsInboxState _currentStateWith({
    required List<AppNotification> items,
    NotificationsFailureKind? failure,
  }) => NotificationsInboxState(
    phase: NotificationsInboxPhase.ready,
    expectedProfileId: state.expectedProfileId,
    items: List.unmodifiable(items),
    hasMore: state.hasMore,
    pendingReadIds: Set.unmodifiable(_pendingReadIds),
    failure: failure,
  );

  List<AppNotification> _replaceReadAt(
    List<AppNotification> items,
    String notificationId,
    DateTime readAt,
  ) => List.unmodifiable([
    for (final item in items)
      if (item.notificationId == notificationId)
        item.withReadAt(readAt)
      else
        item,
  ]);

  bool _isCurrentLoad(
    int identityRevision,
    int loadRevision,
    String profileId,
  ) =>
      _isCurrentIdentity(identityRevision, profileId) &&
      loadRevision == _loadRevision;

  bool _isCurrentIdentity(int identityRevision, String profileId) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      _hasReadyIdentity(profileId);

  bool _hasReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == profileId;
  }

  void _requireReadyIdentity(String profileId) {
    if (!_hasReadyIdentity(profileId)) {
      throw const NotificationsIdentityChangedException();
    }
  }
}

final notificationsInboxProvider =
    NotifierProvider<NotificationsInboxController, NotificationsInboxState>(
      NotificationsInboxController.new,
    );

enum NotificationPreferencesPhase { idle, loading, ready, saving, failure }

class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.phase = NotificationPreferencesPhase.idle,
    this.expectedProfileId,
    this.preferences = const {},
    this.failure,
  });

  final NotificationPreferencesPhase phase;
  final String? expectedProfileId;
  final Map<NotificationCategory, NotificationPreference> preferences;
  final NotificationsFailureKind? failure;

  NotificationPreference? get participation =>
      preferences[NotificationCategory.participation];
  NotificationPreference? get chat => preferences[NotificationCategory.chat];
  NotificationPreference? get resources =>
      preferences[NotificationCategory.resources];
  NotificationPreference? get matching =>
      preferences[NotificationCategory.matching];

  bool get isBusy =>
      phase == NotificationPreferencesPhase.loading ||
      phase == NotificationPreferencesPhase.saving;
}

class NotificationPreferencesController
    extends Notifier<NotificationPreferencesState> {
  var _identityRevision = 0;
  var _operationRevision = 0;

  @override
  NotificationPreferencesState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (_, _) {
        _identityRevision++;
        _operationRevision++;
        state = const NotificationPreferencesState();
      },
    );
    ref.onDispose(() {
      _identityRevision++;
      _operationRevision++;
    });
    return const NotificationPreferencesState();
  }

  Future<bool> load(String expectedProfileId) async {
    final identityRevision = _identityRevision;
    final operationRevision = ++_operationRevision;
    final preserve = state.expectedProfileId == expectedProfileId;
    state = NotificationPreferencesState(
      phase: NotificationPreferencesPhase.loading,
      expectedProfileId: expectedProfileId,
      preferences: preserve ? state.preferences : const {},
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final preferences = await ref
          .read(notificationsGatewayProvider)
          .listPreferences(expectedProfileId: expectedProfileId);
      final known = _knownPreferences(preferences);
      if (!_isCurrent(identityRevision, operationRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationPreferencesState(
        phase: NotificationPreferencesPhase.ready,
        expectedProfileId: expectedProfileId,
        preferences: known,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(identityRevision, operationRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationPreferencesState(
        phase: NotificationPreferencesPhase.failure,
        expectedProfileId: expectedProfileId,
        preferences: state.preferences,
        failure: mapNotificationsFailure(error),
      );
      return false;
    }
  }

  Future<bool> setParticipationInApp({
    required String expectedProfileId,
    required bool enabled,
  }) => _setInApp(
    expectedProfileId: expectedProfileId,
    category: NotificationCategory.participation,
    enabled: enabled,
  );

  Future<bool> setChatInApp({
    required String expectedProfileId,
    required bool enabled,
  }) => _setInApp(
    expectedProfileId: expectedProfileId,
    category: NotificationCategory.chat,
    enabled: enabled,
  );

  Future<bool> setResourcesInApp({
    required String expectedProfileId,
    required bool enabled,
  }) => _setInApp(
    expectedProfileId: expectedProfileId,
    category: NotificationCategory.resources,
    enabled: enabled,
  );

  Future<bool> setMatchingInApp({
    required String expectedProfileId,
    required bool enabled,
  }) => _setInApp(
    expectedProfileId: expectedProfileId,
    category: NotificationCategory.matching,
    enabled: enabled,
  );

  Future<bool> _setInApp({
    required String expectedProfileId,
    required NotificationCategory category,
    required bool enabled,
  }) async {
    final previousPreferences = state.preferences;
    final previous = previousPreferences[category];
    if (previous == null ||
        previous.category != category ||
        !previous.userConfigurable ||
        state.expectedProfileId != expectedProfileId ||
        state.isBusy ||
        previous.inAppEnabled == enabled) {
      return false;
    }
    final identityRevision = _identityRevision;
    final operationRevision = ++_operationRevision;
    state = NotificationPreferencesState(
      phase: NotificationPreferencesPhase.saving,
      expectedProfileId: expectedProfileId,
      preferences: Map.unmodifiable({
        ...previousPreferences,
        category: previous.withInAppEnabled(enabled),
      }),
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      final gateway = ref.read(notificationsGatewayProvider);
      await gateway.setPreference(
        expectedProfileId: expectedProfileId,
        category: category,
        inAppEnabled: enabled,
        pushEnabled: previous.pushEnabled,
      );
      final preferences = await gateway.listPreferences(
        expectedProfileId: expectedProfileId,
      );
      final canonical = _knownPreferences(preferences);
      if (!_isCurrent(identityRevision, operationRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationPreferencesState(
        phase: NotificationPreferencesPhase.ready,
        expectedProfileId: expectedProfileId,
        preferences: canonical,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(identityRevision, operationRevision, expectedProfileId)) {
        return false;
      }
      var restored = previousPreferences;
      try {
        final preferences = await ref
            .read(notificationsGatewayProvider)
            .listPreferences(expectedProfileId: expectedProfileId);
        restored = _knownPreferences(preferences);
      } catch (_) {
        // The already-loaded value is the safest explicit rollback if the
        // authoritative reload is also unavailable.
      }
      if (!_isCurrent(identityRevision, operationRevision, expectedProfileId)) {
        return false;
      }
      state = NotificationPreferencesState(
        phase: NotificationPreferencesPhase.ready,
        expectedProfileId: expectedProfileId,
        preferences: restored,
        failure: mapNotificationsFailure(error),
      );
      return false;
    }
  }

  Map<NotificationCategory, NotificationPreference> _knownPreferences(
    List<NotificationPreference> preferences,
  ) {
    final known = <NotificationCategory, NotificationPreference>{};
    for (final category in const [
      NotificationCategory.participation,
      NotificationCategory.chat,
      NotificationCategory.resources,
      NotificationCategory.matching,
    ]) {
      final matches = preferences.where((item) => item.category == category);
      if (matches.length != 1 || !matches.single.userConfigurable) {
        throw FormatException(
          '${category.name} notification preference was unavailable.',
        );
      }
      known[category] = matches.single;
    }
    return Map.unmodifiable(known);
  }

  bool _isCurrent(
    int identityRevision,
    int operationRevision,
    String profileId,
  ) =>
      ref.mounted &&
      identityRevision == _identityRevision &&
      operationRevision == _operationRevision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireReadyIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const NotificationsIdentityChangedException();
    }
  }
}

final notificationPreferencesProvider =
    NotifierProvider<
      NotificationPreferencesController,
      NotificationPreferencesState
    >(NotificationPreferencesController.new);

NotificationsFailureKind mapNotificationsFailure(Object error) {
  if (error is NotificationsIdentityChangedException) {
    return NotificationsFailureKind.forbidden;
  }
  if (error is PostgrestException && error.code == '42501') {
    return NotificationsFailureKind.forbidden;
  }
  return NotificationsFailureKind.unavailable;
}

class NotificationsIdentityChangedException implements Exception {
  const NotificationsIdentityChangedException();
}
