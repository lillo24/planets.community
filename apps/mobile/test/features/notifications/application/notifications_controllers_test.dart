import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/notifications/application/notifications_controllers.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_notifications.dart';

void main() {
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
