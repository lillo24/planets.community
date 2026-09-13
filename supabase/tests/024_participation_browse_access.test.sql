begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a5100000-0000-4000-8000-000000000001', 'browse-owner@planets.invalid'),
  ('a5200000-0000-4000-8000-000000000002', 'browse-requester@planets.invalid'),
  ('a5300000-0000-4000-8000-000000000003', 'browse-other@planets.invalid'),
  ('a5400000-0000-4000-8000-000000000004', 'browse-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a5100000-0000-4000-8000-000000000001', 'Browse Owner'),
  ('a5200000-0000-4000-8000-000000000002', 'Browse Requester'),
  ('a5300000-0000-4000-8000-000000000003', 'Browse Other'),
  ('a5400000-0000-4000-8000-000000000004', null);

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  summary,
  description,
  starts_at,
  ends_at,
  event_timezone,
  country_code,
  locality,
  public_location_label,
  published_at,
  cancelled_at
)
values
  ('e5100000-0000-4000-8000-000000000001', 'a5100000-0000-4000-8000-000000000001', 'published', 'Bologna requested Proposal', 'Bologna public summary', 'Private-length description', '2098-02-01 09:00+00', '2098-02-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Central Bologna', '2097-01-01 00:00+00', null),
  ('e5200000-0000-4000-8000-000000000002', 'a5100000-0000-4000-8000-000000000001', 'published', 'Rome requested Proposal', 'Rome public summary', 'Private-length description', '2098-03-01 09:00+00', '2098-03-01 11:00+00', 'Europe/Rome', 'IT', 'Rome', 'Central Rome', '2097-01-01 00:00+00', null),
  ('e5300000-0000-4000-8000-000000000003', 'a5100000-0000-4000-8000-000000000001', 'cancelled', 'Cancelled Proposal', 'Cancelled public summary', 'Private-length description', '2098-04-01 09:00+00', '2098-04-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Cancelled location', '2097-01-01 00:00+00', '2097-02-01 00:00+00'),
  ('e5400000-0000-4000-8000-000000000004', 'a5100000-0000-4000-8000-000000000001', 'published', 'Expired Proposal', 'Expired public summary', 'Private-length description', '2020-01-01 09:00+00', '2020-01-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Expired location', '2019-01-01 00:00+00', null),
  ('e5500000-0000-4000-8000-000000000005', 'a5100000-0000-4000-8000-000000000001', 'published', 'Other requester Proposal', 'Other public summary', 'Private-length description', '2098-05-01 09:00+00', '2098-05-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Other location', '2097-01-01 00:00+00', null),
  ('e5600000-0000-4000-8000-000000000006', 'a5100000-0000-4000-8000-000000000001', 'published', 'Rejected Proposal', 'Rejected public summary', 'Private-length description', '2098-06-01 09:00+00', '2098-06-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Rejected location', '2097-01-01 00:00+00', null),
  ('e5700000-0000-4000-8000-000000000007', 'a5100000-0000-4000-8000-000000000001', 'published', 'Withdrawn Proposal', 'Withdrawn public summary', 'Private-length description', '2098-07-01 09:00+00', '2098-07-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Withdrawn location', '2097-01-01 00:00+00', null),
  ('e5800000-0000-4000-8000-000000000008', 'a5100000-0000-4000-8000-000000000001', 'published', 'Accepted Proposal', 'Accepted public summary', 'Private-length description', '2098-08-01 09:00+00', '2098-08-01 11:00+00', 'Europe/Rome', 'IT', 'Bologna', 'Accepted location', '2097-01-01 00:00+00', null);

insert into public.proposal_meeting_details (
  proposal_id,
  exact_meeting_text,
  exact_location_visibility
)
select proposal.id, 'SECRET PROPOSAL ' || proposal.id::text, 'participants'
from public.proposals as proposal
where proposal.id between
  'e5100000-0000-4000-8000-000000000001'::uuid and
  'e5800000-0000-4000-8000-000000000008'::uuid;

