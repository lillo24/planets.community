import '../../groups/domain/group_models.dart';

/// Source and Project rights are independent; only the actual author sees a
/// bound private draft ID. None of these fields grants Project admission.
class DiscussionConversion {
  DiscussionConversion(
    Object? value, {
    required String actor,
    required String room,
  }) {
    if (value is! Map ||
        value['profile_id'] != actor ||
        value['room_id'] != room) {
      throw const FormatException('Mismatched conversion scope.');
    }
    state = value['state'] as String;
    if (!{'none', 'proposed', 'draft', 'published'}.contains(state)) {
      throw const FormatException('Invalid conversion state.');
    }
    canPropose = groupBool(value['can_propose']);
    canReview = groupBool(value['can_review']);
    canPublish = groupBool(value['can_publish']);
    version = value['version'] as int?;
    title = value['title'] as String?;
    summary = value['summary'] as String?;
    review = value['review_status'] as String?;
    projectId = value['project_id'] == null
        ? null
        : groupUuid(value['project_id']);
    projectChatId = value['project_chat_id'] == null
        ? null
        : groupUuid(value['project_chat_id']);
    canOpenDraft = value['can_open_draft'] == true;
    canShareLinks = value['can_share_links'] == true;
    if (state != 'none' &&
        (version == null || version! < 1 || title == null || summary == null)) {
      throw const FormatException('Incomplete conversion proposal.');
    }
    if ((state == 'published' || canOpenDraft) && projectId == null ||
        projectChatId != null && state != 'published') {
      throw const FormatException('Invalid conversion destination.');
    }
  }
  late final String state;
  late final String? title, summary, review, projectId, projectChatId;
  late final int? version;
  late final bool canPropose,
      canReview,
      canPublish,
      canOpenDraft,
      canShareLinks;
}

class DiscussionProjectInvitation {
  DiscussionProjectInvitation(Object? value) {
    if (value is! Map ||
        value.keys.toSet().difference({
          'invitation_id',
          'project_id',
          'status',
          'created_at',
          'title',
          'summary',
        }).isNotEmpty) {
      throw const FormatException('Unexpected Project invitation projection.');
    }
    id = groupUuid(value['invitation_id']);
    projectId = groupUuid(value['project_id']);
    title = groupText(value['title'], 120);
    summary = groupText(value['summary'], 280);
    status = value['status'] as String;
    if (!{'pending', 'opened'}.contains(status))
      throw const FormatException('Invalid Project invitation status.');
    createdAt = groupDate(value['created_at']);
  }
  late final String id, projectId, title, summary, status;
  late final DateTime createdAt;
  Map<String, dynamic> get cursor => {
    'p_before_created_at': createdAt.toUtc().toIso8601String(),
    'p_before_id': id,
  };
}
