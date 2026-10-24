import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../co_creation/application/people_signals.dart';
import '../application/message_unread_controller.dart';
import '../domain/private_pair_models.dart';
import '../domain/message_unread_models.dart';

typedef PrivatePairRpc = Future<Object?> Function(String, Map<String, dynamic>);

class PrivatePairGateway {
  const PrivatePairGateway(this.rpc);
  final PrivatePairRpc rpc;
  Future<List<PrivatePairRow>> list(
    String actor, {
    PrivatePairRow? before,
  }) async {
    final raw = await rpc('list_own_private_pairs_v1', {
      'p_expected_profile_id': actor,
      'p_limit': 21,
      'p_before_activity_at': before?.activity.toUtc().toIso8601String(),
      'p_before_peer_id': before?.peer,
    });
    if (raw is! List || raw.length > 21) {
      throw const FormatException('Invalid personal list.');
    }
    final rows = raw
        .map((r) => PrivatePairRow.parse(r, actor))
        .toList(growable: false);
    final seen = <String>{};
    PrivatePairRow? previous = before;
    for (final row in rows) {
      if (!seen.add(row.peer) ||
          (previous != null &&
              (row.activity.isAfter(previous.activity) ||
                  (row.activity.isAtSameMomentAs(previous.activity) &&
                      row.peer.compareTo(previous.peer) >= 0)))) {
        throw const FormatException('Invalid personal list order.');
      }
      previous = row;
    }
    return List.unmodifiable(rows);
  }

  Future<PrivatePairPage> feed(
    String actor,
    String peer, {
    PrivatePairItem? before,
  }) async {
    final page = PrivatePairPage.parse(
      await rpc('get_own_private_pair_page_v1', {
        'p_expected_profile_id': actor,
        'p_peer_profile_id': peer,
        'p_limit': 31,
        'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_item_kind': before?.kind,
        'p_before_item_id': before?.id,
      }),
      actor,
      peer,
      newest: before == null,
    );
    if (before != null &&
        page.items.any((m) => comparePrivateItems(m, before) >= 0)) {
      throw const FormatException(
        'Personal history did not advance its cursor.',
      );
    }
    return page;
  }

  Future<List<PrivatePairContext>> contexts(
    String actor,
    String peer, {
    PrivatePairContext? before,
    bool onlyWritable = false,
  }) async {
    final raw = await rpc('list_own_private_pair_contexts_v1', {
      'p_expected_profile_id': actor,
      'p_peer_profile_id': peer,
      'p_limit': 50,
      'p_before_kind': before?.kind,
      'p_before_id': before?.id,
      'p_only_writable': onlyWritable,
    });
    if (raw is! List || raw.length > 50) {
      throw const FormatException('Invalid personal contexts.');
    }
    final result = raw.map(PrivatePairContext.parse).toList(growable: false);
    var previous = before;
    for (final c in result) {
      if (previous != null &&
          (c.kind.compareTo(previous.kind) < 0 ||
              (c.kind == previous.kind && c.id.compareTo(previous.id) <= 0))) {
        throw const FormatException('Invalid context order.');
      }
      previous = c;
    }
    return List.unmodifiable(result);
  }

  Future<({String peer, PrivatePairContext? context})> resolve(
    String actor,
    String kind,
    String id,
  ) async {
    final r = messageUnreadObject(
      await rpc('resolve_own_private_pair_v1', {
        'p_expected_profile_id': actor,
        'p_context_kind': kind,
        'p_context_id': id,
      }),
      const {
        'profile_id',
        'peer_profile_id',
        'context_kind',
        'context_id',
        'context',
      },
    );
    if (r['profile_id'] != actor ||
        r['context_kind'] != kind ||
        r['context_id'] != id) {
      throw const FormatException('Mismatched personal source.');
    }
    final context = r['context'] == null
        ? null
        : PrivatePairContext.parse(r['context']);
    if (context != null && (context.kind != kind || context.id != id)) {
      throw const FormatException('Mismatched source focus.');
    }
    return (peer: messageUnreadUuid(r['peer_profile_id']), context: context);
  }

  Future<void> send(PrivatePairSend attempt) async {
    final r = messageUnreadObject(
      await rpc('send_own_private_pair_message_v1', attempt.parameters),
      const {'command_id', 'context_kind', 'context_id', 'result'},
    );
    if (r['command_id'] != attempt.command ||
        r['context_kind'] != attempt.context.kind ||
        r['context_id'] != attempt.context.id ||
        r['result'] is! Map) {
      throw const FormatException('Mismatched send receipt.');
    }
  }

  Future<void> acknowledge(
    String actor,
    String peer,
    String boundary,
    List<String> keys,
  ) async {
    MessageUnreadSummary.parse(
      await rpc('acknowledge_own_private_pair_v1', {
        'p_expected_profile_id': actor,
        'p_peer_profile_id': peer,
        'p_boundary': boundary,
        'p_rendered_keys': keys,
      }),
    );
  }
}

final privatePairGatewayProvider = Provider<PrivatePairGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PrivatePairGateway(
    (name, args) => client.rpc<Object?>(name, params: args),
  );
});

/// Shared own-account hints. Every hint drops protected projections before reread;
/// payloads carry only the recipient UUID. Resume/polling reconcile missed hints.
final privatePairSignalsProvider = StreamProvider.autoDispose<int>((ref) {
  final actor = ref.watch(authSessionProvider).identity?.id;
  if (actor == null) return const Stream.empty();
  final stream = StreamController<int>();
  var revision = 0;
  void changed() {
    if (!stream.isClosed) stream.add(++revision);
  }

  // Realtime evicts duplicate channels for the same topic in the locked SDK.
  // Consume the existing shared subscriptions instead of opening a second one.
  ref.listen(messageUnreadProvider, (_, next) {
    if (next.profileId == actor && next.stale) changed();
  });
  ref.listen(peopleSignalsProvider, (_, next) {
    if (next.hasValue || next.hasError) changed();
  });
  ref.onDispose(() {
    unawaited(stream.close());
  });
  return stream.stream;
});
