begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a1000000-0000-4000-8000-000000000001', 'recurring-a@planets.invalid'),
  ('a2000000-0000-4000-8000-000000000002', 'recurring-b@planets.invalid'),
  ('a3000000-0000-4000-8000-000000000003', 'recurring-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a1000000-0000-4000-8000-000000000001', 'Recurring Owner A'),
  ('a2000000-0000-4000-8000-000000000002', 'Recurring Owner B'),
  ('a3000000-0000-4000-8000-000000000003', null);
-- Legacy scenarios that exercise publication/participation intentionally satisfy
-- the 08A4A canonical-photo precondition; dedicated 08A4A tests cover absence.
insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/00000000-0000-4000-8000-000000000001.webp',
  'interactions'
from public.profiles as profile
where profile.display_name is not null
on conflict (profile_id) do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000003',
  true
);

select throws_ok(
  $$
    select public.create_recurring_activity_draft(
      'a3000000-0000-4000-8000-000000000003',
      null, null, null, null, null, null, null, null, null, 'participants',
      null, null, null, null, null, null, null
    )
  $$,
  '55000',
  'A complete profile is required to create, publish, or resume a recurring activity.',
  'an incomplete profile cannot create a recurring activity draft'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.partial_recurring_id',
  public.create_recurring_activity_draft(
    'a1000000-0000-4000-8000-000000000001',
    '  Early table idea  ',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    'participants',
    null,
    null,
    null,
    null,
    null,
    null,
    null
  )::text,
  true
);

select results_eq(
  $$
    select lifecycle_state, title
    from public.recurring_activities
    where id = current_setting('test.partial_recurring_id')::uuid
  $$,
  $$values ('draft'::text, 'Early table idea'::text)$$,
  'a complete-profile owner can save an incomplete trimmed draft without a schedule'
);
select is(
  (
    select count(*)
    from public.recurring_activity_schedules
    where recurring_activity_id = current_setting('test.partial_recurring_id')::uuid
  ),
  0::bigint,
  'an incomplete draft does not invent a recurrence schedule'
);
select throws_ok(
  $$
    select public.publish_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_recurring_id')::uuid
    )
  $$,
  '22023',
  'Published recurring activities require complete content, rough location, and exact meeting information.',
  'publication centrally rejects an incomplete recurring draft'
);

select throws_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_recurring_id')::uuid,
      'Invalid schedule', null, null, null, null, null, null, null, null,
      'participants', 'weekly', 3, null, '19:00'::time, 90,
      'Not/A_Real_Zone', '2026-01-01'::date
    )
  $$,
  '22023',
  'Recurring activity time zone must be a recognized IANA identifier.',
  'schedule updates validate IANA time zones centrally'
);
select is(
  (
    select title
    from public.recurring_activities
    where id = current_setting('test.partial_recurring_id')::uuid
  ),
  'Early table idea',
  'a rejected atomic schedule update leaves prior draft content unchanged'
);

select throws_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_recurring_id')::uuid,
      'Invalid monthly schedule', null, null, null, null, null, null, null, null,
      'participants', 'monthly', null, 29, '18:30'::time, 120,
      'Europe/Rome', '2026-01-01'::date
    )
  $$,
  '22023',
  'A monthly schedule requires one calendar day from 1 through 28.',
  'monthly recurrence is deliberately limited to calendar days 1 through 28'
);

select set_config(
  'test.weekly_recurring_id',
  public.create_recurring_activity_draft(
    'a1000000-0000-4000-8000-000000000001',
    '  Philosophy Table  ',
    '  Discuss one philosophical question every week.  ',
    '  A recurring local discussion with a rotating reading prompt.  ',
    '  Philosophy  ',
    'it',
    '  Trento  ',
    '  Povo  ',
    '  Trento · Povo  ',
    '  Private room beside the library entrance  ',
    'participants',
    'weekly',
    3,
    null,
    '19:00'::time,
    90,
    'Europe/Rome',
    '2026-01-01'::date
  )::text,
  true
);

