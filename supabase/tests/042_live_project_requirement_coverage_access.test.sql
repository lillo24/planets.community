begin;

select no_plan();

insert into auth.users (id, email)
values
  ('c1000000-0000-4000-8000-000000000001', 'coverage-owner@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000002', 'coverage-first@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000003', 'coverage-second@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000004', 'coverage-third@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000005', 'coverage-fourth@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000006', 'coverage-unrelated@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000007', 'coverage-tavolo@planets.invalid'),
  ('c1000000-0000-4000-8000-000000000008', 'coverage-limit@planets.invalid');

insert into public.profiles (id, display_name)
select id, 'Coverage profile ' || right(id::text, 2)
from auth.users
where id::text like 'c1000000-%';

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at
)
values
  (
    'c2000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000001',
    'published',
    'Live coverage primary',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    'c2000000-0000-4000-8000-000000000002',
    'c1000000-0000-4000-8000-000000000001',
    'published',
    'Live coverage lifecycle',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    'c2000000-0000-4000-8000-000000000003',
    'c1000000-0000-4000-8000-000000000001',
    'published',
    'Live coverage limits',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '1 day'
  );

insert into public.proposal_skills (proposal_id, skill_id, importance)
values
  ('c2000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000001', 'required'),
  ('c2000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8003-000000000002', 'useful'),
  ('c2000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8001-000000000001', 'required');

insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at
)
values
  ('c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'Needed paint', 'open', statement_timestamp(), statement_timestamp()),
  ('c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 'Extra ladder', 'open', statement_timestamp() + interval '1 second', statement_timestamp()),
  ('c3000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000001', 'Already found brush', 'open', statement_timestamp() + interval '2 seconds', statement_timestamp()),
  ('c3000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000001', 'Claimable tarp', 'open', statement_timestamp() + interval '3 seconds', statement_timestamp()),
  ('c3000000-0000-4000-8000-000000000005', 'c2000000-0000-4000-8000-000000000001', 'Generic commitment only', 'open', statement_timestamp() + interval '4 seconds', statement_timestamp()),
  ('c3000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000002', 'Lifecycle resource', 'open', statement_timestamp(), statement_timestamp());

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id
)
values
  ('c4000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000002'),
  ('c4000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000003'),
  ('c4000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000004'),
  ('c4000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000005'),
  ('c4000000-0000-4000-8000-000000000005', 'c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000008'),
  ('c4000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000006');

insert into public.project_join_request_skill_selections (request_id, skill_id)
values
  ('c4000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000001'),
  ('c4000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8003-000000000002'),
  ('c4000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8001-000000000001'),
  ('c4000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8001-000000000001'),
  ('c4000000-0000-4000-8000-000000000006', 'd0000000-0000-4000-8001-000000000001');

insert into public.project_join_request_resource_selections (
  request_id,
  resource_need_id
)
values
  ('c4000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001'),
  ('c4000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002'),
  ('c4000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003'),
  ('c4000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000001'),
  ('c4000000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000001'),
  ('c4000000-0000-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000006'),
  ('c4000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000006');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.coverage_first_membership',
  public.accept_project_join_request(
    'c1000000-0000-4000-8000-000000000001',
    'c4000000-0000-4000-8000-000000000001',
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    '{}'::uuid[],
    array['d0000000-0000-4000-8003-000000000002'::uuid],
    array['c3000000-0000-4000-8000-000000000001'::uuid],
    array['c3000000-0000-4000-8000-000000000003'::uuid],
    array['c3000000-0000-4000-8000-000000000002'::uuid]
  )::text,
  true
);
reset role;

