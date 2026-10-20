import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_contact/application/contact_access_changes.dart';
import 'package:planets_mobile/features/member_contact/application/member_contact_access_changes.dart';
import 'package:planets_mobile/features/messages/application/message_chats_refresh.dart';
import 'package:planets_mobile/features/notifications/application/notifications_controllers.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_notifications.dart';

void main() {
  test(
    'ordinary message refresh cannot invalidate an activity read mutation',
    () async {
      final gateway = FakeNotificationsGateway()
        ..items = [notificationFixture()];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationsInboxProvider.notifier,
      );
      await controller.load('user-1');
      final delivered = Completer<void>();
      gateway.mutationDelay = delivered.future;
      final reading = controller.markAllRead('user-1');
      session.container
          .read(messageChatsRefreshProvider.notifier)
          .notifyChanged();
      delivered.complete();
      expect(await reading, isTrue);
      expect(
        session.container
            .read(notificationsInboxProvider)
            .items
            .single
            .isUnread,
        isFalse,
      );
    },
  );

  test(
    'member access hint clears own cached notice when reload fails',
    () async {
      const parser = NotificationsPayloadParser();
      final notice = parser.notification({
        'notification_id': '00000000-0000-4000-8000-000000000911',
        'category_slug': 'participation',
        'notification_kind': 'member_contact_request',
        'destination_kind': 'member_contact_request',
        'contact_target_id': '00000000-0000-4000-8000-000000000912',
        'created_at': '2026-10-15T10:00:00Z',
        'read_at': null,
      });
      final gateway = FakeNotificationsGateway()..items = [notice];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationsInboxProvider.notifier,
      );
      await controller.load('user-1');
      gateway.listError = StateError('offline');
      session.container
          .read(memberContactAccessChangesProvider.notifier)
          .changed('user-1');
      await Future<void>.delayed(Duration.zero);
      expect(session.container.read(notificationsInboxProvider).items, isEmpty);
      expect(
        session.container.read(notificationsInboxProvider).failure,
        NotificationsFailureKind.unavailable,
      );
    },
  );

  test('access change clears contact notices offline and defeats stale read rollback', () async {
    const parser = NotificationsPayloadParser();
    final notice = parser.notification({
      'notification_id': '00000000-0000-4000-8000-000000000901',
      'category_slug': 'participation',
      'notification_kind': 'group_contact_request',
      'destination_kind': 'group_contact_request',
      'contact_target_id': '00000000-0000-4000-8000-000000000902',
      'created_at': '2026-10-15T10:00:00Z',
      'read_at': null,
    });
    final legacy = notificationFixture();
    final gateway = FakeNotificationsGateway()..items = [notice, legacy];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      notificationsInboxProvider.notifier,
    );
    await controller.load('user-1');
    final delayedRead = Completer<void>();
    gateway.mutationDelay = delayedRead.future;
    final reading = controller.markAllRead('user-1');
    gateway.listError = StateError('offline');
    gateway.mutationError = StateError('lost access');
    session.container
        .read(contactAccessChangesProvider.notifier)
        .changed('user-1');
    await Future<void>.delayed(Duration.zero);
    expect(
      session.container
          .read(notificationsInboxProvider)
          .items
          .map((n) => n.notificationId),
      [legacy.notificationId],
    );
    delayedRead.complete();
    expect(await reading, isFalse);
    expect(
      session.container
          .read(notificationsInboxProvider)
          .items
          .any((n) => n.kind.isContact),
      isFalse,
    );
  });

  test('older unread response cannot undo successful read counts', () async {
    final gateway = FakeNotificationsGateway()..unreadCount = 2;
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      notificationsUnreadProvider.notifier,
    );
    await controller.load('user-1');
    final pending = Completer<void>();
    gateway.unreadDelay = pending.future;
    final loading = controller.load('user-1', refresh: true);
    controller.noteOneRead('user-1');
    pending.complete();
    expect(await loading, isFalse);
    expect(session.container.read(notificationsUnreadProvider).count, 1);
    gateway.unreadDelay = null;
    gateway.unreadError = StateError('offline');
    expect(await controller.load('user-1', refresh: true), isFalse);
    expect(session.container.read(notificationsUnreadProvider).count, 1);
  });

  test('warm revalidation retains 60 rows, coalesces opens, removes revoked rows and continues paging', () async {
    final gateway = FakeNotificationsGateway()
      ..items = [
        for (var index = 1; index <= 81; index++)
          notificationFixture(
            index: index,
            createdAt: DateTime.utc(
              2026,
              10,
              1,
            ).subtract(Duration(minutes: index)),
          ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      notificationsInboxProvider.notifier,
    );
    await controller.load('user-1');
    await controller.loadMore('user-1');
    await controller.loadMore('user-1');
    final previous = session.container.read(notificationsInboxProvider).items;
    expect(previous, hasLength(60));
    final pending = Completer<void>();
    gateway.listDelay = pending.future;
    final callCount = gateway.calls.length;
    final first = controller.load('user-1', refresh: true);
    final second = controller.load('user-1', refresh: true);
    expect(
      session.container.read(notificationsInboxProvider).items,
      same(previous),
    );
    expect(gateway.calls.length, callCount + 1);
    pending.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(
      session.container.read(notificationsInboxProvider).items,
      same(previous),
    );
    gateway.listDelay = null;
    final deleted = gateway.items[35];
    gateway.items = [
      for (var index = 0; index <= 81; index++)
        if (index != 36)
          notificationFixture(
            index: index,
            createdAt: DateTime.utc(
              2026,
              10,
              1,
            ).subtract(Duration(minutes: index)),
          ),
    ];
    expect(await controller.load('user-1', refresh: true), isTrue);
    final refreshed = session.container.read(notificationsInboxProvider).items;
    expect(refreshed.length, greaterThanOrEqualTo(60));
    expect(
      refreshed.any((item) => item.notificationId == deleted.notificationId),
      isFalse,
    );
    expect(
      refreshed.any(
        (item) => item.notificationId == previous.last.notificationId,
      ),
      isTrue,
    );
    expect(await controller.loadMore('user-1'), isTrue);
    while (session.container.read(notificationsInboxProvider).hasMore) {
      expect(await controller.loadMore('user-1'), isTrue);
    }
    expect(
      session.container.read(notificationsInboxProvider).items,
      hasLength(81),
    );
    expect(gateway.requestedLimits.toSet(), {20});
  });

  test(
    'inbox uses created-at/id cursor and appends without duplicates',
    () async {
      final gateway = FakeNotificationsGateway()
        ..items = List.generate(
          21,
          (index) => notificationFixture(index: index + 1),
        );
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationsInboxProvider.notifier,
      );

      expect(await controller.load('user-1'), isTrue);
      expect(
        session.container.read(notificationsInboxProvider).items,
        hasLength(20),
      );
      expect(await controller.loadMore('user-1'), isTrue);
      expect(
        gateway.lastCursor?.notificationId,
        gateway.items[19].notificationId,
      );
      expect(
        session.container.read(notificationsInboxProvider).items,
        hasLength(21),
      );
      expect(
        session.container.read(notificationsInboxProvider).hasMore,
        isFalse,
      );
    },
  );

  test('page two and unread responses for A are discarded under B', () async {
    final pageDelay = Completer<void>();
    final unreadDelay = Completer<void>();
    final gateway = FakeNotificationsGateway()
      ..items = List.generate(
        21,
        (index) => notificationFixture(index: index + 1),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final inbox = session.container.read(notificationsInboxProvider.notifier);
    await inbox.load('user-1');
    gateway
      ..listDelay = pageDelay.future
      ..unreadDelay = unreadDelay.future;

    final page = inbox.loadMore('user-1');
    final unread = session.container
        .read(notificationsUnreadProvider.notifier)
        .load('user-1');
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pageDelay.complete();
    unreadDelay.complete();

    expect(await page, isFalse);
    expect(await unread, isFalse);
    expect(session.container.read(notificationsInboxProvider).items, isEmpty);
    expect(session.container.read(notificationsUnreadProvider).count, isNull);
  });

  test(
    'mark-read failure permits navigation and restores unread state',
    () async {
      final gateway = FakeNotificationsGateway()
        ..items = [notificationFixture()]
        ..mutationError = StateError('private backend diagnostic');
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final inbox = session.container.read(notificationsInboxProvider.notifier);
      await inbox.load('user-1');
      await session.container
          .read(notificationsUnreadProvider.notifier)
          .load('user-1');

      final outcome = await inbox.prepareTap(
        expectedProfileId: 'user-1',
        notification: gateway.items.single,
      );
      await Future<void>.delayed(Duration.zero);

      expect(outcome, NotificationTapOutcome.readFailed);
      expect(
        session.container
            .read(notificationsInboxProvider)
            .items
            .single
            .isUnread,
        isTrue,
      );
      expect(session.container.read(notificationsUnreadProvider).count, 1);
    },
  );

  test(
    'duplicate mark taps are blocked and identity switch cancels navigation',
    () async {
      final delay = Completer<void>();
      final gateway = FakeNotificationsGateway()
        ..items = [notificationFixture()]
        ..mutationDelay = delay.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final inbox = session.container.read(notificationsInboxProvider.notifier);
      await inbox.load('user-1');

      final first = inbox.prepareTap(
        expectedProfileId: 'user-1',
        notification: gateway.items.single,
      );
      expect(
        await inbox.prepareTap(
          expectedProfileId: 'user-1',
          notification: gateway.items.single,
        ),
        NotificationTapOutcome.duplicate,
      );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      delay.complete();

      expect(await first, NotificationTapOutcome.staleIdentity);
      expect(session.container.read(notificationsInboxProvider).items, isEmpty);
      expect(
        gateway.calls.where((call) => call.startsWith('mark:')),
        hasLength(1),
      );
    },
  );

  test('mark all is idempotent and represented rows become read', () async {
    final gateway = FakeNotificationsGateway()
      ..items = [notificationFixture(), notificationFixture(index: 2)];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final inbox = session.container.read(notificationsInboxProvider.notifier);
    await inbox.load('user-1');
    await session.container
        .read(notificationsUnreadProvider.notifier)
        .load('user-1');

    expect(await inbox.markAllRead('user-1'), isTrue);
    expect(
      session.container
          .read(notificationsInboxProvider)
          .items
          .every((item) => !item.isUnread),
      isTrue,
    );
    expect(await inbox.markAllRead('user-1'), isTrue);
    expect(gateway.calls.where((call) => call == 'mark-all'), hasLength(2));
  });

  test(
    'preference mutation preserves hidden push and canonical reload',
    () async {
      final gateway = FakeNotificationsGateway()
        ..preferences = [
          notificationPreferenceFixture(pushEnabled: false),
          notificationPreferenceFixture(
            category: NotificationCategory.chat,
            pushEnabled: true,
          ),
          notificationPreferenceFixture(
            category: NotificationCategory.resources,
            pushEnabled: true,
          ),
          notificationPreferenceFixture(
            category: NotificationCategory.matching,
            pushEnabled: false,
          ),
          notificationPreferenceFixture(category: NotificationCategory.unknown),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationPreferencesProvider.notifier,
      );
      await controller.load('user-1');

      expect(
        await controller.setParticipationInApp(
          expectedProfileId: 'user-1',
          enabled: false,
        ),
        isTrue,
      );
      expect(gateway.lastInAppEnabled, isFalse);
      expect(gateway.lastPushEnabled, isFalse);
      expect(
        session.container
            .read(notificationPreferencesProvider)
            .participation
            ?.inAppEnabled,
        isFalse,
      );
    },
  );

  test(
    'chat preference preserves hidden push and the Participation row',
    () async {
      final gateway = FakeNotificationsGateway()
        ..preferences = [
          notificationPreferenceFixture(
            inAppEnabled: false,
            pushEnabled: false,
          ),
          notificationPreferenceFixture(
            category: NotificationCategory.chat,
            inAppEnabled: true,
            pushEnabled: true,
          ),
          notificationPreferenceFixture(
            category: NotificationCategory.resources,
            pushEnabled: true,
          ),
          notificationPreferenceFixture(
            category: NotificationCategory.matching,
            pushEnabled: false,
          ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationPreferencesProvider.notifier,
      );
      await controller.load('user-1');

      expect(
        await controller.setChatInApp(
          expectedProfileId: 'user-1',
          enabled: false,
        ),
        isTrue,
      );
      expect(gateway.lastCategory, NotificationCategory.chat);
      expect(gateway.lastInAppEnabled, isFalse);
      expect(gateway.lastPushEnabled, isTrue);
      final state = session.container.read(notificationPreferencesProvider);
      expect(state.chat?.inAppEnabled, isFalse);
      expect(state.participation?.inAppEnabled, isFalse);
      expect(
        gateway.preferences
            .singleWhere(
              (item) => item.category == NotificationCategory.participation,
            )
            .inAppEnabled,
        isFalse,
      );
    },
  );

  test(
    'preference failure rolls back and account switch discards late mutation',
    () async {
      final gateway = FakeNotificationsGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationPreferencesProvider.notifier,
      );
      await controller.load('user-1');
      gateway.preferenceError = StateError('private backend diagnostic');

      expect(
        await controller.setParticipationInApp(
          expectedProfileId: 'user-1',
          enabled: false,
        ),
        isFalse,
      );
      expect(
        session.container
            .read(notificationPreferencesProvider)
            .participation
            ?.inAppEnabled,
        isTrue,
      );

      gateway.preferenceError = null;
      final delay = Completer<void>();
      gateway.preferenceDelay = delay.future;
      final pending = controller.setParticipationInApp(
        expectedProfileId: 'user-1',
        enabled: false,
      );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      delay.complete();
      expect(await pending, isFalse);
      expect(
        session.container.read(notificationPreferencesProvider).participation,
        isNull,
      );
      expect(
        session.container.read(notificationPreferencesProvider).chat,
        isNull,
      );
      expect(
        session.container.read(notificationPreferencesProvider).resources,
        isNull,
      );
      expect(
        session.container.read(notificationPreferencesProvider).matching,
        isNull,
      );
    },
  );

  test('Resources preference changes only in-app and preserves push', () async {
    final gateway = FakeNotificationsGateway()
      ..preferences = [
        notificationPreferenceFixture(inAppEnabled: false),
        notificationPreferenceFixture(
          category: NotificationCategory.chat,
          inAppEnabled: false,
        ),
        notificationPreferenceFixture(
          category: NotificationCategory.resources,
          inAppEnabled: true,
          pushEnabled: true,
        ),
        notificationPreferenceFixture(
          category: NotificationCategory.matching,
          pushEnabled: false,
        ),
        notificationPreferenceFixture(category: NotificationCategory.unknown),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      notificationPreferencesProvider.notifier,
    );
    expect(await controller.load('user-1'), isTrue);
    expect(
      session.container
          .read(notificationPreferencesProvider)
          .resources
          ?.inAppEnabled,
      isTrue,
    );

    expect(
      await controller.setResourcesInApp(
        expectedProfileId: 'user-1',
        enabled: false,
      ),
      isTrue,
    );
    expect(gateway.lastCategory, NotificationCategory.resources);
    expect(gateway.lastInAppEnabled, isFalse);
    expect(gateway.lastPushEnabled, isTrue);
    var state = session.container.read(notificationPreferencesProvider);
    expect(state.resources?.inAppEnabled, isFalse);
    expect(state.participation?.inAppEnabled, isFalse);
    expect(state.chat?.inAppEnabled, isFalse);

    expect(
      await controller.setResourcesInApp(
        expectedProfileId: 'user-1',
        enabled: true,
      ),
      isTrue,
    );
    state = session.container.read(notificationPreferencesProvider);
    expect(state.resources?.inAppEnabled, isTrue);
    expect(gateway.lastPushEnabled, isTrue);
    expect(state.preferences, hasLength(4));
  });

  test('Matching preference preserves canonical hidden push values', () async {
    for (final pushEnabled in [false, true]) {
      final gateway = FakeNotificationsGateway()
        ..preferences = [
          notificationPreferenceFixture(),
          notificationPreferenceFixture(category: NotificationCategory.chat),
          notificationPreferenceFixture(
            category: NotificationCategory.resources,
          ),
          notificationPreferenceFixture(
            category: NotificationCategory.matching,
            pushEnabled: pushEnabled,
          ),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationPreferencesProvider.notifier,
      );
      expect(await controller.load('user-1'), isTrue);

      expect(
        await controller.setMatchingInApp(
          expectedProfileId: 'user-1',
          enabled: false,
        ),
        isTrue,
      );
      expect(gateway.lastCategory, NotificationCategory.matching);
      expect(gateway.lastInAppEnabled, isFalse);
      expect(gateway.lastPushEnabled, pushEnabled);
      expect(
        session.container
            .read(notificationPreferencesProvider)
            .matching
            ?.inAppEnabled,
        isFalse,
      );
    }
  });

  test('all four known preferences must be unique and configurable', () async {
    final gateway = FakeNotificationsGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      notificationPreferencesProvider.notifier,
    );
    final valid = List<NotificationPreference>.of(gateway.preferences);
    expect(await controller.load('user-1'), isTrue);

    gateway.preferences = valid
        .where((item) => item.category != NotificationCategory.resources)
        .toList();
    expect(await controller.load('user-1'), isFalse);
    expect(
      session.container.read(notificationPreferencesProvider).phase,
      NotificationPreferencesPhase.failure,
    );

    gateway.preferences = [
      ...valid,
      notificationPreferenceFixture(category: NotificationCategory.resources),
    ];
    expect(await controller.load('user-1'), isFalse);

    gateway.preferences = [
      for (final item in valid)
        if (item.category == NotificationCategory.resources)
          notificationPreferenceFixture(
            category: NotificationCategory.resources,
            userConfigurable: false,
          )
        else
          item,
    ];
    expect(await controller.load('user-1'), isFalse);

    gateway.preferences = [
      ...valid,
      notificationPreferenceFixture(category: NotificationCategory.unknown),
    ];
    expect(await controller.load('user-1'), isTrue);
    expect(
      session.container.read(notificationPreferencesProvider).preferences,
      hasLength(4),
    );
  });

  test(
    'Resources failure rolls back and late account mutation is discarded',
    () async {
      final gateway = FakeNotificationsGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        notificationPreferencesProvider.notifier,
      );
      await controller.load('user-1');
      gateway.preferenceError = StateError('private backend diagnostic');

      expect(
        await controller.setResourcesInApp(
          expectedProfileId: 'user-1',
          enabled: false,
        ),
        isFalse,
      );
      expect(
        session.container
            .read(notificationPreferencesProvider)
            .resources
            ?.inAppEnabled,
        isTrue,
      );

      gateway.preferenceError = null;
      final delay = Completer<void>();
      gateway.preferenceDelay = delay.future;
      final pending = controller.setResourcesInApp(
        expectedProfileId: 'user-1',
        enabled: false,
      );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      delay.complete();
      expect(await pending, isFalse);
      expect(
        session.container.read(notificationPreferencesProvider).preferences,
        isEmpty,
      );
    },
  );
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeNotificationsGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      notificationsGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
