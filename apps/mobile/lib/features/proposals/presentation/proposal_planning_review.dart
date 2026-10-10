import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

/// Advisory preview only: the confirmed server mutation rechecks authority,
/// current photos, future schedule and capacity atomically.
class ProposalPlanningReview extends StatelessWidget {
  const ProposalPlanningReview({
    required this.proposal,
    required this.requirements,
    super.key,
  });
  final OwnProposal proposal;
  final ProposalPromotionRequirements requirements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = <String, String>{
      'title': l10n.proposalTitleLabel,
      'summary': l10n.proposalSummaryLabel,
      'description': l10n.proposalDescriptionLabel,
      'starts_at': l10n.proposalStartLabel,
      'ends_at': l10n.proposalEndLabel,
      'event_timezone': l10n.proposalTimezoneShortLabel,
      'country_code': l10n.proposalCityLabel,
      'locality': l10n.proposalCityLabel,
      'public_location_label': l10n.proposalCityLabel,
      'registration_capacity': l10n.projectRegistrationCapacityLabel,
      'creator_profile': l10n.proposalOrganizerLabel,
      'creator_photo': l10n.proposalPlanningPhotoRequired,
      'organizer_photo': l10n.proposalPlanningPhotoRequired,
    };
    final missing = requirements.missingFields
        .map((key) => labels[key] ?? l10n.proposalPlanningChanged)
        .toSet();
    String date(DateTime? instant) =>
        instant == null || proposal.eventTimezone == null
        ? l10n.proposalDateUndecided
        : formatProposalDateTime(
            instant,
            proposal.eventTimezone!,
            Localizations.localeOf(context).toLanguageTag(),
          );
    return AlertDialog(
      title: Text(l10n.proposalCompletePlanning),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              requirements.canPromote
                  ? l10n.proposalPlanningConfirmHelp
                  : l10n.proposalPlanningMissingHelp,
            ),
            const SizedBox(height: 16),
            if (!requirements.canPromote)
              for (final label in missing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $label'),
                ),
            Text(
              proposal.title ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(proposal.summary ?? ''),
            if (proposal.description != null) Text(proposal.description!),
            const SizedBox(height: 12),
            Text('${l10n.proposalStartLabel}: ${date(proposal.startsAt)}'),
            Text('${l10n.proposalEndLabel}: ${date(proposal.endsAt)}'),
            Text(proposal.publicLocationLabel ?? l10n.proposalPlaceUndecided),
            Text(
              proposal.capacity.registrationCapacity == null
                  ? l10n.projectCapacityNotSet
                  : l10n.projectCapacityLimit(
                      proposal.capacity.registrationCapacity!,
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.proposalPlanningReturn),
        ),
        if (requirements.canPromote)
          FilledButton(
            key: const Key('proposal-confirm-promotion'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.proposalPlanningConfirm),
          ),
      ],
    );
  }
}
