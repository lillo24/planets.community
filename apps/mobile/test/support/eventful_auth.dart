import 'dart:async';

import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import 'fake_auth.dart';

/// Models the SDK publishing a session as well as returning OTP verification.
/// Completers place the event at a specific bootstrap boundary, without sleeps.
class EventfulAuthGateway extends FakeAuthGateway {
  Future<void>? verifyRelease;
  final verified = Completer<void>();
  final statusEntered = Completer<void>();
  final replacementEntered = Completer<void>();
  Future<void>? statusRelease;
  bool eventBeforeReturn = false;
  Object? completionError;

  void publish(AuthSnapshot value) {
    snapshot = value;
    emit(value);
  }

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final identity = await super.verifyEmailOtp(email: email, token: token);
    snapshot = AuthSnapshot(identity: identity);
    verified.complete();
    if (eventBeforeReturn) publish(snapshot);
    if (verifyRelease case final release?) await release;
    if (completionError case final error?) throw error;
    return identity;
  }

  @override
  Future<AccountSuspensionStatus> suspensionStatusFor(String userId) async {
    final call = ++suspensionCheckCount;
    if (call == 1) {
      statusEntered.complete();
      if (statusRelease case final release?) await release;
    } else if (!replacementEntered.isCompleted) {
      replacementEntered.complete();
    }
    if (suspensionError case final error?) throw error;
    return suspension;
  }

  @override
  Future<void> signOut() async {
    if (signOutError case final error?) throw error;
    await super.signOut();
  }
}

class ControlledProfileAnchor extends FakeProfileAnchorGateway {
  final ensureEntered = Completer<void>();
  final readinessEntered = Completer<void>();
  Future<void>? ensureRelease;
  Future<void>? readinessRelease;

  @override
  Future<void> ensureFor(String userId) async {
    if (!ensureEntered.isCompleted) ensureEntered.complete();
    if (ensureRelease case final release?) {
      ensureRelease = null;
      await release;
    }
    await super.ensureFor(userId);
  }

  @override
  Future<ProfileAnchorReadiness> readinessFor(String userId) async {
    if (!readinessEntered.isCompleted) readinessEntered.complete();
    if (readinessRelease case final release?) {
      readinessRelease = null;
      await release;
    }
    return super.readinessFor(userId);
  }
}
