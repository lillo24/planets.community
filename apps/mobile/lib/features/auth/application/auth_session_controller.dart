import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_gateway.dart';
import '../domain/auth_models.dart';

enum AuthBootstrapOutcome { completed, failed, superseded }

class _BootstrapOperation {
  _BootstrapOperation(this.identity, this.ensureProfile, this.revision);

  final AuthIdentity identity;
  final bool ensureProfile;
  final int revision;
  late final Future<AuthBootstrapOutcome> result;
  bool settled = false;
}

class AuthSessionController extends Notifier<AuthSessionState> {
  StreamSubscription<AuthSnapshot>? _subscription;
  var _revision = 0;
  var _started = false;
  _BootstrapOperation? _operation;
  var _identityEpoch = 0;

  // A command may accept its own signed-in event, but not a later sign-out or
  // different identity delivered while SDK verification was still returning.
  // The epoch also rejects A -> signed out -> A; matching an ID is not enough.
  int get verificationEpoch => _identityEpoch;

  bool acceptsVerification(AuthIdentity identity, int startedEpoch) =>
      _identityEpoch == startedEpoch &&
      (state.identity?.id == identity.id || state.identity == null);

  @override
  AuthSessionState build() {
    ref.onDispose(() {
      _revision++;
      unawaited(_subscription?.cancel());
    });
    return const AuthSessionState.restoring();
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    try {
      final gateway = ref.read(authGatewayProvider);
      _subscription = gateway.authStateChanges.listen(
        (snapshot) => unawaited(_applySnapshot(snapshot)),
        onError: (Object _, StackTrace _) {
          if (state.phase == AuthSessionPhase.restoring) {
            _revision += 1;
            state = const AuthSessionState.restorationFailed();
          }
        },
      );
    } catch (_) {
      // Subscription setup is part of restoration, not a signed-out result.
      _revision += 1;
      state = const AuthSessionState.restorationFailed();
      return;
    }
    await _restoreSnapshot();
  }

  Future<void> retryRestoration() async {
    if (state.phase != AuthSessionPhase.restorationFailed) return;
    state = const AuthSessionState.restoring();
    if (_subscription == null) {
      _started = false;
      await start();
      return;
    }
    await _restoreSnapshot();
  }

  Future<void> _restoreSnapshot() async {
    try {
      await _applySnapshot(ref.read(authGatewayProvider).currentSnapshot);
    } catch (_) {
      // Gateway snapshot failures must not impersonate an absent session.
      _revision += 1;
      state = const AuthSessionState.restorationFailed();
    }
  }

  Future<void> _applySnapshot(AuthSnapshot snapshot) async {
    _revision++;
    final identity = snapshot.identity;
    if (identity == null || snapshot.isExpired) {
      _identityEpoch++;
      _operation = null;
      state = const AuthSessionState.signedOut();
      return;
    }

    // Preserve a warm ready session and retained navigation, but never skip the
    // fresh canonical suspension check. Denial/failure still closes private UI.
    if (snapshot.isTokenRefresh &&
        state.phase == AuthSessionPhase.ready &&
        state.identity?.id == identity.id) {
      await _beginBootstrap(identity, preserveReady: true).result;
      return;
    }
    await bootstrap(identity);
  }

  Future<void> refresh() async {
    final identity = state.identity;
    if (identity != null) await bootstrap(identity);
  }

  Future<bool> bootstrap(
    AuthIdentity identity, {
    bool ensureProfile = false,
    ProfileAnchorReadiness? confirmedReadiness,
  }) async =>
      await _beginBootstrap(
        identity,
        ensureProfile: ensureProfile,
        confirmedReadiness: confirmedReadiness,
      ).result ==
      AuthBootstrapOutcome.completed;

  // Explicit OTP/retry work follows a newer same-identity bootstrap rather than
  // converting supersession into a profile failure. Each replacement still
  // performs a fresh account-status check; it inherits pending anchor creation.
  Future<AuthBootstrapOutcome> completeProfileSetup(
    AuthIdentity identity,
  ) async {
    var operation = _beginBootstrap(identity, ensureProfile: true);
    final epoch = _identityEpoch;
    while (true) {
      final outcome = await operation.result;
      if (!ref.mounted) return AuthBootstrapOutcome.superseded;
      final latest = _operation;
      if (epoch != _identityEpoch ||
          state.identity?.id != identity.id ||
          latest == null) {
        return AuthBootstrapOutcome.superseded;
      }
      if (operation.revision == _revision) return outcome;
      if (identical(latest, operation) || latest.identity.id != identity.id) {
        return AuthBootstrapOutcome.superseded;
      }
      operation = latest;
    }
  }

