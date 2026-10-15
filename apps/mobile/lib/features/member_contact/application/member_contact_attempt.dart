import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../domain/member_contact_models.dart';

/// One in-memory actor/intent for an ambiguous delivery. No private persistence.
/// The UI may edit again only after explicit canonical rejection or resolution.
class MemberContactAttempt {
  MemberContactAttempt(
    this.actor,
    this.operation,
    this.intent, {
    String? actionId,
  }) : actionId = actionId ?? const Uuid().v4();
  final String actor, operation, actionId;
  final Object intent;
  MemberContactReceipt? receipt;
  bool ambiguous = false;
  bool matches(String actor, String operation, Object intent) =>
      this.actor == actor &&
      this.operation == operation &&
      this.intent == intent;
  Future<MemberContactReceipt> deliver(
    Future<MemberContactReceipt> Function(String) send,
  ) async {
    ambiguous = true;
    try {
      final result = await send(actionId);
      receipt = result;
      ambiguous = false;
      return result;
    } on PostgrestException catch (error) {
      ambiguous = !{'42501', '22023', 'PT409', 'PT429'}.contains(error.code);
      rethrow;
    } catch (_) {
      ambiguous = true;
      rethrow;
    }
  }
}

class MemberContactAttempts
    extends Notifier<Map<String, MemberContactAttempt>> {
  @override
  Map<String, MemberContactAttempt> build() {
    ref.watch(authSessionProvider.select((s) => (s.identity?.id, s.phase)));
    return const {};
  }

  MemberContactAttempt acquire(
    String slot,
    String actor,
    String operation,
    Object intent,
  ) {
    final previous = state[slot];
    if (previous != null && previous.ambiguous) {
      if (!previous.matches(actor, operation, intent)) {
        throw StateError('Reconcile the frozen contact action first.');
      }
      return previous;
    }
    final attempt =
        previous != null &&
            previous.receipt == null &&
            previous.matches(actor, operation, intent)
        ? previous
        : MemberContactAttempt(actor, operation, intent);
    state = {...state, slot: attempt};
    return attempt;
  }

  void clear(String slot) {
    state = {...state}..remove(slot);
  }
}

final memberContactAttemptsProvider =
    NotifierProvider<MemberContactAttempts, Map<String, MemberContactAttempt>>(
      MemberContactAttempts.new,
    );