select results_eq(
  $$
    select title, topic, country_code, locality, public_location_label
    from public.recurring_activities
    where id = current_setting('test.weekly_recurring_id')::uuid
  $$,
  $$
    values (
      'Philosophy Table'::text,
      'Philosophy'::text,
      'IT'::text,
      'Trento'::text,
      'Trento · Povo'::text
    )
  $$,
  'recurring content and rough location are canonically normalized'
);
select results_eq(
  $$
    select recurrence_type, weekday, day_of_month, local_start_time, duration_minutes
    from public.recurring_activity_schedules
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  $$,
  $$values ('weekly'::text, 3::smallint, null::smallint, '19:00'::time, 90)$$,
  'weekly recurrence stores one ISO weekday, local time, and duration'
);

select lives_ok(
  $$
    select public.publish_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'the owner can publish a valid weekly recurring activity'
);
select lives_ok(
  $$
    select public.publish_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'repeating recurring publication is idempotent'
);

reset role;

select is(
  (
    select count(*)
    from private.audit_events
    where action = 'recurring_activity.published'
      and target_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  1::bigint,
  'idempotent recurring publication creates one audit event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'recurring_activity.published'
      and payload ->> 'recurring_activity_id' =
        current_setting('test.weekly_recurring_id')
  ),
  1::bigint,
  'idempotent recurring publication creates one outbox event'
);
select is(
  (
    select position(
      'Private room' in coalesce(
        (
          select payload::text
          from private.outbox_events
          where event_type = 'recurring_activity.published'
            and payload ->> 'recurring_activity_id' =
              current_setting('test.weekly_recurring_id')
        ),
        ''
      )
    )
  ),
  0,
  'recurring outbox payloads never contain exact meeting information'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a2000000-0000-4000-8000-000000000002',
  true
);

select is(
  (
    select count(*)
    from public.recurring_activities
    where id = current_setting('test.weekly_recurring_id')::uuid
  ),
  0::bigint,
  'another authenticated user cannot directly read a recurring activity'
);
select is(
  (
    select count(*)
    from public.recurring_activity_meeting_details
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  0::bigint,
  'another authenticated user cannot directly read recurring exact meeting details'
);
select throws_ok(
  $$
    select public.update_own_recurring_activity(
      'a2000000-0000-4000-8000-000000000002',
      current_setting('test.weekly_recurring_id')::uuid,
      'Cross-account overwrite', 'Summary', 'Description', null,
      'IT', 'Trento', null, 'Trento', 'Leaked exact place', 'public',
      'weekly', 4, null, '20:00'::time, 60, 'Europe/Rome', '2099-01-01'
    )
  $$,
  '42501',
  'The current user does not own this recurring activity.',
  'cross-user recurring mutation is denied centrally'
);

select set_config(
  'test.user_b_recurring_id',
  public.create_recurring_activity_draft(
    'a2000000-0000-4000-8000-000000000002',
    'User B recurring draft', null, null, null, null, null, null, null, null,
    'participants', null, null, null, null, null, null, null
  )::text,
  true
);
select throws_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.user_b_recurring_id')::uuid,
      'Stale user A content', null, null, null, null, null, null, null, null,
      'participants', null, null, null, null, null, null, null
    )
  $$,
  '42501',
  'The authenticated user does not match the expected recurring activity creator.',
  'a stale user-A form cannot mutate newly authenticated user-B recurring data'
);
select is(
  (
    select title
    from public.recurring_activities
    where id = current_setting('test.user_b_recurring_id')::uuid
  ),
  'User B recurring draft',
  'stale recurring form rejection leaves the newly authenticated account unchanged'
);

reset role;
set local role anon;

