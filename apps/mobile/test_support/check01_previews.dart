import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/project_organization/presentation/project_organization_sheet.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'check01_fixture.dart';

// Standalone data-free debug target; never initializes Supabase or product auth.
void main() => runApp(organizationProposedPreview());

@Preview(name: 'CHECK01 private proposal - IT 320dp', size: Size(320, 900))
Widget organizationProposedPreview() => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('it'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SafeArea(
      child: ProjectOrganizationContent(
        snapshot: organizationFixture(),
        onCommand: (_) async => false,
      ),
    ),
  ),
);

@Preview(name: 'CHECK01 replacement - EN dark 320dp', size: Size(320, 900))
Widget organizationReplacementPreview() => MaterialApp(
  theme: AppTheme.dark,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SafeArea(
      child: ProjectOrganizationContent(
        snapshot: organizationFixture(state: 'replacement'),
        onCommand: (_) async => false,
      ),
    ),
  ),
);
