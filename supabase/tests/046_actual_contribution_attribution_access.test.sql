begin;

select no_plan();

insert into auth.users (id, email)
values
  ('e5100000-0000-4000-8000-000000000001', 'actual-creator@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000002', 'actual-active@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000003', 'actual-unrelated@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000004', 'actual-left-before@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000005', 'actual-removed-before@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000006', 'actual-left-after@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000007', 'actual-removed-after@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000008', 'actual-exact-end@planets.invalid'),
  ('e5100000-0000-4000-8000-000000000009', 'actual-rejoin@planets.invalid');

insert into public.profiles (id, display_name)
select id, 'Actual profile ' || right(id::text, 2)
from auth.users
where id::text like 'e5100000-%';

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at,
  cancelled_at
)
values
  (
    'e5200000-0000-4000-8000-000000000001',
    'e5100000-0000-4000-8000-000000000001',
    'published',
    'Ended actual attribution',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '5 days',
    null
  ),
  (
    'e5200000-0000-4000-8000-000000000002',
    'e5100000-0000-4000-8000-000000000001',
    'published',
    'Future actual attribution',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'e5200000-0000-4000-8000-000000000003',
    'e5100000-0000-4000-8000-000000000001',
    'cancelled',
    'Cancelled actual attribution',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '5 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    'e5200000-0000-4000-8000-000000000004',
    'e5100000-0000-4000-8000-000000000001',
    'draft',
    'Draft actual attribution',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    null,
    null
  ),
  (
    'e5200000-0000-4000-8000-000000000005',
    'e5100000-0000-4000-8000-000000000001',
    'published',
    'Other ended project',
    statement_timestamp() - interval '3 days',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '5 days',
    null
  );

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at
)
values (
  'e5200000-0000-4000-8000-000000000006',
  'e5100000-0000-4000-8000-000000000001',
  'published',
  'Recurring actual attribution',
  statement_timestamp() - interval '5 days'
);

insert into public.proposal_skills (proposal_id, skill_id, importance)
values
  (
    'e5200000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8001-000000000001',
    'required'
  ),
  (
    'e5200000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8003-000000000002',
    'useful'
  );

insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at,
  closed_at
)
values
  (
    'e5300000-0000-4000-8000-000000000001',
    'e5200000-0000-4000-8000-000000000001',
    'Baseline paint',
    'open',
    statement_timestamp() - interval '5 days',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'e5300000-0000-4000-8000-000000000002',
    'e5200000-0000-4000-8000-000000000001',
    'Closed ladder',
    'closed',
    statement_timestamp() - interval '5 days',
    statement_timestamp() - interval '1 day',
    statement_timestamp() - interval '1 day'
  ),
  (
    'e5300000-0000-4000-8000-000000000003',
    'e5200000-0000-4000-8000-000000000001',
    'Open tarp',
    'open',
    statement_timestamp() - interval '5 days',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'e5300000-0000-4000-8000-000000000004',
    'e5200000-0000-4000-8000-000000000001',
    'Closed stale brush',
    'closed',
    statement_timestamp() - interval '5 days',
    statement_timestamp() - interval '1 day',
    statement_timestamp() - interval '1 day'
  ),
  (
    'e5300000-0000-4000-8000-000000000005',
    'e5200000-0000-4000-8000-000000000005',
    'Other project need',
    'open',
    statement_timestamp() - interval '5 days',
    statement_timestamp() - interval '1 day',
    null
  );

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values
  ('e5400000-0000-4000-8000-000000000001', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000002', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000002', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000004', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000003', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000005', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000004', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000006', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000005', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000007', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000006', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000008', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000007', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000009', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000008', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000009', 'accepted', statement_timestamp() - interval '3 days', statement_timestamp() - interval '2 days 2 hours', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000009', 'e5200000-0000-4000-8000-000000000002', 'e5100000-0000-4000-8000-000000000002', 'accepted', statement_timestamp() - interval '2 days', statement_timestamp() - interval '1 day', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000010', 'e5200000-0000-4000-8000-000000000003', 'e5100000-0000-4000-8000-000000000002', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000011', 'e5200000-0000-4000-8000-000000000004', 'e5100000-0000-4000-8000-000000000002', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001'),
  ('e5400000-0000-4000-8000-000000000012', 'e5200000-0000-4000-8000-000000000006', 'e5100000-0000-4000-8000-000000000002', 'accepted', statement_timestamp() - interval '5 days', statement_timestamp() - interval '4 days', 'e5100000-0000-4000-8000-000000000001');

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  left_at,
  removed_at,
  removed_by_profile_id
)
values
  ('e5500000-0000-4000-8000-000000000001', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000002', 'e5400000-0000-4000-8000-000000000001', statement_timestamp() - interval '4 days', null, null, null),
  ('e5500000-0000-4000-8000-000000000002', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000004', 'e5400000-0000-4000-8000-000000000002', statement_timestamp() - interval '4 days', statement_timestamp() - interval '2 days 1 hour', null, null),
  ('e5500000-0000-4000-8000-000000000003', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000005', 'e5400000-0000-4000-8000-000000000003', statement_timestamp() - interval '4 days', null, statement_timestamp() - interval '2 days 1 hour', 'e5100000-0000-4000-8000-000000000001'),
  ('e5500000-0000-4000-8000-000000000004', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000006', 'e5400000-0000-4000-8000-000000000004', statement_timestamp() - interval '4 days', statement_timestamp() - interval '1 day', null, null),
  ('e5500000-0000-4000-8000-000000000005', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000007', 'e5400000-0000-4000-8000-000000000005', statement_timestamp() - interval '4 days', null, statement_timestamp() - interval '1 day', 'e5100000-0000-4000-8000-000000000001'),
  ('e5500000-0000-4000-8000-000000000006', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000008', 'e5400000-0000-4000-8000-000000000006', statement_timestamp() - interval '4 days', statement_timestamp() - interval '2 days', null, null),
  ('e5500000-0000-4000-8000-000000000007', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000009', 'e5400000-0000-4000-8000-000000000007', statement_timestamp() - interval '4 days', statement_timestamp() - interval '2 days 1 hour', null, null),
  ('e5500000-0000-4000-8000-000000000008', 'e5200000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000009', 'e5400000-0000-4000-8000-000000000008', statement_timestamp() - interval '2 days 2 hours', null, null, null),
  ('e5500000-0000-4000-8000-000000000009', 'e5200000-0000-4000-8000-000000000002', 'e5100000-0000-4000-8000-000000000002', 'e5400000-0000-4000-8000-000000000009', statement_timestamp() - interval '1 day', null, null, null),
  ('e5500000-0000-4000-8000-000000000010', 'e5200000-0000-4000-8000-000000000003', 'e5100000-0000-4000-8000-000000000002', 'e5400000-0000-4000-8000-000000000010', statement_timestamp() - interval '4 days', null, null, null),
  ('e5500000-0000-4000-8000-000000000011', 'e5200000-0000-4000-8000-000000000004', 'e5100000-0000-4000-8000-000000000002', 'e5400000-0000-4000-8000-000000000011', statement_timestamp() - interval '4 days', null, null, null),
  ('e5500000-0000-4000-8000-000000000012', 'e5200000-0000-4000-8000-000000000006', 'e5100000-0000-4000-8000-000000000002', 'e5400000-0000-4000-8000-000000000012', statement_timestamp() - interval '4 days', null, null, null);

insert into public.project_membership_skill_commitments (membership_id, skill_id)
values
  ('e5500000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000001'),
  ('e5500000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000002'),
  ('e5500000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8003-000000000002'),
  ('e5500000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8003-000000000002'),
  ('e5500000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8001-000000000001'),
  ('e5500000-0000-4000-8000-000000000005', 'd0000000-0000-4000-8001-000000000001'),
  ('e5500000-0000-4000-8000-000000000006', 'd0000000-0000-4000-8001-000000000001'),
  ('e5500000-0000-4000-8000-000000000007', 'd0000000-0000-4000-8001-000000000001'),
  ('e5500000-0000-4000-8000-000000000008', 'd0000000-0000-4000-8003-000000000002');

insert into public.project_membership_resource_commitments (
  membership_id,
  resource_need_id
)
values
  ('e5500000-0000-4000-8000-000000000001', 'e5300000-0000-4000-8000-000000000001'),
  ('e5500000-0000-4000-8000-000000000001', 'e5300000-0000-4000-8000-000000000004');

insert into public.project_membership_skill_coverages (membership_id, skill_id)
values (
  'e5500000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8001-000000000001'
);
insert into public.project_membership_resource_coverages (
  membership_id,
  resource_need_id
)
values (
  'e5500000-0000-4000-8000-000000000001',
  'e5300000-0000-4000-8000-000000000001'
);

set local role anon;
select throws_ok(
  $$select * from public.list_project_membership_actual_contributions(null, null)$$,
  '42501',
  'permission denied for function list_project_membership_actual_contributions',
  'anonymous callers cannot read actual contributions'
);
select throws_ok(
  $$select * from public.project_membership_actual_effort_markers$$,
  '42501',
  'permission denied for table project_membership_actual_effort_markers',
  'anonymous callers cannot read actual-contribution storage'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e5100000-0000-4000-8000-000000000002', true);
select results_eq(
  $$
    select contribution_kind, contribution_id, attribution_source
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000002',
      'e5500000-0000-4000-8000-000000000001'
    )
    order by contribution_kind, contribution_id
  $$,
  $$values
    ('resource'::text, 'e5300000-0000-4000-8000-000000000001'::uuid, 'final_commitment'::text),
    ('resource'::text, 'e5300000-0000-4000-8000-000000000004'::uuid, 'final_commitment'::text),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid, 'final_commitment'::text),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000002'::uuid, 'final_commitment'::text)
  $$,
  'active participant reads final skill/resource commitments as automatic baseline regardless of stale/closed state'
);
select is(
  (
    select count(*)
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000002',
      'e5500000-0000-4000-8000-000000000001'
    )
  ),
  4::bigint,
  'covered and uncovered final commitments receive the same automatic attribution treatment'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000002',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      '{}'::uuid[], '{}'::uuid[], false
    )
  $$,
  '42501',
  'Only the Project creator can manage actual contributions.',
  'participants cannot mutate actual attribution'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e5100000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$
    select * from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000003',
      'e5500000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The actual contributions are unavailable.',
  'unrelated profiles cannot read actual contributions'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e5100000-0000-4000-8000-000000000001', true);
select results_eq(
  $$
    select option_kind, option_id
    from public.list_project_membership_actual_contribution_options(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001'
    )
    order by option_kind, option_id
  $$,
  $$values
    ('resource'::text, 'e5300000-0000-4000-8000-000000000001'::uuid),
    ('resource'::text, 'e5300000-0000-4000-8000-000000000002'::uuid),
    ('resource'::text, 'e5300000-0000-4000-8000-000000000003'::uuid),
    ('resource'::text, 'e5300000-0000-4000-8000-000000000004'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000002'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid)
  $$,
  'creator options contain current Proposal skills, stale baseline skills, and all same-Project resources'
);

select is(
  public.replace_project_membership_actual_contributions(
    'e5100000-0000-4000-8000-000000000001',
    'e5500000-0000-4000-8000-000000000001',
    array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
    array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
    false,
    array['d0000000-0000-4000-8001-000000000002'::uuid, 'd0000000-0000-4000-8003-000000000002'::uuid],
    array['e5300000-0000-4000-8000-000000000002'::uuid],
    true
  ),
  'e5500000-0000-4000-8000-000000000001'::uuid,
  'creator can atomically replace skills, resources, and effort'
);
select results_eq(
  $$
    select contribution_kind, contribution_id, attribution_source
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001'
    )
    order by contribution_kind, contribution_id nulls first
  $$,
  $$values
    ('resource'::text, 'e5300000-0000-4000-8000-000000000002'::uuid, 'creator_added'::text),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000002'::uuid, 'final_commitment'::text),
    ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid, 'creator_added'::text),
    ('substantial_effort'::text, null::uuid, 'substantial_effort'::text)
  $$,
  'effective read overlays sparse exclusions/additions and the separate effort marker'
);
select is(
  (
    select count(*)
    from public.project_membership_actual_skill_overrides
    where membership_id = 'e5500000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'skill reconciliation stores only one baseline exclusion and one addition'
);
select is(
  (
    select count(*)
    from public.project_membership_actual_resource_overrides
    where membership_id = 'e5500000-0000-4000-8000-000000000001'
  ),
  3::bigint,
  'resource reconciliation stores two baseline exclusions and one addition'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.actual_contributions_updated'
      and payload ->> 'membership_id' = 'e5500000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'one real correction emits exactly one update event'
);
select is(
  (
    select array_agg(key order by key)
    from private.outbox_events as event,
      lateral jsonb_object_keys(event.payload) as key
    where event.event_type = 'project.actual_contributions_updated'
      and event.payload ->> 'membership_id' = 'e5500000-0000-4000-8000-000000000001'
  ),
  array['actor_profile_id', 'membership_id', 'participant_profile_id', 'project_id', 'project_kind']::text[],
  'the update event is identifier-only'
);

select lives_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000002'::uuid, 'd0000000-0000-4000-8003-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000002'::uuid],
      true,
      array['d0000000-0000-4000-8001-000000000002'::uuid, 'd0000000-0000-4000-8003-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000002'::uuid],
      true
    )
  $$,
  'an exact full-set no-op succeeds'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.actual_contributions_updated'
      and payload ->> 'membership_id' = 'e5500000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'an exact no-op emits no event and does not duplicate the effort marker'
);

select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      array['d0000000-0000-4000-8001-000000000002'::uuid, 'd0000000-0000-4000-8003-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000002'::uuid],
      true
    )
  $$,
  'PT409',
  'Actual contributions changed since they were loaded.',
  'stale expected truth is rejected even when desired equals the newer state'
);

select lives_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000002'::uuid, 'd0000000-0000-4000-8003-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000002'::uuid],
      true,
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false
    )
  $$,
  'returning to baseline succeeds'
);
select is(
  (
    select count(*)
    from public.project_membership_actual_skill_overrides
    where membership_id = 'e5500000-0000-4000-8000-000000000001'
  ) + (
    select count(*)
    from public.project_membership_actual_resource_overrides
    where membership_id = 'e5500000-0000-4000-8000-000000000001'
  ) + (
    select count(*)
    from public.project_membership_actual_effort_markers
    where membership_id = 'e5500000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'returning to automatic truth removes every redundant override and marker'
);

select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      array['d0000000-0000-4000-8006-000000000001'::uuid],
      '{}'::uuid[], false
    )
  $$,
  '22023',
  'Every added actual skill must be a final Proposal skill or automatic-baseline skill.',
  'arbitrary global skills cannot be attributed'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000005'::uuid], false
    )
  $$,
  '22023',
  'Every actual resource must belong to this Project.',
  'another Project resource cannot be attributed'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      array[null::uuid], '{}'::uuid[], false
    )
  $$,
  '22023',
  'Actual-contribution identifiers cannot be null.',
  'null desired identifiers are rejected'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000001'::uuid],
      '{}'::uuid[], false
    )
  $$,
  '22023',
  'Actual-contribution identifiers cannot contain duplicates.',
  'duplicate desired identifiers are rejected'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      '{}'::uuid[],
      array_fill('e5300000-0000-4000-8000-000000000001'::uuid, array[51]),
      false
    )
  $$,
  '22023',
  'Actual contributions may contain at most 50 skills and 50 resources.',
  'the resource desired set is independently bounded at 50'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000001',
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      false,
      array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000001'::uuid, 'e5300000-0000-4000-8000-000000000004'::uuid],
      null
    )
  $$,
  '22023',
  'Substantial Effort / Energy state is required.',
  'desired effort truth is required'
);

