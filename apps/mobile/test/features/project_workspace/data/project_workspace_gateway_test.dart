import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';

void main() {
  const contract = ProjectWorkspaceRpcContract();
  const parser = ProjectWorkspacePayloadParser();

  test('maps identity-bound read, set, and clear RPC parameters', () {
    expect(contract.readParams('profile-1', 'project-1'), {
      'p_expected_profile_id': 'profile-1',
      'p_project_id': 'project-1',
    });
    expect(
      contract.setParams(
        'manager-1',
        'project-1',
        ProjectWorkspaceUrl.parse('https://example.org/team'),
      ),
      {
        'p_expected_manager_profile_id': 'manager-1',
        'p_project_id': 'project-1',
        'p_workspace_url': 'https://example.org/team',
      },
    );
    expect(contract.clearParams('manager-1', 'project-1'), {
      'p_expected_manager_profile_id': 'manager-1',
      'p_project_id': 'project-1',
    });
  });

  test('strictly parses zero or one matching workspace row', () {
    expect(parser.optionalWorkspace(const [], 'project-1'), isNull);
    final workspace = parser.optionalWorkspace([
      {
        'project_id': 'project-1',
        'workspace_url': 'https://example.org/team',
        'updated_at': '2030-01-01T00:00:00Z',
      },
    ], 'project-1');
    expect(workspace?.url.hostname, 'example.org');
    expect(workspace?.updatedAt, DateTime.utc(2030));
  });

  test('rejects malformed, mismatched, or multiple rows', () {
    expect(
      () => parser.optionalWorkspace(const ['private'], 'project-1'),
      throwsFormatException,
    );
    expect(
      () => parser.optionalWorkspace([
        {
          'project_id': 'another-project',
          'workspace_url': 'https://example.org/team',
          'updated_at': '2030-01-01T00:00:00Z',
        },
      ], 'project-1'),
      throwsFormatException,
    );
    expect(
      () => parser.optionalWorkspace(const [{}, {}], 'project-1'),
      throwsFormatException,
    );
  });
}
