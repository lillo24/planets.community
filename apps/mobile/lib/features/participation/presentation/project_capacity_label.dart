import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/project_capacity.dart';
import 'project_capacity_presentation.dart';

class ProjectCapacityLabel extends StatelessWidget {
  const ProjectCapacityLabel({
    required this.capacity,
    required this.presentation,
    this.style,
    this.icon = true,
    super.key,
  });

  final ProjectCapacitySnapshot capacity;
  final ProjectCapacityPresentation presentation;
  final TextStyle? style;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reveal =
        presentation == ProjectCapacityPresentation.managerExact ||
        shouldRevealPublicProjectCounts(capacity);
    final summary = projectCapacityText(l10n, capacity, revealExact: reveal);
    final label = reveal
        ? '$summary · '
              '${l10n.projectSocialPeopleInvolved(capacity.socialPeopleCount)}'
        : summary;
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
  ProjectCapacitySnapshot capacity, {
  required bool revealExact,
}) {
  final limit = capacity.registrationCapacity;
  final organizerText = capacity.countOrganizersTowardCapacity
      ? l10n.projectOrganizerIncludedCount(capacity.organizerCount)
      : '+${l10n.projectOrganizerCount(capacity.organizerCount)}';
  if (limit == null) {
    return '${l10n.projectCapacityNotSet} · $organizerText';
  }
  if (!revealExact) {
    final intendedCapacity = capacity.countOrganizersTowardCapacity
        ? l10n.projectCapacityLimit(limit)
        : l10n.projectCapacityUpToParticipants(limit);
    return '$intendedCapacity · $organizerText';
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
