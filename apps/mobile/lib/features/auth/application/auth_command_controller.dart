import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_gateway.dart';
import '../domain/auth_models.dart';
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
  AuthCommandState build() {
    ref.onDispose(() => _flowRevision++);
    return const AuthCommandState();
  }

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
    final session = ref.read(authSessionProvider.notifier);
    final sessionEpoch = session.verificationEpoch;
    try {
      final identity = await ref
          .read(authGatewayProvider)
          .verifyEmailOtp(email: pending.email, token: normalizedToken);
      if (!_isCurrent(revision)) {
        return false;
      }
      if (!session.acceptsVerification(identity, sessionEpoch)) {
        cancelFlow();
        return false;
      }
      state = AuthCommandState(
        phase: AuthCommandPhase.completingProfile,
        resendAvailableAt: state.resendAvailableAt,
      );
      final outcome = await ref
          .read(authSessionProvider.notifier)
          .completeProfileSetup(identity);
      if (!_isCurrent(revision)) return false;
      if (outcome == AuthBootstrapOutcome.superseded) {
        cancelFlow();
        return false;
      }
      if (outcome == AuthBootstrapOutcome.failed) {
        state = AuthCommandState(
          failure: AuthFailureKind.profileSetup,
          resendAvailableAt: state.resendAvailableAt,
        );
        return false;
      }

      ref.read(pendingEmailOtpProvider.notifier).clear();
      state = const AuthCommandState();
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) {
        return false;
      }
      if (session.verificationEpoch != sessionEpoch) {
        cancelFlow();
        return false;
      }
      state = AuthCommandState(
        failure: mapAuthFailure(error),
        resendAvailableAt: state.resendAvailableAt,
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

    final revision = ++_flowRevision;
    state = const AuthCommandState(phase: AuthCommandPhase.completingProfile);
    final outcome = await ref
        .read(authSessionProvider.notifier)
        .completeProfileSetup(identity);
    if (!_isCurrent(revision)) {
      return false;
    }
    if (outcome == AuthBootstrapOutcome.superseded) {
      cancelFlow();
      return false;
    }
    if (outcome == AuthBootstrapOutcome.completed) {
      ref.read(pendingEmailOtpProvider.notifier).clear();
      state = const AuthCommandState();
      return true;
    } else {
      state = const AuthCommandState(failure: AuthFailureKind.profileSetup);
      return false;
    }
  }

  Future<void> signOut() async {
    if (state.isBusy) {
      return;
    }
    state = const AuthCommandState(phase: AuthCommandPhase.signingOut);
    // Invalidate an in-flight verification/setup completion before signing out.
    _flowRevision++;
    try {
      await ref.read(authGatewayProvider).signOut();
      ref.read(pendingEmailOtpProvider.notifier).clear();
      ref.read(authSessionProvider.notifier).markSignedOut();
      state = const AuthCommandState();
    } catch (error) {
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
