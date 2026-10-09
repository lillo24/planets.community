import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/map_discovery.dart';

class MapViewButton extends StatelessWidget {
  const MapViewButton({required this.origin, this.prepare, super.key});
  final MapDiscoveryOrigin origin;
  final VoidCallback? prepare;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        children: [
          Semantics(
            selected: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list),
                  const SizedBox(width: 8),
                  Text(l10n.mapList),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            key: Key('map-open-${origin.name}'),
            icon: const Icon(Icons.map_outlined),
            label: Text(l10n.mapView),
            onPressed: () {
              prepare?.call();
              FocusScope.of(context).unfocus();
              context.push('/discover/map/${origin.name}');
            },
          ),
        ],
      ),
    );
  }
}
