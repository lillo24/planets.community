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
    final text = projectCapacityText(AppLocalizations.of(context), capacity);
    if (!icon) return Text(text, style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.groups_outlined, size: 18),
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
  }
}

String projectCapacityText(
  AppLocalizations l10n,
  ProjectCapacitySnapshot capacity,
) {
  final limit = capacity.peopleCapacity;
  if (limit == null) return l10n.projectCapacityNotSet;
  return capacity.isFull
      ? l10n.projectCapacityFullOccupancy(capacity.currentPeopleCount, limit)
      : l10n.projectCapacityOccupancy(capacity.currentPeopleCount, limit);
}
