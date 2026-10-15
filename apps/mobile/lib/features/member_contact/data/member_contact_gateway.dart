import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/backend/private_broadcast_payload.dart';
import '../../group_contact/data/group_contact_gateway.dart'
    show ContactRpc, ContactSignalSubscription;
import '../../group_contact/domain/group_contact_models.dart' show contactUuid;
import '../domain/member_contact_models.dart';

const memberContactPageSize = 20;

class MemberContactGateway {
  const MemberContactGateway(this.call, {this.signalClient});
  final ContactRpc call;
  final SupabaseClient? signalClient;

  Future<MemberContactContext> context(
    String actor,
    String group,
    String recipient,
  ) async {
    final result = MemberContactContext(
      await call('get_own_member_contact_context', {
        'p_expected_profile_id': actor,
        'p_group_id': group,
        'p_recipient_profile_id': recipient,
      }),
    );
    if (result.groupId != group || result.recipientId != recipient) {
      throw const FormatException('Mismatched member context.');
    }
    return result;
  }

  Future<MemberContactRequest> request(String actor, String request) async {
    final result = MemberContactRequest(
      await call('get_own_member_contact_request', {
        'p_expected_profile_id': actor,
        'p_request_id': request,
      }),
    );
    if (result.id != request ||
        (result.senderId != actor && result.recipientId != actor)) {
      throw const FormatException('Mismatched member request.');
    }
    return result;
  }

  Future<MemberContactConversation> conversation(
    String actor,
    String chat,
  ) async {
    final result = MemberContactConversation(
      await call('get_own_member_contact_conversation', {
        'p_expected_profile_id': actor,
        'p_chat_id': chat,
      }),
    );
    if (result.id != chat || result.peerId == actor) {
      throw const FormatException('Mismatched member conversation.');
    }
    return result;
  }

  Future<MemberContactFeed> feed(
    String actor,
    String chat, {
    MemberContactMessage? before,
  }) async => MemberContactFeed(
    await call('get_own_member_contact_feed', {
      'p_expected_profile_id': actor,
      'p_chat_id': chat,
      'p_limit': memberContactPageSize + 1,
      'p_before_ordinal': before?.ordinal,
      'p_before_id': before?.id,
    }),
    memberContactPageSize,
    chat,
    newest: before == null,
  );
  Future<MemberContactReceipt> submit(
    String actor,
    String action,
    String group,
    String recipient,
    String? note,
  ) async => MemberContactReceipt(
    await call('submit_member_contact_request', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_group_id': group,
      'p_recipient_profile_id': recipient,
      'p_note': note,
    }),
  );
  Future<MemberContactReceipt> decide(
    String actor,
    String action,
    String request,
    String operation,
  ) async {
    if (!{'accept', 'decline', 'withdraw'}.contains(operation)) {
      throw ArgumentError.value(operation);
    }
    return MemberContactReceipt(
      await call('${operation}_member_contact_request', {
        'p_expected_profile_id': actor,
        'p_action_id': action,
        'p_request_id': request,
      }),
    );
  }

  Future<MemberContactReceipt> send(
    String actor,
    String action,
    String chat,
    String episode,
    String body,
  ) async => MemberContactReceipt(
    await call('send_member_contact_message', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_chat_id': chat,
      'p_episode_id': episode,
      'p_body': body,
    }),
  );
  Future<MemberContactReceipt> exit(
    String actor,
    String action,
    String chat,
    String episode, {
    required bool leave,
  }) async => MemberContactReceipt(
    await call('${leave ? 'leave' : 'close'}_member_contact_conversation', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_chat_id': chat,
      'p_episode_id': episode,
    }),
  );
  Future<MemberContactReceipt> mute(
    String actor,
    String action,
    String chat,
    bool muted,
  ) async => MemberContactReceipt(
    await call('set_member_contact_muted', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_chat_id': chat,
      'p_muted': muted,
    }),
  );
  Future<MemberContactReceipt?> recover(String actor, String action) async {
    final value = await call('recover_member_contact_action', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
    });
    return value == null ? null : MemberContactReceipt(value);
  }

  ContactSignalSubscription? subscribe(
    String actor,
    void Function() invalidate,
    void Function(bool) connection, {
    void Function()? accessChanged,
  }) {
    final client = signalClient;
    if (client == null) return null;
    final channel = client.channel(
      'member-contact:profile:$actor',
      opts: const RealtimeChannelConfig(private: true),
    );
    for (final event in [
      'member.contact_changed',
      'member.contact_access_changed',
    ]) {
      channel.onBroadcast(
        event: event,
        callback: (value) {
          try {
            final payload = privateBroadcastPayload(value, event, const {
              'profile_id',
            });
            if (contactUuid(payload['profile_id']) != actor) {
              throw const FormatException('Mismatched member signal.');
            }
            if (event == 'member.contact_access_changed') accessChanged?.call();
            invalidate();
          } on FormatException {
            connection(false);
          } on TypeError {
            connection(false);
          }
        },
      );
    }
    channel.subscribe(
      (status, _) => connection(status == RealtimeSubscribeStatus.subscribed),
    );
    return ContactSignalSubscription(client, channel);
  }
}

final memberContactGatewayProvider = Provider<MemberContactGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MemberContactGateway(
    (name, args) => client.rpc<Object?>(name, params: args),
    signalClient: client,
  );
});
