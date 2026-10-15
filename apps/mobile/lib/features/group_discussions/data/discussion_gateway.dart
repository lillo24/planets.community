import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/private_broadcast_payload.dart';
import '../../../core/backend/supabase_backend.dart';
import '../domain/discussion_models.dart';

enum DiscussionAction {
  create('create_group_discussion_v2'),
  join('join_group_discussion'),
  settings('set_group_discussion_settings'),
  preferences('set_group_discussion_preferences'),
  send('send_group_discussion_message'),
  invite('invite_group_discussion_member'),
  respond('respond_group_discussion_invitation'),
  withdraw('withdraw_group_discussion_invitation'),
  leave('leave_group_discussion'),
  remove('remove_group_discussion_member'),
  update('update_group_discussion_v2'),
  addLink('add_group_discussion_link_v2'),
  editLink('update_group_discussion_link_v2'),
  removeLink('remove_group_discussion_link_v2');

  const DiscussionAction(this.rpc);
  final String rpc;
}

abstract interface class DiscussionGateway {
  Future<List<DiscussionGroup>> groups(
    String actor,
    Map<String, dynamic>? cursor,
  );
  Future<List<DiscussionRoom>> rooms(
    String actor,
    String group,
    Map<String, dynamic>? cursor, {
    bool hidden = false,
  });
  Future<DiscussionSettings> settings(String actor, String group);
  Future<List<DiscussionInvitation>> invitations(
    String actor,
    Map<String, dynamic>? cursor,
  );
  Future<List<DiscussionPerson>> people(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  );
  Future<DiscussionRoom> room(String actor, String room);
  Future<List<DiscussionManagedInvitation>> managedInvitations(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  );
  Future<DiscussionHistory> history(String actor, String room, {int? before});
  Future<DiscussionReceipt> command(
    String actor,
    String key,
    DiscussionAction action,
    Map<String, dynamic> intent,
  );
  Stream<bool> signals(String actor);
  Stream<bool> groupSignals(String actor, String group);
}

class SupabaseDiscussionGateway implements DiscussionGateway {
  const SupabaseDiscussionGateway(this.client);
  final SupabaseClient client;
  Map<String, dynamic> expected(String actor) => {
    'p_expected_profile_id': actor,
  };
  Future<List<T>> page<T extends DiscussionPageRow>(
    String rpc,
    String actor,
    Map<String, dynamic> parameters,
    T Function(Object?) parse,
  ) async {
    final data = await client.rpc<Object?>(
      rpc,
      params: {...expected(actor), 'p_limit': 25, ...parameters},
    );
    if (data is! List || data.length > 25) {
      throw const FormatException('Invalid discussion page.');
    }
    final rows = data.map(parse).toList(growable: false);
    DateTime? date = parameters['p_before_created_at'] == null
        ? null
        : DateTime.parse(parameters['p_before_created_at'] as String);
    String? id = parameters['p_before_id'] as String?;
    for (final row in rows) {
      if (row is DiscussionRoom && row.isGeneral) {
        // Reserved General is first regardless of creation date.
        date = null;
        id = null;
        continue;
      }
      if (date != null &&
          (row.createdAt.isAfter(date) ||
              row.createdAt.isAtSameMomentAs(date) &&
                  row.id.compareTo(id!) >= 0)) {
        throw const FormatException('Invalid discussion cursor ordering.');
      }
      date = row.createdAt;
      id = row.id;
    }
    return List.unmodifiable(rows);
  }

  @override
  Future<List<DiscussionGroup>> groups(
    String actor,
    Map<String, dynamic>? cursor,
  ) => page('list_my_discussion_groups_v2', actor, {
    ...?cursor,
  }, DiscussionGroup.new);
  @override
  Future<List<DiscussionRoom>> rooms(
    String actor,
    String group,
    Map<String, dynamic>? cursor, {
    bool hidden = false,
  }) async {
    final rows = await page('list_group_discussions_v2', actor, {
      'p_group_id': group,
      'p_hidden': hidden,
      ...?cursor,
    }, DiscussionRoom.new);
    if (rows.any((r) => r.groupId != group)) {
      throw const FormatException('Mismatched discussion Group.');
    }
    return rows;
  }

