// UI identity is paired with a genuine prepared Auth JWT; no hosted services.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

class ContactTokenPolicyStore implements PolicyAcceptanceStore {
  const ContactTokenPolicyStore(this.client);
  final SupabaseClient client;
  Future<DateTime?> call(
    String operation,
    String account,
    String version,
  ) async {
    final rows = await client.rpc(
      operation,
      params: {'p_expected_account_id': account, 'p_bundle_version': version},
    );
    if (rows is! List || rows.length > 1) {
      throw const FormatException('Invalid fixture policy response.');
    }
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row is! Map ||
        row['account_id'] != account ||
        row['bundle_version'] != version ||
        row['accepted_at'] is! String) {
      throw const FormatException('Mismatched fixture policy response.');
    }
    final accepted = DateTime.tryParse(row['accepted_at'] as String);
    if (accepted == null || !accepted.isUtc) {
      throw const FormatException('Invalid fixture acknowledgement timestamp.');
    }
    return accepted;
  }

  @override
  Future<DateTime?> read(String account, String version) =>
      call('get_policy_acceptance', account, version);
  @override
  Future<DateTime> write(String account, String version) async {
    final accepted = await call('accept_policy_bundle', account, version);
    if (accepted == null) throw StateError('Acknowledgement not confirmed.');
    return accepted;
  }
}

class ContactLocalIdentity implements AuthGateway {
  const ContactLocalIdentity(this.id);
  final String id;
  @override
  Future<AuthSnapshot> restoreSnapshot() async =>
      AuthSnapshot(identity: AuthIdentity(id: id));
  @override
  Stream<AuthSnapshot> get authStateChanges => const Stream.empty();
  @override
  Future<void> requestEmailOtp(String email) =>
      throw UnsupportedError('Use prepared local OTP fixture.');
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) => throw UnsupportedError('Use prepared local OTP fixture.');
  @override
  Future<void> signOut() async {}
}
