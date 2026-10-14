import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/backend/private_broadcast_payload.dart';
import '../domain/group_contact_models.dart';

typedef ContactRpc = Future<Object?> Function(String, Map<String, dynamic>);
const contactPageSize = 20;
bool contactAccessDenied(Object error) =>
    error is PostgrestException && error.code == '42501';

class GroupContactGateway {
  const GroupContactGateway(this.call, {this.signalClient});
  final ContactRpc call;
  final SupabaseClient? signalClient;
  Future<String> senderName(String actor) async {
    final row = contactRow(
      await call('get_own_group_contact_sender', {
        'p_expected_profile_id': actor,
      }),
      const {'profile_id', 'display_name'},
    );
    if (contactUuid(row['profile_id']) != actor) {
      throw const FormatException('Mismatched contact sender.');
    }
    return contactText(row['display_name'], 120);
  }

  Future<String?> targetRole(String actor, String group) async {
    final value = await call('get_own_group_role', {
      'p_expected_profile_id': actor,
      'p_group_id': group,
    });
    if (value is! List || value.length != 1) {
      throw const FormatException('Malformed own group context.');
    }
    final row = contactRow(value.single, const {
      'authority_role',
      'delegate_id',
      'current_membership_id',
      'membership_status',
    });
    final role = row['authority_role'];
    if (role != null &&
        !{'creator', 'co_creator', 'co_organizer'}.contains(role)) {
      throw const FormatException('Unsupported own role.');
    }
    return role as String?;
  }

  Future<List<ContactGroup>> groups(String actor, {ContactGroup? after}) async {
    final value = await call('list_my_contact_groups', {
      'p_expected_profile_id': actor,
      'p_limit': contactPageSize + 1,
      'p_cursor_created_at': after?.createdAt.toUtc().toIso8601String(),
      'p_cursor_id': after?.id,
    });
    if (value is! List || value.length > contactPageSize + 1) {
      throw const FormatException('Unbounded represented groups.');
    }
    return value.map(ContactGroup.parse).toList(growable: false);
  }

  Future<GroupContactRequest> request(String actor, String id) async {
    final result = GroupContactRequest.parse(
      await call('get_own_group_contact_request', {
        'p_expected_profile_id': actor,
        'p_request_id': id,
      }),
    );
    if (result.id != id) {
      throw const FormatException('Mismatched contact request.');
    }
    return result;
  }

  Future<GroupContactConversation> conversation(String actor, String id) async {
    final result = GroupContactConversation.parse(
      await call('get_own_group_contact_conversation', {
        'p_expected_profile_id': actor,
        'p_chat_id': id,
      }),
    );
    if (result.id != id) {
      throw const FormatException('Mismatched contact conversation.');
    }
    return result;
  }

  Future<ContactFeedPage> feed(
    String actor,
    String id, {
    ContactHumanMessage? before,
  }) async => ContactFeedPage.parse(
    await call('get_own_group_contact_feed', {
      'p_expected_profile_id': actor,
      'p_chat_id': id,
      'p_limit': contactPageSize + 1,
      'p_before_ordinal': before?.ordinal,
      'p_before_id': before?.id,
    }),
    contactPageSize,
    id,
  );
  Future<ContactReceipt> submit(
    String actor,
    String action,
    String source,
    String target,
    GroupContactPurpose purpose,
    String title,
    String note, {
    String? project,
  }) async => ContactReceipt.parse(
    await call('submit_group_contact_request', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_source_group_id': source,
      'p_target_group_id': target,
      'p_purpose': purpose.wireValue,
      'p_title': title,
      'p_note': note,
      'p_public_project_id': project,
    }),
  );
  Future<ContactReceipt> decide(
    String actor,
    String action,
    String request,
    String operation,
  ) async {
    if (!{'accept', 'decline', 'withdraw'}.contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }
    return ContactReceipt.parse(
      await call('${operation}_group_contact_request', {
        'p_expected_profile_id': actor,
        'p_action_id': action,
        'p_request_id': request,
      }),
    );
  }

  Future<ContactReceipt> send(
    String actor,
    String action,
    String chat,
    String body,
  ) async => ContactReceipt.parse(
    await call('send_group_contact_message', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_chat_id': chat,
      'p_body': body,
    }),
  );
  Future<ContactReceipt> exit(
    String actor,
    String action,
    String chat, {
    required bool leave,
  }) async => ContactReceipt.parse(
    await call('${leave ? 'leave' : 'close'}_group_contact_conversation', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_chat_id': chat,
    }),
  );
  Future<ContactReceipt?> recover(String actor, String action) async {
    final value = await call('recover_group_contact_action', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
    });
    return value == null ? null : ContactReceipt.parse(value);
  }

  Future<bool> hasOwnAdmission(String actor, String chat) async => contactBool(
    await call('has_own_group_contact_admission', {
      'p_expected_profile_id': actor,
      'p_chat_id': chat,
    }),
  );

  ContactSignalSubscription? subscribe(
    String actor,
    void Function() invalidate,
    void Function(bool) connection, {
    void Function()? accessChanged,
  }) {
    final client = signalClient;
    if (client == null) {
      return null;
    }
    final channel = client.channel(
      'group-contact:profile:$actor',
      opts: const RealtimeChannelConfig(private: true),
    );
    channel
        .onBroadcast(
          event: 'group.contact_changed',
          callback: (value) {
            try {
              final payload = privateBroadcastPayload(
                value,
                'group.contact_changed',
                const {'profile_id'},
              );
              if (contactUuid(payload['profile_id']) != actor) {
                throw const FormatException(
                  'Mismatched contact signal recipient.',
                );
              }
              invalidate();
            } on FormatException {
              connection(false);
            } on TypeError {
              connection(false);
            }
          },
        )
        .onBroadcast(
          event: 'group.contact_access_changed',
          callback: (value) {
            try {
              final payload = privateBroadcastPayload(
                value,
                'group.contact_access_changed',
                const {'profile_id'},
              );
              if (contactUuid(payload['profile_id']) != actor) {
                throw const FormatException(
                  'Mismatched contact access recipient.',
                );
              }
              accessChanged?.call();
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
    return ContactSignalSubscription(client, channel);
  }
}

class ContactSignalSubscription {
  ContactSignalSubscription(this.client, this.channel);
  final SupabaseClient client;
  final RealtimeChannel channel;
  Future<void> close() async {
    await client.removeChannel(channel);
  }
}

final groupContactGatewayProvider = Provider<GroupContactGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return GroupContactGateway(
    (name, args) => client.rpc<Object?>(name, params: args),
    signalClient: client,
  );
});
