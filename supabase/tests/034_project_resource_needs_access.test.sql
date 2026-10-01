begin;

select no_plan();

insert into auth.users (id, email)
values
  ('e1000000-0000-4000-8000-000000000001', 'needs-owner@planets.invalid'),
  ('e2000000-0000-4000-8000-000000000002', 'needs-other@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e1000000-0000-4000-8000-000000000001', 'Needs Owner'),
  ('e2000000-0000-4000-8000-000000000002', 'Needs Other');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at,
  cancelled_at
)
values
  (
    'f1000000-0000-4000-8000-000000000001',
    'e1000000-0000-4000-8000-000000000001',
    'draft',
    'Draft needs project',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    null,
    null
  ),
  (
    'f2000000-0000-4000-8000-000000000002',
    'e1000000-0000-4000-8000-000000000001',
    'published',
    'Upcoming needs project',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'f3000000-0000-4000-8000-000000000003',
    'e1000000-0000-4000-8000-000000000001',
    'published',
    'Started needs project',
    statement_timestamp() - interval '1 hour',
    statement_timestamp() + interval '2 hours',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'f4000000-0000-4000-8000-000000000004',
    'e1000000-0000-4000-8000-000000000001',
    'published',
    'Expired needs project',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day',
    statement_timestamp() - interval '3 days',
    null
  ),
  (
    'f5000000-0000-4000-8000-000000000005',
    'e1000000-0000-4000-8000-000000000001',
    'cancelled',
    'Cancelled needs project',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day'
  );

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at,
  paused_at,
  ended_at
)
values
  (
    'd1000000-0000-4000-8000-000000000001',
    'e1000000-0000-4000-8000-000000000001',
    'draft',
    'Draft Tavolo needs',
    null,
    null,
    null
  ),
  (
    'd2000000-0000-4000-8000-000000000002',
    'e1000000-0000-4000-8000-000000000001',
    'published',
    'Published Tavolo needs',
    statement_timestamp() - interval '1 day',
    null,
    null
  ),
  (
    'd3000000-0000-4000-8000-000000000003',
    'e1000000-0000-4000-8000-000000000001',
    'paused',
    'Paused Tavolo needs',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day',
    null
  ),
  (
    'd4000000-0000-4000-8000-000000000004',
    'e1000000-0000-4000-8000-000000000001',
    'ended',
    'Ended Tavolo needs',
    statement_timestamp() - interval '2 days',
    null,
    statement_timestamp() - interval '1 day'
  );

insert into public.project_resource_needs (
  id,
  project_id,
  title,
  details
)
values
  (
    'a3000000-0000-4000-8000-000000000003',
    'f3000000-0000-4000-8000-000000000003',
    'Started-project ladder',
    null
  ),
  (
    'a4000000-0000-4000-8000-000000000004',
    'f4000000-0000-4000-8000-000000000004',
    'Expired-project boards',
    null
  ),
  (
    'a5000000-0000-4000-8000-000000000005',
    'f5000000-0000-4000-8000-000000000005',
    'Cancelled-project paint',
    null
  ),
  (
    'a6000000-0000-4000-8000-000000000006',
    'd4000000-0000-4000-8000-000000000004',
    'Ended-Tavolo van',
    null
  );

set local role anon;

select throws_ok(
  $$select id from public.project_resource_needs$$,
  '42501',
  'permission denied for table project_resource_needs',
  'anonymous users cannot read resource needs directly'
);
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'f1000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'draft Proposal needs are not public'
);
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      '00000000-0000-4000-8000-000000000099'
    )
  ),
  0::bigint,
  'a missing Project returns the same empty public shape'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'f1000000-0000-4000-8000-000000000001',
      'x',
      null
    )
  $$,
  '22023',
  'A Project resource-need title must contain between 2 and 160 characters.',
  'need creation rejects a title shorter than two characters'
);
select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'f1000000-0000-4000-8000-000000000001',
      repeat('x', 161),
      null
    )
  $$,
  '22023',
  'A Project resource-need title must contain between 2 and 160 characters.',
  'need creation rejects a title longer than 160 characters'
);
select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'f1000000-0000-4000-8000-000000000001',
      'Paint',
      repeat('x', 1001)
    )
  $$,
  '22023',
  'Project resource-need details must contain at most 1000 characters.',
  'need creation rejects details longer than 1000 characters'
);

