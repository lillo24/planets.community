import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';

class LocationAttribution extends StatelessWidget {
  const LocationAttribution({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    key: const Key('location-attribution'),
    spacing: AppSpacing.small,
    children: [
      _link(
        context,
        'Powered by Geoapify',
        'https://www.geoapify.com/',
        'geoapify',
      ),
      _link(
        context,
        '© OpenStreetMap contributors',
        'https://www.openstreetmap.org/copyright',
        'osm',
      ),
    ],
  );

  Widget _link(
    BuildContext context,
    String label,
    String url,
    String provider,
  ) {
    void open() {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    // One labelled link/action, while the actual button retains keyboard focus.
    return Semantics(
      key: Key('location-attribution-$provider'),
      link: true,
      button: true,
      label: label,
      onTap: open,
      excludeSemantics: true,
      child: TextButton(
        onPressed: open,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          textStyle: Theme.of(context).textTheme.labelSmall
              ?.copyWith(decoration: TextDecoration.underline),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }
}
