import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_gateway.dart';
import '../data/provider_auth_adapter.dart';
import '../domain/auth_models.dart';
import '../domain/provider_auth.dart';
import 'auth_session_controller.dart';
import 'return_destination.dart';

const resendCooldown = Duration(seconds: 30);
const defaultAuthOtpRequestTimeout = Duration(seconds: 15);

final pendingEmailOtpProvider =
    NotifierProvider<PendingEmailOtpController, PendingEmailOtp?>(
      PendingEmailOtpController.new,
    );

class PendingEmailOtpController extends Notifier<PendingEmailOtp?> {
  @override
  PendingEmailOtp? build() => null;

  void set(PendingEmailOtp value) => state = value;

  void clear() => state = null;
}

final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final authOtpRequestTimeoutProvider = Provider<Duration>(
  (ref) => defaultAuthOtpRequestTimeout,
);

class AuthCommandController extends Notifier<AuthCommandState> {
  int _flowRevision = 0;

  @override
  AuthCommandState build() => const AuthCommandState();

  void resetFlow() => cancelFlow();

  void cancelFlow() {
    _flowRevision += 1;
    ref.read(pendingEmailOtpProvider.notifier).clear();
    state = const AuthCommandState();
  }

  Future<bool> requestCode({required String email, String? returnTo}) async {
    if (state.isBusy) {
      return false;
    }

    final trimmedEmail = email.trim();
    if (!_isValidEmail(trimmedEmail)) {
      state = const AuthCommandState(failure: AuthFailureKind.invalidEmail);
      return false;
    }

    final revision = ++_flowRevision;
    state = const AuthCommandState(phase: AuthCommandPhase.requestingCode);
    try {
      await ref
          .read(authGatewayProvider)
          .requestEmailOtp(trimmedEmail)
          .timeout(ref.read(authOtpRequestTimeoutProvider));
      if (!_isCurrent(revision)) {
        return false;
      }
      ref
          .read(pendingEmailOtpProvider.notifier)
          .set(
            PendingEmailOtp(
              email: trimmedEmail,
              returnTo: sanitizeReturnDestination(returnTo),
            ),
          );
      state = AuthCommandState(
        phase: AuthCommandPhase.codeSent,
        resendAvailableAt: ref.read(authClockProvider)().add(resendCooldown),
      );
      return true;
    } on TimeoutException {
      if (!_isCurrent(revision)) {
        return false;
      }
      state = const AuthCommandState(failure: AuthFailureKind.requestTimedOut);
      return false;
    } catch (error) {
      if (!_isCurrent(revision)) {
        return false;
      }
      state = AuthCommandState(failure: mapAuthFailure(error));
      return false;
    }
  }

  Future<bool> resendCode() async {
    if (state.isBusy) {
      return false;
    }
    final pending = ref.read(pendingEmailOtpProvider);
    if (pending == null) {
      return false;
    }

    final availableAt = state.resendAvailableAt;
    if (availableAt != null &&
        ref.read(authClockProvider)().isBefore(availableAt)) {
      state = AuthCommandState(
        phase: AuthCommandPhase.codeSent,
        failure: AuthFailureKind.rateLimited,
        resendAvailableAt: availableAt,
      );
      return false;
    }

    return requestCode(email: pending.email, returnTo: pending.returnTo);
  }