select set_config(
  'test.need_one',
  public.create_project_resource_need(
    'e1000000-0000-4000-8000-000000000001',
    'f1000000-0000-4000-8000-000000000001',
    '  Paint  ',
    '  Exterior-safe paint  '
  )::text,
  true
);
select set_config(
  'test.need_two',
  public.create_project_resource_need(
    'e1000000-0000-4000-8000-000000000001',
    'f1000000-0000-4000-8000-000000000001',
    'Van for transport',
    '   '
  )::text,
  true
);

reset role;

select results_eq(
  $$
    select title, details, state, closed_at
    from public.project_resource_needs
    where id = current_setting('test.need_one')::uuid
  $$,
  $$
    values (
      'Paint'::text,
      'Exterior-safe paint'::text,
      'open'::text,
      null::timestamptz
    )
  $$,
  'need creation trims plain text and creates canonical open state'
);
select is(
  (
    select details
    from public.project_resource_needs
    where id = current_setting('test.need_two')::uuid
  ),
  null,
  'blank optional details normalize to null'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-4000-8000-000000000002',
  true
);

select throws_ok(
  $$
    select public.create_project_resource_need(
      'e2000000-0000-4000-8000-000000000002',
      'f1000000-0000-4000-8000-000000000001',
      'Unauthorized need',
      null
    )
  $$,
  '42501',
  'Only the project creator can manage its resource needs.',
  'an unrelated profile cannot create a Project need'
);
select throws_ok(
  $$
    select public.update_project_resource_need(
      'e2000000-0000-4000-8000-000000000002',
      current_setting('test.need_one')::uuid,
      'Unauthorized update',
      null
    )
  $$,
  '42501',
  'Only the project creator can manage its resource needs.',
  'an unrelated profile cannot update a Project need'
);
select throws_ok(
  $$
    select public.close_project_resource_need(
      'e2000000-0000-4000-8000-000000000002',
      current_setting('test.need_one')::uuid
    )
  $$,
  '42501',
  'Only the project creator can manage its resource needs.',
  'an unrelated profile cannot close a Project need'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_resource_needs(
      'e2000000-0000-4000-8000-000000000002',
      'f1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'Only the project creator can perform this operation.',
  'an unrelated profile cannot read creator need history'
);

select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select *
    from public.list_own_project_resource_needs(
      'e2000000-0000-4000-8000-000000000002',
      'f1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected creator identity is rejected'
);
select results_eq(
  $$
    select resource_need_id
    from public.list_own_project_resource_needs(
      'e1000000-0000-4000-8000-000000000001',
      'f1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    select expected.resource_need_id
    from (values
      (current_setting('test.need_one')::uuid),
      (current_setting('test.need_two')::uuid)
    ) as expected(resource_need_id)
    order by expected.resource_need_id
  $$,
  'creator history uses stable creation-time and UUID ordering'
);

reset role;
update public.projects
set registration_capacity = 12
where id = 'f1000000-0000-4000-8000-000000000001';

update public.proposals
set
  lifecycle_state = 'published',
  published_at = statement_timestamp()
where id = 'f1000000-0000-4000-8000-000000000001';

set local role anon;
select results_eq(
  $$
    select resource_need_id
    from public.list_public_project_resource_needs(
      'f1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    select expected.resource_need_id
    from (values
      (current_setting('test.need_one')::uuid),
      (current_setting('test.need_two')::uuid)
    ) as expected(resource_need_id)
    order by expected.resource_need_id
  $$,
  'publication exposes open needs in deterministic creation order'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.update_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.need_one')::uuid,
      '  Paint and brushes  ',
      '  Exterior supplies  '
    )
  $$,
  'the creator can update an open need while the Proposal is owner-editable'
);

set local role anon;
select results_eq(
  $$
    select title, details
    from public.list_public_project_resource_needs(
      'f1000000-0000-4000-8000-000000000001'
    )
    where resource_need_id = current_setting('test.need_one')::uuid
  $$,
  $$values ('Paint and brushes'::text, 'Exterior supplies'::text)$$,
  'public Project needs reflect a canonical owner update'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.close_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.need_two')::uuid
    )
  $$,
  'the creator can terminally close an open need'
);
select throws_ok(
  $$
    select public.update_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.need_two')::uuid,
      'Reopened title',
      null
    )
  $$,
  '55000',
  'Only an open Project resource need can be updated.',
  'a closed need cannot be updated or reopened'
);
select throws_ok(
  $$
    select public.close_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.need_two')::uuid
    )
  $$,
  '55000',
  'Only an open Project resource need can be closed.',
  'a closed need cannot be closed again'
);

