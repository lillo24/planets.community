import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';

void main() {
  test('same browser account rediscovers membership/chat after original link revocation', () async {
    final fixture = jsonDecode(
      File('config/local.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final url = fixture['SUPABASE_URL'] as String;
    if (url != 'http://127.0.0.1:58721') {
      throw StateError(
        'PI04 rediscovery requires its disposable loopback backend.',
      );
    }
    final participant = fixture['PI04_PARTICIPANT'] as String;
    final project = fixture['PI04_PROPOSAL'] as String;
    final client = SupabaseClient(
      url,
      fixture['SUPABASE_PUBLISHABLE_KEY'] as String,
      accessToken: () async => fixture['PI04_ACCESS_TOKEN'] as String,
    );
    addTearDown(client.dispose);
    final participation = SupabaseParticipationGateway(client);
    final invitations = SupabaseParticipantInvitationGateway(client);
    final before = await participation.listOwnMemberships(participant);
    final current = before
        .where(
          (m) => m.projectId == project && m.status == MembershipStatus.current,
        )
        .single;
    expect(await invitations.currentChat(participant, project), isNotNull);
    expect(
      (await invitations.preview(fixture['PI04_PROPOSAL_TOKEN'] as String))
          .available,
      isFalse,
    );
    // Token-free rediscovery is an own read, with no accept/action UUID/re-entry.
    final after = await participation.listOwnMemberships(participant);
    expect(after.where((m) => m.projectId == project).single.id, current.id);
    final anonymous = SupabaseClient(
      url,
      fixture['SUPABASE_PUBLISHABLE_KEY'] as String,
    );
    addTearDown(anonymous.dispose);
    await expectLater(
      SupabaseParticipationGateway(anonymous).listOwnMemberships(participant),
      throwsA(isA<PostgrestException>()),
    );
  }, skip: !const bool.fromEnvironment('PI04_LOCAL_REHEARSAL'));
}
