begin;

select no_plan();

insert into auth.users (id, email)
values
  ('e7100000-0000-4000-8000-000000000001', 'delegate-owner@planets.invalid'),
  ('e7100000-0000-4000-8000-000000000002', 'delegate-manager@planets.invalid'),
  ('e7100000-0000-4000-8000-000000000003', 'delegate-requester@planets.invalid'),
  ('e7100000-0000-4000-8000-000000000004', 'delegate-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e7100000-0000-4000-8000-000000000001', 'Delegate Owner'),
  ('e7100000-0000-4000-8000-000000000002', 'Delegate Manager'),
  ('e7100000-0000-4000-8000-000000000003', 'Delegate Requester'),
  ('e7100000-0000-4000-8000-000000000004', 'Delegate Unrelated');

update public.profile_field_visibility
set audience = 'public'
where profile_id = 'e7100000-0000-4000-8000-000000000001'
  and field_key = 'display_name';

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  event_timezone,
  published_at
)
values (
  'e7200000-0000-4000-8000-000000000001',
  'e7100000-0000-4000-8000-000000000001',
  'published',
  'Delegate access Proposal',
  statement_timestamp() + interval '2 days',
  statement_timestamp() + interval '3 days',
  'Europe/Rome',
  statement_timestamp() - interval '1 day'
);

insert into public.proposal_meeting_details (
  proposal_id,
  exact_meeting_text,
  exact_location_visibility
)
values (
  'e7200000-0000-4000-8000-000000000001',
  'Meet beside the community garden gate',
  'participants'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.delegate_request',
  public.request_to_join_project(
    'e7100000-0000-4000-8000-000000000003',
    'e7200000-0000-4000-8000-000000000001',
    'I can help organize supplies.'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000001',
  true
);
with created as (
  select *
  from public.create_project_delegate_invitation(
    'e7100000-0000-4000-8000-000000000001',
    'e7200000-0000-4000-8000-000000000001'
  )
)
select set_config('test.delegate_token', created.invite_token, true)
from created;
reset role;

select set_config(
  'test.delegate_invitation',
  (
    select invitation.id::text
    from public.project_delegate_invitations as invitation
    where invitation.token_digest = extensions.digest(
      current_setting('test.delegate_token'),
      'sha256'
    )
  ),
  true
);

select is(
  length(current_setting('test.delegate_token')),
  43,
  'owner creation returns one 256-bit base64url bearer token'
);
select isnt(
  encode(
    (
      select invitation.token_digest
      from public.project_delegate_invitations as invitation
      where invitation.id = current_setting('test.delegate_invitation')::uuid
    ),
    'escape'
  ),
  current_setting('test.delegate_token'),
  'the reusable bearer token is never persisted'
);
select is(
  (
    select invitation.expires_at - invitation.created_at
    from public.project_delegate_invitations as invitation
    where invitation.id = current_setting('test.delegate_invitation')::uuid
  ),
  interval '7 days',
  'the persisted invite expires exactly seven days after creation'
);

set local role anon;
select results_eq(
  $$
    select preview.is_available, preview.project_kind, preview.project_title,
      preview.owner_display_name
    from public.preview_project_delegate_invitation(
      current_setting('test.delegate_token')
    ) as preview
  $$,
  $$values (
    true,
    'one_time'::text,
    'Delegate access Proposal'::text,
    'Delegate Owner'::text
  )$$,
  'anonymous preview returns only minimal public Project context'
);
select throws_ok(
  $$select public.accept_project_delegate_invitation(null, 'invalid')$$,
  '42501',
  'permission denied for function accept_project_delegate_invitation',
  'anonymous callers cannot mutate delegate state'
);
select throws_ok(
  $$select * from public.project_delegate_invitations$$,
  '42501',
  'permission denied for table project_delegate_invitations',
  'anonymous callers cannot enumerate invite metadata'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.accept_project_delegate_invitation(
      'e7100000-0000-4000-8000-000000000001',
      current_setting('test.delegate_token')
    )
  $$,
  '55000',
  'The original Project Creator cannot accept delegated authority.',
  'an owner cannot consume their own invite'
);

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.delegate_id',
  public.accept_project_delegate_invitation(
    'e7100000-0000-4000-8000-000000000002',
    current_setting('test.delegate_token')
  )::text,
  true
);
select is(
  public.accept_project_delegate_invitation(
    'e7100000-0000-4000-8000-000000000002',
    current_setting('test.delegate_token')
  )::text,
  current_setting('test.delegate_id'),
  'the successful accepter can safely retry after a lost response'
);
select is(
  (
    select count(*)
    from public.list_own_project_memberships(
      'e7100000-0000-4000-8000-000000000002'
    ) as membership
  ),
  0::bigint,
  'becoming a delegate does not create a participant membership'
);
select is(
  (
    select count(*)
    from public.list_project_join_requests_for_manager(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    ) as request_row
    where request_row.request_id =
      current_setting('test.delegate_request')::uuid
  ),
  1::bigint,
  'an active delegate sees the Project participation queue'
);
select is(
  (
    select chat.viewer_role
    from public.get_own_project_join_request_chat(
      'e7100000-0000-4000-8000-000000000002',
      current_setting('test.delegate_request')::uuid
    ) as chat
  ),
  'delegate',
  'an active delegate resolves the existing private request chat as a delegate'
);
select lives_ok(
  $$
    select *
    from public.send_project_join_request_chat_message(
      'e7100000-0000-4000-8000-000000000002',
      (
        select chat.chat_id
        from public.get_own_project_join_request_chat(
          'e7100000-0000-4000-8000-000000000002',
          current_setting('test.delegate_request')::uuid
        ) as chat
      ),
      'Thanks. We are reviewing your request.'
    )
  $$,
  'an active delegate participates in the requester-organizer conversation'
);
select set_config(
  'test.delegate_membership',
  public.accept_project_join_request_as_manager(
    'e7100000-0000-4000-8000-000000000002',
    current_setting('test.delegate_request')::uuid
  )::text,
  true
);
select set_config(
  'test.delegate_group_chat',
  (
    select chat.chat_id::text
    from public.get_own_project_group_chat(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    ) as chat
  ),
  true
);
select is(
  (
    select chat.viewer_role
    from public.get_own_project_group_chat(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    ) as chat
  ),
  'delegate',
  'the active delegate resolves the canonical Project group chat'
);
select lives_ok(
  $$
    select *
    from public.send_project_chat_message(
      'e7100000-0000-4000-8000-000000000002',
      current_setting('test.delegate_group_chat')::uuid,
      'Delegate coordination message'
    )
  $$,
  'the active delegate can send to the existing Project group chat'
);
select is(
  (
    select details.exact_meeting_text
    from public.get_project_participant_meeting_details(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    ) as details
  ),
  'Meet beside the community garden gate',
  'the active delegate can read protected meeting details'
);
select throws_ok(
  $$
    select public.cancel_proposal(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The current user does not own this proposal.',
  'delegate authorization does not expand into owner-only lifecycle control'
);

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  $$
    select public.accept_project_delegate_invitation(
      'e7100000-0000-4000-8000-000000000004',
      current_setting('test.delegate_token')
    )
  $$,
  '42501',
  'The delegated-authority invitation is unavailable.',
  'a consumed invite cannot be claimed by another profile'
);
select throws_ok(
  $$
    select *
    from public.list_project_join_requests_for_manager(
      'e7100000-0000-4000-8000-000000000004',
      'e7200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only a current Project manager can perform this operation.',
  'an unrelated authenticated profile is not a Project manager'
);

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000001',
  true
);
with created as (
  select *
  from public.create_project_delegate_invitation(
    'e7100000-0000-4000-8000-000000000001',
    'e7200000-0000-4000-8000-000000000001'
  )
)
select
  set_config('test.delegate_pending_token', created.invite_token, true),
  set_config('test.delegate_pending_invitation', created.invitation_id::text, true)
