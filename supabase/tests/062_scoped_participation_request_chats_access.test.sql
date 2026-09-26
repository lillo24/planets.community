begin;

select no_plan();

insert into auth.users (id, email)
values
  ('e1100000-0000-4000-8000-000000000001', 'scoped-creator@planets.invalid'),
  ('e1100000-0000-4000-8000-000000000002', 'scoped-requester@planets.invalid'),
  ('e1100000-0000-4000-8000-000000000003', 'scoped-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e1100000-0000-4000-8000-000000000001', 'Scoped Creator'),
  ('e1100000-0000-4000-8000-000000000002', 'Scoped Requester'),
  ('e1100000-0000-4000-8000-000000000003', 'Scoped Unrelated');

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
  'e1200000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000001',
  'published',
  'Scoped mural',
  '2098-01-01 10:00+00',
  '2098-01-01 12:00+00',
  'Europe/Rome',
  '2026-09-20 07:00+00'
);

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  request_message,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values
  (
    'e1300000-0000-4000-8000-000000000001',
    'e1200000-0000-4000-8000-000000000001',
    'e1100000-0000-4000-8000-000000000002',
    'accepted',
    'Accepted request fallback',
    '2026-09-20 08:00+00',
    '2026-09-20 09:00+00',
    'e1100000-0000-4000-8000-000000000001'
  ),
  (
    'e1300000-0000-4000-8000-000000000002',
    'e1200000-0000-4000-8000-000000000001',
    'e1100000-0000-4000-8000-000000000003',
    'pending',
    'Pending request fallback',
    '2026-09-20 10:00+00',
    null,
    null
  );

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  'e1400000-0000-4000-8000-000000000001',
  'e1200000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000002',
  'e1300000-0000-4000-8000-000000000001',
  '2026-09-20 09:00+00'
);

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
values (
  'e1500000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000001',
  'exchange',
  'published',
  'Scoped resource',
  'A deterministic resource listing.',
  'IT',
  'Trento',
  'Trento',
  '2026-09-20 07:00+00'
);

insert into public.resource_listing_requests (
  id,
  listing_id,
  requester_profile_id,
  status,
  request_message,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values (
  'e1600000-0000-4000-8000-000000000001',
  'e1500000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000002',
  'accepted',
  'Resource request note',
  '2026-09-20 10:30+00',
  '2026-09-20 11:00+00',
  'e1100000-0000-4000-8000-000000000001'
);

select set_config(
  'test.scoped_resource_agreement',
  private.ensure_resource_exchange_agreement_for_request(
    'e1600000-0000-4000-8000-000000000001',
    'e1100000-0000-4000-8000-000000000001',
    '2026-09-20 11:00+00'
  )::text,
  true
);
select set_config(
  'test.scoped_resource_chat',
  private.ensure_resource_request_chat_for_request(
    'e1600000-0000-4000-8000-000000000001',
    '2026-09-20 11:00+00'
  )::text,
  true
);
select set_config(
  'test.scoped_accepted_chat',
  (
    select chat.id::text
    from public.project_join_request_chats as chat
    where chat.request_id = 'e1300000-0000-4000-8000-000000000001'
  ),
  true
);
select set_config(
  'test.scoped_pending_chat',
  (
    select chat.id::text
    from public.project_join_request_chats as chat
    where chat.request_id = 'e1300000-0000-4000-8000-000000000002'
  ),
  true
);

insert into public.project_join_request_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values (
  'e1700000-0000-4000-8000-000000000001',
  current_setting('test.scoped_pending_chat')::uuid,
  'e1100000-0000-4000-8000-000000000003',
  'Newest private human message',
  '2026-09-20 12:00+00'
);

set local role anon;
select throws_ok(
  $$
    select *
    from public.list_own_scoped_message_chat_items(
      null,
      'private',
      20,
      null,
      null,
      null
    )
  $$,
  '42501',
  'permission denied for function list_own_scoped_message_chat_items',
  'anonymous clients cannot discover scoped private chats'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1100000-0000-4000-8000-000000000001',
  true
);

select results_eq(
  $$
    select item_kind
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000001',
      'groups',
      20,
      null,
      null,
      null
    )
  $$,
  $$values ('project_chat'::text)$$,
  'Groups contains only Project group chats'
);

