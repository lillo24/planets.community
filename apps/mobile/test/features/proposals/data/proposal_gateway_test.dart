import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';

void main() {
  const parser = ProposalPayloadParser();

  test('Idea detail keeps undecided logistics and rejects event status', () {
    final row = {
      ..._publicDetailRow(),
      'definition_phase': 'idea',
      'starts_at': null,
      'ends_at': null,
      'event_timezone': null,
      'country_code': null,
      'locality': null,
      'public_location_label': null,
      'derived_status': null,
      'description': null,
    };
    final detail = parser.publicDetail(row, _capacity);
    expect(detail.summary.isIdea, isTrue);
    expect(detail.summary.startsAt, isNull);
    expect(detail.summary.locality, isNull);
    expect(detail.summary.status, isNull);
    expect(detail.description, isNull);
    expect(
      () => parser.publicDetail({
        ...row,
        'derived_status': 'completed',
      }, _capacity),
      throwsFormatException,
    );
    expect(
      () => parser.publicDetail({
        ...row,
        'definition_phase': 'defined',
      }, _capacity),
      throwsFormatException,
    );
    expect(
      () => parser.publicDetail({
        ...row,
        'definition_phase': 'unknown',
      }, _capacity),
      throwsFormatException,
    );
  });

  test('parses the seeded restricted public Proposal detail shape', () {
    final detail = parser.publicDetail(_publicDetailRow(), _capacity);

    expect(detail.summary.id, _proposalId);
    expect(detail.summary.title, 'DEMO · Riverside mural');
    expect(detail.summary.status, ProposalStatus.upcoming);
    expect(detail.summary.skills, hasLength(2));
    expect(detail.summary.skills.map((skill) => skill.importance), [
      ProposalSkillImportance.required,
      ProposalSkillImportance.useful,
    ]);
    expect(detail.creatorProfileId, _creatorProfileId);
    expect(detail.creatorDisplayName, 'Demo Alice');
    expect(detail.exactMeetingText, isNull);
    expect(detail.exactLocationRestricted, isTrue);
  });

  test('parses public exact location and historical status', () {
    final detail = parser.publicDetail({
      ..._publicDetailRow(),
      'derived_status': 'just_finished',
      'exact_meeting_text': 'Demo civic courtyard, Piazza Aperta 4',
      'exact_location_restricted': false,
    }, _capacity);

    expect(detail.summary.status, ProposalStatus.justFinished);
    expect(detail.exactMeetingText, 'Demo civic courtyard, Piazza Aperta 4');
    expect(detail.exactLocationRestricted, isFalse);
  });

  test('reports contract drift with the failing field', () {
    expect(
      () => parser.publicDetail({
        ..._publicDetailRow(),
        'exact_location_restricted': null,
      }, _capacity),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('exact_location_restricted'),
        ),
      ),
    );
    expect(
      () =>
          parser.publicDetail({..._publicDetailRow(), 'skills': {}}, _capacity),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('skills'),
        ),
      ),
    );
  });
}

const _proposalId = '3ab6fc1a-03e9-4d4a-9a3b-d7ab19670e29';
const _creatorProfileId = '43036e28-e46c-417f-bbcb-27e04de2d0f1';
const _capacity = ProjectCapacitySnapshot(
  registrationCapacity: 20,
  countOrganizersTowardCapacity: false,
  currentParticipantCount: 2,
  ordinaryParticipantCount: 2,
  organizerCount: 1,
  capacityUsedCount: 2,
  socialPeopleCount: 3,
  spotsRemaining: 18,
  isFull: false,
);

Map<String, dynamic> _publicDetailRow() => {
  'definition_phase': 'defined',
  'proposal_id': _proposalId,
  'creator_profile_id': _creatorProfileId,
  'creator_display_name': 'Demo Alice',
  'title': 'DEMO · Riverside mural',
  'summary': 'Paint a bright riverside mural with neighbors.',
  'description':
      'Plan the composition, prepare the wall, and paint a shared local story.',
  'starts_at': '2026-09-27T21:35:00+00:00',
  'ends_at': '2026-09-28T01:35:00+00:00',
  'event_timezone': 'Europe/Rome',
  'country_code': 'IT',
  'locality': 'Trento',
  'administrative_area': 'Povo',
  'public_location_label': 'Trento · Povo',
  'derived_status': 'upcoming',
  'skills': [
    {
      'id': 'd0000000-0000-4000-8001-000000000001',
      'slug': 'mural-painting',
      'label': 'Mural painting',
      'importance': 'required',
      'category_id': 'c0000000-0000-4000-8000-000000000001',
      'category_slug': 'art-creativity',
      'category_label': 'Art & Creativity',
    },
    {
      'id': 'd0000000-0000-4000-8007-000000000001',
      'slug': 'event-organization',
      'label': 'Event organization',
      'importance': 'useful',
      'category_id': 'c0000000-0000-4000-8000-000000000007',
      'category_slug': 'organization-community',
      'category_label': 'Organization & Community',
    },
  ],
  'exact_meeting_text': null,
  'exact_location_restricted': true,
};
