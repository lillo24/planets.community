import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';

void main() {
  const contract = ProjectWorkspaceRpcContract();
  const parser = ProjectWorkspacePayloadParser();
  Map<String, dynamic> row(String id) => {
    'id': id,
    'project_id': 'project-1',
    'display_name': 'Documento',
    'workspace_url': 'https://example.org/team',
    'updated_at': '2030-01-01T00:00:00Z',
    'created_at': '2030-01-01T00:00:00Z',
  };
  test(
    'maps list and item-specific mutation identity and Project parameters',
    () {
      expect(contract.readParams('profile-1', 'project-1'), {
        'p_expected_profile_id': 'profile-1',
        'p_project_id': 'project-1',
      });
      expect(
        contract.saveParams(
          'manager-1',
          'project-1',
          'Documento',
          ProjectWorkspaceUrl.parse('https://example.org/team'),
          'link-1',
        ),
        {
          'p_expected_manager_profile_id': 'manager-1',
          'p_project_id': 'project-1',
          'p_display_name': 'Documento',
          'p_workspace_url': 'https://example.org/team',
          'p_link_id': 'link-1',
        },
      );
      expect(contract.removeParams('manager-1', 'project-1', 'link-1'), {
        'p_expected_manager_profile_id': 'manager-1',
        'p_project_id': 'project-1',
        'p_link_id': 'link-1',
      });
    },
  );
  test(
    'parses empty and ordered multi-link lists without exposing mutable cache',
    () {
      expect(parser.links([], 'project-1'), isEmpty);
      final links = parser.links([row('a'), row('b')], 'project-1');
      expect(links.map((link) => link.id), ['a', 'b']);
      expect(links.first.name, 'Documento');
      expect(links.first.updatedAt, DateTime.utc(2030));
      expect(() => links.clear(), throwsUnsupportedError);
    },
  );
  test(
    'rejects malformed lists, duplicate identities and every malformed row',
    () {
      for (final payload in [
        null,
        {},
        ['private'],
        [row('a'), row('a')],
        [
          row('a'),
          {...row('b'), 'project_id': 'other'},
        ],
        [
          {...row('a'), 'display_name': ' '},
        ],
        [
          {...row('a'), 'id': ''},
        ],
        [
          {...row('a'), 'workspace_url': 'http://example.org'},
        ],
        [
          {...row('a'), 'updated_at': 'invalid'},
        ],
        [
          {...row('a'), 'created_at': null},
        ],
      ]) {
        expect(() => parser.links(payload, 'project-1'), throwsFormatException);
      }
    },
  );
}
