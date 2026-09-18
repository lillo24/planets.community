begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b1100000-0000-4000-8000-000000000001', 'resurface-owner@planets.invalid'),
  ('b1100000-0000-4000-8000-000000000002', 'resurface-current@planets.invalid'),
  ('b1100000-0000-4000-8000-000000000003', 'resurface-former@planets.invalid'),
  ('b1100000-0000-4000-8000-000000000004', 'resurface-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('b1100000-0000-4000-8000-000000000001', 'Resurface Owner'),
  ('b1100000-0000-4000-8000-000000000002', 'Resurface Current'),
  ('b1100000-0000-4000-8000-000000000003', 'Resurface Former'),
  ('b1100000-0000-4000-8000-000000000004', 'Resurface Unrelated');

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
    'b1200000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000001',
    'published',
    'Resurfacing mixed feed',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    'Europe/Rome',
    statement_timestamp() - interval '1 day'
  ),
  (
    'b1200000-0000-4000-8000-000000000002',
    'b1100000-0000-4000-8000-000000000001',
    'published',
    'Resurfacing attention',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    'Europe/Rome',
    statement_timestamp() - interval '1 day'
  ),
  (
    'b1200000-0000-4000-8000-000000000003',
    'b1100000-0000-4000-8000-000000000001',
    'published',
    'Resurfacing without chat',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    'Europe/Rome',
    statement_timestamp() - interval '1 day'
  );

insert into public.proposal_skills (proposal_id, skill_id, importance)
values (
  'b1200000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8001-000000000001',
  'required'
);

insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at
)
values
  (
    'b1300000-0000-4000-8000-000000000001',
    'b1200000-0000-4000-8000-000000000001',
    'Mixed feed paint',
    'open',
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    'b1300000-0000-4000-8000-000000000002',
    'b1200000-0000-4000-8000-000000000001',
    'Former member ladder',
    'open',
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    'b1300000-0000-4000-8000-000000000003',
    'b1200000-0000-4000-8000-000000000002',
    'Attention first need',
    'open',
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    'b1300000-0000-4000-8000-000000000004',
    'b1200000-0000-4000-8000-000000000002',
    'Attention closeable need',
    'open',
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    'b1300000-0000-4000-8000-000000000005',
    'b1200000-0000-4000-8000-000000000002',
    'Attention project-end need',
    'open',
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    'b1300000-0000-4000-8000-000000000006',
    'b1200000-0000-4000-8000-000000000003',
    'No chat need',
    'open',
    statement_timestamp(),
    statement_timestamp()
  );

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id
)
values
  (
    'b1400000-0000-4000-8000-000000000001',
    'b1200000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000002'
  ),
  (
    'b1400000-0000-4000-8000-000000000002',
    'b1200000-0000-4000-8000-000000000001',
    'b1100000-0000-4000-8000-000000000003'
  ),
  (
    'b1400000-0000-4000-8000-000000000003',
    'b1200000-0000-4000-8000-000000000002',
    'b1100000-0000-4000-8000-000000000002'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.resurface_current_membership',
  public.accept_project_join_request(
    'b1100000-0000-4000-8000-000000000001',
    'b1400000-0000-4000-8000-000000000001'
  )::text,
  true
);
select set_config(
  'test.resurface_former_membership',
  public.accept_project_join_request(
    'b1100000-0000-4000-8000-000000000001',
    'b1400000-0000-4000-8000-000000000002'
  )::text,
  true
);
select set_config(
  'test.attention_membership',
  public.accept_project_join_request(
    'b1100000-0000-4000-8000-000000000001',
    'b1400000-0000-4000-8000-000000000003'
  )::text,
  true
);
reset role;

select set_config(
  'test.resurface_chat_id',
  (
    select chat.id::text
    from public.project_group_chats as chat
    where chat.project_id = 'b1200000-0000-4000-8000-000000000001'
  ),
  true
);
select set_config(
  'test.attention_chat_id',
  (
    select chat.id::text
    from public.project_group_chats as chat
    where chat.project_id = 'b1200000-0000-4000-8000-000000000002'
  ),
  true
);

