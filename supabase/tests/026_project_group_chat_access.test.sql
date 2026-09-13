begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a7100000-0000-4000-8000-000000000001', 'chat-creator@planets.invalid'),
  ('a7200000-0000-4000-8000-000000000002', 'chat-participant-a@planets.invalid'),
  ('a7300000-0000-4000-8000-000000000003', 'chat-participant-b@planets.invalid'),
  ('a7400000-0000-4000-8000-000000000004', 'chat-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a7100000-0000-4000-8000-000000000001', 'Chat Creator'),
  ('a7200000-0000-4000-8000-000000000002', 'Chat Participant A'),
  ('a7300000-0000-4000-8000-000000000003', 'Chat Participant B'),
  ('a7400000-0000-4000-8000-000000000004', 'Chat Unrelated');

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
values
  (
    'e7100000-0000-4000-8000-000000000001',
    'a7100000-0000-4000-8000-000000000001',
    'published',
    'Chat foundation Proposal',
    '2098-01-01 10:00+00',
    '2098-01-01 12:00+00',
    'Europe/Rome',
    statement_timestamp()
  ),
  (
    'e7200000-0000-4000-8000-000000000002',
    'a7100000-0000-4000-8000-000000000001',
    'published',
    'Atomic chat Proposal',
    '2098-02-01 10:00+00',
    '2098-02-01 12:00+00',
    'Europe/Rome',
    statement_timestamp()
  ),
  (
    'e7300000-0000-4000-8000-000000000003',
    'a7100000-0000-4000-8000-000000000001',
    'published',
    'Backfill chat Proposal',
    '2098-03-01 10:00+00',
    '2098-03-01 12:00+00',
    'Europe/Rome',
    statement_timestamp()
  );

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at
)
values (
  'f7100000-0000-4000-8000-000000000001',
  'a7100000-0000-4000-8000-000000000001',
  'published',
  'Chat foundation Tavolo',
  statement_timestamp()
);

