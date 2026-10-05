import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/domain/template_models.dart';

const templateActor = '11111111-1111-4111-8111-111111111111';
const templateId = '22222222-2222-4222-8222-222222222222';
const templateSource = '33333333-3333-4333-8333-333333333333';
const templateDestination = '44444444-4444-4444-8444-444444444444';
final templateToken = 'tw01:${List.filled(64, 'a').join()}';
String needId(int index) =>
    '55555555-5555-4555-8555-${index.toString().padLeft(12, '0')}';
TemplateDetail templateDetailFixture({
  String? token,
  int count = 0,
  int? capacity = 8,
  String? creator,
}) => TemplateDetail(
  id: templateId,
  sourceId: templateSource,
  token: token ?? templateToken,
  title: 'Completed garden idea',
  summary: 'Reusable summary',
  description: 'Reusable description',
  skills: const [],
  creatorId: templateActor,
  creatorName: creator,
  durationSeconds: 7200.125,
  blueprintCount: count,
  capacity: capacity,
);
TemplateCard templateCardFixture({String id = templateId}) => TemplateCard(
  id: id,
  sourceId: templateSource,
  linkedAt: DateTime.utc(2026, 1, 1),
  title: 'Completed garden idea',
  summary: 'Reusable summary',
  skills: const [],
  creatorId: templateActor,
);
TemplateReceipt templateReceiptFixture(TemplateAttempt a) => TemplateReceipt(
  requestId: a.requestId,
  destinationId: templateDestination,
  templateId: a.templateId,
  sourceId: templateSource,
  token: a.token,
  prefillCapacity: a.prefillCapacity,
  durationSeconds: 7200.125,
  acceptedAt: DateTime.utc(2026, 10, 5),
  capacity: 8,
);
Map<String, dynamic> templateRowFixture() => {
  'template_id': templateId,
  'source_proposal_id': templateSource,
  'linked_at': '2026-01-01T00:00:00.123456Z',
  'content_version': templateToken,
  'original_creator_profile_id': templateActor,
  'creator_display_name': null,
  'title': 'Completed garden idea',
  'summary': 'Reusable summary',
  'description': 'Reusable description',
  'skills': <dynamic>[],
  'cover_object_path': null,
  'registration_capacity_recommendation': 8,
  'duration_seconds': 7200.125,
  'resource_blueprint_count': 51,
};

class FakeTemplateGateway implements TemplateGateway {
  List<TemplateCard> cards = [templateCardFixture()];
  TemplateDetail? value = templateDetailFixture();
  Object? listError, detailError, pageError, applyError, recoverError;
  Future<List<TemplateCard>> Function(TemplateCursor?, String?, Set<String>?)?
  listLoader;
  Future<TemplateDetail?> Function()? detailLoader;
  Future<List<TemplateBlueprint>> Function(String, String?)? pageLoader;
  Future<TemplateReceipt> Function(TemplateAttempt)? applyLoader;
  TemplateReceipt? recovered;
  final calls = <String>[];
  final commands = <TemplateAttempt>[];
  final cursors = <TemplateCursor?>[];
  final pageTokens = <String>[];
  @override
  Future<List<TemplateCard>> list({
    TemplateCursor? cursor,
    String? query,
    Set<String>? skills,
  }) async {
    calls.add('list');
    cursors.add(cursor);
    if (listError case final e?) throw e;
    return listLoader == null
        ? cards
        : await listLoader!(cursor, query, skills);
  }

  @override
  Future<TemplateDetail?> detail(String id) async {
    calls.add('detail');
    if (detailError case final e?) throw e;
    return detailLoader == null ? value : await detailLoader!();
  }

  @override
  Future<List<TemplateBlueprint>> blueprints(
    String id,
    String token, {
    String? cursor,
  }) async {
    calls.add('page');
    pageTokens.add(token);
    if (pageError case final e?) throw e;
    return pageLoader == null ? const [] : await pageLoader!(token, cursor);
  }

  @override
  Future<TemplateReceipt> apply(TemplateAttempt a) async {
    calls.add('apply');
    commands.add(a);
    if (applyError case final e?) throw e;
    return applyLoader == null
        ? templateReceiptFixture(a)
        : await applyLoader!(a);
  }

  @override
  Future<TemplateReceipt?> recover(TemplateAttempt a) async {
    calls.add('recover');
    if (recoverError case final e?) throw e;
    return recovered;
  }
}
