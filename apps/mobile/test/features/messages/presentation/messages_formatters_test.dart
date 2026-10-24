import 'package:flutter/material.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planets_mobile/features/messages/presentation/messages_formatters.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations_en.dart';
import 'package:planets_mobile/l10n/generated/app_localizations_it.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });
  for (final language in ['it', 'en']) {
    testWidgets(
      'CQ1 full message metadata omits seconds and fractions in $language',
      (tester) async {
        final instant = DateTime(2026, 10, 24, 13, 14, 45, 123, 456);
        final original = instant.microsecondsSinceEpoch;
        late String formatted;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                formatted = messageDate(context, instant);
                return Text(formatted);
              },
            ),
          ),
        );
        expect(formatted, contains('13:14'));
        expect(formatted, isNot(contains('13:14:45')));
        expect(formatted, isNot(contains('123456')));
        expect(instant.microsecondsSinceEpoch, original);
        expect(formatted, contains(language == 'it' ? 'ott' : 'Oct'));
      },
    );
  }
  test(
    'local calendar day chooses time, localized weekday, then compact date',
    () {
      final now = DateTime(2026, 10, 7, 18);
      for (final locale in ['en', 'it']) {
        expect(
          formatMessageActivityDate(
            DateTime(2026, 10, 7, 10, 15),
            now: now,
            locale: locale,
          ),
          '10:15',
        );
        expect(
          formatMessageActivityDate(
            DateTime(2026, 10, 6, 23, 59),
            now: now,
            locale: locale,
          ),
          locale == 'en' ? 'Tue' : 'mar',
        );
        expect(
          formatMessageActivityDate(
            DateTime(2026, 10, 1),
            now: now,
            locale: locale,
          ),
          locale == 'en' ? 'Thu' : 'gio',
        );
        expect(
          formatMessageActivityDate(
            DateTime(2026, 9, 30),
            now: now,
            locale: locale,
          ),
          locale == 'en' ? '9/30/2026' : '30/09/2026',
        );
        expect(
          formatMessageActivityDate(
            DateTime(2025, 10, 7),
            now: now,
            locale: locale,
          ),
          locale == 'en' ? '10/7/2025' : '07/10/2025',
        );
      }
    },
  );
  test('request activity previews are localized without Project context', () {
    final en = AppLocalizationsEn();
    final it = AppLocalizationsIt();
    expect(
      JoinRequestStatus.values.map((s) => messageRequestActivityLabel(en, s)),
      [
        'Pending request',
        'Request accepted',
        'Request rejected',
        'Request withdrawn',
      ],
    );
    expect(
      JoinRequestStatus.values.map((s) => messageRequestActivityLabel(it, s)),
      [
        'Richiesta in attesa',
        'Richiesta accettata',
        'Richiesta rifiutata',
        'Richiesta ritirata',
      ],
    );
    expect(
      it.pairChatReadOnlyReactivation,
      'Potrai inviare messaggi quando ci sarà una nuova richiesta in attesa.',
    );
  });
}
