import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/map_discovery.dart';

/// Equal-width List/Map options: plain selection and a separate outlined action.
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
    return IntrinsicHeight(
      key: const Key('map-view-selector'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _option(
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
          const SizedBox(width: AppSpacing.small),
          _option(
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
    );
  }

  Widget _option(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required Key key,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 12);
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.small),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Expanded(
      child: Semantics(
        key: key,
        label: label,
        button: true,
        selected: selected,
        onTap: selected ? null : onTap,
        excludeSemantics: true,
        child: selected
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: padding,
                  child: IconTheme.merge(
                    data: IconThemeData(color: scheme.onSurface),
                    child: DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: scheme.onSurface),
                      child: content,
                    ),
                  ),
                ),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: padding,
                ),
                onPressed: onTap,
                child: content,
              ),
      ),
    );
  }
}
