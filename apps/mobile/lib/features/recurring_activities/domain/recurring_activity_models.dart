import '../../../core/time/event_time.dart';
import '../../cover_media/domain/cover_media_models.dart';
import '../../participation/domain/project_capacity.dart';

enum RecurringActivityLifecycle {
  draft('draft'),
  published('published'),
  paused('paused'),
  ended('ended');

  const RecurringActivityLifecycle(this.wireValue);
  final String wireValue;

  static RecurringActivityLifecycle fromWire(String value) => switch (value) {
    'draft' => draft,
    'published' => published,
    'paused' => paused,
    'ended' => ended,
    _ => throw const FormatException('Unsupported recurring lifecycle.'),
  };
}

enum RecurrenceType {
  weekly('weekly'),
  monthly('monthly');

  const RecurrenceType(this.wireValue);
  final String wireValue;

  static RecurrenceType fromWire(String value) => switch (value) {
    'weekly' => weekly,
    'monthly' => monthly,
    _ => throw const FormatException('Unsupported recurrence type.'),
  };
}

enum RecurringExactLocationVisibility {
  public('public'),
  participants('participants');

  const RecurringExactLocationVisibility(this.wireValue);
  final String wireValue;

  static RecurringExactLocationVisibility fromWire(String value) =>
      switch (value) {
        'public' => public,
        'participants' => participants,
        _ => throw const FormatException(
          'Unsupported recurring exact-location visibility.',
        ),
      };
}

class RecurringActivityCursor {
  const RecurringActivityCursor({required this.nextStartsAt, required this.id});
  final DateTime nextStartsAt;
  final String id;
}

