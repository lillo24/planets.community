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
    final label = projectCapacityText(
      l10n,
      capacity,
      revealExact: reveal,
      managerExact: presentation == ProjectCapacityPresentation.managerExact,
    );
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
  bool managerExact = false,
}) {
  final limit = capacity.registrationCapacity;
  if (managerExact) {
    final usage = limit == null
        ? l10n.projectPeopleCount(capacity.ordinaryParticipantCount)
        : capacity.countOrganizersTowardCapacity
        ? l10n.projectCapacityUsage(capacity.capacityUsedCount, limit)
        : l10n.projectCapacityParticipantUsage(
            capacity.ordinaryParticipantCount,
            limit,
          );
    final organizers = capacity.countOrganizersTowardCapacity
        ? l10n.projectOrganizerIncludedCount(capacity.organizerCount)
        : l10n.projectOrganizerCount(capacity.organizerCount);
    final summary = '$usage\n$organizers';
    return capacity.isFull ? l10n.projectCapacityFullLabel(summary) : summary;
  }
  if (limit == null) {
    return revealExact
        ? l10n.projectPeopleCount(capacity.socialPeopleCount)
        : l10n.projectCapacityNotSet;
  }
  // Both sides measure unique people. Registration slots may exclude organizers;
  // this presentation total must never change canonical admission enforcement.
  final peopleCapacity =
      limit +
      (capacity.countOrganizersTowardCapacity ? 0 : capacity.organizerCount);
  if (!revealExact) {
    return l10n.projectPeopleCapacity(peopleCapacity);
  }
  final summary = l10n.projectPeopleFraction(
    capacity.socialPeopleCount,
    peopleCapacity,
  );
  return capacity.isFull ? l10n.projectCapacityFullLabel(summary) : summary;
}
