import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class ManualLocationNotice extends StatelessWidget {
  const ManualLocationNotice({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.medium),
    child: Text(
      AppLocalizations.of(context).locationManualEntryNotice,
      key: const Key('location-manual-fallback'),
    ),
  );
}

/// Takes no point/ID/address and creates no map request, URL or platform view.
/// Kept below the detail's canonical location text, never in scrolling feed cards.
class UnavailableLocationMap extends StatelessWidget {
  const UnavailableLocationMap({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('location-map-unavailable'),
    padding: const EdgeInsets.only(top: AppSpacing.medium),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(child: Icon(Icons.map_outlined)),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(AppLocalizations.of(context).locationMapUnavailable),
        ),
      ],
    ),
  );
}
