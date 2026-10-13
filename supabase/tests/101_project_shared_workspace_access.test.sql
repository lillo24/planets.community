begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

insert into auth.users (id, email)
values
  ('f1100000-0000-4000-8000-000000000001', 'workspace-creator@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000002', 'workspace-cocreator@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000003', 'workspace-coorganizer@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000004', 'workspace-participant@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000005', 'workspace-pending@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000006', 'workspace-rejected@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000007', 'workspace-withdrawn@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000008', 'workspace-former@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000009', 'workspace-unrelated@planets.invalid'),
  ('f1100000-0000-4000-8000-000000000010', 'workspace-member-delegate@planets.invalid');

insert into public.profiles (id, display_name)
select id, 'Workspace ' || row_number() over (order by id)
from auth.users
where id between
  'f1100000-0000-4000-8000-000000000001'::uuid and
  'f1100000-0000-4000-8000-000000000010'::uuid;

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  starts_at, ends_at, event_timezone, country_code, locality,
  administrative_area, public_location_label, published_at
)
values (
  'f1200000-0000-4000-8000-000000000001',
  'f1100000-0000-4000-8000-000000000001',
  'published',
  'Shared workspace access Project',
  'Exercises current workspace authorization.',
  'Workspace URLs are private to current managers and participants.',
  statement_timestamp() + interval '2 days',
  statement_timestamp() + interval '3 days',
  'Europe/Rome', 'IT', 'Trento', 'Provincia autonoma di Trento',
  'Trento', statement_timestamp() - interval '1 day'
);

insert into public.project_delegate_invitations (
  id, project_id, owner_profile_id, token_digest, status, created_at,
  expires_at, accepted_at, accepted_by_profile_id, issuer_profile_id,
  requested_authority_role
)
values
  (
    'f1300000-0000-4000-8000-000000000001',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    extensions.digest('workspace-cocreator', 'sha256'),
    'accepted', '2026-09-20 10:00:00+00'::timestamptz,
    '2026-09-27 10:00:00+00'::timestamptz,
    '2026-09-21 10:00:00+00'::timestamptz,
    'f1100000-0000-4000-8000-000000000002',
    'f1100000-0000-4000-8000-000000000001', 'co_creator'
  ),
  (
    'f1300000-0000-4000-8000-000000000002',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    extensions.digest('workspace-coorganizer', 'sha256'),
    'accepted', '2026-09-20 10:00:00+00'::timestamptz,
    '2026-09-27 10:00:00+00'::timestamptz,
    '2026-09-21 10:00:00+00'::timestamptz,
    'f1100000-0000-4000-8000-000000000003',
    'f1100000-0000-4000-8000-000000000001', 'co_organizer'
  ),
  (
    'f1300000-0000-4000-8000-000000000003',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    extensions.digest('workspace-member-delegate', 'sha256'),
    'accepted', '2026-09-20 10:00:00+00'::timestamptz,
    '2026-09-27 10:00:00+00'::timestamptz,
    '2026-09-21 10:00:00+00'::timestamptz,
    'f1100000-0000-4000-8000-000000000010',
    'f1100000-0000-4000-8000-000000000001', 'co_organizer'
  );

insert into public.project_delegates (
  id, project_id, owner_profile_id, delegate_profile_id, invitation_id,
  delegated_at, granted_by_profile_id, initial_authority_role, authority_role
)
values
  (
    'f1400000-0000-4000-8000-000000000001',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000002',
    'f1300000-0000-4000-8000-000000000001',
    '2026-09-21 10:00:00+00'::timestamptz,
    'f1100000-0000-4000-8000-000000000001',
    'co_creator', 'co_creator'
  ),
  (
    'f1400000-0000-4000-8000-000000000002',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000003',
    'f1300000-0000-4000-8000-000000000002',
    '2026-09-21 10:00:00+00'::timestamptz,
    'f1100000-0000-4000-8000-000000000001',
    'co_organizer', 'co_organizer'
  ),
  (
    'f1400000-0000-4000-8000-000000000003',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000010',
    'f1300000-0000-4000-8000-000000000003',
    '2026-09-21 10:00:00+00'::timestamptz,
    'f1100000-0000-4000-8000-000000000001',
    'co_organizer', 'co_organizer'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000001',
      'f1200000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'an authorized Project with no workspace returns a deterministic empty set'
);
select results_eq(
  $$
    select project_id, workspace_url
    from public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000001',
      'f1200000-0000-4000-8000-000000000001',
      '  https://drive.google.com/drive/folders/private-token?usp=sharing  '
    )
  $$,
  $$values (
    'f1200000-0000-4000-8000-000000000001'::uuid,
    'https://drive.google.com/drive/folders/private-token?usp=sharing'::text
  )$$,
  'the Creator can configure and canonically trim a workspace before chat activation'
);
reset role;
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id = 'f1200000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'workspace management does not depend on an activated Project chat'
);
set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select workspace_url
    from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000002',
      'f1200000-0000-4000-8000-000000000001'
    )
  ),
  'https://drive.google.com/drive/folders/private-token?usp=sharing',
  'a Co-creator can read the workspace without participant membership'
);
select lives_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000002',
      'f1200000-0000-4000-8000-000000000001',
      'https://nextcloud.example.org/s/project-room#materials'
    )
  $$,
  'a Co-creator can replace the workspace'
);

