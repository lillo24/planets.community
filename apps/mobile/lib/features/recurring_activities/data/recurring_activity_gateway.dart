import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/cover_media_path.dart';
import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/project_capacity.dart';
import '../domain/recurring_activity_models.dart';

const recurringActivityPageSize = 20;
const recurringActivityOccurrenceLimit = 5;

abstract interface class RecurringActivityGateway {
  Future<List<PublicRecurringActivitySummary>> listPublicActivities({
    required DateTime referenceTime,
    required int limit,
    RecurringActivityCursor? cursor,
    String? locality,
  });

  Future<List<RequestedRecurringActivitySummary>>
  listOwnPendingRequestedActivities(
    String expectedProfileId, {
    required DateTime referenceTime,
    String? locality,
  });

  Future<PublicRecurringActivityDetail?> getPublicActivity(
    String activityId, {
    required DateTime referenceTime,
    int occurrenceLimit = recurringActivityOccurrenceLimit,
  });

  Future<List<OwnRecurringActivity>> listOwnActivities(
    String expectedCreatorId,
  );
  Future<OwnRecurringActivity?> getOwnActivity(
    String expectedCreatorId,
    String activityId,
  );
  Future<String> createDraft(
    String expectedCreatorId,
    RecurringActivityInput input,
  );
  Future<void> updateOwnActivity(
    String expectedCreatorId,
    String activityId,
    RecurringActivityInput input,
  );
  Future<void> publish(String expectedCreatorId, String activityId);
  Future<void> pause(String expectedCreatorId, String activityId);
  Future<void> resume(String expectedCreatorId, String activityId);
  Future<void> end(String expectedCreatorId, String activityId);
}

class SupabaseRecurringActivityGateway implements RecurringActivityGateway {
  const SupabaseRecurringActivityGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PublicRecurringActivitySummary>> listPublicActivities({
    required DateTime referenceTime,
    required int limit,
    RecurringActivityCursor? cursor,
    String? locality,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_public_recurring_activities',
      params: {
        'p_reference_time': referenceTime.toUtc().toIso8601String(),
        'p_limit': limit,
        'p_cursor_next_starts_at': cursor?.nextStartsAt
            .toUtc()
            .toIso8601String(),
        'p_cursor_id': cursor?.id,
        'p_locality': locality,
      },
    );
    final rows = response.cast<Map<String, dynamic>>();
    final capacities = await _publicCapacities(
      rows.map((row) => row['recurring_activity_id'] as String),
    );
    // The reviewed list RPC intentionally exposes only the next occurrence.
    // Enrich each bounded page through the sanitized public-detail RPC so cards
    // can state the weekly/monthly cadence without touching owner data.
    final schedules = await Future.wait(
      rows.map(
        (row) => _getPublicRow(
          row['recurring_activity_id'] as String,
          referenceTime: referenceTime,
          occurrenceLimit: 1,
          capacity: capacities[row['recurring_activity_id'] as String],
        ),
      ),
    );
    return List.generate(
      rows.length,
      (index) => _publicSummaryFromRow(
        rows[index],
        schedules[index]?.schedule ??
            (throw const FormatException(
              'A listed recurring activity had no public detail.',
            )),
        capacities[rows[index]['recurring_activity_id']] ??
            (throw const FormatException(
              'A listed Tavolo had no capacity status.',
            )),
      ),
      growable: false,
    );
  }

