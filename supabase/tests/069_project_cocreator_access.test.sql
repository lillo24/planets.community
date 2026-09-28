begin;

select no_plan();

insert into auth.users (id, email)
values
  ('f0100000-0000-4000-8000-000000000001', 'authority-creator@planets.invalid'),
  ('f0100000-0000-4000-8000-000000000002', 'authority-cocreator@planets.invalid'),
  ('f0100000-0000-4000-8000-000000000003', 'authority-coorganizer@planets.invalid'),
  ('f0100000-0000-4000-8000-000000000004', 'authority-target-one@planets.invalid'),
  ('f0100000-0000-4000-8000-000000000005', 'authority-target-two@planets.invalid'),
  ('f0100000-0000-4000-8000-000000000006', 'authority-requester@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f0100000-0000-4000-8000-000000000001', 'Authority Creator'),
  ('f0100000-0000-4000-8000-000000000002', 'Authority Co-creator'),
  ('f0100000-0000-4000-8000-000000000003', 'Authority Co-organizer'),
  ('f0100000-0000-4000-8000-000000000004', 'Authority Target One'),
  ('f0100000-0000-4000-8000-000000000005', 'Authority Target Two'),
  ('f0100000-0000-4000-8000-000000000006', 'Authority Requester');

update public.profile_field_visibility
set audience = 'public'
where profile_id in (
  'f0100000-0000-4000-8000-000000000001',
  'f0100000-0000-4000-8000-000000000002'
)
  and field_key = 'display_name';

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  starts_at, ends_at, event_timezone, country_code, locality,
  administrative_area, public_location_label, published_at
)
values
  (
    'f0200000-0000-4000-8000-000000000001',
    'f0100000-0000-4000-8000-000000000001',
    'published',
    'Co-creator future Proposal',
    'A future collaborative Proposal.',
    'Used to verify structural authority without ownership transfer.',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    'Europe/Rome', 'IT', 'Rome', 'Lazio', 'Rome',
    statement_timestamp() - interval '1 day'
  ),
  (
    'f0200000-0000-4000-8000-000000000003',
    'f0100000-0000-4000-8000-000000000001',
    'published',
    'Already-started Proposal',
    'A currently running Proposal.',
    'Used to preserve the existing content freeze.',
    statement_timestamp() - interval '1 hour',
    statement_timestamp() + interval '1 day',
    'Europe/Rome', 'IT', 'Rome', 'Lazio', 'Rome',
    statement_timestamp() - interval '1 day'
  );

insert into public.proposal_meeting_details (
  proposal_id, exact_meeting_text, exact_location_visibility
)
values
  (
    'f0200000-0000-4000-8000-000000000001',
    'Future Proposal exact meeting point',
    'participants'
  ),
  (
    'f0200000-0000-4000-8000-000000000003',
    'Started Proposal exact meeting point',
    'participants'
  );

insert into public.recurring_activities (
  id, creator_profile_id, lifecycle_state, title, summary, description,
  topic, country_code, locality, administrative_area,
  public_location_label, published_at
)
values (
  'f0200000-0000-4000-8000-000000000002',
  'f0100000-0000-4000-8000-000000000001',
  'published',
  'Co-creator Tavolo',
  'A recurring authority test.',
  'Used to verify non-destructive structural lifecycle transitions.',
  'Community', 'IT', 'Rome', 'Lazio', 'Rome',
  statement_timestamp() - interval '1 day'
);

insert into public.recurring_activity_meeting_details (
  recurring_activity_id, exact_meeting_text, exact_location_visibility
)
values (
  'f0200000-0000-4000-8000-000000000002',
  'Tavolo exact meeting point',
  'participants'
);

insert into public.recurring_activity_schedules (
  recurring_activity_id, recurrence_type, weekday, local_start_time,
  duration_minutes, event_timezone, effective_from
)
values (
  'f0200000-0000-4000-8000-000000000002',
  'weekly', 4, '20:00'::time, 90, 'Europe/Rome', current_date - 7
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.cocreator_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000001',
      'f0200000-0000-4000-8000-000000000001',
      'co_creator'
    )
  ),
  true
);
select set_config(
  'test.coorganizer_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000001',
      'f0200000-0000-4000-8000-000000000001'
    )
  ),
  true
);
with created as (
  select *
  from public.create_project_delegate_invitation(
    'f0100000-0000-4000-8000-000000000001',
    'f0200000-0000-4000-8000-000000000001',
    'co_organizer'
  )
)
select
  set_config('test.self_token', created.invite_token, true),
  set_config('test.self_invitation_id', created.invitation_id::text, true)
