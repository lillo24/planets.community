import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../domain/project_people_models.dart';
import '../../project_delegates/domain/project_delegate_models.dart';

class ProjectPersonTile extends StatelessWidget {
  const ProjectPersonTile({
    required this.person,
    required this.roleLabels,
    required this.onActions,
    required this.actionsLabel,
    super.key,
  });
  final ProjectPerson person;
  final List<String> roleLabels;
  final VoidCallback? onActions;
  final String actionsLabel;
  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('people-person-${person.profileId}'),
    title: Text(person.displayName),
    subtitle: Wrap(
      spacing: 6,
      children: [for (final role in roleLabels) Chip(label: Text(role))],
    ),
    onLongPress: onActions,
    trailing: IconButton(
      key: Key('people-actions-${person.profileId}'),
      tooltip: actionsLabel,
      icon: const Icon(Icons.more_horiz),
      onPressed: onActions,
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
