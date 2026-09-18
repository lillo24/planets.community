begin;

select no_plan();

insert into auth.users (id, email)
values
  ('91000000-0000-4000-8000-000000000001', 'selection-owner@planets.invalid'),
  ('91000000-0000-4000-8000-000000000002', 'selection-requester@planets.invalid'),
  ('91000000-0000-4000-8000-000000000003', 'selection-requester-two@planets.invalid'),
  ('91000000-0000-4000-8000-000000000004', 'selection-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('91000000-0000-4000-8000-000000000001', 'Selection Owner'),
  ('91000000-0000-4000-8000-000000000002', 'Selection Requester'),
  ('91000000-0000-4000-8000-000000000003', 'Selection Requester Two'),
  ('91000000-0000-4000-8000-000000000004', 'Selection Unrelated');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at
)
values
  (
    '92000000-0000-4000-8000-000000000001',
    '91000000-0000-4000-8000-000000000001',
    'published',
    'Contribution selection Proposal',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    '92000000-0000-4000-8000-000000000002',
    '91000000-0000-4000-8000-000000000001',
    'published',
    'Other contribution Proposal',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
    statement_timestamp() - interval '1 day'
  ),
  (
    '92000000-0000-4000-8000-000000000003',
    '91000000-0000-4000-8000-000000000001',
    'published',
    'Backward-compatible Proposal',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '3 days',
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
  '94000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  'published',
  'Contribution selection Tavolo',
  statement_timestamp() - interval '1 day'
);

insert into public.proposal_skills (proposal_id, skill_id, importance)
values
  (
    '92000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8001-000000000001',
    'required'
  ),
  (
    '92000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8003-000000000002',
    'useful'
  );

insert into public.project_resource_needs (
  id,
  project_id,
  title,
  state,
  created_at,
  updated_at,
  closed_at
)
values
  (
    '93000000-0000-4000-8000-000000000001',
    '92000000-0000-4000-8000-000000000001',
    'First open need',
    'open',
    statement_timestamp() - interval '4 minutes',
    statement_timestamp() - interval '4 minutes',
    null
  ),
  (
    '93000000-0000-4000-8000-000000000002',
    '92000000-0000-4000-8000-000000000001',
    'Second open need',
    'open',
    statement_timestamp() - interval '3 minutes',
    statement_timestamp() - interval '3 minutes',
    null
  ),
  (
    '93000000-0000-4000-8000-000000000003',
    '92000000-0000-4000-8000-000000000002',
    'Other Project need',
    'open',
    statement_timestamp() - interval '2 minutes',
    statement_timestamp() - interval '2 minutes',
    null
  ),
  (
    '93000000-0000-4000-8000-000000000004',
    '92000000-0000-4000-8000-000000000001',
    'Closed need',
    'closed',
    statement_timestamp() - interval '5 minutes',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() - interval '1 minute'
  ),
  (
    '93000000-0000-4000-8000-000000000005',
    '94000000-0000-4000-8000-000000000001',
    'Tavolo open need',
    'open',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() - interval '1 minute',
    null
  );

set local role anon;

select throws_ok(
  $$select * from public.project_join_request_skill_selections$$,
  '42501',
  'permission denied for table project_join_request_skill_selections',
  'anonymous users cannot read skill-selection history directly'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_join_request_contribution_selections(
      null,
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function list_own_project_join_request_contribution_selections',
  'anonymous users cannot invoke the private selection read'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000002',
  true
);

select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Project skill selections cannot contain duplicate identifiers.',
  'duplicate skill IDs fail explicitly before request creation'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      array[null::uuid],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Project skill selections cannot contain null identifiers.',
  'null skill IDs fail explicitly before request creation'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      array_fill(
        'd0000000-0000-4000-8001-000000000001'::uuid,
        array[51]
      ),
      '{}'::uuid[]
    )
  $$,
  '22023',
  'A participation request may select at most 50 Project skills.',
  'skill-selection arrays are bounded before duplicate validation'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      array['d0000000-0000-4000-8006-000000000001'::uuid],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Every selected skill must be a current requirement of this Proposal.',
  'a catalog skill not attached to the Proposal is rejected'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      array['93000000-0000-4000-8000-000000000003'::uuid]
    )
  $$,
  '22023',
  'Every selected resource need must be open and belong to this Project.',
  'a resource need from another Project is rejected'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      array['93000000-0000-4000-8000-000000000004'::uuid]
    )
  $$,
  '22023',
  'Every selected resource need must be open and belong to this Project.',
  'a closed resource need is rejected'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      array['93000000-0000-4000-8000-000000000099'::uuid]
    )
  $$,
  '22023',
  'Every selected resource need must be open and belong to this Project.',
  'an unknown resource need is rejected with the same fail-closed error'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      array[
        '93000000-0000-4000-8000-000000000001'::uuid,
        '93000000-0000-4000-8000-000000000001'::uuid
      ]
    )
  $$,
  '22023',
  'Project resource selections cannot contain duplicate identifiers.',
  'duplicate resource IDs fail explicitly before request creation'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      array[null::uuid]
    )
  $$,
  '22023',
  'Project resource selections cannot contain null identifiers.',
  'null resource IDs fail explicitly before request creation'
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000001',
      null,
      '{}'::uuid[],
      array_fill(
        '93000000-0000-4000-8000-000000000001'::uuid,
        array[51]
      )
    )
  $$,
  '22023',
  'A participation request may select at most 50 Project resource needs.',
  'resource-selection arrays are bounded before duplicate validation'
);

