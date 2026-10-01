import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';

void main() {
  const parser = NotificationsPayloadParser();
  const kinds = <String, NotificationKind>{
    'resource_request_received': NotificationKind.resourceRequestReceived,
    'resource_request_withdrawn': NotificationKind.resourceRequestWithdrawn,
    'resource_request_accepted': NotificationKind.resourceRequestAccepted,
    'resource_request_rejected': NotificationKind.resourceRequestRejected,
    'resource_request_listing_closed':
        NotificationKind.resourceRequestListingClosed,
    'resource_chat_message_received':
        NotificationKind.resourceChatMessageReceived,
    'resource_exchange_terms_proposed':
        NotificationKind.resourceExchangeTermsProposed,
    'resource_exchange_terms_accepted':
        NotificationKind.resourceExchangeTermsAccepted,
    'resource_exchange_terms_rejected':
        NotificationKind.resourceExchangeTermsRejected,
    'resource_exchange_terms_withdrawn':
        NotificationKind.resourceExchangeTermsWithdrawn,
    'resource_exchange_milestone_recorded':
        NotificationKind.resourceExchangeMilestoneRecorded,
    'resource_exchange_cancelled': NotificationKind.resourceExchangeCancelled,
    'resource_exchange_completed': NotificationKind.resourceExchangeCompleted,
  };

  test('all 13 Resource kinds parse with exact destinations and context', () {
    for (final entry in kinds.entries) {
      final parsed = parser.notification(_resourceRow(entry.key));
      expect(parsed.category, NotificationCategory.resources);
      expect(parsed.kind, entry.value);
      expect(parsed.resourceListingId, _listingId);
      expect(parsed.resourceListingTitle, 'Power drill');
      expect(parsed.resourceRequestId, _requestId);
      expect(parsed.actorProfileId, _actorId);
      expect(
        parsed.destinationKind,
        entry.key == 'resource_request_accepted' ||
                entry.key == 'resource_chat_message_received' ||
                entry.key.startsWith('resource_exchange_')
            ? NotificationDestinationKind.resourceChat
            : NotificationDestinationKind.resourceRequest,
        reason: entry.key,
      );
    }
    final chat = parser.notification(
      _resourceRow('resource_chat_message_received'),
    );
    expect(chat.resourceChatId, _chatId);
    expect(chat.resourceChatMessageId, _messageId);
    expect(chat.resourceAgreementId, _agreementId);
    final milestone = parser.notification(
      _resourceRow('resource_exchange_milestone_recorded'),
    );
    expect(milestone.resourceAgreementEventId, _eventId);
    expect(
      milestone.resourceExchangeEventKind,
      ResourceNotificationEventKind.resourceProvided,
    );
    expect(
      milestone.resourceExchangeLegKind,
      ResourceNotificationLegKind.ownerResource,
    );
  });

  test('required Resource fields and UUIDs fail closed', () {
    final valid = _resourceRow('resource_request_received');
    for (final field in [
      'resource_listing_id',
      'resource_listing_title',
      'resource_request_id',
      'actor_profile_id',
    ]) {
      expect(
        () => parser.notification({...valid, field: null}),
        throwsFormatException,
        reason: field,
      );
    }
    for (final field in [
      'resource_listing_id',
      'resource_request_id',
      'resource_chat_id',
      'resource_chat_message_id',
      'resource_agreement_id',
      'resource_agreement_event_id',
    ]) {
      final row = _resourceRow('resource_exchange_milestone_recorded');
      row[field] = 'not-a-uuid';
      expect(
        () => parser.notification(row),
        throwsFormatException,
        reason: field,
      );
    }
    expect(
      () => parser.notification({...valid, 'resource_listing_title': '  '}),
      throwsFormatException,
    );
  });

  test('request, acceptance, and chat shapes reject missing or extra IDs', () {
    for (final kind in [
      'resource_request_received',
      'resource_request_withdrawn',
      'resource_request_rejected',
      'resource_request_listing_closed',
    ]) {
      final valid = _resourceRow(kind);
      expect(
        () => parser.notification({...valid, 'resource_chat_id': _chatId}),
        throwsFormatException,
        reason: kind,
      );
      expect(
        () => parser.notification({
          ...valid,
          'destination_kind': 'resource_chat',
        }),
        throwsFormatException,
        reason: kind,
      );
    }
    for (final kind in [
      'resource_request_accepted',
      'resource_chat_message_received',
    ]) {
      final valid = _resourceRow(kind);
      for (final field in ['resource_chat_id', 'resource_agreement_id']) {
        expect(
          () => parser.notification({...valid, field: null}),
          throwsFormatException,
          reason: '$kind $field',
        );
      }
      expect(
        () => parser.notification({
          ...valid,
          'resource_agreement_event_id': _eventId,
        }),
        throwsFormatException,
      );
      expect(
        () => parser.notification({
          ...valid,
          'resource_chat_message_id': kind == 'resource_request_accepted'
              ? _messageId
              : null,
        }),
        throwsFormatException,
      );
    }
  });

  test('exchange kinds require exact event and milestone leg consistency', () {
    const events = <String, String>{
      'resource_exchange_terms_proposed': 'terms_proposed',
      'resource_exchange_terms_accepted': 'terms_accepted',
      'resource_exchange_terms_rejected': 'terms_rejected',
      'resource_exchange_terms_withdrawn': 'terms_withdrawn',
      'resource_exchange_cancelled': 'agreement_cancelled',
      'resource_exchange_completed': 'agreement_completed',
    };
    for (final entry in events.entries) {
      final valid = _resourceRow(entry.key);
      expect(
        parser.notification(valid).resourceExchangeEventKind,
        ResourceNotificationEventKind.fromWire(entry.value),
      );
      for (final field in [
        'resource_chat_id',
        'resource_agreement_id',
        'resource_agreement_event_id',
        'resource_exchange_event_kind',
      ]) {
        expect(
          () => parser.notification({...valid, field: null}),
          throwsFormatException,
          reason: '${entry.key} $field',
        );
      }
      expect(
        () => parser.notification({
          ...valid,
          'resource_exchange_event_kind': 'terms_proposed' == entry.value
              ? 'terms_accepted'
              : 'terms_proposed',
        }),
        throwsFormatException,
      );
      expect(
        () => parser.notification({
          ...valid,
          'resource_exchange_leg_kind': 'owner_resource',
        }),
        throwsFormatException,
      );
    }
    for (final event in [
      'resource_provided',
      'resource_received',
      'resource_returned',
      'resource_return_received',
    ]) {
      for (final leg in ['owner_resource', 'requester_resource']) {
        final row = _resourceRow('resource_exchange_milestone_recorded')
          ..['resource_exchange_event_kind'] = event
          ..['resource_exchange_leg_kind'] = leg;
        final parsed = parser.notification(row);
        expect(parsed.resourceExchangeEventKind?.isMilestone, isTrue);
        expect(parsed.resourceExchangeLegKind, isNotNull);
      }
    }
    final milestone = _resourceRow('resource_exchange_milestone_recorded');
    for (final changes in [
      {'resource_exchange_event_kind': 'terms_proposed'},
      {'resource_exchange_leg_kind': null},
      {'resource_exchange_leg_kind': 'future_leg'},
      {'resource_chat_message_id': _messageId},
    ]) {
      expect(
        () => parser.notification({...milestone, ...changes}),
        throwsFormatException,
      );
    }
  });

  test('known Project and Resource fields never mix', () {
    final resource = _resourceRow('resource_request_received');
    for (final field in [
      'project_id',
      'project_kind',
      'project_title',
      'request_id',
      'chat_id',
      'message_id',
    ]) {
      expect(
        () => parser.notification({...resource, field: 'future_value'}),
        throwsFormatException,
        reason: field,
      );
    }
    final project = _projectRow();
    for (final field in [
      'resource_listing_id',
      'resource_listing_title',
      'resource_request_id',
      'resource_chat_id',
      'resource_chat_message_id',
      'resource_agreement_id',
      'resource_agreement_event_id',
      'resource_exchange_event_kind',
      'resource_exchange_leg_kind',
    ]) {
      expect(
        () => parser.notification({...project, field: 'future_value'}),
        throwsFormatException,
        reason: field,
      );
    }
    expect(
      () => parser.notification({
        ...project,
        'notification_kind': 'resource_request_received',
      }),
      throwsFormatException,
    );
  });

  test('unknown Resource kind stays generic but known malformed rows fail', () {
    final unknown = parser.notification(_resourceRow('resource_future_kind'));
    expect(unknown.category, NotificationCategory.resources);
    expect(unknown.kind, NotificationKind.unknown);
    expect(
      parser.notification({
        ..._resourceRow('resource_request_received'),
        'category_slug': 'future_category',
      }).category,
      NotificationCategory.unknown,
    );
    expect(
      () => parser.notification({
        ..._resourceRow('resource_exchange_completed'),
        'resource_exchange_event_kind': 'future_event',
      }),
      throwsFormatException,
    );
  });
}

