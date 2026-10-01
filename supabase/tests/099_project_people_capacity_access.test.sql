begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

insert into auth.users (id, email)
values
  ('fa100000-0000-4000-8000-000000000001', 'capacity-owner@planets.invalid'),
  ('fa100000-0000-4000-8000-000000000002', 'capacity-one@planets.invalid'),
  ('fa100000-0000-4000-8000-000000000003', 'capacity-two@planets.invalid'),
  ('fa100000-0000-4000-8000-000000000004', 'capacity-three@planets.invalid'),
  ('fa100000-0000-4000-8000-000000000005', 'capacity-delegate@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('fa100000-0000-4000-8000-000000000001', 'Capacity Creator'),
  ('fa100000-0000-4000-8000-000000000002', 'Capacity One'),
  ('fa100000-0000-4000-8000-000000000003', 'Capacity Two'),
  ('fa100000-0000-4000-8000-000000000004', 'Capacity Three'),
  ('fa100000-0000-4000-8000-000000000005', 'Capacity Delegate');

insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/fa1f0000-0000-4000-8000-000000000001.webp',
  'interactions'
from public.profiles as profile
where profile.id in (
  'fa100000-0000-4000-8000-000000000001',
  'fa100000-0000-4000-8000-000000000002',
  'fa100000-0000-4000-8000-000000000003',
  'fa100000-0000-4000-8000-000000000004',
  'fa100000-0000-4000-8000-000000000005'
);

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  starts_at, ends_at, event_timezone, country_code, locality,
  public_location_label, published_at
)
values
  (
    'fa200000-0000-4000-8000-000000000001',
    'fa100000-0000-4000-8000-000000000001',
    'published', 'Full request Project', 'Full request summary',
    'Full request description', statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days', 'Europe/Rome', 'IT', 'Rome',
    'Central Rome', statement_timestamp() - interval '1 day'
  ),
  (
    'fa200000-0000-4000-8000-000000000002',
    'fa100000-0000-4000-8000-000000000001',
    'published', 'Legacy Project', 'Legacy summary', 'Legacy description',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days', 'Europe/Rome', 'IT', 'Rome',
    'Central Rome', statement_timestamp() - interval '1 day'
  ),
  (
    'fa200000-0000-4000-8000-000000000003',
    'fa100000-0000-4000-8000-000000000001',
    'published', 'Acceptance Project', 'Acceptance summary',
    'Acceptance description', statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days', 'Europe/Rome', 'IT', 'Rome',
    'Central Rome', statement_timestamp() - interval '1 day'
  );

insert into public.proposal_meeting_details (
  proposal_id, exact_meeting_text, exact_location_visibility
)
select proposal.id, 'Capacity test meeting', 'participants'
from public.proposals as proposal
where proposal.id in (
  'fa200000-0000-4000-8000-000000000001',
  'fa200000-0000-4000-8000-000000000002',
  'fa200000-0000-4000-8000-000000000003'
);

update public.projects
set people_capacity = case id
  when 'fa200000-0000-4000-8000-000000000001'::uuid then 1
  when 'fa200000-0000-4000-8000-000000000003'::uuid then 2
  else null
end
where id in (
  'fa200000-0000-4000-8000-000000000001',
  'fa200000-0000-4000-8000-000000000002',
  'fa200000-0000-4000-8000-000000000003'
);

