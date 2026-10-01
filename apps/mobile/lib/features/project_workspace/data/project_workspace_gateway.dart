import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/project_workspace_models.dart';

abstract interface class ProjectWorkspaceGateway {
  Future<ProjectWorkspace?> getWorkspace({
    required String expectedProfileId,
    required String projectId,
  });

  Future<ProjectWorkspace> setWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
    required ProjectWorkspaceUrl url,
  });

  Future<bool> clearWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
  });
}

class ProjectWorkspaceRpcContract {
  const ProjectWorkspaceRpcContract();

  Map<String, dynamic> readParams(String profileId, String projectId) => {
    'p_expected_profile_id': profileId,
    'p_project_id': projectId,
  };

  Map<String, dynamic> setParams(
    String profileId,
    String projectId,
    ProjectWorkspaceUrl url,
  ) => {
    'p_expected_manager_profile_id': profileId,
    'p_project_id': projectId,
    'p_workspace_url': url.value,
  };

  Map<String, dynamic> clearParams(String profileId, String projectId) => {
    'p_expected_manager_profile_id': profileId,
    'p_project_id': projectId,
  };
}

class ProjectWorkspacePayloadParser {
  const ProjectWorkspacePayloadParser();

  ProjectWorkspace? optionalWorkspace(Object? response, String projectId) {
    if (response is! List || response.length > 1) {
      throw const FormatException('Project workspace payload was malformed.');
    }
    if (response.isEmpty) return null;
    return workspace(response.single, projectId);
  }

  ProjectWorkspace workspace(Object? value, String projectId) {
    if (value is! Map) {
      throw const FormatException('Project workspace row was malformed.');
    }
    final row = Map<String, dynamic>.from(value);
    final responseProjectId = row['project_id'];
    final workspaceUrl = row['workspace_url'];
    final updatedAt = row['updated_at'];
    if (responseProjectId != projectId ||
        workspaceUrl is! String ||
        updatedAt is! String) {
      throw const FormatException('Project workspace row was malformed.');
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) {
      throw const FormatException('Project workspace timestamp was malformed.');
    }
    return ProjectWorkspace(
      projectId: projectId,
      url: ProjectWorkspaceUrl.parse(workspaceUrl),
      updatedAt: parsedUpdatedAt.toUtc(),
    );
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
  Future<ProjectWorkspace?> getWorkspace({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_project_shared_workspace',
      params: contract.readParams(expectedProfileId, projectId),
    );
    return parser.optionalWorkspace(response, projectId);
  }

  @override
  Future<ProjectWorkspace> setWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
    required ProjectWorkspaceUrl url,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'set_project_shared_workspace',
      params: contract.setParams(expectedManagerProfileId, projectId, url),
    );
    final workspace = parser.optionalWorkspace(response, projectId);
    if (workspace == null) {
      throw const FormatException('Project workspace result was empty.');
    }
    return workspace;
  }

  @override
  Future<bool> clearWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<bool>(
      'clear_project_shared_workspace',
      params: contract.clearParams(expectedManagerProfileId, projectId),
    );
    return response;
  }
}

final projectWorkspaceGatewayProvider = Provider<ProjectWorkspaceGateway>((
  ref,
) {
  return SupabaseProjectWorkspaceGateway(ref.watch(supabaseClientProvider));
});
