import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'activity_card.dart';

@Preview(name: 'My activities / compact card', size: Size(390, 160))
Widget activityCardPreview() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ActivityCard(
        title: 'Orto di quartiere',
        status: 'Bozza',
        metadata: 'Progetto · 20 ott.',
        onTap: () {},
      ),
    ),
  ),
);