set local role anon;
select throws_ok(
  $$
    select *
    from public.get_own_project_group_chat(
      null,
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function get_own_project_group_chat',
  'anonymous clients cannot resolve Project chat anchors'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.chat_request_a',
  public.request_to_join_project(
    'a7200000-0000-4000-8000-000000000002',
    'e7100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'test.atomic_request',
  public.request_to_join_project(
    'a7200000-0000-4000-8000-000000000002',
    'e7200000-0000-4000-8000-000000000002',
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a7300000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.chat_request_b',
  public.request_to_join_project(
    'a7300000-0000-4000-8000-000000000003',
    'e7100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);

reset role;
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id in (
      'e7100000-0000-4000-8000-000000000001',
      'e7200000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'pending requests do not activate a Project chat'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select *
    from public.get_own_project_group_chat(
      'a7100000-0000-4000-8000-000000000001',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The project group chat is unavailable.',
  'even the creator has no chat anchor before first acceptance'
);

reset role;
create function private.test_fail_project_group_chat_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'Forced chat activation failure.';
end;
$$;
create trigger test_fail_project_group_chat_insert
before insert on public.project_group_chats
for each row
when (new.project_id = 'e7200000-0000-4000-8000-000000000002'::uuid)
execute function private.test_fail_project_group_chat_insert();

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.accept_project_join_request(
      'a7100000-0000-4000-8000-000000000001',
      current_setting('test.atomic_request')::uuid
    )
  $$,
  'P0001',
  'Forced chat activation failure.',
  'chat activation failure aborts the acceptance statement'
);

reset role;
select results_eq(
  $$
    select request.status, count(membership.id), count(chat.id)
    from public.project_join_requests as request
    left join public.project_memberships as membership
      on membership.originating_request_id = request.id
    left join public.project_group_chats as chat
      on chat.project_id = request.project_id
    where request.id = current_setting('test.atomic_request')::uuid
    group by request.status
  $$,
  $$values ('pending'::text, 0::bigint, 0::bigint)$$,
  'a failed activation leaves the request pending with no membership or chat'
);
drop trigger test_fail_project_group_chat_insert on public.project_group_chats;
drop function private.test_fail_project_group_chat_insert();

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_a_one',
  public.accept_project_join_request(
    'a7100000-0000-4000-8000-000000000001',
    current_setting('test.chat_request_a')::uuid
  )::text,
  true
);

reset role;
select set_config(
  'test.main_chat_id',
  (
    select id::text
    from public.project_group_chats
    where project_id = 'e7100000-0000-4000-8000-000000000001'
  ),
  true
);
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id = 'e7100000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'the first accepted membership creates exactly one chat anchor'
);
select is(
  (
    select chat.activated_at
    from public.project_group_chats as chat
    where chat.id = current_setting('test.main_chat_id')::uuid
  ),
  (
    select membership.joined_at
    from public.project_memberships as membership
    where membership.id = current_setting('test.membership_a_one')::uuid
  ),
  'first activation uses the accepted membership timestamp'
);
select results_eq(
  $$
    select
      private.profile_is_project_creator(
        'e7100000-0000-4000-8000-000000000001',
        'a7100000-0000-4000-8000-000000000001'
      ),
      private.profile_has_current_project_chat_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7100000-0000-4000-8000-000000000001'
      ),
      private.profile_has_project_chat_history_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7100000-0000-4000-8000-000000000001'
      ),
      private.profile_was_project_member_at(
        'e7100000-0000-4000-8000-000000000001',
        'a7100000-0000-4000-8000-000000000001',
        statement_timestamp()
      )
  $$,
  $$values (true, true, true, false)$$,
  'the creator has persistent organizer entitlement without a membership interval'
);
select is(
  (
    select count(*)
    from public.project_memberships
    where project_id = 'e7100000-0000-4000-8000-000000000001'
      and participant_profile_id = 'a7100000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'creator entitlement does not fabricate a membership row'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select viewer_role, has_current_entitlement, has_history_entitlement
    from public.get_own_project_group_chat(
      'a7100000-0000-4000-8000-000000000001',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('creator'::text, true, true)$$,
  'the creator resolves the structural chat with organizer entitlement'
);

select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select viewer_role, has_current_entitlement, has_history_entitlement
    from public.get_own_project_group_chat(
      'a7200000-0000-4000-8000-000000000002',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('current_member'::text, true, true)$$,
  'an accepted participant has current and historical chat entitlement'
);
select throws_ok(
  'select id from public.project_group_chats',
  '42501',
  'permission denied for table project_group_chats',
  'an authenticated member cannot bypass the narrow RPC'
);

select set_config(
  'request.jwt.claim.sub',
  'a7400000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  $$
    select *
    from public.get_own_project_group_chat(
      'a7400000-0000-4000-8000-000000000004',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The project group chat is unavailable.',
  'an unrelated viewer cannot resolve a public Project chat'
);
select throws_ok(
  $$
    select *
    from public.get_own_project_group_chat(
      'a7400000-0000-4000-8000-000000000004',
      'e7990000-0000-4000-8000-000000000099'
    )
  $$,
  '42501',
  'The project group chat is unavailable.',
  'missing and unauthorized chat lookups fail identically'
);
select throws_ok(
  $$
    select *
    from public.get_own_project_group_chat(
      'a7200000-0000-4000-8000-000000000002',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected identity cannot cross-read a chat anchor'
);

reset role;
select results_eq(
  $$
    select
      private.profile_has_current_project_chat_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7400000-0000-4000-8000-000000000004'
      ),
      private.profile_has_project_chat_history_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7400000-0000-4000-8000-000000000004'
      )
  $$,
  $$values (false, false)$$,
  'public Project visibility grants no unrelated chat entitlement'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_b',
  public.accept_project_join_request(
    'a7100000-0000-4000-8000-000000000001',
    current_setting('test.chat_request_b')::uuid
  )::text,
  true
);

reset role;
select is(
  (
    select id
    from public.project_group_chats
    where project_id = 'e7100000-0000-4000-8000-000000000001'
  ),
  current_setting('test.main_chat_id')::uuid,
  'later accepted participants reuse the first chat ID'
);
select is(
  private.ensure_project_group_chat(
    'e7100000-0000-4000-8000-000000000001',
    (
      select min(joined_at)
      from public.project_memberships
      where project_id = 'e7100000-0000-4000-8000-000000000001'
    )
  ),
  current_setting('test.main_chat_id')::uuid,
  'repeated conflict-safe activation is idempotent'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.leave_project(
      'a7200000-0000-4000-8000-000000000002',
      current_setting('test.membership_a_one')::uuid
    )
  $$,
  'a participant can leave the first membership interval'
);

reset role;
select results_eq(
  $$
    select
      private.profile_has_current_project_chat_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7200000-0000-4000-8000-000000000002'
      ),
      private.profile_has_project_chat_history_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7200000-0000-4000-8000-000000000002'
      )
  $$,
  $$values (false, true)$$,
  'leaving immediately removes current entitlement but retains history'
);
select results_eq(
  $$
    select
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.joined_at - interval '1 microsecond'
      ),
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.joined_at
      ),
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.left_at
      )
    from public.project_memberships as membership
    where membership.id = current_setting('test.membership_a_one')::uuid
  $$,
  $$values (false, true, false)$$,
  'ended membership uses a half-open interval from join through before leave'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select viewer_role, has_current_entitlement, has_history_entitlement
    from public.get_own_project_group_chat(
      'a7200000-0000-4000-8000-000000000002',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('former_member'::text, false, true)$$,
  'a former participant retains the chat anchor without send entitlement'
);
select set_config(
  'test.chat_request_a_two',
  public.request_to_join_project(
    'a7200000-0000-4000-8000-000000000002',
    'e7100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_a_two',
  public.accept_project_join_request(
    'a7100000-0000-4000-8000-000000000001',
    current_setting('test.chat_request_a_two')::uuid
  )::text,
  true
);

reset role;
select is(
  (
    select count(*)
    from public.project_memberships
    where project_id = 'e7100000-0000-4000-8000-000000000001'
      and participant_profile_id = 'a7200000-0000-4000-8000-000000000002'
  ),
  2::bigint,
  'rejoin creates a second membership row without overwriting the first'
);
select is(
  (
    select id
    from public.project_group_chats
    where project_id = 'e7100000-0000-4000-8000-000000000001'
  ),
  current_setting('test.main_chat_id')::uuid,
  'rejoin retains the canonical chat ID'
);
select results_eq(
  $$
    with membership_intervals as (
      select
        first_membership.left_at as first_end,
        second_membership.joined_at as second_start
      from public.project_memberships as first_membership
      join public.project_memberships as second_membership
        on second_membership.id = current_setting('test.membership_a_two')::uuid
      where first_membership.id = current_setting('test.membership_a_one')::uuid
    )
    select
      private.profile_was_project_member_at(
        'e7100000-0000-4000-8000-000000000001',
        'a7200000-0000-4000-8000-000000000002',
        first_end + ((second_start - first_end) / 2)
      ),
      private.profile_was_project_member_at(
        'e7100000-0000-4000-8000-000000000001',
        'a7200000-0000-4000-8000-000000000002',
        second_start
      )
    from membership_intervals
  $$,
  $$values (false, true)$$,
  'the gap is excluded and the later rejoin interval begins inclusively'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select viewer_role, has_current_entitlement
    from public.get_own_project_group_chat(
      'a7200000-0000-4000-8000-000000000002',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('current_member'::text, true)$$,
  'rejoin restores current chat entitlement'
);

select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.remove_project_member(
      'a7100000-0000-4000-8000-000000000001',
      current_setting('test.membership_a_two')::uuid
    )
  $$,
  'the creator can remove the rejoined participant'
);

reset role;
select results_eq(
  $$
    select
      private.profile_has_current_project_chat_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7200000-0000-4000-8000-000000000002'
      ),
      private.profile_has_project_chat_history_entitlement(
        'e7100000-0000-4000-8000-000000000001',
        'a7200000-0000-4000-8000-000000000002'
      )
  $$,
  $$values (false, true)$$,
  'creator removal immediately removes current entitlement but preserves history'
);
select results_eq(
  $$
    select
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.joined_at
      ),
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.removed_at
      )
    from public.project_memberships as membership
    where membership.id = current_setting('test.membership_a_two')::uuid
  $$,
  $$values (true, false)$$,
  'removal follows the same half-open interval rule as voluntary leave'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select viewer_role, has_current_entitlement, has_history_entitlement
    from public.get_own_project_group_chat(
      'a7200000-0000-4000-8000-000000000002',
      'e7100000-0000-4000-8000-000000000001'
    )
  $$,
  $$values ('former_member'::text, false, true)$$,
  'a removed participant still resolves only their historical chat anchor'
);

