begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

insert into auth.users (id, email)
values
  ('e8100000-0000-4000-8000-000000000001', 'ux-owner@planets.invalid'),
  ('e8100000-0000-4000-8000-000000000002', 'ux-delegate@planets.invalid'),
  ('e8100000-0000-4000-8000-000000000003', 'ux-other@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e8100000-0000-4000-8000-000000000001', 'UX Owner'),
  ('e8100000-0000-4000-8000-000000000002', 'UX Delegate'),
  ('e8100000-0000-4000-8000-000000000003', 'UX Other');

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  starts_at, ends_at, event_timezone, country_code, locality,
  public_location_label, published_at
)
values
  (
    'e8200000-0000-4000-8000-000000000001',
    'e8100000-0000-4000-8000-000000000001',
    'published', 'Delegated Proposal', 'Summary', 'Description',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    'Europe/Rome', 'IT', 'Rome', 'Rome', statement_timestamp()
  ),
  (
    'e8200000-0000-4000-8000-000000000002',
    'e8100000-0000-4000-8000-000000000001',
    'draft', 'Private owner draft', 'Summary', 'Description',
    statement_timestamp() + interval '4 days',
    statement_timestamp() + interval '5 days',
    'Europe/Rome', 'IT', 'Rome', 'Rome', null
  );

insert into public.recurring_activities (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  country_code, locality, public_location_label, published_at
)
values (
  'e8300000-0000-4000-8000-000000000001',
  'e8100000-0000-4000-8000-000000000001',
  'published', 'Delegated Tavolo', 'Summary', 'Description',
  'IT', 'Rome', 'Rome', statement_timestamp()
);

insert into public.project_delegate_invitations (
  id, project_id, owner_profile_id, token_digest, status, created_at,
  expires_at, accepted_at, accepted_by_profile_id, issuer_profile_id
)
values (
  'e8400000-0000-4000-8000-000000000001',
  'e8200000-0000-4000-8000-000000000002',
  'e8100000-0000-4000-8000-000000000001',
  digest('unreachable-draft-fixture', 'sha256'),
  'accepted',
  statement_timestamp() - interval '1 day',
  statement_timestamp() + interval '6 days',
  statement_timestamp(),
  'e8100000-0000-4000-8000-000000000002',
  'e8100000-0000-4000-8000-000000000001'
);
insert into public.project_delegates (
  id, project_id, owner_profile_id, delegate_profile_id, invitation_id,
  delegated_at, granted_by_profile_id
)
values (
  'e8500000-0000-4000-8000-000000000001',
  'e8200000-0000-4000-8000-000000000002',
  'e8100000-0000-4000-8000-000000000001',
  'e8100000-0000-4000-8000-000000000002',
  'e8400000-0000-4000-8000-000000000001',
  (
    select invitation.accepted_at
    from public.project_delegate_invitations as invitation
    where invitation.id = 'e8400000-0000-4000-8000-000000000001'
  ),
  'e8100000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.proposal_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'e8100000-0000-4000-8000-000000000001',
      'e8200000-0000-4000-8000-000000000001'
    )
  ),
  true
);
select set_config(
  'test.tavolo_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'e8100000-0000-4000-8000-000000000001',
      'e8300000-0000-4000-8000-000000000001'
    )
  ),
  true
);

select is(
  public.get_own_project_management_role(
    'e8100000-0000-4000-8000-000000000001',
    'e8200000-0000-4000-8000-000000000001'
  ),
  'creator',
  'the immutable original Creator resolves as creator'
);

select set_config(
  'request.jwt.claim.sub',
  'e8100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.proposal_delegate_id',
  public.accept_project_delegate_invitation(
    'e8100000-0000-4000-8000-000000000002',
    current_setting('test.proposal_token')
  )::text,
  true
);
select set_config(
  'test.tavolo_delegate_id',
  public.accept_project_delegate_invitation(
    'e8100000-0000-4000-8000-000000000002',
    current_setting('test.tavolo_token')
  )::text,
  true
);
select is(
  public.get_own_project_management_role(
    'e8100000-0000-4000-8000-000000000002',
    'e8200000-0000-4000-8000-000000000001'
  ),
  'co_organizer',
  'an active Proposal delegate resolves as Co-organizer'
);
select is(
  public.get_own_project_management_role(
    'e8100000-0000-4000-8000-000000000002',
    'e8300000-0000-4000-8000-000000000001'
  ),
  'co_organizer',
  'an active Tavolo delegate resolves as Co-organizer'
);
select results_eq(
  $$
    select project_kind, project_title, project_status
    from public.list_own_delegated_projects(
      'e8100000-0000-4000-8000-000000000002'
    )
    order by project_kind
  $$,
  $$values
    ('one_time'::text, 'Delegated Proposal'::text, 'published'::text),
    ('recurring'::text, 'Delegated Tavolo'::text, 'published'::text)
  $$,
  'the projection separates Proposal and Tavolo and returns only card fields'
);

select set_config(
  'request.jwt.claim.sub',
  'e8100000-0000-4000-8000-000000000003',
  true
);
select is(
  public.get_own_project_management_role(
    'e8100000-0000-4000-8000-000000000003',
    'e8200000-0000-4000-8000-000000000001'
  ),
  'none',
  'an unrelated profile learns only that it is not a manager'
);
select is(
  (
    select count(*)
    from public.list_own_delegated_projects(
      'e8100000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'another profile cannot read the delegate projection'
);
select throws_ok(
  $$
    select *
    from public.list_own_delegated_projects(
      'e8100000-0000-4000-8000-000000000002'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'the delegate projection is expected-profile bound'
);

select set_config(
  'request.jwt.claim.sub',
  'e8100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_own_delegated_projects(
      'e8100000-0000-4000-8000-000000000002'
    )
    where project_title = 'Private owner draft'
  ),
  0::bigint,
  'owner-only drafts never appear in the delegated projection'
);
select set_config(
  'request.jwt.claim.sub',
  'e8100000-0000-4000-8000-000000000001',
  true
);
select public.revoke_project_delegate(
  'e8100000-0000-4000-8000-000000000001',
  current_setting('test.proposal_delegate_id')::uuid
);

select set_config(
  'request.jwt.claim.sub',
  'e8100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.get_own_project_management_role(
    'e8100000-0000-4000-8000-000000000002',
    'e8200000-0000-4000-8000-000000000001'
  ),
  'none',
  'revocation is visible on the next exact-role read'
);
select results_eq(
  $$
    select project_kind, project_title
    from public.list_own_delegated_projects(
      'e8100000-0000-4000-8000-000000000002'
    )
  $$,
  $$values ('recurring'::text, 'Delegated Tavolo'::text)$$,
  'revocation removes only the revoked Project from the projection'
);

reset role;
select * from finish();
rollback;
