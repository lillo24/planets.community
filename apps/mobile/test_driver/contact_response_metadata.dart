// Extended integrationDriver validates/saves every PNG before invoking its
// response callback. Its default callback pretty-prints the same image bytes as
// JSON again. That exhausted the host heap after the complete M journey passed.
// Keep all other response fields and screenshot metadata, with PNGs stored by the
// unchanged onScreenshot callback. Never serialize a second copy of their bytes.
Map<String, dynamic> contactResponseMetadata(Map<String, dynamic>? data) {
  if (data == null) {
    throw const FormatException('Missing contact native response data.');
  }
  final result = Map<String, dynamic>.of(data);
  if (!result.containsKey('screenshots')) return result;
  final screenshots = result.remove('screenshots');
  if (screenshots is! List) {
    throw const FormatException('Expected contact native screenshot list.');
  }
  result['stored_screenshots'] = [
    for (final screenshot in screenshots) _screenshotMetadata(screenshot),
  ];
  return result;
}

Map<String, dynamic> _screenshotMetadata(Object? value) {
  if (value is! Map<String, dynamic> ||
      value['screenshotName'] is! String ||
      (value['screenshotName'] as String).isEmpty ||
      value['bytes'] is! List ||
      (value['bytes'] as List).isEmpty) {
    throw const FormatException('Invalid contact native screenshot metadata.');
  }
  final result = Map<String, dynamic>.of(value);
  final bytes = result.remove('bytes') as List;
  result['byteCount'] = bytes.length;
  return result;
}