reset role;
select is(
  (
    select count(*)
    from public.project_join_requests
    where requester_profile_id =
      '91000000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'every invalid selection attempt remains atomic with no request row'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.backward_request',
  public.request_to_join_project(
    '91000000-0000-4000-8000-000000000002',
    '92000000-0000-4000-8000-000000000003',
    'Existing three-argument caller'
  )::text,
  true
);

reset role;
select is(
  (
    select count(*)
    from public.project_join_request_skill_selections
    where request_id = current_setting('test.backward_request')::uuid
  ) + (
    select count(*)
    from public.project_join_request_resource_selections
    where request_id = current_setting('test.backward_request')::uuid
  ),
  0::bigint,
  'the existing three-argument call creates an empty selection history'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.primary_request',
  public.request_to_join_project(
    '91000000-0000-4000-8000-000000000002',
    '92000000-0000-4000-8000-000000000001',
    '  I can bring supplies  ',
    array[
      'd0000000-0000-4000-8003-000000000002'::uuid,
      'd0000000-0000-4000-8001-000000000001'::uuid
    ],
    array[
      '93000000-0000-4000-8000-000000000002'::uuid,
      '93000000-0000-4000-8000-000000000001'::uuid
    ]
  )::text,
  true
);

select results_eq(
  $$
    select selection_kind, selection_id, label
    from public.list_own_project_join_request_contribution_selections(
      '91000000-0000-4000-8000-000000000002',
      current_setting('test.primary_request')::uuid
    )
  $$,
  $$
    values
      (
        'skill'::text,
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'Mural painting'::text
      ),
      (
        'skill'::text,
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'Woodworking'::text
      ),
      (
        'resource'::text,
        '93000000-0000-4000-8000-000000000001'::uuid,
        'First open need'::text
      ),
      (
        'resource'::text,
        '93000000-0000-4000-8000-000000000002'::uuid,
        'Second open need'::text
      )
  $$,
  'requesters read canonical skills then resources in deterministic order'
);
select throws_ok(
  $$select * from public.project_join_request_resource_selections$$,
  '42501',
  'permission denied for table project_join_request_resource_selections',
  'authenticated users cannot bypass the contribution read boundary'
);
select lives_ok(
  $$
    select public.withdraw_project_join_request(
      '91000000-0000-4000-8000-000000000002',
      current_setting('test.primary_request')::uuid
    )
  $$,
  'a contribution-aware pending request keeps the existing withdrawal flow'
);
select set_config(
  'test.rejected_request',
  public.request_to_join_project(
    '91000000-0000-4000-8000-000000000002',
    '92000000-0000-4000-8000-000000000001',
    null,
    array['d0000000-0000-4000-8003-000000000002'::uuid],
    array['93000000-0000-4000-8000-000000000002'::uuid]
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.reject_project_join_request(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.rejected_request')::uuid
    )
  $$,
  'a contribution-aware pending request keeps the existing rejection flow'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.accepted_request',
  public.request_to_join_project(
    '91000000-0000-4000-8000-000000000003',
    '92000000-0000-4000-8000-000000000001',
    null,
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array['93000000-0000-4000-8000-000000000001'::uuid]
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.accept_project_join_request(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.accepted_request')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      '{}'::uuid[],
      '{}'::uuid[],
      array['93000000-0000-4000-8000-000000000001'::uuid],
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  'a contribution-aware pending request accepts through explicit triage'
);
select results_eq(
  $$
    select selection_kind, selection_id
    from public.list_own_project_join_request_contribution_selections(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.primary_request')::uuid
    )
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, '93000000-0000-4000-8000-000000000001'::uuid),
      ('resource'::text, '93000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'the Project creator can read another profile private request selections'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  $$
    select *
    from public.list_own_project_join_request_contribution_selections(
      '91000000-0000-4000-8000-000000000004',
      current_setting('test.primary_request')::uuid
    )
  $$,
  '42501',
  'The participation request contribution selections are unavailable.',
  'an unrelated profile cannot read private selection history'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_join_request_contribution_selections(
      '91000000-0000-4000-8000-000000000002',
      current_setting('test.primary_request')::uuid
    )
  $$,
  '42501',
  'The authenticated user does not match the expected participant identity.',
  'a stale expected identity fails before request disclosure'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.request_to_join_project(
      '91000000-0000-4000-8000-000000000002',
      '94000000-0000-4000-8000-000000000001',
      null,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Recurring Projects do not currently define selectable skill requirements.',
  'Tavoli fail closed for non-empty skill selections'
);
select set_config(
  'test.tavolo_request',
  public.request_to_join_project(
    '91000000-0000-4000-8000-000000000002',
    '94000000-0000-4000-8000-000000000001',
    null,
    '{}'::uuid[],
    array['93000000-0000-4000-8000-000000000005'::uuid]
  )::text,
  true
);
select results_eq(
  $$
    select selection_kind, selection_id, label
    from public.list_own_project_join_request_contribution_selections(
      '91000000-0000-4000-8000-000000000002',
      current_setting('test.tavolo_request')::uuid
    )
  $$,
  $$
    values (
      'resource'::text,
      '93000000-0000-4000-8000-000000000005'::uuid,
      'Tavolo open need'::text
    )
  $$,
  'Tavoli accept open resource selections without introducing skill semantics'
);

reset role;

select is(
  (
    select count(*)
    from public.project_join_request_skill_selections
    where request_id in (
      current_setting('test.primary_request')::uuid,
      current_setting('test.rejected_request')::uuid,
      current_setting('test.accepted_request')::uuid
    )
  ),
  4::bigint,
  'withdrawn, rejected, and accepted attempts retain their skill selections'
);
select is(
  (
    select count(*)
    from public.project_join_request_resource_selections
    where request_id in (
      current_setting('test.primary_request')::uuid,
      current_setting('test.rejected_request')::uuid,
      current_setting('test.accepted_request')::uuid
    )
  ),
  4::bigint,
  'withdrawn, rejected, and accepted attempts retain their resource selections'
);
select results_eq(
  $$
    select status
    from public.project_join_requests
    where id in (
      current_setting('test.primary_request')::uuid,
      current_setting('test.rejected_request')::uuid,
      current_setting('test.accepted_request')::uuid
    )
    order by status
  $$,
  $$values ('accepted'::text), ('rejected'::text), ('withdrawn'::text)$$,
  'selection persistence does not alter existing request lifecycle states'
);

update public.skills
set label = 'Community mural painting'
where id = 'd0000000-0000-4000-8001-000000000001';

delete from public.proposal_skills
where proposal_id = '92000000-0000-4000-8000-000000000001'
  and skill_id = 'd0000000-0000-4000-8001-000000000001';

update public.project_resource_needs
set
  title = 'Renamed closed need',
  state = 'closed',
  closed_at = statement_timestamp(),
  updated_at = statement_timestamp()
where id = '93000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select selection_kind, selection_id, label
    from public.list_own_project_join_request_contribution_selections(
      '91000000-0000-4000-8000-000000000002',
      current_setting('test.primary_request')::uuid
    )
  $$,
  $$
    values
      (
        'skill'::text,
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'Community mural painting'::text
      ),
      (
        'skill'::text,
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'Woodworking'::text
      ),
      (
        'resource'::text,
        '93000000-0000-4000-8000-000000000001'::uuid,
        'Renamed closed need'::text
      ),
      (
        'resource'::text,
        '93000000-0000-4000-8000-000000000002'::uuid,
        'Second open need'::text
      )
  $$,
  'historical IDs survive requirement removal and closure while labels resolve canonically'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'project.join_requested'
      and event.payload ->> 'project_id' in (
        '92000000-0000-4000-8000-000000000001',
        '92000000-0000-4000-8000-000000000003',
        '94000000-0000-4000-8000-000000000001'
      )
      and jsonb_object_length(event.payload) = 6
      and event.payload ?& array[
        'project_kind',
        'request_id',
        'requester_profile_id',
        'status',
        'project_id',
        'actor_profile_id'
      ]
  ),
  5::bigint,
  'successful contribution requests retain the exact existing outbox contract'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'project.join_requested'
      and event.payload ->> 'project_id' in (
        '92000000-0000-4000-8000-000000000001',
        '92000000-0000-4000-8000-000000000003',
        '94000000-0000-4000-8000-000000000001'
      )
      and (
        event.payload ?| array[
          'skill_ids',
          'resource_need_ids',
          'request_message',
          'label',
          'title'
        ]
        or event.payload::text like '%I can bring supplies%'
        or event.payload::text like '%First open need%'
        or event.payload::text like '%Mural painting%'
      )
  ),
  0::bigint,
  'join-request outbox payloads remain free of arrays and user-authored text'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action = 'project.join_requested'
      and event.target_id in (
        '92000000-0000-4000-8000-000000000001'::uuid,
        '92000000-0000-4000-8000-000000000003'::uuid,
        '94000000-0000-4000-8000-000000000001'::uuid
      )
      and (
        jsonb_object_length(event.metadata) <> 4
        or event.metadata ?| array[
          'skill_ids',
          'resource_need_ids',
          'request_message',
          'label',
          'title'
        ]
      )
  ),
  0::bigint,
  'join-request audit metadata also retains its identifier-only contract'
);

select * from finish();

rollback;
