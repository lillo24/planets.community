begin;

select no_plan();

select has_table(
  'public',
  'recurring_activities',
  'recurring activities have a dedicated series table'
);
select has_table(
  'public',
  'recurring_activity_schedules',
  'recurring schedules have a version-history table'
);
select has_table(
  'public',
  'recurring_activity_meeting_details',
  'exact recurring meeting information has a separate table'
);

select columns_are(
  'public',
  'recurring_activities',
  array[
    'id',
    'creator_profile_id',
    'lifecycle_state',
    'title',
    'summary',
    'description',
    'topic',
    'country_code',
    'locality',
    'administrative_area',
    'public_location_label',
    'approximate_location',
    'created_at',
    'updated_at',
    'published_at',
    'paused_at',
    'resumed_at',
    'ended_at',
    'selected_public_place',
    'location_revision'
  ],
  'series rows contain content, lifecycle, and rough location without one-time timestamps'
);
select columns_are(
  'public',
  'recurring_activity_schedules',
  array[
    'id',
    'recurring_activity_id',
    'recurrence_type',
    'weekday',
    'day_of_month',
    'local_start_time',
    'duration_minutes',
    'event_timezone',
    'effective_from',
    'effective_until',
    'created_at',
    'superseded_at'
  ],
  'schedule versions preserve local recurrence and effective boundaries'
);
select columns_are(
  'public',
  'recurring_activity_meeting_details',
  array[
    'recurring_activity_id',
    'exact_meeting_text',
    'exact_location_visibility',
    'exact_location',
    'updated_at',
    'selected_exact_place'
  ],
  'exact meeting information is physically separate from public rough location'
);

select col_is_pk(
  'public',
  'recurring_activities',
  'id',
  'recurring activity IDs are primary keys'
);
select col_type_is(
  'public',
  'recurring_activities',
  'id',
  'uuid',
  'recurring activity IDs are UUIDs'
);
select col_is_pk(
  'public',
  'recurring_activity_schedules',
  'id',
  'schedule versions have stable UUID identities'
);
select col_is_pk(
  'public',
  'recurring_activity_meeting_details',
  'recurring_activity_id',
  'meeting details are one-to-one with a recurring activity'
);
select col_type_is(
  'public',
  'recurring_activity_schedules',
  'local_start_time',
  'time without time zone',
  'recurrence stores local wall-clock time rather than a UTC instant'
);
select col_type_is(
  'public',
  'recurring_activity_schedules',
  'effective_from',
  'date',
  'schedule boundaries are local dates'
);
select ok(
  (
    select attribute.atttypid = 'extensions.geography'::regtype
    from pg_attribute as attribute
    where attribute.attrelid = 'public.recurring_activities'::regclass
      and attribute.attname = 'approximate_location'
  ),
  'rough recurring points use the existing PostGIS geography type'
);
select ok(
  (
    select attribute.atttypid = 'extensions.geography'::regtype
    from pg_attribute as attribute
    where attribute.attrelid = 'public.recurring_activity_meeting_details'::regclass
      and attribute.attname = 'exact_location'
  ),
  'exact recurring points remain in the protected meeting record'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.recurring_activities'::regclass
      and conname = 'recurring_activities_lifecycle_state_valid'
      and contype = 'c'
  ),
  'recurring lifecycle values are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.recurring_activity_schedules'::regclass
      and conname = 'recurring_activity_schedules_pattern_valid'
      and contype = 'c'
  ),
  'weekly versus monthly schedule shapes are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.recurring_activity_schedules'::regclass
      and conname = 'recurring_activity_schedules_effective_range_valid'
      and contype = 'c'
  ),
  'schedule effective ranges are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.recurring_activity_meeting_details'::regclass
      and conname = 'recurring_activity_meeting_details_visibility_valid'
      and contype = 'c'
  ),
  'exact recurring location visibility is constrained'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.recurring_activities'::regclass
  ),
  true,
  'recurring activities have RLS enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.recurring_activity_schedules'::regclass
  ),
  true,
  'recurring schedules have RLS enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.recurring_activity_meeting_details'::regclass
  ),
  true,
  'recurring meeting details have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public' and tablename = 'recurring_activities'
      -- 112 independently verifies the added global restrictive account gate.
      and policyname <> 'account_active_required'
  ),
  1::bigint,
  'recurring activities expose only the creator read policy'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public' and tablename = 'recurring_activity_schedules'
      and policyname <> 'account_active_required'
  ),
  1::bigint,
  'recurring schedules expose only the creator read policy'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'recurring_activity_meeting_details'
      and policyname <> 'account_active_required'
  ),
  1::bigint,
  'recurring meeting details expose only the creator read policy'
);

select ok(
  to_regclass('public.recurring_activities_creator_created_at_idx') is not null,
  'owner recurring activity history has a supporting index'
);
select ok(
  to_regclass('public.recurring_activities_published_locality_id_idx') is not null,
  'published locality discovery has a partial index'
);
select ok(
  to_regclass('public.recurring_activity_schedules_activity_effective_idx') is not null,
  'schedule history and foreign-key lookups are indexed'
);
select ok(
  to_regclass('public.recurring_activity_schedules_one_open_idx') is not null,
  'each recurring activity can have only one latest open schedule version'
);
select is(
  (
    select lower(pg_get_expr(index_definition.indpred, index_definition.indrelid))
    from pg_index as index_definition
    where index_definition.indexrelid =
      'public.recurring_activity_schedules_one_open_idx'::regclass
  ),
  '(effective_until is null)',
  'the latest-schedule uniqueness index contains only open versions'
);

