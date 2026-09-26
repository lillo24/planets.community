begin;

select no_plan();

insert into auth.users (id, email)
values
  ('f6100000-0000-4000-8000-000000000001', 'resource-chat-owner@planets.invalid'),
  ('f6100000-0000-4000-8000-000000000002', 'resource-chat-requester-a@planets.invalid'),
  ('f6100000-0000-4000-8000-000000000003', 'resource-chat-requester-b@planets.invalid'),
  ('f6100000-0000-4000-8000-000000000004', 'resource-chat-unrelated@planets.invalid'),
  ('f6100000-0000-4000-8000-000000000005', 'resource-chat-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f6100000-0000-4000-8000-000000000001', 'Resource Chat Owner'),
  ('f6100000-0000-4000-8000-000000000002', 'Resource Chat Requester A'),
  ('f6100000-0000-4000-8000-000000000003', 'Resource Chat Requester B'),
  ('f6100000-0000-4000-8000-000000000004', 'Resource Chat Unrelated'),
  ('f6100000-0000-4000-8000-000000000005', null);

insert into public.resource_listings (
  id,
  owner_profile_id,
  listing_mode,
  lifecycle_state,
  title,
  description,
  country_code,
  locality,
  public_location_label,
  published_at
)
values
  (
    'f6200000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Resource chat workbench',
    'A listing used for chat completion and repeat episodes.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp()
  ),
  (
    'f6200000-0000-4000-8000-000000000002',
    'f6100000-0000-4000-8000-000000000001',
    'donate',
    'published',
    'Resource chat ladder',
    'A listing used to prove listing closure does not end coordination.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp()
  ),
  (
    'f6200000-0000-4000-8000-000000000003',
    'f6100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Resource chat backfill item',
    'A listing used for accepted-request chat backfill.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp()
  );

insert into public.resource_listing_requests (
  id,
  listing_id,
  requester_profile_id,
  status,
  resolved_at,
  resolved_by_profile_id
)
values
  (
    'f6300000-0000-4000-8000-000000000001',
    'f6200000-0000-4000-8000-000000000003',
    'f6100000-0000-4000-8000-000000000002',
    'accepted',
    statement_timestamp(),
    'f6100000-0000-4000-8000-000000000001'
  ),
  (
    'f6300000-0000-4000-8000-000000000002',
    'f6200000-0000-4000-8000-000000000003',
    'f6100000-0000-4000-8000-000000000003',
    'rejected',
    statement_timestamp(),
    'f6100000-0000-4000-8000-000000000001'
  );

