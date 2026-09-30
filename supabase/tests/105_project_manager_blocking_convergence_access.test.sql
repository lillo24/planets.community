begin;

select no_plan();

insert into auth.users (id, email)
select
  format('fd100000-0000-4000-8000-%s', lpad(suffix, 12, '0'))::uuid,
  format('manager-blocking-%s@planets.invalid', suffix)
from unnest(array[
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  '13', '14', '15', '16', '17', '18'
]) as fixture(suffix);

insert into public.profiles (id, display_name)
select id, 'Manager blocking ' || row_number() over (order by id)
from auth.users
where id between
  'fd100000-0000-4000-8000-000000000001'::uuid and
  'fd100000-0000-4000-8000-000000000018'::uuid;

insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/fd1f0000-0000-4000-8000-000000000001.webp',
  'interactions'
from public.profiles as profile
where profile.id between
  'fd100000-0000-4000-8000-000000000001'::uuid and
  'fd100000-0000-4000-8000-000000000018'::uuid;

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  starts_at, ends_at, event_timezone, country_code, locality,
  public_location_label, published_at
)
values (
  'fd200000-0000-4000-8000-000000000001',
  'fd100000-0000-4000-8000-000000000001',
  'published', 'Manager blocking Project',
  'Exercises blocking against the complete current manager set.',
  'Creator, Co-creator, and Co-organizer authority must converge.',
  statement_timestamp() + interval '2 days',
  statement_timestamp() + interval '3 days',
  'Europe/Rome', 'IT', 'Trento', 'Trento',
  statement_timestamp() - interval '1 day'
);

insert into public.proposal_meeting_details (
  proposal_id, exact_meeting_text, exact_location_visibility
)
values (
  'fd200000-0000-4000-8000-000000000001',
  'Meet at the shared workshop entrance',
  'participants'
);

update public.projects
set people_capacity = 20
where id = 'fd200000-0000-4000-8000-000000000001';

insert into public.project_delegate_invitations (
  id, project_id, owner_profile_id, token_digest, status, created_at,
  expires_at, accepted_at, accepted_by_profile_id, issuer_profile_id,
  requested_authority_role
)
values
  (
    'fd300000-0000-4000-8000-000000000001',
    'fd200000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    extensions.digest('manager-blocking-cocreator', 'sha256'),
    'accepted', '2026-09-20 10:00:00+00'::timestamptz,
    '2026-09-27 10:00:00+00'::timestamptz,
    '2026-09-21 10:00:00+00'::timestamptz,
    'fd100000-0000-4000-8000-000000000002',
    'fd100000-0000-4000-8000-000000000001', 'co_creator'
  ),
  (
    'fd300000-0000-4000-8000-000000000002',
    'fd200000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    extensions.digest('manager-blocking-coorganizer', 'sha256'),
    'accepted', '2026-09-20 10:00:00+00'::timestamptz,
    '2026-09-27 10:00:00+00'::timestamptz,
    '2026-09-21 10:00:00+00'::timestamptz,
    'fd100000-0000-4000-8000-000000000003',
    'fd100000-0000-4000-8000-000000000001', 'co_organizer'
  ),
  (
    'fd300000-0000-4000-8000-000000000003',
    'fd200000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    extensions.digest('manager-blocking-revoked', 'sha256'),
    'accepted', '2026-09-20 10:00:00+00'::timestamptz,
    '2026-09-27 10:00:00+00'::timestamptz,
    '2026-09-21 10:00:00+00'::timestamptz,
    'fd100000-0000-4000-8000-000000000004',
    'fd100000-0000-4000-8000-000000000001', 'co_organizer'
  );

