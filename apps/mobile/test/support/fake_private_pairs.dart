import 'package:planets_mobile/features/messages/data/private_pair_gateway.dart';

const pairActor = 'a1010000-0000-4000-8000-000000000001';
const pairPeer = 'a1010000-0000-4000-8000-000000000002';
const pairSource = 'a1020000-0000-4000-8000-000000000001';
const pairBoundary = 'a1090000-0000-4000-8000-000000000001';

Map<String, dynamic> pairRow({
  String actor = pairActor,
  String peer = pairPeer,
  String name = 'Marco',
  int unread = 3,
}) {
  final endpoints = [actor, peer]..sort();
  return {
    'peer_profile_id': peer,
    'display_name': name,
    'pair_key': endpoints.join(':'),
    'activity_at': '2026-10-24T10:00:00Z',
    'is_read_only': false,
    'latest_activity_kind': 'message',
    'last_message_id': 'a1080000-0000-4000-8000-000000000001',
    'last_message_body': 'Tools ready for Saturday',
    'last_sender_profile_id': peer,
    'last_sender_display_name': name,
    'unread_count': unread,
  };
}

Map<String, dynamic> pairContext({
  String kind = 'resource_chat',
  String id = pairSource,
  String title = 'Garden tools',
  bool send = true,
  String? episode,
}) => {
  'kind': kind,
  'id': id,
  'source_id': id,
  'title': title,
  'status': kind == 'participation_request'
      ? (send ? 'pending' : 'accepted')
      : (send ? 'open' : 'closed'),
  'can_send': send,
  'episode_id': episode,
  'created_at': '2026-10-24T09:00:00Z',
};
Map<String, dynamic> pairMessage({
  String kind = 'resource_message',
  String sourceKind = 'resource_chat',
  String source = pairSource,
  String sender = pairPeer,
  String body = 'Tools ready for Saturday',
  int n = 1,
}) => {
  'item_kind': kind,
  'item_id': 'a1080000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
  'source_kind': sourceKind,
  'source_id': source,
  'sender_profile_id': sender,
  'sender_display_name': 'Marco',
  'body': body,
  'created_at': DateTime.utc(2026, 10, 24, 10, n).toIso8601String(),
  'ordinal': n,
  'context_id': source,
  'context_kind': null,
  'title': null,
  'status': null,
  'management_id': null,
};
Map<String, dynamic> pairPage(
  List<Map<String, dynamic>> items, {
  bool newest = true,
  String actor = pairActor,
  String peer = pairPeer,
}) => {
  'profile_id': actor,
  'peer_profile_id': peer,
  'display_name': 'Marco',
  'has_resource_coordination': false,
  'items': items,
  'read_boundary': newest ? pairBoundary : null,
};

/// Explicit canonical server fixture. It does not aggregate legacy client pages.
PrivatePairGateway emptyPrivatePairs() =>
    PrivatePairGateway((name, args) async {
      if (name == 'list_own_private_pairs_v1') return [];
      throw StateError('Unexpected personal RPC in empty fixture: $name');
    });
