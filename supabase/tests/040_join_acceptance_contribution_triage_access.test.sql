begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b1000000-0000-4000-8000-000000000001', 'triage-owner@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000002', 'triage-mixed@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000003', 'triage-invalid@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000004', 'triage-zero-two@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000005', 'triage-zero-eight@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000006', 'triage-stale-skill@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000007', 'triage-stale-resource@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000008', 'triage-auth@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000009', 'triage-tavolo@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000010', 'triage-trigger@planets.invalid'),
  ('b1000000-0000-4000-8000-000000000011', 'triage-foreign@planets.invalid');

insert into public.profiles (id, display_name)
select id, 'Triage profile ' || right(id::text, 2)
from auth.users
where id::text like 'b1000000-%';

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
  ('b2000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'published', 'Mixed triage', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'published', 'Invalid triage', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'published', 'Zero two argument', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001', 'published', 'Zero triaged', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000001', 'published', 'Stale skill', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001', 'published', 'Stale resource', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000001', 'published', 'Authorization', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000001', 'published', 'Foreign resource owner', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day'),
  ('b2000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000001', 'published', 'Incomplete trigger', statement_timestamp() + interval '2 days', statement_timestamp() + interval '3 days', statement_timestamp() - interval '1 day');

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at
)
values (
  'b4000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  'published',
  'Triage Tavolo',
  statement_timestamp() - interval '1 day'
);

insert into public.proposal_skills (proposal_id, skill_id, importance)
values
  ('b2000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000001', 'required'),
  ('b2000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8003-000000000002', 'useful'),
  ('b2000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8001-000000000001', 'required'),
  ('b2000000-0000-4000-8000-000000000005', 'd0000000-0000-4000-8003-000000000002', 'useful'),
  ('b2000000-0000-4000-8000-000000000007', 'd0000000-0000-4000-8001-000000000001', 'required'),
  ('b2000000-0000-4000-8000-000000000009', 'd0000000-0000-4000-8001-000000000001', 'required');

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
  ('b3000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'Mixed extra', 'open', statement_timestamp(), statement_timestamp(), null),
  ('b3000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000001', 'Mixed already found', 'open', statement_timestamp(), statement_timestamp(), null),
  ('b3000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000002', 'Invalid selected', 'open', statement_timestamp(), statement_timestamp(), null),
  ('b3000000-0000-4000-8000-000000000004', 'b2000000-0000-4000-8000-000000000006', 'Stale resource', 'open', statement_timestamp(), statement_timestamp(), null),
  ('b3000000-0000-4000-8000-000000000005', 'b2000000-0000-4000-8000-000000000008', 'Foreign resource', 'open', statement_timestamp(), statement_timestamp(), null),
  ('b3000000-0000-4000-8000-000000000006', 'b4000000-0000-4000-8000-000000000001', 'Tavolo needed resource', 'open', statement_timestamp(), statement_timestamp(), null);

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  request_message
)
values
  ('b5000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000002', 'Private mixed message'),
  ('b5000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000003', null),
  ('b5000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000004', null),
  ('b5000000-0000-4000-8000-000000000004', 'b2000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000005', null),
  ('b5000000-0000-4000-8000-000000000005', 'b2000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000006', null),
  ('b5000000-0000-4000-8000-000000000006', 'b2000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000007', null),
  ('b5000000-0000-4000-8000-000000000007', 'b2000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000008', null),
  ('b5000000-0000-4000-8000-000000000008', 'b4000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000009', null),
  ('b5000000-0000-4000-8000-000000000009', 'b2000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000010', null),
  ('b5000000-0000-4000-8000-000000000010', 'b2000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000011', null);

insert into public.project_join_request_skill_selections (request_id, skill_id)
values
  ('b5000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8001-000000000001'),
  ('b5000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8003-000000000002'),
  ('b5000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8001-000000000001'),
  ('b5000000-0000-4000-8000-000000000005', 'd0000000-0000-4000-8003-000000000002'),
  ('b5000000-0000-4000-8000-000000000007', 'd0000000-0000-4000-8001-000000000001'),
  ('b5000000-0000-4000-8000-000000000009', 'd0000000-0000-4000-8001-000000000001');