insert into public.proposal_skills (proposal_id, skill_id, importance)
values
  ('e5100000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000001', 'required'),
  ('e5200000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8004-000000000001', 'useful');

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  summary,
  description,
  topic,
  country_code,
  locality,
  public_location_label,
  published_at,
  paused_at,
  ended_at
)
values
  ('f5100000-0000-4000-8000-000000000001', 'a5100000-0000-4000-8000-000000000001', 'published', 'Bologna requested Tavolo', 'Bologna Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Central Bologna', '2097-01-01 00:00+00', null, null),
  ('f5200000-0000-4000-8000-000000000002', 'a5100000-0000-4000-8000-000000000001', 'published', 'Rome requested Tavolo', 'Rome Tavolo summary', 'Private-length description', 'Culture', 'IT', 'Rome', 'Central Rome', '2097-01-01 00:00+00', null, null),
  ('f5300000-0000-4000-8000-000000000003', 'a5100000-0000-4000-8000-000000000001', 'paused', 'Paused Tavolo', 'Paused Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Paused location', '2097-01-01 00:00+00', '2097-02-01 00:00+00', null),
  ('f5400000-0000-4000-8000-000000000004', 'a5100000-0000-4000-8000-000000000001', 'ended', 'Ended Tavolo', 'Ended Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Ended location', '2097-01-01 00:00+00', null, '2097-02-01 00:00+00'),
  ('f5500000-0000-4000-8000-000000000005', 'a5100000-0000-4000-8000-000000000001', 'published', 'Other requester Tavolo', 'Other Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Other location', '2097-01-01 00:00+00', null, null),
  ('f5600000-0000-4000-8000-000000000006', 'a5100000-0000-4000-8000-000000000001', 'published', 'Rejected Tavolo', 'Rejected Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Rejected location', '2097-01-01 00:00+00', null, null),
  ('f5700000-0000-4000-8000-000000000007', 'a5100000-0000-4000-8000-000000000001', 'published', 'Withdrawn Tavolo', 'Withdrawn Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Withdrawn location', '2097-01-01 00:00+00', null, null),
  ('f5800000-0000-4000-8000-000000000008', 'a5100000-0000-4000-8000-000000000001', 'published', 'Accepted Tavolo', 'Accepted Tavolo summary', 'Private-length description', 'Community', 'IT', 'Bologna', 'Accepted location', '2097-01-01 00:00+00', null, null);

insert into public.recurring_activity_meeting_details (
  recurring_activity_id,
  exact_meeting_text,
  exact_location_visibility
)
select activity.id, 'SECRET TAVOLO ' || activity.id::text, 'participants'
from public.recurring_activities as activity
where activity.id between
  'f5100000-0000-4000-8000-000000000001'::uuid and
  'f5800000-0000-4000-8000-000000000008'::uuid;

insert into public.recurring_activity_schedules (
  id,
  recurring_activity_id,
  recurrence_type,
  weekday,
  day_of_month,
  local_start_time,
  duration_minutes,
  event_timezone,
  effective_from
)
select
  ('aa' || substr(replace(activity.id::text, '-', ''), 3))::uuid,
  activity.id,
  case when activity.id = 'f5200000-0000-4000-8000-000000000002' then 'monthly' else 'weekly' end,
  case when activity.id = 'f5200000-0000-4000-8000-000000000002' then null else 3 end,
  case when activity.id = 'f5200000-0000-4000-8000-000000000002' then 15 else null end,
  '19:00:00',
  90,
  'Europe/Rome',
  '2097-01-01'
