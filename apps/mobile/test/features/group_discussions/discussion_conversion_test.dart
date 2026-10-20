import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_conversion.dart';

const actor = '00000000-0000-4000-8000-000000000001';
const room = '00000000-0000-4000-8000-000000000002';
const project = '00000000-0000-4000-8000-000000000003';
Map<String, Object?> projection() => {
  'profile_id': actor,
  'room_id': room,
  'state': 'none',
  'can_propose': true,
  'can_review': false,
  'can_publish': false,
};

void main() {
  test('ordinary Idea creator may propose without publishing authority', () {
    final value = DiscussionConversion(projection(), actor: actor, room: room);
    expect(value.canPropose, isTrue);
    expect(value.canPublish, isFalse);
    expect(value.projectId, isNull);
  });
  test('scope mismatch is rejected before any destination can render', () {
    expect(
      () => DiscussionConversion(
        {...projection(), 'profile_id': room},
        actor: actor,
        room: room,
      ),
      throwsFormatException,
    );
    expect(
      () => DiscussionConversion(
        {...projection(), 'room_id': project},
        actor: actor,
        room: room,
      ),
      throwsFormatException,
    );
  });
  test('another publisher private draft can have no disclosed Project id', () {
    final value = DiscussionConversion(
      {
        ...projection(),
        'state': 'draft',
        'version': 2,
        'title': 'Garden',
        'summary': 'Plan a garden',
        'can_open_draft': false,
      },
      actor: actor,
      room: room,
    );
    expect(value.projectId, isNull);
    expect(value.canOpenDraft, isFalse);
  });
  test('published source requires its canonical Project destination', () {
    expect(
      () => DiscussionConversion(
        {
          ...projection(),
          'state': 'published',
          'version': 3,
          'title': 'Garden',
          'summary': 'Plan a garden',
        },
        actor: actor,
        room: room,
      ),
      throwsFormatException,
    );
  });
  test('published source does not imply Project chat entitlement', () {
    final value = DiscussionConversion(
      {
        ...projection(),
        'state': 'published',
        'version': 3,
        'title': 'Garden',
        'summary': 'Plan a garden',
        'project_id': project,
        'project_chat_id': null,
      },
      actor: actor,
      room: room,
    );
    expect(value.projectId, project);
    expect(value.projectChatId, isNull);
  });
  test('Project invitation rejects private origin metadata', () {
    final invitation = {
      'invitation_id': room,
      'project_id': project,
      'title': 'Garden',
      'summary': 'Plan a garden',
      'status': 'pending',
      'created_at': '2026-10-15T12:00:00Z',
    };
    expect(DiscussionProjectInvitation(invitation).projectId, project);
    expect(
      () => DiscussionProjectInvitation({...invitation, 'room_id': room}),
      throwsFormatException,
    );
  });
  test(
    'opening invitation calls only ordinary public Project projection command',
    () async {
      final calls = <String>[];
      final gateway = DiscussionConversionGateway((name, params) async {
        calls.add(name);
        expect(params['p_response'], 'opened');
        expect(params.keys, isNot(contains('p_room_id')));
        return project;
      });
      expect(await gateway.respond(actor, room, 'opened'), project);
      expect(calls, ['respond_discussion_project_invitation']);
    },
  );
  test(
    'invitation paging preserves paired timestamp and identity cursor',
    () async {
      final gateway = DiscussionConversionGateway((name, params) async {
        expect(name, 'list_my_discussion_project_invitations');
        expect(params['p_limit'], 25);
        expect(params['p_before_id'], room);
        expect(params['p_before_created_at'], '2026-10-15T12:00:00Z');
        return <Object?>[];
      });
      expect(
        await gateway.invitations(
          actor,
          cursor: {
            'p_before_id': room,
            'p_before_created_at': '2026-10-15T12:00:00Z',
          },
        ),
        isEmpty,
      );
    },
  );
}
