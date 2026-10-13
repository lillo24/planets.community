import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';

class FakeProjectWorkspaceGateway implements ProjectWorkspaceGateway {
  final links = <ProjectWorkspace>[];
  ProjectWorkspace? get workspace => links.firstOrNull;
  set workspace(ProjectWorkspace? value) {
    links.clear();
    if (value != null) links.add(value);
  }

  Object? readError;
  Object? mutationError;
  Future<void>? readDelay;
  Future<void>? mutationDelay;
  final calls = <String>[];
  @override
  Future<List<ProjectWorkspace>> listLinks({
    required String expectedProfileId,
    required String projectId,
  }) async {
    calls.add('get:$expectedProfileId:$projectId');
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return List.unmodifiable(links);
  }

  @override
  Future<void> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
  }) async {
    calls.add('set:$expectedManagerProfileId:$projectId:${url.value}');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    final id = linkId ?? 'link-${links.length + 1}';
    final entry = ProjectWorkspace(
      id: id,
      name: name,
      projectId: projectId,
      url: url,
      updatedAt: DateTime.utc(2030),
    );
    final index = links.indexWhere((link) => link.id == id);
    if (index < 0) {
      links.add(entry);
    } else {
      links[index] = entry;
    }
  }

  @override
  Future<void> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
  }) async {
    calls.add('clear:$expectedManagerProfileId:$projectId:$linkId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    links.removeWhere((link) => link.id == linkId);
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
  String id = 'link-1',
  String name = 'Workspace',
  String projectId = 'proposal-1',
  String url = 'https://drive.google.com/drive/folders/private-token',
}) => ProjectWorkspace(
  id: id,
  name: name,
  projectId: projectId,
  url: ProjectWorkspaceUrl.parse(url),
  updatedAt: DateTime.utc(2030),
);