class RecurringActivityOccurrence {
  const RecurringActivityOccurrence({
    required this.startsAt,
    required this.endsAt,
    required this.eventTimezone,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final String eventTimezone;
}

class RecurringSchedule {
  const RecurringSchedule({
    required this.id,
    required this.recurrenceType,
    required this.weekday,
    required this.dayOfMonth,
    required this.localStartTime,
    required this.durationMinutes,
    required this.eventTimezone,
    required this.effectiveFrom,
    this.effectiveUntil,
  });

  final String id;
  final RecurrenceType recurrenceType;
  final int? weekday;
  final int? dayOfMonth;
  final String localStartTime;
  final int durationMinutes;
  final String eventTimezone;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  bool isPendingAt(DateTime instant) =>
      effectiveFrom.isAfter(eventLocalDate(instant, eventTimezone));

  bool sameDefinition(RecurringActivityInput input) =>
      recurrenceType == input.recurrenceType &&
      weekday == input.weekday &&
      dayOfMonth == input.dayOfMonth &&
      _minuteTime(localStartTime) == _minuteTime(input.localStartTime ?? '') &&
      durationMinutes == input.durationMinutes &&
      eventTimezone == input.eventTimezone.trim();
}

class PublicRecurringActivitySummary {
  const PublicRecurringActivitySummary({
    required this.id,
    required this.title,
    required this.summary,
    required this.topic,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.nextOccurrence,
    required this.schedule,
    required this.capacity,
    this.coverObjectPath,
  });

  final String id;
  final String title;
  final String summary;
  final String? topic;
  final String countryCode;
  final String locality;
  final String? administrativeArea;
  final String publicLocationLabel;
  final RecurringActivityOccurrence nextOccurrence;
  final RecurringSchedule schedule;
  final ProjectCapacitySnapshot capacity;
  final String? coverObjectPath;

  RecurringActivityCursor get cursor =>
      RecurringActivityCursor(nextStartsAt: nextOccurrence.startsAt, id: id);
}

class RequestedRecurringActivitySummary {
  const RequestedRecurringActivitySummary({
    required this.requestId,
    required this.requestCreatedAt,
    required this.activity,
  });

  final String requestId;
  final DateTime requestCreatedAt;
  final PublicRecurringActivitySummary activity;
}

class PublicRecurringActivityDetail {
  const PublicRecurringActivityDetail({
    required this.id,
    required this.creatorProfileId,
    required this.creatorDisplayName,
    required this.lifecycle,
    required this.title,
    required this.summary,
    required this.description,
    required this.topic,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.schedule,
    required this.nextOccurrences,
    required this.exactMeetingText,
    required this.exactLocationRestricted,
    required this.capacity,
    this.coverObjectPath,
  });

  final String id;
  final String creatorProfileId;
  final String? creatorDisplayName;
  final RecurringActivityLifecycle lifecycle;
  final String title;
  final String summary;
  final String description;
  final String? topic;
  final String countryCode;
  final String locality;
  final String? administrativeArea;
  final String publicLocationLabel;
  final RecurringSchedule schedule;
  final List<RecurringActivityOccurrence> nextOccurrences;
  final String? exactMeetingText;
  final bool exactLocationRestricted;
  final ProjectCapacitySnapshot capacity;
  final String? coverObjectPath;
}

class OwnRecurringActivity {
  const OwnRecurringActivity({
    required this.id,
    required this.lifecycle,
    required this.title,
    required this.summary,
    required this.description,
    required this.topic,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.currentSchedule,
    required this.scheduleHistory,
    required this.exactMeetingText,
    required this.exactLocationVisibility,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.pausedAt,
    required this.resumedAt,
    required this.endedAt,
    required this.capacity,
    this.coverObjectPath,
  });

  final String id;
  final RecurringActivityLifecycle lifecycle;
  final String? title;
  final String? summary;
  final String? description;
  final String? topic;
  final String? countryCode;
  final String? locality;
  final String? administrativeArea;
  final String? publicLocationLabel;
  final RecurringSchedule? currentSchedule;
  final List<RecurringSchedule> scheduleHistory;
  final String? exactMeetingText;
  final RecurringExactLocationVisibility exactLocationVisibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? endedAt;
  final ProjectCapacitySnapshot capacity;
  final String? coverObjectPath;

  bool get isEditable => lifecycle != RecurringActivityLifecycle.ended;
  bool get canPublish => lifecycle == RecurringActivityLifecycle.draft;
  bool get canPause => lifecycle == RecurringActivityLifecycle.published;
  bool get canResume => lifecycle == RecurringActivityLifecycle.paused;
  bool get canEnd =>
      lifecycle == RecurringActivityLifecycle.published ||
      lifecycle == RecurringActivityLifecycle.paused;

  bool hasPendingScheduleAt(DateTime now) =>
      currentSchedule?.isPendingAt(now) ?? false;
}

class RecurringActivityInput {
  const RecurringActivityInput({
    required this.title,
    required this.summary,
    required this.description,
    required this.topic,
    required this.countryCode,
    required this.locality,
    required this.administrativeArea,
    required this.publicLocationLabel,
    required this.exactMeetingText,
    required this.exactLocationVisibility,
    required this.recurrenceType,
    required this.weekday,
    required this.dayOfMonth,
    required this.localStartTime,
    required this.durationMinutes,
    required this.eventTimezone,
    required this.effectiveFrom,
    required this.registrationCapacity,
    required this.countOrganizersTowardCapacity,
  });

  final String title;
  final String summary;
  final String description;
  final String topic;
  final String countryCode;
  final String locality;
  final String administrativeArea;
  final String publicLocationLabel;
  final String exactMeetingText;
  final RecurringExactLocationVisibility exactLocationVisibility;
  final RecurrenceType? recurrenceType;
  final int? weekday;
  final int? dayOfMonth;
  final String? localStartTime;
  final int? durationMinutes;
  final String eventTimezone;
  final DateTime? effectiveFrom;
  final int? registrationCapacity;
  final bool countOrganizersTowardCapacity;

  bool get hasAnyScheduleValue =>
      recurrenceType != null ||
      weekday != null ||
      dayOfMonth != null ||
      (localStartTime?.trim().isNotEmpty ?? false) ||
      durationMinutes != null ||
      eventTimezone.trim().isNotEmpty ||
      effectiveFrom != null;

  bool get hasCompleteSchedule =>
      recurrenceType != null &&
      localStartTime != null &&
      localStartTime!.trim().isNotEmpty &&
      durationMinutes != null &&
      eventTimezone.trim().isNotEmpty &&
      effectiveFrom != null &&
      ((recurrenceType == RecurrenceType.weekly &&
              weekday != null &&
              dayOfMonth == null) ||
          (recurrenceType == RecurrenceType.monthly &&
              dayOfMonth != null &&
              weekday == null));
}

bool isValidRecurringActivityDraft(RecurringActivityInput input) {
  bool bounded(String value, int max, {int min = 0}) {
    final length = value.trim().length;
    return length == 0 || (length >= min && length <= max);
  }

  if (!isValidProjectRegistrationCapacity(input.registrationCapacity) ||
      !bounded(input.title, 100, min: 2) ||
      !bounded(input.summary, 240) ||
      !bounded(input.description, 5000) ||
      !bounded(input.topic, 120) ||
      !bounded(input.locality, 120) ||
      !bounded(input.administrativeArea, 120) ||
      !bounded(input.publicLocationLabel, 180) ||
      !bounded(input.exactMeetingText, 1000) ||
      (input.countryCode.trim().isNotEmpty &&
          !RegExp(r'^[A-Za-z]{2}$').hasMatch(input.countryCode.trim()))) {
    return false;
  }
  if (!input.hasAnyScheduleValue) return true;
  if (!input.hasCompleteSchedule) return false;
  if (!isKnownEventTimeZone(input.eventTimezone)) return false;
  if (input.durationMinutes! < 15 || input.durationMinutes! > 1440) {
    return false;
  }
  if (input.weekday case final weekday? when weekday < 1 || weekday > 7) {
    return false;
  }
  if (input.dayOfMonth case final day? when day < 1 || day > 28) {
    return false;
  }
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$')
      .hasMatch(input.localStartTime!);
}

bool isPublishableRecurringActivityInput(RecurringActivityInput input) =>
    isValidRecurringActivityDraft(input) &&
    input.title.trim().isNotEmpty &&
    input.summary.trim().isNotEmpty &&
    input.description.trim().isNotEmpty &&
    input.countryCode.trim().isNotEmpty &&
    input.locality.trim().isNotEmpty &&
    input.publicLocationLabel.trim().isNotEmpty &&
    input.exactMeetingText.trim().isNotEmpty &&
    input.registrationCapacity != null &&
    input.hasCompleteSchedule;

bool isValidRecurringScheduleTransition(
  OwnRecurringActivity? existing,
  RecurringActivityInput input,
  DateTime now,
) {
  if (existing == null ||
      existing.lifecycle == RecurringActivityLifecycle.draft) {
    return true;
  }
  if (!existing.isEditable) return false;
  final current = existing.currentSchedule;
  if (current == null || !input.hasCompleteSchedule) return false;
  final effectiveFrom = input.effectiveFrom!;
  if (current.isPendingAt(now)) {
    return _sameDate(effectiveFrom, current.effectiveFrom);
  }
  if (current.sameDefinition(input)) {
    return _sameDate(effectiveFrom, current.effectiveFrom);
  }
  return effectiveFrom.isAfter(eventLocalDate(now, input.eventTimezone));
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _minuteTime(String value) {
  final parts = value.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
}

enum RecurringActivityFailureKind {
  invalidInput,
  capacityConflict,
  unavailable,
  forbidden,
  invalidState,
  profilePhotoRequired,
}

enum RecurringActivityLoadPhase { idle, loading, ready, loadingMore, failure }

class PublicRecurringActivitiesState {
  const PublicRecurringActivitiesState({
    this.phase = RecurringActivityLoadPhase.idle,
    this.items = const [],
    this.requestedItems = const [],
    this.locality = '',
    this.referenceTime,
    this.hasMore = true,
    this.failure,
  });

  final RecurringActivityLoadPhase phase;
  // Raw public pages stay separate so personalization never changes cursors.
  final List<PublicRecurringActivitySummary> items;
  final List<RequestedRecurringActivitySummary> requestedItems;
  final String locality;
  final DateTime? referenceTime;
  final bool hasMore;
  final RecurringActivityFailureKind? failure;

  bool get isBusy =>
      phase == RecurringActivityLoadPhase.loading ||
      phase == RecurringActivityLoadPhase.loadingMore;

  List<PublicRecurringActivitySummary> get ordinaryItems {
    final requestedIds = requestedItems.map((item) => item.activity.id).toSet();
    return items
        .where((item) => !requestedIds.contains(item.id))
        .toList(growable: false);
  }
}

class PublicRecurringActivityDetailState {
  const PublicRecurringActivityDetailState({
    this.phase = RecurringActivityLoadPhase.idle,
    this.activityId,
    this.detail,
    this.failure,
  });
  final RecurringActivityLoadPhase phase;
  final String? activityId;
  final PublicRecurringActivityDetail? detail;
  final RecurringActivityFailureKind? failure;
}

class OwnRecurringActivitiesState {
  const OwnRecurringActivitiesState({
    this.phase = RecurringActivityLoadPhase.idle,
    this.expectedCreatorId,
    this.items = const [],
    this.failure,
  });
  final RecurringActivityLoadPhase phase;
  final String? expectedCreatorId;
  final List<OwnRecurringActivity> items;
  final RecurringActivityFailureKind? failure;
  bool get isBusy => phase == RecurringActivityLoadPhase.loading;
}

enum RecurringActivityEditorPhase {
  idle,
  loading,
  ready,
  saving,
  publishing,
  mutatingLifecycle,
  failure,
}

class RecurringActivityEditorState {
  const RecurringActivityEditorState({
    this.phase = RecurringActivityEditorPhase.idle,
    this.expectedCreatorId,
    this.activity,
    this.failure,
    this.coverFailure,
    this.coverPartialSave,
  });
  final RecurringActivityEditorPhase phase;
  final String? expectedCreatorId;
  final OwnRecurringActivity? activity;
  final RecurringActivityFailureKind? failure;
  final CoverPersistenceFailureKind? coverFailure;
  final CoverPartialSaveKind? coverPartialSave;
  bool get isBusy => switch (phase) {
    RecurringActivityEditorPhase.loading ||
    RecurringActivityEditorPhase.saving ||
    RecurringActivityEditorPhase.publishing ||
    RecurringActivityEditorPhase.mutatingLifecycle => true,
    _ => false,
  };
}
