final _projectShare = RegExp(
  r'^https://planets\.community/proposals/'
  r'([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$',
);

/// Human-message compatible first-party link. No title, location, roster,
/// ownership or consent is stored with a share. Query/invitation URLs and prose
/// remain ordinary text and never receive the structured-share review bypass.
String? coSharedProjectId(String body) {
  final match = _projectShare.firstMatch(body);
  return match != null && match.end == body.length ? match.group(1) : null;
}

String coProjectShareUrl(String id) =>
    'https://planets.community/proposals/$id';
