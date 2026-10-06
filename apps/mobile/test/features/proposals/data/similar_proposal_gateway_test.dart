import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/data/similar_proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/similar_proposal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_similar_proposal.dart';

void main() {
  test('exact authenticated read input; normalized set, optional hints, bound exclusion', () async {
    String? name;
    Map<String, dynamic>? capturedParams;
    final gateway = SupabaseSimilarProposalGateway.withRpc((
      n, {
      required params,
    }) async {
      name = n;
      capturedParams = params;
      return [similarRow()];
    });
    final query = SimilarProposalQuery.fromForm(
      actorId: 'actor',
      title: ' Repair Café di quartiere ',
      skillIds: [similarSkillId, similarSkillId],
      country: ' it ',
      locality: '  Trento  ',
      excludedProposalId: similarId,
    )!;
    final rows = await gateway.lookup(query);
    expect(name, 'list_similar_active_proposals');
    expect(capturedParams, {
      'p_expected_profile_id': 'actor',
      'p_title': ' Repair Café di quartiere ',
      'p_skill_ids': [similarSkillId],
      'p_country_code': 'IT',
      'p_locality': 'trento',
      'p_excluded_proposal_id': similarId,
      'p_limit': 5,
    });
    expect(rows.single.coverObjectPath, isNull);
    expect(rows.single.administrativeArea, isNull);
    expect(rows.single.availability, SimilarAvailability.available);
  });
  test('invalid optional geography is omitted without truncating or changing the raw idea', () {
    final query = SimilarProposalQuery.fromForm(
      actorId: 'actor',
      title: 'murale',
      skillIds: [],
      country: 'ITA',
      locality: 'x' * 121,
      excludedProposalId: null,
    )!;
    expect(query.countryCode, isNull);
    expect(query.locality, isNull);
    expect(query.title, 'murale');
    for (final title in ['', '  ', 'x' * 101]) {
      expect(
        SimilarProposalQuery.fromForm(
          actorId: 'actor',
          title: title,
          skillIds: [],
          country: '',
          locality: '',
          excludedProposalId: null,
        ),
        isNull,
      );
    }
  });
  test(
    'raw bounds before normalization and deterministic selected-set identity',
    () {
      final a = SimilarProposalQuery(
        actorId: 'actor',
        title: 'x' * 100,
        skillIds: ['b', 'a', 'a'],
      );
      final b = SimilarProposalQuery(
        actorId: 'actor',
        title: 'x' * 100,
        skillIds: ['a', 'b'],
      );
      expect(a.sameAs(b), isTrue);
      expect(a.skillIds, ['a', 'b']);
      expect(
        () => SimilarProposalQuery(actorId: 'actor', title: 'x' * 101),
        throwsFormatException,
      );
      expect(
        () => SimilarProposalQuery(
          actorId: 'actor',
          title: 'x',
          skillIds: List.filled(51, 'a'),
        ),
        throwsFormatException,
      );
      expect(
        SimilarProposalQuery(
          actorId: 'actor',
          title: '🌻' * 100,
        ).title.runes.length,
        100,
      );
    },
  );
  for (final entry in {
    'available': SimilarAvailability.available,
    'full': SimilarAvailability.full,
    'capacity_unknown': SimilarAvailability.capacityUnknown,
  }.entries) {
    test('explicit availability ${entry.key}, with no invented counts', () {
      expect(
        parseSimilarProposal({...similarRow(), 'availability': entry.key})
            .availability,
        entry.value,
      );
    });
  }
  test('legitimate empty is distinct from transport/auth errors', () async {
    final empty = SupabaseSimilarProposalGateway.withRpc(
      (_, {required params}) async => [],
    );
    expect(
      await empty.lookup(
        SimilarProposalQuery(actorId: 'actor', title: 'repair'),
      ),
      isEmpty,
    );
    final error = SupabaseSimilarProposalGateway.withRpc((
      _, {
      required params,
    }) async {
      throw const PostgrestException(
        message: 'Synthetic denial',
        code: '42501',
      );
    });
    await expectLater(
      error.lookup(SimilarProposalQuery(actorId: 'actor', title: 'repair')),
      throwsA(isA<PostgrestException>()),
    );
  });
  test('canonical public cover remains bound to the preview Project', () {
    const path = '$similarSkillId/projects/$similarId/$similarSkillId.webp';
    expect(
      parseSimilarProposal({...similarRow(), 'cover_object_path': path})
          .coverObjectPath,
      path,
    );
    expect(
      () => parseSimilarProposal({
        ...similarRow(),
        'cover_object_path': path.replaceFirst(
          '/$similarId/',
          '/$similarSkillId/',
        ),
      }),
      throwsFormatException,
    );
  });
  for (final entry in <String, dynamic>{
    'derived_status': 'happening',
    'availability': 'maybe',
    'title_evidence': '99%',
    'location_relation': 'near',
    'starts_at': 'tomorrow',
    'ends_at': '2090-01-01T00:00:00Z',
    'event_timezone': 'Unknown/Zone',
    'proposal_id': 'invalid',
    'shared_skill_ids': [null],
    'cover_object_path': 'foreign/private.webp',
    'administrative_area': 3,
    'summary': null,
  }.entries) {
    test('malformed ${entry.key} fails explicitly', () {
      expect(
        () => parseSimilarProposal({...similarRow(), entry.key: entry.value}),
        throwsFormatException,
      );
    });
  }
  test(
    'unrequested private field and missing public field are contract errors',
    () {
      expect(
        () => parseSimilarProposal({
          ...similarRow(),
          'exact_meeting_text': 'private',
        }),
        throwsFormatException,
      );
      expect(
        () => parseSimilarProposal(similarRow()..remove('cover_object_path')),
        throwsFormatException,
      );
    },
  );
  for (final entry in <dynamic>[
    {},
    [null],
    List.filled(6, similarRow()),
    [similarRow(), similarRow()],
  ].asMap().entries) {
    test(
      'malformed/unbounded/repeated RPC list fails (${entry.key})',
      () async {
        final gateway = SupabaseSimilarProposalGateway.withRpc(
          (_, {required params}) async => entry.value,
        );
        await expectLater(
          gateway.lookup(
            SimilarProposalQuery(actorId: 'actor', title: 'repair'),
          ),
          throwsFormatException,
        );
      },
    );
  }
}
