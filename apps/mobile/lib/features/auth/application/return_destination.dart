const defaultReturnDestination = '/';

String sanitizeReturnDestination(String? candidate) {
  if (candidate == null || candidate.isEmpty || candidate.contains('\\')) {
    return defaultReturnDestination;
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !candidate.startsWith('/') ||
      candidate.startsWith('//') ||
      uri.path == '/auth' ||
      uri.path.startsWith('/auth/')) {
    return defaultReturnDestination;
  }

  return uri.toString();
}