select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000003',
      'f1200000-0000-4000-8000-000000000001',
      'https://dropbox.com/scl/fo/private-share'
    )
  $$,
  'a Co-organizer can replace the workspace'
);

reset role;
update public.project_delegates
set authority_role = 'co_organizer'
where id = 'f1400000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000002',
      'f1200000-0000-4000-8000-000000000001',
      'https://notion.so/shared-project'
    )
  $$,
  'demotion from Co-creator to Co-organizer preserves workspace management'
);

select throws_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000002',
      'f1200000-0000-4000-8000-000000000001',
      'http://drive.google.com/folder'
    )
  $$,
  '22023',
  'A valid absolute HTTPS workspace URL is required.',
  'HTTP workspace links are rejected'
);
select throws_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000002',
      'f1200000-0000-4000-8000-000000000001',
      'https://user:password@example.org/private'
    )
  $$,
  '22023',
  'A valid absolute HTTPS workspace URL is required.',
  'embedded URL credentials are rejected'
);
select throws_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000002',
      'f1200000-0000-4000-8000-000000000001',
      'https://example.org/private folder'
    )
  $$,
  '22023',
  'A valid absolute HTTPS workspace URL is required.',
  'workspace whitespace is rejected'
);

reset role;
insert into public.project_join_requests (
  id, project_id, requester_profile_id, status, created_at,
  resolved_at, resolved_by_profile_id
)
values
  (
    'f1500000-0000-4000-8000-000000000001',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000004', 'accepted',
    statement_timestamp() - interval '2 hours',
    statement_timestamp() - interval '90 minutes',
    'f1100000-0000-4000-8000-000000000001'
  ),
  (
    'f1500000-0000-4000-8000-000000000002',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000005', 'pending',
    statement_timestamp() - interval '2 hours', null, null
  ),
  (
    'f1500000-0000-4000-8000-000000000003',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000006', 'rejected',
    statement_timestamp() - interval '2 hours',
    statement_timestamp() - interval '90 minutes',
    'f1100000-0000-4000-8000-000000000001'
  ),
  (
    'f1500000-0000-4000-8000-000000000004',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000007', 'withdrawn',
    statement_timestamp() - interval '2 hours',
    statement_timestamp() - interval '90 minutes',
    'f1100000-0000-4000-8000-000000000007'
  ),
  (
    'f1500000-0000-4000-8000-000000000005',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000008', 'accepted',
    statement_timestamp() - interval '4 hours',
    statement_timestamp() - interval '3 hours',
    'f1100000-0000-4000-8000-000000000001'
  ),
  (
    'f1500000-0000-4000-8000-000000000006',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000010', 'accepted',
    statement_timestamp() - interval '2 hours',
    statement_timestamp() - interval '90 minutes',
    'f1100000-0000-4000-8000-000000000001'
  );

insert into public.project_memberships (
  id, project_id, participant_profile_id, originating_request_id,
  joined_at, left_at
)
values
  (
    'f1600000-0000-4000-8000-000000000001',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000004',
    'f1500000-0000-4000-8000-000000000001',
    statement_timestamp() - interval '90 minutes', null
  ),
  (
    'f1600000-0000-4000-8000-000000000002',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000008',
    'f1500000-0000-4000-8000-000000000005',
    statement_timestamp() - interval '3 hours',
    statement_timestamp() - interval '1 hour'
  ),
  (
    'f1600000-0000-4000-8000-000000000003',
    'f1200000-0000-4000-8000-000000000001',
    'f1100000-0000-4000-8000-000000000010',
    'f1500000-0000-4000-8000-000000000006',
    statement_timestamp() - interval '90 minutes', null
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000004',
  true
);
select is(
  (
    select workspace_url
    from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000004',
      'f1200000-0000-4000-8000-000000000001'
    )
  ),
  'https://notion.so/shared-project',
  'a current ordinary participant can read the workspace'
);
select throws_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000004',
      'f1200000-0000-4000-8000-000000000001',
      'https://example.org/participant-write'
    )
  $$,
  '42501',
  'Only a current Project manager can manage its workspace.',
  'an ordinary participant cannot mutate the workspace'
);