insert into public.project_join_request_resource_selections (
  request_id,
  resource_need_id
)
values
  ('b5000000-0000-4000-8000-000000000001', 'b3000000-0000-4000-8000-000000000001'),
  ('b5000000-0000-4000-8000-000000000001', 'b3000000-0000-4000-8000-000000000002'),
  ('b5000000-0000-4000-8000-000000000002', 'b3000000-0000-4000-8000-000000000003'),
  ('b5000000-0000-4000-8000-000000000006', 'b3000000-0000-4000-8000-000000000004'),
  ('b5000000-0000-4000-8000-000000000008', 'b3000000-0000-4000-8000-000000000006'),
  ('b5000000-0000-4000-8000-000000000010', 'b3000000-0000-4000-8000-000000000005');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);

select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000002')$$,
  '22023',
  'Skill contribution triage must exactly partition the request selections.',
  'the two-argument overload cannot accept a selected-contribution request'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000002', '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000003'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Skill contribution triage must exactly partition the request selections.',
  'missing skill triage rejects the whole acceptance'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000002', array['d0000000-0000-4000-8001-000000000001'::uuid], array['d0000000-0000-4000-8001-000000000001'::uuid], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000003'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'A skill cannot appear in more than one acceptance disposition.',
  'one item cannot appear across two dispositions'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000002', array['d0000000-0000-4000-8006-000000000001'::uuid], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000003'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Skill contribution triage must exactly partition the request selections.',
  'an unselected item cannot be classified'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000002', array[null::uuid], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000003'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Skill contribution triage cannot contain null identifiers.',
  'null classified IDs reject explicitly'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000002', array['d0000000-0000-4000-8001-000000000001'::uuid, 'd0000000-0000-4000-8001-000000000001'::uuid], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000003'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Each skill disposition array must contain unique identifiers.',
  'duplicates within one disposition reject explicitly'
);

reset role;
select is(
  (select status from public.project_join_requests where id = 'b5000000-0000-4000-8000-000000000002'),
  'pending',
  'invalid triage leaves the request pending'
);
select is(
  (select count(*) from public.project_join_request_skill_acceptance_decisions where request_id = 'b5000000-0000-4000-8000-000000000002')
  + (select count(*) from public.project_join_request_resource_acceptance_decisions where request_id = 'b5000000-0000-4000-8000-000000000002')
  + (select count(*) from public.project_memberships where originating_request_id = 'b5000000-0000-4000-8000-000000000002'),
  0::bigint,
  'invalid triage rolls back decisions and membership atomically'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.triage_mixed_membership',
  public.accept_project_join_request(
    'b1000000-0000-4000-8000-000000000001',
    'b5000000-0000-4000-8000-000000000001',
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array['d0000000-0000-4000-8003-000000000002'::uuid],
    '{}'::uuid[],
    '{}'::uuid[],
    array['b3000000-0000-4000-8000-000000000002'::uuid],
    array['b3000000-0000-4000-8000-000000000001'::uuid]
  )::text,
  true
);

