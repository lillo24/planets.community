enum AuthSessionPhase {
  restoring,
  signedOut,
  checkingProfile,
  ready,
  profileSetupRequired,
}

class AuthIdentity {
  const AuthIdentity({required this.id});

  final String id;
}

class AuthSnapshot {
  const AuthSnapshot({this.identity, this.isExpired = false});

  final AuthIdentity? identity;
  final bool isExpired;
}

enum ProfileAnchorReadiness { missing, incomplete, complete }

class AuthSessionState {
  const AuthSessionState._({
    required this.phase,
    this.identity,
    this.hasProfileAnchor = false,
  });

  const AuthSessionState.restoring()
    : this._(phase: AuthSessionPhase.restoring);

  const AuthSessionState.signedOut()
    : this._(phase: AuthSessionPhase.signedOut);

  const AuthSessionState.checkingProfile(AuthIdentity identity)
    : this._(phase: AuthSessionPhase.checkingProfile, identity: identity);

  const AuthSessionState.ready(AuthIdentity identity)
    : this._(phase: AuthSessionPhase.ready, identity: identity);

  const AuthSessionState.profileSetupRequired(
    AuthIdentity identity, {
    required bool hasProfileAnchor,
  }) : this._(
         phase: AuthSessionPhase.profileSetupRequired,
         identity: identity,
         hasProfileAnchor: hasProfileAnchor,
       );

  final AuthSessionPhase phase;
  final AuthIdentity? identity;
  final bool hasProfileAnchor;

  bool get isAuthenticated => switch (phase) {
    AuthSessionPhase.checkingProfile ||
    AuthSessionPhase.ready ||
    AuthSessionPhase.profileSetupRequired => true,
    AuthSessionPhase.restoring || AuthSessionPhase.signedOut => false,
  };
}

class PendingEmailOtp {
  const PendingEmailOtp({required this.email, required this.returnTo});

  final String email;
  final String returnTo;
}

enum AuthFailureKind {
  invalidEmail,
  invalidCode,
  expiredCode,
  rateLimited,
  requestTimedOut,
  networkUnavailable,
  serviceUnavailable,
  profileSetup,
  unexpected,
}

enum AuthCommandPhase {
  idle,
  requestingCode,
  codeSent,
  verifyingCode,
  signingInWithProvider,
  completingProfile,
  signingOut,
}

class AuthCommandState {
  const AuthCommandState({
    this.phase = AuthCommandPhase.idle,
    this.failure,
    this.resendAvailableAt,
  });

  final AuthCommandPhase phase;
  final AuthFailureKind? failure;
  final DateTime? resendAvailableAt;

  bool get isBusy => switch (phase) {
    AuthCommandPhase.requestingCode ||
    AuthCommandPhase.verifyingCode ||
    AuthCommandPhase.signingInWithProvider ||
    AuthCommandPhase.completingProfile ||
    AuthCommandPhase.signingOut => true,
    AuthCommandPhase.idle || AuthCommandPhase.codeSent => false,
  };
}
