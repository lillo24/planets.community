import 'dart:async';

import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.snapshot = const AuthSnapshot()});

  AuthSnapshot snapshot;
  Object? requestError;
  Object? verifyError;
  Future<void>? requestDelay;
  Future<void>? signOutDelay;
  Object? signOutError;
  AuthIdentity verifiedIdentity = const AuthIdentity(id: 'user-1');
  int requestCount = 0;
  int verifyCount = 0;
  int signOutCount = 0;
  String? requestedEmail;
  String? verifiedEmail;
  String? verifiedToken;

  final StreamController<AuthSnapshot> _states =
      StreamController<AuthSnapshot>.broadcast();

  @override
  AuthSnapshot get currentSnapshot => snapshot;

  @override
  Stream<AuthSnapshot> get authStateChanges => _states.stream;

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
}

class FakeProfileAnchorGateway implements ProfileAnchorGateway {
  ProfileAnchorReadiness readiness = ProfileAnchorReadiness.missing;
  Object? existsError;
  Object? ensureError;
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
    if (existsError case final error?) {
      throw error;
    }
    return readiness;
  }

  @override
  Future<void> ensureFor(String userId) async {
    ensureCount += 1;
    lastUserId = userId;
    if (ensureError case final error?) {
      throw error;
    }
    if (readiness == ProfileAnchorReadiness.missing) {
      readiness = ProfileAnchorReadiness.incomplete;
    }
  }
}