select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
    order by 1, 2
  $$,
  $$values
    ('resource'::text, 'c3000000-0000-4000-8000-000000000001'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid)
  $$,
  'needed acceptance creates participant coverage for exact current items'
);
select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.coverage_first_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.coverage_first_membership')::uuid
    order by 1, 2
  $$,
  $$values
    ('resource'::text, 'c3000000-0000-4000-8000-000000000001'::uuid),
    ('resource'::text, 'c3000000-0000-4000-8000-000000000002'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid)
  $$,
  'needed and extra commitments remain distinct from coverage'
);
select is(
  (
    select originating_request_id
    from public.project_manual_resource_coverages
    where resource_need_id = 'c3000000-0000-4000-8000-000000000003'
  ),
  'c4000000-0000-4000-8000-000000000001'::uuid,
  'uncovered already-found acceptance creates one provenance-bearing manual source'
);
select is(
  (
    select count(*)
    from public.project_membership_skill_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
      and skill_id = 'd0000000-0000-4000-8003-000000000002'
  ),
  0::bigint,
  'extra acceptance never creates participant coverage'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.requirement_covered'
      and payload ->> 'project_id' = 'c2000000-0000-4000-8000-000000000001'
  ),
  3::bigint,
  'first needed and already-found sources emit exact uncovered-to-covered transitions'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.coverage_second_membership',
  public.accept_project_join_request(
    'c1000000-0000-4000-8000-000000000001',
    'c4000000-0000-4000-8000-000000000002',
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    '{}'::uuid[],
    '{}'::uuid[],
    array['c3000000-0000-4000-8000-000000000001'::uuid],
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);
select set_config(
  'test.coverage_third_membership',
  public.accept_project_join_request(
    'c1000000-0000-4000-8000-000000000001',
    'c4000000-0000-4000-8000-000000000003',
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    array['c3000000-0000-4000-8000-000000000001'::uuid],
    '{}'::uuid[]
  )::text,
  true
);
reset role;

