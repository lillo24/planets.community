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
    'version': 1,
  };
  test(
    'maps list and item-specific mutation identity and Project parameters',
    () {
      expect(contract.readParams('profile-1', 'project-1'), {
        'p_expected_profile_id': 'profile-1',
        'p_project_id': 'project-1',
        'p_limit': 10,
        'p_before_created_at': null,
        'p_before_id': null,
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
          'p_client_request_id': null,
          'p_expected_version': null,
        },
      );
      expect(contract.removeParams('manager-1', 'project-1', 'link-1', 1), {
        'p_expected_manager_profile_id': 'manager-1',
        'p_project_id': 'project-1',
        'p_link_id': 'link-1',
        'p_expected_version': 1,
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
  test('bounded page carries complete tied cursor and canonical authority', () {
    final page = parser.page(
      {
        'items': [row('b'), row('a')],
        'can_manage': false,
        'next_cursor': {'created_at': '2030-01-01T00:00:00Z', 'id': 'a'},
      },
      'project-1',
      limit: 2,
    );
    expect(page.items.map((item) => item.id), ['b', 'a']);
    expect(page.canManage, isFalse);
    expect(page.nextCursor!.id, 'a');
    expect(page.items.first.version, 1);
    expect(
      contract.readParams(
        'actor',
        'project-1',
        cursor: page.nextCursor,
        limit: 2,
      ),
      {
        'p_expected_profile_id': 'actor',
        'p_project_id': 'project-1',
        'p_limit': 2,
        'p_before_created_at': '2030-01-01T00:00:00.000Z',
        'p_before_id': 'a',
      },
    );
  });
  test(
    'rejects over-bound pages, invalid order and cursor/authority omissions',
    () {
      final rows = [row('b'), row('a')];
      for (final value in [
        {'items': rows, 'next_cursor': null},
        {'items': rows, 'can_manage': 'yes', 'next_cursor': null},
        {
          'items': [...rows, row('0')],
          'can_manage': true,
          'next_cursor': null,
        },
        {
          'items': [row('a'), row('b')],
          'can_manage': true,
          'next_cursor': null,
        },
        {
          'items': rows,
          'can_manage': true,
          'next_cursor': {'id': 'a'},
        },
        {
          'items': rows,
          'can_manage': true,
          'next_cursor': {'id': 'b', 'created_at': '2030-01-01T00:00:00Z'},
        },
        {
          'items': [],
          'can_manage': true,
          'next_cursor': {'id': 'a', 'created_at': '2030-01-01T00:00:00Z'},
        },
      ]) {
        expect(
          () => parser.page(value, 'project-1', limit: 2),
          throwsFormatException,
        );
      }
      expect(
        parser.page({
          'items': [],
          'can_manage': false,
          'next_cursor': null,
        }, 'project-1').items,
        isEmpty,
      );
    },
  );
  test(
    'receipt distinguishes unaccepted, current item and accepted-but-removed',
    () {
      expect(
        parser.receipt({'accepted': false}, 'project-1').accepted,
        isFalse,
      );
      final value = {
        'accepted': true,
        'link_id': 'a',
        'display_name': 'Documento',
        'workspace_url': 'https://example.org/team',
        'item': row('a'),
      };
      expect(parser.receipt(value, 'project-1').item!.id, 'a');
      final removed = parser.receipt({...value, 'item': null}, 'project-1');
      expect(removed.accepted, isTrue);
      expect(removed.linkId, 'a');
      expect(removed.item, isNull);
      for (final malformed in [
        null,
        {},
        {'accepted': 'yes'},
        {...value, 'item': row('other')},
        {...value, 'workspace_url': 'http://example.org'},
      ]) {
        expect(
          () => parser.receipt(malformed, 'project-1'),
          throwsFormatException,
        );
      }
    },
  );
  test('mutation parameters bind Add identity and Edit/Remove version', () {
    final url = ProjectWorkspaceUrl.parse('https://example.org/team');
    expect(
      contract.saveParams(
        'actor',
        'project-1',
        'Doc',
        url,
        null,
        requestId: 'stable-action',
      )['p_client_request_id'],
      'stable-action',
    );
    final edit = contract.saveParams(
      'actor',
      'project-1',
      'Doc',
      url,
      'a',
      expectedVersion: 7,
    );
    expect(edit['p_expected_version'], 7);
    expect(edit['p_client_request_id'], isNull);
    expect(
      contract.removeParams('actor', 'project-1', 'a', 7)['p_expected_version'],
      7,
    );
    for (final version in [null, 0, -1, '1']) {
      expect(
        () => parser.workspace({...row('a'), 'version': version}, 'project-1'),
        throwsFormatException,
      );
    }
  });
}