select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000005',
  true
);
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000005',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current profile cannot access this Project workspace.',
  'a pending requester cannot read the workspace'
);
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000006',
  true
);
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000006',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current profile cannot access this Project workspace.',
  'a rejected requester cannot read the workspace'
);
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000007',
  true
);
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000007',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current profile cannot access this Project workspace.',
  'a withdrawn requester cannot read the workspace'
);
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000008',
  true
);
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000008',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current profile cannot access this Project workspace.',
  'a former participant cannot read the current workspace'
);
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000009',
  true
);
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000009',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current profile cannot access this Project workspace.',
  'an unrelated authenticated profile cannot read the workspace'
);

reset role;
update public.project_delegates
set revoked_at = statement_timestamp(),
    revoked_by_profile_id = 'f1100000-0000-4000-8000-000000000001'
where id = 'f1400000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select public.clear_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000003',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only a current Project manager can manage its workspace.',
  'a revoked delegate immediately loses workspace mutation'
);
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000003',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current profile cannot access this Project workspace.',
  'a revoked non-participant delegate also loses workspace read'
);

reset role;
update public.project_delegates
set revoked_at = statement_timestamp(),
    revoked_by_profile_id = 'f1100000-0000-4000-8000-000000000001'
where id = 'f1400000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000010',
  true
);
select is(
  (
    select workspace_url
    from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000010',
      'f1200000-0000-4000-8000-000000000001'
    )
  ),
  'https://notion.so/shared-project',
  'a revoked delegate who remains a current participant keeps read access'
);
select throws_ok(
  $$
    select public.set_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000010',
      'f1200000-0000-4000-8000-000000000001',
      'https://example.org/no-longer-manager'
    )
  $$,
  '42501',
  'Only a current Project manager can manage its workspace.',
  'role revocation changes a current participant from read-write to read-only'
);

select set_config(
  'request.jwt.claim.sub',
  'f1100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.clear_project_shared_workspace(
    'f1100000-0000-4000-8000-000000000001',
    'f1200000-0000-4000-8000-000000000001'
  ),
  true,
  'the Creator can clear the configured workspace'
);
select is(
  public.clear_project_shared_workspace(
    'f1100000-0000-4000-8000-000000000001',
    'f1200000-0000-4000-8000-000000000001'
  ),
  false,
  'clearing an already-empty workspace is idempotent'
);

reset role;
set local role anon;
select throws_ok(
  $$
    select * from public.get_own_project_shared_workspace(
      'f1100000-0000-4000-8000-000000000001',
      'f1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  null,
  'anonymous callers cannot execute the workspace read RPC'
);

reset role;
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.metadata::text like '%private-token%'
  ) + (
    select count(*)
    from private.outbox_events as event
    where event.payload::text like '%private-token%'
  ),
  0::bigint,
  'raw workspace URLs never enter generic audit or outbox payloads'
);

