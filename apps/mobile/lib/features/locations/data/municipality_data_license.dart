import 'package:flutter/foundation.dart';

const municipalityDataLicense = '''
ISTAT - Istituto Nazionale di Statistica
Elenco dei comuni italiani, updated 21 February 2026; retrieved 15 October 2026.

Source: https://www.istat.it/storage/codici-unita-amministrative/Elenco-comuni-italiani.xlsx
Dataset description: https://www.istat.it/classificazione/codici-dei-comuni-delle-province-e-delle-regioni/

Licensed under Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/
ISTAT legal notice: https://www.istat.it/note-legali/

PLANETS adaptation: official Italian municipality names with official bilingual
and other-language lookup aliases; normalized, sorted, and deduplicated.
Ambiguous aliases are omitted. No coordinates or Geoapify data are included.
ISTAT does not endorse PLANETS.
''';

bool _registered = false;

/// Called before opening the app's Licences page; adds this data notice once.
void registerMunicipalityDataLicense() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks([
        'ISTAT municipality names',
      ], municipalityDataLicense),
    ),
  );
}
