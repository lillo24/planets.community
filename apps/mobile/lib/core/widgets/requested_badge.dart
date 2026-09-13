import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class RequestedBadge extends StatelessWidget {
  const RequestedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('browse-requested-badge'),
      label: l10n.browseRequestedSemantics,
      child: ExcludeSemantics(
        child: Chip(
          label: Text(l10n.browseRequestedBadge),
          avatar: const Icon(Icons.hourglass_top, size: 16),
          backgroundColor: scheme.tertiaryContainer,
          labelStyle: TextStyle(
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