select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.remove_project_member(
      'a7100000-0000-4000-8000-000000000001',
      current_setting('test.membership_b')::uuid
    )
  $$,
  'the creator can end the remaining current membership'
);

reset role;
update public.proposals
set
  starts_at = '2020-01-01 10:00+00',
  ends_at = '2020-01-01 12:00+00'
where id = 'e7100000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id = 'e7100000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'project completion and all memberships ending retain the chat anchor'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7300000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.tavolo_request',
  public.request_to_join_project(
    'a7300000-0000-4000-8000-000000000003',
    'f7100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a7100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.tavolo_membership',
  public.accept_project_join_request(
    'a7100000-0000-4000-8000-000000000001',
    current_setting('test.tavolo_request')::uuid
  )::text,
  true
);

reset role;
select results_eq(
  $$
    select project_kind, count(*)
    from public.project_group_chats as chat
    join public.projects as project on project.id = chat.project_id
    where chat.project_id = 'f7100000-0000-4000-8000-000000000001'
    group by project_kind
  $$,
  $$values ('recurring'::text, 1::bigint)$$,
  'the shared Project abstraction activates one Tavolo chat'
);
update public.recurring_activities
set
  lifecycle_state = 'paused',
  paused_at = statement_timestamp()
where id = 'f7100000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id = 'f7100000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'pausing a Tavolo retains its chat anchor'
);
update public.recurring_activities
set
  lifecycle_state = 'ended',
  paused_at = null,
  ended_at = statement_timestamp()