from created;

reset role;
select results_eq(
  $$
    select requested_authority_role, issuer_profile_id
    from public.project_delegate_invitations
    where token_digest = extensions.digest(
      current_setting('test.coorganizer_token'),
      'sha256'
    )
  $$,
  $$values (
    'co_organizer'::text,
    'f0100000-0000-4000-8000-000000000001'::uuid
  )$$,
  'the legacy invitation overload remains a Creator-issued Co-organizer link'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.accept_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000001',
      current_setting('test.self_token')
    )
  $$,
  '55000',
  'The original Project Creator cannot accept delegated authority.',
  'the immutable original Creator cannot accept a delegated role'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.cocreator_id',
  public.accept_project_delegate_invitation(
    'f0100000-0000-4000-8000-000000000002',
    current_setting('test.cocreator_token')
  )::text,
  true
);
select is(
  public.get_own_project_management_role(
    'f0100000-0000-4000-8000-000000000002',
    'f0200000-0000-4000-8000-000000000001'
  ),
  'co_creator',
  'a Co-creator is distinguishable from the original Creator'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.coorganizer_id',
  public.accept_project_delegate_invitation(
    'f0100000-0000-4000-8000-000000000003',
    current_setting('test.coorganizer_token')
  )::text,
  true
);
select is(
  public.get_own_project_management_role(
    'f0100000-0000-4000-8000-000000000003',
    'f0200000-0000-4000-8000-000000000001'
  ),
  'co_organizer',
  'an existing-style delegate becomes a Co-organizer, never a Co-creator'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.duplicate_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000001',
      'f0200000-0000-4000-8000-000000000001'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select public.accept_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000003',
      current_setting('test.duplicate_token')
    )
  $$,
  '55000',
  'This profile already has active delegated authority for the Project.',
  'a second invitation cannot create duplicate active authority'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.cocreator_coorganizer_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001',
      'co_organizer'
    )
  ),
  true
);
select set_config(
  'test.stale_demotion_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001',
      'co_creator'
    )
  ),
  true
);

reset role;
select results_eq(
  $$
    select requested_authority_role, issuer_profile_id
    from public.project_delegate_invitations
    where token_digest in (
      extensions.digest(
        current_setting('test.cocreator_coorganizer_token'),
        'sha256'
      ),
      extensions.digest(
        current_setting('test.stale_demotion_token'),
        'sha256'
      )
    )
    order by requested_authority_role collate "C"
  $$,
  $$values
    (
      'co_creator'::text,
      'f0100000-0000-4000-8000-000000000002'::uuid
    ),
    (
      'co_organizer'::text,
      'f0100000-0000-4000-8000-000000000002'::uuid
    )
  $$,
  'an active Co-creator truthfully issues both delegated roles'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.cocreator_granted_target_id',
  public.accept_project_delegate_invitation(
    'f0100000-0000-4000-8000-000000000004',
    current_setting('test.cocreator_coorganizer_token')
  )::text,
  true
);

