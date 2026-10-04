// Discard secret-bearing telemetry rather than uploading a partly redacted URL.
// Covers participant/authority routes, encoded returnTo URLs and RPC parameters.
bool containsInvitationSecret(Object? value) {
  if (value is Map) {
    return value.entries.any(
      (entry) =>
          const {'p_token', 'invite_token'}.contains(entry.key) ||
          containsInvitationSecret(entry.key) ||
          containsInvitationSecret(entry.value),
    );
  }
  if (value is Iterable) return value.any(containsInvitationSecret);
  if (value is! String) return false;
  var text = value;
  for (var i = 0; i < 4; i++) {
    if (text.contains('/join/project/') || text.contains('/invite/project/')) {
      return true;
    }
    // Also suppress standalone opaque invitation tokens in exception messages.
    if (RegExp(r'(^|[^A-Za-z0-9_-])[A-Za-z0-9_-]{43}($|[^A-Za-z0-9_-])')
        .hasMatch(text)) {
      return true;
    }
    try {
      final decoded = Uri.decodeComponent(text);
      if (decoded == text) break;
      text = decoded;
    } on FormatException {
      break;
    } on ArgumentError {
      break;
    }
  }
  return false;
}