  _BootstrapOperation _beginBootstrap(
    AuthIdentity identity, {
    bool ensureProfile = false,
    ProfileAnchorReadiness? confirmedReadiness,
    bool preserveReady = false,
  }) {
    if (state.identity != null && state.identity?.id != identity.id) {
      _identityEpoch++;
    }
    final previous = _operation;
    final operation = _BootstrapOperation(
      identity,
      ensureProfile ||
          (previous != null &&
              !previous.settled &&
              previous.identity.id == identity.id &&
              previous.ensureProfile),
      ++_revision,
    );
    _operation = operation;
    operation.result = _runBootstrap(
      operation,
      confirmedReadiness,
      preserveReady,
    ).whenComplete(() => operation.settled = true);
    return operation;
  }

  Future<AuthBootstrapOutcome> _runBootstrap(
    _BootstrapOperation operation,
    ProfileAnchorReadiness? confirmedReadiness,
    bool preserveReady,
  ) async {
    final identity = operation.identity;
    final revision = operation.revision;
    if (!preserveReady) state = AuthSessionState.checkingAccount(identity);
    try {
      final status = await ref
          .read(authGatewayProvider)
          .suspensionStatusFor(identity.id)
          .timeout(const Duration(seconds: 15));
      if (revision != _revision) return AuthBootstrapOutcome.superseded;
      if (status.isSuspended) {
        state = AuthSessionState.suspended(identity, status);
        return AuthBootstrapOutcome.completed;
      }
    } catch (_) {
      if (revision == _revision) {
        state = AuthSessionState.accountCheckFailed(identity);
      }
      return revision == _revision
          ? AuthBootstrapOutcome.failed
          : AuthBootstrapOutcome.superseded;
    }
    if (preserveReady) return AuthBootstrapOutcome.completed;
    state = AuthSessionState.checkingProfile(identity);
    try {
      if (operation.ensureProfile) {
        await ref.read(profileAnchorGatewayProvider).ensureFor(identity.id);
        if (revision != _revision) return AuthBootstrapOutcome.superseded;
      }
      final readiness =
          confirmedReadiness ??
          await ref
              .read(profileAnchorGatewayProvider)
              .readinessFor(identity.id);
      if (revision != _revision) {
        return AuthBootstrapOutcome.superseded;
      }
      state = readiness == ProfileAnchorReadiness.complete
          ? AuthSessionState.ready(identity)
          : AuthSessionState.profileSetupRequired(
              identity,
              hasProfileAnchor: readiness == ProfileAnchorReadiness.incomplete,
            );
      return AuthBootstrapOutcome.completed;
    } catch (_) {
      if (revision == _revision) {
        state = AuthSessionState.profileSetupRequired(
          identity,
          hasProfileAnchor: false,
        );
      }
      return revision == _revision
          ? AuthBootstrapOutcome.failed
          : AuthBootstrapOutcome.superseded;
    }
  }

  // Only the profile editor uses this after its canonical save and own-profile
  // read have succeeded. Account status is still freshly checked first.
  Future<bool> confirmProfileReady(AuthIdentity identity) =>
      bootstrap(identity, confirmedReadiness: ProfileAnchorReadiness.complete);

  @visibleForTesting
  void markProfileReady(AuthIdentity identity) {
    // Synchronous setup remains useful for isolated controller fixtures. Actual
    // Auth/profile flows use bootstrap/refresh; never override a denied gate.
    if (state.phase == AuthSessionPhase.suspended ||
        state.phase == AuthSessionPhase.accountCheckFailed ||
        state.phase == AuthSessionPhase.checkingAccount) {
      return;
    }
    _revision += 1;
    state = AuthSessionState.ready(identity);
  }

  @visibleForTesting
  void markProfileSetupRequired(
    AuthIdentity identity, {
    required bool hasProfileAnchor,
  }) {
    if (state.phase == AuthSessionPhase.suspended ||
        state.phase == AuthSessionPhase.accountCheckFailed ||
        state.phase == AuthSessionPhase.checkingAccount) {
      return;
    }
    _revision += 1;
    state = AuthSessionState.profileSetupRequired(
      identity,
      hasProfileAnchor: hasProfileAnchor,
    );
  }

  void markSignedOut() {
    _revision += 1;
    _identityEpoch++;
    _operation = null;
    state = const AuthSessionState.signedOut();
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );
