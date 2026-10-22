import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/presentation/notification_destination.dart';

import 'contact_notifications_test.dart' as f;

Map<String, Object?> filling() => {
  'notification_id': f.noticeId,
  'category_slug': 'participation',
  'notification_kind': 'cocreate_filling',
  'destination_kind': 'cocreate_filling',
  'created_at': '2026-10-23T09:00:00Z',
  'read_at': null,
  'cocreate_hub_id': f.targetId,
  'cocreate_general_room_id': f.targetId,
  'cocreate_episode_id': f.targetId,
  'cocreate_recruitment_id': f.targetId,
  'cocreate_topic': 'Lupus in Fabula',
  'cocreate_number': 2,
  'cocreate_starts_at': '2026-11-02T19:30:00Z',
  'cocreate_capacity': 7,
  'cocreate_occupied': 4,
};
void main() {
  const parser = NotificationsPayloadParser();
  test('notification carries meeting time and exact review destination; read does not join', () {
    final n = parser.notification(filling());
    expect(n.coFilling!.occupied, 4);
    expect(n.coFilling!.capacity, 7);
    expect(n.coFilling!.startsAt, DateTime.utc(2026, 11, 2, 19, 30));
    expect(
      notificationDestinationRoute(n),
      contains(
        '/general/${f.targetId}/${f.targetId}/recruitment/${f.targetId}',
      ),
    );
    expect(
      n.withReadAt(DateTime.utc(2026, 10, 24)).coFilling!.refreshValue,
      n.coFilling!.refreshValue,
    );
  });
  test('mixed private context, foreign kind, invalid occupancy or timestamp fail loudly', () {
    for (final change in <Map<String, Object?>>[
      {'cocreate_starts_at': '2026-11-02T19:30:00'},
      {'cocreate_starts_at': '2026-02-30T00:00:00Z'},
      {'cocreate_episode_id': 'bad'},
      {'cocreate_occupied': 8},
      {'cocreate_capacity': 1},
      {'category_slug': 'chat'},
      {'notification_kind': 'chat_message_received'},
      {'destination_kind': 'project_chat'},
      {'project_id': f.targetId},
      {'actor_profile_id': f.targetId},
      {'contact_target_id': f.targetId},
    ]) {
      expect(
        () => parser.notification({...filling(), ...change}),
        throwsFormatException,
        reason: change.toString(),
      );
    }
  });
}