select results_eq(
  $$
    select item_kind
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000001',
      'private',
      20,
      null,
      null,
      null
    )
    order by item_kind
  $$,
  $$values
    ('project_request_chat'::text),
    ('project_request_chat'::text),
    ('resource_chat'::text)
  $$,
  'Private contains participation-request and Resource conversations only'
);

select is(
  (
    select bool_and(
      case item.item_kind
        when 'project_chat' then
          item.project_id is not null
          and item.project_kind is not null
          and item.resource_request_id is null
          and item.project_request_id is null
        when 'resource_chat' then
          item.project_id is null
          and item.resource_request_id is not null
          and item.project_request_id is null
        when 'project_request_chat' then
          item.project_id is null
          and item.resource_request_id is null
          and item.project_request_id is not null
          and item.project_request_project_id is not null
          and item.project_request_counterparty_profile_id is not null
        else false
      end
    )
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000001',
      'all',
      20,
      null,
      null,
      null
    ) as item
  ),
  true,
  'all chat discriminator branches satisfy strict XOR shapes'
);

select results_eq(
  $$
    select
      project_request_id,
      viewer_role,
      is_read_only,
      last_visible_message_body,
      project_request_message,
      project_request_counterparty_display_name
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000001',
      'private',
      20,
      null,
      null,
      null
    )
    where project_request_id = 'e1300000-0000-4000-8000-000000000002'
  $$,
  $$values (
    'e1300000-0000-4000-8000-000000000002'::uuid,
    'creator'::text,
    false,
    'Newest private human message'::text,
    'Pending request fallback'::text,
    'Scoped Unrelated'::text
  )$$,
  'pending request chat prefers the newest human preview and exposes its safe note fallback'
);

select results_eq(
  $$
    select
      is_read_only,
      last_visible_message_id is null,
      project_request_message,
      accepted_project_group_chat_id is not null
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000001',
      'private',
      20,
      null,
      null,
      null
    )
    where project_request_id = 'e1300000-0000-4000-8000-000000000001'
  $$,
  $$values (true, true, 'Accepted request fallback'::text, true)$$,
  'resolved request chat is read-only and retains a structured-note fallback plus group handoff'
);

select is(
  (
    with first_page as (
      select *
      from public.list_own_scoped_message_chat_items(
        'e1100000-0000-4000-8000-000000000001',
        'private',
        1,
        null,
        null,
        null
      )
    )
    select count(*)
    from first_page
    cross join lateral public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000001',
      'private',
      20,
      first_page.activity_at,
      first_page.item_kind,
      first_page.chat_id
    ) as later
    where later.chat_id <> first_page.chat_id
  ),
  2::bigint,
  'Private keyset pagination continues without hiding or repeating another private kind'
);

select set_config(
  'request.jwt.claim.sub',
  'e1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000002',
      'private',
      20,
      null,
      null,
      null
    )
    where project_request_id = 'e1300000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'the requester can discover their own participation-request conversation'
);

select set_config(
  'request.jwt.claim.sub',
  'e1100000-0000-4000-8000-000000000003',
  true
);
select results_eq(
  $$
    select project_request_id, viewer_role
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000003',
      'private',
      20,
      null,
      null,
      null
    )
  $$,
  $$values (
    'e1300000-0000-4000-8000-000000000002'::uuid,
    'requester'::text
  )$$,
  'an unrelated profile sees only the request episode where they are the requester'
);

select throws_ok(
  $$
    select *
    from public.list_own_scoped_message_chat_items(
      'e1100000-0000-4000-8000-000000000003',
      'groups',
      20,
      '2026-09-20 12:00+00',
      'resource_chat',
      'e1600000-0000-4000-8000-000000000001'
    )
  $$,
  '22023',
  'The unified chat cursor item kind is unsupported for this scope.',
  'scope-mismatched cursors fail instead of silently skipping rows'
);

select * from finish();

rollback;
