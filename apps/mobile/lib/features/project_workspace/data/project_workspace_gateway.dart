import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/project_workspace_models.dart';

abstract interface class ProjectWorkspaceGateway {
  Future<List<ProjectWorkspace>> listLinks({
    required String expectedProfileId,
    required String projectId,
  });
  Future<void> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
  });
  Future<void> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
  });
}

class ProjectWorkspaceRpcContract {
  const ProjectWorkspaceRpcContract();
  Map<String, dynamic> readParams(String profileId, String projectId) => {
    'p_expected_profile_id': profileId,
    'p_project_id': projectId,
  };
  Map<String, dynamic> saveParams(
    String profileId,
    String projectId,
    String name,
    ProjectWorkspaceUrl url,
    String? linkId,
  ) => {
    'p_expected_manager_profile_id': profileId,
    'p_project_id': projectId,
    'p_display_name': name,
    'p_workspace_url': url.value,
    'p_link_id': linkId,
  };
  Map<String, dynamic> removeParams(
    String profileId,
    String projectId,
    String linkId,
  ) => {
    'p_expected_manager_profile_id': profileId,
    'p_project_id': projectId,
    'p_link_id': linkId,
  };
}

class ProjectWorkspacePayloadParser {
  const ProjectWorkspacePayloadParser();
  List<ProjectWorkspace> links(Object? response, String projectId) {
    if (response is! List) {
      throw const FormatException('Workspace list was malformed.');
    }
    final result = response.map((row) => workspace(row, projectId)).toList();
    if (result.map((link) => link.id).toSet().length != result.length) {
      throw const FormatException('Workspace link identity was duplicated.');
    }
    return List.unmodifiable(result);
  }

  ProjectWorkspace workspace(Object? value, String projectId) {
    if (value is! Map) {
      throw const FormatException('Workspace row was malformed.');
    }
    final id = value['id'];
    final name = value['display_name'];
    final url = value['workspace_url'];
    final updatedAt = value['updated_at'];
    final createdAt = value['created_at'];
    if (value['project_id'] != projectId ||
        id is! String ||
        id.isEmpty ||
        name is! String ||
        url is! String ||
        updatedAt is! String ||
        createdAt is! String ||
        DateTime.tryParse(updatedAt) == null ||
        DateTime.tryParse(createdAt) == null) {
      throw const FormatException('Workspace row was malformed.');
    }
    try {
      if (validateProjectWorkspaceName(name) != name) {
        throw const ProjectWorkspaceNameException();
      }
      return ProjectWorkspace(
        id: id,
        name: name,
        projectId: projectId,
        url: ProjectWorkspaceUrl.parse(url),
        updatedAt: DateTime.parse(updatedAt).toUtc(),
      );
    } on ProjectWorkspaceNameException {
      throw const FormatException('Workspace name was malformed.');
    } on ProjectWorkspaceUrlException {
      throw const FormatException('Workspace URL was malformed.');
    }
  }
}

class SupabaseProjectWorkspaceGateway implements ProjectWorkspaceGateway {
  const SupabaseProjectWorkspaceGateway(
    this._client, {
    this.contract = const ProjectWorkspaceRpcContract(),
    this.parser = const ProjectWorkspacePayloadParser(),
  });
  final SupabaseClient _client;
  final ProjectWorkspaceRpcContract contract;
  final ProjectWorkspacePayloadParser parser;
  @override
  Future<List<ProjectWorkspace>> listLinks({
    required String expectedProfileId,
    required String projectId,
  }) async => parser.links(
    await _client.rpc<List<dynamic>>(
      'list_project_workspace_links',
      params: contract.readParams(expectedProfileId, projectId),
    ),
    projectId,
  );
  @override
  Future<void> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
  }) async {
    final id = await _client.rpc<String>(
      'save_project_workspace_link',
      params: contract.saveParams(
        expectedManagerProfileId,
        projectId,
        name,
        url,
        linkId,
      ),
    );
    if (id.isEmpty) {
      throw const FormatException('Workspace save returned no identity.');
    }
  }

  @override
  Future<void> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
  }) async {
    final removed = await _client.rpc<bool>(
      'remove_project_workspace_link',
      params: contract.removeParams(
        expectedManagerProfileId,
        projectId,
        linkId,
      ),
    );
    if (!removed) {
      throw const FormatException('Workspace removal was not confirmed.');
    }
  }
}

final projectWorkspaceGatewayProvider = Provider<ProjectWorkspaceGateway>(
  (ref) => SupabaseProjectWorkspaceGateway(ref.watch(supabaseClientProvider)),
);
