import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_destination.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';

import '../../../support/fake_notifications.dart';

void main() {
  test('request destinations reuse the structured Messages route', () {
    expect(
      notificationDestinationRoute(notificationFixture()),
      '/messages/requests/00000000-0000-4000-8000-000000000101',
    );
  });

  test('participation and detail destinations map both project kinds', () {
    expect(
      notificationDestinationRoute(
        notificationFixture(
          kind: NotificationKind.participantLeft,
          destinationKind: NotificationDestinationKind.projectParticipation,
          requestId: null,
        ),
      ),
      '/proposals/00000000-0000-4000-8000-000000000201/participants',
    );
    expect(
      notificationDestinationRoute(
        notificationFixture(
          kind: NotificationKind.participantRemoved,
          destinationKind: NotificationDestinationKind.projectDetail,
          projectKind: ProjectKind.recurring,
          requestId: null,
        ),
      ),
      '/tavoli/00000000-0000-4000-8000-000000000201',
    );
  });

  test('Project chat destination reuses the canonical Messages route', () {
    expect(
      notificationDestinationRoute(
        notificationFixture(
          category: NotificationCategory.chat,
          kind: NotificationKind.chatMessageReceived,
          destinationKind: NotificationDestinationKind.projectChat,
          requestId: null,
          chatId: '00000000-0000-4000-8000-000000000401',
          messageId: '00000000-0000-4000-8000-000000000402',
        ),
      ),
      '/messages/chats/00000000-0000-4000-8000-000000000401',
    );
    expect(
      notificationDestinationRoute(
        notificationFixture(
          category: NotificationCategory.chat,
          kind: NotificationKind.chatMessageReceived,
          destinationKind: NotificationDestinationKind.projectChat,
          requestId: null,
          chatId: null,
          messageId: '00000000-0000-4000-8000-000000000402',
        ),
      ),
      isNull,
    );
  });

  test('unknown and mismatched semantics never guess a route', () {
    expect(
      notificationDestinationRoute(
        notificationFixture(
          category: NotificationCategory.unknown,
          kind: NotificationKind.unknown,
          destinationKind: NotificationDestinationKind.unknown,
          projectId: null,
          projectKind: null,
          requestId: null,
        ),
      ),
      isNull,
    );
    expect(
      notificationDestinationRoute(
        notificationFixture(
          kind: NotificationKind.participantLeft,
          destinationKind: NotificationDestinationKind.projectDetail,
          requestId: null,
        ),
      ),
      isNull,
    );
  });
}
