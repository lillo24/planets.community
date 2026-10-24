import '../../../l10n/generated/app_localizations.dart';
import '../domain/moderation_models.dart';

/// Generic type labels use the typed wire kind; all other authorized server
/// summaries keep their existing contract. Never look up private target content.
String moderationTargetLabel(
  AppLocalizations l,
  ModerationTargetKind kind,
  String summary,
) => switch (kind) {
  ModerationTargetKind.cocreatePost => l.moderationPeoplePost,
  ModerationTargetKind.cocreateInterest => l.moderationPeopleInterest,
  ModerationTargetKind.cocreateContactMessage =>
    l.moderationPeopleContactMessage,
  ModerationTargetKind.cocreateRoomMessage => l.moderationPeopleRoomMessage,
  ModerationTargetKind.cocreateCommunityProposal =>
    l.moderationPeopleCommunityProposal,
  ModerationTargetKind.resourceRequest => l.moderationResourceRequest,
  ModerationTargetKind.groupDiscussionMessage => l.discussionReportLabel,
  _ => summary,
};
