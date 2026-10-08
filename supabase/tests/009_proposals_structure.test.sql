begin;

select no_plan();

select has_table('public', 'proposals', 'one-time proposals exist');
select has_table(
  'public',
  'proposal_meeting_details',
  'exact meeting information has its own table'
);
select has_table('public', 'proposal_skills', 'proposal skills are normalized');

select columns_are(
  'public',
  'proposals',
  array[
    'id',
    'creator_profile_id',
    'lifecycle_state',
    'title',
    'summary',
    'description',
    'starts_at',
    'ends_at',
    'event_timezone',
    'country_code',
    'locality',
    'administrative_area',
    'public_location_label',
    'approximate_location',
    'created_at',
    'updated_at',
    'published_at',
    'cancelled_at',
    'selected_public_place',
    'location_revision'
  ],
  'proposal rows contain lifecycle, content, schedule, and rough location only'
);
select columns_are(
  'public',
  'proposal_meeting_details',
  array[
    'proposal_id',
    'exact_meeting_text',
    'exact_location_visibility',
    'exact_location',
    'updated_at',
    'selected_exact_place'
  ],
  'exact meeting information is physically separate from rough location'
);
select columns_are(
  'public',
  'proposal_skills',
  array['proposal_id', 'skill_id', 'importance', 'created_at'],
  'proposal skill rows contain only the controlled relationship'
);

select col_is_pk('public', 'proposals', 'id', 'proposal IDs are primary keys');
select col_type_is('public', 'proposals', 'id', 'uuid', 'proposal IDs are UUIDs');
select col_is_pk(
  'public',
  'proposal_meeting_details',
  'proposal_id',
  'meeting details are one-to-one with a proposal'
);
select has_pk('public', 'proposal_skills', 'proposal skills have a composite key');
select col_type_is(
  'public',
  'proposals',
  'starts_at',
  'timestamp with time zone',
  'proposal start time is timezone-aware'
);
select col_type_is(
  'public',
  'proposals',
  'ends_at',
  'timestamp with time zone',
  'proposal end time is timezone-aware'
);
select ok(
  (
    select attribute.atttypid = 'extensions.geography'::regtype
    from pg_attribute as attribute
    where attribute.attrelid = 'public.proposals'::regclass
      and attribute.attname = 'approximate_location'
  ),
  'rough points use the existing PostGIS geography type'
);
select ok(
  (
    select attribute.atttypid = 'extensions.geography'::regtype
    from pg_attribute as attribute
    where attribute.attrelid = 'public.proposal_meeting_details'::regclass
      and attribute.attname = 'exact_location'
  ),
  'future exact points remain in the protected meeting record'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.proposals'::regclass
      and conname = 'proposals_lifecycle_state_valid'
      and contype = 'c'
  ),
  'stored proposal lifecycle values are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.proposals'::regclass
      and conname = 'proposals_schedule_order_valid'
      and contype = 'c'
  ),
  'proposal schedule ordering is constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.proposal_meeting_details'::regclass
      and conname = 'proposal_meeting_details_visibility_valid'
      and contype = 'c'
  ),
  'exact location visibility is constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.proposal_skills'::regclass
      and conname = 'proposal_skills_importance_valid'
      and contype = 'c'
  ),
  'proposal skill importance is constrained'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.proposals'::regclass),
  true,
  'proposals have RLS enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.proposal_meeting_details'::regclass
  ),
  true,
  'meeting details have RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.proposal_skills'::regclass),
  true,
  'proposal skills have RLS enabled'
);
select is(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'proposals'),
  1::bigint,
  'proposals expose only the creator read policy'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public' and tablename = 'proposal_meeting_details'
  ),
  1::bigint,
  'meeting details expose only the creator read policy'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public' and tablename = 'proposal_skills'
  ),
  1::bigint,
  'proposal skills expose only the creator read policy'
);

select ok(
  to_regclass('public.proposals_creator_profile_id_created_at_idx') is not null,
  'owner proposal history has a supporting index'
);
select ok(
  to_regclass('public.proposals_published_starts_at_id_idx') is not null,
  'public discovery has a deterministic partial ordering index'
);
select ok(
  to_regclass('public.proposals_published_locality_starts_at_id_idx') is not null,
  'locality-filtered discovery has a partial index'
);
select ok(
  to_regclass('public.proposal_skills_skill_id_proposal_id_idx') is not null,
  'skill filtering and reverse foreign-key lookup are indexed'
);
select is(
  (
    select lower(pg_get_expr(i.indpred, i.indrelid))
    from pg_index as i
    where i.indexrelid = 'public.proposals_published_starts_at_id_idx'::regclass
  ),
  '(lifecycle_state = ''published''::text)',
  'the public ordering index contains only published proposals'
);

