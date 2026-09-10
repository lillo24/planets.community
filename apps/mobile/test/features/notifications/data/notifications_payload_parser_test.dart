import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';

void main() {
  const parser = NotificationsPayloadParser();

  test('parses all current participation kinds', () {
    final cases = {
      'participation_request_received':
          NotificationKind.participationRequestReceived,
      'participation_request_withdrawn':
          NotificationKind.participationRequestWithdrawn,
      'participation_request_accepted':
          NotificationKind.participationRequestAccepted,
      'participation_request_rejected':
          NotificationKind.participationRequestRejected,
      'participant_left': NotificationKind.participantLeft,
      'participant_removed': NotificationKind.participantRemoved,
    };

    for (final entry in cases.entries) {
      final row = _row(entry.key);
      final parsed = parser.notification(row);
      expect(parsed.kind, entry.value);
      expect(parsed.notificationId, _notificationId);
      expect(parsed.createdAt, DateTime.parse('2026-09-10T10:00:00Z'));
    }
  });

  test('unknown category, kind, and destination remain generic and safe', () {
    final parsed = parser.notification({
      ..._row('future_kind'),
      'category_slug': 'future_category',
      'destination_kind': 'future_destination',
      'project_kind': 'future_project_kind',
      'request_id': null,
      'project_id': null,
    });

    expect(parsed.category, NotificationCategory.unknown);
    expect(parsed.kind, NotificationKind.unknown);
    expect(parsed.destinationKind, NotificationDestinationKind.unknown);
    expect(parsed.projectKind, isNull);
  });

  test('known kinds reject missing or mismatched semantic context', () {
    expect(
      () => parser.notification({
        ..._row('participation_request_received'),
        'request_id': null,
      }),
      throwsFormatException,
    );
    expect(
      () => parser.notification({
        ..._row('participant_left'),
        'destination_kind': 'project_detail',
      }),
      throwsFormatException,
    );
    expect(
      () => parser.notification({
        ..._row('participant_removed'),
        'project_kind': 'future_kind',
      }),
      throwsFormatException,
    );
  });

  test('malformed UUIDs and timestamps fail explicitly', () {
    expect(
      () => parser.notification({
        ..._row('participation_request_received'),
        'notification_id': 'not-a-uuid',
      }),
      throwsFormatException,
    );
    expect(
      () => parser.notification({
        ..._row('participation_request_received'),
        'created_at': 'not-a-date',
      }),
      throwsFormatException,
    );
  });

  test('unknown preference categories parse without becoming mutable', () {
    final preference = parser.preference({
      'category_slug': 'future_category',
      'sort_order': 99,
      'in_app_enabled': true,
      'push_enabled': false,
      'has_override': false,
      'user_configurable': true,
    });
    expect(preference.category, NotificationCategory.unknown);
  });
}

const _notificationId = '00000000-0000-4000-8000-000000000001';
const _projectId = '00000000-0000-4000-8000-000000000002';
const _requestId = '00000000-0000-4000-8000-000000000003';
const _actorId = '00000000-0000-4000-8000-000000000004';

Map<String, Object?> _row(String kind) {
  final isRequest = kind.startsWith('participation_request_');
  final isLeft = kind == 'participant_left';
  return {
    'notification_id': _notificationId,
    'category_slug': 'participation',
    'notification_kind': kind,
    'created_at': '2026-09-10T10:00:00Z',
    'read_at': null,
    'project_id': _projectId,
    'project_kind': 'one_time',
    'project_title': 'Community Garden',
    'destination_kind': isRequest
        ? 'participation_request'
        : isLeft
        ? 'project_participation'
        : 'project_detail',
    'request_id': isRequest ? _requestId : null,
    'actor_profile_id': _actorId,
    'actor_display_name': 'Mario',
  };
}
