begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b1000000-0000-4000-8000-000000000001', 'participation-owner@planets.invalid'),
  ('b2000000-0000-4000-8000-000000000002', 'participation-requester@planets.invalid'),
  ('b3000000-0000-4000-8000-000000000003', 'participation-other@planets.invalid'),
  ('b4000000-0000-4000-8000-000000000004', 'participation-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('b1000000-0000-4000-8000-000000000001', 'Project Creator'),
  ('b2000000-0000-4000-8000-000000000002', 'Private Requester'),
  ('b3000000-0000-4000-8000-000000000003', 'Other Person'),
  ('b4000000-0000-4000-8000-000000000004', null);
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
    'c1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    'published',
    'Active one-time project',
    statement_timestamp() - interval '1 hour',
    statement_timestamp() + interval '2 hours',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'c2000000-0000-4000-8000-000000000002',
    'b1000000-0000-4000-8000-000000000001',
    'cancelled',
    'Cancelled one-time project',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    'c3000000-0000-4000-8000-000000000003',
    'b1000000-0000-4000-8000-000000000001',
    'published',
    'Ended one-time project',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day',
    statement_timestamp() - interval '3 days',
    null
  ),
  (
    'c4000000-0000-4000-8000-000000000004',
    'b1000000-0000-4000-8000-000000000001',
    'published',
    'Lifecycle-race project',
    statement_timestamp() + interval '1 hour',
    statement_timestamp() + interval '4 hours',
    statement_timestamp() - interval '1 day',
    null
  );

insert into public.proposal_meeting_details (
  proposal_id,
  exact_meeting_text,
  exact_location_visibility
)
values
  (
    'c1000000-0000-4000-8000-000000000001',
    'Secret proposal courtyard',
    'participants'
  ),
  (
    'c2000000-0000-4000-8000-000000000002',
    'Cancelled secret location',
    'participants'
  ),
  (
    'c3000000-0000-4000-8000-000000000003',
    'Ended secret location',
    'participants'
  ),
  (
    'c4000000-0000-4000-8000-000000000004',
    'Closing project location',
    'participants'
  );

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at,
  paused_at,
  ended_at
)
values
  (
    'd1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    'published',
    'Active Tavolo',
    statement_timestamp() - interval '1 day',
    null,
    null
  ),
  (
    'd2000000-0000-4000-8000-000000000002',
    'b1000000-0000-4000-8000-000000000001',
    'paused',
    'Paused Tavolo',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'd3000000-0000-4000-8000-000000000003',
    'b1000000-0000-4000-8000-000000000001',
    'ended',
    'Ended Tavolo',
    statement_timestamp() - interval '2 days',
    null,
    statement_timestamp() - interval '1 day'
  );

insert into public.recurring_activity_meeting_details (
  recurring_activity_id,
  exact_meeting_text,
  exact_location_visibility
)
values
  (
    'd1000000-0000-4000-8000-000000000001',
    'Secret Tavolo room',
    'participants'
  ),
  (
    'd2000000-0000-4000-8000-000000000002',
    'Paused Tavolo room',
    'participants'
  ),
  (
    'd3000000-0000-4000-8000-000000000003',
    'Ended Tavolo room',
    'participants'
  );

select is(
  (
    select count(*)
    from public.proposals as proposal
    join public.projects as project
      on project.id = proposal.id
      and project.project_kind = 'one_time'
      and project.creator_profile_id = proposal.creator_profile_id
  ),
  (select count(*) from public.proposals),
  'every existing and fixture proposal has exactly one synchronized project identity'
);
select is(
  (
    select count(*)
    from public.recurring_activities as activity
    join public.projects as project
      on project.id = activity.id
      and project.project_kind = 'recurring'
      and project.creator_profile_id = activity.creator_profile_id
  ),
  (select count(*) from public.recurring_activities),
  'every existing and fixture Tavolo has exactly one synchronized project identity'
);
select throws_ok(
  $$
    insert into public.recurring_activities (
      id,
      creator_profile_id,
      title
    )
    values (
      'c1000000-0000-4000-8000-000000000001',
      'b1000000-0000-4000-8000-000000000001',
      'Cross-kind collision'
    )
  $$,
  '23505',
  'Project UUID c1000000-0000-4000-8000-000000000001 is already registered as one_time.',
  'a future cross-kind UUID collision fails closed'
);
select throws_ok(
  $$
    update public.proposals
    set creator_profile_id = 'b2000000-0000-4000-8000-000000000002'
    where id = 'c1000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'Project IDs and creators are immutable.',
  'a trusted update cannot desynchronize project ownership'
);

