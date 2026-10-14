import '../../groups/domain/group_models.dart';
import '../../project_workspace/domain/project_workspace_models.dart';
import 'discussion_models.dart';

/// Room-owned destination. Only validation/classification is shared with Projects.
class DiscussionLink with DiscussionCursor {
  DiscussionLink(
    Object? value, {
    required String actor,
    required String room,
    required String admission,
  }) {
    final r = discussionObject(value, {
      'profile_id',
      'room_id',
      'admission_id',
      'link_id',
      'name',
      'url',
      'version',
      'created_at',
      'updated_at',
    });
    if (groupUuid(r['profile_id']) != actor ||
        groupUuid(r['room_id']) != room ||
        groupUuid(r['admission_id']) != admission) {
      throw const FormatException('Mismatched discussion link scope.');
    }
    id = groupUuid(r['link_id']);
    roomId = room;
    admissionId = admission;
    name = groupText(r['name'], 120);
    if (validateProjectWorkspaceName(name) != name) {
      throw const FormatException('Invalid discussion link name.');
    }
    final raw = groupText(r['url'], 2048);
    url = ProjectWorkspaceUrl.parse(raw);
    if (url.value != raw) {
      throw const FormatException('Noncanonical discussion destination.');
    }
    version = discussionCount(r['version'], minimum: 1);
    createdAt = groupDate(r['created_at']);
    updatedAt = groupDate(r['updated_at']);
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('Invalid discussion link dates.');
    }
  }
  @override
  late final String id;
  late final String roomId, admissionId, name;
  late final ProjectWorkspaceUrl url;
  late final int version;
  @override
  late final DateTime createdAt;
  late final DateTime updatedAt;
}

class DiscussionLinkPage {
  DiscussionLinkPage(
    Object? value, {
    required String actor,
    required String room,
    String? admission,
    Map<String, dynamic>? cursor,
  }) {
    final r = discussionObject(value, {
      'profile_id',
      'room_id',
      'admission_id',
      'archived',
      'can_manage',
      'items',
    });
    if (groupUuid(r['profile_id']) != actor ||
        groupUuid(r['room_id']) != room) {
      throw const FormatException('Mismatched discussion collection.');
    }
    admissionId = groupUuid(r['admission_id']);
    if (admission != null && admission != admissionId) {
      throw const FormatException('Changed discussion admission.');
    }
    archived = groupBool(r['archived']);
    canManage = groupBool(r['can_manage']);
    if (archived && canManage) {
      throw const FormatException('Inconsistent discussion link manager.');
    }
    final data = r['items'];
    if (data is! List || data.length > 25) {
      throw const FormatException('Invalid discussion link page.');
    }
    items = List.unmodifiable(
      data.map(
        (v) =>
            DiscussionLink(v, actor: actor, room: room, admission: admissionId),
      ),
    );
    DateTime? date = cursor == null
        ? null
        : groupDate(cursor['p_before_created_at']);
    String? id = cursor?['p_before_id'] as String?;
    for (final item in items) {
      if (date != null &&
          (item.createdAt.isAfter(date) ||
              item.createdAt.isAtSameMomentAs(date) &&
                  item.id.compareTo(id!) >= 0)) {
        throw const FormatException('Unordered discussion link page.');
      }
      date = item.createdAt;
      id = item.id;
    }
  }
  late final String admissionId;
  late final bool archived, canManage;
  late final List<DiscussionLink> items;
}
