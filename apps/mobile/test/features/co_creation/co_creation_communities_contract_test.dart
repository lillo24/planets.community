import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_communities_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_communities.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';

import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_recruitment_test.dart' as c;

const proposalId = 'ce010000-0000-4000-8000-000000000001';
Map<String, Object?> proposal({String state = 'pending', int count = 2}) => {
  'proposal_id': proposalId,
  'category_id': 'videogames',
  'name': 'Valorant',
  'locality': 'Trento',
  'explanation': 'Meet people who play together.',
  'state': state,
  'interested_count': count,
  'activation_threshold': 3,
  'hub_id': state == 'activated' ? f.hub : null,
  'version': 1,
  'created_at': '2026-10-23T09:00:00Z',
  'expires_at': '2026-11-22T09:00:00Z',
};
void main() {
  test('proposal count is distinct from room occupancy and preserves typed activation', () {
    final p = CoCommunityProposal.parse(proposal());
    expect(p.interested, 2);
    expect(p.threshold, 3);
    expect(p.hub, isNull);
    expect(
      CoCommunityProposal.parse(proposal(state: 'activated', count: 3))
          .hub!
          .value,
      f.hub,
    );
    for (final extra in <Map<String, Object?>>[
      {
        'supporters': [f.a],
      },
      {'proposer_id': f.a},
      {'hub_id': f.hub},
      {'activation_threshold': 2},
      {'state': 'activated'},
      {'interested_count': -1},
      {'created_at': '2026-02-30T09:00:00Z'},
    ]) {
      expect(
        () => CoCommunityProposal.parse({...proposal(), ...extra}),
        throwsFormatException,
        reason: extra.toString(),
      );
    }
  });
  test('scheduled cards reject missing time, private extras and impossible meeting lifetimes', () {
    final scheduled = {
      ...c.card(),
      'meeting_id': proposalId,
      'starts_at': '2026-11-02T19:30:00Z',
    };
    expect(
      CoRecruitment.parse(scheduled).startsAt,
      DateTime.utc(2026, 11, 2, 19, 30),
    );
    for (final extra in <Map<String, Object?>>[
      {'starts_at': null},
      {'meeting_id': null},
      {'starts_at': '2026-11-02T19:30:00'},
      {'starts_at': '2026-10-25T19:30:00Z'},
      {
        'attendees': [f.a],
      },
    ]) {
      expect(
        () => CoRecruitment.parse({...scheduled, ...extra}),
        throwsFormatException,
      );
    }
  });
  test('category and page parsers reject foreign scope, duplicates and reversed cursors', () async {
    final entry = {
      'category_id': 'videogames',
      'kind': 'proposal',
      'hub': null,
      'proposal': proposal(),
    };
    expect(
      () => CoCommunityEntry.parse(entry, 'concerts'),
      throwsFormatException,
    );
    for (final rows in [
      [entry, entry],
      [
        {...entry, 'category_id': 'concerts'},
      ],
    ]) {
      await expectLater(
        CoCreationCommunitiesGateway((_, _) async => rows)
            .communities('videogames'),
        throwsFormatException,
      );
    }
    await expectLater(
      CoCreationCommunitiesGateway(
        (_, _) async => {...proposal(), 'proposal_id': f.a},
      ).proposal(proposalId),
      throwsFormatException,
    );
  });
  test(
    'own invitations require an activated hub and current explicit interest',
    () {
      expect(
        CoOwnCommunityInterest.parse({
          'proposal': proposal(state: 'activated', count: 3),
          'is_proposer': false,
          'interested': true,
          'ready_to_join': true,
        }).ready,
        isTrue,
      );
      expect(
        () => CoOwnCommunityInterest.parse({
          'proposal': proposal(),
          'is_proposer': false,
          'interested': true,
          'ready_to_join': true,
        }),
        throwsFormatException,
      );
    },
  );
}