set local role anon;
select throws_ok(
  'select id from public.projects',
  '42501',
  'permission denied for table projects',
  'anonymous users cannot enumerate shared project identities'
);
select throws_ok(
  $$select * from public.get_project_participant_meeting_details(null, 'c1000000-0000-4000-8000-000000000001')$$,
  '42501',
  'permission denied for function get_project_participant_meeting_details',
  'anonymous users cannot invoke the protected meeting boundary'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b4000000-0000-4000-8000-000000000004', true);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b4000000-0000-4000-8000-000000000004',
      'c1000000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '55000',
  'A complete profile is required to request project participation.',
  'an incomplete profile cannot request participation'
);

select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b1000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '55000',
  'A project creator cannot request to join their own project.',
  'the creator cannot request their own project'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b2000000-0000-4000-8000-000000000002',
      'c2000000-0000-4000-8000-000000000002',
      null
    )
  $$,
  '55000',
  'This project is not accepting participation requests.',
  'a cancelled one-time project rejects new requests'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b2000000-0000-4000-8000-000000000002',
      'c3000000-0000-4000-8000-000000000003',
      null
    )
  $$,
  '55000',
  'This project is not accepting participation requests.',
  'a one-time project at or after its end rejects new requests'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b2000000-0000-4000-8000-000000000002',
      'd2000000-0000-4000-8000-000000000002',
      null
    )
  $$,
  '55000',
  'This project is not accepting participation requests.',
  'a paused Tavolo rejects new requests'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b2000000-0000-4000-8000-000000000002',
      'd3000000-0000-4000-8000-000000000003',
      null
    )
  $$,
  '55000',
  'This project is not accepting participation requests.',
  'an ended Tavolo rejects new requests'
);
select throws_ok(
  format(
    $$select public.request_to_join_project(%L::uuid, %L::uuid, %L)$$,
    'b2000000-0000-4000-8000-000000000002',
    'c1000000-0000-4000-8000-000000000001',
    repeat('x', 501)
  ),
  '22023',
  'A participation request message must contain at most 500 characters.',
  'private participation messages are bounded centrally'
);

