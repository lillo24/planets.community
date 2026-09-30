import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_need_models.dart';

void main() {
  const parser = ProjectResourceNeedsPayloadParser();

  test('strictly parses public open needs', () {
    final need = parser.publicNeed({
      'resource_need_id': 'need-1',
      'title': 'Paint',
      'details': 'Exterior paint.',
      'created_at': '2026-09-15T09:00:00Z',
    });

    expect(need.id, 'need-1');
    expect(need.title, 'Paint');
    expect(need.details, 'Exterior paint.');
    expect(need.createdAt, DateTime.utc(2026, 9, 15, 9));
  });

  test('strictly parses owner open and closed history', () {
    final open = parser.ownNeed(_ownRow('open'));
    final closed = parser.ownNeed({
      ..._ownRow('closed'),
      'closed_at': '2026-09-16T09:00:00Z',
    });

    expect(open.projectKind, ProjectKind.oneTime);
    expect(open.isOpen, isTrue);
    expect(closed.state, ProjectResourceNeedState.closed);
    expect(closed.closedAt, DateTime.utc(2026, 9, 16, 9));
  });

  test('unknown states, kinds, and malformed rows fail loudly', () {
    expect(() => parser.ownNeed(_ownRow('fulfilled')), throwsFormatException);
    expect(
      () => parser.ownNeed({..._ownRow('open'), 'project_kind': 'campaign'}),
      throwsFormatException,
    );
    expect(() => parser.publicNeed([]), throwsFormatException);
    expect(
      () => parser.publicNeed({
        'resource_need_id': 'need-1',
        'title': null,
        'details': null,
        'created_at': '2026-09-15T09:00:00Z',
      }),
      throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
    );
  });

  test('input mirrors canonical title and detail bounds', () {
    expect(
      const ProjectResourceNeedInput(title: 'P', details: '').isValid,
      isFalse,
    );
    expect(
      ProjectResourceNeedInput(
        title: 'Paint',
        details: List.filled(
          projectResourceNeedDetailsMaxLength + 1,
          'x',
        ).join(),
      ).isValid,
      isFalse,
    );
    expect(
      const ProjectResourceNeedInput(
        title: 'Paint',
        details: 'Exterior paint.',
      ).isValid,
      isTrue,
    );
  });

  test('gateway uses only the five canonical RPCs and no table read', () {
    final source = File(
      'lib/features/project_resource_needs/data/project_resource_needs_gateway.dart',
    ).readAsStringSync();
    expect(source, isNot(contains(".from('project_resource_needs')")));
    for (final rpc in [
      'list_public_project_resource_needs',
      'list_own_project_resource_needs',
      'create_project_resource_need',
      'update_project_resource_need',
      'close_project_resource_need',
    ]) {
      expect(source, contains("'$rpc'"));
    }
  });
}

Map<String, dynamic> _ownRow(String state) => {
  'resource_need_id': 'need-1',
  'project_id': 'proposal-1',
  'project_kind': 'one_time',
  'title': 'Paint',
  'details': null,
  'state': state,
  'created_at': '2026-09-15T09:00:00Z',
  'updated_at': '2026-09-15T10:00:00Z',
  'closed_at': null,
};
