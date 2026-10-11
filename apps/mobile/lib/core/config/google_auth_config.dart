/// Public Web OAuth client ID used as Android's serverClientId. Empty disables
/// Google sign-in. This validates shape only, not external provider setup.
String? parseGoogleWebClientId(String value) {
  if (value.isEmpty) return null;
  if (value.trim() != value ||
      !RegExp(r'^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$')
          .hasMatch(value)) {
    // Never echo the input: a mistaken value could be a secret.
    throw const FormatException(
      'GOOGLE_WEB_CLIENT_ID must be an unpadded Google Web OAuth client ID.',
    );
  }
  return value;
}
