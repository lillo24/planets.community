begin;

select no_plan();

insert into auth.users (id, email)
values
  ('c1100000-0000-4000-8000-000000000001', 'chat-ambiguity-owner@planets.invalid'),
  ('c1100000-0000-4000-8000-000000000002', 'chat-ambiguity-member@planets.invalid'),
  ('c1100000-0000-4000-8000-000000000003', 'chat-ambiguity-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('c1100000-0000-4000-8000-000000000001', 'Chat Ambiguity Owner'),
  ('c1100000-0000-4000-8000-000000000002', 'Chat Ambiguity Member'),
  ('c1100000-0000-4000-8000-000000000003', 'Chat Ambiguity Unrelated');

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
  'c1200000-0000-4000-8000-000000000001',
  'c1100000-0000-4000-8000-000000000001',
  'published',
  'Project chat ambiguity regression',
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
  'c1300000-0000-4000-8000-000000000001',
  'c1200000-0000-4000-8000-000000000001',
  'Regression paint',
  'open',
  statement_timestamp(),
  statement_timestamp()
);

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id
)
values (
  'c1400000-0000-4000-8000-000000000001',
  'c1200000-0000-4000-8000-000000000001',
  'c1100000-0000-4000-8000-000000000002'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000001',
  true
);
select public.accept_project_join_request(
  'c1100000-0000-4000-8000-000000000001',
  'c1400000-0000-4000-8000-000000000001'
);
reset role;

select set_config(
  'test.chat_ambiguity_chat_id',
  (
    select chat.id::text
    from public.project_group_chats as chat
    where chat.project_id = 'c1200000-0000-4000-8000-000000000001'
  ),
  true
);

select isnt(
  current_setting('test.chat_ambiguity_chat_id', true),
  null,
  'acceptance creates the canonical Project chat fixture'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000001',
  true
);
select public.send_project_chat_message(
  'c1100000-0000-4000-8000-000000000001',
  current_setting('test.chat_ambiguity_chat_id')::uuid,
  'Owner regression message'
);
select lives_ok(
  $$
    select public.set_project_requirement_manual_coverage(
      'c1100000-0000-4000-8000-000000000001',
      'c1200000-0000-4000-8000-000000000001',
      'resource',
      'c1300000-0000-4000-8000-000000000001',
      true
    )
  $$,
  'covering a requirement does not hit the local chat_id ambiguity'
);
select lives_ok(
  $$
    select public.set_project_requirement_manual_coverage(
      'c1100000-0000-4000-8000-000000000001',
      'c1200000-0000-4000-8000-000000000001',
      'resource',
      'c1300000-0000-4000-8000-000000000001',
      false
    )
  $$,
  'resurfacing a requirement records its system event without 42702'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000002',
  true
);
select public.send_project_chat_message(
  'c1100000-0000-4000-8000-000000000002',
  current_setting('test.chat_ambiguity_chat_id')::uuid,
  'Member regression message'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_feed(
      'c1100000-0000-4000-8000-000000000001',
      current_setting('test.chat_ambiguity_chat_id')::uuid,
      20,
      null,
      null,
      null
    )
  ),
  3::bigint,
  'the creator can load the mixed Project chat feed without 42702'
);
select results_eq(
  $$
    select feed.sender_display_name, feed.body
    from public.list_own_project_chat_feed(
      'c1100000-0000-4000-8000-000000000001',
      current_setting('test.chat_ambiguity_chat_id')::uuid,
      20,
      null,
      null,
      null
    ) as feed
    where feed.item_kind = 'message'
    order by feed.body
  $$,
  $$values
    ('Chat Ambiguity Member'::text, 'Member regression message'::text),
    ('Chat Ambiguity Owner'::text, 'Owner regression message'::text)
  $$,
  'human feed rows retain sender and body parsing'
);
select results_eq(
  $$
    select
      feed.item_kind,
      feed.system_event_kind,
      feed.requirement_kind,
      feed.requirement_id,
      feed.requirement_label
    from public.list_own_project_chat_feed(
      'c1100000-0000-4000-8000-000000000001',
      current_setting('test.chat_ambiguity_chat_id')::uuid,
      20,
      null,
      null,
      null
    ) as feed
    where feed.item_kind = 'system_requirement_needed_again'
  $$,
  $$values (
    'system_requirement_needed_again'::text,
    'requirement_needed_again'::text,
    'resource'::text,
    'c1300000-0000-4000-8000-000000000001'::uuid,
    'Regression paint'::text
  )$$,
  'the coverage transition remains a structured Project chat system row'
);
select is(
  (
    with head as (
      select feed.*
      from public.list_own_project_chat_feed(
        'c1100000-0000-4000-8000-000000000001',
        current_setting('test.chat_ambiguity_chat_id')::uuid,
        1,
        null,
        null,
        null
      ) as feed
    )
    select count(*)
    from head
    cross join lateral public.list_own_project_chat_feed(
      'c1100000-0000-4000-8000-000000000001',
      current_setting('test.chat_ambiguity_chat_id')::uuid,
      20,
      head.created_at,
      head.item_kind,
      head.item_id
    ) as page
  ),
  2::bigint,
  'the complete mixed-feed cursor resumes after the newest item'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_own_project_group_chats(
      'c1100000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as chat
    where chat.chat_id = current_setting('test.chat_ambiguity_chat_id')::uuid
  ),
  1::bigint,
  'the accepted participant can list the Project chat'
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_feed(
      'c1100000-0000-4000-8000-000000000002',
      current_setting('test.chat_ambiguity_chat_id')::uuid,
      20,
      null,
      null,
      null
    )
  ),
  3::bigint,
  'the accepted participant can load the authorized mixed feed'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  format(
    'select * from public.list_own_project_chat_feed(%L, %L, 20, null, null, null)',
    'c1100000-0000-4000-8000-000000000003',
    current_setting('test.chat_ambiguity_chat_id')
  ),
  '42501',
  'The project group chat is unavailable.',
  'an unrelated authenticated profile remains denied'
);
reset role;

select * from finish();
rollback;
