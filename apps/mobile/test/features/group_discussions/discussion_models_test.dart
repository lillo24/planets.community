import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';

import 'discussion_test_support.dart';

void main() {
  test('strict room kind, authority and nullable identity contracts', () {
    expect(DiscussionRoom(roomRow()).canPublish, isTrue);
    expect(DiscussionMessage(messageRow(1)).senderName, isNull);
    for (final change in [
      {'kind': 'project'},
      {'can_manage': false},
      {'archived': true},
      {'version': '1'},
      {'roster': []},
    ]) {
      expect(
        () => DiscussionRoom({...roomRow(), ...change}),
        throwsFormatException,
      );
    }
  });
  test('read snapshot binds actor, room, admission, newest sequence and exact token', () {
    final row = historyRow([2, 1]);
    expect(discussionHistoryFixture([2, 1]).messages.length, 2);
    for (final change in [
      {'profile_id': groupId},
      {'room_id': groupId},
      {'admission_id': 'wrong'},
      {
        'items': [messageRow(1), messageRow(2)],
      },
      {'snapshot_token': '1:${id(1)}:${List.filled(64, 'a').join()}'},
      {'roster': []},
    ]) {
      expect(
        () => DiscussionHistory(
          {...row, ...change},
          newest: true,
          expectedActor: actor,
          expectedRoom: roomId,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => DiscussionHistory(
        row,
        newest: false,
        expectedActor: actor,
        expectedRoom: roomId,
      ),
      throwsFormatException,
    );
    expect(discussionHistoryFixture([], newest: true).token, isNull);
  });
  test(
    'C report uses separate typed endpoint arguments without foreign context',
    () {
      const target = ModerationReportTarget(
        kind: ModerationTargetKind.groupDiscussionMessage,
        id: roomId,
        label: 'Parco',
      );
      final params = const ModerationRpcContract().submitParams(
        expectedProfileId: actor,
        clientSubmissionId: groupId,
        category: ModerationCategory.spam,
        explanation: ' Fictional report ',
        target: target,
      );
      expect(params, {
        'p_expected_reporter_profile_id': actor,
        'p_client_submission_id': groupId,
        'p_category': 'spam',
        'p_explanation': 'Fictional report',
        'p_message_id': roomId,
      });
      expect(
        ModerationTargetKind.fromWire('group_discussion_message'),
        target.kind,
      );
      expect(
        () => const ModerationRpcContract().submitParams(
          expectedProfileId: actor,
          clientSubmissionId: groupId,
          category: ModerationCategory.spam,
          explanation: 'Report',
          target: const ModerationReportTarget(
            kind: ModerationTargetKind.groupDiscussionMessage,
            id: roomId,
            label: 'Parco',
            contextKind: ModerationContextKind.project,
            contextId: groupId,
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
