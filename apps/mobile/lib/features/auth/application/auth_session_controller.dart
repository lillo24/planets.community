import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_gateway.dart';
import '../domain/auth_models.dart';

class AuthSessionController extends Notifier<AuthSessionState> {
  StreamSubscription<AuthSnapshot>? _subscription;
  var _revision = 0;
  var _started = false;

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

    final gateway = ref.read(authGatewayProvider);
    _subscription = gateway.authStateChanges.listen(
      (snapshot) => unawaited(_applySnapshot(snapshot)),
      onError: (Object _, StackTrace _) {
        if (state.phase == AuthSessionPhase.restoring) {
          state = const AuthSessionState.signedOut();
        }
      },
    );
    await _applySnapshot(gateway.currentSnapshot);
  }

  Future<void> _applySnapshot(AuthSnapshot snapshot) async {
    _revision++;
    final identity = snapshot.identity;
    if (identity == null || snapshot.isExpired) {
      state = const AuthSessionState.signedOut();
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
  }) async {
    final revision = ++_revision;
    state = AuthSessionState.checkingAccount(identity);
    try {
      final status = await ref
          .read(authGatewayProvider)
          .suspensionStatusFor(identity.id)
          .timeout(const Duration(seconds: 15));
      if (revision != _revision) return false;
      if (status.isSuspended) {
        state = AuthSessionState.suspended(identity, status);
        return true;
      }
    } catch (_) {
      if (revision == _revision) {
        state = AuthSessionState.accountCheckFailed(identity);
      }
      return false;
    }
    state = AuthSessionState.checkingProfile(identity);
    try {
      if (ensureProfile) {
        await ref.read(profileAnchorGatewayProvider).ensureFor(identity.id);
        if (revision != _revision) return false;
      }
      final readiness =
          confirmedReadiness ??
          await ref
              .read(profileAnchorGatewayProvider)
              .readinessFor(identity.id);
      if (revision != _revision) {
        return false;
      }
      state = readiness == ProfileAnchorReadiness.complete
          ? AuthSessionState.ready(identity)
          : AuthSessionState.profileSetupRequired(
              identity,
              hasProfileAnchor: readiness == ProfileAnchorReadiness.incomplete,
            );
      return true;
    } catch (_) {
      if (revision == _revision) {
        state = AuthSessionState.profileSetupRequired(
          identity,
          hasProfileAnchor: false,
        );
      }
      return false;
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
    state = const AuthSessionState.signedOut();
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );
