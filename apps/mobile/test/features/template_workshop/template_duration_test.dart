import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_duration.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final language in ['it', 'en']) {
    test('$language duration keeps exact minute values and marks rounding', () {
      final l = lookupAppLocalizations(Locale(language));
      expect(templateDuration(l, 3600), language == 'it' ? '1 ora' : '1 hour');
      expect(
        templateDuration(l, 10800.0),
        language == 'it' ? '3 ore' : '3 hours',
      );
      expect(
        templateDuration(l, 5400),
        language == 'it' ? '1 ora e 30 minuti' : '1 hour and 30 minutes',
      );
      expect(
        templateDuration(l, 60),
        language == 'it' ? '1 minuto' : '1 minute',
      );
      expect(
        templateDuration(l, 0.5),
        language == 'it' ? 'meno di un minuto' : 'less than a minute',
      );
      expect(
        templateDuration(l, 3600.1),
        language == 'it' ? 'circa 1 ora' : 'about 1 hour',
      );
      expect(
        templateDuration(l, 259200),
        language == 'it' ? '72 ore' : '72 hours',
      );
      final huge = templateDuration(l, 1e100);
      expect(huge, startsWith(language == 'it' ? 'circa ' : 'about '));
      expect(huge, contains('E'));
      expect(() => templateDuration(l, 0), throwsFormatException);
    });
  }
}
