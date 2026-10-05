import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/moderation/data/own_consequence_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/own_consequence_models.dart';

import '../../../support/fake_own_consequences.dart';

void main() {
  const contract = OwnConsequenceRpcContract();

  test(
    'safe projection parses all four types, both states and content kinds',
    () {
      for (final type in [
        'safety_notice',
        'interaction_restriction',
        'content_hide',
        'account_suspension',
      ]) {
        for (final active in [true, false]) {
          for (final kind in [
            null,
            'one_time',
            'recurring',
            'resource_listing',
          ]) {
            final item = OwnConsequence.fromJson(
              ownConsequenceRow(
                1,
                type: type,
                active: active,
                contentKind: kind,
              ),
            );
            expect(item.isActive, active);
            expect(item.revokedAt == null, active);
            expect(item.revokeReason == null, active);
            expect(item.contentKind, kind);
            expect(item.applyReason, contains('<b>not markup</b>'));
          }
        }
      }
    },
  );

  test('nullable content title and verbatim Unicode reasons are valid', () {
    final row = ownConsequenceRow(1, contentKind: 'one_time')
      ..['content_title'] = null;
    row['apply_reason'] = '  ${List.filled(999, '🌍').join()}  ';
    final item = OwnConsequence.fromJson(row);
    expect(item.contentTitle, isNull);
    expect(item.applyReason, row['apply_reason']);
    expect(item.appliedAt.microsecond, 456);
  });

  test(
    'cursor retains exact six-digit timestamp and paired ID, default 20',
    () {
      final item = ownConsequence(5);
      expect(contract.params('verified-user', item.cursor), {
        'p_expected_profile_id': 'verified-user',
        'p_limit': 20,
        'p_before_applied_at': '2026-10-01T12:00:00.123456+00:00',
        'p_before_consequence_id': item.id,
      });
      expect(
        contract.params('verified-user', null)['p_before_applied_at'],
        isNull,
      );
      expect(
        contract.params('verified-user', null)['p_before_consequence_id'],
        isNull,
      );
    },
  );

  test('empty is successful only for a valid empty page', () {
    expect(contract.parse([]).items, isEmpty);
    expect(contract.parse([]).hasMore, isFalse);
    for (final value in [
      null,
      {},
      '[]',
      [null],
      [true],
      [
        {'consequence_id': 'bad'},
      ],
    ]) {
      expect(() => contract.parse(value), throwsFormatException);
    }
  });

  test(
    'full tied-time page continues with UUID ordering and no precision loss',
    () {
      final page = contract.parse([
        for (var id = 21; id >= 2; id--) ownConsequenceRow(id),
      ]);
      expect(page.items, hasLength(20));
      expect(page.hasMore, isTrue);
      final next = contract.parse([
        ownConsequenceRow(1),
      ], cursor: page.items.last.cursor);
      expect(next.items.single.id, endsWith('000000000001'));
      expect(next.hasMore, isFalse);
      expect(
        () => contract.parse([
          ownConsequenceRow(2),
        ], cursor: page.items.last.cursor),
        throwsFormatException,
      );
      expect(
        () => contract.parse([ownConsequenceRow(1), ownConsequenceRow(2)]),
        throwsFormatException,
      );
      expect(
        () => contract.parse([ownConsequenceRow(1), ownConsequenceRow(1)]),
        throwsFormatException,
      );
      expect(
        () => contract.parse([
          for (var id = 21; id > 0; id--) ownConsequenceRow(id),
        ]),
        throwsFormatException,
      );
    },
  );

  test(
    'malformed, unsafe and contradictory episodes fail without private text',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (r) => r.remove('apply_reason'),
        (r) => r['actor_profile_id'] = 'private-staff-identity',
        (r) => r['internal_note'] = 'private-fixture-text',
        (r) => r['consequence_type'] = 'unknown',
        (r) => r['consequence_id'] = 'invalid',
        (r) => r['is_active'] = 'true',
        (r) => r['apply_reason'] = ' ',
        (r) => r['apply_reason'] = List.filled(2001, 'x').join(),
        (r) => r['applied_at'] = '2026-02-31T12:00:00Z',
        (r) => r['applied_at'] = '2026-10-01',
        (r) => r['applied_at'] = '2026-10-01T12:00:00.1234567Z',
        (r) => r['is_active'] = false,
        (r) => r['revoked_at'] = '2026-10-02T12:00:00Z',
        (r) => r['content_title'] = 'orphan-title',
        (r) => r['content_kind'] = 'unknown',
      ];
      for (final mutate in mutations) {
        final row = ownConsequenceRow(1);
        mutate(row);
        expect(
          () => OwnConsequence.fromJson(row),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'safe error',
              isNot(contains('private-fixture-text')),
            ),
          ),
        );
      }
      final removed = ownConsequenceRow(1, active: false)
        ..['revoked_at'] = '2026-09-01T12:00:00Z';
      expect(() => OwnConsequence.fromJson(removed), throwsFormatException);
    },
  );
}
