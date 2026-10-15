const actor = '00000000-0000-4000-8000-000000000101';
const peer = '00000000-0000-4000-8000-000000000102';
const source = '00000000-0000-4000-8000-000000000201';
const target = '00000000-0000-4000-8000-000000000202';
const requestId = '00000000-0000-4000-8000-000000000301';
const chatId = '00000000-0000-4000-8000-000000000401';
const messageId = '00000000-0000-4000-8000-000000000501';
const token = '00000000-0000-4000-8000-000000000601';
const time = '2026-10-14T08:00:00Z';
Map<String, dynamic> requestRow({
  String viewer = 'requester',
  bool metadata = false,
  String status = 'pending',
  String? chat,
}) => {
  'item_kind': 'group_contact_request',
  'request_id': requestId,
  'viewer_role': viewer,
  'status': status,
  'created_at': time,
  'resolved_at': status == 'pending' ? null : time,
  'expires_at': '2026-10-21T08:00:00Z',
  'activity_at': time,
  'purpose': metadata ? null : 'idea',
  'title': metadata ? null : 'A fictional group proposal',
  'request_message': metadata ? null : 'Private fictional contact note',
  'source_group_id': metadata ? null : source,
  'target_group_id': metadata ? null : target,
  'source_group_name': metadata ? null : 'Garden',
  'target_group_name': metadata ? null : 'Workshop',
  'requester_profile_id': metadata ? null : actor,
  'requester_display_name': metadata ? null : 'Fictional Alice',
  'public_project_id': null,
  'public_project_kind': null,
  'public_project_title': null,
  'can_review': viewer == 'delegate' && status == 'pending' && !metadata,
  'can_withdraw': viewer == 'requester' && status == 'pending',
  'chat_id': chat,
};
Map<String, dynamic> chatRow({bool list = false, bool readOnly = false}) => {
  'item_kind': 'group_contact_chat',
  'chat_id': chatId,
  'conversation_kind': 'bilateral',
  'display_title': 'A fictional collaboration',
  'summary': 'A fresh private conversation summary',
  'activity_at': time,
  'created_at': time,
  'is_read_only': readOnly,
  'closed_at': null,
  'audience': [
    {
      'profile_id': actor,
      'group_id': source,
      'group_name': 'Garden',
      'display_name': 'Fictional Alice',
      'active': true,
    },
    {
      'profile_id': peer,
      'group_id': target,
      'group_name': 'Workshop',
      'display_name': 'Fictional Bob',
      'active': true,
    },
  ],
  'last_visible_message_id': null,
  'last_visible_message_body': null,
  'last_visible_message_at': null,
  'last_visible_sender_profile_id': null,
  'last_visible_sender_display_name': null,
  if (list) 'unread_count': 0,
};
Map<String, dynamic> messageRow({int ordinal = 1}) => {
  'id': messageId,
  'chat_id': chatId,
  'sender_profile_id': peer,
  'sender_display_name': 'Fictional Bob',
  'represented_group_id': target,
  'group_name_at_send': 'Workshop at send time',
  'body': 'Private fictional human message',
  'ordinal': ordinal,
  'created_at': time,
};
Map<String, dynamic> groupRow(String id, String name) => {
  'id': id,
  'name': name,
  'created_at': time,
  'authority_role': 'co_organizer',
};
Map<String, dynamic> ownRole() => {
  'authority_role': null,
  'delegate_id': null,
  'current_membership_id': null,
  'membership_status': null,
};
