import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';

class LocationAttribution extends StatelessWidget {
  const LocationAttribution({this.centered = false, super.key});

  /// Detail credits share one compact row, wrapping text inside 48dp links.
  /// Other surfaces retain their existing wrapping-button layout.
  final bool centered;
  @override
  Widget build(BuildContext context) {
    final links = [
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
    ];
    if (centered) {
      return Align(
        key: const Key('location-attribution'),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(flex: 2, child: links[0]),
            const SizedBox(width: AppSpacing.small),
            Flexible(flex: 3, child: links[1]),
          ],
        ),
      );
    }
    return Wrap(
      key: const Key('location-attribution'),
      spacing: AppSpacing.small,
      children: links,
    );
  }

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
      child: centered
          ? InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : TextButton(
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
