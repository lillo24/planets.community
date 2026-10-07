import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../participation/domain/participation_models.dart';

String messageStatusLabel(AppLocalizations l10n, JoinRequestStatus status) =>
    switch (status) {
      JoinRequestStatus.pending => l10n.participationStatusPending,
      JoinRequestStatus.accepted => l10n.participationStatusAccepted,
      JoinRequestStatus.rejected => l10n.participationStatusRejected,
      JoinRequestStatus.withdrawn => l10n.participationStatusWithdrawn,
    };

String messageProjectKindLabel(AppLocalizations l10n, ProjectKind kind) =>
    switch (kind) {
      ProjectKind.oneTime => l10n.messagesProposal,
      ProjectKind.recurring => l10n.messagesTavolo,
    };

String messageDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final locale = Localizations.localeOf(context).toString();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}

/// Calendar-day rules use the viewer's locale and local timezone. Human activity
/// wins exact request/message timestamp ties in the canonical v4 projection.
String messageActivityDate(
  BuildContext context,
  DateTime date, {
  DateTime? now,
}) {
  return formatMessageActivityDate(
    date,
    now: now ?? DateTime.now(),
    locale: Localizations.localeOf(context).toString(),
  );
}

String formatMessageActivityDate(
  DateTime date, {
  required DateTime now,
  required String locale,
}) {
  final local = date.toLocal();
  final today = now.toLocal();
  final days = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  if (days == 0) return DateFormat.Hm(locale).format(local);
  if (days > 0 && days < 7) return DateFormat.E(locale).format(local);
  return DateFormat.yMd(locale).format(local);
}

String messageRequestActivityLabel(
  AppLocalizations l10n,
  JoinRequestStatus status,
) => switch (status) {
  JoinRequestStatus.pending => l10n.messageRequestPendingPreview,
  JoinRequestStatus.accepted => l10n.messageRequestAcceptedPreview,
  JoinRequestStatus.rejected => l10n.messageRequestRejectedPreview,
  JoinRequestStatus.withdrawn => l10n.messageRequestWithdrawnPreview,
};
