import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../domain/group_contact_models.dart';

/// One in-memory actor/intent for an ambiguous delivery. No private persistence.
/// The UI may edit again only after explicit canonical rejection or resolution.
class ContactAttempt {
  ContactAttempt(this.actor, this.operation, this.intent, {String? actionId})
    : actionId = actionId ?? const Uuid().v4();
  final String actor, operation, actionId;
  final Object intent;
  ContactReceipt? receipt;
  bool ambiguous = false;
  bool matches(String actor, String operation, Object intent) =>
      this.actor == actor &&
      this.operation == operation &&
      this.intent == intent;
  Future<ContactReceipt> deliver(
    Future<ContactReceipt> Function(String) send,
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

class ContactAttempts extends Notifier<Map<String, ContactAttempt>> {
  @override
  Map<String, ContactAttempt> build() {
    ref.watch(authSessionProvider.select((s) => (s.identity?.id, s.phase)));
    return const {};
  }

  ContactAttempt acquire(
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
        : ContactAttempt(actor, operation, intent);
    state = {...state, slot: attempt};
    return attempt;
  }

  void clear(String slot) {
    state = {...state}..remove(slot);
  }
}

final contactAttemptsProvider =
    NotifierProvider<ContactAttempts, Map<String, ContactAttempt>>(
      ContactAttempts.new,
    );
