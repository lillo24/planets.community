import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/project_workspace_models.dart';

abstract interface class ProjectWorkspaceGateway {
  Future<ProjectWorkspacePage> listLinks({
    required String expectedProfileId,
    required String projectId,
    ProjectWorkspaceCursor? cursor,
    int limit = 10,
  });
  Future<ProjectWorkspace?> getLink({
    required String expectedProfileId,
    required String projectId,
    required String linkId,
  });
  Future<WorkspaceAddReceipt> readAddReceipt({
    required String expectedManagerProfileId,
    required String projectId,
    required String requestId,
  });
  Future<String> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
    String? requestId,
    int? expectedVersion,
  });
  Future<void> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
    required int expectedVersion,
  });
}

class ProjectWorkspaceRpcContract {
  const ProjectWorkspaceRpcContract();
  Map<String, dynamic> readParams(
    String profileId,
    String projectId, {
    ProjectWorkspaceCursor? cursor,
    int limit = 10,
  }) => {
    'p_expected_profile_id': profileId,
    'p_project_id': projectId,
    'p_limit': limit,
    'p_before_created_at': cursor?.createdAt.toUtc().toIso8601String(),
    'p_before_id': cursor?.id,
  };
  Map<String, dynamic> saveParams(
    String profileId,
    String projectId,
    String name,
    ProjectWorkspaceUrl url,
    String? linkId, {
    String? requestId,
    int? expectedVersion,
  }) => {
    'p_expected_manager_profile_id': profileId,
    'p_project_id': projectId,
    'p_display_name': name,
    'p_workspace_url': url.value,
    'p_link_id': linkId,
    'p_client_request_id': requestId,
    'p_expected_version': expectedVersion,
  };
  Map<String, dynamic> removeParams(
    String profileId,
    String projectId,
    String linkId,
    int expectedVersion,
  ) => {
    'p_expected_manager_profile_id': profileId,
    'p_project_id': projectId,
    'p_link_id': linkId,
    'p_expected_version': expectedVersion,
  };
}

class ProjectWorkspacePayloadParser {
  const ProjectWorkspacePayloadParser();