select is_empty(
  $$
    select *
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000002'
    )
  $$,
  'leaving before Project end yields a valid empty automatic baseline'
);
select is_empty(
  $$
    select *
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000003'
    )
  $$,
  'removal before Project end yields a valid empty automatic baseline'
);
select is(
  (
    select count(*)
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000004'
    )
  ),
  1::bigint,
  'leaving after Project end preserves the automatic baseline'
);
select is(
  (
    select count(*)
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000005'
    )
  ),
  1::bigint,
  'removal after Project end preserves the automatic baseline'
);
select is_empty(
  $$
    select *
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000006'
    )
  $$,
  'a membership ending exactly at Proposal end is not active at that instant'
);
select is_empty(
  $$
    select *
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000007'
    )
  $$,
  'the earlier rejoin episode has no automatic baseline'
);
select is(
  (
    select contribution_id
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000008'
    )
  ),
  'd0000000-0000-4000-8003-000000000002'::uuid,
  'the later rejoin episode independently receives its own baseline'
);

select lives_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000002',
      '{}'::uuid[], '{}'::uuid[], false,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['e5300000-0000-4000-8000-000000000002'::uuid], true
    )
  $$,
  'creator can credit real work to a membership that ended before Project end'
);
select results_eq(
  $$
    select contribution_kind, attribution_source
    from public.list_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000002'
    )
    order by contribution_kind
  $$,
  $$values
    ('resource'::text, 'creator_added'::text),
    ('skill'::text, 'creator_added'::text),
    ('substantial_effort'::text, 'substantial_effort'::text)
  $$,
  'manual additions and effort are explicit for a pre-end departure'
);