set local role anon;
select throws_ok(
  $$
    select * from public.list_own_project_chat_feed(
      null,
      null,
      20,
      null,
      null,
      null
    )
  $$,
  '42501',
  'permission denied for function list_own_project_chat_feed',
  'anonymous profiles cannot read the mixed feed'
);
select throws_ok(
  $$
    select * from public.get_own_project_requirement_attention(null, null)
  $$,
  '42501',
  'permission denied for function get_own_project_requirement_attention',
  'anonymous profiles cannot read current attention'
);
select throws_ok(
  $$
    select public.acknowledge_project_requirement_attention(null, null, null)
  $$,
  '42501',
  'permission denied for function acknowledge_project_requirement_attention',
  'anonymous profiles cannot acknowledge current attention'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.resurface_human_message',
  (
    select message_id::text
    from public.send_project_chat_message(
      'b1100000-0000-4000-8000-000000000001',
      current_setting('test.resurface_chat_id')::uuid,
      'Human preview stays human'
    )
  ),
  true
);
reset role;

select is(
  (
    select summary.activity_at
    from public.list_own_project_group_chats(
      'b1100000-0000-4000-8000-000000000001',
      20,
      null,
      null
    ) as summary
    where summary.chat_id = current_setting('test.resurface_chat_id')::uuid
  ),
  (
    select message.created_at
    from public.project_chat_messages as message
    where message.id = current_setting('test.resurface_human_message')::uuid
  ),
  'human-message activity remains the chat-list activity before a system item'
);
select results_eq(
  $$
    select
      event.event_type,
      event.payload ? 'body' as has_body,
      event.payload ? 'message_id' as has_message_id
    from private.outbox_events as event
    where event.event_type = 'project.chat_message_sent'
      and event.payload ->> 'message_id'
        = current_setting('test.resurface_human_message')
  $$,
  $$values ('project.chat_message_sent'::text, false, true)$$,
  'the existing human send still emits its identifier-only message event'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000001',
  'resource',
  'b1300000-0000-4000-8000-000000000001',
  true
);
reset role;

select is(
  (
    select count(*)
    from public.project_chat_system_events as event
    where event.chat_id = current_setting('test.resurface_chat_id')::uuid
  ),
  0::bigint,
  'a covered transition creates no durable chat system item'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000001',
  'resource',
  'b1300000-0000-4000-8000-000000000001',
  false
);
reset role;

select set_config(
  'test.resurface_event_one',
  (
    select event.id::text
    from public.project_chat_system_events as event
    where event.chat_id = current_setting('test.resurface_chat_id')::uuid
      and event.resource_need_id =
        'b1300000-0000-4000-8000-000000000001'
  ),
  true
);

select is(
  (
    select count(*)
    from public.project_chat_system_events as event
    where event.id = current_setting('test.resurface_event_one')::uuid
  ),
  1::bigint,
  'one needed-again transition with a chat creates exactly one system item'
);
select results_eq(
  $$
    select
      source.event_type,
      source.payload ->> 'project_id',
      source.payload ->> 'requirement_kind',
      source.payload ->> 'requirement_id',
      source.created_at = event.created_at
    from public.project_chat_system_events as event
    join private.outbox_events as source
      on source.id = event.source_outbox_event_id
    where event.id = current_setting('test.resurface_event_one')::uuid
  $$,
  $$values (
    'project.requirement_needed_again'::text,
    'b1200000-0000-4000-8000-000000000001'::text,
    'resource'::text,
    'b1300000-0000-4000-8000-000000000001'::text,
    true
  )$$,
  'system history retains exact identifier provenance and canonical transition time'
);

