import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_models.dart';

String authFailureMessage(AppLocalizations l10n, AuthFailureKind failure) {
  return switch (failure) {
    AuthFailureKind.invalidEmail => l10n.authInvalidEmail,
    AuthFailureKind.invalidCode => l10n.authInvalidCode,
    AuthFailureKind.expiredCode => l10n.authExpiredCode,
    AuthFailureKind.rateLimited => l10n.authRateLimited,
    AuthFailureKind.requestTimedOut => l10n.authRequestTimedOut,
    AuthFailureKind.networkUnavailable => l10n.authNetworkUnavailable,
    AuthFailureKind.serviceUnavailable => l10n.authServiceUnavailable,
    AuthFailureKind.profileSetup => l10n.authProfileSetupFailure,
    AuthFailureKind.unexpected => l10n.authUnexpectedFailure,
  };
}
