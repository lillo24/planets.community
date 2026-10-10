import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/project_delegate_models.dart';

abstract interface class ProjectDelegateGateway {
  Future<ProjectManagementRole> getOwnManagementRole({
    required String expectedProfileId,
    required String projectId,
  });

  Future<List<ProjectDelegate>> listDelegates({
    required String expectedStructuralActorId,
    required String projectId,
  });

  Future<List<ProjectDelegateInvitation>> listPendingInvitations({
    required String expectedStructuralActorId,
    required String projectId,
  });

  Future<ProjectDelegateInvitationResult> createInvitation({
    required String expectedStructuralActorId,
    required String projectId,
    required ProjectDelegatedAuthorityRole requestedAuthorityRole,
  });

  Future<void> revokeInvitation({
    required String expectedStructuralActorId,
    required String invitationId,
  });

  Future<void> changeDelegateRole({
    required String expectedStructuralActorId,
    required String delegateId,
    required ProjectDelegatedAuthorityRole authorityRole,
  });

  Future<void> revokeDelegate({
    required String expectedStructuralActorId,
    required String delegateId,
  });

  Future<ProjectDelegateInvitePreview> previewInvitation(String token);

  Future<void> acceptInvitation({
    required String expectedProfileId,
    required String token,
  });

  Future<List<DelegatedProject>> listOwnDelegatedProjects(
    String expectedProfileId,
  );
}

/// Keeps the mobile RPC argument contract explicit and independently testable.
class ProjectDelegateRpcContract {
  const ProjectDelegateRpcContract();

  Map<String, dynamic> managementRoleParams(
    String expectedProfileId,
    String projectId,
  ) => {'p_expected_profile_id': expectedProfileId, 'p_project_id': projectId};

  Map<String, dynamic> teamParams(
    String expectedStructuralActorId,
    String projectId,
  ) => {
    // The established RPC keeps this legacy parameter name while accepting
    // either the Creator or a current Co-creator.
    'p_expected_owner_profile_id': expectedStructuralActorId,
    'p_project_id': projectId,
  };

  Map<String, dynamic> createInvitationParams(
    String expectedStructuralActorId,
    String projectId,
    ProjectDelegatedAuthorityRole role,
  ) => {
    ...teamParams(expectedStructuralActorId, projectId),
    'p_requested_authority_role': role.wireValue,
  };

  Map<String, dynamic> invitationMutationParams(
    String expectedStructuralActorId,
    String invitationId,
  ) => {
    'p_expected_owner_profile_id': expectedStructuralActorId,
    'p_invitation_id': invitationId,
  };

  Map<String, dynamic> delegateMutationParams(
    String expectedStructuralActorId,
    String delegateId,
  ) => {
    'p_expected_owner_profile_id': expectedStructuralActorId,
    'p_delegate_id': delegateId,
  };

  Map<String, dynamic> changeDelegateRoleParams(
    String expectedStructuralActorId,
    String delegateId,
    ProjectDelegatedAuthorityRole role,
  ) => {
    'p_expected_structural_profile_id': expectedStructuralActorId,
    'p_delegate_id': delegateId,
    'p_authority_role': role.wireValue,
  };
}

/// Parses authority-bearing payloads fail-closed so unknown roles never
/// silently become a less-privileged role in the UI.
class ProjectDelegatePayloadParser {
  const ProjectDelegatePayloadParser();

  ProjectManagementRole managementRole(Object? value) {
    if (value is! String) {
      throw const FormatException('Management role was malformed.');
    }
    return ProjectManagementRole.fromWire(value);
  }

  ProjectDelegate delegate(Object? value) {
    final row = _row(value);
    return ProjectDelegate(
      id: _string(row, 'delegate_id'),
      profileId: _string(row, 'delegate_profile_id'),
      displayName: _string(row, 'delegate_display_name'),
      delegatedAt: _date(row, 'delegated_at'),
      authorityRole: _authorityRole(row, 'authority_role'),
      grantedByProfileId: _string(row, 'granted_by_profile_id'),
      grantedByDisplayName: _string(row, 'granted_by_display_name'),
    );
  }

  ProjectDelegateInvitation invitation(Object? value) {
    final row = _row(value);
    return ProjectDelegateInvitation(
      id: _string(row, 'invitation_id'),
      createdAt: _date(row, 'created_at'),
      expiresAt: _date(row, 'expires_at'),
      requestedAuthorityRole: _authorityRole(row, 'requested_authority_role'),
      issuerProfileId: _string(row, 'issuer_profile_id'),
      issuerDisplayName: _string(row, 'issuer_display_name'),
    );
  }

  ProjectDelegateInvitationResult invitationResult(
    Object? response,
    ProjectDelegatedAuthorityRole requestedAuthorityRole,
  ) {
    if (response is! List ||
        response.length != 1 ||
        response.single is! Map<String, dynamic>) {
      throw const FormatException('Invitation creation result was malformed.');
    }
    final row = response.single as Map<String, dynamic>;
    return ProjectDelegateInvitationResult(
      id: _string(row, 'invitation_id'),
      token: _string(row, 'invite_token'),
      expiresAt: _date(row, 'expires_at'),
      requestedAuthorityRole: requestedAuthorityRole,
    );
  }

