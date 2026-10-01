const _uuidPattern =
    r'[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';

/// Parses a nullable provider-independent cover path bound to its parent row.
String? parseCoverObjectPath(
  Object? value, {
  required String parentId,
  required String parentSegment,
}) {
  if (value == null) return null;
  if (value is! String ||
      !RegExp(
        '^$_uuidPattern/$parentSegment/${RegExp.escape(parentId)}/$_uuidPattern\\.webp\$',
        caseSensitive: false,
      ).hasMatch(value)) {
    throw const FormatException('Cover object path was malformed.');
  }
  return value;
}