const _notificationId = '00000000-0000-4000-8000-000000000001';
const _listingId = '00000000-0000-4000-8000-000000000501';
const _requestId = '00000000-0000-4000-8000-000000000502';
const _chatId = '00000000-0000-4000-8000-000000000503';
const _messageId = '00000000-0000-4000-8000-000000000504';
const _agreementId = '00000000-0000-4000-8000-000000000505';
const _eventId = '00000000-0000-4000-8000-000000000506';
const _actorId = '00000000-0000-4000-8000-000000000507';

Map<String, Object?> _resourceRow(String kind) {
  final requestOnly = const {
    'resource_request_received',
    'resource_request_withdrawn',
    'resource_request_rejected',
    'resource_request_listing_closed',
  }.contains(kind);
  final exchange = kind.startsWith('resource_exchange_');
  const events = <String, String>{
    'resource_exchange_terms_proposed': 'terms_proposed',
    'resource_exchange_terms_accepted': 'terms_accepted',
    'resource_exchange_terms_rejected': 'terms_rejected',
    'resource_exchange_terms_withdrawn': 'terms_withdrawn',
    'resource_exchange_milestone_recorded': 'resource_provided',
    'resource_exchange_cancelled': 'agreement_cancelled',
    'resource_exchange_completed': 'agreement_completed',
  };
  return {
    'notification_id': _notificationId,
    'category_slug': 'resources',
    'notification_kind': kind,
    'created_at': '2026-09-20T10:00:00Z',
    'read_at': null,
    'project_id': null,
    'project_kind': null,
    'project_title': null,
    'request_id': null,
    'chat_id': null,
    'message_id': null,
    'actor_profile_id': _actorId,
    'actor_display_name': 'Mario',
    'resource_listing_id': _listingId,
    'resource_listing_title': 'Power drill',
    'resource_request_id': _requestId,
    'destination_kind': requestOnly ? 'resource_request' : 'resource_chat',
    'resource_chat_id': requestOnly ? null : _chatId,
    'resource_chat_message_id': kind == 'resource_chat_message_received'
        ? _messageId
        : null,
    'resource_agreement_id': requestOnly ? null : _agreementId,
    'resource_agreement_event_id': exchange ? _eventId : null,
    'resource_exchange_event_kind': events[kind],
    'resource_exchange_leg_kind': kind == 'resource_exchange_milestone_recorded'
        ? 'owner_resource'
        : null,
  };
}

Map<String, Object?> _projectRow() => {
  'notification_id': _notificationId,
  'category_slug': 'participation',
  'notification_kind': 'participation_request_received',
  'created_at': '2026-09-20T10:00:00Z',
  'read_at': null,
  'project_id': _listingId,
  'project_kind': 'one_time',
  'project_title': 'Garden',
  'request_id': _requestId,
  'chat_id': null,
  'message_id': null,
  'actor_profile_id': _actorId,
  'actor_display_name': 'Mario',
  'destination_kind': 'participation_request',
};
