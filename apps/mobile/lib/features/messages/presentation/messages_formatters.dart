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
