import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/auth_models.dart';

abstract interface class AuthGateway {
  AuthSnapshot get currentSnapshot;

  Stream<AuthSnapshot> get authStateChanges;

  Future<void> requestEmailOtp(String email);

  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  });

  Future<void> signOut();

  Future<AccountSuspensionStatus> suspensionStatusFor(String expectedProfileId);
}

abstract interface class ProfileAnchorGateway {
  Future<ProfileAnchorReadiness> readinessFor(String userId);

  Future<void> ensureFor(String userId);
}

class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  AuthSnapshot get currentSnapshot => _toSnapshot(_client.auth.currentSession);

  @override
  Stream<AuthSnapshot> get authStateChanges =>
      _client.auth.onAuthStateChange.map(
        (authState) => _toSnapshot(
          authState.session,
          isTokenRefresh: authState.event == AuthChangeEvent.tokenRefreshed,
        ),
      );

  @override
  Future<void> requestEmailOtp(String email) {
    return _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    final user = response.user ?? response.session?.user;
    if (user == null) {
      throw const AuthException('Verification completed without a user.');
    }
    return AuthIdentity(id: user.id);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<AccountSuspensionStatus> suspensionStatusFor(
    String expectedProfileId,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_own_account_suspension_status',
      params: {'p_expected_profile_id': expectedProfileId},
    );
    if (rows.length != 1 || rows.single is! Map<String, dynamic>) {
      throw const FormatException('Expected one own account status.');
    }
    return AccountSuspensionStatus.fromJson(
      rows.single as Map<String, dynamic>,
    );
  }

  static AuthSnapshot _toSnapshot(
    Session? session, {
    bool isTokenRefresh = false,
  }) {
    if (session == null) {
      return const AuthSnapshot();
    }
    return AuthSnapshot(
      identity: AuthIdentity(id: session.user.id),
      isExpired: session.isExpired,
      isTokenRefresh: isTokenRefresh,
    );
  }
}

class SupabaseProfileAnchorGateway implements ProfileAnchorGateway {
  const SupabaseProfileAnchorGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileAnchorReadiness> readinessFor(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, display_name')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      return ProfileAnchorReadiness.missing;
    }
    return row['display_name'] is String
        ? ProfileAnchorReadiness.complete
        : ProfileAnchorReadiness.incomplete;
  }

  @override
  Future<void> ensureFor(String userId) async {
    try {
      await _client.from('profiles').insert({'id': userId});
    } on PostgrestException catch (error) {
      if (!isExpectedProfileAnchorDuplicate(error)) {
        rethrow;
      }
    }
  }
}

bool isExpectedProfileAnchorDuplicate(PostgrestException error) {
  final diagnostic = '${error.message} ${error.details}'.toLowerCase();
  return error.code == '23505' && diagnostic.contains('profiles_pkey');
}

final authGatewayProvider = Provider<AuthGateway>((ref) {
  return SupabaseAuthGateway(ref.watch(supabaseClientProvider));
});

final profileAnchorGatewayProvider = Provider<ProfileAnchorGateway>((ref) {
  return SupabaseProfileAnchorGateway(ref.watch(supabaseClientProvider));
});
