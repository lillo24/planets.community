begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a1000000-0000-4000-8000-000000000001', 'commitment-owner@planets.invalid'),
  ('a1000000-0000-4000-8000-000000000002', 'commitment-member@planets.invalid'),
  ('a1000000-0000-4000-8000-000000000003', 'commitment-other@planets.invalid'),
  ('a1000000-0000-4000-8000-000000000004', 'commitment-recurring-member@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a1000000-0000-4000-8000-000000000001', 'Commitment Owner'),
  ('a1000000-0000-4000-8000-000000000002', 'Commitment Member'),
  ('a1000000-0000-4000-8000-000000000003', 'Commitment Other'),
  ('a1000000-0000-4000-8000-000000000004', 'Commitment Recurring Member');

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
    'a2000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'published',
    'Started operational commitment Proposal',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '2 days',
    statement_timestamp() - interval '2 days'
  ),
  (
    'a2000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'published',
    'Other commitment Proposal',
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
  'a4000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'published',
  'Commitment Tavolo',
  statement_timestamp() - interval '1 day'
);

insert into public.proposal_skills (proposal_id, skill_id, importance)
values
  (
    'a2000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8001-000000000001',
    'required'
  ),
  (
    'a2000000-0000-4000-8000-000000000001',
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
    'a3000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'Seeded open need',
    'open',
    statement_timestamp() - interval '4 minutes',
    statement_timestamp() - interval '4 minutes',
    null
  ),
  (
    'a3000000-0000-4000-8000-000000000002',
    'a2000000-0000-4000-8000-000000000001',
    'Second open need',
    'open',
    statement_timestamp() - interval '3 minutes',
    statement_timestamp() - interval '3 minutes',
    null
  ),
  (
    'a3000000-0000-4000-8000-000000000003',
    'a2000000-0000-4000-8000-000000000002',
    'Other Project need',
    'open',
    statement_timestamp() - interval '2 minutes',
    statement_timestamp() - interval '2 minutes',
    null
  ),
  (
    'a3000000-0000-4000-8000-000000000004',
    'a2000000-0000-4000-8000-000000000001',
    'Already closed need',
    'closed',
    statement_timestamp() - interval '5 minutes',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() - interval '1 minute'
  ),
  (
    'a3000000-0000-4000-8000-000000000005',
    'a4000000-0000-4000-8000-000000000001',
    'Tavolo seeded need',
    'open',
    statement_timestamp() - interval '2 minutes',
    statement_timestamp() - interval '2 minutes',
    null
  ),
  (
    'a3000000-0000-4000-8000-000000000006',
    'a4000000-0000-4000-8000-000000000001',
    'Tavolo added need',
    'open',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() - interval '1 minute',
    null
  );

set local role anon;

