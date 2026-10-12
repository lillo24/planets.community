import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_proposal.dart';

void main() {
  test(
    'skill RPC sends only identity, project, expected skills and new skills',
    () async {
      final client = SupabaseClient(
        'http://localhost',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/update_proposal_skills');
          expect(jsonDecode(request.body), {
            'p_expected_structural_profile_id': 'actor',
            'p_proposal_id': 'project',
            'p_expected_skills': {'skill': 'required'},
            'p_skill_ids': ['skill'],
            'p_skill_importances': ['useful'],
          });
          return http.Response('', 204, request: request);
        }),
      );
      addTearDown(client.dispose);
      await SupabaseProposalGateway(client).updateProposalSkills(
        'actor',
        'project',
        expectedSkills: {'skill': ProposalSkillImportance.required},
        skills: {'skill': ProposalSkillImportance.useful},
      );
    },
  );
  for (final preserve in [false, true]) {
    test(
      'content RPC preserveSkills=$preserve keeps draft and published contracts distinct',
      () async {
        final input = proposalInputFixture();
        final client = SupabaseClient(
          'http://localhost',
          'test-key',
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(request.url.path, '/rest/v1/rpc/update_own_proposal');
            expect(body['p_title'], input.title);
            expect(body['p_expected_creator_profile_id'], 'actor');
            expect(
              body['p_skill_ids'],
              preserve ? isNull : input.skillImportanceById.keys.toList(),
            );
            expect(
              body['p_skill_importances'],
              preserve
                  ? isNull
                  : input.skillImportanceById.values
                        .map((v) => v.wireValue)
                        .toList(),
            );
            return http.Response('', 204, request: request);
          }),
        );
        addTearDown(client.dispose);
        await SupabaseProposalGateway(client).updateOwnProposal(
          'actor',
          'project',
          input,
          preserveSkills: preserve,
        );
      },
    );
  }
}
