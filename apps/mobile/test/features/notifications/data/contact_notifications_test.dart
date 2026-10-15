import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_destination.dart';

const noticeId = '00000000-0000-4000-8000-000000000901';
const targetId = '00000000-0000-4000-8000-000000000902';

Map<String, Object?> contactNotice(String kind) => {
  'notification_id': noticeId,
  'category_slug': 'participation',
  'notification_kind': kind,
  'destination_kind': kind,
  'contact_target_id': targetId,
  'created_at': '2026-10-15T10:00:00Z',
  'read_at': null,
};

void main() {
  const parser = NotificationsPayloadParser();
  final routes = {
    'group_contact_request': '/messages/requests/group-contact/$targetId',
    'group_coordination_proposal':
        '/messages/requests/group-coordination/$targetId',
    'member_contact_request': '/messages/requests/member-contact/$targetId',
  };

  for (final entry in routes.entries) {
    test('${entry.key} uses its typed destination without private context', () {
      final notice = parser.notification(contactNotice(entry.key));
      expect(notice.kind.isContact, isTrue);
      expect(notice.category, NotificationCategory.participation);
      expect(notice.contactTargetId, targetId);
      expect(notificationDestinationRoute(notice), entry.value);
      expect(notice.actorDisplayName, isNull);
      expect(notice.projectTitle, isNull);
      expect(
        notice.withReadAt(DateTime.utc(2026, 10, 16)).contactTargetId,
        targetId,
      );
    });

    test('${entry.key} rejects missing, crossed, or leaking context', () {
      for (final change in <Map<String, Object?>>[
        {'contact_target_id': null},
        {'contact_target_id': 'not-a-uuid'},
        {'category_slug': 'chat'},
        {'destination_kind': 'project_chat'},
        {'actor_profile_id': targetId},
        {'actor_display_name': 'Private sender'},
        {'project_id': targetId},
        {'project_title': 'Private source'},
        {'chat_id': targetId},
        {'request_id': targetId},
        {'resource_listing_id': targetId},
      ]) {
        expect(
          () => parser.notification({...contactNotice(entry.key), ...change}),
          throwsFormatException,
          reason: change.toString(),
        );
      }
    });
  }
}
