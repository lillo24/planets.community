import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

void main() {
  const contract = ProjectDelegateRpcContract();
  const parser = ProjectDelegatePayloadParser();

  test('RPC contract binds structural actor and exact delegated role', () {
    expect(
      contract.createInvitationParams(
        'actor-1',
        'project-1',
        ProjectDelegatedAuthorityRole.coCreator,
      ),
      {
        'p_expected_owner_profile_id': 'actor-1',
        'p_project_id': 'project-1',
        'p_requested_authority_role': 'co_creator',
      },
    );
    expect(
      contract.changeDelegateRoleParams(
        'actor-1',
        'delegate-1',
        ProjectDelegatedAuthorityRole.coOrganizer,
      ),
      {
        'p_expected_structural_profile_id': 'actor-1',
        'p_delegate_id': 'delegate-1',
        'p_authority_role': 'co_organizer',
      },
    );
  });

  test('active delegate parser preserves role and grantor provenance', () {
    final delegate = parser.delegate({
      'delegate_id': 'delegate-1',
      'delegate_profile_id': 'profile-2',
      'delegate_display_name': 'Jordan',
      'delegated_at': '2030-01-01T00:00:00Z',
      'authority_role': 'co_creator',
      'granted_by_profile_id': 'profile-1',
      'granted_by_display_name': 'Alex',
    });

    expect(delegate.authorityRole, ProjectDelegatedAuthorityRole.coCreator);
    expect(delegate.grantedByProfileId, 'profile-1');
    expect(delegate.grantedByDisplayName, 'Alex');
  });

  test('pending invitation parser preserves requested role and issuer', () {
    final row = {
      'invitation_id': 'invitation-1',
      'created_at': '2030-01-01T00:00:00Z',
      'expires_at': '2030-01-08T00:00:00Z',
      'requested_authority_role': 'co_organizer',
      'issuer_profile_id': 'profile-1',
      'issuer_display_name': 'Alex',
    };
    final invitation = parser.invitation(row);

    expect(
      invitation.requestedAuthorityRole,
      ProjectDelegatedAuthorityRole.coOrganizer,
    );
    expect(invitation.issuerProfileId, 'profile-1');
    expect(invitation.issuerDisplayName, 'Alex');
    expect(
      () => parser.invitation({...row}..remove('requested_authority_role')),
      throwsFormatException,
    );
    expect(
      () => parser.invitation({...row}..remove('issuer_profile_id')),
      throwsFormatException,
    );
  });

  test('delegated Project parser preserves and validates exact role', () {
    final row = {
      'project_id': 'project-1',
      'project_kind': 'one_time',
      'project_title': 'Community mural',
      'project_status': 'published',
      'delegated_at': '2030-01-01T00:00:00Z',
    };

    expect(
      parser.delegatedProject({
        ...row,
        'authority_role': 'co_creator',
      }).authorityRole,
      ProjectDelegatedAuthorityRole.coCreator,
    );
    expect(() => parser.delegatedProject(row), throwsFormatException);
    expect(
      () => parser.delegatedProject({...row, 'authority_role': 'admin'}),
      throwsFormatException,
    );
  });

  test('created invitation keeps the requested role beside its raw token', () {
    final result = parser.invitationResult([
      {
        'invitation_id': 'invitation-1',
        'invite_token': 'token-1',
        'expires_at': '2030-01-08T00:00:00Z',
      },
    ], ProjectDelegatedAuthorityRole.coCreator);

    expect(
      result.requestedAuthorityRole,
      ProjectDelegatedAuthorityRole.coCreator,
    );
    expect(result.token, 'token-1');
  });

  test(
    'Project authority gateway uses RPCs instead of direct table access',
    () {
      final source = File(
        'lib/features/project_delegates/data/project_delegate_gateway.dart',
      ).readAsStringSync();

      for (final rpc in [
        'get_own_project_management_role',
        'list_project_delegates_for_owner',
        'list_project_delegate_invitations_for_owner',
        'create_project_delegate_invitation',
        'change_project_delegate_role',
        'revoke_project_delegate',
      ]) {
        expect(source, contains("'$rpc'"));
      }
      expect(source, isNot(contains('.from(')));
    },
  );
}