select throws_ok(
  $$select * from public.project_membership_skill_commitments$$,
  '42501',
  'permission denied for table project_membership_skill_commitments',
  'anonymous users cannot read skill commitments directly'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitments(
      null,
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function list_own_project_membership_commitments',
  'anonymous users cannot invoke the commitment read'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitment_options(
      null,
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function list_own_project_membership_commitment_options',
  'anonymous users cannot invoke the commitment-options read'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.commitment_request',
  public.request_to_join_project(
    'a1000000-0000-4000-8000-000000000002',
    'a2000000-0000-4000-8000-000000000001',
    'Seed my current commitments',
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array['a3000000-0000-4000-8000-000000000001'::uuid]
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.commitment_membership',
  public.accept_project_join_request(
    'a1000000-0000-4000-8000-000000000001',
    current_setting('test.commitment_request')::uuid
  )::text,
  true
);

reset role;

select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    order by 1 desc
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000001'::uuid)
  $$,
  'acceptance atomically seeds the membership from immutable request selections'
);
select is(
  (
    select count(*)
    from public.project_membership_skill_commitments as commitment
    join public.project_memberships as membership
      on membership.id = commitment.membership_id
    where commitment.membership_id =
      current_setting('test.commitment_membership')::uuid
      and commitment.committed_at = membership.joined_at
  ) + (
    select count(*)
    from public.project_membership_resource_commitments as commitment
    join public.project_memberships as membership
      on membership.id = commitment.membership_id
    where commitment.membership_id =
      current_setting('test.commitment_membership')::uuid
      and commitment.committed_at = membership.joined_at
  ),
  2::bigint,
  'seeded rows inherit the canonical acceptance time'
);
select is(
  (
    select count(*)
    from public.project_join_request_skill_selections
    where request_id = current_setting('test.commitment_request')::uuid
  ) + (
    select count(*)
    from public.project_join_request_resource_selections
    where request_id = current_setting('test.commitment_request')::uuid
  ),
  2::bigint,
  'acceptance seeding does not rewrite or remove immutable request history'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.membership_commitments_updated'
      and payload ->> 'membership_id' =
        current_setting('test.commitment_membership')
  ),
  0::bigint,
  'acceptance seeding emits no commitment-updated event'
);
select is(
  (
    select count(*)
    from public.project_group_chats
    where project_id = 'a2000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'the existing acceptance-time group-chat trigger still creates one chat'
);

select set_config(
  'test.options_audit_before',
  (select count(*)::text from private.audit_events),
  true
);
select set_config(
  'test.options_outbox_before',
  (select count(*)::text from private.outbox_events),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select option_kind, option_id, label
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
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
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'Seeded open need'::text
      ),
      (
        'resource'::text,
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'Second open need'::text
      )
  $$,
  'a Proposal participant reads required/useful skills then open resources in deterministic order'
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select option_kind, option_id
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000001'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'the canonical creator may read one current member addable options'
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000003',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  '42501',
  'The membership commitment options are unavailable.',
  'an unrelated profile cannot read addable options'
);

reset role;
select is(
  (select count(*) from private.audit_events),
  current_setting('test.options_audit_before')::bigint,
  'successful and denied options reads create no audit rows'
);
select is(
  (select count(*) from private.outbox_events),
  current_setting('test.options_outbox_before')::bigint,
  'successful and denied options reads create no outbox rows'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select commitment_kind, commitment_id, label
    from public.list_own_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
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
        'resource'::text,
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'Seeded open need'::text
      )
  $$,
  'the participant reads normalized skills then resources with current labels'
);
select throws_ok(
  $$select * from public.project_membership_resource_commitments$$,
  '42501',
  'permission denied for table project_membership_resource_commitments',
  'authenticated users cannot bypass the guarded read'
);

select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '22023',
  'Expected Project skill commitments cannot contain duplicate identifiers.',
  'duplicate expected skill IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array[null::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '22023',
  'Expected Project skill commitments cannot contain null identifiers.',
  'null expected skill IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array_fill(
        'd0000000-0000-4000-8001-000000000001'::uuid,
        array[51]
      ),
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '22023',
  'An expected membership snapshot may contain at most 50 Project skills.',
  'expected skill arrays are bounded before duplicate validation'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000001'::uuid
      ],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '22023',
  'Expected Project resource commitments cannot contain duplicate identifiers.',
  'duplicate expected resource IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array[null::uuid],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '22023',
  'Expected Project resource commitments cannot contain null identifiers.',
  'null expected resource IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array_fill(
        'a3000000-0000-4000-8000-000000000001'::uuid,
        array[51]
      ),
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '22023',
  'An expected membership snapshot may contain at most 50 Project resource needs.',
  'expected resource arrays are bounded before duplicate validation'
);

select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Project skill commitments cannot contain duplicate identifiers.',
  'duplicate skill IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array[null::uuid],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Project skill commitments cannot contain null identifiers.',
  'null skill IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array_fill(
        'd0000000-0000-4000-8001-000000000001'::uuid,
        array[51]
      ),
      '{}'::uuid[]
    )
  $$,
  '22023',
  'A membership may commit to at most 50 Project skills.',
  'skill arrays are bounded before duplicate validation'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array['d0000000-0000-4000-8006-000000000001'::uuid],
      '{}'::uuid[]
    )
  $$,
  '22023',
  'Every new skill commitment must be a current requirement of this Proposal.',
  'an unattached catalog skill cannot be newly committed'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      '{}'::uuid[],
      array[
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  '22023',
  'Project resource commitments cannot contain duplicate identifiers.',
  'duplicate resource IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      '{}'::uuid[],
      array[null::uuid]
    )
  $$,
  '22023',
  'Project resource commitments cannot contain null identifiers.',
  'null resource IDs fail explicitly'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      '{}'::uuid[],
      array_fill(
        'a3000000-0000-4000-8000-000000000002'::uuid,
        array[51]
      )
    )
  $$,
  '22023',
  'A membership may commit to at most 50 Project resource needs.',
  'resource arrays are bounded before duplicate validation'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      '{}'::uuid[],
      array['a3000000-0000-4000-8000-000000000003'::uuid]
    )
  $$,
  '22023',
  'Every new resource commitment must be open and belong to this Project.',
  'a different Project resource need cannot be newly committed'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      '{}'::uuid[],
      array['a3000000-0000-4000-8000-000000000004'::uuid]
    )
  $$,
  '22023',
  'Every new resource commitment must be open and belong to this Project.',
  'a closed resource need cannot be newly committed'
);