  ProjectDelegateInvitePreview preview(Object? response) {
    if (response is! List ||
        response.length != 1 ||
        response.single is! Map<String, dynamic>) {
      throw const FormatException('Invitation preview was malformed.');
    }
    final row = response.single as Map<String, dynamic>;
    if (row['is_available'] != true) {
      return const ProjectDelegateInvitePreview(isAvailable: false);
    }
    return ProjectDelegateInvitePreview(
      isAvailable: true,
      projectId: _string(row, 'project_id'),
      projectKind: ProjectKind.fromWire(_string(row, 'project_kind')),
      projectTitle: _string(row, 'project_title'),
      ownerDisplayName: _optionalString(row, 'owner_display_name'),
      issuerDisplayName: _optionalString(row, 'issuer_display_name'),
      expiresAt: _date(row, 'expires_at'),
      requestedAuthorityRole: _authorityRole(row, 'requested_authority_role'),
    );
  }

  DelegatedProject delegatedProject(Object? value) {
    final row = _row(value);
    return DelegatedProject(
      id: _string(row, 'project_id'),
      kind: ProjectKind.fromWire(_string(row, 'project_kind')),
      title: _string(row, 'project_title'),
      status: _string(row, 'project_status'),
      delegatedAt: _date(row, 'delegated_at'),
      authorityRole: _authorityRole(row, 'authority_role'),
    );
  }
}

class SupabaseProjectDelegateGateway implements ProjectDelegateGateway {
  const SupabaseProjectDelegateGateway(
    this._client, {
    this.contract = const ProjectDelegateRpcContract(),
    this.parser = const ProjectDelegatePayloadParser(),
  });

  final SupabaseClient _client;
  final ProjectDelegateRpcContract contract;
  final ProjectDelegatePayloadParser parser;

  @override
  Future<ProjectManagementRole> getOwnManagementRole({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_own_project_management_role',
      params: contract.managementRoleParams(expectedProfileId, projectId),
    );
    return parser.managementRole(response);
  }

  @override
  Future<List<ProjectDelegate>> listDelegates({
    required String expectedStructuralActorId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_delegates_for_owner',
      params: contract.teamParams(expectedStructuralActorId, projectId),
    );
    return response.map(parser.delegate).toList(growable: false);
  }

  @override
  Future<List<ProjectDelegateInvitation>> listPendingInvitations({
    required String expectedStructuralActorId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_delegate_invitations_for_owner',
      params: contract.teamParams(expectedStructuralActorId, projectId),
    );
    final now = DateTime.now().toUtc();
    return response
        .map(_row)
        .where(
          (row) =>
              _string(row, 'status') == 'pending' &&
              _date(row, 'expires_at').isAfter(now),
        )
        .map(parser.invitation)
        .toList(growable: false);
  }

  @override
  Future<ProjectDelegateInvitationResult> createInvitation({
    required String expectedStructuralActorId,
    required String projectId,
    required ProjectDelegatedAuthorityRole requestedAuthorityRole,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'create_project_delegate_invitation',
      params: contract.createInvitationParams(
        expectedStructuralActorId,
        projectId,
        requestedAuthorityRole,
      ),
    );
    return parser.invitationResult(response, requestedAuthorityRole);
  }

  @override
  Future<void> revokeInvitation({
    required String expectedStructuralActorId,
    required String invitationId,
  }) async {
    await _client.rpc<dynamic>(
      'revoke_project_delegate_invitation',
      params: contract.invitationMutationParams(
        expectedStructuralActorId,
        invitationId,
      ),
    );
  }

  @override
  Future<void> changeDelegateRole({
    required String expectedStructuralActorId,
    required String delegateId,
    required ProjectDelegatedAuthorityRole authorityRole,
  }) async {
    await _client.rpc<dynamic>(
      'change_project_delegate_role',
      params: contract.changeDelegateRoleParams(
        expectedStructuralActorId,
        delegateId,
        authorityRole,
      ),
    );
  }

  @override
  Future<void> revokeDelegate({
    required String expectedStructuralActorId,
    required String delegateId,
  }) async {
    await _client.rpc<dynamic>(
      'revoke_project_delegate',
      params: contract.delegateMutationParams(
        expectedStructuralActorId,
        delegateId,
      ),
    );
  }

  @override
  Future<ProjectDelegateInvitePreview> previewInvitation(String token) async {
    final response = await _client.rpc<List<dynamic>>(
      'preview_project_delegate_invitation',
      params: {'p_token': token},
    );
    return parser.preview(response);
  }

  @override
  Future<void> acceptInvitation({
    required String expectedProfileId,
    required String token,
  }) async {
    await _client.rpc<dynamic>(
      'accept_project_delegate_invitation',
      params: {
        'p_expected_delegate_profile_id': expectedProfileId,
        'p_token': token,
      },
    );
  }

  @override
  Future<List<DelegatedProject>> listOwnDelegatedProjects(
    String expectedProfileId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_delegated_projects_v2',
      params: {'p_expected_profile_id': expectedProfileId},
    );
    return response.map(parser.delegatedProject).toList(growable: false);
  }
}

ProjectDelegatedAuthorityRole _authorityRole(
  Map<String, dynamic> row,
  String key,
) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Project delegate $key was malformed.');
  }
  return ProjectDelegatedAuthorityRole.fromWire(value);
}

Map<String, dynamic> _row(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Project delegate row was malformed.');
  }
  return value;
}

String _string(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Project delegate $key was malformed.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('Project delegate $key was malformed.');
  }
  return value;
}

DateTime _date(Map<String, dynamic> row, String key) {
  final parsed = DateTime.tryParse(_string(row, key));
  if (parsed == null) {
    throw FormatException('Project delegate $key was not a timestamp.');
  }
  return parsed;
}

final projectDelegateGatewayProvider = Provider<ProjectDelegateGateway>((ref) {
  return SupabaseProjectDelegateGateway(ref.watch(supabaseClientProvider));
});
