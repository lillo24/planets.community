import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';

void main() {
  const parser = MessagesPayloadParser();

  test('strictly parses skill and resource contribution selections', () {
    final skill = parser.contributionSelection({
      'selection_kind': 'skill',
      'selection_id': 'skill-1',
      'label': 'Carpentry',
    });
    final resource = parser.contributionSelection({
      'selection_kind': 'resource',
      'selection_id': 'need-1',
      'label': 'Wooden boards',
    });

    expect(skill.kind, RequestContributionSelectionKind.skill);
    expect(resource.kind, RequestContributionSelectionKind.resource);
    expect(resource.label, 'Wooden boards');
  });

  test('unknown selection kinds and malformed rows fail safely', () {
    expect(
      () => parser.contributionSelection({
        'selection_kind': 'free_text',
        'selection_id': 'selection-1',
        'label': 'Anything',
      }),
      throwsFormatException,
    );
    expect(() => parser.contributionSelection([]), throwsFormatException);
  });

  test('Messages selection source calls only the authorized B1 RPC', () {
    final source = File('lib/features/messages/data/messages_gateway.dart')
        .readAsStringSync();
    expect(
      source,
      contains("'list_own_project_join_request_contribution_selections'"),
    );
    expect(
      source,
      isNot(contains(".from('project_join_request_skill_selections')")),
    );
    expect(
      source,
      isNot(contains(".from('project_join_request_resource_selections')")),
    );
  });
}
