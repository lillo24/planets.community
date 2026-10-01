import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/project_workspace_models.dart';

abstract interface class ProjectWorkspaceLauncher {
  Future<bool> open(ProjectWorkspaceUrl url);
}

class ExternalProjectWorkspaceLauncher implements ProjectWorkspaceLauncher {
  const ExternalProjectWorkspaceLauncher();

  @override
  Future<bool> open(ProjectWorkspaceUrl url) async {
    try {
      return await launchUrl(url.uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

final projectWorkspaceLauncherProvider = Provider<ProjectWorkspaceLauncher>((
  ref,
) {
  return const ExternalProjectWorkspaceLauncher();
});