select throws_ok(
  $$
    insert into public.project_chat_system_events (
      chat_id,
      event_kind,
      requirement_kind,
      resource_need_id,
      source_outbox_event_id,
      created_at
    )
    select
      event.chat_id,
      event.event_kind,
      event.requirement_kind,
      event.resource_need_id,
      event.source_outbox_event_id,
      event.created_at
    from public.project_chat_system_events as event
    where event.id = current_setting('test.resurface_event_one')::uuid
  $$,
  '23505',
  'duplicate key value violates unique constraint "project_chat_system_events_source_outbox_event_id_key"',
  'replaying one source outbox transition cannot duplicate system history'
);
select throws_ok(
  $$
    update public.project_chat_system_events
    set event_kind = event_kind
    where id = current_setting('test.resurface_event_one')::uuid
  $$,
  '55000',
  'Project chat system events are immutable.',
  'system events cannot be updated'
);
select throws_ok(
  $$
    delete from public.project_chat_system_events
    where id = current_setting('test.resurface_event_one')::uuid
  $$,
  '55000',
  'Project chat system events are immutable.',
  'system events cannot be deleted'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000003',
  'resource',
  'b1300000-0000-4000-8000-000000000006',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000003',
  'resource',
  'b1300000-0000-4000-8000-000000000006',
  false
);
reset role;

select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'project.requirement_needed_again'
      and event.payload ->> 'project_id'
        = 'b1200000-0000-4000-8000-000000000003'
  ),
  1::bigint,
  'a no-chat Project retains its canonical needed-again outbox transition'
);
select is(
  (
    select count(*)
    from public.project_group_chats as chat
    where chat.project_id = 'b1200000-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'a requirement transition never creates a chat anchor'
);
select is(
  (
    select count(*)
    from public.project_chat_system_events as event
    join public.project_group_chats as chat on chat.id = event.chat_id
    where chat.project_id = 'b1200000-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'a no-chat transition creates no structured chat history'
);

update public.project_resource_needs
set
  title = 'Current canonical paint label',
  updated_at = statement_timestamp()
where id = 'b1300000-0000-4000-8000-000000000001';

insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
select
  'b1500000-0000-4000-8000-000000000001',
  event.chat_id,
  'b1100000-0000-4000-8000-000000000001',
  'Equal timestamp human',
  event.created_at
from public.project_chat_system_events as event
where event.id = current_setting('test.resurface_event_one')::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select feed.item_kind, feed.item_id
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000001',
      current_setting('test.resurface_chat_id')::uuid,
      20,
      null,
      null,
      null
    ) as feed
    where feed.created_at = (
      select event.created_at
      from public.project_chat_system_events as event
      where event.id = current_setting('test.resurface_event_one')::uuid
    )
  $$,
  $$values
    ('message'::text, 'b1500000-0000-4000-8000-000000000001'::uuid),
    (
      'system_requirement_needed_again'::text,
      current_setting('test.resurface_event_one')::uuid
    )
  $$,
  'equal timestamps use the explicit message-before-system tie-break'
);
select results_eq(
  $$
    select feed.item_kind, feed.item_id
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000001',
      current_setting('test.resurface_chat_id')::uuid,
      1,
      (
        select event.created_at
        from public.project_chat_system_events as event
        where event.id = current_setting('test.resurface_event_one')::uuid
      ),
      'message',
      'b1500000-0000-4000-8000-000000000001'
    ) as feed
  $$,
  $$values (
    'system_requirement_needed_again'::text,
    current_setting('test.resurface_event_one')::uuid
  )$$,
  'a keyset page boundary crosses item kinds without losing the next item'
);
select results_eq(
  $$
    select
      feed.requirement_kind,
      feed.requirement_id,
      feed.requirement_label
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000001',
      current_setting('test.resurface_chat_id')::uuid,
      20,
      null,
      null,
      null
    ) as feed
    where feed.item_id = current_setting('test.resurface_event_one')::uuid
  $$,
  $$values (
    'resource'::text,
    'b1300000-0000-4000-8000-000000000001'::uuid,
    'Current canonical paint label'::text
  )$$,
  'historical system items resolve the current canonical requirement label'
);
select is(
  (
    select bool_and(
      (
        feed.item_kind = 'message'
        and feed.sender_profile_id is not null
        and feed.sender_display_name is not null
        and feed.body is not null
        and feed.system_event_kind is null
        and feed.requirement_kind is null
        and feed.requirement_id is null
        and feed.requirement_label is null
      )
      or (
        feed.item_kind = 'system_requirement_needed_again'
        and feed.sender_profile_id is null
        and feed.sender_display_name is null
        and feed.body is null
        and feed.system_event_kind = 'requirement_needed_again'
        and feed.requirement_kind is not null
        and feed.requirement_id is not null
        and feed.requirement_label is not null
      )
    )
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000001',
      current_setting('test.resurface_chat_id')::uuid,
      20,
      null,
      null,
      null
    ) as feed
  ),
  true,
  'every mixed-feed row obeys its strict nullable-column discriminator'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  format(
    'select * from public.list_own_project_chat_feed(%L, %L, 20, null, null, null)',
    'b1100000-0000-4000-8000-000000000004',
    current_setting('test.resurface_chat_id')
  ),
  '42501',
  'The project group chat is unavailable.',
  'an unrelated authenticated profile cannot read mixed history'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000003',
  true
);
select public.claim_project_requirement(
  'b1100000-0000-4000-8000-000000000003',
  'b1200000-0000-4000-8000-000000000001',
  'resource',
  'b1300000-0000-4000-8000-000000000002'
);
select public.leave_project(
  'b1100000-0000-4000-8000-000000000003',
  current_setting('test.resurface_former_membership')::uuid
);
reset role;