select ok(
  to_regprocedure('public.create_recurring_activity_draft(uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)') is not null,
  'the canonical recurring draft operation exists'
);
select ok(
  to_regprocedure('public.update_own_recurring_activity(uuid,uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)') is not null,
  'the canonical expected-owner recurring update exists'
);
select ok(
  to_regprocedure('public.publish_recurring_activity(uuid,uuid)') is not null,
  'the recurring publish transition exists'
);
select ok(
  to_regprocedure('public.pause_recurring_activity(uuid,uuid)') is not null,
  'the recurring pause transition exists'
);
select ok(
  to_regprocedure('public.resume_recurring_activity(uuid,uuid)') is not null,
  'the recurring resume transition exists'
);
select ok(
  to_regprocedure('public.end_recurring_activity(uuid,uuid)') is not null,
  'the recurring terminal end transition exists'
);
select ok(
  to_regprocedure('public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)') is not null,
  'the sanitized public recurring list exists'
);
select ok(
  (
    select proargnames[1] = 'p_reference_time'
      and pronargdefaults = 4
    from pg_proc
    where oid = 'public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)'::regprocedure
  ),
  'the public recurring list requires one snapshot while retaining optional page and filter arguments'
);
select ok(
  to_regprocedure('public.list_public_recurring_activity_occurrences(uuid,timestamptz,timestamptz,integer)') is not null,
  'the bounded public occurrence window exists'
);
select ok(
  to_regprocedure('public.get_public_recurring_activity(uuid,integer,timestamptz)') is not null,
  'the sanitized exact-ID recurring detail exists'
);
select ok(
  to_regprocedure('public.list_own_recurring_activities(uuid)') is not null,
  'the recurring owner history operation exists'
);
select ok(
  to_regprocedure('public.get_own_recurring_activity(uuid,uuid)') is not null,
  'the recurring owner edit read exists'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.create_recurring_activity_draft(uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)'::regprocedure,
      'public.update_own_recurring_activity(uuid,uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)'::regprocedure,
      'public.publish_recurring_activity(uuid,uuid)'::regprocedure,
      'public.pause_recurring_activity(uuid,uuid)'::regprocedure,
      'public.resume_recurring_activity(uuid,uuid)'::regprocedure,
      'public.end_recurring_activity(uuid,uuid)'::regprocedure,
      'public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)'::regprocedure,
      'public.list_public_recurring_activity_occurrences(uuid,timestamptz,timestamptz,integer)'::regprocedure,
      'public.get_public_recurring_activity(uuid,integer,timestamptz)'::regprocedure,
      'public.list_own_recurring_activities(uuid)'::regprocedure,
      'public.get_own_recurring_activity(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all recurring client operations use deliberate security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.create_recurring_activity_draft(uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)'::regprocedure,
      'public.update_own_recurring_activity(uuid,uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)'::regprocedure,
      'public.publish_recurring_activity(uuid,uuid)'::regprocedure,
      'public.pause_recurring_activity(uuid,uuid)'::regprocedure,
      'public.resume_recurring_activity(uuid,uuid)'::regprocedure,
      'public.end_recurring_activity(uuid,uuid)'::regprocedure,
      'public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)'::regprocedure,
      'public.list_public_recurring_activity_occurrences(uuid,timestamptz,timestamptz,integer)'::regprocedure,
      'public.get_public_recurring_activity(uuid,integer,timestamptz)'::regprocedure,
      'public.list_own_recurring_activities(uuid)'::regprocedure,
      'public.get_own_recurring_activity(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all recurring API operations have an empty fixed search path'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)',
    'EXECUTE'
  ),
  true,
  'anonymous users can call sanitized recurring discovery'
);
select is(
  has_function_privilege(
    'anon',
    'public.get_public_recurring_activity(uuid,integer,timestamptz)',
    'EXECUTE'
  ),
  true,
  'anonymous users can call sanitized recurring detail'
);
select is(
  has_function_privilege(
    'anon',
    'public.create_recurring_activity_draft(uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)',
    'EXECUTE'
  ),
  false,
  'anonymous users cannot create recurring drafts'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.create_recurring_activity_draft(uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time,integer,text,date)',
    'EXECUTE'
  ),
  true,
  'authenticated users can call recurring draft creation'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_recurring_activities(uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated users can call recurring owner history'
);
select is(
  has_function_privilege(
    'service_role',
    'public.get_public_recurring_activity(uuid,integer,timestamptz)',
    'EXECUTE'
  ),
  false,
  'service role receives no convenience recurring API grant'
);

select is(
  (
    select bool_or(has_table_privilege('anon', table_name, privilege_name))
    from unnest(
      array[
        'public.recurring_activities',
        'public.recurring_activity_schedules',
        'public.recurring_activity_meeting_details'
      ]
    ) as tables(table_name)
    cross join unnest(
      array['SELECT', 'INSERT', 'UPDATE', 'DELETE']
    ) as privileges(privilege_name)
  ),
  false,
  'anonymous users receive no direct recurring-table privilege'
);
select is(
  (
    select bool_or(
      has_table_privilege('authenticated', table_name, privilege_name)
    )
    from unnest(
      array[
        'public.recurring_activities',
        'public.recurring_activity_schedules',
        'public.recurring_activity_meeting_details'
      ]
    ) as tables(table_name)
    cross join unnest(
      array['INSERT', 'UPDATE', 'DELETE']
    ) as privileges(privilege_name)
  ),
  false,
  'authenticated clients cannot mutate recurring tables directly'
);

select * from finish();

rollback;
