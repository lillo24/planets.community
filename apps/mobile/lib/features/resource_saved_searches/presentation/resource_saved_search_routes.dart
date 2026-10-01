abstract final class ResourceSavedSearchRoutes {
  static const path = '/resources/saved-searches';

  static bool isManagementPath(String destination) =>
      Uri.tryParse(destination)?.path == path;
}
