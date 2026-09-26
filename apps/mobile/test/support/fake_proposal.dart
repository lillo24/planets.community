import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

typedef RequestedProposalLoader =
    Future<List<RequestedProposalSummary>> Function(
      String expectedProfileId, {
      String? query,
      String? locality,
      Set<String>? skillIds,
    });

typedef PublicProposalLoader = Future<List<ProposalSummary>> Function({
  required int limit,
  ProposalCursor? cursor,
  String? query,
  String? locality,
  Set<String>? skillIds,
});

class FakeProposalGateway implements ProposalGateway {
  List<ProposalSkillCategory> categories = proposalCategoriesFixture();
  List<ProposalSummary> publicItems = [];
  List<RequestedProposalSummary> requestedItems = [];
  ProposalDetail? publicDetail;
  Future<ProposalDetail?>? publicDetailResult;
  List<OwnProposal> ownItems = [];
  Object? error;
  Object? requestedError;
  RequestedProposalLoader? requestedLoader;
  PublicProposalLoader? publicLoader;
  Future<void>? mutationDelay;
  Future<List<OwnProposal>>? ownListResult;
  Future<OwnProposal?>? ownResult;
  final List<String> calls = [];
  String? lastExpectedIdentity;
  ProposalInput? lastInput;
  ProposalCursor? lastCursor;
  String? lastQuery;
  String? lastLocality;
  Set<String>? lastSkillIds;
  String? lastRequestedIdentity;
  String? lastRequestedQuery;
  String? lastRequestedLocality;
  Set<String>? lastRequestedSkillIds;

  @override
  Future<List<ProposalSkillCategory>> loadSkillCatalog() async {
    _throwIfNeeded();
    return categories;
  }

  @override
  Future<List<ProposalSummary>> listPublicProposals({
    required int limit,
    ProposalCursor? cursor,
    String? query,
    String? locality,
    Set<String>? skillIds,
  }) async {
    _throwIfNeeded();
    calls.add('list-public');
    lastCursor = cursor;
    lastQuery = query;
    lastLocality = locality;
    lastSkillIds = skillIds;
    if (publicLoader case final loader?) {
      return loader(
        limit: limit,
        cursor: cursor,
        query: query,
        locality: locality,
        skillIds: skillIds,
      );
    }
    return publicItems.take(limit).toList();
  }

  @override
  Future<List<RequestedProposalSummary>> listOwnPendingRequestedProposals(
    String expectedProfileId, {
    String? query,
    String? locality,
    Set<String>? skillIds,
  }) async {
    calls.add('list-requested');
    lastRequestedIdentity = expectedProfileId;
    lastRequestedQuery = query;
    lastRequestedLocality = locality;
    lastRequestedSkillIds = skillIds;
    if (requestedError case final failure?) throw failure;
    if (requestedLoader case final loader?) {
      return loader(
        expectedProfileId,
        query: query,
        locality: locality,
        skillIds: skillIds,
      );
    }
    return requestedItems;
  }

  @override
  Future<ProposalDetail?> getPublicProposal(String proposalId) async {
    _throwIfNeeded();
    calls.add('public-detail:$proposalId');
    return publicDetailResult ?? publicDetail;
  }

  @override
  Future<List<OwnProposal>> listOwnProposals(String expectedCreatorId) async {
    _throwIfNeeded();
    lastExpectedIdentity = expectedCreatorId;
    return ownListResult ?? Future.value(ownItems);
  }

  @override
  Future<OwnProposal?> getOwnProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    _throwIfNeeded();
    lastExpectedIdentity = expectedCreatorId;
    return ownResult ??
        Future.value(
          ownItems.where((item) => item.id == proposalId).firstOrNull,
        );
  }

  @override
  Future<String> createDraft(
    String expectedCreatorId,
    ProposalInput input,
  ) async {
    _throwIfNeeded();
    calls.add('create');
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    lastInput = input;
    ownItems = [ownProposalFixture(id: 'new-draft', input: input), ...ownItems];
    return 'new-draft';
  }

  @override
  Future<void> updateOwnProposal(
    String expectedCreatorId,
    String proposalId,
    ProposalInput input,
  ) async {
    _throwIfNeeded();
    calls.add('update:$proposalId');
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    lastInput = input;
  }

  @override
  Future<void> publishProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    _throwIfNeeded();
    calls.add('publish:$proposalId');
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
  }

  @override
  Future<void> cancelProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    _throwIfNeeded();
    calls.add('cancel:$proposalId');
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
  }

  void _throwIfNeeded() {
    if (error case final failure?) throw failure;
  }
}

