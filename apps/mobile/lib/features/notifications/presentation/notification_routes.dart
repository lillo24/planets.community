bool isNotificationsPath(String path) {
  final segments = Uri.tryParse(path)?.pathSegments ?? const [];
  return segments.isNotEmpty && segments.first == 'notifications';
}
