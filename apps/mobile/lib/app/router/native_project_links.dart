/// The OS filters are shape globs; this is the application trust boundary.
/// Internal app navigation remains independent of the public HTTPS allowlist.
String? nativeProjectDestination(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host != 'planets.community' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment ||
      uri.path.contains('%') ||
      uri.path.contains('\\')) {
    return null;
  }
  final path = uri.path;
  final token = RegExp(r'^/(?:join|invite)/project/[A-Za-z0-9_-]{43}$');
  final detail = RegExp(
    r'^/(?:proposals|tavoli)/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  if (token.hasMatch(path) && !uri.hasQuery) return path;
  if (detail.hasMatch(path)) {
    // Keep the original query, including duplicate intent markers. The ordinary
    // flow itself requires exactly one intent=join; delivery never admits.
    return '$path${uri.hasQuery ? '?${uri.query}' : ''}';
  }
  return null;
}
