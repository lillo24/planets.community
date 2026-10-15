import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/group_controllers.dart';
import '../domain/group_models.dart';

String groupKindLabel(AppLocalizations l, GroupKind kind) =>
    kind == GroupKind.informal ? l.groupsInformal : l.groupsOrganization;
String groupStateLabel(AppLocalizations l, GroupPublication state) =>
    switch (state) {
      GroupPublication.draft => l.groupsDraft,
      GroupPublication.published => l.groupsPublished,
      GroupPublication.archived => l.groupsArchived,
    };
String groupFailureLabel(AppLocalizations l, GroupFailure failure) =>
    switch (failure) {
      GroupFailure.stale => l.groupsStale,
      GroupFailure.invalid => l.groupsInvalid,
      GroupFailure.denied => l.groupsDenied,
      GroupFailure.prerequisite => l.groupsPrerequisite,
      GroupFailure.setup => l.groupsSetup,
      GroupFailure.uncertain => l.groupsUncertain,
    };
void closeGroups(BuildContext context, [String fallback = '/groups']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

PreferredSizeWidget groupAppBar(
  BuildContext context,
  String title, {
  String fallback = '/groups',
  VoidCallback? close,
  List<Widget>? actions,
}) => pageAppBar(
  context,
  title: Text(title),
  onClose: close ?? () => closeGroups(context, fallback),
  actions: actions,
);

class GroupSummary extends StatelessWidget {
  const GroupSummary(this.group, {this.full = false, super.key});
  final PublicGroup group;
  final bool full;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = group.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: const Icon(Icons.groups_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                c.name.isEmpty ? l.groupsUntitled : c.name,
                style: full
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          groupKindLabel(l, c.kind),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (c.locality != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(c.locality!),
          ),
        if (c.volunteering)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l.groupsVolunteer),
          ),
        const SizedBox(height: 12),
        Text(
          c.description,
          maxLines: full ? null : 3,
          overflow: full ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class GroupLoadError extends StatelessWidget {
  const GroupLoadError({required this.retry, this.error, super.key});
  final VoidCallback retry;
  final Object? error;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error != null && groupFailure(error!) == GroupFailure.setup
                ? l.groupsSetup
                : l.groupsLoadError,
          ),
          TextButton(onPressed: retry, child: Text(l.groupsRetry)),
        ],
      ),
    );
  }
}