select is(
  (
    select count(*)
    from public.project_membership_skill_coverages
    where skill_id = 'd0000000-0000-4000-8001-000000000001'
      and membership_id in (
        current_setting('test.coverage_first_membership')::uuid,
        current_setting('test.coverage_second_membership')::uuid
      )
  ),
  2::bigint,
  'multiple participant sources can cover one requirement'
);
select is(
  (
    select count(*)
    from public.project_manual_resource_coverages
    where resource_need_id = 'c3000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'already found does not create a redundant manual source over participant coverage'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.requirement_covered'
      and payload ->> 'requirement_id' = 'd0000000-0000-4000-8001-000000000001'
  ),
  1::bigint,
  'a redundant second participant source emits no duplicate covered event'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000002', true);
select is(
  public.claim_project_requirement(
    'c1000000-0000-4000-8000-000000000002',
    'c2000000-0000-4000-8000-000000000001',
    'skill',
    'd0000000-0000-4000-8003-000000000002'
  ),
  current_setting('test.coverage_first_membership')::uuid,
  'an extra commitment can explicitly become the live source'
);
select is(
  public.claim_project_requirement(
    'c1000000-0000-4000-8000-000000000002',
    'c2000000-0000-4000-8000-000000000001',
    'resource',
    'c3000000-0000-4000-8000-000000000004'
  ),
  current_setting('test.coverage_first_membership')::uuid,
  'a participant can claim an uncovered resource without a commitment'
);
select throws_ok(
  $$select public.claim_project_requirement('c1000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 'resource', 'c3000000-0000-4000-8000-000000000001')$$,
  'PT409',
  'The Project requirement is already covered.',
  'claiming an already-covered requirement returns the stable conflict'
);
reset role;

select ok(
  exists (
    select 1
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.coverage_first_membership')::uuid
      and resource_need_id = 'c3000000-0000-4000-8000-000000000004'
  )
  and exists (
    select 1
    from public.project_membership_resource_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
      and resource_need_id = 'c3000000-0000-4000-8000-000000000004'
  ),
  'claim atomically creates a missing commitment and its coverage source'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.membership_commitments_updated'
      and payload ->> 'membership_id' =
        current_setting('test.coverage_first_membership')
  ),
  1::bigint,
  'only the claim-created commitment emits the existing commitment event'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000002', true);
select is(
  public.replace_project_membership_commitments(
    'c1000000-0000-4000-8000-000000000002',
    current_setting('test.coverage_first_membership')::uuid,
    array[
      'd0000000-0000-4000-8001-000000000001'::uuid,
      'd0000000-0000-4000-8003-000000000002'::uuid
    ],
    array[
      'c3000000-0000-4000-8000-000000000001'::uuid,
      'c3000000-0000-4000-8000-000000000002'::uuid,
      'c3000000-0000-4000-8000-000000000004'::uuid
    ],
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array[
      'c3000000-0000-4000-8000-000000000001'::uuid,
      'c3000000-0000-4000-8000-000000000002'::uuid,
      'c3000000-0000-4000-8000-000000000004'::uuid,
      'c3000000-0000-4000-8000-000000000005'::uuid
    ]
  ),
  current_setting('test.coverage_first_membership')::uuid,
  'generic commitment replacement can remove covered and add uncovered items'
);
reset role;

select is(
  (
    select count(*)
    from public.project_membership_resource_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
      and resource_need_id = 'c3000000-0000-4000-8000-000000000005'
  ),
  0::bigint,
  'generic commitment addition does not create coverage'
);
select is(
  (
    select count(*)
    from public.project_membership_skill_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
      and skill_id = 'd0000000-0000-4000-8003-000000000002'
  ),
  0::bigint,
  'removing a covered commitment removes its participant coverage'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.requirement_needed_again'
      and payload ->> 'requirement_id' = 'd0000000-0000-4000-8003-000000000002'
  ),
  1::bigint,
  'removing the last participant source emits one needed-again transition'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select is(
  public.set_project_requirement_manual_coverage(
    'c1000000-0000-4000-8000-000000000001',
    'c2000000-0000-4000-8000-000000000001',
    'resource',
    'c3000000-0000-4000-8000-000000000001',
    true
  ),
  'c3000000-0000-4000-8000-000000000001'::uuid,
  'creator may add an independent manual source over participant coverage'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000002', true);
select lives_ok(
  $$select public.replace_project_membership_commitments(
    'c1000000-0000-4000-8000-000000000002',
    current_setting('test.coverage_first_membership')::uuid,
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array[
      'c3000000-0000-4000-8000-000000000001'::uuid,
      'c3000000-0000-4000-8000-000000000002'::uuid,
      'c3000000-0000-4000-8000-000000000004'::uuid,
      'c3000000-0000-4000-8000-000000000005'::uuid
    ],
    '{}'::uuid[],
    array[
      'c3000000-0000-4000-8000-000000000002'::uuid,
      'c3000000-0000-4000-8000-000000000004'::uuid,
      'c3000000-0000-4000-8000-000000000005'::uuid
    ]
  )$$,
  'one participant source can be removed while another and manual sources remain'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000003', true);
select lives_ok(
  $$select public.replace_project_membership_commitments(
    'c1000000-0000-4000-8000-000000000003',
    current_setting('test.coverage_second_membership')::uuid,
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array['c3000000-0000-4000-8000-000000000001'::uuid],
    '{}'::uuid[],
    '{}'::uuid[]
  )$$,
  'the last participant source can be removed while a manual source preserves coverage'
);
reset role;

select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.requirement_needed_again'
      and payload ->> 'requirement_id' = 'c3000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'participant source removals emit no needed-again while manual coverage remains'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$select public.set_project_requirement_manual_coverage(
    'c1000000-0000-4000-8000-000000000001',
    'c2000000-0000-4000-8000-000000000001',
    'resource',
    'c3000000-0000-4000-8000-000000000001',
    false
  )$$,
  'creator can clear the final manual source'
);
select lives_ok(
  $$select public.set_project_requirement_manual_coverage(
    'c1000000-0000-4000-8000-000000000001',
    'c2000000-0000-4000-8000-000000000001',
    'resource',
    'c3000000-0000-4000-8000-000000000001',
    false
  )$$,
  'clearing an absent manual source is idempotent'
);
reset role;

select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.requirement_needed_again'
      and payload ->> 'requirement_id' = 'c3000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'clearing the final total source emits exactly one needed-again transition'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000004', true);
select is(
  public.claim_project_requirement(
    'c1000000-0000-4000-8000-000000000004',
    'c2000000-0000-4000-8000-000000000001',
    'resource',
    'c3000000-0000-4000-8000-000000000005'
  ),
  current_setting('test.coverage_third_membership')::uuid,
  'another current participant can claim an uncovered generic commitment item'
);
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$select public.remove_project_member(
    'c1000000-0000-4000-8000-000000000001',
    current_setting('test.coverage_third_membership')::uuid
  )$$,
  'creator removal releases every participant coverage source'
);
reset role;
select ok(
  exists (
    select 1
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.coverage_third_membership')::uuid
      and resource_need_id = 'c3000000-0000-4000-8000-000000000005'
  )
  and not exists (
    select 1
    from public.project_membership_resource_coverages
    where membership_id = current_setting('test.coverage_third_membership')::uuid
  ),
  'creator removal retains commitment history while clearing live coverage'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select results_eq(
  $$
    select
      requirement_kind,
      requirement_id,
      importance,
      is_covered,
      viewer_is_covering,
      is_manually_covered
    from public.list_project_live_requirement_coverage(
      'c1000000-0000-4000-8000-000000000001',
      'c2000000-0000-4000-8000-000000000001'
    )
  $$,
  $$values
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid, 'required'::text, false, false, false),
    ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid, 'useful'::text, false, false, false),
    ('resource'::text, 'c3000000-0000-4000-8000-000000000001'::uuid, null::text, false, false, false),
    ('resource'::text, 'c3000000-0000-4000-8000-000000000002'::uuid, null::text, false, false, false),
    ('resource'::text, 'c3000000-0000-4000-8000-000000000003'::uuid, null::text, true, false, true),
    ('resource'::text, 'c3000000-0000-4000-8000-000000000004'::uuid, null::text, true, false, false),
    ('resource'::text, 'c3000000-0000-4000-8000-000000000005'::uuid, null::text, false, false, false)
  $$,
  'creator read returns current requirements in deterministic normalized order without provider names'
);
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000002', true);
select is(
  (
    select viewer_is_covering
    from public.list_project_live_requirement_coverage(
      'c1000000-0000-4000-8000-000000000002',
      'c2000000-0000-4000-8000-000000000001'
    )
    where requirement_kind = 'resource'
      and requirement_id = 'c3000000-0000-4000-8000-000000000004'
  ),
  true,
  'current participant read identifies only the viewer own live source'
);
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select * from public.list_project_live_requirement_coverage('c1000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000001')$$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'stale expected identity fails before any coverage read'
);
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000006', true);
select throws_ok(
  $$select * from public.list_project_live_requirement_coverage('c1000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000001')$$,
  '42501',
  'Live Project requirement coverage is unavailable.',
  'unrelated authenticated profiles cannot read live coverage'
);
reset role;

