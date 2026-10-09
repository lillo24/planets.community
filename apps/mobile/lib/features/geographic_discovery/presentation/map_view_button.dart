import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/map_discovery.dart';

/// Shared equal-width List/Map selector. The selected half never navigates.
class MapViewButton extends StatelessWidget {
  const MapViewButton({
    required this.origin,
    this.prepare,
    this.mapSelected = false,
    super.key,
  });
  final MapDiscoveryOrigin origin;
  final VoidCallback? prepare;
  final bool mapSelected;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('map-view-selector'),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _segment(
              context,
              label: l10n.mapList,
              icon: Icons.list,
              selected: !mapSelected,
              key: Key(mapSelected ? 'map-return-list' : 'map-list-selected'),
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go(switch (origin) {
                      MapDiscoveryOrigin.projects => '/proposals',
                      MapDiscoveryOrigin.tavoli => '/tavoli',
                      MapDiscoveryOrigin.resources => '/resources',
                    }),
            ),
            _segment(
              context,
              label: l10n.mapView,
              icon: Icons.map_outlined,
              selected: mapSelected,
              key: Key(
                mapSelected ? 'map-map-selected' : 'map-open-${origin.name}',
              ),
              onTap: () {
                prepare?.call();
                FocusScope.of(context).unfocus();
                context.push('/discover/map/${origin.name}');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required Key key,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        key: key,
        label: label,
        button: true,
        selected: selected,
        onTap: selected ? null : onTap,
        excludeSemantics: true,
        child: Ink(
          color: selected ? scheme.secondaryContainer : scheme.surface,
          child: InkWell(
            onTap: selected ? null : onTap,
            canRequestFocus: !selected,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
