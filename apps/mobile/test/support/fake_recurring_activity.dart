import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';

typedef PublicTavoliLoader =
    Future<List<PublicRecurringActivitySummary>> Function({
      required DateTime referenceTime,
      required int limit,
      RecurringActivityCursor? cursor,
      String? locality,
    });

typedef RequestedTavoliLoader =
    Future<List<RequestedRecurringActivitySummary>> Function(
      String expectedProfileId, {
      required DateTime referenceTime,
      String? locality,
    });

class FakeRecurringActivityGateway implements RecurringActivityGateway {
  List<PublicRecurringActivitySummary> publicItems = [];
  List<RequestedRecurringActivitySummary> requestedItems = [];
  PublicRecurringActivityDetail? publicDetail;
  Future<PublicRecurringActivityDetail?>? publicDetailResult;
  List<OwnRecurringActivity> ownItems = [];
  PublicTavoliLoader? publicLoader;
  RequestedTavoliLoader? requestedLoader;
  Future<void>? mutationDelay;
  Object? error;
  Object? requestedError;
  final calls = <String>[];
  final referenceTimes = <DateTime>[];
  RecurringActivityCursor? lastCursor;
  String? lastLocality;
  String? lastExpectedIdentity;
  String? lastRequestedIdentity;
  RecurringActivityInput? lastInput;

  @override
  Future<List<PublicRecurringActivitySummary>> listPublicActivities({
    required DateTime referenceTime,
    required int limit,
    RecurringActivityCursor? cursor,
    String? locality,
  }) async {
    _throwIfNeeded();
    calls.add('list-public');
    referenceTimes.add(referenceTime);
    lastCursor = cursor;
    lastLocality = locality;
    if (publicLoader case final loader?) {
      return loader(
        referenceTime: referenceTime,
        limit: limit,
        cursor: cursor,
        locality: locality,
      );
    }
    return publicItems.take(limit).toList();
  }

  @override
  Future<List<RequestedRecurringActivitySummary>>
  listOwnPendingRequestedActivities(
    String expectedProfileId, {
    required DateTime referenceTime,
    String? locality,
  }) async {
    calls.add('list-requested');
    lastRequestedIdentity = expectedProfileId;
    lastLocality = locality;
    referenceTimes.add(referenceTime);
    if (requestedError case final failure?) throw failure;
    if (requestedLoader case final loader?) {
      return loader(
        expectedProfileId,
        referenceTime: referenceTime,
        locality: locality,
      );
    }
    return requestedItems;
  }

  @override
  Future<PublicRecurringActivityDetail?> getPublicActivity(
    String activityId, {
    required DateTime referenceTime,
    int occurrenceLimit = recurringActivityOccurrenceLimit,
  }) async {
    _throwIfNeeded();
    calls.add('public-detail:$activityId:$occurrenceLimit');
    referenceTimes.add(referenceTime);
    if (publicDetailResult case final result?) return result;
    return publicDetail;
  }

  @override
  Future<List<OwnRecurringActivity>> listOwnActivities(
    String expectedCreatorId,
  ) async {
    _throwIfNeeded();
    calls.add('list-own');
    lastExpectedIdentity = expectedCreatorId;
    return ownItems;
  }

  @override
  Future<OwnRecurringActivity?> getOwnActivity(
    String expectedCreatorId,
    String activityId,
  ) async {
    _throwIfNeeded();
    calls.add('own-detail:$activityId');
    lastExpectedIdentity = expectedCreatorId;
    return ownItems.where((item) => item.id == activityId).firstOrNull;
  }

  @override
  Future<String> createDraft(
    String expectedCreatorId,
    RecurringActivityInput input,
  ) async {
    _throwIfNeeded();
    calls.add('create');
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    lastInput = input;
    ownItems = [ownRecurringActivityFixture(id: 'new-tavolo', input: input)];
    return 'new-tavolo';
  }

  @override
  Future<void> updateOwnActivity(
    String expectedCreatorId,
    String activityId,
    RecurringActivityInput input,
  ) async {
    _throwIfNeeded();
    calls.add('update:$activityId');
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = expectedCreatorId;
    lastInput = input;
    ownItems = [
      ownRecurringActivityFixture(
        id: activityId,
        lifecycle: ownItems.firstOrNull?.lifecycle,
        input: input,
      ),
    ];
  }

  @override
  Future<void> publish(String expectedCreatorId, String activityId) =>
      _mutation('publish:$activityId', expectedCreatorId);

  @override
  Future<void> pause(String expectedCreatorId, String activityId) =>
      _mutation('pause:$activityId', expectedCreatorId);

  @override
  Future<void> resume(String expectedCreatorId, String activityId) =>
      _mutation('resume:$activityId', expectedCreatorId);

  @override
  Future<void> end(String expectedCreatorId, String activityId) =>
      _mutation('end:$activityId', expectedCreatorId);

  Future<void> _mutation(String call, String identity) async {
    _throwIfNeeded();
    calls.add(call);
    if (mutationDelay case final delay?) await delay;
    lastExpectedIdentity = identity;
  }

  void _throwIfNeeded() {
    if (error case final value?) throw value;
  }
}