select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array[
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'a3000000-0000-4000-8000-000000000001'::uuid
      ]
    )
  $$,
  'a participant can replace the full set on an already-started Proposal'
);

reset role;
select set_config(
  'test.useful_committed_at',
  (
    select committed_at::text
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
      and skill_id = 'd0000000-0000-4000-8003-000000000002'
  ),
  true
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.membership_commitments_updated'
      and payload ->> 'membership_id' =
        current_setting('test.commitment_membership')
  ),
  1::bigint,
  'one real full-set change emits exactly one outbox event'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array[
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'a3000000-0000-4000-8000-000000000001'::uuid
      ],
      array[
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  'an identical desired set succeeds as a no-op'
);

reset role;
select is(
  (
    select committed_at::text
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
      and skill_id = 'd0000000-0000-4000-8003-000000000002'
  ),
  current_setting('test.useful_committed_at'),
  'a no-op does not rewrite existing commitment timestamps'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'project.membership_commitments_updated'
      and payload ->> 'membership_id' =
        current_setting('test.commitment_membership')
  ),
  1::bigint,
  'a no-op emits no event'
);

select set_config(
  'test.cas_audit_before',
  (select count(*)::text from private.audit_events),
  true
);
select set_config(
  'test.cas_outbox_before',
  (select count(*)::text from private.outbox_events),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array[
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'a3000000-0000-4000-8000-000000000001'::uuid
      ],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  'the participant wins when participant and creator edit the same snapshot'
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.commitment_membership')::uuid,
      array[
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'd0000000-0000-4000-8001-000000000001'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'a3000000-0000-4000-8000-000000000001'::uuid
      ],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid]
    )
  $$,
  '40001',
  'Membership commitments changed since they were loaded.',
  'a stale creator snapshot rejects even when desired equals the newer canonical set'
);

reset role;
select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    order by 1 desc
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000001'::uuid)
  $$,
  'a rejected creator overwrite leaves the participant result canonical'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  'the creator can replace a freshly loaded participant result'
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array['a3000000-0000-4000-8000-000000000001'::uuid],
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8003-000000000002'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  '40001',
  'Membership commitments changed since they were loaded.',
  'the participant cannot overwrite a creator update from a stale snapshot'
);

reset role;
select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    order by 1 desc
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'a rejected participant overwrite leaves the creator result canonical'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8003-000000000002'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  'the first of two rapid participant submissions commits'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  '40001',
  'Membership commitments changed since they were loaded.',
  'the second rapid participant submission cannot overwrite from stale state'
);

reset role;
select results_eq(
  $$
    select 'skill'::text, skill_id
    from public.project_membership_skill_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    union all
    select 'resource'::text, resource_need_id
    from public.project_membership_resource_commitments
    where membership_id = current_setting('test.commitment_membership')::uuid
    order by 1 desc, 2
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000001'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'stale participant submission leaves the first participant result canonical'
);
select is(
  (select count(*) from private.audit_events),
  current_setting('test.cas_audit_before')::bigint + 3,
  'three successful CAS changes create exactly three audit rows'
);
select is(
  (select count(*) from private.outbox_events),
  current_setting('test.cas_outbox_before')::bigint + 3,
  'stale CAS conflicts create no outbox rows beyond the three real changes'
);

delete from public.proposal_skills
where proposal_id = 'a2000000-0000-4000-8000-000000000001'
  and skill_id = 'd0000000-0000-4000-8001-000000000001';
update public.project_resource_needs
set
  state = 'closed',
  closed_at = statement_timestamp(),
  updated_at = statement_timestamp()
