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
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://www.geoapify.com/'),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text('Powered by Geoapify'),
      ),
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text('© OpenStreetMap contributors'),
      ),
    ],
  );
}