insert into public.project_delegates (
  id, project_id, owner_profile_id, delegate_profile_id, invitation_id,
  delegated_at, revoked_at, revoked_by_profile_id, granted_by_profile_id,
  initial_authority_role, authority_role
)
values
  (
    'fd400000-0000-4000-8000-000000000001',
    'fd200000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000002',
    'fd300000-0000-4000-8000-000000000001',
    '2026-09-21 10:00:00+00'::timestamptz, null, null,
    'fd100000-0000-4000-8000-000000000001',
    'co_creator', 'co_creator'
  ),
  (
    'fd400000-0000-4000-8000-000000000002',
    'fd200000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000003',
    'fd300000-0000-4000-8000-000000000002',
    '2026-09-21 10:00:00+00'::timestamptz, null, null,
    'fd100000-0000-4000-8000-000000000001',
    'co_organizer', 'co_organizer'
  ),
  (
    'fd400000-0000-4000-8000-000000000003',
    'fd200000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000004',
    'fd300000-0000-4000-8000-000000000003',
    '2026-09-21 10:00:00+00'::timestamptz,
    '2026-09-22 10:00:00+00'::timestamptz,
    'fd100000-0000-4000-8000-000000000001',
    'fd100000-0000-4000-8000-000000000001',
    'co_organizer', 'co_organizer'
  );

insert into public.project_join_requests (
  id, project_id, requester_profile_id, status, created_at,
  resolved_at, resolved_by_profile_id
)
values (
  'fd500000-0000-4000-8000-000000000001',
  'fd200000-0000-4000-8000-000000000001',
  'fd100000-0000-4000-8000-000000000017',
  'accepted', statement_timestamp() - interval '2 days',
  statement_timestamp() - interval '1 day',
  'fd100000-0000-4000-8000-000000000001'
);

insert into public.project_memberships (
  id, project_id, participant_profile_id, originating_request_id, joined_at
)
values (
  'fd600000-0000-4000-8000-000000000001',
  'fd200000-0000-4000-8000-000000000001',
  'fd100000-0000-4000-8000-000000000017',
  'fd500000-0000-4000-8000-000000000001',
  statement_timestamp() - interval '1 day'
);

insert into public.project_shared_workspaces (project_id, workspace_url)
values (
  'fd200000-0000-4000-8000-000000000001',
  'https://workspace.example.org/manager-blocking'
);

select results_eq(
  $$
    select profile_id
    from private.current_project_manager_profile_ids(
      'fd200000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    values
      ('fd100000-0000-4000-8000-000000000001'::uuid),
      ('fd100000-0000-4000-8000-000000000002'::uuid),
      ('fd100000-0000-4000-8000-000000000003'::uuid)
  $$,
  'the canonical manager set includes Creator and active delegates but excludes the revoked delegate'
);

select results_eq(
  $$
    select current_participant_count, current_people_count
    from private.project_capacity_snapshot(
      'fd200000-0000-4000-8000-000000000001'
    )
  $$,
  $$values (1, 2)$$,
  'delegated managers do not consume Project capacity'
);

-- A fresh request is denied in either block direction for every current
-- manager, while a revoked delegate is outside the barrier.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000001', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000001',
  'fd100000-0000-4000-8000-000000000005'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Creator-to-requester blocking denies a fresh request generically'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000001', true);
select public.unblock_user(
  'fd100000-0000-4000-8000-000000000001',
  'fd100000-0000-4000-8000-000000000005'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000005',
  'fd100000-0000-4000-8000-000000000001'
);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'requester-to-Creator blocking denies a fresh request generically'
);
select public.unblock_user(
  'fd100000-0000-4000-8000-000000000005',
  'fd100000-0000-4000-8000-000000000001'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000002',
  'fd100000-0000-4000-8000-000000000005'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Co-creator-to-requester blocking denies a fresh request generically'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select public.unblock_user(
  'fd100000-0000-4000-8000-000000000002',
  'fd100000-0000-4000-8000-000000000005'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000005',
  'fd100000-0000-4000-8000-000000000002'
);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'requester-to-Co-creator blocking denies a fresh request generically'
);
select public.unblock_user(
  'fd100000-0000-4000-8000-000000000005',
  'fd100000-0000-4000-8000-000000000002'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000003', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000003',
  'fd100000-0000-4000-8000-000000000005'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Co-organizer-to-requester blocking denies a fresh request generically'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000003', true);