select is(
  private.ensure_resource_request_chat_for_request(
    'f6300000-0000-4000-8000-000000000001',
    null
  ),
  private.ensure_resource_request_chat_for_request(
    'f6300000-0000-4000-8000-000000000001',
    null
  ),
  'accepted-request chat backfill is idempotent'
);
select private.ensure_resource_exchange_agreement_for_request(
  'f6300000-0000-4000-8000-000000000001',
  'f6100000-0000-4000-8000-000000000001',
  null
);
select is(
  (
    select count(*)
    from public.resource_request_chats
    where request_id = 'f6300000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'an existing accepted request owns exactly one backfilled chat'
);
select is(
  (
    select count(*)
    from public.resource_request_chats
    where request_id = 'f6300000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'a rejected request receives no chat'
);
select throws_ok(
  $$
    select private.ensure_resource_request_chat_for_request(
      'f6300000-0000-4000-8000-000000000002',
      null
    )
  $$,
  '55000',
  'Only an accepted resource listing request can own a chat.',
  'the activation helper rejects non-accepted requests'
);

set local role anon;
select throws_ok(
  $$select * from public.list_own_resource_request_chats(null, 20, null, null)$$,
  '42501',
  'permission denied for function list_own_resource_request_chats',
  'anonymous clients cannot list resource chats'
);
select throws_ok(
  $$select * from public.resource_request_chat_messages$$,
  '42501',
  'permission denied for table resource_request_chat_messages',
  'anonymous clients cannot enumerate message rows'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.main_request',
  public.request_resource_listing(
    'f6100000-0000-4000-8000-000000000002',
    'f6200000-0000-4000-8000-000000000001',
    'Private initial request text must never become a chat message'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.accept_resource_listing_request(
    'f6100000-0000-4000-8000-000000000001',
    current_setting('test.main_request')::uuid
  ),
  current_setting('test.main_request')::uuid,
  'the owner accepts the pending request'
);

reset role;
select set_config(
  'test.main_chat',
  (
    select id::text
    from public.resource_request_chats
    where request_id = current_setting('test.main_request')::uuid
  ),
  true
);
select set_config(
  'test.main_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.main_request')::uuid
  ),
  true
);
select results_eq(
  $$
    select
      request.status,
      agreement.lifecycle_state,
      chat.activated_at = request.resolved_at
    from public.resource_listing_requests as request
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = request.id
    join public.resource_request_chats as chat
      on chat.request_id = request.id
    where request.id = current_setting('test.main_request')::uuid
  $$,
  $$values ('accepted'::text, 'negotiating'::text, true)$$,
  'acceptance atomically creates one agreement and one chat at acceptance time'
);
select is(
  (
    select count(*)
    from public.resource_request_chat_messages
    where chat_id = current_setting('test.main_chat')::uuid
  ),
  0::bigint,
  'request text is not copied into the human message table'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select is(
  private.profile_can_receive_resource_request_chat_topic(
    private.resource_request_chat_realtime_topic(
      current_setting('test.main_chat')::uuid,
      'f6100000-0000-4000-8000-000000000001'
    )
  ),
  true,
  'the owner may receive the exact private resource-chat topic'
);
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select is(
  private.profile_can_receive_resource_request_chat_topic(
    private.resource_request_chat_realtime_topic(
      current_setting('test.main_chat')::uuid,
      'f6100000-0000-4000-8000-000000000002'
    )
  ),
  true,
  'the requester may receive the exact private resource-chat topic'
);
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000004',
  true
);
select is(
  private.profile_can_receive_resource_request_chat_topic(
    private.resource_request_chat_realtime_topic(
      current_setting('test.main_chat')::uuid,
      'f6100000-0000-4000-8000-000000000004'
    )
  ),
  false,
  'an unrelated profile cannot receive a resource-chat topic'
);
select is(
  private.profile_can_receive_resource_request_chat_topic('malformed'),
  false,
  'malformed private resource-chat topics fail closed'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select
      viewer_role,
      agreement_lifecycle,
      has_send_entitlement,
      last_visible_message_id,
      activity_at = activated_at
    from public.get_own_resource_request_chat(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.main_chat')::uuid
    )
  $$,
  $$values ('owner'::text, 'negotiating'::text, true, null::uuid, true)$$,
  'a newly activated no-message chat starts activity at activation'
);

select pg_sleep(0.002);
select set_config(
  'test.main_terms',
  public.propose_resource_exchange_terms(
    'f6100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    null,
    null,
    'give', null, null,
    'none', null, null, null, 'Private agreement note'
  )::text,
  true
);
select results_eq(
  $$
    select
      last_visible_message_id,
      activity_at > activated_at
    from public.get_own_resource_request_chat(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.main_chat')::uuid
    )
  $$,
  $$values (null::uuid, true)$$,
  'terms activity bubbles the chat without inventing a human preview'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select public.accept_resource_exchange_terms(
  'f6100000-0000-4000-8000-000000000002',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.main_terms')::uuid
);
select pg_sleep(0.002);
select set_config(
  'test.main_message',
  (
    select message_id::text
    from public.send_resource_request_chat_message(
      'f6100000-0000-4000-8000-000000000002',
      current_setting('test.main_chat')::uuid,
      E'  Durable requester message  \n'
    )
  ),
  true
);

reset role;
select results_eq(
  $$
    select sender_profile_id, body
    from public.resource_request_chat_messages
    where id = current_setting('test.main_message')::uuid
  $$,
  $$values (
    'f6100000-0000-4000-8000-000000000002'::uuid,
    'Durable requester message'::text
  )$$,
  'send derives the authenticated sender and trims the durable body'
);
select ok(
  (
    select created_at between transaction_timestamp() and clock_timestamp()
    from public.resource_request_chat_messages
    where id = current_setting('test.main_message')::uuid
  ),
  'the server assigns the immutable message timestamp'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select sender_profile_id, sender_display_name, body
    from public.list_own_resource_request_chat_messages(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.main_chat')::uuid,
      20,
      null,
      null
    )
    where message_id = current_setting('test.main_message')::uuid
  $$,
  $$values (
    'f6100000-0000-4000-8000-000000000002'::uuid,
    'Resource Chat Requester A'::text,
    'Durable requester message'::text
  )$$,
  'the owner reads the request-conversation history'
);
select results_eq(
  $$
    select
      viewer_role,
      last_visible_message_id,
      last_visible_message_body,
      activity_at = last_visible_message_at
    from public.get_own_resource_request_chat(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.main_chat')::uuid
    )
  $$,
  $$values (
    'owner'::text,
    current_setting('test.main_message')::uuid,
    'Durable requester message'::text,
    true
  )$$,
  'the exact summary exposes an honest latest human preview'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  format(
    $query$
      select * from public.get_own_resource_request_chat(
        'f6100000-0000-4000-8000-000000000004',
        %L::uuid
      )
    $query$,
    current_setting('test.main_chat')
  ),
  '42501',
  'The resource request chat is unavailable.',
  'an unrelated authenticated user cannot read the exact chat'
);
select throws_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000004',
        %L::uuid,
        'unrelated send'
      )
    $query$,
    current_setting('test.main_chat')
  ),
  '42501',
  'The resource request chat is unavailable.',
  'an unrelated authenticated user cannot send'
);
select is(
  (
    select count(*)
    from public.list_own_resource_request_chats(
      'f6100000-0000-4000-8000-000000000004',
      20,
      null,
      null
    )
  ),
  0::bigint,
  'an unrelated user has no resource-chat list visibility'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000005',
  true
);
select throws_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000005',
        %L::uuid,
        'incomplete send'
      )
    $query$,
    current_setting('test.main_chat')
  ),
  '55000',
  'A complete profile is required to request a resource listing.',
  'an incomplete profile cannot send resource-chat messages'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000002',
        %L::uuid,
        E' \t\n '
      )
    $query$,
    current_setting('test.main_chat')
  ),
  '22023',
  'A resource request chat message cannot be empty.',
  'whitespace-only bodies are rejected'
);
select throws_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000002',
        %L::uuid,
        repeat('x', 4001)
      )
    $query$,
    current_setting('test.main_chat')
  ),
  '22023',
  'A resource request chat message cannot exceed 4,000 characters.',
  'oversized bodies are rejected'
);