  ProjectWorkspacePage page(
    Object? response,
    String projectId, {
    int limit = 10,
  }) {
    if (response is! Map || response['can_manage'] is! bool) {
      throw const FormatException('Workspace page was malformed.');
    }
    final items = links(response['items'], projectId);
    if (items.length > limit) {
      throw const FormatException(
        'Workspace page exceeded its requested bound.',
      );
    }
    for (var i = 1; i < items.length; i++) {
      final a = items[i - 1], b = items[i];
      if (a.createdAt.isBefore(b.createdAt) ||
          (a.createdAt == b.createdAt && a.id.compareTo(b.id) <= 0)) {
        throw const FormatException('Workspace creation order was malformed.');
      }
    }
    ProjectWorkspaceCursor? cursor;
    final next = response['next_cursor'];
    if (next != null) {
      if (next is! Map ||
          next['created_at'] is! String ||
          next['id'] is! String ||
          items.length != limit ||
          items.isEmpty) {
        throw const FormatException('Workspace cursor was malformed.');
      }
      final time = DateTime.tryParse(next['created_at'] as String)?.toUtc();
      if (time == null ||
          time != items.last.createdAt ||
          next['id'] != items.last.id) {
        throw const FormatException('Workspace cursor did not match its page.');
      }
      cursor = ProjectWorkspaceCursor(
        createdAt: time,
        id: next['id'] as String,
      );
    }
    return ProjectWorkspacePage(
      items: items,
      canManage: response['can_manage'] as bool,
      nextCursor: cursor,
    );
  }

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
    final id = value['id'],
        name = value['display_name'],
        url = value['workspace_url'];
    final updated = value['updated_at'],
        created = value['created_at'],
        version = value['version'];
    if (value['project_id'] != projectId ||
        id is! String ||
        id.isEmpty ||
        name is! String ||
        url is! String ||
        updated is! String ||
        created is! String ||
        version is! int ||
        version < 1) {
      throw const FormatException('Workspace row was malformed.');
    }
    final updatedAt = DateTime.tryParse(updated)?.toUtc(),
        createdAt = DateTime.tryParse(created)?.toUtc();
    if (updatedAt == null || createdAt == null) {
      throw const FormatException('Workspace timestamps were malformed.');
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
        updatedAt: updatedAt,
        createdAt: createdAt,
        version: version,
      );
    } on ProjectWorkspaceNameException {
      throw const FormatException('Workspace name was malformed.');
    } on ProjectWorkspaceUrlException {
      throw const FormatException('Workspace URL was malformed.');
    }
  }

  WorkspaceAddReceipt receipt(Object? value, String projectId) {
    if (value is! Map || value['accepted'] is! bool) {
      throw const FormatException('Workspace Add receipt was malformed.');
    }
    if (value['accepted'] == false) {
      return const WorkspaceAddReceipt(accepted: false);
    }
    final id = value['link_id'],
        name = value['display_name'],
        input = value['workspace_url'];
    if (id is! String || id.isEmpty || name is! String || input is! String) {
      throw const FormatException('Workspace Add identity was malformed.');
    }
    try {
      if (validateProjectWorkspaceName(name) != name) {
        throw const ProjectWorkspaceNameException();
      }
      final item = value['item'] == null
          ? null
          : workspace(value['item'], projectId);
      if (item != null && item.id != id) {
        throw const FormatException('Workspace Add item identity changed.');
      }
      return WorkspaceAddReceipt(
        accepted: true,
        linkId: id,
        name: name,
        url: ProjectWorkspaceUrl.parse(input),
        item: item,
      );
    } on ProjectWorkspaceNameException {
      throw const FormatException('Workspace Add name was malformed.');
    } on ProjectWorkspaceUrlException {
      throw const FormatException('Workspace Add URL was malformed.');
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
  Future<ProjectWorkspacePage> listLinks({
    required String expectedProfileId,
    required String projectId,
    ProjectWorkspaceCursor? cursor,
    int limit = 10,
  }) async => parser.page(
    await _client.rpc(
      'list_project_workspace_links',
      params: contract.readParams(
        expectedProfileId,
        projectId,
        cursor: cursor,
        limit: limit,
      ),
    ),
    projectId,
    limit: limit,
  );

  @override
  Future<ProjectWorkspace?> getLink({
    required String expectedProfileId,
    required String projectId,
    required String linkId,
  }) async {
    final value = await _client.rpc(
      'get_project_workspace_link',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_project_id': projectId,
        'p_link_id': linkId,
      },
    );
    return value == null ? null : parser.workspace(value, projectId);
  }

  @override
  Future<WorkspaceAddReceipt> readAddReceipt({
    required String expectedManagerProfileId,
    required String projectId,
    required String requestId,
  }) async => parser.receipt(
    await _client.rpc(
      'get_project_workspace_add_receipt',
      params: {
        'p_expected_manager_profile_id': expectedManagerProfileId,
        'p_project_id': projectId,
        'p_client_request_id': requestId,
      },
    ),
    projectId,
  );

  @override
  Future<String> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
    String? requestId,
    int? expectedVersion,
  }) async {
    final id = await _client.rpc<String>(
      'save_project_workspace_link',
      params: contract.saveParams(
        expectedManagerProfileId,
        projectId,
        name,
        url,
        linkId,
        requestId: requestId,
        expectedVersion: expectedVersion,
      ),
    );
    if (id.isEmpty) {
      throw const FormatException('Workspace save returned no identity.');
    }
    return id;
  }

  @override
  Future<void> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
    required int expectedVersion,
  }) async {
    final removed = await _client.rpc<bool>(
      'remove_project_workspace_link',
      params: contract.removeParams(
        expectedManagerProfileId,
        projectId,
        linkId,
        expectedVersion,
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
