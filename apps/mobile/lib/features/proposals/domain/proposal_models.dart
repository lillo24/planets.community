import '../../cover_media/domain/cover_media_models.dart';
import '../../participation/domain/project_capacity.dart';

enum ProposalLifecycle {
  draft('draft'),
  published('published'),
  cancelled('cancelled');

  const ProposalLifecycle(this.wireValue);

  final String wireValue;

  static ProposalLifecycle fromWire(String value) => switch (value) {
    'draft' => ProposalLifecycle.draft,
    'published' => ProposalLifecycle.published,
    'cancelled' => ProposalLifecycle.cancelled,
    _ => throw const FormatException('Unsupported proposal lifecycle.'),
  };
}

enum ProposalStatus {
  upcoming('upcoming'),
  happening('happening'),
  justFinished('just_finished'),
  completed('completed');

  const ProposalStatus(this.wireValue);

  final String wireValue;

  static ProposalStatus fromWire(String value) => switch (value) {
    'upcoming' => ProposalStatus.upcoming,
    'happening' => ProposalStatus.happening,
    'just_finished' => ProposalStatus.justFinished,
    'completed' => ProposalStatus.completed,
    _ => throw const FormatException('Unsupported proposal status.'),
  };
}

enum ProposalSkillImportance {
  required('required'),
  useful('useful');

  const ProposalSkillImportance(this.wireValue);

  final String wireValue;

  static ProposalSkillImportance fromWire(String value) => switch (value) {
    'required' => ProposalSkillImportance.required,
    'useful' => ProposalSkillImportance.useful,
    _ => throw const FormatException('Unsupported proposal skill importance.'),
  };
}

enum ExactLocationVisibility {
  public('public'),
  participants('participants');

  const ExactLocationVisibility(this.wireValue);

  final String wireValue;

  static ExactLocationVisibility fromWire(String value) => switch (value) {
    'public' => ExactLocationVisibility.public,
    'participants' => ExactLocationVisibility.participants,
    _ => throw const FormatException('Unsupported exact-location visibility.'),
  };
}

class ProposalSkill {
  const ProposalSkill({
    required this.id,
    required this.slug,
    required this.label,
    required this.categoryId,
    required this.categorySlug,
    required this.categoryLabel,
    required this.importance,
  });

  final String id;
  final String slug;
  final String label;
  final String categoryId;
  final String categorySlug;
  final String categoryLabel;
  final ProposalSkillImportance importance;
}

class ProposalCatalogSkill {
  const ProposalCatalogSkill({
    required this.id,
    required this.categoryId,
    required this.slug,
    required this.label,
    required this.sortOrder,
  });

  final String id;
  final String categoryId;
  final String slug;
  final String label;
  final int sortOrder;
}

class ProposalSkillCategory {
  const ProposalSkillCategory({
    required this.id,
    required this.slug,
    required this.label,
    required this.sortOrder,
    required this.skills,
  });

  final String id;
  final String slug;
  final String label;
  final int sortOrder;
  final List<ProposalCatalogSkill> skills;
}

class ProposalCursor {
  const ProposalCursor({required this.startsAt, required this.id});

  final DateTime startsAt;
  final String id;
}

