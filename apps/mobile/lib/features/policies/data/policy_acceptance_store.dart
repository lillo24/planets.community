import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';

/// Only a confirmed exact-account/version server timestamp establishes acceptance.
/// Null is a successful read with no record, never an unavailable backend.
abstract interface class PolicyAcceptanceStore {
  Future<DateTime?> read(String account, String version);
  Future<DateTime> write(String account, String version);
}

class SupabasePolicyAcceptanceStore implements PolicyAcceptanceStore {
  SupabasePolicyAcceptanceStore(
    this._client, {
    this.requestTimeout = const Duration(seconds: 15),
  });

  final SupabaseClient _client;
  final Duration requestTimeout;

  Future<DateTime?> _call(
    String operation,
    String account,
    String version, {
    required bool accepting,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired || session.user.id != account) {
      throw StateError('Policy acknowledgement requires the current account');
    }
    final result = await _client
        .rpc(
          operation,
          params: {
            'p_expected_account_id': account,
            'p_bundle_version': version,
          },
        )
        .timeout(requestTimeout);
    final current = _client.auth.currentSession;
    if (current == null ||
        current.isExpired ||
        current.user.id != account ||
        current.accessToken != session.accessToken) {
      throw StateError('Policy acknowledgement session changed');
    }
    if (result is! List || result.length > 1) {
      throw const FormatException('Invalid policy acknowledgement response');
    }
    if (result.isEmpty && !accepting) return null;
    if (result.isEmpty) {
      throw const FormatException('Policy acceptance was not confirmed');
    }
    final row = result.single;
    if (row is! Map<String, dynamic> ||
        row['account_id'] != account ||
        row['bundle_version'] != version ||
        row['accepted_at'] is! String) {
      throw const FormatException('Mismatched policy acknowledgement');
    }
    final acceptedAt = DateTime.tryParse(row['accepted_at'] as String);
    if (acceptedAt == null || !acceptedAt.isUtc) {
      throw const FormatException('Invalid server policy acceptance timestamp');
    }
    return acceptedAt;
  }

  @override
  Future<DateTime?> read(String account, String version) =>
      _call('get_policy_acceptance', account, version, accepting: false);

  @override
  Future<DateTime> write(String account, String version) async =>
      (await _call('accept_policy_bundle', account, version, accepting: true))!;
}

final policyAcceptanceStoreProvider = Provider<PolicyAcceptanceStore>(
  (ref) => SupabasePolicyAcceptanceStore(ref.watch(supabaseClientProvider)),
);
