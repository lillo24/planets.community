import 'package:planets_mobile/core/backend/public_external_link.dart';
import 'package:planets_mobile/features/external_activities/data/external_activity_gateway.dart';
import 'package:planets_mobile/features/external_activities/domain/external_activity.dart';

const externalActivityFixtureId = 'a9530000-0000-4000-8000-000000000001';

Map<String, dynamic> externalActivityPayload({bool stale = false}) => {
  'id': externalActivityFixtureId,
  'title': 'Synthetic cultural exhibition about sport',
  'description':
      'A synthetic description. No booking or availability is inferred.',
  'category': 'culture',
  'status': 'scheduled',
  'canonical_url': 'https://calendar.example.org/events/synthetic',
  'source_categories': ['Exhibition'],
  'observed_at': stale ? '2026-10-17T12:00:00Z' : '2026-10-21T12:00:00Z',
  'stale': stale,
  'next_at': '2026-10-24T08:00:00Z',
  'occurrences': [
    {
      'kind': 'timed',
      'start': '2026-10-24T10:00:00+02:00',
      'end': '2026-10-24T11:00:00+02:00',
      'timezone': 'Europe/Rome',
    },
    {
      'kind': 'timed',
      'start': '2026-10-31T10:00:00+01:00',
      'end': '2026-10-31T11:00:00+01:00',
      'timezone': 'Europe/Rome',
    },
  ],
  'source': {
    'id': 'synthetic',
    'name': 'Synthetic calendar',
    'attribution': 'Synthetic fixture attribution',
    'license_url': 'https://calendar.example.org/license',
  },
  'city': 'Trento',
  'venue': 'Synthetic hall',
};

ExternalActivityPage externalPageFixture({
  List<ExternalActivity> items = const [],
  ExternalCatalogueHealth health = ExternalCatalogueHealth.unconfigured,
  List<String> disciplines = const [],
  Map<String, dynamic>? cursor,
}) => ExternalActivityPage(
  health: health,
  asOf: DateTime.utc(2026, 10, 21, 12),
  items: items,
  disciplines: disciplines,
  nextCursor: cursor,
);

class FakeExternalActivityGateway implements ExternalActivityGateway {
  ExternalActivityPage page = externalPageFixture();
  ExternalActivity? detail;
  Object? error, detailError;
  final calls = <ExternalActivityFilter>[];
  final cursors = <Map<String, dynamic>?>[];
  final detailCalls = <String>[];
  Future<ExternalActivityPage> Function(
    ExternalActivityFilter,
    Map<String, dynamic>?,
  )?
  onList;

  @override
  Future<ExternalActivityPage> list(
    ExternalActivityFilter filter, {
    Map<String, dynamic>? cursor,
  }) async {
    calls.add(filter);
    cursors.add(cursor);
    if (error != null) throw error!;
    return onList == null ? page : onList!(filter, cursor);
  }

  @override
  Future<ExternalActivity?> get(String id) async {
    detailCalls.add(id);
    if (detailError != null) throw detailError!;
    return detail;
  }
}

class FakePublicExternalLinkLauncher implements PublicExternalLinkLauncher {
  bool result = true;
  final links = <PublicExternalLink>[];
  @override
  Future<bool> open(PublicExternalLink link) async {
    links.add(link);
    return result;
  }
}