select set_config(
  'test.resurface_event_after_leave',
  (
    select event.id::text
    from public.project_chat_system_events as event
    where event.chat_id = current_setting('test.resurface_chat_id')::uuid
      and event.resource_need_id =
        'b1300000-0000-4000-8000-000000000002'
  ),
  true
);
select ok(
  (
    select event.created_at > membership.left_at
    from public.project_chat_system_events as event
    cross join public.project_memberships as membership
    where event.id = current_setting('test.resurface_event_after_leave')::uuid
      and membership.id =
        current_setting('test.resurface_former_membership')::uuid
  ),
  'a leave-caused system event is strictly after the membership frontier'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000003',
  true
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000003',
      current_setting('test.resurface_chat_id')::uuid,
      50,
      null,
      null,
      null
    ) as feed
    where feed.item_id =
      current_setting('test.resurface_event_after_leave')::uuid
  ),
  0::bigint,
  'a former member cannot read the system item caused after their leave frontier'
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000003',
      current_setting('test.resurface_chat_id')::uuid,
      50,
      null,
      null,
      null
    ) as feed
    where feed.item_id = current_setting('test.resurface_event_one')::uuid
  ),
  1::bigint,
  'a former member retains system history created before membership end'
);
select ok(
  (
    select summary.activity_at < event.created_at
    from public.list_own_project_group_chats(
      'b1100000-0000-4000-8000-000000000003',
      20,
      null,
      null
    ) as summary
    cross join public.project_chat_system_events as event
    where summary.chat_id = current_setting('test.resurface_chat_id')::uuid
      and event.id = current_setting('test.resurface_event_after_leave')::uuid
  ),
  'post-leave system activity does not move a former member historical chat'
);
select throws_ok(
  $$
    select * from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000003',
      'b1200000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Current Project requirement attention is unavailable.',
  'a former member has no current Needs-attention state'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select
      summary.last_visible_message_body,
      summary.activity_at = event.created_at
    from public.list_own_project_group_chats(
      'b1100000-0000-4000-8000-000000000001',
      20,
      null,
      null
    ) as summary
    join public.project_chat_system_events as event
      on event.id = current_setting('test.resurface_event_after_leave')::uuid
    where summary.chat_id = current_setting('test.resurface_chat_id')::uuid
  $$,
  $$values ('Equal timestamp human'::text, true)$$,
  'system activity moves the creator chat upward without faking the human preview'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000003',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000003',
  false
);
reset role;

