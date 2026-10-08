import 'dart:async';

import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/data/provider_auth_adapter.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/domain/provider_auth.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.snapshot = const AuthSnapshot()});

  AuthSnapshot snapshot;
  Object? snapshotError;
  Object? streamError;
  Object? requestError;
  Object? verifyError;
  Future<void>? requestDelay;
  Future<void>? verifyDelay;
  Future<void>? signOutDelay;
  Object? signOutError;
  AuthIdentity verifiedIdentity = const AuthIdentity(id: 'user-1');
  int requestCount = 0;
  int verifyCount = 0;
  int signOutCount = 0;
  int suspensionCheckCount = 0;
  AccountSuspensionStatus suspension = const AccountSuspensionStatus.inactive();
  Object? suspensionError;
  Future<void>? suspensionDelay;
  String? requestedEmail;
  String? verifiedEmail;
  String? verifiedToken;

  final StreamController<AuthSnapshot> _states =
      StreamController<AuthSnapshot>.broadcast();

  @override
  AuthSnapshot get currentSnapshot {
    if (snapshotError != null) throw snapshotError!;
    return snapshot;
  }

  @override
  Stream<AuthSnapshot> get authStateChanges {
    if (streamError != null) throw streamError!;
    return _states.stream;
  }

  void emit(AuthSnapshot value) => _states.add(value);

  void emitError(Object error) => _states.addError(error);

  Future<void> close() => _states.close();

  @override
  Future<void> requestEmailOtp(String email) async {
    requestCount += 1;
    requestedEmail = email;
    final delay = requestDelay;
    if (delay != null) {
      await delay;
    }
    if (requestError case final error?) {
      throw error;
    }
  }

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    verifyCount += 1;
    verifiedEmail = email;
    verifiedToken = token;
    if (verifyDelay case final delay?) await delay;
    if (verifyError case final error?) {
      throw error;
    }
    return verifiedIdentity;
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    if (signOutDelay case final delay?) await delay;
    if (signOutError case final error?) throw error;
    snapshot = const AuthSnapshot();
    emit(snapshot);
  }

  @override
  Future<AccountSuspensionStatus> suspensionStatusFor(
    String expectedProfileId,
  ) async {
    suspensionCheckCount++;
    if (suspensionDelay case final delay?) await delay;
    if (suspensionError case final error?) throw error;
    return suspension;
  }
}

class FakeProfileAnchorGateway implements ProfileAnchorGateway {
  ProfileAnchorReadiness readiness = ProfileAnchorReadiness.missing;
  Object? existsError;
  Object? ensureError;
  Future<void>? ensureDelay;
  Future<void>? readinessDelay;
  bool createsAnchor = true;
  int existsCount = 0;
  int ensureCount = 0;
  String? lastUserId;

  bool get exists => readiness != ProfileAnchorReadiness.missing;

  set exists(bool value) {
    readiness = value
        ? ProfileAnchorReadiness.complete
        : ProfileAnchorReadiness.missing;
  }

  @override
  Future<ProfileAnchorReadiness> readinessFor(String userId) async {
    existsCount += 1;
    lastUserId = userId;
    if (readinessDelay case final delay?) await delay;
    if (existsError case final error?) {
      throw error;
    }
    return readiness;
  }

  @override
  Future<void> ensureFor(String userId) async {
    ensureCount += 1;
    lastUserId = userId;
    if (ensureDelay case final delay?) await delay;
    if (ensureError case final error?) {
      throw error;
    }
    if (createsAnchor && readiness == ProfileAnchorReadiness.missing) {
      readiness = ProfileAnchorReadiness.incomplete;
    }
  }
}

class FakeProviderAuthAdapter implements ProviderAuthAdapter {
  Set<AuthProvider> availableProviders = AuthProvider.values.toSet();
  ProviderAuthResult result = const ProviderAuthSuccess(
    AuthIdentity(id: 'user-1'),
  );
  Future<void>? signInDelay;
  Object? signInError;
  int signInCount = 0;
  AuthProvider? lastProvider;

  @override
  bool isAvailable(AuthProvider provider) =>
      availableProviders.contains(provider);

  @override
  Future<ProviderAuthResult> signIn(AuthProvider provider) async {
    signInCount += 1;
    lastProvider = provider;
    if (signInDelay case final delay?) await delay;
    if (signInError case final error?) throw error;
    return result;
  }
}
