import 'package:planets_mobile/features/group_discussions/data/discussion_projects_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';

/// Older chat/navigation fixtures deliberately have no registered Group rooms.
class EmptyDiscussionGateway implements DiscussionGateway {
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
    String actor,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<List<DiscussionRoom>> rooms(
    String actor,
    String group,
    Map<String, dynamic>? cursor, {
    bool hidden = false,
  }) async => [];
  @override
  Future<List<DiscussionInvitation>> invitations(
    String actor,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<List<DiscussionPerson>> people(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<List<DiscussionManagedInvitation>> managedInvitations(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  ) async => [];
  @override
  Future<DiscussionRoom> room(String actor, String room) async =>
      throw StateError('No C room belongs to this fixture.');
  @override
  Future<DiscussionHistory> history(
    String actor,
    String room, {
    int? before,
  }) async => throw StateError('No C history belongs to this fixture.');
  @override
  Future<DiscussionReceipt> command(
    String actor,
    String key,
    DiscussionAction action,
    Map<String, dynamic> intent,
  ) async => throw StateError('No C command belongs to this fixture.');
  @override
  Stream<bool> signals(String actor) => const Stream.empty();
}

class EmptyDiscussionProjectsGateway implements DiscussionProjectsGateway {
  @override Future<List<DiscussionProjectRow>> projects(String actor, String group, Map<String,dynamic>? cursor) async => [];
  @override Future<Set<String>> grouped(String actor, List<String> chats) async => {};
}
