import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';

void main() {
  const parser = NotificationsPayloadParser();

  test('parses the strict Matching shape with optional title enrichment', () {
    final withTitle = parser.notification(_matchingRow());
    expect(withTitle.category, NotificationCategory.matching);
    expect(withTitle.kind, NotificationKind.matchingAvailable);
    expect(
      withTitle.destinationKind,
      NotificationDestinationKind.matchingResult,
    );
    expect(withTitle.resourceListingId, _listingId);
    expect(withTitle.resourceListingTitle, 'Power drill');
    expect(withTitle.kind.isResource, isFalse);

    final withoutTitle = parser.notification(
      _matchingRow(resourceListingTitle: null),
    );
    expect(withoutTitle.resourceListingTitle, isNull);
  });

  test('rejects incomplete and cross-shaped known Matching rows', () {
    for (final change in <Map<String, Object?>>[
      {'resource_listing_id': null},
      {'notification_kind': 'future_kind'},
      {'destination_kind': 'future_destination'},
      {'actor_profile_id': _actorId},
      {'actor_display_name': 'Mario'},
      {'project_id': _projectId},
      {'request_id': _requestId},
      {'resource_request_id': _requestId},
      {'resource_chat_id': _chatId},
      {'resource_agreement_id': _agreementId},
      {'resource_exchange_event_kind': 'terms_proposed'},
    ]) {
      expect(
        () => parser.notification({..._matchingRow(), ...change}),
        throwsFormatException,
        reason: change.keys.single,
      );
    }

    expect(
      () => parser.notification({
        ..._matchingRow(),
        'category_slug': 'resources',
      }),
      throwsFormatException,
    );
    expect(
      () => parser.notification({
        ..._matchingRow(),
        'category_slug': 'future_category',
      }),
      throwsFormatException,
    );
  });

  test('unknown future semantics remain generic and non-Matching', () {
    final parsed = parser.notification({
      ..._matchingRow(resourceListingTitle: null),
      'category_slug': 'future_category',
      'notification_kind': 'future_kind',
      'destination_kind': 'future_destination',
      'resource_listing_id': null,
    });
    expect(parsed.category, NotificationCategory.unknown);
    expect(parsed.kind, NotificationKind.unknown);
    expect(parsed.destinationKind, NotificationDestinationKind.unknown);
  });
}

const _notificationId = '00000000-0000-4000-8000-000000000001';
const _listingId = '00000000-0000-4000-8000-000000000002';
const _actorId = '00000000-0000-4000-8000-000000000003';
const _projectId = '00000000-0000-4000-8000-000000000004';
const _requestId = '00000000-0000-4000-8000-000000000005';
const _chatId = '00000000-0000-4000-8000-000000000006';
const _agreementId = '00000000-0000-4000-8000-000000000007';

Map<String, Object?> _matchingRow({
  Object? resourceListingTitle = 'Power drill',
}) => {
  'notification_id': _notificationId,
  'category_slug': 'matching',
  'notification_kind': 'matching_available',
  'created_at': '2026-09-26T10:00:00Z',
  'read_at': null,
  'destination_kind': 'matching_result',
  'project_id': null,
  'project_kind': null,
  'project_title': null,
  'request_id': null,
  'chat_id': null,
  'message_id': null,
  'actor_profile_id': null,
  'actor_display_name': null,
  'resource_listing_id': _listingId,
  'resource_listing_title': resourceListingTitle,
  'resource_request_id': null,
  'resource_chat_id': null,
  'resource_chat_message_id': null,
  'resource_agreement_id': null,
  'resource_agreement_event_id': null,
  'resource_exchange_event_kind': null,
  'resource_exchange_leg_kind': null,
};