from public.recurring_activities as activity
where activity.id between
  'f5100000-0000-4000-8000-000000000001'::uuid and
  'f5800000-0000-4000-8000-000000000008'::uuid;

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  request_message,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values
  ('b5100000-0000-4000-8000-000000000001', 'e5100000-0000-4000-8000-000000000001', 'a5200000-0000-4000-8000-000000000002', 'pending', 'SECRET REQUEST P1', '2097-01-01 10:00+00', null, null),
  ('b5200000-0000-4000-8000-000000000002', 'e5200000-0000-4000-8000-000000000002', 'a5200000-0000-4000-8000-000000000002', 'pending', 'SECRET REQUEST P2', '2097-01-02 10:00+00', null, null),
  ('b5300000-0000-4000-8000-000000000003', 'e5300000-0000-4000-8000-000000000003', 'a5200000-0000-4000-8000-000000000002', 'pending', null, '2097-01-03 10:00+00', null, null),
  ('b5400000-0000-4000-8000-000000000004', 'e5400000-0000-4000-8000-000000000004', 'a5200000-0000-4000-8000-000000000002', 'pending', null, '2097-01-04 10:00+00', null, null),
  ('b5500000-0000-4000-8000-000000000005', 'e5500000-0000-4000-8000-000000000005', 'a5300000-0000-4000-8000-000000000003', 'pending', null, '2097-01-05 10:00+00', null, null),
  ('b5600000-0000-4000-8000-000000000006', 'e5600000-0000-4000-8000-000000000006', 'a5200000-0000-4000-8000-000000000002', 'rejected', null, '2097-01-06 10:00+00', '2097-01-06 11:00+00', 'a5100000-0000-4000-8000-000000000001'),
  ('b5700000-0000-4000-8000-000000000007', 'e5700000-0000-4000-8000-000000000007', 'a5200000-0000-4000-8000-000000000002', 'withdrawn', null, '2097-01-07 10:00+00', '2097-01-07 11:00+00', 'a5200000-0000-4000-8000-000000000002'),
  ('b5800000-0000-4000-8000-000000000008', 'e5800000-0000-4000-8000-000000000008', 'a5200000-0000-4000-8000-000000000002', 'accepted', null, '2097-01-08 10:00+00', '2097-01-08 11:00+00', 'a5100000-0000-4000-8000-000000000001'),
  ('c5100000-0000-4000-8000-000000000001', 'f5100000-0000-4000-8000-000000000001', 'a5200000-0000-4000-8000-000000000002', 'pending', 'SECRET REQUEST T1', '2097-02-01 10:00+00', null, null),
  ('c5200000-0000-4000-8000-000000000002', 'f5200000-0000-4000-8000-000000000002', 'a5200000-0000-4000-8000-000000000002', 'pending', 'SECRET REQUEST T2', '2097-02-02 10:00+00', null, null),
  ('c5300000-0000-4000-8000-000000000003', 'f5300000-0000-4000-8000-000000000003', 'a5200000-0000-4000-8000-000000000002', 'pending', null, '2097-02-03 10:00+00', null, null),
  ('c5400000-0000-4000-8000-000000000004', 'f5400000-0000-4000-8000-000000000004', 'a5200000-0000-4000-8000-000000000002', 'pending', null, '2097-02-04 10:00+00', null, null),
  ('c5500000-0000-4000-8000-000000000005', 'f5500000-0000-4000-8000-000000000005', 'a5300000-0000-4000-8000-000000000003', 'pending', null, '2097-02-05 10:00+00', null, null),
  ('c5600000-0000-4000-8000-000000000006', 'f5600000-0000-4000-8000-000000000006', 'a5200000-0000-4000-8000-000000000002', 'rejected', null, '2097-02-06 10:00+00', '2097-02-06 11:00+00', 'a5100000-0000-4000-8000-000000000001'),
  ('c5700000-0000-4000-8000-000000000007', 'f5700000-0000-4000-8000-000000000007', 'a5200000-0000-4000-8000-000000000002', 'withdrawn', null, '2097-02-07 10:00+00', '2097-02-07 11:00+00', 'a5200000-0000-4000-8000-000000000002'),
  ('c5800000-0000-4000-8000-000000000008', 'f5800000-0000-4000-8000-000000000008', 'a5200000-0000-4000-8000-000000000002', 'accepted', null, '2097-02-08 10:00+00', '2097-02-08 11:00+00', 'a5100000-0000-4000-8000-000000000001');

