import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';

void main() {
  const parser = MessagesPayloadParser();

  test('strictly discriminates Project and Resource request rows', () {
    final project = parser.item(_projectRow());
    final resource = parser.item(_resourceRow());

    expect(project, isA<ParticipationRequestMessageItem>());
    expect(resource, isA<ResourceRequestMessageItem>());
    expect(
      (resource as ResourceRequestMessageItem).status,
      ResourceRequestStatus.pending,
    );
    expect(resource.viewerRole, MessageViewerRole.owner);
  });

  test('cross-domain fields and invalid Resource anchors fail closed', () {
    expect(
      () => parser.item({..._projectRow(), 'resource_listing_id': _listingId}),
      throwsFormatException,
    );
    expect(
      () => parser.item(
        _resourceRow(status: 'accepted', resolvedAt: '2026-09-18T11:00:00Z'),
      ),
      throwsFormatException,
    );
  });

  test('Resource statuses and accepted coordination anchors stay typed', () {
    for (final wire in ['rejected', 'withdrawn', 'listing_closed']) {
      final item = parser.item(
        _resourceRow(status: wire, resolvedAt: '2026-09-18T11:00:00Z'),
      ) as ResourceRequestMessageItem;
      expect(item.status.wireValue, wire);
      expect(item.chatId, isNull);
    }
    final accepted = parser.item(
      _resourceRow(
        status: 'accepted',
        resolvedAt: '2026-09-18T11:00:00Z',
        acceptedAnchors: true,
      ),
    ) as ResourceRequestMessageItem;
    expect(accepted.status, ResourceRequestStatus.accepted);
    expect(accepted.chatId, isNotNull);
    expect(accepted.agreementId, isNotNull);
  });

  test('unknown structured kinds fail safely', () {
    expect(
      () => parser.item({..._projectRow(), 'item_kind': 'group_invite'}),
      throwsFormatException,
    );
  });

  test('strictly parses skill and resource contribution selections', () {
    final skill = parser.contributionSelection({
      'selection_kind': 'skill',
      'selection_id': 'skill-1',
      'label': 'Carpentry',
    });
    final resource = parser.contributionSelection({
      'selection_kind': 'resource',
      'selection_id': 'need-1',
      'label': 'Wooden boards',
    });

    expect(skill.kind, RequestContributionSelectionKind.skill);
    expect(resource.kind, RequestContributionSelectionKind.resource);
    expect(resource.label, 'Wooden boards');
  });

  test('unknown selection kinds and malformed rows fail safely', () {
    expect(
      () => parser.contributionSelection({
        'selection_kind': 'free_text',
        'selection_id': 'selection-1',
        'label': 'Anything',
      }),
      throwsFormatException,
    );
    expect(() => parser.contributionSelection([]), throwsFormatException);
  });

  test('Messages selection source calls only the authorized B1 RPC', () {
    final source = File('lib/features/messages/data/messages_gateway.dart')
        .readAsStringSync();
    expect(
      source,
      contains("'list_own_project_join_request_contribution_selections'"),
    );
    expect(
      source,
      isNot(contains(".from('project_join_request_skill_selections')")),
    );
    expect(
      source,
      isNot(contains(".from('project_join_request_resource_selections')")),
    );
  });

  test('Messages list and exact reads use only the unified C2 RPCs', () {
    final source = File('lib/features/messages/data/messages_gateway.dart')
        .readAsStringSync();
    expect(source, contains("'list_own_structured_request_message_items'"));
    expect(source, contains("'get_own_structured_request_message_item'"));
    expect(source, contains("'p_cursor_item_kind'"));
    expect(
      source,
      isNot(contains("'list_own_participation_request_messages'")),
    );
  });
}

const _requestId = '00000000-0000-4000-8000-000000000301';
const _listingId = '00000000-0000-4000-8000-000000000201';

Map<String, dynamic> _commonRow() => {
  'request_id': _requestId,
  'viewer_role': 'requester',
  'requester_profile_id': '00000000-0000-4000-8000-000000000102',
  'requester_display_name': 'Jordan',
  'request_message': 'I can help.',
  'status': 'pending',
  'created_at': '2026-09-18T10:00:00Z',
  'resolved_at': null,
  'activity_at': '2026-09-18T10:00:00Z',
};

Map<String, dynamic> _projectRow() => {
  ..._commonRow(),
  'item_kind': 'participation_request',
  'project_id': '00000000-0000-4000-8000-000000000401',
  'project_kind': 'one_time',
  'project_title': 'Paint the square',
  'project_creator_profile_id': '00000000-0000-4000-8000-000000000101',
  'project_creator_display_name': 'Casey',
  'resource_listing_id': null,
  'resource_listing_mode': null,
  'resource_listing_title': null,
  'resource_listing_lifecycle': null,
  'resource_owner_profile_id': null,
  'resource_owner_display_name': null,
  'resource_chat_id': null,
  'resource_agreement_id': null,
  'coordination_closed_at': null,
};

Map<String, dynamic> _resourceRow({
  String status = 'pending',
  String? resolvedAt,
  bool acceptedAnchors = false,
}) => {
  ..._commonRow(),
  'item_kind': 'resource_request',
  'viewer_role': 'owner',
  'status': status,
  'resolved_at': resolvedAt,
  'project_id': null,
  'project_kind': null,
  'project_title': null,
  'project_creator_profile_id': null,
  'project_creator_display_name': null,
  'resource_listing_id': _listingId,
  'resource_listing_mode': 'donate',
  'resource_listing_title': 'Garden tools',
  'resource_listing_lifecycle': 'published',
  'resource_owner_profile_id': '00000000-0000-4000-8000-000000000101',
  'resource_owner_display_name': 'Casey',
  'resource_chat_id': acceptedAnchors
      ? '00000000-0000-4000-8000-000000000501'
      : null,
  'resource_agreement_id': acceptedAnchors
      ? '00000000-0000-4000-8000-000000000601'
      : null,
  'coordination_closed_at': null,
};
