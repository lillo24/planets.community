import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Discloses secondary browse filters without applying or clearing them.
class BrowseFilterButton extends StatelessWidget {
  const BrowseFilterButton({
    required this.expanded,
    required this.hasActiveFilters,
    required this.onPressed,
    super.key,
  });

  final bool expanded;
  final bool hasActiveFilters;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = expanded ? l10n.browseHideFilters : l10n.browseShowFilters;
    return Semantics(
      expanded: expanded,
      child: IconButton(
        tooltip: hasActiveFilters
            ? '$label · ${l10n.browseFiltersActive}'
            : label,
        onPressed: onPressed,
        icon: Badge(
          key: const Key('browse-active-filters'),
          isLabelVisible: hasActiveFilters,
          child: Icon(expanded ? Icons.filter_list_off : Icons.filter_list),
        ),
      ),
    );
  }
}
