import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/data/participant_invitation_gateway.dart';
import 'package:planets_mobile/features/project_participant_invites/domain/participant_invitation_models.dart';

void main() {
  test('PI02 adapters exercise photo-free admission and recovery against local PI01', () async {
    final fixture = jsonDecode(
      File('config/pi02-smoke.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final url = fixture['apiUrl'] as String;
    if (Uri.parse(url).host != '127.0.0.1') {
      throw StateError('Only disposable loopback backend is allowed.');
    }
    final manager = fixture['manager'] as String;
    final participant = fixture['participant'] as String;
    final project = fixture['project'] as String;
    SupabaseClient client(String role) => SupabaseClient(
      url,
      fixture['key'] as String,
      accessToken: () async => fixture['${role}Token'] as String,
    );
    final ownerClient = client('manager');
    final memberClient = client('participant');
    final anonymous = SupabaseClient(url, fixture['key'] as String);
    addTearDown(ownerClient.dispose);
    addTearDown(memberClient.dispose);
    addTearDown(anonymous.dispose);
    final owner = SupabaseParticipantInvitationGateway(ownerClient);
    final member = SupabaseParticipantInvitationGateway(memberClient);
    final link = await owner.create(manager, project);
    expect((await owner.create(manager, project)).id, link.id);
    expect(
      (await SupabaseParticipantInvitationGateway(anonymous)
              .preview(link.token))
          .title,
      'PI02 local mural',
    );
    const action = '55000000-0000-4000-8000-000000000006';
    final receipt = await member.accept(participant, link.token, action);
    expect(receipt.outcome, ParticipantAdmissionOutcome.joined);
    final participation = SupabaseParticipationGateway(memberClient);
    expect(
      (await participation.listOwnMemberships(participant))
          .where((m) => m.projectId == project)
          .length,
      1,
    );
    final requests = await participation.listOwnJoinRequests(participant);
    expect(requests.single.id, fixture['request']);
    expect(requests.single.status.wireValue, 'withdrawn');
    expect(await member.currentChat(participant, project), isNotNull);
    await owner.revoke(manager, project, link.id);
    expect((await member.preview(link.token)).available, isFalse);
    final replay = await member.accept(participant, link.token, action);
    expect(replay.replayed, isTrue);
    expect(replay.membershipId, receipt.membershipId);
    expect(await owner.current(manager, project), isNull);
    expect((await owner.history(manager, project)).single.reason, 'revoked');
  }, skip: !const bool.fromEnvironment('PI02_LOCAL_SMOKE'));
}
