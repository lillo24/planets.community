import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/time/event_time.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';

import '../../../support/fake_recurring_activity.dart';

void main() {
  test('weekly and monthly schedules enforce their constrained fields', () {
    expect(
      isPublishableRecurringActivityInput(recurringInputFixture()),
      isTrue,
    );
    expect(
      isPublishableRecurringActivityInput(
        recurringInputFixture(type: RecurrenceType.monthly),
      ),
      isTrue,
    );
    final invalidDay = RecurringActivityInput(
      title: 'Valid title',
      summary: 'Summary',
      description: 'Description',
      topic: '',
      countryCode: 'IT',
      locality: 'Bologna',
      administrativeArea: '',
      publicLocationLabel: 'Central Bologna',
      exactMeetingText: 'At the table',
      exactLocationVisibility: RecurringExactLocationVisibility.participants,
      recurrenceType: RecurrenceType.monthly,
      weekday: null,
      dayOfMonth: 29,
      localStartTime: '19:00:00',
      durationMinutes: 90,
      eventTimezone: 'Europe/Rome',
      effectiveFrom: DateTime(2026, 9, 5),
    );
    expect(isValidRecurringActivityDraft(invalidDay), isFalse);
  });

  test('an entirely absent schedule remains a valid incomplete draft', () {
    final input = recurringInputFixture(type: null);
    expect(input.hasAnyScheduleValue, isFalse);
    expect(isValidRecurringActivityDraft(input), isTrue);
    expect(isPublishableRecurringActivityInput(input), isFalse);
  });

  test('UTC alias and named event zones preserve wall-clock intent', () {
    expect(isKnownEventTimeZone('UTC'), isTrue);
    expect(isKnownEventTimeZone('Europe/Rome'), isTrue);
    expect(isKnownEventTimeZone('Mars/Olympus'), isFalse);
    expect(
      eventUtcToWallTime(DateTime.utc(2026, 7, 1, 17), 'Europe/Rome'),
      DateTime(2026, 7, 1, 19),
    );
  });

  test('effective schedule edits preserve history and pending correction', () {
    final now = DateTime.utc(2026, 9, 4, 10);
    final active = ownRecurringActivityFixture(
      lifecycle: RecurringActivityLifecycle.published,
    );
    expect(
      isValidRecurringScheduleTransition(
        active,
        recurringInputFixture(effectiveFrom: DateTime(2026, 9, 1)),
        now,
      ),
      isTrue,
    );
    final changedFuture = recurringInputFixture(
      type: RecurrenceType.monthly,
      effectiveFrom: DateTime(2026, 10, 12),
    );
    expect(
      isValidRecurringScheduleTransition(active, changedFuture, now),
      isTrue,
    );
    final pendingSchedule = recurringScheduleFixture(
      type: RecurrenceType.monthly,
      effectiveFrom: DateTime(2026, 10, 12),
    );
    final pending = ownRecurringActivityFixture(
      lifecycle: RecurringActivityLifecycle.published,
      schedule: pendingSchedule,
    );
    expect(pending.hasPendingScheduleAt(now), isTrue);
    expect(
      isValidRecurringScheduleTransition(pending, changedFuture, now),
      isTrue,
    );
    expect(
      isValidRecurringScheduleTransition(
        pending,
        recurringInputFixture(
          type: RecurrenceType.monthly,
          effectiveFrom: DateTime(2026, 10, 13),
        ),
        now,
      ),
      isFalse,
    );
  });
}