  Future<bool> verifyCode(String token) async {
    if (state.isBusy) {
      return false;
    }
    final pending = ref.read(pendingEmailOtpProvider);
    if (pending == null) {
      return false;
    }
    final normalizedToken = token.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedToken)) {
      state = AuthCommandState(
        failure: AuthFailureKind.invalidCode,
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }

    final revision = ++_flowRevision;
    state = AuthCommandState(
      phase: AuthCommandPhase.verifyingCode,
      resendAvailableAt: state.resendAvailableAt,
    );
    try {
      final identity = await ref
          .read(authGatewayProvider)
          .verifyEmailOtp(email: pending.email, token: normalizedToken);
      return await _completeSignIn(identity, revision);
    } catch (error) {
      if (!_isCurrent(revision)) {
        return false;
      }
      state = AuthCommandState(
        failure: mapAuthFailure(error),
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }
  }

  Future<bool> signInWithProvider(AuthProvider provider) async {
    if (state.isBusy) {
      return false;
    }
    final adapter = ref.read(providerAuthAdapterProvider);
    if (!adapter.isAvailable(provider)) {
      state = AuthCommandState(
        failure: AuthFailureKind.serviceUnavailable,
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }

    final revision = ++_flowRevision;
    final previousState = state;
    state = AuthCommandState(
      phase: AuthCommandPhase.signingInWithProvider,
      resendAvailableAt: previousState.resendAvailableAt,
    );
    try {
      final result = await adapter.signIn(provider);
      if (!_isCurrent(revision)) {
        return false;
      }
      switch (result) {
        case ProviderAuthSuccess(:final identity):
          return await _completeSignIn(identity, revision);
        case ProviderAuthCancelled():
          // Dismissal leaves the prior OTP flow usable, without an error banner.
          state = AuthCommandState(
            phase: previousState.phase,
            resendAvailableAt: previousState.resendAvailableAt,
          );
          return false;
        case ProviderAuthFailure(:final failure):
          state = AuthCommandState(
            failure: failure,
            resendAvailableAt: previousState.resendAvailableAt,
          );
          return false;
      }
    } catch (error) {
      if (!_isCurrent(revision)) {
        return false;
      }
      state = AuthCommandState(
        failure: mapAuthFailure(error),
        resendAvailableAt: previousState.resendAvailableAt,
      );
      return false;
    }
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _flowRevision;

  Future<bool> retryProfileSetup() async {
    if (state.isBusy) {
      return false;
    }
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null) {
      return false;
    }

    return _completeSignIn(identity, ++_flowRevision);
  }

  /// One completion owner for OTP, future providers, and anchor-creation retry.
  Future<bool> _completeSignIn(AuthIdentity identity, int revision) async {
    if (!_isCurrent(revision)) {
      return false;
    }
    ref.read(authSessionProvider.notifier).markCheckingProfile(identity);
    state = AuthCommandState(
      phase: AuthCommandPhase.completingProfile,
      resendAvailableAt: state.resendAvailableAt,
    );
    try {
      await ref.read(profileAnchorGatewayProvider).ensureFor(identity.id);
      if (!_isCurrent(revision)) {
        return false;
      }
      final readiness = await ref
          .read(profileAnchorGatewayProvider)
          .readinessFor(identity.id);
      if (!_isCurrent(revision)) {
        return false;
      }
      if (readiness == ProfileAnchorReadiness.complete) {
        ref.read(authSessionProvider.notifier).markProfileReady(identity);
      } else {
        ref
            .read(authSessionProvider.notifier)
            .markProfileSetupRequired(
              identity,
              hasProfileAnchor: readiness == ProfileAnchorReadiness.incomplete,
            );
      }
      ref.read(pendingEmailOtpProvider.notifier).clear();
      state = const AuthCommandState();
      return true;
    } catch (_) {
      if (!_isCurrent(revision)) {
        return false;
      }
      ref
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(identity, hasProfileAnchor: false);
      state = AuthCommandState(
        failure: AuthFailureKind.profileSetup,
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    if (state.isBusy) {
      return;
    }
    final revision = ++_flowRevision;
    state = const AuthCommandState(phase: AuthCommandPhase.signingOut);
    try {
      await ref.read(authGatewayProvider).signOut();
      if (!_isCurrent(revision)) {
        return;
      }
      ref.read(pendingEmailOtpProvider.notifier).clear();
      ref.read(authSessionProvider.notifier).markSignedOut();
      state = const AuthCommandState(didSignOut: true);
    } catch (error) {
      if (!_isCurrent(revision)) {
        return;
      }
      state = AuthCommandState(failure: mapAuthFailure(error));
    }
  }
}

AuthFailureKind mapAuthFailure(Object error) {
  if (error is AuthRetryableFetchException) {
    return AuthFailureKind.networkUnavailable;
  }
  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    if (code.contains('email') && code.contains('invalid')) {
      return AuthFailureKind.invalidEmail;
    }
    if (code.contains('expired')) {
      return AuthFailureKind.expiredCode;
    }
    if (code.contains('otp') || code.contains('token')) {
      return AuthFailureKind.invalidCode;
    }
    if (code.contains('rate') || error.statusCode == '429') {
      return AuthFailureKind.rateLimited;
    }
    final status = int.tryParse(error.statusCode ?? '');
    if (status != null && status >= 500) {
      return AuthFailureKind.serviceUnavailable;
    }
  }
  return AuthFailureKind.unexpected;
}

bool _isValidEmail(String value) {
  return value.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
}

final authCommandProvider =
    NotifierProvider<AuthCommandController, AuthCommandState>(
      AuthCommandController.new,
    );
