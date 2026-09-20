import '../../../l10n/generated/app_localizations.dart';
import '../application/resource_exchange_controller.dart';

String resourceExchangeFailureMessage(
  AppLocalizations l10n,
  ResourceExchangeFailureKind failure,
) => switch (failure) {
  ResourceExchangeFailureKind.invalidInput => l10n.resourceExchangeInvalidInput,
  ResourceExchangeFailureKind.forbidden => l10n.resourceExchangeForbidden,
  ResourceExchangeFailureKind.notFound => l10n.resourceExchangeNotFound,
  ResourceExchangeFailureKind.conflict => l10n.resourceExchangeConflict,
  ResourceExchangeFailureKind.cancellationConflict =>
    l10n.resourceExchangeCancellationConflict,
  ResourceExchangeFailureKind.unavailable => l10n.resourceExchangeUnavailable,
};