  @override
  Future<List<RequestedRecurringActivitySummary>>
  listOwnPendingRequestedActivities(
    String expectedProfileId, {
    required DateTime referenceTime,
    String? locality,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_pending_requested_recurring_activities',
      params: {
        'p_expected_requester_profile_id': expectedProfileId,
        'p_reference_time': referenceTime.toUtc().toIso8601String(),
        'p_locality': locality,
      },
    );
    final rows = response.cast<Map<String, dynamic>>();
    final capacities = await _publicCapacities(
      rows.map((row) => row['recurring_activity_id'] as String),
    );
    return rows
        .map(
          (row) => RequestedRecurringActivitySummary(
            requestId: row['request_id'] as String,
            requestCreatedAt: DateTime.parse(
              row['request_created_at'] as String,
            ),
            activity: _publicSummaryFromRow(
              row,
              _scheduleFromFlatRow(row),
              capacities[row['recurring_activity_id']] ??
                  (throw const FormatException(
                    'A requested Tavolo had no capacity status.',
                  )),
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PublicRecurringActivityDetail?> getPublicActivity(
    String activityId, {
    required DateTime referenceTime,
    int occurrenceLimit = recurringActivityOccurrenceLimit,
  }) => _getPublicRow(
    activityId,
    referenceTime: referenceTime,
    occurrenceLimit: occurrenceLimit,
  );

  Future<PublicRecurringActivityDetail?> _getPublicRow(
    String activityId, {
    required DateTime referenceTime,
    required int occurrenceLimit,
    ProjectCapacitySnapshot? capacity,
  }) async {
    final values = await Future.wait<dynamic>([
      _client.rpc<List<dynamic>>(
        'get_public_recurring_activity',
        params: {
          'p_recurring_activity_id': activityId,
          'p_occurrence_limit': occurrenceLimit,
          'p_reference_time': referenceTime.toUtc().toIso8601String(),
        },
      ),
      if (capacity == null) _publicCapacities([activityId]),
    ]);
    final rows = (values.first as List<dynamic>).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    final resolvedCapacity =
        capacity ??
        (values[1] as Map<String, ProjectCapacitySnapshot>)[activityId];
    if (resolvedCapacity == null) {
      throw const FormatException('A public Tavolo had no capacity status.');
    }
    return _publicDetailFromRow(rows.single, resolvedCapacity);
  }

  @override
  Future<List<OwnRecurringActivity>> listOwnActivities(
    String expectedCreatorId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_recurring_activities',
      params: {'p_expected_creator_profile_id': expectedCreatorId},
    );
    final rows = response.cast<Map<String, dynamic>>();
    final capacities = await _structuralCapacities(
      expectedCreatorId,
      rows.map((row) => row['recurring_activity_id'] as String),
    );
    return rows
        .map(
          (row) => _ownActivityFromRow(
            row,
            capacities[row['recurring_activity_id']] ??
                (throw const FormatException(
                  'A managed Tavolo had no capacity status.',
                )),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<OwnRecurringActivity?> getOwnActivity(
    String expectedCreatorId,
    String activityId,
  ) async {
    final values = await Future.wait<dynamic>([
      _client.rpc<List<dynamic>>(
        'get_own_recurring_activity',
        params: {
          'p_expected_creator_profile_id': expectedCreatorId,
          'p_recurring_activity_id': activityId,
        },
      ),
      _structuralCapacities(expectedCreatorId, [activityId]),
    ]);
    final rows = (values.first as List<dynamic>).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    final capacity =
        (values[1] as Map<String, ProjectCapacitySnapshot>)[activityId];
    if (capacity == null) {
      throw const FormatException('A managed Tavolo had no capacity status.');
    }
    return _ownActivityFromRow(rows.single, capacity);
  }

  @override
  Future<String> createDraft(
    String expectedCreatorId,
    RecurringActivityInput input,
  ) => _client.rpc<String>(
    'create_recurring_activity_draft',
    params: _contentParams(expectedCreatorId, input),
  );

  @override
  Future<void> updateOwnActivity(
    String expectedCreatorId,
    String activityId,
    RecurringActivityInput input,
  ) async {
    await _client.rpc<void>(
      'update_own_recurring_activity',
      params: {
        ..._contentParams(expectedCreatorId, input),
        'p_recurring_activity_id': activityId,
      },
    );
  }

  @override
  Future<void> publish(String expectedCreatorId, String activityId) =>
      _command('publish_recurring_activity', expectedCreatorId, activityId);

  @override
  Future<void> pause(String expectedCreatorId, String activityId) =>
      _command('pause_recurring_activity', expectedCreatorId, activityId);

  @override
  Future<void> resume(String expectedCreatorId, String activityId) =>
      _command('resume_recurring_activity', expectedCreatorId, activityId);

  @override
  Future<void> end(String expectedCreatorId, String activityId) =>
      _command('end_recurring_activity', expectedCreatorId, activityId);

  Future<void> _command(
    String name,
    String expectedCreatorId,
    String activityId,
  ) async {
    await _client.rpc<void>(
      name,
      params: {
        'p_expected_creator_profile_id': expectedCreatorId,
        'p_recurring_activity_id': activityId,
      },
    );
  }

  Map<String, dynamic> _contentParams(
    String expectedCreatorId,
    RecurringActivityInput input,
  ) => {
    'p_expected_creator_profile_id': expectedCreatorId,
    'p_title': input.title,
    'p_summary': input.summary,
    'p_description': input.description,
    'p_topic': input.topic,
    'p_country_code': input.countryCode,
    'p_locality': input.locality,
    'p_administrative_area': input.administrativeArea,
    'p_public_location_label': input.publicLocationLabel,
    'p_exact_meeting_text': input.exactMeetingText,
    'p_exact_location_visibility': input.exactLocationVisibility.wireValue,
    'p_recurrence_type': input.recurrenceType?.wireValue,
    'p_weekday': input.weekday,
    'p_day_of_month': input.dayOfMonth,
    'p_local_start_time': input.localStartTime,
    'p_duration_minutes': input.durationMinutes,
    'p_event_timezone': input.eventTimezone,
    'p_effective_from': input.effectiveFrom == null
        ? null
        : _date(input.effectiveFrom!),
    'p_registration_capacity': input.registrationCapacity,
    'p_count_organizers_toward_capacity': input.countOrganizersTowardCapacity,
  };

  PublicRecurringActivitySummary _publicSummaryFromRow(
    Map<String, dynamic> row,
    RecurringSchedule schedule,
    ProjectCapacitySnapshot capacity,
  ) => PublicRecurringActivitySummary(
    id: row['recurring_activity_id'] as String,
    title: row['title'] as String,
    summary: row['summary'] as String,
    topic: row['topic'] as String?,
    countryCode: row['country_code'] as String,
    locality: row['locality'] as String,
    administrativeArea: row['administrative_area'] as String?,
    publicLocationLabel: row['public_location_label'] as String,
    nextOccurrence: RecurringActivityOccurrence(
      startsAt: DateTime.parse(row['next_starts_at'] as String),
      endsAt: DateTime.parse(row['next_ends_at'] as String),
      eventTimezone: row['event_timezone'] as String,
    ),
    schedule: schedule,
    capacity: capacity,
    coverObjectPath: parseCoverObjectPath(
      row['cover_object_path'],
      parentId: row['recurring_activity_id'] as String,
      parentSegment: 'projects',
    ),
  );

  PublicRecurringActivityDetail _publicDetailFromRow(
    Map<String, dynamic> row,
    ProjectCapacitySnapshot capacity,
  ) => PublicRecurringActivityDetail(
    id: row['recurring_activity_id'] as String,
    creatorProfileId: row['creator_profile_id'] as String,
    creatorDisplayName: row['creator_display_name'] as String?,
    lifecycle: RecurringActivityLifecycle.fromWire(
      row['lifecycle_state'] as String,
    ),
    title: row['title'] as String,
    summary: row['summary'] as String,
    description: row['description'] as String,
    topic: row['topic'] as String?,
    countryCode: row['country_code'] as String,
    locality: row['locality'] as String,
    administrativeArea: row['administrative_area'] as String?,
    publicLocationLabel: row['public_location_label'] as String,
    schedule: _scheduleFromFlatRow(row),
    nextOccurrences: _occurrences(row['next_occurrences']),
    exactMeetingText: row['exact_meeting_text'] as String?,
    exactLocationRestricted: row['exact_location_restricted'] as bool,
    capacity: capacity,
    coverObjectPath: parseCoverObjectPath(
      row['cover_object_path'],
      parentId: row['recurring_activity_id'] as String,
      parentSegment: 'projects',
    ),
  );

  OwnRecurringActivity _ownActivityFromRow(
    Map<String, dynamic> row,
    ProjectCapacitySnapshot capacity,
  ) => OwnRecurringActivity(
    id: row['recurring_activity_id'] as String,
    lifecycle: RecurringActivityLifecycle.fromWire(
      row['lifecycle_state'] as String,
    ),
    title: row['title'] as String?,
    summary: row['summary'] as String?,
    description: row['description'] as String?,
    topic: row['topic'] as String?,
    countryCode: row['country_code'] as String?,
    locality: row['locality'] as String?,
    administrativeArea: row['administrative_area'] as String?,
    publicLocationLabel: row['public_location_label'] as String?,
    currentSchedule: row['current_schedule'] == null
        ? null
        : _scheduleFromJson(
            (row['current_schedule'] as Map).cast<String, dynamic>(),
          ),
    scheduleHistory: _schedules(row['schedule_history']),
    exactMeetingText: row['exact_meeting_text'] as String?,
    exactLocationVisibility: RecurringExactLocationVisibility.fromWire(
      row['exact_location_visibility'] as String,
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    publishedAt: _optionalDate(row['published_at']),
    pausedAt: _optionalDate(row['paused_at']),
    resumedAt: _optionalDate(row['resumed_at']),
    endedAt: _optionalDate(row['ended_at']),
    capacity: capacity,
    coverObjectPath: parseCoverObjectPath(
      row['cover_object_path'],
      parentId: row['recurring_activity_id'] as String,
      parentSegment: 'projects',
    ),
  );

  Future<Map<String, ProjectCapacitySnapshot>> _publicCapacities(
    Iterable<String> projectIds,
  ) => _capacityMap('list_public_project_capacity_statuses', {
    'p_project_ids': projectIds.toList(growable: false),
  });

  Future<Map<String, ProjectCapacitySnapshot>> _structuralCapacities(
    String expectedProfileId,
    Iterable<String> projectIds,
  ) => _capacityMap('list_project_capacity_statuses_for_structural_actor', {
    'p_expected_profile_id': expectedProfileId,
    'p_project_ids': projectIds.toList(growable: false),
  });

  Future<Map<String, ProjectCapacitySnapshot>> _capacityMap(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      functionName,
      params: params,
    );
    return {
      for (final row in response.cast<Map<String, dynamic>>())
        row['project_id'] as String: ProjectCapacitySnapshot.fromRow(row),
    };
  }

  RecurringSchedule _scheduleFromFlatRow(Map<String, dynamic> row) =>
      RecurringSchedule(
        id: 'public',
        recurrenceType: RecurrenceType.fromWire(
          row['recurrence_type'] as String,
        ),
        weekday: row['weekday'] as int?,
        dayOfMonth: row['day_of_month'] as int?,
        localStartTime: row['local_start_time'] as String,
        durationMinutes: row['duration_minutes'] as int,
        eventTimezone: row['event_timezone'] as String,
        effectiveFrom: DateTime.parse(row['schedule_effective_from'] as String),
      );

  RecurringSchedule _scheduleFromJson(Map<String, dynamic> row) =>
      RecurringSchedule(
        id: row['id'] as String,
        recurrenceType: RecurrenceType.fromWire(
          row['recurrence_type'] as String,
        ),
        weekday: row['weekday'] as int?,
        dayOfMonth: row['day_of_month'] as int?,
        localStartTime: row['local_start_time'] as String,
        durationMinutes: row['duration_minutes'] as int,
        eventTimezone: row['event_timezone'] as String,
        effectiveFrom: DateTime.parse(row['effective_from'] as String),
        effectiveUntil: _optionalDate(row['effective_until']),
      );

  List<RecurringSchedule> _schedules(dynamic value) {
    if (value is! List) {
      throw const FormatException('Recurring schedule history was not a list.');
    }
    return value
        .map((item) => _scheduleFromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  List<RecurringActivityOccurrence> _occurrences(dynamic value) {
    if (value is! List) {
      throw const FormatException('Recurring occurrences were not a list.');
    }
    return value
        .map((item) {
          final row = (item as Map).cast<String, dynamic>();
          return RecurringActivityOccurrence(
            startsAt: DateTime.parse(row['starts_at'] as String),
            endsAt: DateTime.parse(row['ends_at'] as String),
            eventTimezone: row['event_timezone'] as String,
          );
        })
        .toList(growable: false);
  }

  DateTime? _optionalDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final recurringActivityGatewayProvider = Provider<RecurringActivityGateway>((
  ref,
) {
  return SupabaseRecurringActivityGateway(ref.watch(supabaseClientProvider));
});
