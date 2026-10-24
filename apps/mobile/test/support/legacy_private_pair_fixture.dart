// Compatibility presentation fixtures for pre-A1 tests. This simulates the
// canonical server response from their explicit source fixtures; production never
// groups client pages. Independent SQL/real-HTTP tests own aggregation correctness.
import 'package:planets_mobile/features/messages/data/private_pair_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_message_chats.dart';
import 'fake_private_pairs.dart';
import 'fake_project_request_chat.dart';
import 'fake_resource_chat.dart';

PrivatePairGateway legacyPrivatePairFixture({
  required String actor,
  required FakeMessageChatsGateway chats,
  required FakeResourceChatGateway resource,
  required FakeProjectRequestChatGateway requests,
}) {
  List<Map<String, dynamic>> rows() {
    final groups = <String, List<MessageChatItem>>{};
    final seen = <String>{};
    for (final item in chats.items) {
      final peer = switch (item) {
        ResourceMessageChatItem i => i.counterpartyProfileId,
        ProjectRequestMessageChatItem i => i.counterpartyProfileId,
        _ => null,
      };
      if (peer == null || !seen.add(item.compositeId)) continue;
      (groups[peer] ??= []).add(item);
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final sources = entry.value
        ..sort((a, b) => b.activityAt.compareTo(a.activityAt));
      final latest = sources.first;
      final name = switch (latest) {
        ResourceMessageChatItem i => i.counterpartyDisplayName,
        ProjectRequestMessageChatItem i => i.counterpartyDisplayName,
        _ => throw StateError('Not personal'),
      };
      result.add({
        ...pairRow(
          actor: actor,
          peer: entry.key,
          name: name,
          unread: sources.fold(0, (n, i) => n + i.unreadCount),
        ),
        'activity_at': latest.activityAt.toUtc().toIso8601String(),
        'is_read_only': sources.every((i) => i.isReadOnly),
        'last_message_id': latest.lastVisibleMessageId,
        'last_message_body': latest.lastVisibleMessageBody,
        'last_sender_profile_id': latest.lastVisibleSenderProfileId,
        'last_sender_display_name': latest.lastVisibleSenderDisplayName,
        'latest_activity_kind':
            latest is ProjectRequestMessageChatItem &&
                latest.latestRequestActivityStatus != null
            ? 'context'
            : latest.lastVisibleMessageId == null
            ? 'empty'
            : 'message',
      });
    }
    result.sort((a, b) {
      final time = (b['activity_at'] as String).compareTo(
        a['activity_at'] as String,
      );
      return time != 0
          ? time
          : (b['peer_profile_id'] as String).compareTo(
              a['peer_profile_id'] as String,
            );
    });
    return result;
  }

  Future<({String peer, String name, Map<String, dynamic> context})> source(
    String kind,
    String id,
  ) async {
    if (kind == 'resource_chat') {
      final r = await resource.getChat(expectedProfileId: actor, chatId: id);
      if (r.chatId != id ||
          ![r.ownerProfileId, r.requesterProfileId].contains(actor)) {
        throw const PostgrestException(
          message: 'Unavailable source',
          code: '42501',
        );
      }
      final owner = r.ownerProfileId == actor;
      return (
        peer: owner ? r.requesterProfileId : r.ownerProfileId,
        name: owner ? r.requesterDisplayName : r.ownerDisplayName,
        context: pairContext(
          kind: kind,
          id: id,
          title: r.listingTitle,
          send: r.hasSendEntitlement,
        ),
      );
    }
    if (kind == 'participation_request') {
      final r = await requests.getChat(expectedProfileId: actor, requestId: id);
      if (![r.creatorProfileId, r.requesterProfileId].contains(actor)) {
        throw const PostgrestException(
          message: 'Unavailable source',
          code: '42501',
        );
      }
      final creator = r.creatorProfileId == actor;
      return (
        peer: creator ? r.requesterProfileId : r.creatorProfileId,
        name: creator ? r.requesterDisplayName : r.creatorDisplayName,
        context: {
          ...pairContext(
            kind: kind,
            id: id,
            title: r.projectTitle,
            send: r.hasSendEntitlement,
          ),
          'source_id': r.chatId,
        },
      );
    }
    throw const PostgrestException(
      message: 'Unavailable source',
      code: '42501',
    );
  }

  ({String peer, String name, Map<String, dynamic> context})? resolved;
  return PrivatePairGateway((name, args) async {
    if (name == 'list_own_private_pairs_v1') {
      chats.calls.add('private-pair-list');
      chats.requestedLimits.add(20);
      if (chats.delay case final delay?) await delay;
      if (chats.error case final error?) throw error;
      final all = rows(), before = args['p_before_peer_id'];
      final start = before == null
          ? 0
          : all.indexWhere((r) => r['peer_profile_id'] == before) + 1;
      return all.skip(start).take(args['p_limit'] as int).toList();
    }
    if (name == 'resolve_own_private_pair_v1') {
      resolved = await source(
        args['p_context_kind'] as String,
        args['p_context_id'] as String,
      );
      return {
        'profile_id': actor,
        'peer_profile_id': resolved!.peer,
        'context_kind': args['p_context_kind'],
        'context_id': args['p_context_id'],
        'context': resolved!.context,
      };
    }
    if (name == 'get_own_private_pair_page_v1' ||
        name == 'list_own_private_pair_contexts_v1') {
      final peer = args['p_peer_profile_id'];
      if (resolved == null) {
        final item = chats.items
            .where(
              (i) => switch (i) {
                ResourceMessageChatItem r => r.counterpartyProfileId == peer,
                ProjectRequestMessageChatItem r =>
                  r.counterpartyProfileId == peer,
                _ => false,
              },
            )
            .firstOrNull;
        resolved = switch (item) {
          ResourceMessageChatItem r => await source('resource_chat', r.chatId),
          ProjectRequestMessageChatItem r => await source(
            'participation_request',
            r.requestId,
          ),
          _ => null,
        };
      }
      if (resolved?.peer != peer) {
        throw const PostgrestException(
          message: 'Unavailable pair',
          code: '42501',
        );
      }
      if (name == 'list_own_private_pair_contexts_v1') {
        return args['p_only_writable'] == true &&
                resolved!.context['can_send'] == false
            ? []
            : [resolved!.context];
      }
      return {
        ...pairPage([], actor: actor, peer: peer as String),
        'display_name': resolved!.name,
      };
    }
    throw StateError(
      'Unexpected A1 operation in legacy presentation fixture: $name',
    );
  });
}