select results_eq(
  $$
    select people_capacity, current_participant_count, current_people_count,
      spots_remaining, is_full
    from public.list_public_project_capacity_statuses(
      array['fa200000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  $$values (1, 0, 1, 0, true)$$,
  'public capacity counts the immutable Creator as the first person'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'fa100000-0000-4000-8000-000000000002',
      'fa200000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  'PT409',
  'This Project is full.',
  'a full Project rejects a new request with a stable conflict code'
);
select lives_ok(
  $$
    select public.request_to_join_project(
      'fa100000-0000-4000-8000-000000000002',
      'fa200000-0000-4000-8000-000000000002',
      null,
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  'a legacy null-capacity Project remains joinable'
);
select set_config(
  'test.request_one',
  public.request_to_join_project(
    'fa100000-0000-4000-8000-000000000002',
    'fa200000-0000-4000-8000-000000000003',
    null,
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.request_two',
  public.request_to_join_project(
    'fa100000-0000-4000-8000-000000000003',
    'fa200000-0000-4000-8000-000000000003',
    null,
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.request_three',
  public.request_to_join_project(
    'fa100000-0000-4000-8000-000000000004',
    'fa200000-0000-4000-8000-000000000003',
    null,
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_two',
  public.accept_project_join_request_as_manager(
    'fa100000-0000-4000-8000-000000000001',
    current_setting('test.request_two')::uuid
  )::text,
  true
);
select throws_ok(
  $$
    select public.accept_project_join_request_as_manager(
      'fa100000-0000-4000-8000-000000000001',
      current_setting('test.request_one')::uuid
    )
  $$,
  'PT409',
  'This Project is full.',
  'acceptance rechecks fullness under the shared Project lock'
);
reset role;
select is(
  (
    select status
    from public.project_join_requests
    where id = current_setting('test.request_one')::uuid
  ),
  'pending',
  'failed full acceptance preserves the pending request'
);
select is(
  (
    select count(*)
    from public.project_memberships
    where originating_request_id = current_setting('test.request_one')::uuid
  ),
  0::bigint,
  'failed full acceptance creates no membership'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select public.leave_project(
      'fa100000-0000-4000-8000-000000000003',
      current_setting('test.membership_two')::uuid
    )
  $$,
  'leaving naturally releases the occupied spot'
);

select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_one',
  public.accept_project_join_request_as_manager(
    'fa100000-0000-4000-8000-000000000001',
    current_setting('test.request_one')::uuid
  )::text,
  true
);
select lives_ok(
  $$
    select public.remove_project_member_as_manager(
      'fa100000-0000-4000-8000-000000000001',
      current_setting('test.membership_one')::uuid
    )
  $$,
  'manager removal naturally releases the occupied spot'
);
select lives_ok(
  $$
    select public.accept_project_join_request_as_manager(
      'fa100000-0000-4000-8000-000000000001',
      current_setting('test.request_three')::uuid
    )
  $$,
  'a pending request can be accepted after a spot is released'
);

select throws_ok(
  $$
    select public.update_own_proposal(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000003',
      'Acceptance Project', 'Acceptance summary', 'Acceptance description',
      statement_timestamp() + interval '2 days',
      statement_timestamp() + interval '3 days',
      'Europe/Rome', 'IT', 'Rome', null, 'Central Rome',
      'Capacity test meeting', 'participants', '{}'::uuid[], '{}'::text[], 1
    )
  $$,
  '22023',
  'People capacity cannot be lower than the current people count.',
  'capacity cannot be reduced below Creator plus current memberships'
);
select throws_ok(
  $$
    select public.update_own_proposal(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000003',
      'Acceptance Project', 'Acceptance summary', 'Acceptance description',
      statement_timestamp() + interval '2 days',
      statement_timestamp() + interval '3 days',
      'Europe/Rome', 'IT', 'Rome', null, 'Central Rome',
      'Capacity test meeting', 'participants', '{}'::uuid[], '{}'::text[], 0
    )
  $$,
  '22023',
  'People capacity must be between 1 and 100,000.',
  'zero people capacity is rejected'
);
select throws_ok(
  $$
    select public.update_own_proposal(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000003',
      'Acceptance Project', 'Acceptance summary', 'Acceptance description',
      statement_timestamp() + interval '2 days',
      statement_timestamp() + interval '3 days',
      'Europe/Rome', 'IT', 'Rome', null, 'Central Rome',
      'Capacity test meeting', 'participants', '{}'::uuid[], '{}'::text[],
      100001
    )
  $$,
  '22023',
  'People capacity must be between 1 and 100,000.',
  'people capacity above 100,000 is rejected'
);
select lives_ok(
  $$
    select public.update_own_proposal(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000003',
      'Acceptance Project', 'Acceptance summary', 'Acceptance description',
      statement_timestamp() + interval '2 days',
      statement_timestamp() + interval '3 days',
      'Europe/Rome', 'IT', 'Rome', null, 'Central Rome',
      'Capacity test meeting', 'participants', '{}'::uuid[], '{}'::text[], 2
    )
  $$,
  'capacity may equal current people count and makes the Project full'
);

select set_config(
  'test.delegate_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000002',
      'co_creator'
    )
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000005',
  true
);
select lives_ok(
  $$
    select public.accept_project_delegate_invitation(
      'fa100000-0000-4000-8000-000000000005',
      current_setting('test.delegate_token')
    )
  $$,
  'a Co-creator can be granted authority independently of participation'
);
select results_eq(
  $$
    select current_participant_count, current_people_count
    from public.list_public_project_capacity_statuses(
      array['fa200000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  $$values (0, 1)$$,
  'delegated authority alone does not consume a participant spot'
);

select set_config(
  'test.delegate_request',
  public.request_to_join_project(
    'fa100000-0000-4000-8000-000000000005',
    'fa200000-0000-4000-8000-000000000002',
    null,
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.accept_project_join_request_as_manager(
      'fa100000-0000-4000-8000-000000000001',
      current_setting('test.delegate_request')::uuid
    )
  $$,
  'a delegated structural actor may independently become a participant'
);
select results_eq(
  $$
    select current_participant_count, current_people_count
    from public.list_public_project_capacity_statuses(
      array['fa200000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  $$values (1, 2)$$,
  'a delegated actor with a current membership consumes exactly one participant spot'
);

reset role;

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  starts_at, ends_at, event_timezone, country_code, locality,
  public_location_label
)
values (
  'fa200000-0000-4000-8000-000000000004',
  'fa100000-0000-4000-8000-000000000001',
  'draft', 'Capacity Proposal draft', 'Capacity Proposal summary',
  'Capacity Proposal description', statement_timestamp() + interval '2 days',
  statement_timestamp() + interval '3 days', 'Europe/Rome', 'IT', 'Rome',
  'Central Rome'
);
insert into public.proposal_meeting_details (
  proposal_id, exact_meeting_text, exact_location_visibility
)
values (
  'fa200000-0000-4000-8000-000000000004',
  'Capacity Proposal meeting',
  'participants'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.publish_proposal(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000004'
    )
  $$,
  '22023',
  'People capacity is required before publication.',
  'a Proposal draft cannot publish without capacity'
);

reset role;
update public.projects
set people_capacity = 12
where id = 'fa200000-0000-4000-8000-000000000004';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.publish_proposal(
      'fa100000-0000-4000-8000-000000000001',
      'fa200000-0000-4000-8000-000000000004'
    )
  $$,
  'a valid-capacity Proposal publishes'
);

reset role;

insert into public.recurring_activities (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  country_code, locality, public_location_label
)
values (
  'fa300000-0000-4000-8000-000000000001',
  'fa100000-0000-4000-8000-000000000001',
  'draft', 'Capacity Tavolo', 'Capacity Tavolo summary',
  'Capacity Tavolo description', 'IT', 'Rome', 'Central Rome'
);
insert into public.recurring_activity_meeting_details (
  recurring_activity_id, exact_meeting_text, exact_location_visibility
)
values (
  'fa300000-0000-4000-8000-000000000001',
  'Capacity Tavolo meeting',
  'participants'
);
insert into public.recurring_activity_schedules (
  recurring_activity_id, recurrence_type, weekday, local_start_time,
  duration_minutes, event_timezone, effective_from
)
values (
  'fa300000-0000-4000-8000-000000000001',
  'weekly', 3, '19:00'::time, 90, 'Europe/Rome', current_date + 1
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.publish_recurring_activity(
      'fa100000-0000-4000-8000-000000000001',
      'fa300000-0000-4000-8000-000000000001'
    )
  $$,
  '22023',
  'People capacity is required before publication.',
  'a Tavolo draft cannot publish without capacity'
);

reset role;
update public.projects
set people_capacity = 12
where id = 'fa300000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'fa100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.publish_recurring_activity(
      'fa100000-0000-4000-8000-000000000001',
      'fa300000-0000-4000-8000-000000000001'
    )
  $$,
  'a valid-capacity Tavolo publishes'
);

select * from finish();
rollback;
