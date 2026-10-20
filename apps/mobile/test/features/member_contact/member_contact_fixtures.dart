const actor = '00000000-0000-4000-8000-000000000101';
const peer = '00000000-0000-4000-8000-000000000102';
const group = '00000000-0000-4000-8000-000000000201';
const requestId = '00000000-0000-4000-8000-000000000301';
const chatId = '00000000-0000-4000-8000-000000000401';
const messageId = '00000000-0000-4000-8000-000000000501';
const episode = '00000000-0000-4000-8000-000000000601';
const boundary = '00000000-0000-4000-8000-000000000701';
const time = '2026-10-15T08:00:00Z';

Map<String, dynamic> contextRow({bool eligible = true}) => {
  'group_id': group,
  'group_name': 'Fictional shared garden',
  'recipient_profile_id': peer,
  'recipient_display_name': 'Fictional Bob',
  'can_request': eligible,
};
Map<String, dynamic> requestRow({
  bool incoming = false,
  String status = 'pending',
}) => {
  'item_kind': 'member_contact_request',
  'request_id': requestId,
  'group_id': group,
  'group_name': 'Fictional shared garden',
  'sender_profile_id': incoming ? peer : actor,
  'sender_display_name': incoming ? 'Fictional Bob' : 'Fictional Alice',
  'recipient_profile_id': incoming ? actor : peer,
  'recipient_display_name': incoming ? 'Fictional Alice' : 'Fictional Bob',
  'request_message': 'A fictional private introduction',
  'status': status,
  'created_at': time,
  'activity_at': time,
  'expires_at': '2026-10-22T08:00:00Z',
  'chat_id': status == 'accepted' ? chatId : null,
  'episode_id': status == 'accepted' ? episode : null,
  'can_accept': incoming && status == 'pending',
  'can_decline': incoming && status == 'pending',
  'can_withdraw': !incoming && status == 'pending',
};
Map<String, dynamic> messageRow({int ordinal = 1}) => {
  'id': messageId,
  'chat_id': chatId,
  'episode_id': episode,
  'sender_profile_id': peer,
  'sender_display_name': 'Fictional Bob',
  'body': 'Fictional received message',
  'ordinal': ordinal,
  'created_at': time,
};
Map<String, dynamic> chatRow({
  bool readOnly = false,
  bool muted = false,
  String activeEpisode = episode,
}) => {
  'item_kind': 'member_contact_chat',
  'chat_id': chatId,
  'group_id': group,
  'group_name': 'Fictional shared garden',
  'peer_profile_id': peer,
  'peer_display_name': 'Fictional Bob',
  'created_at': time,
  'activity_at': time,
  'is_read_only': readOnly,
  'current_episode_id': readOnly ? null : activeEpisode,
  'ended_reason': readOnly ? 'closed' : null,
  'muted': muted,
  'latest_message': messageRow(),
  'unread_count': 1,
};
Map<String, dynamic> receipt(String outcome) => {
  'group_id': group,
  'request_id': requestId,
  'chat_id': outcome == 'requested' ? null : chatId,
  'episode_id': outcome == 'requested' ? null : episode,
  'message_id': outcome == 'sent' ? messageId : null,
  'outcome': outcome,
  'current_status': outcome == 'requested' ? 'pending' : 'active',
  'replayed': false,
};
