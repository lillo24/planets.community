import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';

void main() {
  const parser = ParticipantInvitationParser();
  final token = 'A' * 43;
  final link = {
    'invitation_id': 'link-1',
    'invite_token': token,
    'created_at': '2030-01-01T00:00:00Z',
  };
  final preview = {
    'available': true,
    'project_id': 'project-1',
    'project_kind': 'one_time',
    'project_title': 'Mural',
  };
  final receipt = {
    'project_id': 'project-1',
    'membership_id': 'member-1',
    'outcome': 'joined',
    'membership_status': 'current',
    'replayed': false,
  };
  test(
    'preview requires exactly one row and no disclosure when unavailable',
    () {
      expect(parser.preview([preview]).kind, ProjectKind.oneTime);
      expect(
        parser.preview([
          {
            'available': false,
            'project_id': null,
            'project_kind': null,
            'project_title': null,
          },
        ]).available,
        isFalse,
      );
      for (final bad in [
        [],
        [preview, preview],
        {'available': false},
        [
          {...preview, 'available': 'true'},
        ],
        [
          {...preview, 'available': false},
        ],
        [
          {...preview, 'project_kind': 'unknown'},
        ],
      ]) {
        expect(() => parser.preview(bad), throwsFormatException);
      }
    },
  );
  test('receipt parses every status and outcome, never fabricates Creator membership', () {
    for (final status in ['current', 'left', 'removed']) {
      final value = parser.admission([
        {...receipt, 'membership_status': status, 'replayed': true},
      ]);
      expect(value.status!.wireValue, status);
      expect(value.replayed, isTrue);
    }
    expect(
      parser.admission([
        {...receipt, 'outcome': 'already_joined'},
      ]).outcome,
      ParticipantAdmissionOutcome.alreadyJoined,
    );
    final creator = {
      ...receipt,
      'outcome': 'creator',
      'membership_id': null,
      'membership_status': null,
    };
    expect(parser.admission([creator]).membershipId, isNull);
    for (final bad in [
      {...receipt}..remove('replayed'),
      {...receipt, 'membership_id': null},
      {...receipt, 'membership_status': 'accepted'},
      {...receipt, 'outcome': 'creator'},
      {...creator}..remove('membership_status'),
    ]) {
      expect(() => parser.admission([bad]), throwsFormatException);
    }
  });
  test('link and bounded metadata history reject malformed contracts and expose no secret serialization', () {
    final value = parser.link([link]);
    expect(value.toString(), isNot(contains(token)));
    expect(
      () => parser.link([
        {...link, 'invite_token': 'short'},
      ]),
      throwsFormatException,
    );
    final history = {
      'invitation_id': 'link-1',
      'issued_by_profile_id': 'issuer-1',
      'created_at': '2030-01-01T00:00:00Z',
      'revoked_at': null,
      'revoked_by_profile_id': null,
      'revocation_reason': null,
    };
    expect(parser.history([history]).single.reason, isNull);
    expect(
      () => parser.history(List.filled(21, history)),
      throwsFormatException,
    );
    expect(
      () => parser.history([
        {...history, 'revocation_reason': 'expired'},
      ]),
      throwsFormatException,
    );
    expect(
      parser
          .history([
            {
              ...history,
              'revoked_at': '2030-01-02T00:00:00Z',
              'revoked_by_profile_id': 'issuer-2',
              'revocation_reason': 'replaced',
            },
          ])
          .single
          .reason,
      'replaced',
    );
  });
  test('maps canonical full/authorization/profile/input errors without raw backend messages', () {
    for (final pair in [
      ('PT409', ParticipantInviteFailure.unavailable),
      ('42501', ParticipantInviteFailure.forbidden),
      ('55000', ParticipantInviteFailure.profileRequired),
      ('22023', ParticipantInviteFailure.invalidInput),
    ]) {
      expect(
        participantInviteFailure(
          PostgrestException(message: 'Private reason', code: pair.$1),
        ),
        pair.$2,
      );
    }
    expect(
      participantInviteFailure(
        const PostgrestException(
          message: 'This Project is full.',
          code: 'PT409',
        ),
      ),
      ParticipantInviteFailure.full,
    );
    expect(
      participantInviteFailure(const FormatException('bad payload')),
      ParticipantInviteFailure.malformed,
    );
    expect(
      participantInviteFailure(const SocketException('offline')),
      ParticipantInviteFailure.network,
    );
  });
  test('real Supabase adapter sends only exact canonical RPC parameters and handles scalar revoke', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <({String name, Map<String, dynamic> body})>[];
    var currentValue = <Object?>[link];
    var chatValue = <Object?>[
      {
        'project_id': 'project-1',
        'chat_id': 'chat-1',
        'has_current_entitlement': true,
      },
    ];
    server.listen((request) async {
      final body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      final name = request.uri.pathSegments.last;
      requests.add((name: name, body: body));
      final Object response = switch (name) {
        'get_project_participant_invitation_preview' => [preview],
        'accept_project_participant_invitation' => [receipt],
        'get_current_project_participant_invitation' => currentValue,
        'create_project_participant_invitation' ||
        'regenerate_project_participant_invitation' => [link],
        'revoke_project_participant_invitation' => 'link-1',
        'list_project_participant_invitation_history' => [],
        'get_own_project_group_chat' => chatValue,
        _ => throw StateError('unexpected RPC'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    addTearDown(client.dispose);
    final gateway = SupabaseParticipantInvitationGateway(client);
    await gateway.preview(token);
    await gateway.accept('viewer', token, 'action-id');
    await gateway.create('viewer', 'project-1');
    await gateway.current('viewer', 'project-1');
    await gateway.regenerate('viewer', 'project-1');
    await gateway.revoke('viewer', 'project-1', 'link-1');
    await gateway.history(
      'viewer',
      'project-1',
      before: ParticipantLinkHistory(
        id: 'older-id',
        issuerId: 'issuer',
        createdAt: DateTime.utc(2030),
      ),
    );
    expect(await gateway.currentChat('viewer', 'project-1'), 'chat-1');
    expect(requests[0].body, {'p_token': token});
    expect(requests[1].body, {
      'p_expected_profile_id': 'viewer',
      'p_token': token,
      'p_client_action_id': 'action-id',
    });
    for (final request in requests.skip(2).take(3)) {
      expect(request.body, {
        'p_expected_profile_id': 'viewer',
        'p_project_id': 'project-1',
      });
    }
    expect(requests[5].body, {
      'p_expected_profile_id': 'viewer',
      'p_project_id': 'project-1',
      'p_invitation_id': 'link-1',
    });
    expect(requests[6].body, {
      'p_expected_profile_id': 'viewer',
      'p_project_id': 'project-1',
      'p_limit': 20,
      'p_before_created_at': '2030-01-01T00:00:00.000Z',
      'p_before_invitation_id': 'older-id',
    });
    currentValue = [];
    expect(await gateway.current('viewer', 'project-1'), isNull);
    currentValue = [link, link];
    await expectLater(
      gateway.current('viewer', 'project-1'),
      throwsFormatException,
    );
    chatValue = [
      {
        'project_id': 'project-1',
        'chat_id': 'chat-1',
        'has_current_entitlement': false,
      },
    ];
    expect(await gateway.currentChat('viewer', 'project-1'), isNull);
    chatValue = [
      {
        'project_id': 'other',
        'chat_id': 'chat-1',
        'has_current_entitlement': true,
      },
    ];
    await expectLater(
      gateway.currentChat('viewer', 'project-1'),
      throwsFormatException,
    );
  });
}
