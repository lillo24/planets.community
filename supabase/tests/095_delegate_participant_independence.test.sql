begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

insert into auth.users (id, email)
values
  ('e9100000-0000-4000-8000-000000000001', 'independence-owner@planets.invalid'),
  ('e9100000-0000-4000-8000-000000000002', 'independence-delegate@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e9100000-0000-4000-8000-000000000001', 'Independence Owner'),
  ('e9100000-0000-4000-8000-000000000002', 'Independence Delegate');

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
  'e9200000-0000-4000-8000-000000000001',
  'e9100000-0000-4000-8000-000000000001',
  'published',
  'Independent delegate participation',
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
  'e9200000-0000-4000-8000-000000000001',
  'Meet beside the independence test gate',
  'participants'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.delegate_token',
  (
    select invite_token
    from public.create_project_delegate_invitation(
      'e9100000-0000-4000-8000-000000000001',
      'e9200000-0000-4000-8000-000000000001'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.delegate_id',
  public.accept_project_delegate_invitation(
    'e9100000-0000-4000-8000-000000000002',
    current_setting('test.delegate_token')
  )::text,
  true
);
select set_config(
  'test.first_request',
  public.request_to_join_project(
    'e9100000-0000-4000-8000-000000000002',
    'e9200000-0000-4000-8000-000000000001',
    'I am participating independently from organizing.'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.first_membership',
  public.accept_project_join_request(
    'e9100000-0000-4000-8000-000000000001',
    current_setting('test.first_request')::uuid
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.get_own_project_management_role(
    'e9100000-0000-4000-8000-000000000002',
    'e9200000-0000-4000-8000-000000000001'
  ),
  'co_organizer',
  'a current participant retains the independent delegate role'
);
select is(
  (
    select count(*)
    from public.list_own_project_memberships(
      'e9100000-0000-4000-8000-000000000002'
    ) as membership
    where membership.membership_id =
      current_setting('test.first_membership')::uuid
      and membership.membership_status = 'current'
  ),
  1::bigint,
  'the delegate own participation projection retains the current membership'
);
select throws_ok(
  $$
    select public.remove_project_member_as_manager(
      'e9100000-0000-4000-8000-000000000002',
      current_setting('test.first_membership')::uuid
    )
  $$,
  '55000',
  'A Project manager cannot remove their own participant membership. Leave the Project instead.',
  'a delegate cannot record their voluntary exit as a manager removal'
);

reset role;
select results_eq(
  $$
    select left_at is null, removed_at is null, removed_by_profile_id is null
    from public.project_memberships
    where id = current_setting('test.first_membership')::uuid
  $$,
  $$values (true, true, true)$$,
  'rejected self-removal leaves the membership unchanged'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.leave_project(
    'e9100000-0000-4000-8000-000000000002',
    current_setting('test.first_membership')::uuid
  )::text,
  current_setting('test.first_membership'),
  'the delegate leaves through the canonical participant operation'
);

reset role;
select results_eq(
  $$
    select left_at is not null, removed_at is null,
      removed_by_profile_id is null
    from public.project_memberships
    where id = current_setting('test.first_membership')::uuid
  $$,
  $$values (true, true, true)$$,
  'voluntary delegate exit records left_at and never removed_at'
);
select is(
  (
    select count(*)
    from public.project_delegates as delegate
    where delegate.id = current_setting('test.delegate_id')::uuid
      and delegate.revoked_at is null
  ),
  1::bigint,
  'leaving participation does not revoke delegation'
);
select results_eq(
  $$
    select event.action::text collate "C", count(*)
    from private.audit_events as event
    where event.metadata ->> 'membership_id' =
      current_setting('test.first_membership')
      and event.action in (
        'project.participant_left',
        'project.participant_removed'
      )
    group by event.action
    order by event.action collate "C"
  $$,
  $$values ('project.participant_left'::text collate "C", 1::bigint)$$,
  'voluntary exit emits participant_left audit semantics only'
);
select results_eq(
  $$
    select event.event_type::text collate "C", count(*)
    from private.outbox_events as event
    where event.payload ->> 'membership_id' =
      current_setting('test.first_membership')
      and event.event_type in (
        'project.participant_left',
        'project.participant_removed'
      )
    group by event.event_type
    order by event.event_type collate "C"
  $$,
  $$values ('project.participant_left'::text collate "C", 1::bigint)$$,
  'voluntary exit emits participant_left outbox semantics only'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.get_own_project_management_role(
    'e9100000-0000-4000-8000-000000000002',
    'e9200000-0000-4000-8000-000000000001'
  ),
  'co_organizer',
  'voluntary participant exit preserves management role'
);
select lives_ok(
  $$
    select *
    from public.list_project_members_for_manager(
      'e9100000-0000-4000-8000-000000000002',
      'e9200000-0000-4000-8000-000000000001'
    )
  $$,
  'the delegate retains organizer participation access after leaving'
);
select is(
  (
    select chat.viewer_role
    from public.get_own_project_group_chat(
      'e9100000-0000-4000-8000-000000000002',
      'e9200000-0000-4000-8000-000000000001'
    ) as chat
  ),
  'delegate',
  'the delegate retains organizer group-chat access after leaving'
);
select is(
  (
    select details.exact_meeting_text
    from public.get_project_participant_meeting_details(
      'e9100000-0000-4000-8000-000000000002',
      'e9200000-0000-4000-8000-000000000001'
    ) as details
  ),
  'Meet beside the independence test gate',
  'the delegate retains organizer protected-location access after leaving'
);

select set_config(
  'test.second_request',
  public.request_to_join_project(
    'e9100000-0000-4000-8000-000000000002',
    'e9200000-0000-4000-8000-000000000001',
    'I am participating again.'
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.second_membership',
  public.accept_project_join_request(
    'e9100000-0000-4000-8000-000000000001',
    current_setting('test.second_request')::uuid
  )::text,
  true
);
select public.revoke_project_delegate(
  'e9100000-0000-4000-8000-000000000001',
  current_setting('test.delegate_id')::uuid
);

select set_config(
  'request.jwt.claim.sub',
  'e9100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.get_own_project_management_role(
    'e9100000-0000-4000-8000-000000000002',
    'e9200000-0000-4000-8000-000000000001'
  ),
  'none',
  'revoking delegation removes only the manager role'
);
select is(
  (
    select count(*)
    from public.list_own_project_memberships(
      'e9100000-0000-4000-8000-000000000002'
    ) as membership
    where membership.membership_id =
      current_setting('test.second_membership')::uuid
      and membership.membership_status = 'current'
  ),
  1::bigint,
  'delegate revocation preserves the independent current membership'
);
select is(
  (
    select chat.viewer_role
    from public.get_own_project_group_chat(
      'e9100000-0000-4000-8000-000000000002',
      'e9200000-0000-4000-8000-000000000001'
    ) as chat
  ),
  'current_member',
  'the revoked delegate retains participant group-chat access'
);
select is(
  (
    select details.exact_meeting_text
    from public.get_project_participant_meeting_details(
      'e9100000-0000-4000-8000-000000000002',
      'e9200000-0000-4000-8000-000000000001'
    ) as details
  ),
  'Meet beside the independence test gate',
  'the revoked delegate retains participant protected-location access'
);
select is(
  public.leave_project(
    'e9100000-0000-4000-8000-000000000002',
    current_setting('test.second_membership')::uuid
  )::text,
  current_setting('test.second_membership'),
  'the revoked delegate retains the normal participant leave operation'
);

reset role;
select * from finish();
rollback;