reset role;
select throws_ok(
  format(
    $query$
      update public.resource_request_chat_messages
      set body = 'edited'
      where id = %L::uuid
    $query$,
    current_setting('test.main_message')
  ),
  '55000',
  'Resource request chat messages are immutable.',
  'persisted messages cannot be updated'
);
select throws_ok(
  format(
    $query$
      delete from public.resource_request_chat_messages
      where id = %L::uuid
    $query$,
    current_setting('test.main_message')
  ),
  '55000',
  'Resource request chat messages are immutable.',
  'persisted messages cannot be deleted'
);

select pg_sleep(0.002);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f6100000-0000-4000-8000-000000000001',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.main_terms')::uuid,
  'owner_resource',
  'resource_provided'
);
select results_eq(
  $$
    select
      last_visible_message_id,
      last_visible_message_body,
      activity_at > last_visible_message_at
    from public.get_own_resource_request_chat(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.main_chat')::uuid
    )
  $$,
  $$values (
    current_setting('test.main_message')::uuid,
    'Durable requester message'::text,
    true
  )$$,
  'agreement milestones bump activity without becoming fake human previews'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select public.record_resource_exchange_milestone(
  'f6100000-0000-4000-8000-000000000002',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.main_terms')::uuid,
  'owner_resource',
  'resource_received'
);
select throws_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000002',
        %L::uuid,
        'post-completion send'
      )
    $query$,
    current_setting('test.main_chat')
  ),
  'PT409',
  'The resource request chat is read-only because coordination is closed.',
  'automatic completion makes the chat read-only'
);
select results_eq(
  $$
    select agreement_lifecycle, has_send_entitlement,
      coordination_closed_at is not null
    from public.get_own_resource_request_chat(
      'f6100000-0000-4000-8000-000000000002',
      current_setting('test.main_chat')::uuid
    )
  $$,
  $$values ('completed'::text, false, true)$$,
  'completed coordination remains readable with explicit read-only state'
);
select is(
  (
    select count(*)
    from public.list_own_resource_request_chat_messages(
      'f6100000-0000-4000-8000-000000000002',
      current_setting('test.main_chat')::uuid,
      20,
      null,
      null
    )
    where message_id = current_setting('test.main_message')::uuid
  ),
  1::bigint,
  'both counterparties retain full message history after completion'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select is(
  private.profile_can_receive_resource_request_chat_topic(
    private.resource_request_chat_realtime_topic(
      current_setting('test.main_chat')::uuid,
      'f6100000-0000-4000-8000-000000000002'
    )
  ),
  true,
  'topic read authorization survives agreement completion'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.repeat_request',
  public.request_resource_listing(
    'f6100000-0000-4000-8000-000000000002',
    'f6200000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f6100000-0000-4000-8000-000000000001',
  current_setting('test.repeat_request')::uuid
);
reset role;
select set_config(
  'test.repeat_chat',
  (
    select id::text
    from public.resource_request_chats
    where request_id = current_setting('test.repeat_request')::uuid
  ),
  true
);
select set_config(
  'test.repeat_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.repeat_request')::uuid
  ),
  true
);
select isnt(
  current_setting('test.repeat_chat')::uuid,
  current_setting('test.main_chat')::uuid,
  'a later request episode receives a distinct conversation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.repeat_message',
  (
    select message_id::text
    from public.send_resource_request_chat_message(
      'f6100000-0000-4000-8000-000000000002',
      current_setting('test.repeat_chat')::uuid,
      'Message retained after cancellation'
    )
  ),
  true
);
select public.cancel_resource_exchange_agreement(
  'f6100000-0000-4000-8000-000000000002',
  current_setting('test.repeat_agreement')::uuid
);
select throws_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000002',
        %L::uuid,
        'post-cancel send'
      )
    $query$,
    current_setting('test.repeat_chat')
  ),
  'PT409',
  'The resource request chat is read-only because coordination is closed.',
  'cancellation makes the chat read-only'
);
select is(
  (
    select count(*)
    from public.list_own_resource_request_chat_messages(
      'f6100000-0000-4000-8000-000000000002',
      current_setting('test.repeat_chat')::uuid,
      20,
      null,
      null
    )
    where message_id = current_setting('test.repeat_message')::uuid
  ),
  1::bigint,
  'cancelled coordination retains readable human history'
);

