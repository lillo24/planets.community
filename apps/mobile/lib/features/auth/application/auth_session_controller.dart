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
    final revision = ++_revision;
    final identity = snapshot.identity;
    if (identity == null || snapshot.isExpired) {
      state = const AuthSessionState.signedOut();
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
