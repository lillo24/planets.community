begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a8100000-0000-4000-8000-000000000001', 'message-creator@planets.invalid'),
  ('a8200000-0000-4000-8000-000000000002', 'message-a@planets.invalid'),
  ('a8300000-0000-4000-8000-000000000003', 'message-b@planets.invalid'),
  ('a8400000-0000-4000-8000-000000000004', 'message-unrelated@planets.invalid'),
  ('a8500000-0000-4000-8000-000000000005', 'message-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a8100000-0000-4000-8000-000000000001', 'Message Creator'),
  ('a8200000-0000-4000-8000-000000000002', 'Message Participant A'),
  ('a8300000-0000-4000-8000-000000000003', 'Message Participant B'),
  ('a8400000-0000-4000-8000-000000000004', 'Message Unrelated'),
  ('a8500000-0000-4000-8000-000000000005', null);

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
  'e8100000-0000-4000-8000-000000000001',
  'a8100000-0000-4000-8000-000000000001',
  'published',
  'Project chat message Proposal',
  '2098-01-01 10:00+00',
  '2098-01-01 12:00+00',
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
  'f8100000-0000-4000-8000-000000000001',
  'a8100000-0000-4000-8000-000000000001',
  'published',
  'Project chat message Tavolo',
  statement_timestamp()
);

set local role anon;
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(null, null, 'no')
  $$,
  '42501',
  'permission denied for function send_project_chat_message',
  'anonymous clients cannot send messages'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_chat_messages(null, null, 20, null, null)
  $$,
  '42501',
  'permission denied for function list_own_project_chat_messages',
  'anonymous clients cannot read message history'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_group_chats(null, 20, null, null)
  $$,
  '42501',
  'permission denied for function list_own_project_group_chats',
  'anonymous clients cannot list Project chats'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8200000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.request_a',
  public.request_to_join_project(
    'a8200000-0000-4000-8000-000000000002',
    'e8100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_a',
  public.accept_project_join_request(
    'a8100000-0000-4000-8000-000000000001',
    current_setting('test.request_a')::uuid
  )::text,
  true
);

reset role;
select set_config(
  'test.chat_id',
  (
    select id::text
    from public.project_group_chats
    where project_id = 'e8100000-0000-4000-8000-000000000001'
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.message_1',
  (
    select message_id::text
    from public.send_project_chat_message(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      E'  First durable message  \n'
    )
  ),
  true
);
select results_eq(
  $$
    select chat_id, sender_profile_id, body
    from public.send_project_chat_message(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      'Second creator message'
    )
  $$,
  $$values (
    current_setting('test.chat_id')::uuid,
    'a8100000-0000-4000-8000-000000000001'::uuid,
    'Second creator message'::text
  )$$,
  'the creator sends with server-owned identity and a canonical response'
);
select set_config(
  'test.message_creator_2',
  (
    select id::text
    from public.project_chat_messages
    where body = 'Second creator message'
  ),
  true
);

reset role;
select is(
  (
    select body
    from public.project_chat_messages
    where id = current_setting('test.message_1')::uuid
  ),
  'First durable message',
  'the server canonically trims a message body'
);
select ok(
  (
    select created_at between transaction_timestamp() and clock_timestamp()
    from public.project_chat_messages
    where id = current_setting('test.message_1')::uuid
  ),
  'the server assigns the immutable message timestamp'
);
select results_eq(
  $$
    select
      event.event_type,
      event.payload ? 'body' as has_body,
      event.payload ? 'email' as has_email,
      event.payload ? 'chat_id' as has_chat_id,
      event.payload ? 'project_id' as has_project_id,
      event.payload ? 'project_kind' as has_project_kind,
      event.payload ? 'message_id' as has_message_id,
      event.payload ? 'sender_profile_id' as has_sender
    from private.outbox_events as event
    where (event.payload ->> 'message_id')::uuid
      = current_setting('test.message_1')::uuid
  $$,
  $$values (
    'project.chat_message_sent'::text,
    false,
    false,
    true,
    true,
    true,
    true,
    true
  )$$,
  'a successful send emits one identifier-only outbox event without body or email'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.metadata::text like '%First durable message%'
  ),
  0::bigint,
  'message bodies are absent from audit metadata'
);

