import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  test('English and Italian catalogs expose representative messages', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final italian = lookupAppLocalizations(const Locale('it'));

    expect(AppLocalizations.supportedLocales, const [
      Locale('en'),
      Locale('it'),
    ]);
    expect(english.navigationBrowse, 'Browse');
    expect(italian.navigationBrowse, 'Esplora');
    expect(english.projectRegistrationCapacityLabel, 'Registration capacity');
    expect(italian.projectRegistrationCapacityLabel, 'Capienza iscrizioni');
    expect(
      english.projectCountOrganizersCapacityLabel,
      'Count organizers toward capacity',
    );
    expect(
      italian.projectCountOrganizersCapacityLabel,
      'Conta gli organizzatori nella capienza',
    );
    expect(english.projectSocialPeopleInvolved(3), '3 unique people involved');
    expect(
      italian.projectSocialPeopleInvolved(3),
      '3 persone uniche coinvolte',
    );
    expect(
      italian.authVerifyDescription('m***@example.com'),
      'Abbiamo inviato un codice a 6 cifre a m***@example.com.',
    );
    expect(italian.notificationsUnreadSemantics(1), 'Notifiche, 1 non letta');
    expect(italian.notificationsUnreadSemantics(3), 'Notifiche, 3 non lette');
  });

  testWidgets('an Italian device locale resolves Italian copy and weekdays', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('it', 'IT'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const _LocalizationProbeApp());
    await tester.pumpAndSettle();

    expect(find.text('Esplora'), findsOneWidget);
    expect(find.text('it'), findsOneWidget);
    expect(find.text('lunedì'), findsOneWidget);
  });

  testWidgets('an unsupported device locale falls back to English', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('fr', 'FR'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const _LocalizationProbeApp());
    await tester.pumpAndSettle();

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('en'), findsOneWidget);
  });

  testWidgets('an English override wins over an Italian device locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('it', 'IT'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const _LocalizationProbeApp(locale: Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('en'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
  });

  testWidgets('an Italian override wins over an English device locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('en', 'US'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const _LocalizationProbeApp(locale: Locale('it')));
    await tester.pumpAndSettle();

    expect(find.text('Esplora'), findsOneWidget);
    expect(find.text('it'), findsOneWidget);
    expect(find.text('lunedì'), findsOneWidget);
  });
}

class _LocalizationProbeApp extends StatelessWidget {
  const _LocalizationProbeApp({this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final locale = Localizations.localeOf(context);
          final l10n = AppLocalizations.of(context);
          final weekday = DateFormat.EEEE(locale.toLanguageTag())
              .format(DateTime(2024, 1));

          return Column(
            children: [
              Text(l10n.navigationBrowse),
              Text(locale.toLanguageTag()),
              Text(weekday),
            ],
          );
        },
      ),
    );
  }
}