set local role anon;
select throws_ok(
  $$select * from public.list_own_pending_requested_proposals(null, null, null)$$,
  '42501',
  'permission denied for function list_own_pending_requested_proposals',
  'anonymous clients cannot invoke requested Proposal discovery'
);
select throws_ok(
  $$select * from public.list_own_pending_requested_recurring_activities(null, '2098-01-01', null)$$,
  '42501',
  'permission denied for function list_own_pending_requested_recurring_activities',
  'anonymous clients cannot invoke requested Tavolo discovery'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a5200000-0000-4000-8000-000000000002', true);

select results_eq(
  $$
    select proposal_id, request_id
    from public.list_own_pending_requested_proposals(
      'a5200000-0000-4000-8000-000000000002', null, null
    )
  $$,
  $$values
    ('e5200000-0000-4000-8000-000000000002'::uuid, 'b5200000-0000-4000-8000-000000000002'::uuid),
    ('e5100000-0000-4000-8000-000000000001'::uuid, 'b5100000-0000-4000-8000-000000000001'::uuid)
  $$,
  'only own, pending, publicly eligible Proposals are newest-request ordered'
);
select results_eq(
  $$
    select proposal_id
    from public.list_own_pending_requested_proposals(
      'a5200000-0000-4000-8000-000000000002', ' bologna ', null
    )
  $$,
  $$values ('e5100000-0000-4000-8000-000000000001'::uuid)$$,
  'requested Proposal locality filtering matches public discovery semantics'
);
select results_eq(
  $$
    select proposal_id
    from public.list_own_pending_requested_proposals(
      'a5200000-0000-4000-8000-000000000002',
      null,
      array['d0000000-0000-4000-8001-000000000001'::uuid]
    )
  $$,
  $$values ('e5100000-0000-4000-8000-000000000001'::uuid)$$,
  'requested Proposal skill filtering matches public discovery semantics'
);
select is(
  (
    select bool_and(
      row_to_json(card)::text not like '%SECRET REQUEST%'
      and row_to_json(card)::text not like '%SECRET PROPOSAL%'
      and row_to_json(card)::text not like '%Private-length description%'
    )
    from public.list_own_pending_requested_proposals(
      'a5200000-0000-4000-8000-000000000002', null, null
    ) as card
  ),
  true,
  'requested Proposal cards contain no private request or meeting/detail data'
);

select results_eq(
  $$
    select recurring_activity_id, request_id
    from public.list_own_pending_requested_recurring_activities(
      'a5200000-0000-4000-8000-000000000002', '2098-01-01 00:00+00', null
    )
  $$,
  $$values
    ('f5200000-0000-4000-8000-000000000002'::uuid, 'c5200000-0000-4000-8000-000000000002'::uuid),
    ('f5100000-0000-4000-8000-000000000001'::uuid, 'c5100000-0000-4000-8000-000000000001'::uuid)
  $$,
  'only own, pending, active Tavoli are newest-request ordered'
);
select results_eq(
  $$
    select recurring_activity_id
    from public.list_own_pending_requested_recurring_activities(
      'a5200000-0000-4000-8000-000000000002',
      '2098-01-01 00:00+00',
      ' bologna '
    )
  $$,
  $$values ('f5100000-0000-4000-8000-000000000001'::uuid)$$,
  'requested Tavolo locality filtering matches public discovery semantics'
);
select results_eq(
  $$
    select recurrence_type, weekday, day_of_month, local_start_time, duration_minutes
    from public.list_own_pending_requested_recurring_activities(
      'a5200000-0000-4000-8000-000000000002', '2098-01-01 00:00+00', null
    )
  $$,
  $$values
    ('monthly'::text, null::smallint, 15::smallint, '19:00:00'::time, 90),
    ('weekly'::text, 3::smallint, null::smallint, '19:00:00'::time, 90)
  $$,
  'requested Tavolo cards carry their sanitized schedule metadata'
);
select is(
  (
    select bool_and(
      row_to_json(card)::text not like '%SECRET REQUEST%'
      and row_to_json(card)::text not like '%SECRET TAVOLO%'
      and row_to_json(card)::text not like '%Private-length description%'
    )
    from public.list_own_pending_requested_recurring_activities(
      'a5200000-0000-4000-8000-000000000002', '2098-01-01 00:00+00', null
    ) as card
  ),
  true,
  'requested Tavolo cards contain no private request or meeting/detail data'
);

select throws_ok(
  $$
    select *
    from public.list_own_pending_requested_proposals(
      'a5300000-0000-4000-8000-000000000003', null, null
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected identity cannot cross-read requested Proposals'
);
select throws_ok(
  $$
    select *
    from public.list_own_pending_requested_recurring_activities(
      'a5300000-0000-4000-8000-000000000003', '2098-01-01', null
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected identity cannot cross-read requested Tavoli'
);

select set_config('request.jwt.claim.sub', 'a5300000-0000-4000-8000-000000000003', true);
select results_eq(
  $$
    select proposal_id
    from public.list_own_pending_requested_proposals(
      'a5300000-0000-4000-8000-000000000003', null, null
    )
  $$,
  $$values ('e5500000-0000-4000-8000-000000000005'::uuid)$$,
  'another requester sees only their own requested Proposal'
);
select results_eq(
  $$
    select recurring_activity_id
    from public.list_own_pending_requested_recurring_activities(
      'a5300000-0000-4000-8000-000000000003', '2098-01-01', null
    )
  $$,
  $$values ('f5500000-0000-4000-8000-000000000005'::uuid)$$,
  'another requester sees only their own requested Tavolo'
);

select set_config('request.jwt.claim.sub', 'a5100000-0000-4000-8000-000000000001', true);
select is(
  (
    select count(*)
    from public.list_own_pending_requested_proposals(
      'a5100000-0000-4000-8000-000000000001', null, null
    )
  ),
  0::bigint,
  'creator-side incoming Proposal requests are not surfaced as own requests'
);
select is(
  (
    select count(*)
    from public.list_own_pending_requested_recurring_activities(
      'a5100000-0000-4000-8000-000000000001', '2098-01-01', null
    )
  ),
  0::bigint,
  'creator-side incoming Tavolo requests are not surfaced as own requests'
);

select set_config('request.jwt.claim.sub', 'a5400000-0000-4000-8000-000000000004', true);
select throws_ok(
  $$
    select *
    from public.list_own_pending_requested_proposals(
      'a5400000-0000-4000-8000-000000000004', null, null
    )
  $$,
  '55000',
  'A complete profile is required to request project participation.',
  'an incomplete profile cannot use requested Proposal discovery'
);
select throws_ok(
  $$
    select *
    from public.list_own_pending_requested_recurring_activities(
      'a5400000-0000-4000-8000-000000000004', '2098-01-01', null
    )
  $$,
  '55000',
  'A complete profile is required to request project participation.',
  'an incomplete profile cannot use requested Tavolo discovery'
);

select * from finish();

rollback;
