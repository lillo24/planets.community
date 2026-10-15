import '../data/italian_municipality_names.g.dart';
import '../domain/location_preview.dart';

enum PublicCityNameSource { manual, istat }

/// Presentation-only public city text, separate from a provider place/receipt.
/// Resolving a name never verifies a venue, supplies geometry or changes storage.
class IndependentPublicCity {
  const IndependentPublicCity(this.name, this.countryCode, this.source);
  final String name, countryCode;
  final PublicCityNameSource source;

  LegacyPreviewArea get searchArea => LegacyPreviewArea(name, countryCode);
}

/// Public list DTOs lack authored-text provenance. A catalogue hit still gives
/// their cards an independent name; a miss retains their existing credited text.
String? cataloguedPublicCityName(String? locality, String? countryCode) =>
    independentPublicCity(
      publicArea: LegacyPreviewArea(locality ?? '', countryCode ?? ''),
    )?.name;

/// Reuse genuinely attested manual text; otherwise look up the PUBLIC locality
/// in the independent ISTAT catalogue. The input is only an exact lookup key:
/// the output name comes from ISTAT, never from shortening a geocoder label.
/// Unknown/international unmatched data has no independent text projection.
IndependentPublicCity? independentPublicCity({
  required LegacyPreviewArea publicArea,
  String? publicLabel,
  String textSource = 'unknown',
}) {
  final locality = publicArea.locality.trim();
  final country = publicArea.countryCode.trim().toUpperCase();
  if (textSource == 'manual') {
    final name = locality.isNotEmpty ? locality : publicLabel?.trim();
    if (name == null ||
        name.isEmpty ||
        name.length > 180 ||
        RegExp(r'[<>\x00-\x1f]').hasMatch(name)) {
      return null;
    }
    return IndependentPublicCity(name, country, PublicCityNameSource.manual);
  }
  if (country != 'IT') return null;
  final key = locality
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('’', "'")
      .toLowerCase();
  final name = italianMunicipalityNames[key];
  return name == null
      ? null
      : IndependentPublicCity(name, 'IT', PublicCityNameSource.istat);
}