where id = 'a3000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select commitment_kind, commitment_id
    from public.list_own_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8001-000000000001'::uuid),
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000001'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'retained commitments still include a removed skill and closed need'
);
select results_eq(
  $$
    select option_kind, option_id
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'removed skills and closed needs are absent from newly addable options'
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8003-000000000002'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ],
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8003-000000000002'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  'existing stale commitments can be retained'
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8003-000000000002'::uuid
      ],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ],
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  'existing stale commitments can be removed'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8003-000000000002'::uuid
      ],
      array['a3000000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  '22023',
  'Every new skill commitment must be a current requirement of this Proposal.',
  'a removed stale skill cannot be re-added'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array[
        'a3000000-0000-4000-8000-000000000001'::uuid,
        'a3000000-0000-4000-8000-000000000002'::uuid
      ]
    )
  $$,
  '22023',
  'Every new resource commitment must be open and belong to this Project.',
  'a removed stale resource need cannot be re-added'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      null,
      null
    )
  $$,
  'the canonical creator can clear the full set and null arrays normalize empty'
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.commitment_membership')::uuid,
      null,
      null,
      null,
      null
    )
  $$,
  'null expected and desired arrays normalize to the empty-set no-op'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000003',
      current_setting('test.commitment_membership')::uuid,
      '{}'::uuid[],
      '{}'::uuid[],
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  '42501',
  'Only the participant or Project creator can manage this membership commitment set.',
  'an unrelated profile cannot mutate commitments'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000003',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  '42501',
  'The membership commitments are unavailable.',
  'an unrelated profile cannot read commitments'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      '{}'::uuid[],
      '{}'::uuid[],
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  'the participant can establish the final historical set before leaving'
);
select lives_ok(
  $$
    select public.leave_project(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  'the existing leave flow ends the membership episode'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      '{}'::uuid[],
      '{}'::uuid[]
    )
  $$,
  '55000',
  'Only a current membership can change its commitments.',
  'an ended membership cannot mutate its retained final set'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  '55000',
  'Only a current membership can list commitment options.',
  'an ended membership cannot request editable options'
);
select results_eq(
  $$
    select commitment_kind, commitment_id
    from public.list_own_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'an ended participant can read the retained final commitment set'
);

select set_config(
  'test.rejoin_request',
  public.request_to_join_project(
    'a1000000-0000-4000-8000-000000000002',
    'a2000000-0000-4000-8000-000000000001',
    null,
    array['d0000000-0000-4000-8003-000000000002'::uuid],
    array['a3000000-0000-4000-8000-000000000002'::uuid]
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.rejoin_membership',
  public.accept_project_join_request(
    'a1000000-0000-4000-8000-000000000001',
    current_setting('test.rejoin_request')::uuid
  )::text,
  true
);
select isnt(
  current_setting('test.rejoin_membership'),
  current_setting('test.commitment_membership'),
  'rejoining creates an independent membership episode'
);
select results_eq(
  $$
    select commitment_kind, commitment_id
    from public.list_own_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.rejoin_membership')::uuid
    )
  $$,
  $$
    values
      ('skill'::text, 'd0000000-0000-4000-8003-000000000002'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000002'::uuid)
  $$,
  'the new episode seeds only from its own immutable request attempt'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.recurring_request',
  public.request_to_join_project(
    'a1000000-0000-4000-8000-000000000004',
    'a4000000-0000-4000-8000-000000000001',
    null,
    '{}'::uuid[],
    array['a3000000-0000-4000-8000-000000000005'::uuid]
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.recurring_membership',
  public.accept_project_join_request(
    'a1000000-0000-4000-8000-000000000001',
    current_setting('test.recurring_request')::uuid
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000004',
  true
);
select results_eq(
  $$
    select option_kind, option_id, label
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000004',
      current_setting('test.recurring_membership')::uuid
    )
  $$,
  $$
    values
      (
        'resource'::text,
        'a3000000-0000-4000-8000-000000000005'::uuid,
        'Tavolo seeded need'::text
      ),
      (
        'resource'::text,
        'a3000000-0000-4000-8000-000000000006'::uuid,
        'Tavolo added need'::text
      )
  $$,
  'a published Tavolo returns open resources and no skill options'
);

reset role;
update public.recurring_activities
set
  lifecycle_state = 'paused',
  paused_at = statement_timestamp()
where id = 'a4000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000004',
  true
);
select results_eq(
  $$
    select option_kind, option_id
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000004',
      current_setting('test.recurring_membership')::uuid
    )
  $$,
  $$
    values
      ('resource'::text, 'a3000000-0000-4000-8000-000000000005'::uuid),
      ('resource'::text, 'a3000000-0000-4000-8000-000000000006'::uuid)
  $$,
  'a paused Tavolo still returns open resource options and no skills'
);
select lives_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000004',
      current_setting('test.recurring_membership')::uuid,
      '{}'::uuid[],
      array['a3000000-0000-4000-8000-000000000005'::uuid],
      '{}'::uuid[],
      array[
        'a3000000-0000-4000-8000-000000000005'::uuid,
        'a3000000-0000-4000-8000-000000000006'::uuid
      ]
    )
  $$,
  'a paused Tavolo remains operational for resource commitments'
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000004',
      current_setting('test.recurring_membership')::uuid,
      '{}'::uuid[],
      array[
        'a3000000-0000-4000-8000-000000000005'::uuid,
        'a3000000-0000-4000-8000-000000000006'::uuid
      ],
      array['d0000000-0000-4000-8001-000000000001'::uuid],
      array[
        'a3000000-0000-4000-8000-000000000005'::uuid,
        'a3000000-0000-4000-8000-000000000006'::uuid
      ]
    )
  $$,
  '22023',
  'Recurring Projects do not currently define new skill commitments.',
  'a Tavolo rejects every new skill commitment'
);

