import '../../member_contact/data/member_contact_gateway.dart';
import '../../member_contact/application/member_contact_access_changes.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/backend/private_broadcast_payload.dart';
import '../domain/message_unread_models.dart';
import '../../group_contact/data/group_contact_gateway.dart';
import '../../group_contact/application/contact_access_changes.dart';

abstract interface class MessageUnreadSubscription {
  Future<void> close();
}

abstract interface class MessageUnreadGateway {
  Future<MessageUnreadSummary> summary(String profileId);
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  );
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  );
}

class SupabaseMessageUnreadGateway implements MessageUnreadGateway {
  const SupabaseMessageUnreadGateway(
    this.client, {
    this.contactAccessChanged,
    this.memberAccessChanged,
  });
  final SupabaseClient client;
  final void Function(String)? contactAccessChanged, memberAccessChanged;
  @override
  Future<MessageUnreadSummary> summary(String profileId) async =>
      MessageUnreadSummary.parse(
        await client.rpc<Object?>(
          'get_own_private_pair_unread_v1',
          params: {'p_expected_profile_id': profileId},
        ),
      );
  @override
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  ) async {
    if (kind == 'cocreate_contact') {
      await client.rpc<void>(
        'acknowledge_cocreate_contact',
        params: {
          'p_expected_profile_id': profileId,
          'p_contact_id': chatId,
          'p_read_token': boundary,
        },
      );
    } else if (kind == 'group_discussion') {
      await client.rpc<void>(
        'acknowledge_group_discussion_read_v2',
        params: {
          'p_expected_profile_id': profileId,
          'p_room_id': chatId,
          'p_snapshot_token': boundary,
        },
      );
    } else {
      await client.rpc<Object?>(
        'acknowledge_own_message_read_v3',
        params: {
          'p_expected_profile_id': profileId,
          'p_kind': kind,
          'p_chat_id': chatId,
          'p_boundary': boundary,
        },
      );
    }
    return summary(profileId);
  }

  @override
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  ) {
    var legacyConnected = false,
        contactConnected = false,
        memberConnected = false;
    void statusChanged() =>
        connection(legacyConnected && contactConnected && memberConnected);
    final contact =
        GroupContactGateway(
          (name, args) => client.rpc<Object?>(name, params: args),
          signalClient: client,
        ).subscribe(profileId, invalidate, (connected) {
          contactConnected = connected;
          statusChanged();
        }, accessChanged: () => contactAccessChanged?.call(profileId));
    final member =
        MemberContactGateway(
          (name, args) => client.rpc<Object?>(name, params: args),
          signalClient: client,
        ).subscribe(profileId, invalidate, (connected) {
          memberConnected = connected;
          statusChanged();
        }, accessChanged: () => memberAccessChanged?.call(profileId));
    final channel = client.channel(
      'message-unread:profile:$profileId',
      opts: const RealtimeChannelConfig(private: true),
    );
    channel
        .onBroadcast(
          event: 'messages.unread_changed',
          callback: (value) {
            try {
              final payload = privateBroadcastPayload(
                value,
                'messages.unread_changed',
                const {'profile_id'},
              );
              if (messageUnreadUuid(payload['profile_id']) != profileId) {
                throw const FormatException('Mismatched unread recipient.');
              }
              invalidate();
            } on FormatException {
              connection(false);
            } on TypeError {
              connection(false);
            }
          },
        )
        .subscribe((status, _) {
          legacyConnected = status == RealtimeSubscribeStatus.subscribed;
          statusChanged();
        });
    return _UnreadSubscription(client, channel, contact, member);
  }
}

class _UnreadSubscription implements MessageUnreadSubscription {
  _UnreadSubscription(this.client, this.channel, this.contact, this.member);
  final SupabaseClient client;
  final RealtimeChannel channel;
  final ContactSignalSubscription? contact, member;
  @override
  Future<void> close() async {
    await client.removeChannel(channel);
    await contact?.close();
    await member?.close();
  }
}

final messageUnreadGatewayProvider = Provider<MessageUnreadGateway>(
  (ref) => SupabaseMessageUnreadGateway(
    ref.watch(supabaseClientProvider),
    memberAccessChanged: (actor) =>
        ref.read(memberContactAccessChangesProvider.notifier).changed(actor),
    contactAccessChanged: (actor) =>
        ref.read(contactAccessChangesProvider.notifier).changed(actor),
  ),
);