select throws_ok(
  'select id from public.recurring_activities',
  '42501',
  'permission denied for table recurring_activities',
  'anonymous users cannot enumerate recurring activity rows directly'
);
select throws_ok(
  'select exact_meeting_text from public.recurring_activity_meeting_details',
  '42501',
  'permission denied for table recurring_activity_meeting_details',
  'anonymous users cannot enumerate recurring exact meeting rows directly'
);
select is(
  (
    select count(*)
    from public.list_public_recurring_activities(
      '2026-03-24 00:00:00+00',
      20,
      null,
      null,
      ' trento '
    )
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  1::bigint,
  'a published weekly Tavolo appears in locality-filtered signed-out discovery'
);
select results_eq(
  $$
    select next_starts_at, next_ends_at, event_timezone
    from public.list_public_recurring_activities(
      '2026-03-24 00:00:00+00',
      20,
      null,
      null,
      null
    )
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  $$,
  $$
    values (
      '2026-03-25 18:00:00+00'::timestamptz,
      '2026-03-25 19:30:00+00'::timestamptz,
      'Europe/Rome'::text
    )
  $$,
  'public discovery derives the next weekly occurrence and duration'
);
select is(
  (
    select position(
      'Private room' in row_to_json(public_activity)::text
    )
    from public.list_public_recurring_activities(
      '2026-03-24 00:00:00+00',
      20,
      null,
      null,
      null
    ) as public_activity
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  0,
  'public recurring cards never contain exact meeting information'
);
select results_eq(
  $$
    select lifecycle_state, exact_meeting_text, exact_location_restricted
    from public.get_public_recurring_activity(
      current_setting('test.weekly_recurring_id')::uuid,
      5,
      '2026-03-24 00:00:00+00'
    )
  $$,
  $$values ('published'::text, null::text, true)$$,
  'restricted public detail returns an indicator without the exact value'
);
select is(
  (
    select position('Private room' in row_to_json(public_detail)::text)
    from public.get_public_recurring_activity(
      current_setting('test.weekly_recurring_id')::uuid,
      5,
      '2026-03-24 00:00:00+00'
    ) as public_detail
  ),
  0,
  'restricted recurring exact meeting content is absent from the full public payload'
);

select results_eq(
  $$
    select local_starts_at, starts_at
    from public.list_public_recurring_activity_occurrences(
      current_setting('test.weekly_recurring_id')::uuid,
      '2026-03-24 00:00:00+00',
      '2026-04-02 00:00:00+00',
      10
    )
    order by starts_at
  $$,
  $$
    values
      ('2026-03-25 19:00:00'::timestamp, '2026-03-25 18:00:00+00'::timestamptz),
      ('2026-04-01 19:00:00'::timestamp, '2026-04-01 17:00:00+00'::timestamptz)
  $$,
  'weekly wall-clock time remains 19:00 while the UTC offset changes across spring DST'
);
select results_eq(
  $$
    select local_starts_at, starts_at
    from public.list_public_recurring_activity_occurrences(
      current_setting('test.weekly_recurring_id')::uuid,
      '2026-10-20 00:00:00+00',
      '2026-10-30 00:00:00+00',
      10
    )
    order by starts_at
  $$,
  $$
    values
      ('2026-10-21 19:00:00'::timestamp, '2026-10-21 17:00:00+00'::timestamptz),
      ('2026-10-28 19:00:00'::timestamp, '2026-10-28 18:00:00+00'::timestamptz)
  $$,
  'weekly wall-clock time remains 19:00 while the UTC offset changes across autumn DST'
);
select throws_ok(
  $$
    select *
    from public.list_public_recurring_activity_occurrences(
      current_setting('test.weekly_recurring_id')::uuid,
      '2026-01-01 00:00:00+00',
      '2031-01-02 00:00:00+00',
      10
    )
  $$,
  '22023',
  'Occurrence windows cannot exceed five years.',
  'occurrence derivation rejects unbounded windows'
);
select throws_ok(
  $$
    select *
    from public.list_public_recurring_activity_occurrences(
      current_setting('test.weekly_recurring_id')::uuid,
      '2026-01-01 00:00:00+00',
      '2026-02-01 00:00:00+00',
      101
    )
  $$,
  '22023',
  'Occurrence limits must be between 1 and 100.',
  'occurrence derivation rejects excessive row limits'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select is(
  (
    select exact_meeting_text
    from public.get_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  ),
  'Private room beside the library entrance',
  'the creator can read participant-restricted recurring meeting information'
);

select set_config(
  'test.monthly_recurring_id',
  public.create_recurring_activity_draft(
    'a1000000-0000-4000-8000-000000000001',
    'Monthly culture table',
    'Meet monthly to discuss local cultural initiatives.',
    'An open-ended monthly exchange about events and shared projects.',
    'Culture',
    'IT',
    'Trento',
    'Centro storico',
    'Trento · Centro storico',
    'Piazza Pubblica, beside the fountain',
    'public',
    'monthly',
    null,
    12,
    '18:30'::time,
    120,
    'Europe/Rome',
    '2026-01-01'::date
  )::text,
  true
);
select lives_ok(
  $$
    select public.publish_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.monthly_recurring_id')::uuid
    )
  $$,
  'the owner can publish a valid monthly recurring activity'
);

reset role;
set local role anon;

select results_eq(
  $$
    select local_starts_at
    from public.list_public_recurring_activity_occurrences(
      current_setting('test.monthly_recurring_id')::uuid,
      '2026-01-01 00:00:00+00',
      '2026-04-01 00:00:00+00',
      10
    )
    order by starts_at
  $$,
  $$
    values
      ('2026-01-12 18:30:00'::timestamp),
      ('2026-02-12 18:30:00'::timestamp),
      ('2026-03-12 18:30:00'::timestamp)
  $$,
  'monthly recurrence derives the configured calendar day and local time'
);
select results_eq(
  $$
    select exact_meeting_text, exact_location_restricted
    from public.get_public_recurring_activity(
      current_setting('test.monthly_recurring_id')::uuid,
      3,
      '2026-01-01 00:00:00+00'
    )
  $$,
  $$values ('Piazza Pubblica, beside the fountain'::text, false)$$,
  'public exact meeting text is exposed only through intended exact-ID detail'
);
select is(
  (
    select position(
      'Piazza Pubblica' in row_to_json(public_activity)::text
    )
    from public.list_public_recurring_activities(
      '2026-01-01 00:00:00+00',
      20,
      null,
      null,
      null
    ) as public_activity
    where recurring_activity_id = current_setting('test.monthly_recurring_id')::uuid
  ),
  0,
  'even public exact recurring location never appears on discovery cards'
);

select is(
  (
    select count(*)
    from public.list_public_recurring_activities(
      '2026-01-01 00:00:00+00',
      1,
      null,
      null,
      null
    )
  ),
  1::bigint,
  'public recurring discovery honors the bounded page size'
);
select throws_ok(
  $$
    select *
    from public.list_public_recurring_activities(null)
  $$,
  '22023',
  'Recurring activity discovery requires a reference time.',
  'public recurring discovery requires an explicit reference-time snapshot'
);
select results_eq(
  $$
    select recurring_activity_id, next_starts_at
    from public.list_public_recurring_activities(
      '2026-01-01 00:00:00+00',
      1,
      null,
      null,
      null
    )
  $$,
  $$
    select
      current_setting('test.weekly_recurring_id')::uuid,
      '2026-01-07 18:00:00+00'::timestamptz
  $$,
  'page one derives its cursor from the caller-owned reference-time snapshot'
);
select results_eq(
  $$
    select recurring_activity_id, next_starts_at
    from public.list_public_recurring_activities(
      '2026-01-01 00:00:00+00',
      1,
      '2026-01-07 18:00:00+00',
      current_setting('test.weekly_recurring_id')::uuid,
      null
    )
  $$,
  $$
    select
      current_setting('test.monthly_recurring_id')::uuid,
      '2026-01-12 17:30:00+00'::timestamptz
  $$,
  'page two reuses the page-one snapshot so a crossed occurrence boundary cannot duplicate or skip rows'
);
select throws_ok(
  $$
    select *
    from public.list_public_recurring_activities(
      '2026-01-01 00:00:00+00',
      51,
      null,
      null,
      null
    )
  $$,
  '22023',
  'Recurring activity page size must be between 1 and 50.',
  'public recurring discovery rejects an excessive page size'
);
select throws_ok(
  $$
    select *
    from public.list_public_recurring_activities(
      '2026-01-01 00:00:00+00',
      20,
      '2026-01-12 17:30:00+00',
      null,
      null
    )
  $$,
  '22023',
  'Recurring activity cursor values must be supplied together.',
  'public recurring discovery rejects a partial cursor'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid,
      'Philosophy Table',
      'Discuss one philosophical question every week.',
      'A recurring local discussion with a rotating reading prompt.',
      'Philosophy',
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo',
      'Private room beside the library entrance',
      'participants',
      'weekly',
      4,
      null,
      '20:00'::time,
      90,
      'Europe/Rome',
      current_date
    )
  $$,
  '22023',
  'A published schedule change must begin on a future local date after the current version.',
  'published schedule changes cannot rewrite the current or past local date'
);

select lives_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid,
      'Philosophy Table',
      'Discuss one philosophical question every week.',
      'A recurring local discussion with a rotating reading prompt.',
      'Philosophy',
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo',
      'Private room beside the library entrance',
      'participants',
      'weekly',
      4,
      null,
      '20:00'::time,
      90,
      'Europe/Rome',
      '2099-01-01'::date
    )
  $$,
  'a future published schedule change succeeds atomically'
);

