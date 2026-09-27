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
    required String expectedOwnerId,
    required String projectId,
  });

  Future<List<ProjectDelegateInvitation>> listPendingInvitations({
    required String expectedOwnerId,
    required String projectId,
  });

  Future<ProjectDelegateInvitationResult> createInvitation({
    required String expectedOwnerId,
    required String projectId,
  });

  Future<void> revokeInvitation({
    required String expectedOwnerId,
    required String invitationId,
  });

  Future<void> revokeDelegate({
    required String expectedOwnerId,
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

class SupabaseProjectDelegateGateway implements ProjectDelegateGateway {
  const SupabaseProjectDelegateGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ProjectManagementRole> getOwnManagementRole({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_own_project_management_role',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_project_id': projectId,
      },
    );
    if (response is! String) {
      throw const FormatException('Management role was malformed.');
    }
    return ProjectManagementRole.fromWire(response);
  }

  @override
  Future<List<ProjectDelegate>> listDelegates({
    required String expectedOwnerId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_delegates_for_owner',
      params: {
        'p_expected_owner_profile_id': expectedOwnerId,
        'p_project_id': projectId,
      },
    );
    return response.map(_delegate).toList(growable: false);
  }

  @override
  Future<List<ProjectDelegateInvitation>> listPendingInvitations({
    required String expectedOwnerId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_delegate_invitations_for_owner',
      params: {
        'p_expected_owner_profile_id': expectedOwnerId,
        'p_project_id': projectId,
      },
    );
    final now = DateTime.now().toUtc();
    return response
        .map(_row)
        .where(
          (row) =>
              row['status'] == 'pending' &&
              _date(row, 'expires_at').isAfter(now),
        )
        .map(_invitation)
        .toList(growable: false);
  }

  @override
  Future<ProjectDelegateInvitationResult> createInvitation({
    required String expectedOwnerId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'create_project_delegate_invitation',
      params: {
        'p_expected_owner_profile_id': expectedOwnerId,
        'p_project_id': projectId,
      },
    );
    if (response.length != 1 || response.single is! Map<String, dynamic>) {
      throw const FormatException('Invitation creation result was malformed.');
    }
    final row = response.single as Map<String, dynamic>;
    return ProjectDelegateInvitationResult(
      id: _string(row, 'invitation_id'),
      token: _string(row, 'invite_token'),
      expiresAt: _date(row, 'expires_at'),
    );
  }

  @override
  Future<void> revokeInvitation({
    required String expectedOwnerId,
    required String invitationId,
  }) async {
    await _client.rpc<dynamic>(
      'revoke_project_delegate_invitation',
      params: {
        'p_expected_owner_profile_id': expectedOwnerId,
        'p_invitation_id': invitationId,
      },
    );
  }

  @override
  Future<void> revokeDelegate({
    required String expectedOwnerId,
    required String delegateId,
  }) async {
    await _client.rpc<dynamic>(
      'revoke_project_delegate',
      params: {
        'p_expected_owner_profile_id': expectedOwnerId,
        'p_delegate_id': delegateId,
      },
    );
  }

  @override
  Future<ProjectDelegateInvitePreview> previewInvitation(String token) async {
    final response = await _client.rpc<List<dynamic>>(
      'preview_project_delegate_invitation',
      params: {'p_token': token},
    );
    if (response.length != 1 || response.single is! Map<String, dynamic>) {
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
      expiresAt: _date(row, 'expires_at'),
    );
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
      'list_own_delegated_projects',
      params: {'p_expected_profile_id': expectedProfileId},
    );
    return response.map(_delegatedProject).toList(growable: false);
  }
}

ProjectDelegate _delegate(dynamic value) {
  final row = _row(value);
  return ProjectDelegate(
    id: _string(row, 'delegate_id'),
    profileId: _string(row, 'delegate_profile_id'),
    displayName: _string(row, 'delegate_display_name'),
    delegatedAt: _date(row, 'delegated_at'),
  );
}

ProjectDelegateInvitation _invitation(dynamic value) {
  final row = _row(value);
  return ProjectDelegateInvitation(
    id: _string(row, 'invitation_id'),
    createdAt: _date(row, 'created_at'),
    expiresAt: _date(row, 'expires_at'),
  );
}

DelegatedProject _delegatedProject(dynamic value) {
  final row = _row(value);
  return DelegatedProject(
    id: _string(row, 'project_id'),
    kind: ProjectKind.fromWire(_string(row, 'project_kind')),
    title: _string(row, 'project_title'),
    status: _string(row, 'project_status'),
    delegatedAt: _date(row, 'delegated_at'),
  );
}

Map<String, dynamic> _row(dynamic value) {
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
