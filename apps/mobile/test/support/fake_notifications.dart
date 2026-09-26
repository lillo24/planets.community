import 'dart:async';

import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';

class FakeNotificationsGateway implements NotificationsGateway {
  List<AppNotification> items = [];
  List<NotificationPreference> preferences = [
    notificationPreferenceFixture(),
    notificationPreferenceFixture(category: NotificationCategory.chat),
    notificationPreferenceFixture(category: NotificationCategory.resources),
    notificationPreferenceFixture(category: NotificationCategory.matching),
  ];
  int? unreadCount;
  Object? listError;
  Object? unreadError;
  Object? mutationError;
  Object? preferenceError;
  Future<void>? listDelay;
  Future<void>? unreadDelay;
  Future<void>? mutationDelay;
  Future<void>? preferenceDelay;
  final List<String> calls = [];
  NotificationCursor? lastCursor;
  String? lastExpectedProfileId;
  bool? lastInAppEnabled;
  bool? lastPushEnabled;
  NotificationCategory? lastCategory;

  @override
  Future<NotificationsPage> listNotifications({
    required String expectedProfileId,
    required int limit,
    NotificationCursor? cursor,
  }) async {
    calls.add('list');
    lastExpectedProfileId = expectedProfileId;
    lastCursor = cursor;
    if (listDelay case final delay?) await delay;
    if (listError case final error?) throw error;
    final cursorIndex = cursor == null
        ? -1
        : items.indexWhere(
            (item) => item.notificationId == cursor.notificationId,
          );
    final start = cursorIndex < 0 ? 0 : cursorIndex + 1;
    final page = items.skip(start).take(limit).toList(growable: false);
    return NotificationsPage(
      items: page,
      hasMore: start + page.length < items.length,
    );
  }

  @override
  Future<int> getUnreadCount({required String expectedProfileId}) async {
    calls.add('unread');
    lastExpectedProfileId = expectedProfileId;
    if (unreadDelay case final delay?) await delay;
    if (unreadError case final error?) throw error;
    return unreadCount ?? items.where((item) => item.isUnread).length;
  }

  @override
  Future<DateTime> markRead({
    required String expectedProfileId,
    required String notificationId,
  }) async {
    calls.add('mark:$notificationId');
    lastExpectedProfileId = expectedProfileId;
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    final readAt = DateTime.utc(2026, 9, 10, 12);
    items = [
      for (final item in items)
        if (item.notificationId == notificationId)
          item.withReadAt(readAt)
        else
          item,
    ];
    return readAt;
  }

  @override
  Future<int> markAllRead({required String expectedProfileId}) async {
    calls.add('mark-all');
    lastExpectedProfileId = expectedProfileId;
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    final unread = items.where((item) => item.isUnread).length;
    final readAt = DateTime.utc(2026, 9, 10, 12);
    items = [
      for (final item in items) item.isUnread ? item.withReadAt(readAt) : item,
    ];
    unreadCount = 0;
    return unread;
  }

  @override
  Future<List<NotificationPreference>> listPreferences({
    required String expectedProfileId,
  }) async {
    calls.add('preferences');
    lastExpectedProfileId = expectedProfileId;
    if (preferenceDelay case final delay?) await delay;
    if (preferenceError case final error?) throw error;
    return List.unmodifiable(preferences);
  }

  @override
  Future<void> setPreference({
    required String expectedProfileId,
    required NotificationCategory category,
    required bool inAppEnabled,
    required bool pushEnabled,
  }) async {
    calls.add('set-preference');
    lastExpectedProfileId = expectedProfileId;
    lastCategory = category;
    lastInAppEnabled = inAppEnabled;
    lastPushEnabled = pushEnabled;
    if (preferenceDelay case final delay?) await delay;
    if (preferenceError case final error?) throw error;
    preferences = [
      for (final preference in preferences)
        if (preference.category == category)
          NotificationPreference(
            category: preference.category,
            sortOrder: preference.sortOrder,
            inAppEnabled: inAppEnabled,
            pushEnabled: pushEnabled,
            hasOverride: true,
            userConfigurable: preference.userConfigurable,
          )
        else
          preference,
    ];
  }
}

