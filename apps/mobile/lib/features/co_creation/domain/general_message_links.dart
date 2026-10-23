// Local educational heuristic, never a spam verdict or a URL validator.
// Message input is bounded to 2,000 characters by the existing composer/server.
// Bounded host labels and non-overlapping scans avoid nested open-ended regexes.
final _webScheme = RegExp(
  r'''https?://[^\s<>(){}.,;!?"']''',
  caseSensitive: false,
);
final _www = RegExp(r'www\.[a-z0-9]', caseSensitive: false);
final _email = RegExp(
  r'[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*',
  caseSensitive: false,
);
final _domain = RegExp(
  r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
  r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+',
  caseSensitive: false,
);
final _hostOrEmailCharacter = RegExp(r'[a-z0-9_.@-]', caseSensitive: false);
final _countrySuffix = RegExp(r'^[a-z]{2}$');
const _genericSuffixes = {
  'com',
  'org',
  'net',
  'edu',
  'gov',
  'mil',
  'int',
  'info',
  'biz',
  'name',
  'pro',
  'app',
  'dev',
  'community',
  'online',
  'site',
  'xyz',
  'club',
  'social',
  'sport',
  'sports',
  'museum',
  'travel',
  'events',
  'art',
  'world',
  'coop',
  'tech',
  'store',
  'shop',
  'blog',
  'cloud',
  'news',
  'live',
  'tools',
  'team',
};

/// Likely web links in prose/Markdown; standalone email, times and decimals are
/// excluded. Bare ASCII/punycode hosts use country codes or the common generic
/// suffixes above, rather than treating every dotted word/file as a web domain.
/// No network lookup, content inspection, telemetry or persisted analysis.
bool containsLikelyWebLink(String text) {
  bool startsHost(String source, int start) =>
      start == 0 || !_hostOrEmailCharacter.hasMatch(source[start - 1]);
  for (final match in _webScheme.allMatches(text)) {
    if (startsHost(text, match.start)) return true;
  }
  // Ignore the whole address, including a dotted local part such as
  // garden.org@example.it. Explicit HTTP URLs with userinfo were handled above.
  final withoutEmails = text.replaceAll(_email, ' ');
  for (final match in _www.allMatches(withoutEmails)) {
    if (startsHost(withoutEmails, match.start)) return true;
  }
  for (final match in _domain.allMatches(withoutEmails)) {
    if (!startsHost(withoutEmails, match.start)) continue;
    final host = match.group(0)!.toLowerCase();
    if (host.length > 253) continue;
    final suffix = host.substring(host.lastIndexOf('.') + 1);
    if (_countrySuffix.hasMatch(suffix) || _genericSuffixes.contains(suffix)) {
      return true;
    }
  }
  return false;
}