class ProposalSummary {
  const ProposalSummary({
    required this.id,
    required this.title,
    required this.summary,
    required this.startsAt,
    required this.endsAt,
    required this.eventTimezone,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.status,
    required this.skills,
    required this.capacity,
    this.coverObjectPath,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime startsAt;
  final DateTime endsAt;
  final String eventTimezone;
  final String countryCode;
  final String locality;
  final String? administrativeArea;
  final String publicLocationLabel;
  final ProposalStatus status;
  final List<ProposalSkill> skills;
  final ProjectCapacitySnapshot capacity;
  final String? coverObjectPath;

  ProposalCursor get cursor => ProposalCursor(startsAt: startsAt, id: id);
}

class RequestedProposalSummary {
  const RequestedProposalSummary({
    required this.requestId,
    required this.requestCreatedAt,
    required this.proposal,
  });

  final String requestId;
  final DateTime requestCreatedAt;
  final ProposalSummary proposal;
}

class ProposalDetail {
  const ProposalDetail({
    required this.summary,
    required this.creatorProfileId,
    required this.creatorDisplayName,
    required this.description,
    required this.exactMeetingText,
    required this.exactLocationRestricted,
  });

  final ProposalSummary summary;
  final String creatorProfileId;
  final String? creatorDisplayName;
  final String description;
  final String? exactMeetingText;
  final bool exactLocationRestricted;
}

class OwnProposal {
  const OwnProposal({
    required this.id,
    required this.lifecycle,
    required this.title,
    required this.summary,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.eventTimezone,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.status,
    required this.skills,
    required this.exactMeetingText,
    required this.exactLocationVisibility,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.cancelledAt,
    required this.capacity,
    this.coverObjectPath,
  });

  final String id;
  final ProposalLifecycle lifecycle;
  final String? title;
  final String? summary;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? eventTimezone;
  final String? countryCode;
  final String? locality;
  final String? administrativeArea;
  final String? publicLocationLabel;
  final ProposalStatus? status;
  final List<ProposalSkill> skills;
  final String? exactMeetingText;
  final ExactLocationVisibility exactLocationVisibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? cancelledAt;
  final ProjectCapacitySnapshot capacity;
  final String? coverObjectPath;

  bool isEditableAt(DateTime now) =>
      lifecycle == ProposalLifecycle.draft ||
      (lifecycle == ProposalLifecycle.published &&
          (status == null || status == ProposalStatus.upcoming) &&
          startsAt != null &&
          now.isBefore(startsAt!));

  bool canCancelAt(DateTime now) =>
      lifecycle == ProposalLifecycle.published &&
      status != ProposalStatus.completed &&
      endsAt != null &&
      now.isBefore(endsAt!);
}

class ProposalInput {
  const ProposalInput({
    required this.title,
    required this.summary,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.eventTimezone,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.exactMeetingText,
    required this.exactLocationVisibility,
    required this.skillImportanceById,
    required this.peopleCapacity,
  });

  final String title;
  final String summary;
  final String description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String eventTimezone;
  final String countryCode;
  final String locality;
  final String administrativeArea;
  final String publicLocationLabel;
  final String exactMeetingText;
  final ExactLocationVisibility exactLocationVisibility;
  final Map<String, ProposalSkillImportance> skillImportanceById;
  final int? peopleCapacity;
}

bool isValidProposalDraft(ProposalInput input) {
  final titleLength = input.title.trim().length;
  final summaryLength = input.summary.trim().length;
  final descriptionLength = input.description.trim().length;
  final timezoneLength = input.eventTimezone.trim().length;
  final countryCode = input.countryCode.trim();
  final localityLength = input.locality.trim().length;
  final administrativeAreaLength = input.administrativeArea.trim().length;
  final labelLength = input.publicLocationLabel.trim().length;
  final exactLength = input.exactMeetingText.trim().length;

  return (titleLength == 0 || (titleLength >= 2 && titleLength <= 100)) &&
      summaryLength <= 240 &&
      descriptionLength <= 5000 &&
      timezoneLength <= 100 &&
      (countryCode.isEmpty || RegExp(r'^[A-Za-z]{2}$').hasMatch(countryCode)) &&
      localityLength <= 120 &&
      administrativeAreaLength <= 120 &&
      labelLength <= 180 &&
      exactLength <= 1000 &&
      isValidProjectPeopleCapacity(input.peopleCapacity) &&
      (input.startsAt == null ||
          input.endsAt == null ||
          input.endsAt!.isAfter(input.startsAt!));
}

bool isPublishableProposalInput(ProposalInput input) =>
    isValidProposalDraft(input) &&
    input.title.trim().isNotEmpty &&
    input.summary.trim().isNotEmpty &&
    input.description.trim().isNotEmpty &&
    input.startsAt != null &&
    input.endsAt != null &&
    input.eventTimezone.trim().isNotEmpty &&
    input.countryCode.trim().isNotEmpty &&
    input.locality.trim().isNotEmpty &&
    input.publicLocationLabel.trim().isNotEmpty &&
    input.exactMeetingText.trim().isNotEmpty &&
    input.peopleCapacity != null;

enum ProposalFailureKind {
  invalidInput,
  unavailable,
  forbidden,
  invalidState,
  profilePhotoRequired,
}

enum ProposalLoadPhase { idle, loading, ready, loadingMore, failure }

class PublicProposalsState {
  const PublicProposalsState({
    this.phase = ProposalLoadPhase.idle,
    this.items = const [],
    this.requestedItems = const [],
    this.categories = const [],
    this.query = '',
    this.locality = '',
    this.selectedSkillIds = const {},
    this.hasMore = true,
    this.failure,
  });

  final ProposalLoadPhase phase;
  // Raw public pages stay separate so personalization never changes cursors.
  final List<ProposalSummary> items;
  final List<RequestedProposalSummary> requestedItems;
  final List<ProposalSkillCategory> categories;
  final String query;
  final String locality;
  final Set<String> selectedSkillIds;
  final bool hasMore;
  final ProposalFailureKind? failure;

  bool get isBusy =>
      phase == ProposalLoadPhase.loading ||
      phase == ProposalLoadPhase.loadingMore;

  List<ProposalSummary> get ordinaryItems {
    final requestedIds = requestedItems.map((item) => item.proposal.id).toSet();
    return items
        .where((item) => !requestedIds.contains(item.id))
        .toList(growable: false);
  }
}

class ProposalDetailState {
  const ProposalDetailState({
    this.phase = ProposalLoadPhase.idle,
    this.proposalId,
    this.detail,
    this.failure,
  });

  final ProposalLoadPhase phase;
  final String? proposalId;
  final ProposalDetail? detail;
  final ProposalFailureKind? failure;
}

class OwnProposalsState {
  const OwnProposalsState({
    this.phase = ProposalLoadPhase.idle,
    this.expectedCreatorId,
    this.items = const [],
    this.failure,
  });

  final ProposalLoadPhase phase;
  final String? expectedCreatorId;
  final List<OwnProposal> items;
  final ProposalFailureKind? failure;

  bool get isBusy => phase == ProposalLoadPhase.loading;
}

enum ProposalEditorPhase {
  idle,
  loading,
  ready,
  saving,
  publishing,
  cancelling,
  failure,
}

class ProposalEditorState {
  const ProposalEditorState({
    this.phase = ProposalEditorPhase.idle,
    this.expectedCreatorId,
    this.proposal,
    this.categories = const [],
    this.failure,
    this.coverFailure,
    this.coverPartialSave,
  });

  final ProposalEditorPhase phase;
  final String? expectedCreatorId;
  final OwnProposal? proposal;
  final List<ProposalSkillCategory> categories;
  final ProposalFailureKind? failure;
  final CoverPersistenceFailureKind? coverFailure;
  final CoverPartialSaveKind? coverPartialSave;

  bool get isBusy => switch (phase) {
    ProposalEditorPhase.loading ||
    ProposalEditorPhase.saving ||
    ProposalEditorPhase.publishing ||
    ProposalEditorPhase.cancelling => true,
    ProposalEditorPhase.idle ||
    ProposalEditorPhase.ready ||
    ProposalEditorPhase.failure => false,
  };
}