AppNotification notificationFixture({
  int index = 1,
  NotificationCategory category = NotificationCategory.participation,
  NotificationKind kind = NotificationKind.participationRequestReceived,
  NotificationDestinationKind destinationKind =
      NotificationDestinationKind.participationRequest,
  ProjectKind? projectKind = ProjectKind.oneTime,
  String? projectTitle = 'Community Garden',
  String? actorDisplayName = 'Mario',
  String? actorProfileId = '00000000-0000-4000-8000-000000000301',
  String? requestId = '00000000-0000-4000-8000-000000000101',
  String? projectId = '00000000-0000-4000-8000-000000000201',
  String? chatId,
  String? messageId,
  String? resourceListingId,
  String? resourceListingTitle,
  String? resourceRequestId,
  String? resourceChatId,
  String? resourceChatMessageId,
  String? resourceAgreementId,
  String? resourceAgreementEventId,
  ResourceNotificationEventKind? resourceExchangeEventKind,
  ResourceNotificationLegKind? resourceExchangeLegKind,
  DateTime? createdAt,
  DateTime? readAt,
}) => AppNotification(
  notificationId:
      '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  category: category,
  kind: kind,
  createdAt:
      createdAt ??
      DateTime.utc(2026, 9, 10, 10).subtract(Duration(minutes: index)),
  readAt: readAt,
  destinationKind: destinationKind,
  projectId: projectId,
  projectKind: projectKind,
  projectTitle: projectTitle,
  requestId: requestId,
  chatId: chatId,
  messageId: messageId,
  actorProfileId: actorProfileId,
  actorDisplayName: actorDisplayName,
  resourceListingId: resourceListingId,
  resourceListingTitle: resourceListingTitle,
  resourceRequestId: resourceRequestId,
  resourceChatId: resourceChatId,
  resourceChatMessageId: resourceChatMessageId,
  resourceAgreementId: resourceAgreementId,
  resourceAgreementEventId: resourceAgreementEventId,
  resourceExchangeEventKind: resourceExchangeEventKind,
  resourceExchangeLegKind: resourceExchangeLegKind,
);

AppNotification resourceNotificationFixture({
  int index = 1,
  NotificationKind kind = NotificationKind.resourceRequestReceived,
  NotificationDestinationKind destinationKind =
      NotificationDestinationKind.resourceRequest,
  String? actorDisplayName = 'Mario',
  String resourceListingId = '00000000-0000-4000-8000-000000000501',
  String? resourceListingTitle = 'Power drill',
  String resourceRequestId = '00000000-0000-4000-8000-000000000502',
  String? resourceChatId,
  String? resourceChatMessageId,
  String? resourceAgreementId,
  String? resourceAgreementEventId,
  ResourceNotificationEventKind? resourceExchangeEventKind,
  ResourceNotificationLegKind? resourceExchangeLegKind,
}) => notificationFixture(
  index: index,
  category: NotificationCategory.resources,
  kind: kind,
  destinationKind: destinationKind,
  projectId: null,
  projectKind: null,
  projectTitle: null,
  requestId: null,
  actorDisplayName: actorDisplayName,
  resourceListingId: resourceListingId,
  resourceListingTitle: resourceListingTitle,
  resourceRequestId: resourceRequestId,
  resourceChatId: resourceChatId,
  resourceChatMessageId: resourceChatMessageId,
  resourceAgreementId: resourceAgreementId,
  resourceAgreementEventId: resourceAgreementEventId,
  resourceExchangeEventKind: resourceExchangeEventKind,
  resourceExchangeLegKind: resourceExchangeLegKind,
);

AppNotification matchingNotificationFixture({
  int index = 1,
  String resourceListingId = '00000000-0000-4000-8000-000000000501',
  String? resourceListingTitle = 'Power drill',
}) => notificationFixture(
  index: index,
  category: NotificationCategory.matching,
  kind: NotificationKind.matchingAvailable,
  destinationKind: NotificationDestinationKind.matchingResult,
  projectId: null,
  projectKind: null,
  projectTitle: null,
  requestId: null,
  actorProfileId: null,
  actorDisplayName: null,
  resourceListingId: resourceListingId,
  resourceListingTitle: resourceListingTitle,
);

NotificationPreference notificationPreferenceFixture({
  NotificationCategory category = NotificationCategory.participation,
  bool inAppEnabled = true,
  bool pushEnabled = false,
  bool userConfigurable = true,
}) => NotificationPreference(
  category: category,
  sortOrder: switch (category) {
    NotificationCategory.chat => 40,
    NotificationCategory.resources => 50,
    NotificationCategory.matching => 60,
    _ => 10,
  },
  inAppEnabled: inAppEnabled,
  pushEnabled: pushEnabled,
  hasOverride: false,
  userConfigurable: userConfigurable,
);
