import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';

enum BrowseActivityType { proposals, tavoli }

class BrowseActivitySwitcher extends StatelessWidget {
  const BrowseActivitySwitcher({required this.selected, super.key});

  final BrowseActivityType selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
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
            value: BrowseActivityType.tavoli,
            label: Text(l10n.browseTavoliChoice),
            icon: const Icon(Icons.autorenew),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) {
          switch (selection.single) {
            case BrowseActivityType.proposals:
              context.go('/proposals');
            case BrowseActivityType.tavoli:
              context.go('/tavoli');
          }
        },
      ),
    );
  }
}