select set_config(
  'test.attention_event_a',
  (
    select event.id::text
    from public.project_chat_system_events as event
    where event.chat_id = current_setting('test.attention_chat_id')::uuid
      and event.resource_need_id =
        'b1300000-0000-4000-8000-000000000003'
    order by event.created_at desc, event.id desc
    limit 1
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select
      attention.chat_id,
      attention.has_unseen_resurfaced_need,
      attention.latest_unseen_event_id
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  $$,
  $$values (
    current_setting('test.attention_chat_id')::uuid,
    true,
    current_setting('test.attention_event_a')::uuid
  )$$,
  'an unseen resurfaced requirement that remains uncovered raises attention'
);
select is(
  public.acknowledge_project_requirement_attention(
    'b1100000-0000-4000-8000-000000000002',
    'b1200000-0000-4000-8000-000000000002',
    current_setting('test.attention_event_a')::uuid
  ),
  current_setting('test.attention_event_a')::uuid,
  'attention advances only through the explicit event the member saw'
);
select is(
  (
    select attention.has_unseen_resurfaced_need
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  ),
  false,
  'acknowledging through the latest event clears current attention'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000004',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000004',
  false
);
reset role;

select set_config(
  'test.attention_event_b',
  (
    select event.id::text
    from public.project_chat_system_events as event
    where event.chat_id = current_setting('test.attention_chat_id')::uuid
      and event.resource_need_id =
        'b1300000-0000-4000-8000-000000000004'
    order by event.created_at desc, event.id desc
    limit 1
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.acknowledge_project_requirement_attention(
    'b1100000-0000-4000-8000-000000000002',
    'b1200000-0000-4000-8000-000000000002',
    current_setting('test.attention_event_a')::uuid
  ),
  current_setting('test.attention_event_a')::uuid,
  'a stale acknowledgement cannot move the receipt beyond the supplied frontier'
);
select results_eq(
  $$
    select
      attention.has_unseen_resurfaced_need,
      attention.latest_unseen_event_id
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  $$,
  $$values (true, current_setting('test.attention_event_b')::uuid)$$,
  'a later serialized event remains unseen behind an older explicit frontier'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000004',
  true
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select attention.has_unseen_resurfaced_need
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  ),
  false,
  're-covering a need removes stale attention without deleting history'
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000002',
      current_setting('test.attention_chat_id')::uuid,
      50,
      null,
      null,
      null
    ) as feed
    where feed.item_id = current_setting('test.attention_event_b')::uuid
  ),
  1::bigint,
  're-covering leaves the historical system item in the mixed feed'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000004',
  false
);
select public.close_project_resource_need(
  'b1100000-0000-4000-8000-000000000001',
  'b1300000-0000-4000-8000-000000000004'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select attention.has_unseen_resurfaced_need
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  ),
  false,
  'closing a resource suppresses attention while preserving history'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'skill',
  'd0000000-0000-4000-8001-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'skill',
  'd0000000-0000-4000-8001-000000000001',
  false
);
reset role;

delete from public.proposal_skills
where proposal_id = 'b1200000-0000-4000-8000-000000000002'
  and skill_id = 'd0000000-0000-4000-8001-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select attention.has_unseen_resurfaced_need
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  ),
  false,
  'removing a Proposal skill suppresses stale attention'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000001',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000005',
  true
);
select public.set_project_requirement_manual_coverage(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002',
  'resource',
  'b1300000-0000-4000-8000-000000000005',
  false
);
select public.cancel_proposal(
  'b1100000-0000-4000-8000-000000000001',
  'b1200000-0000-4000-8000-000000000002'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b1100000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select attention.has_unseen_resurfaced_need
    from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000002',
      'b1200000-0000-4000-8000-000000000002'
    ) as attention
  ),
  false,
  'ending the Project lifecycle suppresses current Needs attention'
);
select is(
  (
    select count(*)
    from public.list_own_project_chat_feed(
      'b1100000-0000-4000-8000-000000000002',
      current_setting('test.attention_chat_id')::uuid,
      50,
      null,
      null,
      null
    ) as feed
    where feed.item_kind <> 'system_requirement_needed_again'
  ),
  0::bigint,
  'a chat with no human messages returns system-only history cleanly'
);
select throws_ok(
  $$
    select * from public.get_own_project_requirement_attention(
      'b1100000-0000-4000-8000-000000000001',
      'b1200000-0000-4000-8000-000000000002'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'attention reads reject an expected-profile mismatch'
);
reset role;

select * from finish();

rollback;
