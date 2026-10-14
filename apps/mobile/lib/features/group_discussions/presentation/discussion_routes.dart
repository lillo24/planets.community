String discussionRoute(String room) =>
    '/messages/discussions/${Uri.encodeComponent(room)}';
String discussionGroupRoute(String group) =>
    '/messages/discussions/groups/${Uri.encodeComponent(group)}';
String discussionCreateRoute(String group) =>
    '${discussionGroupRoute(group)}/create';
String discussionPeopleRoute(String room) => '${discussionRoute(room)}/people';
String discussionLinksRoute(String room) => '${discussionRoute(room)}/links';
String discussionLeaveRoute(String room, String admission) =>
    '${discussionRoute(room)}/leave/${Uri.encodeComponent(admission)}';
String discussionDeclineRoute(String room, String invitation) =>
    '${discussionRoute(room)}/decline/${Uri.encodeComponent(invitation)}';
bool isDiscussionExitPath(String path) => RegExp(
  r'^/messages/discussions/[0-9a-f-]{36}/(leave|decline)/[0-9a-f-]{36}$',
).hasMatch(path);
