import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../features/settings/application/activities_split_preference_controller.dart';

import '../../l10n/generated/app_localizations.dart';

enum BrowseActivityType { proposals, tavoli, activities }

class BrowseActivitySwitcher extends ConsumerWidget {
  const BrowseActivitySwitcher({
    required this.selected,
    this.onChanged,
    this.splitMode,
    super.key,
  });

  final BrowseActivityType? selected;
  final bool? splitMode;
  final ValueChanged<BrowseActivityType>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split =
        splitMode ?? ref.watch(activitiesSplitPreferenceProvider).enabled;
    final effectiveSelected = split && selected == BrowseActivityType.tavoli
        ? BrowseActivityType.activities
        : selected;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<BrowseActivityType>(
            key: const Key('browse-activity-switcher'),
            segments: [
              ButtonSegment(
                value: BrowseActivityType.proposals,
                label: Text(l10n.browseProposalsChoice),
                icon: const Icon(Icons.event_outlined),
              ),
              ButtonSegment(
                value: split
                    ? BrowseActivityType.activities
                    : BrowseActivityType.tavoli,
                label: Text(
                  split ? l10n.activitiesTitle : l10n.browseTavoliChoice,
                ),
                icon: const Icon(Icons.autorenew),
              ),
            ],
            selected: {?effectiveSelected},
            emptySelectionAllowed: selected == null,
            onSelectionChanged: (selection) {
              if (onChanged != null) {
                onChanged!(selection.single);
                return;
              }
              switch (selection.single) {
                case BrowseActivityType.proposals:
                  context.go('/proposals');
                case BrowseActivityType.tavoli:
                  context.go('/tavoli');
                case BrowseActivityType.activities:
                  context.go('/activities');
              }
            },
          ),
        ),
      ],
    );
  }
}
