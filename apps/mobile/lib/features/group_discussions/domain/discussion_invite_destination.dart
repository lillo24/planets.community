import '../../groups/domain/group_models.dart';
import 'discussion_models.dart';

/// Minimal authorized destination; it contains no chat, roster or grant data.
class DiscussionInviteDestination with DiscussionCursor {
  DiscussionInviteDestination(Object? value, String group, String person) {
    final row = discussionObject(value, {
      'room_id',
      'group_id',
      'target_profile_id',
      'title',
      'purpose',
      'visibility',
      'created_at',
    });
    id = groupUuid(row['room_id']);
    groupId = groupUuid(row['group_id']);
    targetId = groupUuid(row['target_profile_id']);
    if (groupId != group || targetId != person) {
      throw const FormatException('Mismatched Idea invitation context.');
    }
    title = groupText(row['title'], 120);
    purpose = row['purpose'] == '' ? '' : groupText(row['purpose'], 500);
    visibility = groupText(row['visibility'], 20);
    if (!{'group', 'invitation'}.contains(visibility)) {
      throw const FormatException('Invalid Idea invitation audience.');
    }
    createdAt = groupDate(row['created_at']);
  }
  @override
  late final String id;
  late final String groupId, targetId, title, purpose, visibility;
  @override
  late final DateTime createdAt;
}

/// Scopes a retained invitation to [actor], [group], [room] and [person].
///
/// Both entry points keep unrelated intents separate. No command body is persisted.
String discussionInviteSlot(
  String actor,
  String group,
  String room,
  String person,
) => 'invite/$actor/$group/$room/$person';