RecurringSchedule recurringScheduleFixture({
  String id = 'schedule-1',
  RecurrenceType type = RecurrenceType.weekly,
  int? weekday = DateTime.wednesday,
  int? dayOfMonth,
  DateTime? effectiveFrom,
  DateTime? effectiveUntil,
  String timezone = 'Europe/Rome',
}) => RecurringSchedule(
  id: id,
  recurrenceType: type,
  weekday: type == RecurrenceType.weekly ? weekday : null,
  dayOfMonth: type == RecurrenceType.monthly ? (dayOfMonth ?? 12) : null,
  localStartTime: '19:00:00',
  durationMinutes: 90,
  eventTimezone: timezone,
  effectiveFrom: effectiveFrom ?? DateTime(2026, 9, 1),
  effectiveUntil: effectiveUntil,
);

PublicRecurringActivitySummary publicRecurringSummaryFixture({
  String id = 'tavolo-1',
  String title = 'Neighborhood philosophy table',
  RecurrenceType type = RecurrenceType.weekly,
}) => PublicRecurringActivitySummary(
  id: id,
  title: title,
  summary: 'A recurring conversation about ideas and local life.',
  topic: 'Philosophy',
  countryCode: 'IT',
  locality: 'Bologna',
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: 'Central Bologna',
  nextOccurrence: RecurringActivityOccurrence(
    startsAt: DateTime.utc(2026, 9, 9, 17),
    endsAt: DateTime.utc(2026, 9, 9, 18, 30),
    eventTimezone: 'Europe/Rome',
  ),
  schedule: recurringScheduleFixture(type: type),
);

RequestedRecurringActivitySummary requestedRecurringActivityFixture({
  String requestId = 'request-1',
  String activityId = 'tavolo-1',
  DateTime? requestCreatedAt,
}) => RequestedRecurringActivitySummary(
  requestId: requestId,
  requestCreatedAt: requestCreatedAt ?? DateTime.utc(2026, 9, 4, 12),
  activity: publicRecurringSummaryFixture(id: activityId),
);

PublicRecurringActivityDetail publicRecurringDetailFixture({
  String id = 'tavolo-1',
  String title = 'Neighborhood philosophy table',
  RecurringActivityLifecycle lifecycle = RecurringActivityLifecycle.published,
  bool restricted = true,
  RecurrenceType type = RecurrenceType.weekly,
  String creatorProfileId = 'user-1',
}) => PublicRecurringActivityDetail(
  id: id,
  creatorProfileId: creatorProfileId,
  creatorDisplayName: 'Casey',
  lifecycle: lifecycle,
  title: title,
  summary: 'A recurring conversation about ideas and local life.',
  description: 'Bring one question for a welcoming discussion.',
  topic: 'Philosophy',
  countryCode: 'IT',
  locality: 'Bologna',
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: 'Central Bologna',
  schedule: recurringScheduleFixture(type: type),
  nextOccurrences: lifecycle == RecurringActivityLifecycle.published
      ? [publicRecurringSummaryFixture().nextOccurrence]
      : const [],
  exactMeetingText: restricted ? null : 'At the long reading-room table',
  exactLocationRestricted: restricted,
);

RecurringActivityInput recurringInputFixture({
  RecurrenceType? type = RecurrenceType.weekly,
  DateTime? effectiveFrom,
}) => RecurringActivityInput(
  title: 'Neighborhood philosophy table',
  summary: 'A recurring conversation about ideas and local life.',
  description: 'Bring one question for a welcoming discussion.',
  topic: 'Philosophy',
  countryCode: 'IT',
  locality: 'Bologna',
  administrativeArea: 'Emilia-Romagna',
  publicLocationLabel: 'Central Bologna',
  exactMeetingText: 'At the long reading-room table',
  exactLocationVisibility: RecurringExactLocationVisibility.participants,
  recurrenceType: type,
  weekday: type == RecurrenceType.weekly ? DateTime.wednesday : null,
  dayOfMonth: type == RecurrenceType.monthly ? 12 : null,
  localStartTime: type == null ? null : '19:00:00',
  durationMinutes: type == null ? null : 90,
  eventTimezone: type == null ? '' : 'Europe/Rome',
  effectiveFrom: type == null ? null : effectiveFrom ?? DateTime(2026, 9, 1),
);

OwnRecurringActivity ownRecurringActivityFixture({
  String id = 'tavolo-1',
  RecurringActivityLifecycle? lifecycle,
  RecurringActivityInput? input,
  RecurringSchedule? schedule,
}) {
  final value = input ?? recurringInputFixture();
  final current =
      schedule ??
      (value.recurrenceType == null
          ? null
          : RecurringSchedule(
              id: 'schedule-1',
              recurrenceType: value.recurrenceType!,
              weekday: value.weekday,
              dayOfMonth: value.dayOfMonth,
              localStartTime: value.localStartTime!,
              durationMinutes: value.durationMinutes!,
              eventTimezone: value.eventTimezone,
              effectiveFrom: value.effectiveFrom!,
            ));
  return OwnRecurringActivity(
    id: id,
    lifecycle: lifecycle ?? RecurringActivityLifecycle.draft,
    title: value.title,
    summary: value.summary,
    description: value.description,
    topic: value.topic,
    countryCode: value.countryCode,
    locality: value.locality,
    administrativeArea: value.administrativeArea,
    publicLocationLabel: value.publicLocationLabel,
    currentSchedule: current,
    scheduleHistory: current == null ? const [] : [current],
    exactMeetingText: value.exactMeetingText,
    exactLocationVisibility: value.exactLocationVisibility,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    publishedAt: null,
    pausedAt: null,
    resumedAt: null,
    endedAt: null,
  );
}