set local role anon;
select results_eq(
  $$
    select resource_need_id
    from public.list_public_project_resource_needs(
      'f1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$values (current_setting('test.need_one')::uuid)$$,
  'closure removes only the closed need from public visibility'
);

reset role;
select results_eq(
  $$
    select state, closed_at is not null, updated_at >= closed_at
    from public.project_resource_needs
    where id = current_setting('test.need_two')::uuid
  $$,
  $$values ('closed'::text, true, true)$$,
  'closure preserves identity with canonical terminal timestamps'
);
select is(
  (
    select count(*)
    from public.project_resource_needs
    where id = current_setting('test.need_two')::uuid
  ),
  1::bigint,
  'closing a need never deletes its stable identity'
);

update public.proposals
set
  lifecycle_state = 'cancelled',
  cancelled_at = statement_timestamp()
where id = 'f1000000-0000-4000-8000-000000000001';

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'f1000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'a cancelled Proposal hides every still-open need'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'f1000000-0000-4000-8000-000000000001',
      'Late need',
      null
    )
  $$,
  '55000',
  'This project can no longer manage resource needs.',
  'a cancelled Proposal rejects new need mutations'
);
select is(
  (
    select count(*)
    from public.list_own_project_resource_needs(
      'e1000000-0000-4000-8000-000000000001',
      'f1000000-0000-4000-8000-000000000001'
    )
  ),
  2::bigint,
  'a historical Proposal owner retains open and closed need history'
);

select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'f3000000-0000-4000-8000-000000000003',
      'Started mutation',
      null
    )
  $$,
  '55000',
  'This project can no longer manage resource needs.',
  'a started Proposal follows the existing owner-edit immutability boundary'
);
select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'f4000000-0000-4000-8000-000000000004',
      'Expired mutation',
      null
    )
  $$,
  '55000',
  'This project can no longer manage resource needs.',
  'an ended Proposal rejects need mutations'
);

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'f3000000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'a currently joinable started Proposal can still show its existing open need'
);
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'f4000000-0000-4000-8000-000000000004'
    )
  ),
  0::bigint,
  'a time-ended Proposal hides open needs'
);
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'f5000000-0000-4000-8000-000000000005'
    )
  ),
  0::bigint,
  'a cancelled Proposal hides open needs'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.draft_tavolo_need',
  public.create_project_resource_need(
    'e1000000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000001',
    'Draft Tavolo tools',
    null
  )::text,
  true
);
select set_config(
  'test.published_tavolo_need',
  public.create_project_resource_need(
    'e1000000-0000-4000-8000-000000000001',
    'd2000000-0000-4000-8000-000000000002',
    'Published Tavolo tools',
    null
  )::text,
  true
);
select set_config(
  'test.paused_tavolo_need',
  public.create_project_resource_need(
    'e1000000-0000-4000-8000-000000000001',
    'd3000000-0000-4000-8000-000000000003',
    'Paused Tavolo tools',
    null
  )::text,
  true
);

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'd1000000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'a draft Tavolo hides its open needs'
);
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'd2000000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'a published Tavolo exposes its open needs'
);
select is(
  (
    select count(*)
    from public.list_public_project_resource_needs(
      'd3000000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'a paused Tavolo hides its open needs'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.update_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.paused_tavolo_need')::uuid,
      'Paused Tavolo materials',
      null
    )
  $$,
  'a paused but owner-manageable Tavolo permits need updates'
);

