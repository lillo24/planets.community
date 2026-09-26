begin;

select no_plan();

insert into auth.users (id, email)
values
  ('d1100000-0000-4000-8000-000000000001', 'request-chat-creator@planets.invalid'),
  ('d1100000-0000-4000-8000-000000000002', 'request-chat-requester@planets.invalid'),
  ('d1100000-0000-4000-8000-000000000003', 'request-chat-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('d1100000-0000-4000-8000-000000000001', 'Request Chat Creator'),
  ('d1100000-0000-4000-8000-000000000002', 'Request Chat Requester'),
  ('d1100000-0000-4000-8000-000000000003', 'Request Chat Unrelated');

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
  'd1200000-0000-4000-8000-000000000001',
  'd1100000-0000-4000-8000-000000000001',
  'published',
  'Participation request private chat',
  statement_timestamp() + interval '2 days',
  statement_timestamp() + interval '3 days',
  'Europe/Rome',
  statement_timestamp() - interval '1 day'
);

insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at
)
values (
  'd1300000-0000-4000-8000-000000000001',
  'd1200000-0000-4000-8000-000000000001',
  'Request chat paint',
  'open',
  statement_timestamp(),
  statement_timestamp()
);

set local role anon;
select throws_ok(
  $$
    select *
    from public.get_own_project_join_request_chat(
      null,
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function get_own_project_join_request_chat',
  'anonymous clients cannot resolve a request chat'
);
select throws_ok(
  $$select * from public.project_join_request_chat_messages$$,
  '42501',
  'permission denied for table project_join_request_chat_messages',
  'anonymous clients cannot enumerate request-chat messages'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.request_chat_request',
  public.request_to_join_project(
    'd1100000-0000-4000-8000-000000000002',
    'd1200000-0000-4000-8000-000000000001',
    'Private request note',
    '{}'::uuid[],
    array['d1300000-0000-4000-8000-000000000001'::uuid]
  )::text,
  true
);
reset role;

select set_config(
  'test.request_chat_chat',
  (
    select chat.id::text
    from public.project_join_request_chats as chat
    where chat.request_id = current_setting('test.request_chat_request')::uuid
  ),
  true
);

select results_eq(
  $$
    select
      chat.activated_at = request.created_at,
      (
        select count(*)
        from public.project_join_request_resource_selections as selection
        where selection.request_id = request.id
      )
    from public.project_join_requests as request
    join public.project_join_request_chats as chat
      on chat.request_id = request.id
    where request.id = current_setting('test.request_chat_request')::uuid
  $$,
  $$values (true, 1::bigint)$$,
  'request creation atomically persists selections and one canonically timed chat'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select
      exact.viewer_role,
      exact.request_status,
      exact.request_message,
      exact.is_read_only,
      exact.has_send_entitlement,
      exact.accepted_project_group_chat_id is null
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_request')::uuid
    ) as exact
  $$,
  $$values (
    'requester'::text,
    'pending'::text,
    'Private request note'::text,
    false,
    true,
    true
  )$$,
  'the requester resolves the exact pending episode and send entitlement'
);
select is(
  (
    select count(*)
    from public.list_own_project_join_request_chat_items(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_chat')::uuid,
      20,
      null,
      null,
      null
    ) as item
    where item.item_kind = 'request'
      and item.request_message = 'Private request note'
      and item.message_id is null
      and item.sender_profile_id is null
      and item.body is null
  ),
  1::bigint,
  'the initial note is one structured Request item, not a human message'
);
select is(
  (
    select count(*)
    from public.list_own_structured_request_message_items(
      'd1100000-0000-4000-8000-000000000002',
      20,
      null,
      null,
      null
    ) as item
    where item.item_kind = 'participation_request'
      and item.request_id = current_setting('test.request_chat_request')::uuid
  ),
  1::bigint,
  'the established structured Requests projection remains intact'
);
reset role;
select is(
  private.profile_can_receive_project_join_request_chat_topic(
    format(
      'project-request-chat:%s:profile:%s',
      current_setting('test.request_chat_chat'),
      'd1100000-0000-4000-8000-000000000002'
    )
  ),
  true,
  'the requester can receive their exact private topic'
);
select is(
  private.profile_can_receive_project_join_request_chat_topic(
    format(
      'project-request-chat:%s:profile:%s',
      current_setting('test.request_chat_chat'),
      'd1100000-0000-4000-8000-000000000003'
    )
  ),
  false,
  'a requester cannot forge another profile suffix'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select *
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000003',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The participation-request chat is unavailable.',
  'missing and unauthorized exact request IDs fail identically'
);
select throws_ok(
  format(
    $query$
      select *
      from public.get_own_project_join_request_chat(
        'd1100000-0000-4000-8000-000000000003',
        %L::uuid
      )
    $query$,
    current_setting('test.request_chat_request')
  ),
  '42501',
  'The participation-request chat is unavailable.',
  'an unrelated profile cannot resolve the exact chat'
);
select throws_ok(
  format(
    $query$
      select *
      from public.list_own_project_join_request_chat_items(
        'd1100000-0000-4000-8000-000000000003',
        %L::uuid,
        20,
        null,
        null,
        null
      )
    $query$,
    current_setting('test.request_chat_chat')
  ),
  '42501',
  'The participation-request chat is unavailable.',
  'an unrelated profile cannot read the chat feed'
);
select throws_ok(
  format(
    $query$
      select *
      from public.send_project_join_request_chat_message(
        'd1100000-0000-4000-8000-000000000003',
        %L::uuid,
        'Forbidden'
      )
    $query$,
    current_setting('test.request_chat_chat')
  ),
  '42501',
  'The participation-request chat is unavailable.',
  'an unrelated profile cannot send'
);
reset role;
select is(
  private.profile_can_receive_project_join_request_chat_topic(
    format(
      'project-request-chat:%s:profile:%s',
      current_setting('test.request_chat_chat'),
      'd1100000-0000-4000-8000-000000000003'
    )
  ),
  false,
  'an unrelated profile cannot receive its otherwise canonical topic'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select *
    from public.send_project_join_request_chat_message(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_chat')::uuid,
      '   '
    )
  $$,
  '22023',
  'A participation-request chat message cannot be empty.',
  'whitespace-only human messages are rejected'
);
select throws_ok(
  $$
    select *
    from public.send_project_join_request_chat_message(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_chat')::uuid,
      repeat('x', 4001)
    )
  $$,
  '22023',
  'A participation-request chat message cannot exceed 4,000 characters.',
  'oversized human messages are rejected'
);
select set_config(
  'test.request_chat_message_one',
  (
    select sent.message_id::text
    from public.send_project_join_request_chat_message(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_chat')::uuid,
      '  Requester says hello  '
    ) as sent
    where sent.body = 'Requester says hello'
  ),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.request_chat_message_two',
  (
    select sent.message_id::text
    from public.send_project_join_request_chat_message(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_chat')::uuid,
      'Creator replies'
    ) as sent
  ),
  true
);
select results_eq(
  $$
    select exact.viewer_role, exact.has_send_entitlement
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_request')::uuid
    ) as exact
  $$,
  $$values ('creator'::text, true)$$,
  'the Project creator is the other writable counterparty'
);
reset role;
select is(
  private.profile_can_receive_project_join_request_chat_topic(
    format(
      'project-request-chat:%s:profile:%s',
      current_setting('test.request_chat_chat'),
      'd1100000-0000-4000-8000-000000000001'
    )
  ),
  true,
  'the Project creator can receive their exact private topic'
);

