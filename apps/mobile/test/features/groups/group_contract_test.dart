import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/groups/application/group_controllers.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/groups/domain/group_models.dart';

const actor = '00000000-0000-4000-8000-000000000001';
const id = '00000000-0000-4000-8000-000000000002';
Map<String, dynamic> row({
  int version = 1,
  String state = 'draft',
  bool suppressed = false,
  String name = 'Fictional garden',
}) => {
  'group_id': id,
  'name': name,
  'description': 'Local people caring for a shared garden.',
  'group_kind': 'informal',
  'locality': null,
  'volunteering_focus': true,
  'version': version,
  'publication_state': state,
  'directory_suppressed': suppressed,
  'created_at': '2026-10-11T12:00:00Z',
  'updated_at': '2026-10-11T12:00:00Z',
};
const content = GroupContent(
  name: 'Fictional garden',
  description: 'Local people caring for a shared garden.',
);
void main() {
  test('lifecycle commands preserve identity and advance reviewed versions with fresh keys', () async {
    var version = 1;
    var publication = 'draft';
    var currentName = content.name;
    final keys = <String>{};
    final editor = GroupEditorController(
      id: id,
      actor: actor,
      authorized: () => true,
      policyAllows: () => true,
      gateway: GroupGateway((name, args) async {
        if (name == 'get_own_group') {
          return [row(version: version, state: publication, name: currentName)];
        }
        if (name == 'recover_group_command') return [];
        expect(args['p_group_id'], id);
        expect(args['p_expected_profile_id'], actor);
        expect(args['p_expected_version'], version);
        expect(keys.add(args['p_client_request_id'] as String), isTrue);
        if (name == 'update_group') {
          currentName = (args['p_content'] as Map)['name'] as String;
        } else if (name == 'set_group_publication_state') {
          publication = args['p_publication_state'] as String;
        } else {
          throw StateError(name);
        }
        return ++version;
      }),
    );
    addTearDown(editor.dispose);
    await editor.reload();
    expect(await editor.publication(GroupPublication.published), isTrue);
    editor.edit(
      const GroupContent(
        name: 'Updated live group',
        description: 'A sufficiently detailed public description.',
      ),
    );
    expect(await editor.save(), isTrue);
    expect(editor.own!.publication, GroupPublication.published);
    expect(editor.own!.content.name, 'Updated live group');
    for (final next in [
      GroupPublication.draft,
      GroupPublication.archived,
      GroupPublication.draft,
    ]) {
      expect(await editor.publication(next), isTrue);
      expect(editor.own!.publication, next);
    }
    expect(editor.groupId, id);
    expect(keys, hasLength(5));
    expect(editor.own!.version, 6);
  });
  test('strict public and owner projections reject malformed wire types', () {
    expect(PublicGroup(row()).content.locality, isNull);
    expect(OwnGroup(row()).publication, GroupPublication.draft);
    for (final entry in <String, Object?>{
      'group_id': 'not-a-uuid',
      'version': '1',
      'group_kind': 'verified',
      'volunteering_focus': 'true',
      'created_at': 'yesterday',
      'name': null,
    }.entries) {
      expect(
        () => PublicGroup({...row(), entry.key: entry.value}),
        throwsFormatException,
        reason: entry.key,
      );
    }
    expect(
      () => OwnGroup({...row(), 'publication_state': 'pending'}),
      throwsFormatException,
    );
    expect(
      () => OwnGroup({...row(), 'directory_suppressed': null}),
      throwsFormatException,
    );
  });
  test('Unicode scalar limits, full replacement and blank locality', () {
    final unicode = GroupContent(
      name: '😀' * 120,
      description: '  purpose\n',
      locality: ' \t ',
    );
    expect(unicode.valid, isTrue);
    expect(groupTrim('\u00a0\u3000purpose\u0085'), 'purpose');
    expect(groupTrim('\ufeffpurpose'), '\ufeffpurpose');
    expect(GroupContent(name: '😀' * 121).valid, isFalse);
    expect(unicode.toJson(), {
      'name': '😀' * 120,
      'description': 'purpose',
      'group_kind': 'informal',
      'locality': null,
      'volunteering_focus': false,
    });
    expect(
      const GroupContent(name: 'a', description: 'x').publishable,
      isFalse,
    );
  });
  test('gateway composes literal filters and paired immutable cursor; scalar receipts strict', () async {
    final calls = <String, Map<String, dynamic>>{};
    Object? response = [row()];
    final gateway = GroupGateway((name, args) async {
      calls[name] = args;
      return response;
    });
    final filters = GroupFilters(
      search: r'%_\',
      kind: GroupKind.organization,
      volunteering: true,
      locality: ' Trento ',
    );
    final cursor = PublicGroup(row()).cursor;
    await gateway.publicPage(filters, cursor);
    expect(calls['list_public_groups'], {
      ...filters.params,
      ...cursor.params,
      'p_limit': 25,
    });
    response = [];
    expect(await gateway.publicDetail(id), isNull);
    response = {};
    await expectLater(gateway.publicDetail(id), throwsFormatException);
    response = id;
    expect(await gateway.create(actor, id, content), id);
    response = '2';
    await expectLater(
      gateway.update(actor, id, id, 1, content),
      throwsFormatException,
    );
    response = [
      {'group_id': id, 'accepted_version': 2},
    ];
    expect((await gateway.recover(actor, id))!.version, 2);
    response = [row(), row()];
    await expectLater(gateway.publicDetail(id), throwsFormatException);
  });
  test('paging deduplicates loads, preserves failure cursor, reset rejects late results', () async {
    final first = Completer<List<PublicGroup>>();
    final next = Completer<List<PublicGroup>>();
    final cursors = <GroupCursor?>[];
    var calls = 0;
    final pager = GroupPager<PublicGroup>((cursor) {
      cursors.add(cursor);
      return calls++ == 0 ? first.future : next.future;
    });
    addTearDown(pager.dispose);
    final loading = pager.load();
    await pager.load();
    expect(calls, 1);
    first.complete(
      List.generate(
        25,
        (i) => PublicGroup({
          ...row(),
          'group_id':
              '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        }),
      ),
    );
    await loading;
    expect(pager.rows.length, 25);
    expect(pager.more, isTrue);
    final paging = pager.load();
    next.completeError(Exception('offline'));
    await paging;
    expect(pager.rows.length, 25);
    expect(pager.error, isNotNull);
    final oldCursor = pager.cursor;
    final reset = pager.reset();
    await reset; // same failed future is an explicit new chain
    expect(cursors[1], oldCursor);
    expect(cursors.last, isNull);
    final late = Completer<List<PublicGroup>>();
    var n = 0;
    final resetPager = GroupPager<PublicGroup>(
      (_) => n++ == 0 ? late.future : Future.value([]),
    );
    addTearDown(resetPager.dispose);
    final old = resetPager.load();
    await resetPager.reset();
    late.complete([PublicGroup(row())]);
    await old;
    expect(resetPager.rows, isEmpty);
  });
  test(
    'later-page retry repeats cursor and deduplicates tied timestamps',
    () async {
      var calls = 0;
      final cursors = <GroupCursor?>[];
      final page = List.generate(
        25,
        (i) => PublicGroup({
          ...row(),
          'group_id':
              '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        }),
      );
      final pager = GroupPager<PublicGroup>((cursor) async {
        cursors.add(cursor);
        calls++;
        if (calls == 1) return page;
        if (calls == 2) throw Exception('network');
        return [page.last, PublicGroup(row())];
      });
      addTearDown(pager.dispose);
      await pager.load();
      await pager.load();
      await pager.load();
      expect(cursors[1], same(cursors[2]));
      expect(pager.rows.map((g) => g.id).toSet().length, pager.rows.length);
      expect(pager.more, isFalse);
    },
  );
  test('create lost reply recovers same key, reloads latest version, never duplicates', () async {
    var creates = 0, recoveries = 0;
    String? acceptedKey;
    final gateway = GroupGateway((name, args) async {
      switch (name) {
        case 'recover_group_command':
          recoveries++;
          return acceptedKey == args['p_client_request_id']
              ? [
                  {'group_id': id, 'accepted_version': 1},
                ]
              : [];
        case 'create_group_draft':
          creates++;
          acceptedKey = args['p_client_request_id'] as String;
          throw Exception('lost after commit');
        case 'get_own_group':
          return [row(version: 3)];
        default:
          throw StateError(name);
      }
    });
    final editor = GroupEditorController(
      gateway: gateway,
      actor: actor,
      authorized: () => true,
      policyAllows: () => true,
    );
    addTearDown(editor.dispose);
    editor.edit(content);
    expect(await editor.save(), isFalse);
    final key = editor.pending!.key;
    editor.edit(const GroupContent(name: 'retarget'));
    expect(editor.content.name, content.name);
    expect(await editor.retry(), isTrue);
    expect(acceptedKey, key);
    expect(creates, 1);
    expect(recoveries, 2);
    expect(editor.own!.version, 3);
    expect(editor.groupId, id);
  });
  test(
    'separate save/publication failures and stale reconciliation retain input',
    () async {
      var version = 1;
      var stale = false;
      var failPublish = true;
      final gateway = GroupGateway((name, args) async {
        if (name == 'recover_group_command') return [];
        if (name == 'get_own_group') {
          return [row(version: version, suppressed: true)];
        }
        if (name == 'create_group_draft') return id;
        if (name == 'update_group') {
          if (stale) {
            throw const PostgrestException(message: 'stale', code: 'PT409');
          }
          return ++version;
        }
        if (name == 'set_group_publication_state') {
          if (failPublish) {
            throw const PostgrestException(message: 'invalid', code: '22023');
          }
          version++;
          return version;
        }
        throw StateError(name);
      });
      final editor = GroupEditorController(
        gateway: gateway,
        actor: actor,
        authorized: () => true,
        policyAllows: () => true,
      );
      addTearDown(editor.dispose);
      editor.edit(content);
      expect(await editor.save(), isTrue);
      expect(await editor.publication(GroupPublication.published), isFalse);
      expect(editor.own!.publication, GroupPublication.draft);
      expect(editor.pending, isNull);
      expect(editor.groupId, id);
      stale = true;
      editor.edit(
        const GroupContent(
          name: 'My retained input',
          description: 'A changed description for the group.',
        ),
      );
      expect(await editor.save(), isFalse);
      expect(editor.failure, GroupFailure.stale);
      expect(editor.content.name, 'My retained input');
      version = 7;
      await editor.reload(keepInput: true);
      expect(editor.own!.version, 7);
      expect(editor.content.name, 'My retained input');
      expect(editor.dirty, isTrue);
      stale = false;
      expect(await editor.save(), isTrue);
      failPublish = false;
      expect(await editor.publication(GroupPublication.published), isTrue);
      expect(editor.own!.suppressed, isTrue);
    },
  );
  test(
    'policy and identity changes stop commands and reject late private results',
    () async {
      var account = true, policy = false, calls = 0;
      final reply = Completer<Object?>();
      final gateway = GroupGateway((name, args) async {
        calls++;
        return reply.future;
      });
      final editor = GroupEditorController(
        gateway: gateway,
        actor: actor,
        authorized: () => account,
        policyAllows: () => policy,
      );
      addTearDown(editor.dispose);
      editor.edit(content);
      expect(await editor.save(), isFalse);
      expect(calls, 0);
      policy = true;
      final saving = editor.save();
      account = false;
      editor.invalidate();
      reply.complete([
        {'group_id': id, 'accepted_version': 1},
      ]);
      expect(await saving, isFalse);
      expect(calls, 1);
      expect(editor.own, isNull);
      expect(editor.pending, isNull);
      expect(editor.content.name, isEmpty);
      expect(await editor.retry(), isFalse);
      expect(calls, 1);
    },
  );
}
