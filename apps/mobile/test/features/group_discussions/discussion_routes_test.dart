import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';

import 'discussion_test_support.dart';

void main() {
  test('only exact own exit/decline destinations bypass content readiness', () {
    expect(
      isDiscussionExitPath(discussionLeaveRoute(roomId, admission)),
      isTrue,
    );
    expect(
      isDiscussionExitPath(discussionDeclineRoute(roomId, admission)),
      isTrue,
    );
    for (final path in [
      discussionRoute(roomId),
      discussionPeopleRoute(roomId),
      discussionCreateRoute(groupId),
      '${discussionLeaveRoute(roomId, admission)}/extra',
      '/messages/discussions/wrong/leave/wrong',
    ]) {
      expect(isDiscussionExitPath(path), isFalse);
    }
  });
  test(
    'safe room destination survives Auth without permitting external redirects',
    () {
      final path = discussionRoute(roomId);
      expect(sanitizeReturnDestination(path), path);
      expect(sanitizeReturnDestination('https://outside.invalid$path'), '/');
    },
  );
}