reset role;
select results_eq(
  $$
    select
      owner_profile_id,
      granted_by_profile_id,
      initial_authority_role,
      authority_role
    from public.project_delegates
    where id = current_setting('test.cocreator_granted_target_id')::uuid
  $$,
  $$values (
    'f0100000-0000-4000-8000-000000000001'::uuid,
    'f0100000-0000-4000-8000-000000000002'::uuid,
    'co_organizer'::text,
    'co_organizer'::text
  )$$,
  'a Co-creator grant preserves original-Creator and real-grantor provenance'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select *
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000003',
      'f0200000-0000-4000-8000-000000000001',
      'co_creator'
    )
  $$,
  '42501',
  'Only a current Project structural actor can create authority invitations.',
  'a Co-organizer cannot create structural grants'
);
select throws_ok(
  $$
    select public.revoke_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000003',
      current_setting('test.self_invitation_id')::uuid
    )
  $$,
  '42501',
  'The delegated-authority invitation is unavailable.',
  'a Co-organizer cannot revoke a pending authority invitation'
);
select throws_ok(
  $$
    select public.change_project_delegate_role(
      'f0100000-0000-4000-8000-000000000003',
      current_setting('test.cocreator_granted_target_id')::uuid,
      'co_creator'
    )
  $$,
  '42501',
  'The Project delegated authority is unavailable.',
  'a Co-organizer cannot promote another delegated actor'
);
select throws_ok(
  $$
    select public.update_own_proposal(
      'f0100000-0000-4000-8000-000000000003',
      'f0200000-0000-4000-8000-000000000001',
      'Unauthorized Co-organizer rewrite',
      'A future collaborative Proposal.',
      'A Co-organizer must not edit structural Project content.',
      statement_timestamp() + interval '2 days',
      statement_timestamp() + interval '3 days',
      'Europe/Rome', 'IT', 'Rome', 'Lazio', 'Rome',
      'Future Proposal exact meeting point', 'participants',
      array[]::uuid[], array[]::text[]
    )
  $$,
  '42501',
  'The current user does not own this proposal.',
  'a Co-organizer cannot edit core Project authoring fields'
);
select throws_ok(
  $$
    select public.cancel_proposal(
      'f0100000-0000-4000-8000-000000000003',
      'f0200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current user does not own this proposal.',
  'a Co-organizer cannot perform structural lifecycle actions'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select *
    from public.list_project_delegates_for_owner(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001'
    )
  $$,
  'a Co-creator can list delegated authority with roles'
);
select lives_ok(
  $$
    select public.revoke_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000002',
      (
        select invitation_id
        from public.list_project_delegate_invitations_for_owner(
          'f0100000-0000-4000-8000-000000000002',
          'f0200000-0000-4000-8000-000000000001'
        )
        where invitation_id =
          current_setting('test.self_invitation_id')::uuid
      )
    )
  $$,
  'a Co-creator can revoke a Creator-issued pending invitation'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.participation_request',
  public.request_to_join_project(
    'f0100000-0000-4000-8000-000000000003',
    'f0200000-0000-4000-8000-000000000001',
    'Authority and participation remain independent.'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_id',
  public.accept_project_join_request(
    'f0100000-0000-4000-8000-000000000001',
    current_setting('test.participation_request')::uuid
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select public.change_project_delegate_role(
  'f0100000-0000-4000-8000-000000000002',
  current_setting('test.coorganizer_id')::uuid,
  'co_creator'
);
reset role;
select is(
  (
    select authority_role
    from public.project_delegates
    where id = current_setting('test.coorganizer_id')::uuid
  ),
  'co_creator',
  'a Co-creator can promote a Co-organizer to Co-creator'
);
select is(
  (
    select count(*)
    from public.project_memberships
    where id = current_setting('test.membership_id')::uuid
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'promotion preserves the target ordinary participation state'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select public.change_project_delegate_role(
  'f0100000-0000-4000-8000-000000000002',
  current_setting('test.coorganizer_id')::uuid,
  'co_organizer'
);
reset role;
select is(
  (
    select count(*)
    from public.project_memberships
    where id = current_setting('test.membership_id')::uuid
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'demotion also preserves ordinary participation state'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select public.change_project_delegate_role(
  'f0100000-0000-4000-8000-000000000001',
  current_setting('test.coorganizer_id')::uuid,
  'co_creator'
);
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000003',
  true
);
select public.leave_project(
  'f0100000-0000-4000-8000-000000000003',
  current_setting('test.membership_id')::uuid
);
select is(
  public.get_own_project_management_role(
    'f0100000-0000-4000-8000-000000000003',
    'f0200000-0000-4000-8000-000000000001'
  ),
  'co_creator',
  'participant Leave does not remove Co-creator authority'
);

select set_config(
  'test.second_participation_request',
  public.request_to_join_project(
    'f0100000-0000-4000-8000-000000000003',
    'f0200000-0000-4000-8000-000000000001',
    'Rejoin before authority revocation.'
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.second_membership_id',
  public.accept_project_join_request(
    'f0100000-0000-4000-8000-000000000001',
    current_setting('test.second_participation_request')::uuid
  )::text,
  true
);
select public.revoke_project_delegate(
  'f0100000-0000-4000-8000-000000000001',
  current_setting('test.coorganizer_id')::uuid
);
reset role;
select is(
  (
    select count(*)
    from public.project_memberships
    where id = current_setting('test.second_membership_id')::uuid
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'authority revocation preserves a current participant membership'
);
select is(
  (
    select count(*)
    from public.project_delegate_role_changes
    where delegate_id = current_setting('test.coorganizer_id')::uuid
  ),
  3::bigint,
  'promotion and demotion append truthful role-change history'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000006',
  true
);
select set_config(
  'test.operational_request',
  public.request_to_join_project(
    'f0100000-0000-4000-8000-000000000006',
    'f0200000-0000-4000-8000-000000000001',
    'Co-creators retain operational manager access.'
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_project_join_requests_for_manager(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001'
    ) as request_row
    where request_row.request_id =
      current_setting('test.operational_request')::uuid
  ),
  1::bigint,
  'a Co-creator inherits existing operational manager permissions'
);

select lives_ok(
  $$
    select public.update_own_proposal(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001',
      'Co-creator updated Proposal',
      'A future collaborative Proposal.',
      'Updated by a Co-creator without changing original attribution.',
      statement_timestamp() + interval '2 days',
      statement_timestamp() + interval '3 days',
      'Europe/Rome', 'IT', 'Rome', 'Lazio', 'Rome',
      'Future Proposal exact meeting point', 'participants',
      array[]::uuid[], array[]::text[]
    )
  $$,
  'a Co-creator can edit a future published Proposal'
);
reset role;
select results_eq(
  $$
    select creator_profile_id, title
    from public.proposals
    where id = 'f0200000-0000-4000-8000-000000000001'
  $$,
  $$values (
    'f0100000-0000-4000-8000-000000000001'::uuid,
    'Co-creator updated Proposal'::text
  )$$,
  'Co-creator editing preserves the immutable original Creator'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.started_cocreator_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000001',
      'f0200000-0000-4000-8000-000000000003',
      'co_creator'
    )
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select public.accept_project_delegate_invitation(
  'f0100000-0000-4000-8000-000000000002',
  current_setting('test.started_cocreator_token')
);
select throws_ok(
  $$
    select public.update_own_proposal(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000003',
      'Late rewrite', 'Summary', 'Description',
      statement_timestamp() + interval '1 hour',
      statement_timestamp() + interval '2 hours',
      'Europe/Rome', 'IT', 'Rome', 'Lazio', 'Rome',
      'Started Proposal exact meeting point', 'participants',
      array[]::uuid[], array[]::text[]
    )
  $$,
  '55000',
  'A published proposal cannot be edited after it starts.',
  'a Co-creator receives the same Proposal content freeze as the Creator'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select public.change_project_delegate_role(
  'f0100000-0000-4000-8000-000000000001',
  current_setting('test.cocreator_id')::uuid,
  'co_organizer'
);

reset role;
select results_eq(
  $$
    select status, revoked_by_profile_id is not null
    from public.project_delegate_invitations
    where token_digest = extensions.digest(
      current_setting('test.stale_demotion_token'),
      'sha256'
    )
  $$,
  $$values ('revoked'::text, true)$$,
  'demotion atomically invalidates pending grants issued by that Co-creator'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000005',
  true
);
select throws_ok(
  $$
    select public.accept_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000005',
      current_setting('test.stale_demotion_token')
    )
  $$,
  '42501',
  'The delegated-authority invitation is unavailable.',
  'an invalidated invitation cannot bypass issuer demotion'
);
select is(
  (
    select preview.is_available
    from public.preview_project_delegate_invitation(
      current_setting('test.stale_demotion_token')
    ) as preview
  ),
  false,
  'stale invitations also fail closed during preview'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select *
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001',
      'co_creator'
    )
  $$,
  '42501',
  'Only a current Project structural actor can create authority invitations.',
  'a demoted Co-creator immediately loses structural authority'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select public.change_project_delegate_role(
  'f0100000-0000-4000-8000-000000000001',
  current_setting('test.cocreator_id')::uuid,
  'co_creator'
);
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.stale_revocation_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001',
      'co_creator'
    )
  ),
  true
);

select lives_ok(
  $$
    select public.cancel_proposal(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000001'
    )
  $$,
  'a Co-creator can cancel a lifecycle-eligible Proposal'
);

select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select public.revoke_project_delegate(
  'f0100000-0000-4000-8000-000000000001',
  current_setting('test.cocreator_id')::uuid
);

reset role;
select is(
  (
    select status
    from public.project_delegate_invitations
    where token_digest = extensions.digest(
      current_setting('test.stale_revocation_token'),
      'sha256'
    )
  ),
  'revoked',
  'revoking a Co-creator invalidates that actor pending grants'
);
select results_eq(
  $$
    select proposal.lifecycle_state, project.creator_profile_id
    from public.proposals as proposal
    join public.projects as project on project.id = proposal.id
    where proposal.id = 'f0200000-0000-4000-8000-000000000001'
  $$,
  $$values (
    'cancelled'::text,
    'f0100000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Proposal cancellation is retained and does not rewrite Creator attribution'
);
select is(
  (
    select count(*)
    from public.project_memberships
    where id = current_setting('test.second_membership_id')::uuid
      and left_at is null
      and removed_at is null
  ),
  1::bigint,
  'Proposal cancellation does not remove participant membership history'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.tavolo_cocreator_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'f0100000-0000-4000-8000-000000000001',
      'f0200000-0000-4000-8000-000000000002',
      'co_creator'
    )
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f0100000-0000-4000-8000-000000000002',
  true
);
select public.accept_project_delegate_invitation(
  'f0100000-0000-4000-8000-000000000002',
  current_setting('test.tavolo_cocreator_token')
);
select lives_ok(
  $$
    select public.update_own_recurring_activity(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000002',
      'Co-creator updated Tavolo',
      'A recurring authority test.',
      'Updated by a Co-creator without ownership transfer.',
      'Community', 'IT', 'Rome', 'Lazio', 'Rome',
      'Tavolo exact meeting point', 'participants',
      'weekly', 4, null, '20:00'::time, 90, 'Europe/Rome',
      current_date - 7
    )
  $$,
  'a Co-creator can edit a published Tavolo under existing schedule rules'
);
select lives_ok(
  $$
    select public.pause_recurring_activity(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000002'
    )
  $$,
  'a Co-creator can pause a published Tavolo'
);
select lives_ok(
  $$
    select public.resume_recurring_activity(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000002'
    )
  $$,
  'a Co-creator can resume a paused Tavolo'
);
select lives_ok(
  $$
    select public.end_recurring_activity(
      'f0100000-0000-4000-8000-000000000002',
      'f0200000-0000-4000-8000-000000000002'
    )
  $$,
  'a Co-creator can end a published Tavolo'
);

reset role;
select results_eq(
  $$
    select activity.lifecycle_state, project.creator_profile_id
    from public.recurring_activities as activity
    join public.projects as project on project.id = activity.id
    where activity.id = 'f0200000-0000-4000-8000-000000000002'
  $$,
  $$values (
    'ended'::text,
    'f0100000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Tavolo ending is retained and preserves original-Creator attribution'
);
select is(
  (
    select count(*)
    from private.audit_events
    where actor_user_id = 'f0100000-0000-4000-8000-000000000002'
      and action in (
        'proposal.updated',
        'proposal.cancelled',
        'recurring_activity.updated',
        'recurring_activity.paused',
        'recurring_activity.resumed',
        'recurring_activity.ended'
      )
  ),
  6::bigint,
  'authoring and lifecycle audit events attribute the actual Co-creator actor'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where payload ->> 'actor_id' =
      'f0100000-0000-4000-8000-000000000002'
      and event_type in (
        'proposal.updated',
        'proposal.cancelled',
        'recurring_activity.updated',
        'recurring_activity.paused',
        'recurring_activity.resumed',
        'recurring_activity.ended'
      )
  ),
  6::bigint,
  'authoring and lifecycle outbox events attribute the actual Co-creator actor'
);
select ok(
  not exists (
    select 1
    from private.audit_events
    where metadata::text like '%' || current_setting('test.cocreator_token') || '%'
  )
    and not exists (
      select 1
      from private.outbox_events
      where payload::text like '%' || current_setting('test.cocreator_token') || '%'
    ),
  'role-aware audit and outbox metadata never logs bearer tokens'
);

select * from finish();
rollback;