reset role;
select results_eq(
  $$
    select 'skill'::text, skill_id, disposition
    from public.project_join_request_skill_acceptance_decisions
    where request_id = 'b5000000-0000-4000-8000-000000000001'
    union all
    select 'resource'::text, resource_need_id, disposition
    from public.project_join_request_resource_acceptance_decisions
    where request_id = 'b5000000-0000-4000-8000-000000000001'
    order by 1, 2
  $$,
  $$values
    ('resource'::text, 'b3000000-0000-4000-8000-000000000001'::uuid, 'extra'::text),
    ('resource'::text, 'b3000000-0000-4000-8000-000000000002'::uuid, 'already_found'::text),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid, 'needed'::text),
    ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid, 'already_found'::text)
  $$,
  'mixed acceptance stores every exact historical disposition'
);
select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.triage_mixed_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.triage_mixed_membership')::uuid
    order by 1, 2
  $$,
  $$values
    ('resource'::text, 'b3000000-0000-4000-8000-000000000001'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid)
  $$,
  'only needed and extra seed current commitments'
);
select is(
  (select count(*) from public.project_join_request_skill_selections where request_id = 'b5000000-0000-4000-8000-000000000001')
  + (select count(*) from public.project_join_request_resource_selections where request_id = 'b5000000-0000-4000-8000-000000000001'),
  4::bigint,
  'acceptance leaves every original request selection unchanged'
);
select is(
  (select count(*) from public.project_group_chats where project_id = 'b2000000-0000-4000-8000-000000000001'),
  1::bigint,
  'triaged acceptance still activates the Project chat atomically'
);
select is(
  (select count(*) from private.audit_events where action = 'project.join_request_accepted' and target_id = 'b2000000-0000-4000-8000-000000000001'),
  1::bigint,
  'triaged acceptance records exactly the canonical acceptance audit event'
);
select is(
  (select count(*) from private.outbox_events where event_type = 'project.join_request_accepted' and payload ->> 'project_id' = 'b2000000-0000-4000-8000-000000000001'),
  1::bigint,
  'triaged acceptance emits exactly the canonical acceptance outbox event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.join_request_accepted'
      and payload ->> 'project_id' = 'b2000000-0000-4000-8000-000000000001'
      and (
        payload ?| array['needed_skill_ids', 'already_found_skill_ids', 'extra_skill_ids', 'needed_resource_need_ids', 'already_found_resource_need_ids', 'extra_resource_need_ids', 'request_message']
        or payload::text like '%Private mixed message%'
      )
  ),
  0::bigint,
  'the acceptance event exposes no triage arrays, labels, or private message'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select is(
  public.replace_project_membership_commitments(
    'b1000000-0000-4000-8000-000000000001',
    current_setting('test.triage_mixed_membership')::uuid,
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array['b3000000-0000-4000-8000-000000000001'::uuid],
    array['d0000000-0000-4000-8003-000000000002'::uuid],
    array['b3000000-0000-4000-8000-000000000002'::uuid]
  ),
  current_setting('test.triage_mixed_membership')::uuid,
  'current commitments remain independently editable'
);
reset role;
select results_eq(
  $$
    select disposition
    from public.project_join_request_skill_acceptance_decisions
    where request_id = 'b5000000-0000-4000-8000-000000000001'
    order by skill_id
  $$,
  $$values ('needed'::text), ('already_found'::text)$$,
  'editing current commitments never rewrites historical decisions'
);
select throws_ok(
  $$update public.project_join_request_skill_acceptance_decisions set disposition = 'extra' where request_id = 'b5000000-0000-4000-8000-000000000001'$$,
  '55000',
  'Project join-request acceptance decisions are immutable.',
  'skill acceptance decisions cannot be updated even by a trusted SQL path'
);
select throws_ok(
  $$delete from public.project_join_request_resource_acceptance_decisions where request_id = 'b5000000-0000-4000-8000-000000000001'$$,
  '55000',
  'Project join-request acceptance decisions are immutable.',
  'resource acceptance decisions cannot be deleted even by a trusted SQL path'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000003')$$,
  'zero selections remain compatible with two-argument acceptance'
);
select lives_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000004', '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[])$$,
  'zero selections also accept through explicit all-empty triage'
);

select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000008', true);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000008', 'b5000000-0000-4000-8000-000000000007', array['d0000000-0000-4000-8001-000000000001'::uuid], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[])$$,
  '42501',
  'Only the project creator can accept join requests.',
  'a requester cannot triage their own request'
);
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000008', 'b5000000-0000-4000-8000-000000000007', array['d0000000-0000-4000-8001-000000000001'::uuid], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[])$$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected creator identity is rejected'
);