select set_config(
  'test.proposal_request_id',
  public.request_to_join_project(
    'b2000000-0000-4000-8000-000000000002',
    'c1000000-0000-4000-8000-000000000001',
    '  I can bring painting experience.  '
  )::text,
  true
);
select results_eq(
  $$
    select project_kind, status, request_message
    from public.list_own_project_join_requests(
      'b2000000-0000-4000-8000-000000000002'
    )
    where request_id = current_setting('test.proposal_request_id')::uuid
  $$,
  $$values ('one_time'::text, 'pending'::text, 'I can bring painting experience.'::text)$$,
  'a happening one-time project accepts a trimmed private request visible to its requester'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b2000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '55000',
  'The requester already has a pending request for this project.',
  'a second pending request is rejected'
);
select throws_ok(
  $$
    select *
    from public.get_project_participant_meeting_details(
      'b2000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator or a current participant can read protected meeting information.',
  'a pending requester cannot read protected meeting information'
);

select set_config('request.jwt.claim.sub', 'b3000000-0000-4000-8000-000000000003', true);
select is(
  (
    select count(*)
    from public.list_own_project_join_requests(
      'b3000000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'an unrelated user cannot read another request through the own-history boundary'
);
select throws_ok(
  $$
    select *
    from public.list_project_join_requests(
      'b3000000-0000-4000-8000-000000000003',
      'c1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator can perform this operation.',
  'an unrelated user cannot invoke the creator request review'
);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'b3000000-0000-4000-8000-000000000003',
      current_setting('test.proposal_request_id')::uuid
    )
  $$,
  '42501',
  'Only the project creator can accept join requests.',
  'a non-creator cannot accept a request'
);
select throws_ok(
  $$
    select public.reject_project_join_request(
      'b3000000-0000-4000-8000-000000000003',
      current_setting('test.proposal_request_id')::uuid
    )
  $$,
  '42501',
  'Only the project creator can reject join requests.',
  'a non-creator cannot reject a request'
);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'b2000000-0000-4000-8000-000000000002',
      current_setting('test.proposal_request_id')::uuid
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected creator identity fails before mutation'
);

select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select results_eq(
  $$
    select requester_display_name, request_message
    from public.list_project_join_requests(
      'b1000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000001'
    )
    where request_id = current_setting('test.proposal_request_id')::uuid
  $$,
  $$values ('Private Requester'::text, 'I can bring painting experience.'::text)$$,
  'the creator gets a narrow authenticated requester identity and private message projection'
);
select results_eq(
  $$
    select project_kind, exact_meeting_text
    from public.get_project_participant_meeting_details(
      'b1000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('one_time'::text, 'Secret proposal courtyard'::text)$$,
  'the creator can read participant-protected proposal meeting information'
);
select set_config(
  'test.proposal_membership_id',
  public.accept_project_join_request(
    'b1000000-0000-4000-8000-000000000001',
    current_setting('test.proposal_request_id')::uuid
  )::text,
  true
);
reset role;
select results_eq(
  $$
    select status, count(*)
    from public.project_join_requests as request
    left join public.project_memberships as membership
      on membership.originating_request_id = request.id
    where request.id = current_setting('test.proposal_request_id')::uuid
    group by status
  $$,
  $$values ('accepted'::text, 1::bigint)$$,
  'acceptance atomically creates exactly one membership with the accepted request'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'b1000000-0000-4000-8000-000000000001',
      current_setting('test.proposal_request_id')::uuid
    )
  $$,
  '55000',
  'Only a pending join request can be accepted.',
  'an accepted request cannot be accepted again or duplicate its membership'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
select results_eq(
  $$
    select membership_status
    from public.list_own_project_memberships(
      'b2000000-0000-4000-8000-000000000002'
    )
    where membership_id = current_setting('test.proposal_membership_id')::uuid
  $$,
  $$values ('current'::text)$$,
  'the accepted participant can read own current membership state'
);
select is(
  (
    select exact_meeting_text
    from public.get_project_participant_meeting_details(
      'b2000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000001'
    )
  ),
  'Secret proposal courtyard',
  'a current accepted participant can read protected proposal meeting information'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      'b2000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '55000',
  'The requester is already a current project participant.',
  'a current member cannot request the same project again'
);
select lives_ok(
  $$
    select public.leave_project(
      'b2000000-0000-4000-8000-000000000002',
      current_setting('test.proposal_membership_id')::uuid
    )
  $$,
  'a current participant can leave their own membership'
);
select throws_ok(
  $$
    select *
    from public.get_project_participant_meeting_details(
      'b2000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator or a current participant can read protected meeting information.',
  'a voluntarily-left participant immediately loses protected meeting access'
);
select set_config(
  'test.proposal_request_two_id',
  public.request_to_join_project(
    'b2000000-0000-4000-8000-000000000002',
    'c1000000-0000-4000-8000-000000000001',
    'I would like to return.'
  )::text,
  true
);

select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.proposal_membership_two_id',
  public.accept_project_join_request(
    'b1000000-0000-4000-8000-000000000001',
    current_setting('test.proposal_request_two_id')::uuid
  )::text,
  true
);
select lives_ok(
  $$
    select public.remove_project_member(
      'b1000000-0000-4000-8000-000000000001',
      current_setting('test.proposal_membership_two_id')::uuid
    )
  $$,
  'the creator can remove a current participant'
);
select results_eq(
  $$
    select membership_status, removed_by_profile_id
    from public.list_project_members(
      'b1000000-0000-4000-8000-000000000001',
      'c1000000-0000-4000-8000-000000000001'
    )
    order by joined_at
  $$,
  $$
    values
      ('left'::text, null::uuid),
      ('removed'::text, 'b1000000-0000-4000-8000-000000000001'::uuid)
  $$,
  'creator member history preserves voluntary leave and creator removal separately'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$
    select *
    from public.get_project_participant_meeting_details(
      'b2000000-0000-4000-8000-000000000002',
      'c1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator or a current participant can read protected meeting information.',
  'a removed participant loses protected meeting access'
);
select set_config(
  'test.post_removal_request_id',
  public.request_to_join_project(
    'b2000000-0000-4000-8000-000000000002',
    'c1000000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select lives_ok(
  $$
    select public.withdraw_project_join_request(
      'b2000000-0000-4000-8000-000000000002',
      current_setting('test.post_removal_request_id')::uuid
    )
  $$,
  'ordinary removal still permits a fresh request and withdrawal while eligible'
);
select throws_ok(
  $$
    select public.withdraw_project_join_request(
      'b2000000-0000-4000-8000-000000000002',
      current_setting('test.post_removal_request_id')::uuid
    )
  $$,
  '55000',
  'Only a pending join request can be withdrawn.',
  'a terminal withdrawn request cannot be rewritten'
);

select set_config(
  'test.race_request_id',
  public.request_to_join_project(
    'b2000000-0000-4000-8000-000000000002',
    'c4000000-0000-4000-8000-000000000004',
    null
  )::text,
  true
);
reset role;
update public.projects
set registration_capacity = 10
where id = 'c4000000-0000-4000-8000-000000000004';
update public.proposals
set
  starts_at = statement_timestamp() - interval '1 hour',
  ends_at = statement_timestamp()
where id = 'c4000000-0000-4000-8000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'b1000000-0000-4000-8000-000000000001',
      current_setting('test.race_request_id')::uuid
    )
  $$,
  '55000',
  'This project is not accepting participation requests.',
  'acceptance revalidates one-time eligibility at the decision boundary'
);

select set_config('request.jwt.claim.sub', 'b3000000-0000-4000-8000-000000000003', true);
select set_config(
  'test.reject_request_id',
  public.request_to_join_project(
    'b3000000-0000-4000-8000-000000000003',
    'c1000000-0000-4000-8000-000000000001',
    'Please consider me.'
  )::text,
  true
);
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$
    select public.reject_project_join_request(
      'b1000000-0000-4000-8000-000000000001',
      current_setting('test.reject_request_id')::uuid
    )
  $$,
  'the creator can reject a pending request'
);
reset role;
select is(
  (
    select count(*)
    from public.project_memberships
    where originating_request_id = current_setting('test.reject_request_id')::uuid
  ),
  0::bigint,
  'rejection creates no membership'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b3000000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$
    select *
    from public.get_project_participant_meeting_details(
      'b3000000-0000-4000-8000-000000000003',
      'c1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator or a current participant can read protected meeting information.',
  'a rejected requester cannot read protected meeting information'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
select set_config(
  'test.tavolo_request_id',
  public.request_to_join_project(
    'b2000000-0000-4000-8000-000000000002',
    'd1000000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config('request.jwt.claim.sub', 'b3000000-0000-4000-8000-000000000003', true);
select set_config(
  'test.tavolo_pending_id',
  public.request_to_join_project(
    'b3000000-0000-4000-8000-000000000003',
    'd1000000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.tavolo_membership_id',
  public.accept_project_join_request(
    'b1000000-0000-4000-8000-000000000001',
    current_setting('test.tavolo_request_id')::uuid
  )::text,
  true
);

reset role;
update public.recurring_activities
set
  lifecycle_state = 'paused',
  paused_at = statement_timestamp(),
  resumed_at = null
where id = 'd1000000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from public.project_memberships
    where id = current_setting('test.tavolo_membership_id')::uuid
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'pausing a Tavolo preserves its current membership'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'b1000000-0000-4000-8000-000000000001',
      current_setting('test.tavolo_pending_id')::uuid
    )
  $$,
  '55000',
  'This project is not accepting participation requests.',
  'a paused Tavolo cannot accept an already-pending request'
);
select results_eq(
  $$
    select project_kind, exact_meeting_text
    from public.get_project_participant_meeting_details(
      'b1000000-0000-4000-8000-000000000001',
      'd1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('recurring'::text, 'Secret Tavolo room'::text)$$,
  'the creator meeting boundary resolves recurring projects'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-4000-8000-000000000002', true);
select is(
  (
    select exact_meeting_text
    from public.get_project_participant_meeting_details(
      'b2000000-0000-4000-8000-000000000002',
      'd1000000-0000-4000-8000-000000000001'
    )
  ),
  'Secret Tavolo room',
  'a current participant retains protected Tavolo meeting access while paused'
);

reset role;
update public.recurring_activities
set
  lifecycle_state = 'ended',
  paused_at = null,
  ended_at = statement_timestamp()
where id = 'd1000000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from public.project_memberships
    where id = current_setting('test.tavolo_membership_id')::uuid
  ),
  1::bigint,
  'ending a Tavolo preserves membership history'
);
select throws_ok(
  $$delete from public.proposals where id = 'c1000000-0000-4000-8000-000000000001'$$,
  '23503',
  'A project with participation history cannot be deleted.',
  'a source project with participation history cannot be deleted or orphaned'
);

select is(
  (
    select count(*)
    from private.audit_events
    where action = 'project.join_request_accepted'
      and target_id in (
        'c1000000-0000-4000-8000-000000000001',
        'd1000000-0000-4000-8000-000000000001'
      )
  ),
  3::bigint,
  'each successful acceptance records one stable audit event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed'
    )
      and (
        payload::text like '%painting experience%'
        or payload::text like '%Secret proposal%'
        or payload::text like '%Secret Tavolo%'
      )
  ),
  0::bigint,
  'participation outbox payloads contain no private messages or exact meeting data'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.join_request_accepted'
      and payload ? 'membership_id'
      and payload ? 'project_id'
      and payload ->> 'project_id' in (
        'c1000000-0000-4000-8000-000000000001',
        'd1000000-0000-4000-8000-000000000001'
      )
  ),
  3::bigint,
  'acceptance events expose stable identifiers for later notification/chat consumers'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b3000000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$
    select public.leave_project(
      'b3000000-0000-4000-8000-000000000003',
      current_setting('test.tavolo_membership_id')::uuid
    )
  $$,
  '42501',
  'Only the current participant can leave this membership.',
  'an unrelated user cannot leave another participant membership'
);
select throws_ok(
  $$
    select public.remove_project_member(
      'b3000000-0000-4000-8000-000000000003',
      current_setting('test.tavolo_membership_id')::uuid
    )
  $$,
  '42501',
  'Only the project creator can remove a participant.',
  'an unrelated user cannot remove another participant'
);
select throws_ok(
  'select request_message from public.project_join_requests',
  '42501',
  'permission denied for table project_join_requests',
  'authenticated clients cannot directly enumerate private request messages'
);
select throws_ok(
  'select id from public.project_memberships',
  '42501',
  'permission denied for table project_memberships',
  'authenticated clients cannot directly enumerate membership history'
);

select * from finish();

rollback;
