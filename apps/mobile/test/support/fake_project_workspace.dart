import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';

class FakeProjectWorkspaceGateway implements ProjectWorkspaceGateway {
  ProjectWorkspace? workspace;
  Object? readError;
  Object? mutationError;
  Future<void>? readDelay;
  Future<void>? mutationDelay;
  final calls = <String>[];

  @override
  Future<bool> clearWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    calls.add('clear:$expectedManagerProfileId:$projectId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    final existed = workspace != null;
    workspace = null;
    return existed;
  }

  @override
  Future<ProjectWorkspace?> getWorkspace({
    required String expectedProfileId,
    required String projectId,
  }) async {
    calls.add('get:$expectedProfileId:$projectId');
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return workspace;
  }

  @override
  Future<ProjectWorkspace> setWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
    required ProjectWorkspaceUrl url,
  }) async {
    calls.add('set:$expectedManagerProfileId:$projectId:${url.value}');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    return workspace = ProjectWorkspace(
      projectId: projectId,
      url: url,
      updatedAt: DateTime.utc(2030),
    );
  }
}

class FakeProjectWorkspaceLauncher implements ProjectWorkspaceLauncher {
  bool result = true;
  ProjectWorkspaceUrl? opened;
  int calls = 0;

  @override
  Future<bool> open(ProjectWorkspaceUrl url) async {
    calls++;
    opened = url;
    return result;
  }
}

ProjectWorkspace projectWorkspaceFixture({
  String projectId = 'proposal-1',
  String url = 'https://drive.google.com/drive/folders/private-token',
}) => ProjectWorkspace(
  projectId: projectId,
  url: ProjectWorkspaceUrl.parse(url),
  updatedAt: DateTime.utc(2030),
);
