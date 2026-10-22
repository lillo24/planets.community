import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/co_creation_commands.dart';

Object? _frozen(Object? value) => switch (value) {
  Map value => Map<String, dynamic>.unmodifiable(
    value.map((k, v) => MapEntry(k as String, _frozen(v))),
  ),
  List value => List<Object?>.unmodifiable(value.map(_frozen)),
  _ => value,
};

/// RAM-only immutable command, retained across route changes for exact retry.
/// Even a malformed success response is uncertain: it may have committed.
class PeopleAttempt {
  PeopleAttempt(
    this.actor,
    this.rpc,
    Map<String, dynamic> intent, {
    String? commandId,
  }) : commandId = commandId ?? const Uuid().v4(),
       intent = _frozen(jsonDecode(jsonEncode(intent))) as Map<String, dynamic>;
  final String actor, rpc, commandId;
  final Map<String, dynamic> intent;
  bool uncertain = false, busy = false;
  Map<String, Object?>? receipt;
  Future<Map<String, Object?>> deliver(CoCreationCommandGateway gateway) async {
    if (busy) throw StateError('Command is already being delivered.');
    busy = true;
    uncertain = true;
    try {
      final result = await gateway.command(rpc, {
        'p_expected_profile_id': actor,
        'p_command_id': commandId,
        ...intent,
      });
      receipt = result;
      uncertain = false;
      return result;
    } on PostgrestException catch (e) {
      uncertain = !{
        '42501',
        '22023',
        'PT409',
        'PT429',
        '55000',
        'P0002',
      }.contains(e.code);
      rethrow;
    } finally {
      busy = false;
    }
  }
}

class PeopleAttempts extends Notifier<Map<String, PeopleAttempt>> {
  @override
  Map<String, PeopleAttempt> build() {
    ref.watch(authSessionProvider.select((s) => (s.identity?.id, s.phase)));
    return const {};
  }

  PeopleAttempt acquire(
    String slot,
    String actor,
    String rpc,
    Map<String, dynamic> intent,
  ) {
    final previous = state[slot];
    if (previous?.uncertain == true) {
      if (previous!.actor != actor ||
          previous.rpc != rpc ||
          jsonEncode(previous.intent) != jsonEncode(intent)) {
        throw StateError('Resolve the original uncertain command first.');
      }
      return previous;
    }
    final attempt = PeopleAttempt(actor, rpc, intent);
    state = {...state, slot: attempt};
    return attempt;
  }

  void clear(String slot) {
    state = {...state}..remove(slot);
  }

  void updated() {
    state = {...state};
  }
}

final peopleAttemptsProvider =
    NotifierProvider<PeopleAttempts, Map<String, PeopleAttempt>>(
      PeopleAttempts.new,
    );