set local role authenticated;
select is(
  (
    select count(*)
    from public.list_own_project_join_request_chat_items(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_chat')::uuid,
      20,
      null,
      null,
      null
    )
  ),
  3::bigint,
  'the mixed feed contains one Request item and two human messages'
);
select is(
  (
    select bool_and(
      case item.item_kind
        when 'request' then
          item.message_id is null
          and item.sender_profile_id is null
          and item.sender_display_name is null
          and item.body is null
          and item.project_id is not null
          and item.request_status is not null
        when 'message' then
          item.message_id = item.item_id
          and item.sender_profile_id is not null
          and item.sender_display_name is not null
          and item.body is not null
          and item.project_id is null
          and item.request_status is null
          and item.request_message is null
        else false
      end
    )
    from public.list_own_project_join_request_chat_items(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_chat')::uuid,
      20,
      null,
      null,
      null
    ) as item
  ),
  true,
  'every feed row satisfies the Request/message discriminator XOR'
);
select results_eq(
  format(
    $query$
      with first_page as (
        select *
        from public.list_own_project_join_request_chat_items(
          'd1100000-0000-4000-8000-000000000001',
          %L::uuid,
          1,
          null,
          null,
          null
        )
      )
      select count(*)
      from first_page
      cross join lateral public.list_own_project_join_request_chat_items(
        'd1100000-0000-4000-8000-000000000001',
        %L::uuid,
        20,
        first_page.created_at,
        first_page.item_kind,
        first_page.item_id
      ) as later_page
      where later_page.item_id <> first_page.item_id
    $query$,
    current_setting('test.request_chat_chat'),
    current_setting('test.request_chat_chat')
  ),
  $$values (2::bigint)$$,
  'the complete keyset cursor continues without repeating the boundary item'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.join_request_chat_message_sent'
      and payload ?& array[
        'chat_id',
        'request_id',
        'project_id',
        'project_kind',
        'message_id',
        'sender_profile_id'
      ]
      and (select count(*) from jsonb_object_keys(payload)) = 6
      and payload::text not like '%Requester says hello%'
      and payload::text not like '%Creator replies%'
  ),
  2::bigint,
  'durable events contain identifiers only and never message bodies'
);
select is(
  (
    select count(*)
    from realtime.messages
    where extension = 'broadcast'
      and event = 'project.join_request_chat_message_sent'
      and payload ?& array['id', 'chat_id', 'request_id', 'message_id', 'created_at']
      and (select count(*) from jsonb_object_keys(payload)) = 5
      and payload::text not like '%Requester says hello%'
      and payload::text not like '%Creator replies%'
  ),
  4::bigint,
  'private Realtime fan-out writes one identifier-only hint per counterparty'
);
select throws_ok(
  format(
    'update public.project_join_request_chat_messages set body = %L where id = %L::uuid',
    'Changed',
    current_setting('test.request_chat_message_one')
  ),
  '55000',
  'Project participation-request chat messages are immutable.',
  'human messages cannot be updated'
);
select throws_ok(
  format(
    'delete from public.project_join_request_chat_messages where id = %L::uuid',
    current_setting('test.request_chat_message_one')
  ),
  '55000',
  'Project participation-request chat messages are immutable.',
  'human messages cannot be deleted'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.request_chat_membership',
  public.accept_project_join_request(
    'd1100000-0000-4000-8000-000000000001',
    current_setting('test.request_chat_request')::uuid,
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    array['d1300000-0000-4000-8000-000000000001'::uuid],
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);
select results_eq(
  $$
    select
      exact.request_status,
      exact.is_read_only,
      exact.has_send_entitlement,
      exact.accepted_project_group_chat_id is not null
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_request')::uuid
    ) as exact
  $$,
  $$values ('accepted'::text, true, false, true)$$,
  'acceptance makes this episode read-only and exposes its separate group chat'
);
select throws_ok(
  format(
    $query$
      select *
      from public.send_project_join_request_chat_message(
        'd1100000-0000-4000-8000-000000000001',
        %L::uuid,
        'Too late'
      )
    $query$,
    current_setting('test.request_chat_chat')
  ),
  'PT409',
  'The participation-request chat is read-only because the request is resolved.',
  'resolved request chats reject further sends'
);
select is(
  (
    select count(*)
    from public.list_own_project_join_request_chat_items(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_chat')::uuid,
      20,
      null,
      null,
      null
    )
  ),
  3::bigint,
  'resolved history remains readable without losing messages'
);
select results_eq(
  $$
    select item.request_status
    from public.list_own_project_join_request_chat_items(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_chat')::uuid,
      20,
      null,
      null,
      null
    ) as item
    where item.item_kind = 'request'
  $$,
  $$values ('accepted'::text)$$,
  'the structured Request feed item reflects canonical resolved status'
);