select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.close_request',
  public.request_resource_listing(
    'f6100000-0000-4000-8000-000000000003',
    'f6200000-0000-4000-8000-000000000002',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f6100000-0000-4000-8000-000000000001',
  current_setting('test.close_request')::uuid
);
reset role;
select set_config(
  'test.close_chat',
  (
    select id::text
    from public.resource_request_chats
    where request_id = current_setting('test.close_request')::uuid
  ),
  true
);
select set_config(
  'test.close_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.close_request')::uuid
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select public.close_resource_listing(
  'f6100000-0000-4000-8000-000000000001',
  'f6200000-0000-4000-8000-000000000002'
);
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  format(
    $query$
      select * from public.send_resource_request_chat_message(
        'f6100000-0000-4000-8000-000000000003',
        %L::uuid,
        'Accepted coordination survives listing closure'
      )
    $query$,
    current_setting('test.close_chat')
  ),
  'listing closure does not disable an accepted open chat'
);
select results_eq(
  $$
    select agreement_lifecycle, has_send_entitlement
    from public.get_own_resource_request_chat(
      'f6100000-0000-4000-8000-000000000003',
      current_setting('test.close_chat')::uuid
    )
  $$,
  $$values ('negotiating'::text, true)$$,
  'the closed listing chat remains open because coordination remains open'
);

reset role;
insert into public.resource_request_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values
  (
    'f6400000-0000-4000-8000-000000000001',
    current_setting('test.close_chat')::uuid,
    'f6100000-0000-4000-8000-000000000001',
    'Same-time resource message one',
    '2000-01-01 00:00+00'
  ),
  (
    'f6400000-0000-4000-8000-000000000002',
    current_setting('test.close_chat')::uuid,
    'f6100000-0000-4000-8000-000000000001',
    'Same-time resource message two',
    '2000-01-01 00:00+00'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f6100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select message_id
    from public.list_own_resource_request_chat_messages(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.close_chat')::uuid,
      1,
      '2000-01-01 00:00+00',
      'ffffffff-ffff-4fff-bfff-ffffffffffff'
    )
  $$,
  $$values ('f6400000-0000-4000-8000-000000000002'::uuid)$$,
  'history keysets use the UUID tie-breaker without skipping same-time rows'
);
select results_eq(
  $$
    select message_id
    from public.list_own_resource_request_chat_messages(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.close_chat')::uuid,
      1,
      '2000-01-01 00:00+00',
      'f6400000-0000-4000-8000-000000000002'
    )
  $$,
  $$values ('f6400000-0000-4000-8000-000000000001'::uuid)$$,
  'the next history page returns the other same-time message exactly once'
);
select throws_ok(
  $$
    select * from public.list_own_resource_request_chat_messages(
      'f6100000-0000-4000-8000-000000000001',
      current_setting('test.close_chat')::uuid,
      51,
      null,
      null
    )
  $$,
  '22023',
  'The resource request chat message page size must be between 1 and 50.',
  'history limits are bounded'
);
select throws_ok(
  $$
    select * from public.list_own_resource_request_chats(
      'f6100000-0000-4000-8000-000000000001',
      20,
      statement_timestamp(),
      null
    )
  $$,
  '22023',
  'Both resource request chat-list cursor values must be provided together.',
  'partial list cursors fail validation'
);

