import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_copy.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_notifications.dart';

void main() {
  testWidgets('request, chat, terms, and close copy keep meanings distinct', (
    tester,
  ) async {
    const cases = <NotificationKind, String>{
      NotificationKind.resourceRequestReceived:
          'Mario is interested in “Power drill”',
      NotificationKind.resourceRequestWithdrawn:
          'Mario withdrew their request for “Power drill”',
      NotificationKind.resourceRequestAccepted:
          'Your request for “Power drill” was accepted',
      NotificationKind.resourceRequestRejected:
          'Your request for “Power drill” was declined',
      NotificationKind.resourceRequestListingClosed:
          '“Power drill” was closed before your request was accepted',
      NotificationKind.resourceChatMessageReceived:
          'Mario sent a message about “Power drill”',
      NotificationKind.resourceExchangeTermsProposed:
          'Mario proposed exchange terms for “Power drill”',
      NotificationKind.resourceExchangeTermsAccepted:
          'Mario accepted the exchange terms for “Power drill”',
      NotificationKind.resourceExchangeTermsRejected:
          'Mario rejected the proposed terms for “Power drill”',
      NotificationKind.resourceExchangeTermsWithdrawn:
          'Mario withdrew their terms proposal for “Power drill”',
      NotificationKind.resourceExchangeCancelled:
          'Mario cancelled the coordination for “Power drill”',
      NotificationKind.resourceExchangeCompleted:
          'The exchange for “Power drill” was completed',
    };
    for (final entry in cases.entries) {
      expect(
        await _copy(tester, resourceNotificationFixture(kind: entry.key)),
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  testWidgets('all milestones describe participant statements, not proof', (
    tester,
  ) async {
    const cases =
        <(ResourceNotificationLegKind, ResourceNotificationEventKind), String>{
          (
            ResourceNotificationLegKind.ownerResource,
            ResourceNotificationEventKind.resourceProvided,
          ): 'Mario marked “Power drill” as handed over',
          (
            ResourceNotificationLegKind.ownerResource,
            ResourceNotificationEventKind.resourceReceived,
          ): 'Mario confirmed receiving “Power drill”',
          (
            ResourceNotificationLegKind.ownerResource,
            ResourceNotificationEventKind.resourceReturned,
          ): 'Mario marked “Power drill” as returned',
          (
            ResourceNotificationLegKind.ownerResource,
            ResourceNotificationEventKind.resourceReturnReceived,
          ): 'Mario confirmed “Power drill” was returned',
          (
            ResourceNotificationLegKind.requesterResource,
            ResourceNotificationEventKind.resourceProvided,
          ): 'Mario marked their exchange item as handed over',
          (
            ResourceNotificationLegKind.requesterResource,
            ResourceNotificationEventKind.resourceReceived,
          ): 'Mario confirmed receiving the other exchange item',
          (
            ResourceNotificationLegKind.requesterResource,
            ResourceNotificationEventKind.resourceReturned,
          ): 'Mario marked their exchange item as returned',
          (
            ResourceNotificationLegKind.requesterResource,
            ResourceNotificationEventKind.resourceReturnReceived,
          ): 'Mario confirmed the other exchange item was returned',
        };
    for (final entry in cases.entries) {
      final copy = await _copy(
        tester,
        resourceNotificationFixture(
          kind: NotificationKind.resourceExchangeMilestoneRecorded,
          resourceExchangeLegKind: entry.key.$1,
          resourceExchangeEventKind: entry.key.$2,
        ),
      );
      expect(copy, entry.value);
      expect(copy, isNot(contains('verified')));
      if (entry.key.$1 == ResourceNotificationLegKind.requesterResource) {
        expect(copy, isNot(contains('Power drill')));
      }
    }
  });

  testWidgets('missing display context has localized safe fallback', (
    tester,
  ) async {
    final notification = resourceNotificationFixture(
      actorDisplayName: null,
      resourceListingTitle: null,
    );
    final copy = await _copy(tester, notification);
    expect(copy, 'Someone is interested in “a Resource listing”');
    expect(copy, isNot(contains(notification.resourceListingId!)));

    final future = await _copy(
      tester,
      resourceNotificationFixture(kind: NotificationKind.unknown),
    );
    expect(future, 'You have a new notification.');
  });
}

Future<String> _copy(WidgetTester tester, AppNotification notification) async {
  String? copy;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          copy = notificationCopy(AppLocalizations.of(context), notification);
          return Text(copy!);
        },
      ),
    ),
  );
  return copy!;
}