select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000002',
  true
);
select public.leave_project(
  'd1100000-0000-4000-8000-000000000002',
  current_setting('test.request_chat_membership')::uuid
);
select set_config(
  'test.request_chat_second_request',
  public.request_to_join_project(
    'd1100000-0000-4000-8000-000000000002',
    'd1200000-0000-4000-8000-000000000001',
    null,
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);
select public.withdraw_project_join_request(
  'd1100000-0000-4000-8000-000000000002',
  current_setting('test.request_chat_second_request')::uuid
);
select set_config(
  'test.request_chat_second_chat',
  (
    select exact.chat_id::text
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_second_request')::uuid
    ) as exact
  ),
  true
);
select results_eq(
  $$
    select
      exact.chat_id <> current_setting('test.request_chat_chat')::uuid,
      exact.request_status,
      exact.request_message is null,
      exact.is_read_only,
      exact.has_send_entitlement
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_second_request')::uuid
    ) as exact
  $$,
  $$values (true, 'withdrawn'::text, true, true, false)$$,
  'a later participation episode owns a distinct permanent read-only chat'
);
select is(
  (
    select count(*)
    from public.list_own_project_join_request_chat_items(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_second_chat')::uuid,
      20,
      null,
      null,
      null
    ) as item
    where item.item_kind = 'request'
      and item.request_message is null
  ),
  1::bigint,
  'a null-note episode still has exactly one structured Request item'
);
select throws_ok(
  format(
    $query$
      select *
      from public.send_project_join_request_chat_message(
        'd1100000-0000-4000-8000-000000000002',
        %L::uuid,
        'Too late after withdrawal'
      )
    $query$,
    current_setting('test.request_chat_second_chat')
  ),
  'PT409',
  'The participation-request chat is read-only because the request is resolved.',
  'withdrawn request chats reject further sends'
);