select ok(
  to_regprocedure('public.create_proposal_draft(uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])') is not null,
  'the canonical draft creation operation exists'
);
select ok(
  to_regprocedure('public.update_own_proposal(uuid,uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])') is not null,
  'the canonical atomic update operation exists'
);
select ok(
  to_regprocedure('public.publish_proposal(uuid,uuid)') is not null,
  'the canonical publish operation exists'
);
select ok(
  to_regprocedure('public.cancel_proposal(uuid,uuid)') is not null,
  'the canonical cancel operation exists'
);
select ok(
  to_regprocedure('public.list_public_proposals(integer,timestamptz,uuid,text,uuid[],text)') is not null,
  'the sanitized public list operation exists'
);
select ok(
  to_regprocedure('public.get_public_proposal(uuid)') is not null,
  'the sanitized exact-ID public detail operation exists'
);
select ok(
  to_regprocedure('public.list_own_proposals(uuid)') is not null,
  'the owner history operation exists'
);
select ok(
  to_regprocedure('public.get_own_proposal(uuid,uuid)') is not null,
  'the owner edit read operation exists'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.create_proposal_draft(uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])'::regprocedure,
      'public.update_own_proposal(uuid,uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])'::regprocedure,
      'public.publish_proposal(uuid,uuid)'::regprocedure,
      'public.cancel_proposal(uuid,uuid)'::regprocedure,
      'public.list_public_proposals(integer,timestamptz,uuid,text,uuid[],text)'::regprocedure,
      'public.get_public_proposal(uuid)'::regprocedure,
      'public.list_own_proposals(uuid)'::regprocedure,
      'public.get_own_proposal(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'client proposal operations deliberately use hardened security definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.create_proposal_draft(uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])'::regprocedure,
      'public.update_own_proposal(uuid,uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])'::regprocedure,
      'public.publish_proposal(uuid,uuid)'::regprocedure,
      'public.cancel_proposal(uuid,uuid)'::regprocedure,
      'public.list_public_proposals(integer,timestamptz,uuid,text,uuid[],text)'::regprocedure,
      'public.get_public_proposal(uuid)'::regprocedure,
      'public.list_own_proposals(uuid)'::regprocedure,
      'public.get_own_proposal(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'every proposal API operation has an empty fixed search path'
);

select is(
  has_function_privilege('anon', 'public.list_public_proposals(integer,timestamptz,uuid,text,uuid[],text)', 'EXECUTE'),
  true,
  'anonymous users can call the sanitized proposal list'
);
select is(
  has_function_privilege('anon', 'public.get_public_proposal(uuid)', 'EXECUTE'),
  true,
  'anonymous users can call sanitized proposal detail'
);
select is(
  has_function_privilege('anon', 'public.create_proposal_draft(uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])', 'EXECUTE'),
  false,
  'anonymous users cannot create drafts'
);
select is(
  has_function_privilege('authenticated', 'public.create_proposal_draft(uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[])', 'EXECUTE'),
  true,
  'authenticated users can call draft creation'
);
select is(
  has_function_privilege('authenticated', 'public.list_own_proposals(uuid)', 'EXECUTE'),
  true,
  'authenticated users can call the owner history boundary'
);
select is(
  has_function_privilege('service_role', 'public.get_public_proposal(uuid)', 'EXECUTE'),
  false,
  'service role receives no convenience proposal API grant'
);

select is(
  (
    select bool_or(
      has_table_privilege('anon', table_name, privilege_name)
    )
    from unnest(
      array[
        'public.proposals',
        'public.proposal_meeting_details',
        'public.proposal_skills'
      ]
    ) as tables(table_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'anonymous users receive no direct proposal-table privilege'
);
select is(
  (
    select bool_or(
      has_table_privilege('authenticated', table_name, privilege_name)
    )
    from unnest(
      array[
        'public.proposals',
        'public.proposal_meeting_details',
        'public.proposal_skills'
      ]
    ) as tables(table_name)
    cross join unnest(array['INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'authenticated clients cannot mutate proposal tables directly'
);

select * from finish();

rollback;