  @override
  Future<DiscussionSettings> settings(String actor, String group) async =>
      DiscussionSettings(
        await client.rpc<Object?>(
          'get_group_discussion_settings',
          params: {...expected(actor), 'p_group_id': group},
        ),
      );
  @override
  Future<List<DiscussionInvitation>> invitations(
    String actor,
    Map<String, dynamic>? cursor,
  ) => page('list_group_discussion_invitations', actor, {
    ...?cursor,
  }, DiscussionInvitation.new);
  @override
  Future<List<DiscussionPerson>> people(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  ) => page('list_group_discussion_people', actor, {
    'p_room_id': room,
    ...?cursor,
  }, DiscussionPerson.new);
  @override
  Future<List<DiscussionManagedInvitation>> managedInvitations(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  ) => page('list_group_discussion_managed_invitations', actor, {
    'p_room_id': room,
    ...?cursor,
  }, DiscussionManagedInvitation.new);
  @override
  Future<DiscussionRoom> room(String actor, String room) async {
    final result = DiscussionRoom(
      await client.rpc<Object?>(
        'get_group_discussion_v2',
        params: {...expected(actor), 'p_room_id': room},
      ),
    );
    if (result.id != room) {
      throw const FormatException('Mismatched discussion room.');
    }
    return result;
  }

  @override
  Future<DiscussionHistory> history(
    String actor,
    String room, {
    int? before,
  }) async => DiscussionHistory(
    await client.rpc<Object?>(
      'get_group_discussion_message_page_v2',
      params: {
        ...expected(actor),
        'p_room_id': room,
        'p_limit': 30,
        'p_before_sequence': before,
      },
    ),
    newest: before == null,
    expectedActor: actor,
    expectedRoom: room,
    allowReadOnlySnapshot: true,
  );
  @override
  Future<DiscussionReceipt> command(
    String actor,
    String key,
    DiscussionAction action,
    Map<String, dynamic> intent,
  ) async => DiscussionReceipt(
    await client.rpc<Object?>(
      action.rpc,
      params: {...expected(actor), 'p_client_request_id': key, ...intent},
    ),
  );
  @override
  Stream<bool> signals(String actor) =>
      subscribe('group-discussions:profile:$actor', 'profile_id', actor);
  @override
  Stream<bool> groupSignals(String actor, String group) =>
      subscribe('group-discussions:group:$group', 'group_id', group);
  Stream<bool> subscribe(String topic, String field, String expectedId) {
    late final RealtimeChannel channel;
    late final StreamController<bool> events;
    events = StreamController<bool>(
      onListen: () {
        channel = client.channel(
          topic,
          opts: const RealtimeChannelConfig(private: true),
        );
        channel
            .onBroadcast(
              event: 'changed',
              callback: (value) {
                try {
                  final data = privateBroadcastPayload(value, 'changed', {
                    field,
                  });
                  if (data[field] != expectedId) {
                    throw const FormatException(
                      'Invalid discussion recipient.',
                    );
                  }
                  if (!events.isClosed) events.add(true);
                } on FormatException {
                  if (!events.isClosed) events.add(false);
                } on TypeError {
                  if (!events.isClosed) events.add(false);
                }
              },
            )
            .subscribe((state, _) {
              if (!events.isClosed) {
                events.add(state == RealtimeSubscribeStatus.subscribed);
              }
            });
      },
      onCancel: () async {
        await client.removeChannel(channel);
      },
    );
    return events.stream;
  }
}

final discussionGatewayProvider = Provider<DiscussionGateway>(
  (ref) => SupabaseDiscussionGateway(ref.watch(supabaseClientProvider)),
);