reset role;
update public.recurring_activities
set
  lifecycle_state = 'ended',
  ended_at = statement_timestamp()
where id = 'a4000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000004',
      current_setting('test.recurring_membership')::uuid
    )
  $$,
  '55000',
  'Membership commitments can only change while the Project is operational.',
  'an ended Tavolo rejects editable option reads'
);

reset role;
update public.proposals
set ends_at = statement_timestamp() - interval '1 minute'
where id = 'a2000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.replace_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.rejoin_membership')::uuid,
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid],
      array['d0000000-0000-4000-8003-000000000002'::uuid],
      array['a3000000-0000-4000-8000-000000000002'::uuid]
    )
  $$,
  '55000',
  'Membership commitments can only change while the Project is operational.',
  'an ended Proposal rejects mutation even when the desired set is a no-op'
);
select throws_ok(
  $$
    select *
    from public.list_own_project_membership_commitment_options(
      'a1000000-0000-4000-8000-000000000002',
      current_setting('test.rejoin_membership')::uuid
    )
  $$,
  '55000',
  'Membership commitments can only change while the Project is operational.',
  'an ended Proposal rejects editable option reads'
);

reset role;
update public.skills
set label = 'Current woodworking label'
where id = 'd0000000-0000-4000-8003-000000000002';
update public.project_resource_needs
set
  title = 'Current second-need title',
  updated_at = statement_timestamp()
where id = 'a3000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select commitment_kind, commitment_id, label
    from public.list_own_project_membership_commitments(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.commitment_membership')::uuid
    )
  $$,
  $$
    values
      (
        'skill'::text,
        'd0000000-0000-4000-8003-000000000002'::uuid,
        'Current woodworking label'::text
      ),
      (
        'resource'::text,
        'a3000000-0000-4000-8000-000000000002'::uuid,
        'Current second-need title'::text
      )
  $$,
  'the creator reads ended history with current canonical labels'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'project.membership_commitments_updated'
      and event.payload ->> 'membership_id' in (
        current_setting('test.commitment_membership'),
        current_setting('test.recurring_membership')
      )
      and jsonb_object_length(event.payload) = 5
      and event.payload ?& array[
        'project_id',
        'project_kind',
        'membership_id',
        'participant_profile_id',
        'actor_profile_id'
      ]
  ),
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'project.membership_commitments_updated'
      and event.payload ->> 'membership_id' in (
        current_setting('test.commitment_membership'),
        current_setting('test.recurring_membership')
      )
  ),
  'every real-change outbox event has the exact five-identifier payload'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'project.membership_commitments_updated'
      and event.payload ->> 'membership_id' in (
        current_setting('test.commitment_membership'),
        current_setting('test.recurring_membership')
      )
      and (
        event.payload ?| array[
          'skill_ids',
          'resource_need_ids',
          'label',
          'title',
          'message',
          'count'
        ]
        or event.payload::text like '%Current woodworking label%'
        or event.payload::text like '%Current second-need title%'
      )
  ),
  0::bigint,
  'commitment events never expose arrays, labels, messages, or counts'
);
select is(
  (
    select count(*)
    from private.audit_events as event
    where event.action = 'project.membership_commitments_updated'
      and event.target_id in (
        current_setting('test.commitment_membership')::uuid,
        current_setting('test.recurring_membership')::uuid
      )
      and (
        event.target_type <> 'project_membership'
        or jsonb_object_length(event.metadata) <> 5
      )
  ),
  0::bigint,
  'audit rows use the membership target and exact identifier-only metadata'
);
select is(
  (
    select count(*)
    from public.notifications as notification
    join private.outbox_events as event
      on event.id = notification.source_outbox_event_id
    where event.event_type = 'project.membership_commitments_updated'
  ),
  0::bigint,
  'commitment changes create no notifications'
);

select * from finish();

rollback;
