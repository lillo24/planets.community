import 'package:flutter/material.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

class FakeProjectDelegateGateway implements ProjectDelegateGateway {
  ProjectManagementRole role = ProjectManagementRole.none;
  Future<ProjectManagementRole>? roleResult;
  List<ProjectDelegate> delegates = [];
  Future<List<ProjectDelegate>>? delegatesResult;
  List<ProjectDelegateInvitation> invitations = [];
  Future<List<ProjectDelegateInvitation>>? invitationsResult;
  List<DelegatedProject> delegatedProjects = [];
  ProjectDelegateInvitePreview preview = const ProjectDelegateInvitePreview(
    isAvailable: false,
  );
  ProjectDelegateInvitationResult created = ProjectDelegateInvitationResult(
    id: 'invitation-1',
    token: 'A' * 43,
    expiresAt: DateTime.utc(2030, 1, 8),
    requestedAuthorityRole: ProjectDelegatedAuthorityRole.coOrganizer,
  );
  Object? failure;
  Object? mutationFailure;
  Object? listFailure;
  Future<void>? mutationDelay;
  final calls = <String>[];

  @override
  Future<void> acceptInvitation({
    required String expectedProfileId,
    required String token,
  }) async {
    calls.add('accept:$expectedProfileId:$token');
    if (failure case final error?) throw error;
  }

  @override
  Future<ProjectDelegateInvitationResult> createInvitation({
    required String expectedStructuralActorId,
    required String projectId,
    required ProjectDelegatedAuthorityRole requestedAuthorityRole,
  }) async {
    calls.add(
      'create:$expectedStructuralActorId:$projectId:${requestedAuthorityRole.wireValue}',
    );
    await _waitForMutation();
    if (mutationFailure case final error?) throw error;
    if (failure case final error?) throw error;
    return ProjectDelegateInvitationResult(
      id: created.id,
      token: created.token,
      expiresAt: created.expiresAt,
      requestedAuthorityRole: requestedAuthorityRole,
    );
  }

  @override
  Future<ProjectManagementRole> getOwnManagementRole({
    required String expectedProfileId,
    required String projectId,
  }) async {
    calls.add('role:$expectedProfileId:$projectId');
    if (failure case final error?) throw error;
    return roleResult ?? role;
  }

  @override
  Future<List<ProjectDelegate>> listDelegates({
    required String expectedStructuralActorId,
    required String projectId,
  }) async {
    calls.add('delegates:$expectedStructuralActorId:$projectId');
    if (listFailure case final error?) throw error;
    if (failure case final error?) throw error;
    return delegatesResult ?? delegates;
  }

  @override
  Future<List<ProjectDelegateInvitation>> listPendingInvitations({
    required String expectedStructuralActorId,
    required String projectId,
  }) async {
    calls.add('invitations:$expectedStructuralActorId:$projectId');
    if (listFailure case final error?) throw error;
    if (failure case final error?) throw error;
    return invitationsResult ?? invitations;
  }

  @override
  Future<List<DelegatedProject>> listOwnDelegatedProjects(
    String expectedProfileId,
  ) async {
    calls.add('projects:$expectedProfileId');
    if (failure case final error?) throw error;
    return delegatedProjects;
  }

  @override
  Future<ProjectDelegateInvitePreview> previewInvitation(String token) async {
    calls.add('preview:$token');
    if (failure case final error?) throw error;
    return preview;
  }

  @override
  Future<void> revokeDelegate({
    required String expectedStructuralActorId,
    required String delegateId,
  }) async {
    calls.add('revoke-delegate:$expectedStructuralActorId:$delegateId');
    await _waitForMutation();
    if (mutationFailure case final error?) throw error;
    if (failure case final error?) throw error;
    delegates = delegates.where((item) => item.id != delegateId).toList();
  }

  @override
  Future<void> revokeInvitation({
    required String expectedStructuralActorId,
    required String invitationId,
  }) async {
    calls.add('revoke-invitation:$expectedStructuralActorId:$invitationId');
    await _waitForMutation();
    if (mutationFailure case final error?) throw error;
    if (failure case final error?) throw error;
    invitations = invitations.where((item) => item.id != invitationId).toList();
  }

  @override
  Future<void> changeDelegateRole({
    required String expectedStructuralActorId,
    required String delegateId,
    required ProjectDelegatedAuthorityRole authorityRole,
  }) async {
    calls.add(
      'change-role:$expectedStructuralActorId:$delegateId:${authorityRole.wireValue}',
    );
    await _waitForMutation();
    if (mutationFailure case final error?) throw error;
    if (failure case final error?) throw error;
    delegates = delegates
        .map(
          (item) => item.id != delegateId
              ? item
              : ProjectDelegate(
                  id: item.id,
                  profileId: item.profileId,
                  displayName: item.displayName,
                  delegatedAt: item.delegatedAt,
                  grantedByProfileId: item.grantedByProfileId,
                  grantedByDisplayName: item.grantedByDisplayName,
                  authorityRole: authorityRole,
                ),
        )
        .toList();
  }

  Future<void> _waitForMutation() async {
    if (mutationDelay case final delay?) await delay;
  }
}

class FakeProjectInviteSharing implements ProjectInviteSharing {
  String? copied;
  String? shared;

  @override
  Future<void> copy(String value) async => copied = value;

  @override
  Future<void> share(String value, {Rect? origin}) async => shared = value;
}
