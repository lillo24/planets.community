import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../messages/data/message_chats_gateway.dart';
import '../../messages/domain/message_chat_models.dart';
import '../../groups/domain/group_models.dart';
import '../domain/discussion_models.dart';

class DiscussionProjectRow implements DiscussionPageRow {
  DiscussionProjectRow(this.item);
  final ProjectMessageChatItem item;
  @override
  String get id => item.chatId;
  @override
  DateTime get createdAt => item.activityAt;
  @override
  Map<String, dynamic> get cursor => {
    'p_before_activity_at': item.activityAt.toUtc().toIso8601String(),
    'p_before_id': id,
  };
}

abstract interface class DiscussionProjectsGateway {
  Future<List<DiscussionProjectRow>> projects(
    String actor,
    String group,
    Map<String, dynamic>? cursor,
  );
  Future<Set<String>> grouped(String actor, List<String> chats);
}

class SupabaseDiscussionProjectsGateway implements DiscussionProjectsGateway {
  const SupabaseDiscussionProjectsGateway(this.client);
  final SupabaseClient client;
  @override
  Future<List<DiscussionProjectRow>> projects(
    String actor,
    String group,
    Map<String, dynamic>? cursor,
  ) async {
    final data = await client.rpc<Object?>(
      'list_group_project_conversations',
      params: {
        'p_expected_profile_id': actor,
        'p_group_id': group,
        'p_limit': 25,
        ...?cursor,
      },
    );
    if (data is! List || data.length > 25) {
      throw const FormatException('Invalid Group Project chat page.');
    }
    return data
        .map((row) {
          final item = const MessageChatsPayloadParser().item(row);
          if (item is! ProjectMessageChatItem) {
            throw const FormatException('Unexpected Group conversation.');
          }
          return DiscussionProjectRow(item);
        })
        .toList(growable: false);
  }

  @override
  Future<Set<String>> grouped(String actor, List<String> chats) async {
    final result = <String>{};
    // Bound each authorization query; never use public Group feed as entitlement.
    for (var offset = 0; offset < chats.length; offset += 25) {
      final chunk = chats.skip(offset).take(25).toList();
      final data = await client.rpc<Object?>(
        'list_own_group_project_chat_folders',
        params: {'p_expected_profile_id': actor, 'p_chat_ids': chunk},
      );
      if (data is! List || data.length > chunk.length) {
        throw const FormatException('Invalid Group chat mapping.');
      }
      for (final value in data) {
        final row = discussionObject(value, {
          'chat_id',
          'group_id',
          'group_name',
        });
        final id = groupUuid(row['chat_id']);
        groupUuid(row['group_id']);
        groupText(row['group_name'], 120);
        if (!chunk.contains(id) || !result.add(id)) {
          throw const FormatException('Mismatched Group chat mapping.');
        }
      }
    }
    return result;
  }
}

final discussionProjectsGatewayProvider = Provider<DiscussionProjectsGateway>(
  (ref) => SupabaseDiscussionProjectsGateway(ref.watch(supabaseClientProvider)),
);
