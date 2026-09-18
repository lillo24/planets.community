import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_chat/domain/project_needs_models.dart';

void main() {
  const parser = ProjectNeedsPayloadParser();

  test('strictly parses skill and resource coverage rows', () {
    final skill = parser.requirement(_coverageRow());
    final resource = parser.requirement({
      ..._coverageRow(),
      'requirement_kind': 'resource',
      'requirement_id': 'resource-1',
      'importance': null,
    });

    expect(skill.kind, ProjectRequirementKind.skill);
    expect(skill.importance, ProjectRequirementImportance.required);
    expect(resource.kind, ProjectRequirementKind.resource);
    expect(resource.importance, isNull);
  });

  test('rejects unknown or discriminator-inconsistent coverage', () {
    expect(
      () => parser.requirement({..._coverageRow(), 'requirement_kind': 'tool'}),
      throwsFormatException,
    );
    expect(
      () => parser.requirement({..._coverageRow(), 'importance': null}),
      throwsFormatException,
    );
    expect(
      () => parser.requirement({..._coverageRow(), 'extra': true}),
      throwsFormatException,
    );
  });

  test('attention requires a complete explicit unseen frontier', () {
    final unseen = parser.attention({
      'chat_id': 'chat-1',
      'has_unseen_resurfaced_need': true,
      'latest_unseen_event_id': 'event-1',
      'latest_unseen_event_at': '2026-09-18T12:00:00Z',
    });
    final seen = parser.attention({
      'chat_id': 'chat-1',
      'has_unseen_resurfaced_need': false,
      'latest_unseen_event_id': null,
      'latest_unseen_event_at': null,
    });

    expect(unseen.latestUnseenEventId, 'event-1');
    expect(seen.hasUnseenResurfacedNeed, isFalse);
    expect(
      () => parser.attention({
        'chat_id': 'chat-1',
        'has_unseen_resurfaced_need': true,
        'latest_unseen_event_id': null,
        'latest_unseen_event_at': null,
      }),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _coverageRow() => {
  'requirement_kind': 'skill',
  'requirement_id': 'skill-1',
  'label': 'Painting',
  'importance': 'required',
  'is_covered': false,
  'viewer_is_covering': false,
  'is_manually_covered': false,
};
