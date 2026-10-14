import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';
import 'package:planets_mobile/features/group_contact/domain/group_contact_models.dart';
import 'package:planets_mobile/features/group_coordination/domain/coordination_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';

import '../group_contact/contact_fixtures.dart';

const extraGroup = '00000000-0000-4000-8000-000000000203';
const extraPerson = '00000000-0000-4000-8000-000000000103';
Map<String, dynamic> coordinationRow({
  bool named = false,
  bool metadata = false,
}) => {
  'item_kind': 'group_coordination_proposal',
  'proposal_id': requestId,
  'viewer_role': 'delegate',
  'status': 'pending',
  'version': 2,
  'created_at': time,
  'activity_at': time,
  'expires_at': '2026-10-21T08:00:00Z',
  'resolved_at': null,
  'title': metadata ? null : 'Fresh fictional coordination',
  'request_message': metadata ? null : 'Only a fresh shared synthetic note.',
  'requester_profile_id': metadata ? null : peer,
  'requester_display_name': metadata ? null : 'Fictional Bob',
  'groups': metadata
      ? []
      : [
          {'group_id': source, 'group_name': 'Garden', 'is_claimed': true},
          {'group_id': target, 'group_name': 'Workshop', 'is_claimed': true},
          {
            'group_id': extraGroup,
            'group_name':
                'Fictional Laboratorio del quartiere con un nome molto lungo',
            'is_claimed': named,
          },
        ],
  'audience': named
      ? [
          {
            'profile_id': peer,
            'group_id': source,
            'group_name': 'Garden',
            'display_name': 'Fictional Bob',
            'active': true,
            'confirmed': true,
          },
          {
            'profile_id': extraPerson,
            'group_id': target,
            'group_name': 'Workshop',
            'display_name': 'Fictional Carol',
            'active': true,
            'confirmed': true,
          },
          {
            'profile_id': actor,
            'group_id': extraGroup,
            'group_name':
                'Fictional Laboratorio del quartiere con un nome molto lungo',
            'display_name': 'Fictional Alice',
            'active': true,
            'confirmed': false,
          },
        ]
      : [],
  'audience_disclosed': named,
  'all_seats_named': named,
  'claimable_group_ids': named || metadata ? [] : [extraGroup],
  'own_group_id': named ? extraGroup : null,
  'own_confirmed': false,
  'can_confirm': named,
  'can_change_audience': false,
  'can_cancel': false,
  'can_decline': !metadata,
  'source_chat_id': null,
  'chat_id': null,
};
void main() {
  test(
    'Requests v3 parses a separate proposal without inherited source or unread',
    () {
      final item = const MessagesPayloadParser().item(
        coordinationRow(),
      ) as GroupCoordinationMessageItem;
      expect(item.kind, StructuredRequestItemKind.groupCoordinationProposal);
      expect(item.proposal.sourceChatId, isNull);
      expect(item.proposal.audience, isEmpty);
      expect(item.proposal.canConfirm, isFalse);
      expect(
        CoordinationProposal.parse(coordinationRow(metadata: true)).note,
        isNull,
      );
    },
  );
  test('rejects audience leakage, duplicate humans, and silent fields', () {
    final named = coordinationRow(named: true);
    expect(
      () => CoordinationProposal.parse({...named, 'audience_disclosed': false}),
      throwsFormatException,
    );
    expect(
      () => CoordinationProposal.parse({
        ...named,
        'audience': [
          ...(named['audience'] as List),
          (named['audience'] as List).last,
        ],
      }),
      throwsFormatException,
    );
    expect(
      () =>
          CoordinationProposal.parse({...coordinationRow(), 'old_history': []}),
      throwsFormatException,
    );
    expect(
      () => CoordinationProposal.parse({
        ...coordinationRow(metadata: true),
        'source_chat_id': chatId,
      }),
      throwsFormatException,
    );
    expect(
      () => CoordinationProposal.parse({...named, 'version': 0}),
      throwsFormatException,
    );
  });
  test(
    'coordination receipts require exact result/version and recover metadata',
    () {
      final r = ContactReceipt.parse({
        'coordination_id': requestId,
        'version': 3,
        'outcome': 'active',
        'chat_id': chatId,
        'replayed': true,
      });
      expect(r.coordinationId, requestId);
      expect(r.chatId, chatId);
      expect(
        () => ContactReceipt.parse({
          'coordination_id': requestId,
          'version': 3,
          'outcome': 'active',
          'replayed': true,
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'continuations accept only identifiers and never invitation/body queries',
    () {
      expect(
        sanitizeReturnDestination(
          '/messages/requests/group-coordination/$requestId',
        ),
        '/messages/requests/group-coordination/$requestId',
      );
      expect(
        sanitizeReturnDestination(
          '/messages/chats/group-contact/$chatId/coordinate',
        ),
        '/messages/chats/group-contact/$chatId/coordinate',
      );
      expect(
        sanitizeReturnDestination(
          '/messages/requests/group-coordination/$requestId?note=private',
        ),
        '/',
      );
      expect(
        sanitizeReturnDestination(
          '/messages/chats/group-contact/$chatId/coordinate?group=$source',
        ),
        '/',
      );
    },
  );
}
