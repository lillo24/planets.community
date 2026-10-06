import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/backend/private_broadcast_payload.dart';
import '../domain/message_unread_models.dart';

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
  const SupabaseMessageUnreadGateway(this.client);
  final SupabaseClient client;
  @override
  Future<MessageUnreadSummary> summary(String profileId) async =>
      MessageUnreadSummary.parse(
        await client.rpc<Object?>(
          'get_own_message_unread_summary',
          params: {'p_expected_profile_id': profileId},
        ),
      );
  @override
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  ) async => MessageUnreadSummary.parse(
    await client.rpc<Object?>(
      'acknowledge_own_message_read',
      params: {
        'p_expected_profile_id': profileId,
        'p_kind': kind,
        'p_chat_id': chatId,
        'p_boundary': boundary,
      },
    ),
  );
  @override
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  ) {
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
        .subscribe(
          (status, _) =>
              connection(status == RealtimeSubscribeStatus.subscribed),
        );
    return _UnreadSubscription(client, channel);
  }
}

class _UnreadSubscription implements MessageUnreadSubscription {
  _UnreadSubscription(this.client, this.channel);
  final SupabaseClient client;
  final RealtimeChannel channel;
  @override
  Future<void> close() async {
    await client.removeChannel(channel);
  }
}

final messageUnreadGatewayProvider = Provider<MessageUnreadGateway>(
  (ref) => SupabaseMessageUnreadGateway(ref.watch(supabaseClientProvider)),
);
