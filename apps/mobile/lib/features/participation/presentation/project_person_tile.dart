import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/project_people_models.dart';
import '../../project_delegates/domain/project_delegate_models.dart';

class ProjectPersonTile extends StatelessWidget {
  const ProjectPersonTile({
    required this.person,
    required this.roleLabels,
    required this.onActions,
    required this.actionsLabel,
    this.hasActions = true,
    super.key,
  });
  final ProjectPerson person;
  final List<String> roleLabels;
  final VoidCallback? onActions;
  final String actionsLabel;
  final bool hasActions;
  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('people-person-${person.profileId}'),
    onLongPress: hasActions ? onActions : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  roleLabels.join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasActions)
            IconButton(
              key: Key('people-actions-${person.profileId}'),
              tooltip: actionsLabel,
              icon: const Icon(Icons.more_horiz),
              onPressed: onActions,
            ),
        ],
      ),
    ),
  );
}

@Preview(
  name: 'Organizer and participant',
  group: 'Project People',
  size: Size(400, 130),
)
Widget projectPersonTilePreview() => Material(
  child: ProjectPersonTile(
    person: const ProjectPerson(
      profileId: 'preview',
      displayName: 'Sara',
      isCreator: false,
      roleRank: 1,
      authorityRole: ProjectDelegatedAuthorityRole.coCreator,
      delegateId: 'role',
      membershipId: 'membership',
    ),
    roleLabels: const ['Co-creator', 'Participant'],
    actionsLabel: 'Member actions',
    onActions: () {},
  ),
);
