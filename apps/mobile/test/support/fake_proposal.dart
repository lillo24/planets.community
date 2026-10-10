import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';

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
  Object? publishError;
  Object? createResponseError;
  Object? ownReadError;
  String createdId = 'new-draft';
  Object? mutationError;
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
    calls.add('list-own');
    lastExpectedIdentity = expectedCreatorId;
    return ownListResult ?? Future.value(ownItems);
  }

  @override
  Future<OwnProposal?> getOwnProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    _throwIfNeeded();
    if (ownReadError case final failure?) throw failure;
    lastExpectedIdentity = expectedCreatorId;
    return ownResult ??
        Future.value(
          ownItems.where((item) => item.id == proposalId).firstOrNull,
        );
  }

  @override
  Future<String> createDraft(
    String expectedCreatorId,
    ProposalInput input, {
    String? clientRequestId,
  }) async {
    _throwIfNeeded();
    calls.add('create');
    _throwMutationIfNeeded();
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    lastInput = input;
    final receipt = _receipts['$expectedCreatorId:$clientRequestId'];
    if (clientRequestId != null && receipt != null) return receipt;
    ownItems = [ownProposalFixture(id: createdId, input: input), ...ownItems];
    if (clientRequestId != null) {
      _receipts['$expectedCreatorId:$clientRequestId'] = createdId;
    }
    if (createResponseError case final failure?) {
      createResponseError = null;
      throw failure;
    }
    return createdId;
  }

  final _receipts = <String, String>{};
  @override
  Future<String?> recoverDraftCreation(
    String expectedCreatorId,
    String clientRequestId,
  ) async => _receipts['$expectedCreatorId:$clientRequestId'];

  @override
  Future<void> updateOwnProposal(
    String expectedCreatorId,
    String proposalId,
    ProposalInput input,
  ) async {
    _throwIfNeeded();
    calls.add('update:$proposalId');
    _throwMutationIfNeeded();
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    lastInput = input;
    ownItems = [
      for (final proposal in ownItems)
        if (proposal.id == proposalId)
          _copyProposal(proposal, input: input)
        else
          proposal,
    ];
  }

  @override
  Future<void> publishProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    _throwIfNeeded();
    calls.add('publish:$proposalId');
    if (publishError case final failure?) throw failure;
    _throwMutationIfNeeded();
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    ownItems = [
      for (final proposal in ownItems)
        if (proposal.id == proposalId)
          _copyProposal(
            proposal,
            lifecycle: ProposalLifecycle.published,
            status: ProposalStatus.upcoming,
          )
        else
          proposal,
    ];
  }

  @override
  Future<void> cancelProposal(
    String expectedCreatorId,
    String proposalId,
  ) async {
    _throwIfNeeded();
    calls.add('cancel:$proposalId');
    _throwMutationIfNeeded();
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    ownItems = [
      for (final proposal in ownItems)
        if (proposal.id == proposalId)
          _copyProposal(proposal, lifecycle: ProposalLifecycle.cancelled)
        else
          proposal,
    ];
  }

  void _throwIfNeeded() {
    if (error case final failure?) throw failure;
  }

  void _throwMutationIfNeeded() {
    if (mutationError case final failure?) throw failure;
  }
}

OwnProposal _copyProposal(
  OwnProposal proposal, {
  ProposalInput? input,
  ProposalLifecycle? lifecycle,
  ProposalStatus? status,
}) => OwnProposal(
  id: proposal.id,
  lifecycle: lifecycle ?? proposal.lifecycle,
  title: input?.title ?? proposal.title,
  summary: input?.summary ?? proposal.summary,
  description: input?.description ?? proposal.description,
  startsAt: input == null ? proposal.startsAt : input.startsAt,
  endsAt: input == null ? proposal.endsAt : input.endsAt,
  eventTimezone: input?.eventTimezone ?? proposal.eventTimezone,
  countryCode: input?.countryCode ?? proposal.countryCode,
  locality: input?.locality ?? proposal.locality,
  administrativeArea: input?.administrativeArea ?? proposal.administrativeArea,
  publicLocationLabel:
      input?.publicLocationLabel ?? proposal.publicLocationLabel,
  status: lifecycle == ProposalLifecycle.cancelled
      ? null
      : status ?? proposal.status,
  skills: proposal.skills,
  exactMeetingText: input?.exactMeetingText ?? proposal.exactMeetingText,
  exactLocationVisibility:
      input?.exactLocationVisibility ?? proposal.exactLocationVisibility,
  createdAt: proposal.createdAt,
  updatedAt: proposal.updatedAt,
  publishedAt: lifecycle == ProposalLifecycle.published
      ? proposal.publishedAt ?? DateTime.utc(2026, 9, 2)
      : proposal.publishedAt,
  cancelledAt: lifecycle == ProposalLifecycle.cancelled
      ? DateTime.utc(2026, 9, 3)
      : proposal.cancelledAt,
  capacity: projectCapacityFixture(
    registrationCapacity: input == null
        ? proposal.capacity.registrationCapacity
        : input.registrationCapacity,
    countOrganizersTowardCapacity:
        input?.countOrganizersTowardCapacity ??
        proposal.capacity.countOrganizersTowardCapacity,
    currentParticipantCount: proposal.capacity.currentParticipantCount,
  ),
);

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
  String title = 'Paint the square',
  String locality = 'Bologna',
  String publicLocationLabel = 'Central Bologna',
  ProposalStatus status = ProposalStatus.upcoming,
  List<ProposalSkill>? skills,
  String? coverObjectPath,
  ProjectCapacitySnapshot? capacity,
}) => ProposalSummary(
  id: id,
  title: title,
  summary: 'Create a community mural together.',
  startsAt: DateTime.utc(2026, 9, 10, 10),
  endsAt: DateTime.utc(2026, 9, 10, 12),
  eventTimezone: 'Europe/Rome',
  countryCode: 'IT',
  locality: locality,
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: publicLocationLabel,
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
  coverObjectPath: coverObjectPath,
  capacity: capacity ?? projectCapacityFixture(),
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
  String id = 'proposal-1',
  String title = 'Paint the square',
  String locality = 'Bologna',
  String publicLocationLabel = 'Central Bologna',
  String? exactMeetingText = 'At the fountain, Piazza Maggiore',
  bool restricted = true,
  ProposalStatus status = ProposalStatus.upcoming,
  List<ProposalSkill>? skills,
  String creatorProfileId = 'user-1',
  ProjectCapacitySnapshot? capacity,
}) => ProposalDetail(
  summary: proposalSummaryFixture(
    id: id,
    title: title,
    locality: locality,
    publicLocationLabel: publicLocationLabel,
    status: status,
    skills: skills,
    capacity: capacity,
  ),
  creatorProfileId: creatorProfileId,
  creatorDisplayName: 'Casey',
  description: 'A full proposal description.',
  exactMeetingText: restricted ? null : exactMeetingText,
  exactLocationRestricted: restricted,
);