where id = 'f7100000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id = 'f7100000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'ending a Tavolo retains its chat anchor'
);

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values
  (
    'b7310000-0000-4000-8000-000000000001',
    'e7300000-0000-4000-8000-000000000003',
    'a7200000-0000-4000-8000-000000000002',
    'accepted',
    '2023-12-01 00:00+00',
    '2024-01-01 00:00+00',
    'a7100000-0000-4000-8000-000000000001'
  ),
  (
    'b7320000-0000-4000-8000-000000000002',
    'e7300000-0000-4000-8000-000000000003',
    'a7300000-0000-4000-8000-000000000003',
    'accepted',
    '2023-11-01 00:00+00',
    '2023-12-01 00:00+00',
    'a7100000-0000-4000-8000-000000000001'
  );
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  left_at
)
values
  (
    'c7310000-0000-4000-8000-000000000001',
    'e7300000-0000-4000-8000-000000000003',
    'a7200000-0000-4000-8000-000000000002',
    'b7310000-0000-4000-8000-000000000001',
    '2024-01-01 00:00+00',
    '2024-01-02 00:00+00'
  ),
  (
    'c7320000-0000-4000-8000-000000000002',
    'e7300000-0000-4000-8000-000000000003',
    'a7300000-0000-4000-8000-000000000003',
    'b7320000-0000-4000-8000-000000000002',
    '2023-12-01 00:00+00',
    '2023-12-02 00:00+00'
  );
select is(
  (
    select activated_at
    from public.project_group_chats
    where project_id = 'e7300000-0000-4000-8000-000000000003'
  ),
  '2023-12-01 00:00+00'::timestamptz,
  'out-of-order canonical history preserves the earliest activation time'
);
delete from public.project_group_chats
where project_id = 'e7300000-0000-4000-8000-000000000003';
select is(
  private.reconcile_project_group_chats(),
  1::bigint,
  'reconciliation backfills exactly the missing historical Project chat'
);
select set_config(
  'test.backfilled_chat_id',
  (
    select id::text
    from public.project_group_chats
    where project_id = 'e7300000-0000-4000-8000-000000000003'
  ),
  true
);
select is(
  (
    select activated_at
    from public.project_group_chats
    where id = current_setting('test.backfilled_chat_id')::uuid
  ),
  '2023-12-01 00:00+00'::timestamptz,
  'backfill uses the earliest canonical joined_at including ended history'
);
select is(
  private.reconcile_project_group_chats(),
  0::bigint,
  'repeated backfill reconciliation is state-idempotent'
);
select is(
  (
    select id
    from public.project_group_chats
    where project_id = 'e7300000-0000-4000-8000-000000000003'
  ),
  current_setting('test.backfilled_chat_id')::uuid,
  'idempotent reconciliation retains the backfilled chat identity'
);

select is(
  (
    select count(*)
    from private.audit_events
    where action like 'project.%chat%'
  ),
  0::bigint,
  'transactional anchor activation adds no redundant audit event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type like 'project.%chat%'
  ),
  0::bigint,
  'transactional activation does not consume or duplicate the participation outbox'
);

select * from finish();

rollback;
