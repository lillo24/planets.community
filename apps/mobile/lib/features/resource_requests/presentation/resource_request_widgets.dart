import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/resource_request_models.dart';

String resourceRequestStatusLabel(
  AppLocalizations l10n,
  ResourceRequestStatus status,
) => switch (status) {
  ResourceRequestStatus.pending => l10n.resourceRequestStatusPending,
  ResourceRequestStatus.accepted => l10n.resourceRequestStatusAccepted,
  ResourceRequestStatus.rejected => l10n.resourceRequestStatusRejected,
  ResourceRequestStatus.withdrawn => l10n.resourceRequestStatusWithdrawn,
  ResourceRequestStatus.listingClosed =>
    l10n.resourceRequestStatusListingClosed,
};

String resourceRequestFailureMessage(
  AppLocalizations l10n,
  ResourceRequestFailureKind? failure, {
  required bool loading,
}) => switch (failure) {
  ResourceRequestFailureKind.invalidInput => l10n.resourceRequestInvalidInput,
  ResourceRequestFailureKind.profilePhotoRequired =>
    l10n.profilePhotoScambioRequiredTitle,
  ResourceRequestFailureKind.forbidden => l10n.resourceRequestForbidden,
  ResourceRequestFailureKind.conflict => l10n.resourceRequestChangedElsewhere,
  ResourceRequestFailureKind.interactionUnavailable =>
    l10n.blockingInteractionUnavailable,
  ResourceRequestFailureKind.listingUnavailable =>
    l10n.resourceRequestListingUnavailable,
  ResourceRequestFailureKind.notFound => l10n.resourceRequestNotFound,
  ResourceRequestFailureKind.unavailable || null =>
    loading ? l10n.resourceRequestUnableLoad : l10n.resourceRequestUnableUpdate,
};

String formatResourceRequestDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final locale = Localizations.localeOf(context).toLanguageTag();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}

class ResourceRequestStatusChip extends StatelessWidget {
  const ResourceRequestStatusChip({required this.status, super.key});

  final ResourceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final label = resourceRequestStatusLabel(
      AppLocalizations.of(context),
      status,
    );
    return Semantics(
      label: label,
      child: Chip(
        key: Key('resource-request-status-${status.wireValue}'),
        visualDensity: VisualDensity.compact,
        label: Text(label),
      ),
    );
  }
}
