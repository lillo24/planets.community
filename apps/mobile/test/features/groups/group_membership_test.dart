import 'dart:async';
import 'dart:io';

import 'package:planets_mobile/features/groups/domain/group_models.dart';

import 'group_contract_test.dart' as content_fixture show row;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/group_membership/application/group_relationship_controller.dart';
import 'package:planets_mobile/features/group_membership/data/group_relationship_gateway.dart';
import 'package:planets_mobile/features/group_membership/domain/group_relationships.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/groups/application/group_controllers.dart';
import 'package:planets_mobile/app/router/native_project_links.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';
import 'package:planets_mobile/core/monitoring/invitation_telemetry_filter.dart';

const actor = 'f303b000-0000-4000-8000-000000000001',
    group = 'f303b000-0000-4000-8000-000000000002',
    episode = 'f303b000-0000-4000-8000-000000000003';
final capability = 'A' * 43;
Map<String, dynamic> selfRow({String? role, String? member, String? pending}) =>
    {
      'authority_role': role,
      'delegate_id': role == null || role == 'creator' ? null : episode,
      'current_membership_id': member,
      'membership_status': member == null ? null : 'current',
      'pending_request_id': pending,
      'pending_note': pending == null ? null : 'Private note',
      'latest_request_id': pending,
      'latest_request_status': pending == null ? null : 'pending',
      'latest_membership_id': member,
      'latest_membership_status': member == null ? null : 'current',
    };
