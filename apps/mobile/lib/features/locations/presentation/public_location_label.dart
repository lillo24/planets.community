import 'independent_public_city.dart';

/// Compact area text from PUBLIC fields only. Never pass exact meeting data.
/// Without structure, only established Italian province/region suffixes can be
/// removed. International/manual comma names remain intact; no geocoding occurs.
String? shortPublicLocationLabel(
  String? locality,
  String? publicLabel, {
  bool manual = false,
  String? countryCode,
}) {
  final independent = cataloguedPublicCityName(locality, countryCode);
  if (independent != null) return independent;
  final city = locality?.trim();
  if (city != null && city.isNotEmpty) return city;
  final label = publicLabel?.trim();
  if (label == null || label.isEmpty) return null;
  if (!manual) {
    final match = RegExp(
      r'^([^,0-9<>\r\n]+),\s*(?:Provincia(?: autonoma)? di [^,]+|Trentino[ –-]+Alto Adige(?:/Südtirol)?)(?:,\s*[^,]+)*,\s*(?:Italia|Italy)$',
      caseSensitive: false,
    ).firstMatch(label);
    if (match != null &&
        !RegExp(
          r'\b(via|viale|vicolo|piazza|corso|strada|street|road|avenue|lane)\b',
          caseSensitive: false,
        ).hasMatch(match[1]!)) {
      return match[1]!.trim();
    }
  }
  return label;
}
