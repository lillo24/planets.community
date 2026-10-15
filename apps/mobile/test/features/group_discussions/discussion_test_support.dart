import 'dart:async';

import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';

const actor = '00000000-0000-4000-8000-000000000001',
    roomId = '00000000-0000-4000-8000-000000000002',
    groupId = '00000000-0000-4000-8000-000000000003',
    admission = '00000000-0000-4000-8000-000000000004';
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Map<String, dynamic> roomRow({String episode = admission}) => {
  'kind': 'group_discussion',
  'room_id': roomId,
  'group_id': groupId,
  'group_name': 'Trento Green',
  'title': 'Parco',
  'archived': false,
  'version': 1,
  'created_at': '2026-10-14T10:00:00Z',
  'admission_id': episode,
  'can_manage': true,
  'can_publish': true,
  'unread_count': 2,
  'preview': null,
};
DiscussionGroup discussionGroupFixture(int n) => DiscussionGroup({
  'group_id': id(n),
  'name': 'Trento Green ${n.toString()}',
  'created_at': '2026-10-14T10:00:00Z',
  'room_count': 1,
  'unread_count': 2,
});
Map<String, dynamic> messageRow(int n) => {
  'message_id': id(n),
  'sequence': n,
  'sender_id': groupId,
  'sender_name': null,
  'body': 'Message $n',
  'created_at': '2026-10-14T10:00:00Z',
};
Map<String, dynamic> historyRow(
  List<int> numbers, {
  bool newest = true,
  String episode = admission,
}) => {
  'items': numbers.map(messageRow).toList(),
  'snapshot_token': newest && numbers.isNotEmpty
      ? '${numbers.first}:${id(numbers.first)}:${List.filled(64, 'a').join()}'
      : null,
  'profile_id': actor,
  'room_id': roomId,
  'admission_id': episode,
};
DiscussionHistory discussionHistoryFixture(
  List<int> numbers, {
  bool newest = true,
  String episode = admission,
}) => DiscussionHistory(
  historyRow(numbers, newest: newest, episode: episode),
  newest: newest,
  expectedActor: actor,
  expectedRoom: roomId,
);
DiscussionReceipt receipt() => DiscussionReceipt({
  'room_id': roomId,
  'object_id': admission,
  'version': 1,
  'sequence': 1,
});

class Session extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: actor));
  void change(String? value) {
    state = value == null
        ? const AuthSessionState.signedOut()
        : AuthSessionState.ready(AuthIdentity(id: value));
  }
}

class Gateway implements DiscussionGateway {
  int groupReads = 0, roomReads = 0, historyReads = 0;
  final hints = StreamController<bool>.broadcast();
  DiscussionRoom context = DiscussionRoom(roomRow());
  DiscussionHistory latest = discussionHistoryFixture([2, 1]);
  Future<DiscussionHistory> Function(int?)? historyFetch;
  Future<DiscussionReceipt> Function(String, Map<String, dynamic>)? write;
  final keys = <String>[];
  @override
  Stream<bool> groupSignals(String actor, String group) => const Stream.empty();
  @override
  Future<DiscussionSettings> settings(String actor, String group) async =>
      DiscussionSettings({
        'group_id': group,
        'creation_policy': 'managers',
        'version': 1,
        'can_edit': true,
        'can_create': true,
        'general_room_id': null,
      });
  @override
  Future<List<DiscussionGroup>> groups(
    String a,
    Map<String, dynamic>? cursor,
  ) async {
    groupReads++;
    return [discussionGroupFixture(3)];
  }

  @override
  Future<List<DiscussionRoom>> rooms(
    String a,
    String g,
    Map<String, dynamic>? cursor, {
    bool hidden = false,
  }) async {
    roomReads++;
    return [context];
  }

  @override
  Future<List<DiscussionInvitation>> invitations(
    String a,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<List<DiscussionPerson>> people(
    String a,
    String r,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<List<DiscussionManagedInvitation>> managedInvitations(
    String a,
    String r,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<DiscussionRoom> room(String a, String r) async => context;
  @override
  Future<DiscussionHistory> history(String a, String r, {int? before}) async {
    historyReads++;
    return historyFetch == null ? latest : await historyFetch!(before);
  }

  @override
  Future<DiscussionReceipt> command(
    String a,
    String key,
    DiscussionAction action,
    Map<String, dynamic> intent,
  ) async {
    keys.add(key);
    return write == null ? receipt() : await write!(key, intent);
  }

  @override
  Stream<bool> signals(String a) => hints.stream;
}