select set_config(
  'test.request_chat_third_request',
  public.request_to_join_project(
    'd1100000-0000-4000-8000-000000000002',
    'd1200000-0000-4000-8000-000000000001',
    null,
    '{}'::uuid[],
    '{}'::uuid[]
  )::text,
  true
);
select set_config(
  'test.request_chat_third_chat',
  (
    select exact.chat_id::text
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000002',
      current_setting('test.request_chat_third_request')::uuid
    ) as exact
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  'd1100000-0000-4000-8000-000000000001',
  true
);
select public.reject_project_join_request(
  'd1100000-0000-4000-8000-000000000001',
  current_setting('test.request_chat_third_request')::uuid
);
select results_eq(
  $$
    select exact.request_status, exact.is_read_only, exact.has_send_entitlement
    from public.get_own_project_join_request_chat(
      'd1100000-0000-4000-8000-000000000001',
      current_setting('test.request_chat_third_request')::uuid
    ) as exact
  $$,
  $$values ('rejected'::text, true, false)$$,
  'rejection preserves exact read-only conversation history'
);
select throws_ok(
  format(
    $query$
      select *
      from public.send_project_join_request_chat_message(
        'd1100000-0000-4000-8000-000000000001',
        %L::uuid,
        'Too late after rejection'
      )
    $query$,
    current_setting('test.request_chat_third_chat')
  ),
  'PT409',
  'The participation-request chat is read-only because the request is resolved.',
  'rejected request chats reject further sends'
);

select * from finish();

rollback;
