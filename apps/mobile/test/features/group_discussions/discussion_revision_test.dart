import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/native_project_links.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';

import 'discussion_test_support.dart';

Map<String, dynamic> revised({
  String access = 'joined',
  String kind = 'idea',
}) => {
  ...roomRow(),
  'room_kind': kind,
  'visibility': 'group',
  'purpose': 'Plan a fictional shared garden.',
  'creator_id': actor,
  'access_id': access == 'discoverable' ? null : admission,
  'admission_id': access == 'discoverable' ? null : admission,
  'access': access,
  'can_join': access == 'discoverable',
  'can_send': access == 'joined' || access == 'general',
  'can_manage': access == 'joined',
  'can_publish': false,
  'can_invite': access == 'joined',
  'can_read_links': access != 'former' && access != 'discoverable',
  'muted': false,
  'manually_hidden': false,
  'automatically_hidden': false,
  'frozen': false,
  'invitation_link_version': 1,
  'preview': null,
  'unread_count': 0,
};
void main() {
  test('v2 history validates the canonical effective access envelope', () {
    final page = DiscussionHistory(
      {
        ...historyRow([2, 1]),
        'access_id': admission,
      },
      newest: true,
      expectedActor: actor,
      expectedRoom: roomId,
    );
    expect(page.admissionId, admission);
    expect(page.messages.map((message) => message.sequence), [2, 1]);
    expect(page.token, isNotNull);
    for (final malformed in [
      {
        ...historyRow([2, 1]),
        'access_id': id(9),
      },
      {
        ...historyRow([2, 1]),
        'access_id': null,
      },
      {
        ...historyRow([2, 1]),
        'access_id': admission,
        'extra': true,
      },
    ]) {
      expect(
        () => DiscussionHistory(
          malformed,
          newest: true,
          expectedActor: actor,
          expectedRoom: roomId,
        ),
        throwsFormatException,
      );
    }
  });

  test('discovery never fetches a transcript; deliberate admission opens full history', () async {
    final gateway = Gateway()
      ..context = DiscussionRoom(revised(access: 'discoverable'));
    final controller = DiscussionChatController(
      gateway,
      actor,
      roomId,
      () => true,
    );
    addTearDown(controller.dispose);
    addTearDown(gateway.hints.close);
    await controller.refresh();
    expect(controller.room!.canJoin, isTrue);
    expect(controller.messages, isEmpty);
    expect(gateway.historyReads, 0);
    gateway.context = DiscussionRoom(revised());
    await controller.refresh();
    expect(gateway.historyReads, 1);
    expect(controller.messages.map((m) => m.sequence), [1, 2]);
  });
  test('former frontier replaces cached current history and disables protected controls', () async {
    final gateway = Gateway()
      ..context = DiscussionRoom(revised())
      ..latest = discussionHistoryFixture([3, 2, 1]);
    final controller = DiscussionChatController(
      gateway,
      actor,
      roomId,
      () => true,
    );
    addTearDown(controller.dispose);
    addTearDown(gateway.hints.close);
    await controller.refresh();
    gateway.context = DiscussionRoom(revised(access: 'former'));
    gateway.latest = DiscussionHistory(
      {
        ...historyRow([2, 1]),
        'snapshot_token': null,
      },
      newest: true,
      expectedActor: actor,
      expectedRoom: roomId,
      allowReadOnlySnapshot: true,
    );
    await controller.refresh();
    expect(controller.messages.map((m) => m.sequence), [1, 2]);
    expect(controller.token, isNull);
    expect(controller.room!.canSend, isFalse);
    expect(controller.room!.canReadLinks, isFalse);
    expect(controller.room!.canReadPeople, isFalse);
    expect(controller.room!.canLeave, isFalse);
  });
  test(
    'General and manager oversight remain distinct from explicit admission',
    () {
      final general = DiscussionRoom({
        ...revised(access: 'general', kind: 'general'),
        'admission_id': null,
      });
      expect(general.canReadHistory, isTrue);
      expect(general.canLeave, isFalse);
      expect(general.canHide, isFalse);
      final oversight = DiscussionRoom({
        ...revised(access: 'oversight'),
        'admission_id': null,
        'can_manage': true,
      });
      expect(oversight.actualAdmissionId, isNull);
      expect(oversight.accessId, admission);
      expect(oversight.canLeave, isFalse);
      final discoverable = DiscussionRoom(revised(access: 'discoverable'));
      expect(discoverable.canHide, isTrue);
      expect(discoverable.canReadHistory, isFalse);
    },
  );
  test('Project-only folder exposes no implicit Idea audience', () {
    final folder = DiscussionGroup({
      'group_id': groupId,
      'name': 'Group',
      'created_at': '2026-10-15T00:00:00Z',
      'room_count': 0,
      'unread_count': 2,
      'can_read_ideas': false,
    });
    expect(folder.canReadIdeas, isFalse);
    expect(folder.roomCount, 0);
  });
  test('Idea capability native entry validates exact host, alphabet and shape', () {
    final token = List.filled(64, 'a').join(),
        path = '/messages/discussions/invite/${List.filled(64, 'a').join()}';
    expect(
      nativeProjectDestination(Uri.parse('https://planets.community$path')),
      path,
    );
    for (final url in [
      'https://evil.invalid$path',
      'https://planets.community$path?auto=join',
      'https://planets.community$path#x',
      'https://planets.community/messages/discussions/invite/${token}a',
      'http://planets.community$path',
      'https://planets.community/messages/discussions/invite/%2F${token.substring(1)}',
    ]) {
      expect(nativeProjectDestination(Uri.parse(url)), isNull, reason: url);
    }
  });
}
