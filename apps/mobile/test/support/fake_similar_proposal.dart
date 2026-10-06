import 'package:planets_mobile/features/proposals/data/similar_proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/similar_proposal.dart';

const similarId = 'e6000000-0000-4000-8000-000000000001';
const similarSkillId = 'e6000000-0000-4000-8000-000000000002';

class FakeSimilarProposalGateway implements SimilarProposalGateway {
  final calls = <SimilarProposalQuery>[];
  List<SimilarProposal> items = [];
  Object? error;
  Future<List<SimilarProposal>> Function(SimilarProposalQuery)? loader;
  @override
  Future<List<SimilarProposal>> lookup(SimilarProposalQuery query) async {
    calls.add(query);
    if (loader != null) return loader!(query);
    if (error != null) throw error!;
    return items;
  }
}

SimilarProposal similarFixture({
  String id = similarId,
  String title = 'Repair Café del sabato',
  SimilarAvailability availability = SimilarAvailability.available,
}) => SimilarProposal(
  id: id,
  title: title,
  summary: 'Public activity preview',
  startsAt: DateTime.utc(2098, 3, 1, 10),
  endsAt: DateTime.utc(2098, 3, 1, 12),
  eventTimezone: 'Europe/Rome',
  countryCode: 'IT',
  locality: 'Trento',
  administrativeArea: null,
  publicLocationLabel: 'Public rough area',
  coverObjectPath: null,
  availability: availability,
  titleEvidence: SimilarTitleEvidence.titleTopic,
  sharedSkillIds: const [],
  locationRelation: SimilarLocationRelation.sameLocality,
);

Map<String, dynamic> similarRow() => {
  'proposal_id': similarId,
  'cover_object_path': null,
  'title': 'Repair Café del sabato',
  'summary': 'Public activity preview',
  'starts_at': '2098-03-01T10:00:00Z',
  'ends_at': '2098-03-01T12:00:00Z',
  'event_timezone': 'Europe/Rome',
  'country_code': 'IT',
  'locality': 'Trento',
  'administrative_area': null,
  'public_location_label': 'Public rough area',
  'derived_status': 'upcoming',
  'availability': 'available',
  'title_evidence': 'title_topic',
  'shared_skill_ids': <String>[],
  'location_relation': 'same_locality',
};