reset role;
delete from public.proposal_skills
where proposal_id = 'b2000000-0000-4000-8000-000000000005';
update public.project_resource_needs
set state = 'closed', updated_at = statement_timestamp(), closed_at = statement_timestamp()
where id = 'b3000000-0000-4000-8000-000000000004';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000005', array['d0000000-0000-4000-8003-000000000002'::uuid], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Every needed skill must remain a current Proposal requirement.',
  'a removed useful skill cannot be classified needed'
);
select lives_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000005', '{}'::uuid[], '{}'::uuid[], array['d0000000-0000-4000-8003-000000000002'::uuid], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[])$$,
  'a removed historical skill may still be classified extra'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000006', '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000004'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Every needed resource must remain open and belong to this Project.',
  'a closed selected resource cannot be classified needed'
);
select lives_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000006', '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000004'::uuid], '{}'::uuid[])$$,
  'a closed historical resource may still be classified already found'
);
select throws_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000010', '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000005'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  '22023',
  'Every needed resource must remain open and belong to this Project.',
  'a selected resource from another Project cannot be classified needed'
);
select lives_ok(
  $$select public.accept_project_join_request('b1000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000008', '{}'::uuid[], '{}'::uuid[], '{}'::uuid[], array['b3000000-0000-4000-8000-000000000006'::uuid], '{}'::uuid[], '{}'::uuid[])$$,
  'a Tavolo accepts resource triage while all skill arrays stay empty'
);

reset role;
select throws_ok(
  $$
    insert into public.project_memberships (
      project_id,
      participant_profile_id,
      originating_request_id,
      joined_at
    ) values (
      'b2000000-0000-4000-8000-000000000009',
      'b1000000-0000-4000-8000-000000000010',
      'b5000000-0000-4000-8000-000000000009',
      statement_timestamp()
    )
  $$,
  '55000',
  'Contribution triage must be complete before membership creation.',
  'membership creation from a selected request fails closed without decisions'
);
select is(
  (select count(*) from public.project_memberships where originating_request_id = 'b5000000-0000-4000-8000-000000000009'),
  0::bigint,
  'the incomplete trusted membership insert rolls back fully'
);

-- End the first membership and prove the next request attempt owns a fresh
-- decision and commitment set, including a current useful-skill requirement.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000002', true);
select lives_ok(
  format(
    'select public.leave_project(%L::uuid, %L::uuid)',
    'b1000000-0000-4000-8000-000000000002',
    current_setting('test.triage_mixed_membership')
  ),
  'the first participant episode can end before rejoining'
);
reset role;

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id
)
values (
  'b5000000-0000-4000-8000-000000000011',
  'b2000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000002'
);
insert into public.project_join_request_skill_selections (request_id, skill_id)
values (
  'b5000000-0000-4000-8000-000000000011',
  'd0000000-0000-4000-8003-000000000002'
);
insert into public.project_join_request_resource_selections (
  request_id,
  resource_need_id
)
values (
  'b5000000-0000-4000-8000-000000000011',
  'b3000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-4000-8000-000000000001', true);
select set_config(
  'test.triage_rejoin_membership',
  public.accept_project_join_request(
    'b1000000-0000-4000-8000-000000000001',
    'b5000000-0000-4000-8000-000000000011',
    array['d0000000-0000-4000-8003-000000000002'::uuid],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    array['b3000000-0000-4000-8000-000000000001'::uuid]
  )::text,
  true
);
reset role;

select isnt(
  current_setting('test.triage_rejoin_membership')::uuid,
  current_setting('test.triage_mixed_membership')::uuid,
  'rejoining creates an independent membership episode'
);
select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.triage_rejoin_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.triage_rejoin_membership')::uuid
    order by 1, 2
  $$,
  $$values
    ('resource'::text, 'b3000000-0000-4000-8000-000000000001'::uuid),
    ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid)
  $$,
  'rejoin seeds only the second request needed and extra decisions'
);
select is(
  (select disposition from public.project_join_request_skill_acceptance_decisions where request_id = 'b5000000-0000-4000-8000-000000000011'),
  'needed',
  'a current useful Proposal skill is valid as needed on rejoin'
);

select * from finish();

rollback;
