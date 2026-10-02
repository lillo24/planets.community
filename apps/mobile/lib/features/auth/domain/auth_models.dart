enum AuthSessionPhase {
  restoring,
  signedOut,
  checkingAccount,
  accountCheckFailed,
  suspended,
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
    this.suspension,
  });

  const AuthSessionState.restoring()
    : this._(phase: AuthSessionPhase.restoring);

  const AuthSessionState.signedOut()
    : this._(phase: AuthSessionPhase.signedOut);

  const AuthSessionState.checkingAccount(AuthIdentity identity)
    : this._(phase: AuthSessionPhase.checkingAccount, identity: identity);

  const AuthSessionState.accountCheckFailed(AuthIdentity identity)
    : this._(phase: AuthSessionPhase.accountCheckFailed, identity: identity);

  const AuthSessionState.suspended(
    AuthIdentity identity,
    AccountSuspensionStatus status,
  ) : this._(
        phase: AuthSessionPhase.suspended,
        identity: identity,
        suspension: status,
      );

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
  final AccountSuspensionStatus? suspension;

  // Controllers already discard private state on identity changes. Also discard
  // it when account access is denied or its status check fails, without losing
  // Auth identity. A routine successful refresh does not discard retained forms.
  String? get accountAccessIdentityId =>
      phase == AuthSessionPhase.ready ||
          phase == AuthSessionPhase.checkingAccount ||
          phase == AuthSessionPhase.checkingProfile ||
          phase == AuthSessionPhase.profileSetupRequired
      ? identity?.id
      : null;

  bool get isAuthenticated => switch (phase) {
    AuthSessionPhase.checkingProfile ||
    AuthSessionPhase.checkingAccount ||
    AuthSessionPhase.accountCheckFailed ||
    AuthSessionPhase.suspended ||
    AuthSessionPhase.ready ||
    AuthSessionPhase.profileSetupRequired => true,
    AuthSessionPhase.restoring || AuthSessionPhase.signedOut => false,
  };
}

class AccountSuspensionStatus {
  const AccountSuspensionStatus.inactive()
    : isSuspended = false,
      consequenceId = null,
      appliedAt = null,
      userReason = null;

  const AccountSuspensionStatus.active({
    required String this.consequenceId,
    required DateTime this.appliedAt,
    required String this.userReason,
  }) : isSuspended = true;

  factory AccountSuspensionStatus.fromJson(Map<String, dynamic> row) {
    const keys = {
      'is_suspended',
      'consequence_id',
      'applied_at',
      'user_reason',
    };
    if (row.length != keys.length || !row.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected account status shape.');
    }
    if (row['is_suspended'] == false &&
        row['consequence_id'] == null &&
        row['applied_at'] == null &&
        row['user_reason'] == null) {
      return const AccountSuspensionStatus.inactive();
    }
    final id = row['consequence_id'];
    final time = row['applied_at'];
    final reason = row['user_reason'];
    if (row['is_suspended'] != true ||
        id is! String ||
        id.isEmpty ||
        time is! String ||
        reason is! String ||
        reason.trim().isEmpty ||
        reason.runes.length > 2000) {
      throw const FormatException('Invalid account status.');
    }
    return AccountSuspensionStatus.active(
      consequenceId: id,
      appliedAt: DateTime.parse(time),
      userReason: reason,
    );
  }

  final bool isSuspended;
  final String? consequenceId;
  final DateTime? appliedAt;
  final String? userReason;
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
    AuthCommandPhase.completingProfile ||
    AuthCommandPhase.signingOut => true,
    AuthCommandPhase.idle || AuthCommandPhase.codeSent => false,
  };
}