from created;

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select *
    from public.create_project_delegate_invitation(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only a current Project structural actor can create authority invitations.',
  'a Co-organizer cannot invite another delegated actor'
);
select throws_ok(
  $$
    select public.revoke_project_delegate_invitation(
      'e7100000-0000-4000-8000-000000000002',
      current_setting('test.delegate_pending_invitation')::uuid
    )
  $$,
  '42501',
  'The delegated-authority invitation is unavailable.',
  'a Co-organizer cannot revoke a Creator invitation'
);

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.revoke_project_delegate(
    'e7100000-0000-4000-8000-000000000001',
    current_setting('test.delegate_id')::uuid
  )::text,
  current_setting('test.delegate_id'),
  'the owner revokes the active delegate relationship'
);

select set_config(
  'request.jwt.claim.sub',
  'e7100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select *
    from public.list_project_members_for_manager(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only a current Project manager can perform this operation.',
  'revocation removes manager participation reads on the next call'
);
select throws_ok(
  $$
    select *
    from public.get_own_project_group_chat(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The project group chat is unavailable.',
  'revocation removes delegate-only group-chat history and access'
);
select throws_ok(
  $$
    select *
    from public.get_project_participant_meeting_details(
      'e7100000-0000-4000-8000-000000000002',
      'e7200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator or a current participant can read protected meeting information.',
  'revocation removes protected meeting access on the next call'
);

reset role;
select ok(
  not exists (
    select 1
    from private.audit_events as event
    where event.action like 'project.delegate%'
      and event.metadata::text like '%' || current_setting('test.delegate_token') || '%'
  ) and not exists (
    select 1
    from private.outbox_events as event
    where event.event_type like 'project.delegate%'
      and event.payload::text like '%' || current_setting('test.delegate_token') || '%'
  ),
  'identifier-only audit and outbox events never contain bearer tokens'
);
select results_eq(
  $$
    select event.action::text collate "C", count(*)
    from private.audit_events as event
    where event.target_id = 'e7200000-0000-4000-8000-000000000001'
      and event.action like 'project.delegate%'
    group by event.action
    order by event.action collate "C"
  $$,
  $$values
    ('project.delegate_added'::text collate "C", 1::bigint),
    ('project.delegate_invite_created'::text collate "C", 2::bigint),
    ('project.delegate_revoked'::text collate "C", 1::bigint)
  $$,
  'delegate role transitions emit durable identifier-only audit events'
);

select * from finish();
rollback;
