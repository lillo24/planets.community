import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_destination.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';

import '../../../support/fake_notifications.dart';

void main() {
  test('Matching alerts open the existing Resource detail route', () {
    expect(
      notificationDestinationRoute(matchingNotificationFixture()),
      '/resources/00000000-0000-4000-8000-000000000501',
    );
    expect(
      notificationDestinationRoute(
        notificationFixture(
          category: NotificationCategory.matching,
          kind: NotificationKind.unknown,
          destinationKind: NotificationDestinationKind.matchingResult,
          projectId: null,
          projectKind: null,
          projectTitle: null,
          requestId: null,
          actorProfileId: null,
          actorDisplayName: null,
          resourceListingId: '00000000-0000-4000-8000-000000000501',
        ),
      ),
      isNull,
    );
  });

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

  test('Resource request alerts open the structured Resource request', () {
    for (final kind in [
      NotificationKind.resourceRequestReceived,
      NotificationKind.resourceRequestWithdrawn,
      NotificationKind.resourceRequestRejected,
      NotificationKind.resourceRequestListingClosed,
    ]) {
      expect(
        notificationDestinationRoute(resourceNotificationFixture(kind: kind)),
        '/messages/requests/resource/00000000-0000-4000-8000-000000000502',
        reason: kind.name,
      );
    }
  });

  test('accepted, chat, and exchange alerts open Resource chat', () {
    for (final kind in [
      NotificationKind.resourceRequestAccepted,
      NotificationKind.resourceChatMessageReceived,
      NotificationKind.resourceExchangeTermsProposed,
      NotificationKind.resourceExchangeTermsAccepted,
      NotificationKind.resourceExchangeTermsRejected,
      NotificationKind.resourceExchangeTermsWithdrawn,
      NotificationKind.resourceExchangeMilestoneRecorded,
      NotificationKind.resourceExchangeCancelled,
      NotificationKind.resourceExchangeCompleted,
    ]) {
      expect(
        notificationDestinationRoute(
          resourceNotificationFixture(
            kind: kind,
            destinationKind: NotificationDestinationKind.resourceChat,
            resourceChatId: '00000000-0000-4000-8000-000000000503',
          ),
        ),
        '/messages/chats/resource/00000000-0000-4000-8000-000000000503',
        reason: kind.name,
      );
    }
    expect(
      notificationDestinationRoute(
        resourceNotificationFixture(
          kind: NotificationKind.resourceRequestAccepted,
          destinationKind: NotificationDestinationKind.resourceChat,
          resourceChatId: null,
        ),
      ),
      isNull,
    );
    expect(
      notificationDestinationRoute(
        resourceNotificationFixture(kind: NotificationKind.unknown),
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