Map<String, dynamic> receiptRow({String? status = 'current'}) => {
  'group_id': group,
  'relationship_id': episode,
  'relationship_kind': 'membership',
  'outcome': 'joined',
  'current_status': status,
  'replayed': false,
  'expires_at': null,
};
Map<String, dynamic> personRow(int n) => {
  'profile_id': 'f303b000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
  'display_name': 'Fictional $n',
  'is_creator': false,
  'authority_role': null,
  'delegate_id': null,
  'current_membership_id': episode,
  'joined_at': '2026-10-12T00:00:00Z',
  'role_rank': 3,
};
void main() {
  test('structural Restore lost reply recovers and exits without reading the Creator draft', () async {
    var accepted = false, reads = 0, writes = 0;
    final editor = GroupEditorController(
      id: group,
      actor: actor,
      structural: true,
      authorized: () => true,
      policyAllows: () => true,
      gateway: GroupGateway((operation, args) async {
        if (operation == 'get_group_structural_context') {
          reads++;
          return [
            {...content_fixture.row(state: 'archived'), 'group_id': group},
          ];
        }
        if (operation == 'recover_group_structural_command') {
          return accepted
              ? [
                  {'group_id': group, 'accepted_version': 3},
                ]
              : [];
        }
        if (operation == 'set_managed_group_publication_state') {
          writes++;
          accepted = true;
          throw const SocketException('Synthetic reply loss.');
        }
        throw StateError('Wrong content boundary: $operation');
      }),
    );
    addTearDown(editor.dispose);
    await editor.reload();
    expect(await editor.publication(GroupPublication.draft), false);
    expect(await editor.retry(), true);
    expect(editor.accessEnded, true);
    expect(editor.own, isNull);
    expect(reads, 1);
    expect(writes, 1);
  });
  test('exact-self pending request and null third-party status stay distinct from membership', () {
    final own = GroupSelfContext(selfRow(pending: episode));
    expect(own.pendingRequestId, episode);
    expect(own.people, false);
    expect(own.membershipId, isNull);
    final receipt = GroupRelationshipReceipt(receiptRow(status: null));
    expect(receipt.currentStatus, isNull);
    expect(receipt.outcome, 'joined');
    final bad = selfRow()..remove('pending_request_id');
    expect(() => GroupSelfContext(bad), throwsFormatException);
    expect(
      () => GroupRelationshipReceipt({
        ...receiptRow(),
        'current_status': 'invented',
      }),
      throwsFormatException,
    );
  });
  test(
    'rank cursor, bounded own pages and exact-self RPC never scan history',
    () async {
      final calls = <({String name, Map<String, dynamic> args})>[];
      final gateway = GroupRelationshipGateway(
        GroupGateway((name, args) async {
          calls.add((name: name, args: args));
          return name == 'get_own_group_membership_context'
              ? [selfRow()]
              : name == 'list_current_group_people'
              ? [personRow(4)]
              : [];
        }),
      );
      await gateway.self(actor, group);
      expect(calls.single.name, 'get_own_group_membership_context');
      final people = await gateway.people(actor, group, null);
      await gateway.people(actor, group, people.single.cursor);
      expect(calls.last.args['p_after_role_rank'], 3);
      expect(calls.last.args['p_after_profile_id'], people.single.id);
      expect(calls.last.args['p_limit'], 25);
      await gateway.history(actor, GroupHistoryKind.memberships);
      expect(calls.last.args.containsKey('p_before_joined_at'), true);
      expect(calls.last.args.containsKey('p_before_created_at'), false);
    },
  );
  test('loaded window survives transport failure, denial clears it, and late identity results are rejected', () async {
    var active = true, mode = 0;
    final late = Completer<List<GroupPerson>>();
    final pager = GroupRelationshipPager<GroupPerson>((cursor) async {
      if (mode == 1) {
        throw const PostgrestException(message: 'offline', code: '503');
      }
      if (mode == 2) {
        throw const PostgrestException(message: 'denied', code: '42501');
      }
      if (mode == 3) return late.future;
      return [GroupPerson(personRow(4))];
    }, () => active);
    addTearDown(pager.dispose);
    await pager.load();
    mode = 1;
    await pager.refresh();
    expect(pager.rows.length, 1);
    expect(pager.error, isNotNull);
    mode = 2;
    await pager.refresh();
    expect(pager.rows, isEmpty);
    mode = 3;
    final read = pager.refresh();
    active = false;
    pager.clear();
    late.complete([GroupPerson(personRow(5))]);
    await read;
    expect(pager.rows, isEmpty);
  });
  test('frozen actor key recovers a lost response, rejects changed intent and clears on account switch', () async {
    String? identity = actor;
    String? acceptedKey;
    var sends = 0;
    final registry = GroupCommandRegistry(
      GroupRelationshipGateway(
        GroupGateway((name, args) async {
          if (name == 'recover_group_relationship_command') {
            return acceptedKey == args['p_client_request_id']
                ? [receiptRow()]
                : [];
          }
          sends++;
          acceptedKey = args['p_client_request_id'];
          throw const PostgrestException(message: 'lost reply');
        }),
      ),
      () => identity,
    );
    addTearDown(registry.dispose);
    final intent = {'p_group_id': group, 'p_note': 'first'};
    expect(
      await registry.run(
        'request',
        actor,
        GroupMutation.request,
        intent,
        policyAllows: () => true,
      ),
      isNull,
    );
    final key = registry.attempts['request']!.key;
    expect(
      await registry.run('request', actor, GroupMutation.request, {
        'p_group_id': group,
        'p_note': 'changed',
      }, policyAllows: () => true),
      isNull,
    );
    expect(registry.attempts['request']!.key, key);
    expect(registry.attempts['request']!.failure, GroupFailure.stale);
    expect(
      await registry.run(
        'request',
        actor,
        GroupMutation.request,
        intent,
        policyAllows: () => true,
      ),
      isNotNull,
    );
    expect(sends, 1);
    identity = null;
    registry.clear();
    expect(registry.attempts, isEmpty);
  });
  test('invitation opening never accepts, response loss recovers after unavailable preview, status retry is read only', () async {
    var sent = 0, recovered = false, statusFails = true, available = true;
    final controller = GroupInvitationController(
      GroupRelationshipGateway(
        GroupGateway((name, args) async {
          if (name == 'get_group_participant_invitation_preview') {
            return [
              {
                'available': available,
                'group_id': available ? group : null,
                'group_name': available ? 'Fictional garden' : null,
                'group_kind': available ? 'informal' : null,
              },
            ];
          }
          if (name == 'recover_group_relationship_command') {
            return recovered ? [receiptRow()] : [];
          }
          if (name == 'accept_group_participant_invitation') {
            sent++;
            recovered = true;
            throw const PostgrestException(message: 'lost reply');
          }
          if (name == 'get_own_group_membership_context') {
            if (statusFails) throw const PostgrestException(message: 'offline');
            return [selfRow(member: episode)];
          }
          throw StateError(name);
        }),
      ),
      () => actor,
    );
    addTearDown(controller.dispose);
    await controller.open(capability, false);
    expect(sent, 0);
    final consent = controller.preview!.consentVersion;
    await controller.accept(
      actor,
      consentVersion: consent,
      policyAllows: () => true,
    );
    expect(sent, 1);
    available = false;
    await controller.open(capability, false);
    await controller.accept(
      actor,
      consentVersion: consent,
      policyAllows: () => true,
    );
    expect(controller.receipt, isNotNull);
    expect(controller.statusFailed, true);
    expect(controller.confirmed, false);
    statusFails = false;
    await controller.refreshStatus();
    expect(controller.confirmed, true);
    expect(sent, 1);
  });
  test('group capabilities are literal, separate and redacted through nested return URLs', () {
    for (final kind in ['join', 'invite']) {
      final path = '/$kind/group/$capability';
      expect(
        nativeProjectDestination(Uri.parse('https://planets.community$path')),
        path,
      );
      expect(authCancelDestination(path), path);
      expect(profileEditCancelDestination(path), path);
      expect(
        containsInvitationSecret(
          '/auth?returnTo=${Uri.encodeComponent(Uri.encodeComponent(path))}',
        ),
        true,
      );
      for (final suffix in ['?x=1', '#x', '/', '%2F']) {
        expect(
          nativeProjectDestination(
            Uri.parse('https://planets.community$path$suffix'),
          ),
          isNull,
        );
      }
      expect(sanitizeReturnDestination('$path?x=1'), '/');
    }
    expect(
      nativeProjectDestination(
        Uri.parse('https://elsewhere.invalid/join/group/$capability'),
      ),
      isNull,
    );
  });
}
