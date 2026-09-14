import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_copy.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_notifications.dart';

void main() {
  testWidgets('chat copy uses safe actor and Project display context', (
    tester,
  ) async {
    await _pumpCopy(
      tester,
      notificationFixture(
        category: NotificationCategory.chat,
        kind: NotificationKind.chatMessageReceived,
        destinationKind: NotificationDestinationKind.projectChat,
        requestId: null,
        chatId: '00000000-0000-4000-8000-000000000401',
        messageId: '00000000-0000-4000-8000-000000000402',
      ),
    );

    expect(
      find.text('Mario sent a message in “Community Garden”'),
      findsOneWidget,
    );
    expect(find.textContaining('private message body'), findsNothing);
  });

  testWidgets('chat copy falls back without exposing identifiers', (
    tester,
  ) async {
    final base = notificationFixture(
      category: NotificationCategory.chat,
      kind: NotificationKind.chatMessageReceived,
      destinationKind: NotificationDestinationKind.projectChat,
      requestId: null,
      chatId: '00000000-0000-4000-8000-000000000401',
      messageId: '00000000-0000-4000-8000-000000000402',
      actorDisplayName: null,
    );
    await _pumpCopy(tester, base);
    expect(find.text('New message in “Community Garden”'), findsOneWidget);
    expect(find.textContaining(base.chatId!), findsNothing);
    expect(find.textContaining(base.messageId!), findsNothing);

    await _pumpCopy(
      tester,
      notificationFixture(
        category: NotificationCategory.chat,
        kind: NotificationKind.chatMessageReceived,
        destinationKind: NotificationDestinationKind.projectChat,
        projectTitle: null,
        actorDisplayName: null,
        requestId: null,
        chatId: '00000000-0000-4000-8000-000000000401',
        messageId: '00000000-0000-4000-8000-000000000402',
      ),
    );
    expect(find.text('New project chat message'), findsOneWidget);
  });
}

Future<void> _pumpCopy(WidgetTester tester, AppNotification notification) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(
            notificationCopy(AppLocalizations.of(context), notification),
          ),
        ),
      ),
    );
