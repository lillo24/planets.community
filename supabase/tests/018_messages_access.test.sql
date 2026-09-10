begin;

select no_plan();

insert into auth.users (id, email)
values
  ('71000000-0000-4000-8000-000000000001', 'messages-creator@planets.invalid'),
  ('72000000-0000-4000-8000-000000000002', 'messages-requester@planets.invalid'),
  ('73000000-0000-4000-8000-000000000003', 'messages-other@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('71000000-0000-4000-8000-000000000001', 'Messages Creator'),
  ('72000000-0000-4000-8000-000000000002', 'Messages Requester'),
  ('73000000-0000-4000-8000-000000000003', 'Messages Other');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at
)
values (
  '74000000-0000-4000-8000-000000000004',
  '71000000-0000-4000-8000-000000000001',
  'published',
  'Messages proposal',
  statement_timestamp() + interval '1 day',
  statement_timestamp() + interval '2 days',
  statement_timestamp() - interval '1 day'
);

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at
)
values (
  '75000000-0000-4000-8000-000000000005',
  '71000000-0000-4000-8000-000000000001',
  'published',
  'Messages Tavolo',
  statement_timestamp() - interval '1 day'
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
    '76000000-0000-4000-8000-000000000001',
    '74000000-0000-4000-8000-000000000004',
    '72000000-0000-4000-8000-000000000002',
    'pending',
    'Private pending proposal request.',
    statement_timestamp() - interval '4 hours',
    null,
    null
  ),
  (
    '76000000-0000-4000-8000-000000000002',
    '74000000-0000-4000-8000-000000000004',
    '72000000-0000-4000-8000-000000000002',
    'accepted',
    'Private accepted proposal request.',
    statement_timestamp() - interval '5 hours',
    statement_timestamp() - interval '1 hour',
    '71000000-0000-4000-8000-000000000001'
  ),
  (
    '76000000-0000-4000-8000-000000000003',
    '75000000-0000-4000-8000-000000000005',
    '72000000-0000-4000-8000-000000000002',
    'rejected',
    null,
    statement_timestamp() - interval '6 hours',
    statement_timestamp() - interval '2 hours',
    '71000000-0000-4000-8000-000000000001'
  ),
  (
    '76000000-0000-4000-8000-000000000004',
    '75000000-0000-4000-8000-000000000005',
    '72000000-0000-4000-8000-000000000002',
    'withdrawn',
    'Private withdrawn Tavolo request.',
    statement_timestamp() - interval '7 hours',
    statement_timestamp() - interval '3 hours',
    '72000000-0000-4000-8000-000000000002'
  );

set local role anon;
select throws_ok(
  $$
    select *
    from public.list_own_participation_request_message_items(null, 20, null, null)
  $$,
  '42501',
  'permission denied for function list_own_participation_request_message_items',
  'anonymous clients cannot invoke the Messages inbox boundary'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '72000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
  ),
  4::bigint,
  'a requester sees all of their proposal and Tavolo request history'
);
select is(
  (
    select count(*)
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as item
    where item.viewer_role = 'requester'
      and item.requester_display_name = 'Messages Requester'
      and item.creator_display_name = 'Messages Creator'
  ),
  4::bigint,
  'outgoing items identify the viewer and both participants'
);
select set_eq(
  $$
    select item.status
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as item
  $$,
  $$ values
    ('pending'::text),
    ('accepted'::text),
    ('rejected'::text),
    ('withdrawn'::text)
  $$,
  'pending and every resolved participation state remain in Messages history'
);
select is(
  (
    select bool_and(
      item.activity_at = coalesce(item.resolved_at, item.created_at)
    )
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as item
  ),
  true,
  'activity chronology uses resolution time with creation time as the pending fallback'
);
select is(
  (
    select item.request_message
    from public.get_own_participation_request_message_item(
      '72000000-0000-4000-8000-000000000002',
      '76000000-0000-4000-8000-000000000001'
    ) as item
  ),
  'Private pending proposal request.',
  'the requester can read their full private request message'
);
select set_eq(
  $$
    select item.project_kind || ':' || item.project_title
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as item
  $$,
  $$ values
    ('one_time:Messages proposal'::text),
    ('recurring:Messages Tavolo'::text)
  $$,
  'Messages resolves both canonical project kinds and titles'
);
select results_eq(
  $$
    with first_page as (
      select *
      from public.list_own_participation_request_message_items(
        '72000000-0000-4000-8000-000000000002',
        2,
        null,
        null
      )
    ), cursor_row as (
      select first_page.activity_at, first_page.request_id
      from first_page
      order by first_page.activity_at desc, first_page.request_id desc
      offset 1
      limit 1
    )
    select item.request_id
    from cursor_row
    cross join lateral public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      2,
      cursor_row.activity_at,
      cursor_row.request_id
    ) as item
  $$,
  $$ values
    ('76000000-0000-4000-8000-000000000004'::uuid),
    ('76000000-0000-4000-8000-000000000001'::uuid)
  $$,
  'the paired cursor returns the next stable page without overlap'
);
select throws_ok(
  $$
    select *
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      0,
      null,
      null
    )
  $$,
  '22023',
  'The message page size must be between 1 and 50.',
  'page size is bounded'
);
select throws_ok(
  $$
    select *
    from public.list_own_participation_request_message_items(
      '72000000-0000-4000-8000-000000000002',
      20,
      statement_timestamp(),
      null
    )
  $$,
  '22023',
  'Both message cursor values must be provided together.',
  'partial cursors fail explicitly'
);
select throws_ok(
  $$
    select *
    from public.list_own_participation_request_message_items(
      '71000000-0000-4000-8000-000000000001',
      20,
      null,
      null
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'cross-account inbox reads fail at the expected-identity boundary'
);

select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.list_own_participation_request_message_items(
      '71000000-0000-4000-8000-000000000001',
      20,
      null,
      null
    ) as item
    where item.viewer_role = 'creator'
  ),
  4::bigint,
  'the creator sees incoming requests across their proposal and Tavolo'
);
select is(
  (
    select item.request_message
    from public.get_own_participation_request_message_item(
      '71000000-0000-4000-8000-000000000001',
      '76000000-0000-4000-8000-000000000001'
    ) as item
  ),
  'Private pending proposal request.',
  'the project creator can read the full private request message'
);

select set_config(
  'request.jwt.claim.sub',
  '73000000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.list_own_participation_request_message_items(
      '73000000-0000-4000-8000-000000000003',
      20,
      null,
      null
    )
  ),
  0::bigint,
  'an unrelated authenticated user sees no participation messages'
);
select throws_ok(
  $$
    select *
    from public.get_own_participation_request_message_item(
      '73000000-0000-4000-8000-000000000003',
      '76000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The participation request message item is unavailable.',
  'an unrelated user cannot probe an existing private request'
);
select throws_ok(
  $$
    select *
    from public.get_own_participation_request_message_item(
      '73000000-0000-4000-8000-000000000003',
      '76000000-0000-4000-8000-000000000099'
    )
  $$,
  '42501',
  'The participation request message item is unavailable.',
  'missing and unauthorized exact lookups fail identically'
);

select * from finish();

rollback;