-- Membership end removes live sources but retains commitments as episode history.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000002', true);
select lives_ok(
  $$select public.leave_project(
    'c1000000-0000-4000-8000-000000000002',
    current_setting('test.coverage_first_membership')::uuid
  )$$,
  'a participant can leave and release every remaining source'
);
select throws_ok(
  $$select * from public.list_project_live_requirement_coverage('c1000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001')$$,
  '42501',
  'Live Project requirement coverage is unavailable.',
  'former participants cannot read current live coverage'
);
reset role;
select ok(
  exists (
    select 1
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.coverage_first_membership')::uuid
  )
  and not exists (
    select 1
    from public.project_membership_resource_coverages
    where membership_id = current_setting('test.coverage_first_membership')::uuid
  ),
  'ended membership commitments remain while its live sources are gone'
);

-- Requirement removal clears coverage without a false needed-again event and
-- later re-addition does not resurrect the removed source.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.coverage_lifecycle_membership',
  public.accept_project_join_request(
    'c1000000-0000-4000-8000-000000000001',
    'c4000000-0000-4000-8000-000000000004',
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    '{}'::uuid[],
    '{}'::uuid[],
    array['c3000000-0000-4000-8000-000000000006'::uuid],
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);
reset role;

delete from public.proposal_skills
where proposal_id = 'c2000000-0000-4000-8000-000000000002'
  and skill_id = 'd0000000-0000-4000-8001-000000000001';
