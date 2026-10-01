import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/project_capacity.dart';

class ProjectCapacityLabel extends StatelessWidget {
  const ProjectCapacityLabel({
    required this.capacity,
    this.style,
    this.icon = true,
    super.key,
  });

  final ProjectCapacitySnapshot capacity;
  final TextStyle? style;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label =
        '${projectCapacityText(l10n, capacity)} · '
        '${l10n.projectSocialPeopleInvolved(capacity.socialPeopleCount)}';
    if (!icon) return Text(label, style: style);
    return Row(
      children: [
        const Icon(Icons.groups_outlined, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: style)),
      ],
    );
  }
}

String projectCapacityText(
  AppLocalizations l10n,
  ProjectCapacitySnapshot capacity,
) {
  final limit = capacity.registrationCapacity;
  final organizerText = capacity.countOrganizersTowardCapacity
      ? l10n.projectOrganizerIncludedCount(capacity.organizerCount)
      : '+${l10n.projectOrganizerCount(capacity.organizerCount)}';
  if (limit == null) {
    return '${l10n.projectCapacityNotSet} · $organizerText';
  }
  final usage = capacity.countOrganizersTowardCapacity
      ? l10n.projectCapacityUsage(capacity.capacityUsedCount, limit)
      : l10n.projectCapacityParticipantUsage(
          capacity.ordinaryParticipantCount,
          limit,
        );
  final summary = '$usage · $organizerText';
  return capacity.isFull ? l10n.projectCapacityFullLabel(summary) : summary;
}
