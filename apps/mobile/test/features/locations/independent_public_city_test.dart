import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/presentation/independent_public_city.dart';

void main() {
  test(
    'existing provider Trento resolves from ISTAT without rewriting provenance',
    () {
      const preview = LocationPreview(
        item: PreviewItem('one_time', 'mappa-test'),
        revision: 7,
        isProtected: false,
        publicLabel: 'Trento, Provincia autonoma di Trento, Italy',
        textSource: 'geoapify',
        legacy: LegacyPreviewArea('Trento', 'IT'),
        place: PreviewPlace(
          'locality',
          'Provider formatted label',
          46.07,
          11.12,
        ),
      );
      final city = independentPublicCity(
        publicArea: preview.legacy,
        publicLabel: preview.publicLabel,
        textSource: preview.textSource,
      )!;
      expect(city.name, 'Trento');
      expect(city.source, PublicCityNameSource.istat);
      expect(city.searchArea.query, 'Trento, IT');
      expect(preview.textSource, 'geoapify');
      expect(preview.place!.label, 'Provider formatted label');
      expect(preview.place!.latitude, 46.07);
      expect(preview.revision, 7);
    },
  );

  test(
    'official aliases, case and whitespace resolve to official Italian names',
    () {
      for (final entry in {
        ' TRENTO ': 'Trento',
        'Bozen': 'Bolzano',
        'L’Aquila': "L'Aquila",
        'Reggio   di Calabria': 'Reggio di Calabria',
      }.entries) {
        expect(
          independentPublicCity(publicArea: LegacyPreviewArea(entry.key, 'it'))
              ?.name,
          entry.value,
        );
      }
    },
  );

  test('attested manual city is kept, including international and nonmunicipal names', () {
    final city = independentPublicCity(
      publicArea: const LegacyPreviewArea('Berlin', 'DE'),
      textSource: 'manual',
    )!;
    expect(city.name, 'Berlin');
    expect(city.source, PublicCityNameSource.manual);
    expect(city.searchArea.query, 'Berlin, DE');
  });

  test('unknown text is never reclassified manual or extracted from a full address', () {
    for (final area in [
      const LegacyPreviewArea('Berlin', 'DE'),
      const LegacyPreviewArea('Trento', 'US'),
      const LegacyPreviewArea('Unclassified village', 'IT'),
      const LegacyPreviewArea('Trento, Via Roma 42', 'IT'),
      const LegacyPreviewArea('', 'IT'),
    ]) {
      expect(
        independentPublicCity(publicArea: area, publicLabel: 'Trento'),
        isNull,
      );
    }
  });
}