set constraints proposal_skills_clear_removed_live_coverage immediate;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$select public.close_project_resource_need(
    'c1000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000006'
  )$$,
  'closing a resource need clears its live source'
);
select set_config(
  'test.coverage_stale_membership',
  public.accept_project_join_request(
    'c1000000-0000-4000-8000-000000000001',
    'c4000000-0000-4000-8000-000000000006',
    '{}'::uuid[],
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    '{}'::uuid[],
    '{}'::uuid[],
    array['c3000000-0000-4000-8000-000000000006'::uuid],
    '{}'::uuid[]
  )::text,
  true
);
reset role;

insert into public.proposal_skills (proposal_id, skill_id, importance)
values (
  'c2000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8001-000000000001',
  'required'
);

select ok(
  exists (
    select 1
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.coverage_lifecycle_membership')::uuid
      and skill_id = 'd0000000-0000-4000-8001-000000000001'
  )
  and not exists (
    select 1
    from public.project_membership_skill_coverages
    where membership_id = current_setting('test.coverage_lifecycle_membership')::uuid
      and skill_id = 'd0000000-0000-4000-8001-000000000001'
  ),
  'removed and re-added Proposal skill retains stale commitment but starts uncovered'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.requirement_needed_again'
      and payload ->> 'project_id' = 'c2000000-0000-4000-8000-000000000002'
      and payload ->> 'requirement_id' = 'd0000000-0000-4000-8001-000000000001'
  ),
  0::bigint,
  'Proposal skill removal emits no needed-again event'
);
select ok(
  not exists (
    select 1
    from public.project_membership_resource_coverages
    where resource_need_id = 'c3000000-0000-4000-8000-000000000006'
  )
  and not exists (
    select 1
    from private.outbox_events
    where event_type = 'project.requirement_needed_again'
      and payload ->> 'requirement_id' = 'c3000000-0000-4000-8000-000000000006'
  ),
  'resource closure suppresses stale coverage and false resurfacing'
);
select is(
  (
    select count(*)
    from public.project_manual_skill_coverages
    where project_id = 'c2000000-0000-4000-8000-000000000002'
      and skill_id = 'd0000000-0000-4000-8001-000000000001'
  ) + (
    select count(*)
    from public.project_manual_resource_coverages
    where resource_need_id = 'c3000000-0000-4000-8000-000000000006'
  ),
  0::bigint,
  'stale already-found decisions create no live manual coverage'
);

update public.projects
set people_capacity = 100
where id = 'c2000000-0000-4000-8000-000000000002';
update public.proposals
set
  starts_at = statement_timestamp() - interval '2 hours',
  ends_at = statement_timestamp() - interval '1 hour'
where id = 'c2000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000005', true);
select throws_ok(
  $$select public.claim_project_requirement(
    'c1000000-0000-4000-8000-000000000005',
    'c2000000-0000-4000-8000-000000000002',
    'skill',
    'd0000000-0000-4000-8001-000000000001'
  )$$,
  '55000',
  'Live requirement coverage is available only while the Project is operational.',
  'ended Projects reject further live coverage mutation'
);
select throws_ok(
  $$select * from public.list_project_live_requirement_coverage(
    'c1000000-0000-4000-8000-000000000005',
    'c2000000-0000-4000-8000-000000000002'
  )$$,
  '55000',
  'Live requirement coverage is available only while the Project is operational.',
  'ended Projects expose no current live coverage read'
);
reset role;

