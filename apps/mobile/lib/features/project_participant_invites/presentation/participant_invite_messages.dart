import '../../../l10n/generated/app_localizations.dart';
import '../domain/participant_invitation_models.dart';

String participantInviteFailureMessage(
  AppLocalizations l10n,
  ParticipantInviteFailure failure,
) => switch (failure) {
  ParticipantInviteFailure.full => l10n.projectNoSpots,
  ParticipantInviteFailure.unavailable => l10n.participantInviteUnavailable,
  ParticipantInviteFailure.forbidden => l10n.participantInviteForbidden,
  ParticipantInviteFailure.profileRequired => l10n.participantInviteProfile,
  ParticipantInviteFailure.invalidInput => l10n.participantInviteInvalidInput,
  ParticipantInviteFailure.malformed => l10n.participantInviteMalformed,
  ParticipantInviteFailure.network => l10n.projectShareFailure,
};
