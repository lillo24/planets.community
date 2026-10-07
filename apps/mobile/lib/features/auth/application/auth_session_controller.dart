import 'dart:async';

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
    final revision = ++_revision;
    final identity = snapshot.identity;
    if (identity == null || snapshot.isExpired) {
      state = const AuthSessionState.signedOut();
      return;
    }

    if (snapshot.isTokenRefresh &&
        state.phase == AuthSessionPhase.ready &&
        state.identity?.id == identity.id) {
      return;
    }
    state = AuthSessionState.checkingProfile(identity);
    try {
      final readiness = await ref
          .read(profileAnchorGatewayProvider)
          .readinessFor(identity.id);
      if (revision != _revision) {
        return;
      }
      state = readiness == ProfileAnchorReadiness.complete
          ? AuthSessionState.ready(identity)
          : AuthSessionState.profileSetupRequired(
              identity,
              hasProfileAnchor: readiness == ProfileAnchorReadiness.incomplete,
            );
    } catch (_) {
      if (revision == _revision) {
        state = AuthSessionState.profileSetupRequired(
          identity,
          hasProfileAnchor: false,
        );
      }
    }
  }

  void markCheckingProfile(AuthIdentity identity) {
    _revision += 1;
    state = AuthSessionState.checkingProfile(identity);
  }

  void markProfileReady(AuthIdentity identity) {
    _revision += 1;
    state = AuthSessionState.ready(identity);
  }

  void markProfileSetupRequired(
    AuthIdentity identity, {
    required bool hasProfileAnchor,
  }) {
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