select throws_ok(
  $$select * from public.list_project_membership_actual_contributions('e5100000-0000-4000-8000-000000000001', 'e5500000-0000-4000-8000-000000000009')$$,
  '55000',
  'Actual contributions are available only for ended published one-time Proposals.',
  'pre-end Proposal reads are rejected'
);
select throws_ok(
  $$
    select public.replace_project_membership_actual_contributions(
      'e5100000-0000-4000-8000-000000000001',
      'e5500000-0000-4000-8000-000000000009',
      '{}'::uuid[], '{}'::uuid[], false,
      '{}'::uuid[], '{}'::uuid[], false
    )
  $$,
  '55000',
  'Actual contributions are available only for ended published one-time Proposals.',
  'pre-end Proposal mutations are rejected'
);
select throws_ok(
  $$select * from public.list_project_membership_actual_contributions('e5100000-0000-4000-8000-000000000001', 'e5500000-0000-4000-8000-000000000010')$$,
  '55000',
  'Actual contributions are available only for ended published one-time Proposals.',
  'cancelled Proposal reads are rejected'
);
select throws_ok(
  $$select * from public.list_project_membership_actual_contributions('e5100000-0000-4000-8000-000000000001', 'e5500000-0000-4000-8000-000000000011')$$,
  '55000',
  'Actual contributions are available only for ended published one-time Proposals.',
  'draft Proposal reads are rejected'
);
select throws_ok(
  $$select * from public.list_project_membership_actual_contributions('e5100000-0000-4000-8000-000000000001', 'e5500000-0000-4000-8000-000000000012')$$,
  '55000',
  'Actual contributions are available only for ended one-time Proposals.',
  'Tavolo actual-attribution reads are rejected'
);
reset role;

select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.actual_contributions_updated'
  ),
  3::bigint,
  'automatic baselines emit nothing; only the three real explicit changes emit events'
);
select is(
  (
    select count(*)
    from public.project_membership_skill_coverages
    where membership_id = 'e5500000-0000-4000-8000-000000000002'
  ) + (
    select count(*)
    from public.project_membership_resource_coverages
    where membership_id = 'e5500000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'manual attribution and effort create no live-coverage source for the pre-end departure'
);

select * from finish();

rollback;