select set_config(
  'test.first_list_chat',
  (
    select chat_id::text
    from public.list_own_resource_request_chats(
      'f6100000-0000-4000-8000-000000000001',
      1,
      null,
      null
    )
  ),
  true
);
select set_config(
  'test.first_list_activity',
  (
    select activity_at::text
    from public.list_own_resource_request_chats(
      'f6100000-0000-4000-8000-000000000001',
      1,
      null,
      null
    )
  ),
  true
);
select is(
  (
    select count(*)
    from public.list_own_resource_request_chats(
      'f6100000-0000-4000-8000-000000000001',
      1,
      current_setting('test.first_list_activity')::timestamptz,
      current_setting('test.first_list_chat')::uuid
    )
    where chat_id = current_setting('test.first_list_chat')::uuid
  ),
  0::bigint,
  'chat-list keysets do not repeat the preceding item'
);

reset role;
select results_eq(
  $$
    select
      event.event_type,
      event.payload ? 'body' as has_body,
      event.payload ? 'chat_id' as has_chat,
      event.payload ? 'request_id' as has_request,
      event.payload ? 'agreement_id' as has_agreement,
      event.payload ? 'listing_id' as has_listing,
      event.payload ? 'owner_profile_id' as has_owner,
      event.payload ? 'requester_profile_id' as has_requester,
      event.payload ? 'message_id' as has_message,
      event.payload ? 'sender_profile_id' as has_sender
    from private.outbox_events as event
    where event.event_type = 'resource_chat.message_sent'
      and (event.payload ->> 'message_id')::uuid =
        current_setting('test.main_message')::uuid
  $$,
  $$values (
    'resource_chat.message_sent'::text,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true
  )$$,
  'message outbox state is identifier-only and resolves both counterparties'
);
select is(
  (
    select count(*)
    from realtime.messages
    where extension = 'broadcast'
      and event = 'resource.chat_message_sent'
      and payload ->> 'message_id' = current_setting('test.main_message')
      and payload ? 'body'
  ),
  0::bigint,
  'message Realtime payloads never contain the human body'
);
select is(
  (
    select count(*)
    from realtime.messages
    where extension = 'broadcast'
      and event = 'resource.chat_message_sent'
      and payload ->> 'message_id' = current_setting('test.main_message')
  ),
  2::bigint,
  'a human message broadcasts one private hint to each counterparty'
);
select is(
  (
    select count(*)
    from realtime.messages
    where extension = 'broadcast'
      and event = 'resource.exchange_changed'
      and payload ->> 'agreement_id' = current_setting('test.main_agreement')
      and (
        payload::text like '%Private agreement note%'
        or payload ? 'body'
      )
  ),
  0::bigint,
  'agreement refresh hints contain no private terms or chat body'
);
select is(
  (
    select count(*)
    from realtime.messages
    where extension = 'broadcast'
      and event = 'resource.exchange_changed'
      and payload ->> 'agreement_event_id' = (
        select event.id::text
        from public.resource_exchange_agreement_events as event
        where event.agreement_id = current_setting('test.main_agreement')::uuid
          and event.event_kind = 'agreement_completed'
      )
  ),
  2::bigint,
  'the final completion signal reaches both historical counterparties'
);
select is(
  (
    select count(*)
    from public.resource_request_chat_messages
    where chat_id = current_setting('test.main_chat')::uuid
      and body in (
        'agreement_completed',
        'terms_proposed',
        'resource_provided',
        'resource_received'
      )
  ),
  0::bigint,
  'structured agreement events never become fake human messages'
);
select is(
  (
    select count(*)
    from private.audit_events
    where metadata::text like '%Durable requester message%'
      or metadata::text like '%Private agreement note%'
  ),
  0::bigint,
  'message and agreement private text never leaks into audit metadata'
);

select * from finish();

rollback;