select throws_ok(
  $$
    update public.project_chat_messages
    set body = 'edited'
    where id = current_setting('test.message_1')::uuid
  $$,
  '55000',
  'Project chat messages are immutable.',
  'even the table owner cannot update a persisted message through ordinary DML'
);
select throws_ok(
  $$
    delete from public.project_chat_messages
    where id = current_setting('test.message_1')::uuid
  $$,
  '55000',
  'Project chat messages are immutable.',
  'even the table owner cannot delete a persisted message through ordinary DML'
);
select throws_ok(
  $$
    insert into public.project_chat_messages (
      chat_id,
      sender_profile_id,
      body
    )
    values (
      current_setting('test.chat_id')::uuid,
      'a8100000-0000-4000-8000-000000000001',
      ' padded '
    )
  $$,
  '23514',
  null,
  'the table constraint rejects non-canonical bodies'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.request_b_one',
  public.request_to_join_project(
    'a8300000-0000-4000-8000-000000000003',
    'e8100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_b_one',
  public.accept_project_join_request(
    'a8100000-0000-4000-8000-000000000001',
    current_setting('test.request_b_one')::uuid
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8200000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.message_2',
  (
    select message_id::text
    from public.send_project_chat_message(
      'a8200000-0000-4000-8000-000000000002',
      current_setting('test.chat_id')::uuid,
      'Participant A message'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select results_eq(
  $$
    select body
    from public.list_own_project_chat_messages(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      20,
      null,
      null
    )
    where message_id in (
      current_setting('test.message_1')::uuid,
      current_setting('test.message_2')::uuid
    )
    order by created_at desc, message_id desc
  $$,
  $$values
    ('Participant A message'::text),
    ('First durable message'::text)
  $$,
  'a newly accepted current participant reads messages from before joining'
);

select throws_ok(
  $$
    select * from public.project_chat_messages
  $$,
  '42501',
  'permission denied for table project_chat_messages',
  'an authorized current member cannot bypass the history RPC'
);
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8200000-0000-4000-8000-000000000002',
      current_setting('test.chat_id')::uuid,
      'cross identity'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'expected identity prevents a cross-profile send'
);
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      E' \t\n '
    )
  $$,
  '22023',
  'A Project chat message cannot be empty.',
  'whitespace-only bodies fail canonical validation'
);
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      repeat('x', 4001)
    )
  $$,
  '22023',
  'A Project chat message cannot exceed 4,000 characters.',
  'oversized Unicode-character bodies are rejected'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select is(
  private.profile_can_receive_project_chat_realtime_topic(
    private.project_chat_realtime_topic(
      current_setting('test.chat_id')::uuid,
      'a8300000-0000-4000-8000-000000000003'
    )
  ),
  true,
  'a current member is eligible for their private chat Broadcast topic'
);
select is(
  private.profile_can_receive_project_chat_realtime_topic(
    private.project_chat_realtime_topic(
      current_setting('test.chat_id')::uuid,
      'a8400000-0000-4000-8000-000000000004'
    )
  ),
  false,
  'a user cannot subscribe to another profile private topic'
);
select is(
  private.profile_can_receive_project_chat_realtime_topic('malformed'),
  false,
  'malformed Realtime topics fail closed'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select public.leave_project(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.membership_b_one')::uuid
    )
  $$,
  'participant B leaves the first interval'
);

select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.message_3',
  (
    select message_id::text
    from public.send_project_chat_message(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      'Gap message'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select results_eq(
  $$
    select
      count(*) filter (
        where message_id = current_setting('test.message_1')::uuid
      ),
      count(*) filter (
        where message_id = current_setting('test.message_2')::uuid
      ),
      count(*) filter (
        where message_id = current_setting('test.message_3')::uuid
      )
    from public.list_own_project_chat_messages(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      50,
      null,
      null
    )
  $$,
  $$values (1::bigint, 1::bigint, 0::bigint)$$,
  'a former member retains prior history but cannot read a message after leave'
);
select results_eq(
  $$
    select last_visible_message_id, last_visible_message_body
    from public.list_own_project_group_chats(
      'a8300000-0000-4000-8000-000000000003',
      20,
      null,
      null
    )
    where chat_id = current_setting('test.chat_id')::uuid
  $$,
  $$values (
    current_setting('test.message_2')::uuid,
    'Participant A message'::text
  )$$,
  'an inaccessible new message does not change a former member preview'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select is(
  private.profile_can_receive_project_chat_realtime_topic(
    private.project_chat_realtime_topic(
      current_setting('test.chat_id')::uuid,
      'a8300000-0000-4000-8000-000000000003'
    )
  ),
  false,
  'a former member is no longer eligible for live Broadcast signals'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      'former cannot send'
    )
  $$,
  '42501',
  'The project group chat is unavailable for sending.',
  'a former participant cannot send'
);
select set_config(
  'test.request_b_two',
  public.request_to_join_project(
    'a8300000-0000-4000-8000-000000000003',
    'e8100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.membership_b_two',
  public.accept_project_join_request(
    'a8100000-0000-4000-8000-000000000001',
    current_setting('test.request_b_two')::uuid
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_messages(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      50,
      null,
      null
    )
    where message_id = current_setting('test.message_3')::uuid
  ),
  1::bigint,
  'rejoin reveals accumulated gap history'
);
select set_config(
  'test.message_4',
  (
    select message_id::text
    from public.send_project_chat_message(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      'Rejoined participant message'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.remove_project_member(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.membership_b_two')::uuid
    )
  $$,
  'the creator removes participant B after rejoin'
);
select set_config(
  'test.message_5',
  (
    select message_id::text
    from public.send_project_chat_message(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      'After removal message'
    )
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a8300000-0000-4000-8000-000000000003',
  true
);
select results_eq(
  $$
    select
      count(*) filter (
        where message_id = current_setting('test.message_3')::uuid
      ),
      count(*) filter (
        where message_id = current_setting('test.message_4')::uuid
      ),
      count(*) filter (
        where message_id = current_setting('test.message_5')::uuid
      )
    from public.list_own_project_chat_messages(
      'a8300000-0000-4000-8000-000000000003',
      current_setting('test.chat_id')::uuid,
      50,
      null,
      null
    )
  $$,
  $$values (1::bigint, 1::bigint, 0::bigint)$$,
  'the later removal frontier retains gap/rejoin history but hides later messages'
);
select results_eq(
  $$
    select last_visible_message_id, last_visible_message_body
    from public.list_own_project_group_chats(
      'a8300000-0000-4000-8000-000000000003',
      20,
      null,
      null
    )
    where chat_id = current_setting('test.chat_id')::uuid
  $$,
  $$values (
    current_setting('test.message_4')::uuid,
    'Rejoined participant message'::text
  )$$,
  'the latest former-member frontier controls preview and activity after removal'
);

select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_messages(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      50,
      null,
      null
    )
    where message_id in (
      current_setting('test.message_1')::uuid,
      current_setting('test.message_2')::uuid,
      current_setting('test.message_3')::uuid,
      current_setting('test.message_4')::uuid,
      current_setting('test.message_5')::uuid
    )
  ),
  5::bigint,
  'the immutable creator can read every message across membership changes'
);

select set_config(
  'request.jwt.claim.sub',
  'a8400000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  $$
    select *
    from public.list_own_project_chat_messages(
      'a8400000-0000-4000-8000-000000000004',
      current_setting('test.chat_id')::uuid,
      20,
      null,
      null
    )
  $$,
  '42501',
  'The project group chat is unavailable.',
  'an unrelated user cannot read an existing chat'
);
select is(
  (
    select count(*)
    from public.list_own_project_group_chats(
      'a8400000-0000-4000-8000-000000000004',
      20,
      null,
      null
    )
  ),
  0::bigint,
  'an unrelated user has no chat-list visibility'
);
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8400000-0000-4000-8000-000000000004',
      current_setting('test.chat_id')::uuid,
      'unrelated send'
    )
  $$,
  '42501',
  'The project group chat is unavailable for sending.',
  'an unrelated user cannot send'
);

select set_config(
  'request.jwt.claim.sub',
  'a8500000-0000-4000-8000-000000000005',
  true
);
select throws_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8500000-0000-4000-8000-000000000005',
      current_setting('test.chat_id')::uuid,
      'incomplete send'
    )
  $$,
  '55000',
  'A complete profile is required to send Project chat messages.',
  'a skeletal authenticated profile cannot send'
);

reset role;
insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values
  (
    'd8100000-0000-4000-8000-000000000001',
    current_setting('test.chat_id')::uuid,
    'a8100000-0000-4000-8000-000000000001',
    'Same-time one',
    '2000-01-01 00:00+00'
  ),
  (
    'd8100000-0000-4000-8000-000000000002',
    current_setting('test.chat_id')::uuid,
    'a8100000-0000-4000-8000-000000000001',
    'Same-time two',
    '2000-01-01 00:00+00'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select message_id, body
    from public.list_own_project_chat_messages(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      1,
      '2000-01-01 00:00+00',
      'ffffffff-ffff-4fff-bfff-ffffffffffff'
    )
  $$,
  $$values (
    'd8100000-0000-4000-8000-000000000002'::uuid,
    'Same-time two'::text
  )$$,
  'the first same-timestamp keyset page uses the UUID tie-breaker'
);
select results_eq(
  $$
    select message_id, body
    from public.list_own_project_chat_messages(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      1,
      '2000-01-01 00:00+00',
      'd8100000-0000-4000-8000-000000000002'
    )
  $$,
  $$values (
    'd8100000-0000-4000-8000-000000000001'::uuid,
    'Same-time one'::text
  )$$,
  'the next keyset page neither duplicates nor skips a same-time row'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_chat_messages(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      20,
      statement_timestamp(),
      null
    )
  $$,
  '22023',
  'Both Project chat message cursor values must be provided together.',
  'partial history cursors fail validation'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_chat_messages(
      'a8100000-0000-4000-8000-000000000001',
      current_setting('test.chat_id')::uuid,
      51,
      null,
      null
    )
  $$,
  '22023',
  'The Project chat message page size must be between 1 and 50.',
  'history page size is bounded'
);

select set_config(
  'request.jwt.claim.sub',
  'a8200000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.tavolo_request',
  public.request_to_join_project(
    'a8200000-0000-4000-8000-000000000002',
    'f8100000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a8100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.tavolo_membership',
  public.accept_project_join_request(
    'a8100000-0000-4000-8000-000000000001',
    current_setting('test.tavolo_request')::uuid
  )::text,
  true
);

reset role;
select set_config(
  'test.tavolo_chat_id',
  (
    select id::text
    from public.project_group_chats
    where project_id = 'f8100000-0000-4000-8000-000000000001'
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8200000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8200000-0000-4000-8000-000000000002',
      current_setting('test.tavolo_chat_id')::uuid,
      'Tavolo current-member message'
    )
  $$,
  'a current Tavolo participant can send through the shared Project domain'
);

reset role;
update public.recurring_activities
set lifecycle_state = 'ended', ended_at = clock_timestamp()
where id = 'f8100000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a8200000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select *
    from public.send_project_chat_message(
      'a8200000-0000-4000-8000-000000000002',
      current_setting('test.tavolo_chat_id')::uuid,
      'Ended Tavolo coordination remains writable'
    )
  $$,
  'Project lifecycle alone does not revoke Tavolo chat send entitlement'
);
select results_eq(
  $$
    select project_kind, project_title, viewer_role, has_current_entitlement
    from public.list_own_project_group_chats(
      'a8200000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
    where chat_id = current_setting('test.tavolo_chat_id')::uuid
  $$,
  $$values (
    'recurring'::text,
    'Project chat message Tavolo'::text,
    'current_member'::text,
    true
  )$$,
  'the accessible chat list returns a narrow Tavolo summary'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_group_chats(
      'a8200000-0000-4000-8000-000000000002',
      20,
      statement_timestamp(),
      null
    )
  $$,
  '22023',
  'Both Project chat-list cursor values must be provided together.',
  'partial chat-list cursors fail validation'
);

select * from finish();

rollback;