reset role;
update public.recurring_activities
set
  lifecycle_state = 'published',
  paused_at = null,
  resumed_at = statement_timestamp()
where id = 'd3000000-0000-4000-8000-000000000003';

set local role anon;
select results_eq(
  $$
    select title
    from public.list_public_project_resource_needs(
      'd3000000-0000-4000-8000-000000000003'
    )
  $$,
  $$values ('Paused Tavolo materials'::text)$$,
  'resuming a Tavolo restores visibility for its still-open updated need'
);

reset role;
update public.recurring_activities
set
  lifecycle_state = 'paused',
  paused_at = statement_timestamp()
where id = 'd3000000-0000-4000-8000-000000000003';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.close_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.paused_tavolo_need')::uuid
    )
  $$,
  'a paused owner-manageable Tavolo permits terminal need closure'
);
select throws_ok(
  $$
    select public.create_project_resource_need(
      'e1000000-0000-4000-8000-000000000001',
      'd4000000-0000-4000-8000-000000000004',
      'Ended Tavolo mutation',
      null
    )
  $$,
  '55000',
  'This project can no longer manage resource needs.',
  'an ended Tavolo rejects need mutations'
);
select is(
  (
    select count(*)
    from public.list_own_project_resource_needs(
      'e1000000-0000-4000-8000-000000000001',
      'd4000000-0000-4000-8000-000000000004'
    )
  ),
  1::bigint,
  'an ended Tavolo owner retains historical need identity'
);

reset role;

select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type in (
      'project.resource_need_created',
      'project.resource_need_updated',
      'project.resource_need_closed'
    )
      and (
        select count(*)
        from jsonb_object_keys(event.payload)
      ) = 4
      and event.payload ?& array[
        'project_id',
        'project_kind',
        'resource_need_id',
        'creator_profile_id'
      ]
  ),
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type in (
      'project.resource_need_created',
      'project.resource_need_updated',
      'project.resource_need_closed'
    )
  ),
  'every resource-need outbox event contains exactly four canonical identifiers'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action in (
      'project.resource_need_created',
      'project.resource_need_updated',
      'project.resource_need_closed'
    )
      and event.target_type = 'project_resource_need'
      and (
        select count(*)
        from jsonb_object_keys(event.metadata)
      ) = 4
      and event.metadata ?& array[
        'project_id',
        'project_kind',
        'resource_need_id',
        'creator_profile_id'
      ]
  ),
  (
    select count(*)
    from private.audit_events as event
    where event.action in (
      'project.resource_need_created',
      'project.resource_need_updated',
      'project.resource_need_closed'
    )
  ),
  'every resource-need audit event contains exactly four canonical identifiers'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type like 'project.resource_need_%'
      and (
        event.payload::text like '%Paint and brushes%'
        or event.payload::text like '%Exterior supplies%'
        or event.payload::text like '%Van for transport%'
      )
  ),
  0::bigint,
  'resource-need outbox payloads contain no title or details text'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$select id from public.project_resource_needs$$,
  '42501',
  'permission denied for table project_resource_needs',
  'authenticated users cannot bypass the narrow resource-need RPCs'
);

select * from finish();

rollback;