List<ProposalSkillCategory> proposalCategoriesFixture() => const [
  ProposalSkillCategory(
    id: 'category-art',
    slug: 'art',
    label: 'Art',
    sortOrder: 1,
    skills: [
      ProposalCatalogSkill(
        id: 'skill-mural',
        categoryId: 'category-art',
        slug: 'mural',
        label: 'Mural painting',
        sortOrder: 1,
      ),
    ],
  ),
];

ProposalSummary proposalSummaryFixture({
  String id = 'proposal-1',
  ProposalStatus status = ProposalStatus.upcoming,
  List<ProposalSkill>? skills,
}) => ProposalSummary(
  id: id,
  title: 'Paint the square',
  summary: 'Create a community mural together.',
  startsAt: DateTime.utc(2026, 9, 10, 10),
  endsAt: DateTime.utc(2026, 9, 10, 12),
  eventTimezone: 'Europe/Rome',
  countryCode: 'IT',
  locality: 'Bologna',
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: 'Central Bologna',
  status: status,
  skills:
      skills ??
      const [
        ProposalSkill(
          id: 'skill-mural',
          slug: 'mural',
          label: 'Mural painting',
          categoryId: 'category-art',
          categorySlug: 'art',
          categoryLabel: 'Art',
          importance: ProposalSkillImportance.required,
        ),
      ],
);

RequestedProposalSummary requestedProposalFixture({
  String requestId = 'request-1',
  String proposalId = 'proposal-1',
  DateTime? requestCreatedAt,
}) => RequestedProposalSummary(
  requestId: requestId,
  requestCreatedAt: requestCreatedAt ?? DateTime.utc(2026, 9, 4, 12),
  proposal: proposalSummaryFixture(id: proposalId),
);

ProposalDetail proposalDetailFixture({
  bool restricted = true,
  ProposalStatus status = ProposalStatus.upcoming,
  List<ProposalSkill>? skills,
  String creatorProfileId = 'user-1',
}) => ProposalDetail(
  summary: proposalSummaryFixture(status: status, skills: skills),
  creatorProfileId: creatorProfileId,
  creatorDisplayName: 'Casey',
  description: 'A full proposal description.',
  exactMeetingText: restricted ? null : 'At the fountain, Piazza Maggiore',
  exactLocationRestricted: restricted,
);

ProposalInput proposalInputFixture({
  DateTime? startsAt,
  DateTime? endsAt,
  String eventTimezone = 'Europe/Rome',
}) => ProposalInput(
  title: 'Paint the square',
  summary: 'Create a community mural together.',
  description: 'A full proposal description.',
  startsAt: startsAt ?? DateTime.utc(2026, 9, 10, 10),
  endsAt: endsAt ?? DateTime.utc(2026, 9, 10, 12),
  eventTimezone: eventTimezone,
  countryCode: 'IT',
  locality: 'Bologna',
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: 'Central Bologna',
  exactMeetingText: 'At the fountain',
  exactLocationVisibility: ExactLocationVisibility.participants,
  skillImportanceById: const {'skill-mural': ProposalSkillImportance.required},
);

OwnProposal ownProposalFixture({
  String id = 'proposal-1',
  ProposalInput? input,
}) {
  final value = input ?? proposalInputFixture();
  return OwnProposal(
    id: id,
    lifecycle: ProposalLifecycle.draft,
    title: value.title,
    summary: value.summary,
    description: value.description,
    startsAt: value.startsAt,
    endsAt: value.endsAt,
    eventTimezone: value.eventTimezone,
    countryCode: value.countryCode,
    locality: value.locality,
    administrativeArea: value.administrativeArea,
    publicLocationLabel: value.publicLocationLabel,
    status: null,
    skills: proposalSummaryFixture().skills,
    exactMeetingText: value.exactMeetingText,
    exactLocationVisibility: value.exactLocationVisibility,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    publishedAt: null,
    cancelledAt: null,
  );
}