ProposalInput proposalInputFixture({
  String title = 'Paint the square',
  DateTime? startsAt,
  DateTime? endsAt,
  String eventTimezone = 'Europe/Rome',
  String countryCode = 'IT',
  String locality = 'Bologna',
  String publicLocationLabel = 'Central Bologna',
  String exactMeetingText = 'At the fountain',
  int? registrationCapacity = 20,
  bool countOrganizersTowardCapacity = false,
}) => ProposalInput(
  title: title,
  summary: 'Create a community mural together.',
  description: 'A full proposal description.',
  startsAt: startsAt ?? DateTime.utc(2026, 9, 10, 10),
  endsAt: endsAt ?? DateTime.utc(2026, 9, 10, 12),
  eventTimezone: eventTimezone,
  countryCode: countryCode,
  locality: locality,
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: publicLocationLabel,
  exactMeetingText: exactMeetingText,
  exactLocationVisibility: ExactLocationVisibility.participants,
  skillImportanceById: const {'skill-mural': ProposalSkillImportance.required},
  registrationCapacity: registrationCapacity,
  countOrganizersTowardCapacity: countOrganizersTowardCapacity,
);

OwnProposal ownProposalFixture({
  String id = 'proposal-1',
  ProposalInput? input,
  bool unsetTimezone = false,
  String? coverObjectPath,
  ProposalLifecycle lifecycle = ProposalLifecycle.draft,
  ProposalStatus? status,
  DateTime? startsAt,
  DateTime? endsAt,
  ProjectCapacitySnapshot? capacity,
}) {
  final value = input ?? proposalInputFixture();
  return OwnProposal(
    id: id,
    lifecycle: lifecycle,
    title: value.title,
    summary: value.summary,
    description: value.description,
    startsAt: startsAt ?? value.startsAt,
    endsAt: endsAt ?? value.endsAt,
    eventTimezone: unsetTimezone ? null : value.eventTimezone,
    countryCode: value.countryCode,
    locality: value.locality,
    administrativeArea: value.administrativeArea,
    publicLocationLabel: value.publicLocationLabel,
    status: lifecycle == ProposalLifecycle.published
        ? status ?? ProposalStatus.upcoming
        : null,
    skills: proposalSummaryFixture().skills,
    exactMeetingText: value.exactMeetingText,
    exactLocationVisibility: value.exactLocationVisibility,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    publishedAt: lifecycle == ProposalLifecycle.published
        ? DateTime.utc(2026, 9, 2)
        : null,
    cancelledAt: lifecycle == ProposalLifecycle.cancelled
        ? DateTime.utc(2026, 9, 3)
        : null,
    coverObjectPath: coverObjectPath,
    capacity:
        capacity ??
        projectCapacityFixture(
          registrationCapacity: value.registrationCapacity,
          countOrganizersTowardCapacity: value.countOrganizersTowardCapacity,
        ),
  );
}

ProjectCapacitySnapshot projectCapacityFixture({
  int? registrationCapacity = 20,
  int currentParticipantCount = 0,
  int organizerCount = 1,
  bool countOrganizersTowardCapacity = false,
}) {
  final capacityUsed =
      currentParticipantCount +
      (countOrganizersTowardCapacity ? organizerCount : 0);
  final people = currentParticipantCount + organizerCount;
  final remaining = registrationCapacity == null
      ? null
      : (registrationCapacity > capacityUsed
            ? registrationCapacity - capacityUsed
            : 0);
  return ProjectCapacitySnapshot(
    registrationCapacity: registrationCapacity,
    countOrganizersTowardCapacity: countOrganizersTowardCapacity,
    currentParticipantCount: currentParticipantCount,
    ordinaryParticipantCount: currentParticipantCount,
    organizerCount: organizerCount,
    capacityUsedCount: capacityUsed,
    socialPeopleCount: people,
    spotsRemaining: remaining,
    isFull:
        registrationCapacity != null && capacityUsed >= registrationCapacity,
  );
}