select is(
  (
    select count(*)
    from public.recurring_activity_schedules
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  2::bigint,
  'a published schedule change creates a second version instead of overwriting history'
);
select results_eq(
  $$
    select local_start_time, effective_from, effective_until, superseded_at is not null
    from public.recurring_activity_schedules
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
    order by effective_from
  $$,
  $$
    values
      ('19:00'::time, '2026-01-01'::date, '2099-01-01'::date, true),
      ('20:00'::time, '2099-01-01'::date, null::date, false)
  $$,
  'schedule versioning closes the prior local-date range and preserves its original wall time'
);
select is(
  (
    select jsonb_array_length(schedule_history)
    from public.get_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  ),
  2,
  'owner detail exposes schedule history needed for safe future editing'
);

select lives_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid,
      'Philosophy Table',
      'Discuss one philosophical question every week.',
      'A recurring local discussion with a rotating reading prompt.',
      'Philosophy',
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo',
      'Private room beside the library entrance',
      'participants',
      'weekly',
      4,
      null,
      '21:00'::time,
      90,
      'Europe/Rome',
      '2099-01-01'::date
    )
  $$,
  'a pending future schedule can be corrected at its existing effective date'
);
select is(
  (
    select count(*)
    from public.recurring_activity_schedules
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  2::bigint,
  'correcting a pending schedule does not create a redundant history version'
);
select results_eq(
  $$
    select local_start_time, effective_from, effective_until, superseded_at is not null
    from public.recurring_activity_schedules
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
    order by effective_from
  $$,
  $$
    values
      ('19:00'::time, '2026-01-01'::date, '2099-01-01'::date, true),
      ('21:00'::time, '2099-01-01'::date, null::date, false)
  $$,
  'pending correction preserves the already-effective version and updates only the future row'
);

reset role;

select throws_ok(
  format(
    $sql$
      insert into public.recurring_activity_schedules (
        recurring_activity_id,
        recurrence_type,
        weekday,
        local_start_time,
        duration_minutes,
        event_timezone,
        effective_from,
        effective_until,
        superseded_at
      )
      values (
        %L::uuid,
        'weekly',
        2,
        '17:00'::time,
        60,
        'Europe/Rome',
        '2030-01-01'::date,
        '2031-01-01'::date,
        statement_timestamp()
      )
    $sql$,
    current_setting('test.weekly_recurring_id')
  ),
  '23P01',
  'Recurring activity schedule versions cannot overlap.',
  'the database rejects overlapping schedule effective ranges even outside client operations'
);
select is(
  (
    select count(*)
    from private.audit_events
    where action = 'recurring_activity.schedule_changed'
      and target_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  2::bigint,
  'initial scheduling and pending correction each record one audit event'
);
select is(
  (
    select coalesce(bool_or(payload::text like '%Private room%'), false)
    from private.outbox_events
    where event_type = 'recurring_activity.schedule_changed'
      and payload ->> 'recurring_activity_id' =
        current_setting('test.weekly_recurring_id')
  ),
  false,
  'schedule-change outbox metadata contains no meeting or description content'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$
    select public.pause_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'the owner can pause a published recurring activity'
);
select lives_ok(
  $$
    select public.pause_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'repeating pause is idempotent'
);

reset role;
select is(
  (
    select count(*)
    from private.audit_events
    where action = 'recurring_activity.paused'
      and target_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  1::bigint,
  'idempotent pause records one audit event'
);

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_recurring_activities(
      '2026-03-24 00:00:00+00',
      20,
      null,
      null,
      null
    )
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  0::bigint,
  'pausing immediately removes a Tavolo from normal discovery'
);
select results_eq(
  $$
    select lifecycle_state, next_occurrences, exact_meeting_text, exact_location_restricted
    from public.get_public_recurring_activity(
      current_setting('test.weekly_recurring_id')::uuid,
      5,
      '2026-03-24 00:00:00+00'
    )
  $$,
  $$values ('paused'::text, '[]'::jsonb, null::text, true)$$,
  'paused exact-ID detail remains public, sanitized, and has no active occurrences'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$
    select public.resume_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'the owner can resume a paused recurring activity with a future occurrence'
);
select lives_ok(
  $$
    select public.resume_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'repeating resume is idempotent'
);

reset role;
select is(
  (
    select count(*)
    from private.audit_events
    where action = 'recurring_activity.resumed'
      and target_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  1::bigint,
  'idempotent resume records one audit event'
);

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_recurring_activities(
      '2026-03-24 00:00:00+00',
      20,
      null,
      null,
      null
    )
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  1::bigint,
  'resuming returns the Tavolo to normal discovery'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$
    select public.end_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'the owner can terminally end a published recurring activity'
);
select lives_ok(
  $$
    select public.end_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  'repeating end is idempotent'
);
select throws_ok(
  $$
    select public.resume_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid
    )
  $$,
  '55000',
  'Only a paused recurring activity can be resumed.',
  'an ended recurring activity cannot be resumed'
);
select throws_ok(
  $$
    select public.update_own_recurring_activity(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.weekly_recurring_id')::uuid,
      'Late rewrite', 'Summary', 'Description', null,
      'IT', 'Trento', null, 'Trento', 'Meeting', 'participants',
      'weekly', 4, null, '20:00'::time, 90, 'Europe/Rome', '2099-01-01'
    )
  $$,
  '55000',
  'An ended recurring activity is immutable.',
  'ended recurring activity content and schedule are immutable'
);

reset role;
select is(
  (
    select count(*)
    from private.audit_events
    where action = 'recurring_activity.ended'
      and target_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  1::bigint,
  'idempotent end records one audit event'
);

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_recurring_activities(
      '2026-03-24 00:00:00+00',
      20,
      null,
      null,
      null
    )
    where recurring_activity_id = current_setting('test.weekly_recurring_id')::uuid
  ),
  0::bigint,
  'ending permanently removes a Tavolo from normal discovery'
);
select results_eq(
  $$
    select lifecycle_state, next_occurrences, exact_meeting_text, exact_location_restricted
    from public.get_public_recurring_activity(
      current_setting('test.weekly_recurring_id')::uuid,
      5,
      '2026-03-24 00:00:00+00'
    )
  $$,
  $$values ('ended'::text, '[]'::jsonb, null::text, true)$$,
  'ended exact-ID detail remains historical and sanitized without active occurrences'
);

select * from finish();

rollback;