-- WORKSPACE02: new canonical APIs share the existing actor matrix.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000001', true);
select is(jsonb_array_length(public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000001', 'f1200000-0000-4000-8000-000000000001')), 0, 'new list distinguishes genuine empty state');
select set_config('test.workspace_first', public.save_project_workspace_link(
  'f1100000-0000-4000-8000-000000000001', 'f1200000-0000-4000-8000-000000000001',
  '  Documento privato  ', ' https://example.org/document ')::text, true);
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000002', true);
select set_config('test.workspace_second', public.save_project_workspace_link(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001',
  'Sheet Budget', 'https://example.org/sheet')::text, true);
select is(public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001')->0->>'display_name',
  'Documento privato', 'names are trimmed and creation ordering is stable');
select is(jsonb_array_length(public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001')), 2, 'two independent named links coexist');
select is(public.save_project_workspace_link(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001',
  'Budget aggiornato', 'https://example.org/updated', current_setting('test.workspace_second')::uuid),
  current_setting('test.workspace_second')::uuid, 'editing preserves item identity');
select is(public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001')->0->>'workspace_url',
  'https://example.org/document', 'editing one entry preserves its neighbor');
select throws_ok($$ select public.save_project_workspace_link(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001', '', 'https://example.org') $$,
  '22023', 'A valid workspace link name is required.', 'empty names fail');
select throws_ok($$ select public.save_project_workspace_link(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001', repeat('x',121), 'https://example.org') $$,
  '22023', 'A valid workspace link name is required.', 'long names fail');
select throws_ok($$ select public.save_project_workspace_link(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'http://example.org') $$,
  '22023', 'A valid absolute HTTPS workspace URL is required.', 'new mutation enforces HTTPS');
select throws_ok($$ select public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000001', 'f1200000-0000-4000-8000-000000000001') $$,
  '42501', null, 'list rejects expected-identity mismatch');
select lives_ok($$ select public.set_project_shared_workspace(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001', 'https://example.org/legacy') $$,
  'legacy update shares the canonical entry');
select is(public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001')->0->>'display_name',
  'Documento privato', 'legacy update preserves editable name');
select is(public.clear_project_shared_workspace(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001'), true, 'legacy clear removes only its entry');
select is(jsonb_array_length(public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001')), 1, 'legacy clear preserves extra links');
select is((select count(*) from public.get_own_project_shared_workspace(
  'f1100000-0000-4000-8000-000000000002', 'f1200000-0000-4000-8000-000000000001')), 0::bigint, 'legacy deletion does not promote an unrelated link');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000003', true);
select throws_ok($$ select public.list_project_workspace_links('f1100000-0000-4000-8000-000000000003', 'f1200000-0000-4000-8000-000000000001') $$, '42501', null, 'non-current actor 3 cannot read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000003', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 3 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000003', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 3 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000004', true);
select is(jsonb_array_length(public.list_project_workspace_links('f1100000-0000-4000-8000-000000000004', 'f1200000-0000-4000-8000-000000000001')), 1, 'current participant 4 can read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000004', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 4 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000004', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 4 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000005', true);
select throws_ok($$ select public.list_project_workspace_links('f1100000-0000-4000-8000-000000000005', 'f1200000-0000-4000-8000-000000000001') $$, '42501', null, 'non-current actor 5 cannot read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000005', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 5 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000005', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 5 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000006', true);
select throws_ok($$ select public.list_project_workspace_links('f1100000-0000-4000-8000-000000000006', 'f1200000-0000-4000-8000-000000000001') $$, '42501', null, 'non-current actor 6 cannot read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000006', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 6 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000006', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 6 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000007', true);
select throws_ok($$ select public.list_project_workspace_links('f1100000-0000-4000-8000-000000000007', 'f1200000-0000-4000-8000-000000000001') $$, '42501', null, 'non-current actor 7 cannot read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000007', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 7 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000007', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 7 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000008', true);
select throws_ok($$ select public.list_project_workspace_links('f1100000-0000-4000-8000-000000000008', 'f1200000-0000-4000-8000-000000000001') $$, '42501', null, 'non-current actor 8 cannot read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000008', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 8 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000008', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 8 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000009', true);
select throws_ok($$ select public.list_project_workspace_links('f1100000-0000-4000-8000-000000000009', 'f1200000-0000-4000-8000-000000000001') $$, '42501', null, 'non-current actor 9 cannot read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000009', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 9 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000009', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 9 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000010', true);
select is(jsonb_array_length(public.list_project_workspace_links('f1100000-0000-4000-8000-000000000010', 'f1200000-0000-4000-8000-000000000001')), 1, 'current participant 10 can read');
select throws_ok($$ select public.save_project_workspace_link('f1100000-0000-4000-8000-000000000010', 'f1200000-0000-4000-8000-000000000001', 'Doc', 'https://example.org') $$, '42501', null, 'non-manager 10 cannot add');
select throws_ok($$ select public.remove_project_workspace_link('f1100000-0000-4000-8000-000000000010', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$, '42501', null, 'non-manager 10 cannot remove');
select set_config('request.jwt.claim.sub', 'f1100000-0000-4000-8000-000000000001', true);
select is(public.remove_project_workspace_link(
  'f1100000-0000-4000-8000-000000000001', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid), true,
  'individual removal succeeds');
select throws_ok($$ select public.remove_project_workspace_link(
  'f1100000-0000-4000-8000-000000000001', 'f1200000-0000-4000-8000-000000000001', current_setting('test.workspace_second')::uuid) $$,
  '42501', null, 'missing items fail explicitly');
reset role;
set local role anon;
select throws_ok($$ select public.list_project_workspace_links(null, null) $$, '42501', null, 'anonymous list denied');
select throws_ok($$ select public.save_project_workspace_link(null, null, 'Doc','https://example.org') $$, '42501', null, 'anonymous add denied');
select throws_ok($$ select public.remove_project_workspace_link(null, null, null) $$, '42501', null, 'anonymous removal denied');
reset role;

update public.project_memberships set removed_at=statement_timestamp(),
  removed_by_profile_id='f1100000-0000-4000-8000-000000000001'
  where id='f1600000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','f1100000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.list_project_workspace_links(
  'f1100000-0000-4000-8000-000000000004','f1200000-0000-4000-8000-000000000001')$$,
  '42501',null,'removed member loses list access immediately');
reset role;

select * from finish();
rollback;
