import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../group_contact/data/group_contact_gateway.dart';
import '../../group_contact/domain/group_contact_models.dart';
import '../domain/coordination_models.dart';

class CoordinationGateway {
  const CoordinationGateway(this.call);
  final ContactRpc call;
  Future<CoordinationProposal> proposal(String actor, String id) async {
    final p = CoordinationProposal.parse(
      await call('get_own_group_coordination_proposal', {
        'p_expected_profile_id': actor,
        'p_proposal_id': id,
      }),
    );
    if (p.id != id) {
      throw const FormatException('Mismatched coordination proposal.');
    }
    return p;
  }

  Future<CoordinationProposal?> context(String actor, String chat) async {
    final value = await call('get_own_group_coordination_for_conversation', {
      'p_expected_profile_id': actor,
      'p_chat_id': chat,
    });
    if (value == null) return null;
    final result = CoordinationProposal.parse(value);
    if (result.chatId != chat) {
      throw const FormatException('Mismatched coordination conversation.');
    }
    return result;
  }

  Future<ContactReceipt> submit(
    String actor,
    String action,
    String source,
    List<String> groups,
    String title,
    String note,
  ) async => ContactReceipt.parse(
    await call('submit_group_coordination_proposal', {
      'p_expected_profile_id': actor,
      'p_action_id': action,
      'p_source_chat_id': source,
      'p_group_ids': groups,
      'p_title': title,
      'p_note': note,
    }),
  );
  Future<ContactReceipt> decide(
    String actor,
    String action,
    String id,
    int version,
    String operation, {
    String? group,
    List<String>? groups,
  }) async {
    final name = switch (operation) {
      'claim' => 'claim_group_coordination_seat',
      'confirm' => 'confirm_group_coordination_audience',
      'targets' => 'replace_group_coordination_targets',
      'decline' => 'decline_group_coordination_proposal',
      'cancel' => 'cancel_group_coordination_proposal',
      _ => throw ArgumentError.value(operation),
    };
    return ContactReceipt.parse(
      await call(name, {
        'p_expected_profile_id': actor,
        'p_action_id': action,
        'p_proposal_id': id,
        if (operation != 'cancel') 'p_expected_version': version,
        if (operation == 'claim') 'p_group_id': group,
        if (operation == 'targets') 'p_group_ids': groups,
      }),
    );
  }
}

final coordinationGatewayProvider = Provider<CoordinationGateway>(
  (ref) => CoordinationGateway(ref.watch(groupContactGatewayProvider).call),
);
