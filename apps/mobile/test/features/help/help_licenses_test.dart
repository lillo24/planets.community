import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/help/presentation/help_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language Help exposes independent dataset attribution in Licences',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HelpScreen(),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('help-licenses-action')));
        await t.tap(find.byKey(const Key('help-licenses-action')));
        await t.pumpAndSettle();
        expect(find.text('ISTAT municipality names'), findsOneWidget);
        await t.tap(find.text('ISTAT municipality names'));
        await t.pumpAndSettle();
        expect(find.textContaining('CC BY 4.0'), findsWidgets);
        expect(
          find.textContaining('https://creativecommons.org/licenses/by/4.0/'),
          findsWidgets,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