select public.unblock_user(
  'fd100000-0000-4000-8000-000000000003',
  'fd100000-0000-4000-8000-000000000005'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000005',
  'fd100000-0000-4000-8000-000000000003'
);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'requester-to-Co-organizer blocking denies a fresh request generically'
);
select public.unblock_user(
  'fd100000-0000-4000-8000-000000000005',
  'fd100000-0000-4000-8000-000000000003'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000004', true);
select public.block_user(
  'fd100000-0000-4000-8000-000000000004',
  'fd100000-0000-4000-8000-000000000005'
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select set_config(
  'test.revoked_manager_request',
  public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )::text,
  true
);
select lives_ok(
  $$select public.withdraw_project_join_request(
    'fd100000-0000-4000-8000-000000000005',
    current_setting('test.revoked_manager_request')::uuid
  )$$,
  'a revoked delegate block does not deny or strand a fresh request'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000018', true);
select set_config(
  'test.unblocked_request',
  public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000018',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )::text,
  true
);
select lives_ok(
  $$select public.withdraw_project_join_request(
    'fd100000-0000-4000-8000-000000000018',
    current_setting('test.unblocked_request')::uuid
  )$$,
  'an unblocked requester retains the ordinary request path'
);

reset role;
update public.projects
set people_capacity = 2
where id = 'fd200000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000005', true);
select throws_ok(
  $$select public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000005',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This Project is full.',
  'capacity behavior remains unchanged when no current-manager block exists'
);
reset role;
update public.projects
set people_capacity = 20
where id = 'fd200000-0000-4000-8000-000000000001';

-- Pending-request cleanup uses the current manager set and keeps exactly one
-- terminal transition per request.
insert into public.project_join_requests (
  id, project_id, requester_profile_id, status, created_at
)
values
  ('fd500000-0000-4000-8000-000000000006', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000006', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000007', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000007', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000008', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000008', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000009', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000009', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000010', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000010', 'pending', statement_timestamp());

set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select public.block_user('fd100000-0000-4000-8000-000000000002', 'fd100000-0000-4000-8000-000000000006');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000003', true);
select public.block_user('fd100000-0000-4000-8000-000000000003', 'fd100000-0000-4000-8000-000000000007');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000008', true);
select public.block_user('fd100000-0000-4000-8000-000000000008', 'fd100000-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000009', true);
select public.block_user('fd100000-0000-4000-8000-000000000009', 'fd100000-0000-4000-8000-000000000003');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000004', true);
select public.block_user('fd100000-0000-4000-8000-000000000004', 'fd100000-0000-4000-8000-000000000010');
reset role;

select results_eq(
  $$
    select id, status, resolved_by_profile_id
    from public.project_join_requests
    where id between
      'fd500000-0000-4000-8000-000000000006'::uuid and
      'fd500000-0000-4000-8000-000000000010'::uuid
    order by id
  $$,
  $$
    values
      ('fd500000-0000-4000-8000-000000000006'::uuid, 'rejected'::text, 'fd100000-0000-4000-8000-000000000002'::uuid),
      ('fd500000-0000-4000-8000-000000000007'::uuid, 'rejected'::text, 'fd100000-0000-4000-8000-000000000003'::uuid),
      ('fd500000-0000-4000-8000-000000000008'::uuid, 'withdrawn'::text, 'fd100000-0000-4000-8000-000000000008'::uuid),
      ('fd500000-0000-4000-8000-000000000009'::uuid, 'withdrawn'::text, 'fd100000-0000-4000-8000-000000000009'::uuid),
      ('fd500000-0000-4000-8000-000000000010'::uuid, 'pending'::text, null::uuid)
  $$,
  'current managers reject, requesters withdraw, and a revoked delegate leaves pending state untouched'
);

select is(
  (
    select count(*)
    from private.audit_events
    where action = 'project.join_request_rejected'
      and metadata ->> 'request_id' = 'fd500000-0000-4000-8000-000000000006'
  ),
  1::bigint,
  'manager-side cleanup records exactly one audit transition'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.join_request_rejected'
      and payload ->> 'request_id' = 'fd500000-0000-4000-8000-000000000006'
  ),
  1::bigint,
  'manager-side cleanup records exactly one outbox transition'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select public.unblock_user('fd100000-0000-4000-8000-000000000002', 'fd100000-0000-4000-8000-000000000006');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000006', true);
select public.block_user('fd100000-0000-4000-8000-000000000006', 'fd100000-0000-4000-8000-000000000003');
reset role;
select results_eq(
  $$
    select status, resolved_by_profile_id
    from public.project_join_requests
    where id = 'fd500000-0000-4000-8000-000000000006'
  $$,
  $$values ('rejected'::text, 'fd100000-0000-4000-8000-000000000002'::uuid)$$,
  'a later block does not rewrite an already terminal request'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.join_request_rejected'
      and payload ->> 'request_id' = 'fd500000-0000-4000-8000-000000000006'
  ),
  1::bigint,
  'terminal-state idempotence prevents duplicate request outbox events'
);

-- Acceptance is denied when any current manager has either directional block.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select public.block_user('fd100000-0000-4000-8000-000000000002', 'fd100000-0000-4000-8000-000000000011');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000012', true);
select public.block_user('fd100000-0000-4000-8000-000000000012', 'fd100000-0000-4000-8000-000000000003');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000001', true);
select public.block_user('fd100000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000013');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000003', true);
select public.block_user('fd100000-0000-4000-8000-000000000003', 'fd100000-0000-4000-8000-000000000014');
reset role;

insert into public.project_join_requests (
  id, project_id, requester_profile_id, status, created_at
)
values
  ('fd500000-0000-4000-8000-000000000011', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000011', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000012', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000012', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000013', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000013', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000014', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000014', 'pending', statement_timestamp()),
  ('fd500000-0000-4000-8000-000000000016', 'fd200000-0000-4000-8000-000000000001', 'fd100000-0000-4000-8000-000000000016', 'pending', statement_timestamp());

set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.accept_project_join_request(
    'fd100000-0000-4000-8000-000000000001',
    'fd500000-0000-4000-8000-000000000011',
    '{}'::uuid[], '{}'::uuid[], '{}'::uuid[],
    '{}'::uuid[], '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Creator explicit-triage acceptance is denied by a Co-creator block'
);
select throws_ok(
  $$select public.accept_project_join_request(
    'fd100000-0000-4000-8000-000000000001',
    'fd500000-0000-4000-8000-000000000011'
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Creator compatibility acceptance is denied by a Co-creator block'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$select public.accept_project_join_request_as_manager(
    'fd100000-0000-4000-8000-000000000003',
    'fd500000-0000-4000-8000-000000000011',
    '{}'::uuid[], '{}'::uuid[], '{}'::uuid[],
    '{}'::uuid[], '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'delegated-manager explicit-triage acceptance is denied by another manager block'
);
select throws_ok(
  $$select public.accept_project_join_request_as_manager(
    'fd100000-0000-4000-8000-000000000003',
    'fd500000-0000-4000-8000-000000000011'
  )$$,
  'PT409', 'This interaction is unavailable.',
  'delegated-manager compatibility acceptance is denied by another manager block'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.accept_project_join_request(
    'fd100000-0000-4000-8000-000000000001',
    'fd500000-0000-4000-8000-000000000012'
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Creator acceptance is denied when the requester blocks a Co-organizer'
);

select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$select public.accept_project_join_request_as_manager(
    'fd100000-0000-4000-8000-000000000002',
    'fd500000-0000-4000-8000-000000000013'
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Co-creator acceptance is denied by a Creator block'
);
select throws_ok(
  $$select public.accept_project_join_request_as_manager(
    'fd100000-0000-4000-8000-000000000002',
    'fd500000-0000-4000-8000-000000000014',
    '{}'::uuid[], '{}'::uuid[], '{}'::uuid[],
    '{}'::uuid[], '{}'::uuid[], '{}'::uuid[]
  )$$,
  'PT409', 'This interaction is unavailable.',
  'Co-creator explicit-triage acceptance is denied by a Co-organizer block'
);

reset role;
update public.projects
set people_capacity = 2
where id = 'fd200000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$select public.accept_project_join_request_as_manager(
    'fd100000-0000-4000-8000-000000000002',
    'fd500000-0000-4000-8000-000000000016'
  )$$,
  'PT409', 'This Project is full.',
  'unblocked delegated-manager acceptance preserves the established capacity conflict'
);
reset role;
select is(
  (
    select status
    from public.project_join_requests
    where id = 'fd500000-0000-4000-8000-000000000016'
  ),
  'pending',
  'failed full acceptance preserves pending state'
);
update public.projects
set people_capacity = 20
where id = 'fd200000-0000-4000-8000-000000000001';

-- A revoked-delegate-only block does not affect current-manager acceptance.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000004', true);
select public.block_user('fd100000-0000-4000-8000-000000000004', 'fd100000-0000-4000-8000-000000000015');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000015', true);
select set_config(
  'test.revoked_only_acceptance_request',
  public.request_to_join_project(
    'fd100000-0000-4000-8000-000000000015',
    'fd200000-0000-4000-8000-000000000001', null, '{}'::uuid[], '{}'::uuid[]
  )::text,
  true
);
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000003', true);
select lives_ok(
  $$select public.accept_project_join_request_as_manager(
    'fd100000-0000-4000-8000-000000000003',
    current_setting('test.revoked_only_acceptance_request')::uuid
  )$$,
  'a revoked-delegate-only block does not deny delegated-manager acceptance'
);
reset role;
select is(
  (
    select count(*)
    from public.project_memberships
    where originating_request_id =
      current_setting('test.revoked_only_acceptance_request')::uuid
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'revoked-delegate-only blocking still produces one current membership'
);

-- Blocking after acceptance does not change established Project membership,
-- group chat, meeting, workspace, or capacity state.
select set_config(
  'test.people_before_existing_member_block',
  (
    select current_people_count::text
    from private.project_capacity_snapshot(
      'fd200000-0000-4000-8000-000000000001'
    )
  ),
  true
);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000002', true);
select public.block_user('fd100000-0000-4000-8000-000000000002', 'fd100000-0000-4000-8000-000000000017');
select set_config('request.jwt.claim.sub', 'fd100000-0000-4000-8000-000000000017', true);
select is(
  (
    select count(*)
    from public.list_own_blocked_profiles(
      'fd100000-0000-4000-8000-000000000017', 50, null, null
    )
  ),
  0::bigint,
  'an accepted member cannot enumerate an inbound manager block'
);
select is(
  (
    select count(*)
    from public.get_own_project_group_chat(
      'fd100000-0000-4000-8000-000000000017',
      'fd200000-0000-4000-8000-000000000001'
    )
    where has_current_entitlement
  ),
  1::bigint,
  'the blocked existing member retains group-chat entitlement'
);
select is(
  (
    select count(*)
    from public.get_project_participant_meeting_details(
      'fd100000-0000-4000-8000-000000000017',
      'fd200000-0000-4000-8000-000000000001'
    )
    where exact_meeting_text = 'Meet at the shared workshop entrance'
  ),
  1::bigint,
  'the blocked existing member retains protected meeting access'
);
select is(
  (
    select count(*)
    from public.get_own_project_shared_workspace(
      'fd100000-0000-4000-8000-000000000017',
      'fd200000-0000-4000-8000-000000000001'
    )
    where workspace_url = 'https://workspace.example.org/manager-blocking'
  ),
  1::bigint,
  'the blocked existing member retains shared-workspace access'
);
reset role;
select is(
  (
    select count(*)
    from public.project_memberships
    where id = 'fd600000-0000-4000-8000-000000000001'
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'blocking does not end an established membership'
);
select is(
  (
    select current_people_count::text
    from private.project_capacity_snapshot(
      'fd200000-0000-4000-8000-000000000001'
    )
  ),
  current_setting('test.people_before_existing_member_block'),
  'blocking does not change current Project occupancy'
);

select * from finish();

rollback;
