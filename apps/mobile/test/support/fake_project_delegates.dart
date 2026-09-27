import 'package:flutter/material.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

class FakeProjectDelegateGateway implements ProjectDelegateGateway {
  ProjectManagementRole role = ProjectManagementRole.none;
  Future<ProjectManagementRole>? roleResult;
  List<ProjectDelegate> delegates = [];
  List<ProjectDelegateInvitation> invitations = [];
  List<DelegatedProject> delegatedProjects = [];
  ProjectDelegateInvitePreview preview = const ProjectDelegateInvitePreview(
    isAvailable: false,
  );
  ProjectDelegateInvitationResult created = ProjectDelegateInvitationResult(
    id: 'invitation-1',
    token: 'A' * 43,
    expiresAt: DateTime.utc(2030, 1, 8),
  );
  Object? failure;
  Object? listFailure;
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
    required String expectedOwnerId,
    required String projectId,
  }) async {
    calls.add('create:$expectedOwnerId:$projectId');
    if (failure case final error?) throw error;
    return created;
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
    required String expectedOwnerId,
    required String projectId,
  }) async {
    calls.add('delegates:$expectedOwnerId:$projectId');
    if (listFailure case final error?) throw error;
    if (failure case final error?) throw error;
    return delegates;
  }

  @override
  Future<List<ProjectDelegateInvitation>> listPendingInvitations({
    required String expectedOwnerId,
    required String projectId,
  }) async {
    calls.add('invitations:$expectedOwnerId:$projectId');
    if (listFailure case final error?) throw error;
    if (failure case final error?) throw error;
    return invitations;
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
    required String expectedOwnerId,
    required String delegateId,
  }) async {
    calls.add('revoke-delegate:$expectedOwnerId:$delegateId');
    if (failure case final error?) throw error;
    delegates = delegates.where((item) => item.id != delegateId).toList();
  }

  @override
  Future<void> revokeInvitation({
    required String expectedOwnerId,
    required String invitationId,
  }) async {
    calls.add('revoke-invitation:$expectedOwnerId:$invitationId');
    if (failure case final error?) throw error;
    invitations = invitations.where((item) => item.id != invitationId).toList();
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
