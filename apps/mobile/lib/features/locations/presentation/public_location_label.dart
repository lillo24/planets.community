/// Compact card text from PUBLIC fields only. Never pass exact meeting data.
/// Older records without structured locality retain their full public label;
/// provider labels are not parsed to guess a city.
String? shortPublicLocationLabel(String? locality, String? publicLabel) {
  for (final value in [locality, publicLabel]) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