-- A resource-only Tavolo uses the same current coverage contract and rejects skills.
insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at
)
values (
  'c6000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000001',
  'paused',
  'Coverage Tavolo',
  statement_timestamp() - interval '1 day'
);
insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at
)
values (
  'c7000000-0000-4000-8000-000000000001',
  'c6000000-0000-4000-8000-000000000001',
  'Tavolo resource',
  'open',
  statement_timestamp(),
  statement_timestamp()
);
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  resolved_at,
  resolved_by_profile_id
)
values (
  'c8000000-0000-4000-8000-000000000001',
  'c6000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000007',
  'accepted',
  statement_timestamp(),
  'c1000000-0000-4000-8000-000000000001'
);
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'c9000000-0000-4000-8000-000000000001',
  'c6000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000007',
  'c8000000-0000-4000-8000-000000000001',
  statement_timestamp()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000007', true);
select lives_ok(
  $$select public.claim_project_requirement(
    'c1000000-0000-4000-8000-000000000007',
    'c6000000-0000-4000-8000-000000000001',
    'resource',
    'c7000000-0000-4000-8000-000000000001'
  )$$,
  'a current participant may claim a paused Tavolo resource'
);
select throws_ok(
  $$select public.claim_project_requirement(
    'c1000000-0000-4000-8000-000000000007',
    'c6000000-0000-4000-8000-000000000001',
    'skill',
    'd0000000-0000-4000-8001-000000000001'
  )$$,
  '22023',
  'Recurring Projects do not define skill requirements.',
  'Tavolo skill claims fail closed'
);
reset role;

-- Exercise the independent resource commitment limit through a real claim.
insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  'c2000000-0000-4000-8000-000000000003',
  'Limit resource ' || series.value,
  'open',
  statement_timestamp() + (series.value || ' seconds')::interval,
  statement_timestamp()
from generate_series(1, 51) as series(value);

update public.project_join_requests
set
  status = 'accepted',
  resolved_at = statement_timestamp(),
  resolved_by_profile_id = 'c1000000-0000-4000-8000-000000000001'
where id = 'c4000000-0000-4000-8000-000000000005';
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'c9000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000003',
  'c1000000-0000-4000-8000-000000000008',
  'c4000000-0000-4000-8000-000000000005',
  statement_timestamp()
);
insert into public.project_membership_resource_commitments (
  membership_id,
  resource_need_id
)
select
  'c9000000-0000-4000-8000-000000000002',
  need.id
from public.project_resource_needs as need
where need.project_id = 'c2000000-0000-4000-8000-000000000003'
order by need.created_at, need.id
limit 50;
select set_config(
  'test.coverage_limit_need',
  (
    select need.id::text
    from public.project_resource_needs as need
    where need.project_id = 'c2000000-0000-4000-8000-000000000003'
    order by need.created_at desc, need.id desc
    limit 1
  ),
  true
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-4000-8000-000000000008', true);
select throws_ok(
  format(
    'select public.claim_project_requirement(%L::uuid, %L::uuid, %L, %L::uuid)',
    'c1000000-0000-4000-8000-000000000008',
    'c2000000-0000-4000-8000-000000000003',
    'resource',
    current_setting('test.coverage_limit_need')
  ),
  '22023',
  'A membership may commit to at most 50 Project resource needs.',
  'claim respects the independent 50-resource commitment limit'
);
reset role;

select is(
  (
    select count(*)
    from private.outbox_events
    where event_type in (
      'project.requirement_covered',
      'project.requirement_needed_again'
    )
      and (
        payload ?| array[
          'label',
          'title',
          'request_message',
          'display_name',
          'email'
        ]
        or payload::text ilike '%coverage profile%'
        or payload::text ilike '%needed paint%'
      )
  ),
  0::bigint,
  'coverage transition events contain identifiers only'
);

select * from finish();

rollback;
