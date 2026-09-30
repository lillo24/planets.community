import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';

void main() {
  const parser = ResourceRequestPayloadParser();
  const contract = ResourceRequestRpcContract();

  test(
    'optional message accepts blank and the exact 500-character boundary',
    () {
      expect(isValidResourceRequestMessage(''), isTrue);
      expect(
        isValidResourceRequestMessage(List.filled(500, 'x').join()),
        isTrue,
      );
      expect(
        isValidResourceRequestMessage(List.filled(501, 'x').join()),
        isFalse,
      );
    },
  );

  test('strict parser preserves canonical status and active-request rules', () {
    final pending = parser.own(_row());
    final accepted = parser.own(
      _row(status: 'accepted', resolvedAt: '2026-09-18T11:00:00Z'),
    );
    final closedAccepted = parser.own(
      _row(
        status: 'accepted',
        resolvedAt: '2026-09-18T11:00:00Z',
        coordinationClosedAt: '2026-09-19T11:00:00Z',
      ),
    );

    expect(pending.status, ResourceRequestStatus.pending);
    expect(pending.isActive, isTrue);
    expect(accepted.isActive, isTrue);
    expect(closedAccepted.isActive, isFalse);
  });

  test('parser preserves every terminal status', () {
    for (final wire in ['rejected', 'withdrawn', 'listing_closed']) {
      final item = parser.own(
        _row(status: wire, resolvedAt: '2026-09-18T11:00:00Z'),
      );
      expect(item.status.wireValue, wire);
      expect(item.isActive, isFalse);
    }
  });

  test('exact parser includes both counterparties', () {
    final item = parser.exact({
      ..._row(),
      'requester_profile_id': '00000000-0000-4000-8000-000000000102',
      'requester_display_name': 'Jordan',
    });

    expect(item.ownerDisplayName, 'Casey');
    expect(item.requesterDisplayName, 'Jordan');
    expect(
      item.viewerRoleFor('00000000-0000-4000-8000-000000000101'),
      ResourceRequestViewerRole.owner,
    );
  });

  test('malformed UUIDs and inconsistent lifecycle timestamps fail closed', () {
    expect(
      () => parser.own({..._row(), 'request_id': 'not-a-uuid'}),
      throwsFormatException,
    );
    expect(
      () => parser.own(_row(status: 'accepted', resolvedAt: null)),
      throwsFormatException,
    );
  });

  test(
    'request contract trims optional copy and binds expected identities',
    () {
      expect(
        contract.createParams(
          expectedRequesterProfileId: 'requester',
          listingId: 'listing',
          message: '  hello  ',
        ),
        {
          'p_expected_requester_profile_id': 'requester',
          'p_listing_id': 'listing',
          'p_message': 'hello',
        },
      );
      expect(
        contract.createParams(
          expectedRequesterProfileId: 'requester',
          listingId: 'listing',
          message: '   ',
        )['p_message'],
        isNull,
      );
      expect(
        contract.requesterMutationParams(
          expectedRequesterProfileId: 'requester',
          requestId: 'request',
        ),
        {
          'p_expected_requester_profile_id': 'requester',
          'p_request_id': 'request',
        },
      );
      expect(
        contract.ownerMutationParams(
          expectedOwnerProfileId: 'owner',
          requestId: 'request',
        ),
        {'p_expected_owner_profile_id': 'owner', 'p_request_id': 'request'},
      );
      expect(
        contract.exactParams(
          expectedProfileId: 'profile',
          requestId: 'request',
        ),
        {'p_expected_profile_id': 'profile', 'p_request_id': 'request'},
      );
    },
  );

  test(
    'Resource requests use authorized mutations plus unified exact read',
    () {
      final source = File(
        'lib/features/resource_requests/data/resource_request_gateway.dart',
      ).readAsStringSync();
      for (final rpc in [
        'request_resource_listing',
        'withdraw_resource_listing_request',
        'accept_resource_listing_request',
        'reject_resource_listing_request',
        'list_own_resource_listing_requests',
        'get_own_structured_request_message_item',
      ]) {
        expect(source, contains("'$rpc'"));
      }
      expect(source, isNot(contains(".from('resource_listing_requests')")));
    },
  );

  test('unified exact read carries accepted conversation anchors', () {
    final row = {
      'item_kind': 'resource_request',
      'request_id': '00000000-0000-4000-8000-000000000301',
      'viewer_role': 'owner',
      'requester_profile_id': '00000000-0000-4000-8000-000000000102',
      'requester_display_name': 'Jordan',
      'status': 'accepted',
      'request_message': 'Could I use these this weekend?',
      'created_at': '2026-09-18T10:00:00Z',
      'resolved_at': '2026-09-18T11:00:00Z',
      'activity_at': '2026-09-18T11:00:00Z',
      'project_id': null,
      'project_kind': null,
      'project_title': null,
      'project_creator_profile_id': null,
      'project_creator_display_name': null,
      'resource_listing_id': '00000000-0000-4000-8000-000000000201',
      'resource_listing_mode': 'donate',
      'resource_listing_title': 'Garden tools',
      'resource_listing_lifecycle': 'published',
      'resource_owner_profile_id': '00000000-0000-4000-8000-000000000101',
      'resource_owner_display_name': 'Casey',
      'resource_chat_id': '00000000-0000-4000-8000-000000000401',
      'resource_agreement_id': '00000000-0000-4000-8000-000000000501',
      'coordination_closed_at': null,
    };

    final request = const ResourceRequestPayloadParser().exact(row);

    expect(request.chatId, '00000000-0000-4000-8000-000000000401');
    expect(request.agreementId, '00000000-0000-4000-8000-000000000501');
  });
}

Map<String, dynamic> _row({
  String status = 'pending',
  Object? resolvedAt = _unset,
  String? coordinationClosedAt,
}) => {
  'request_id': '00000000-0000-4000-8000-000000000301',
  'listing_id': '00000000-0000-4000-8000-000000000201',
  'listing_mode': 'donate',
  'listing_title': 'Garden tools',
  'listing_lifecycle': 'published',
  'owner_profile_id': '00000000-0000-4000-8000-000000000101',
  'owner_display_name': 'Casey',
  'status': status,
  'request_message': 'Could I use these this weekend?',
  'created_at': '2026-09-18T10:00:00Z',
  'resolved_at': identical(resolvedAt, _unset) ? null : resolvedAt,
  'coordination_closed_at': coordinationClosedAt,
};

const _unset = Object();
