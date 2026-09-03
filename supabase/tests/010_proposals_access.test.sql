begin;

select no_plan();

insert into auth.users (id, email)
values
  ('91000000-0000-4000-8000-000000000001', 'proposal-a@planets.invalid'),
  ('92000000-0000-4000-8000-000000000002', 'proposal-b@planets.invalid'),
  ('93000000-0000-4000-8000-000000000003', 'proposal-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('91000000-0000-4000-8000-000000000001', 'Proposal Owner A'),
  ('92000000-0000-4000-8000-000000000002', 'Proposal Owner B'),
  ('93000000-0000-4000-8000-000000000003', null);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '93000000-0000-4000-8000-000000000003',
  true
);

select throws_ok(
  $$
    select public.create_proposal_draft(
      '93000000-0000-4000-8000-000000000003',
      null, null, null, null, null, null, null, null, null, null, null,
      'participants', array[]::uuid[], array[]::text[]
    )
  $$,
  '55000',
  'A complete profile is required to create or publish a proposal.',
  'an incomplete profile cannot create a proposal draft'
);

select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.partial_proposal_id',
  public.create_proposal_draft(
    '91000000-0000-4000-8000-000000000001',
    '  Early idea  ',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    'participants',
    array[]::uuid[],
    array[]::text[]
  )::text,
  true
);

select results_eq(
  $$
    select lifecycle_state, title
    from public.proposals
    where id = current_setting('test.partial_proposal_id')::uuid
  $$,
  $$values ('draft'::text, 'Early idea'::text)$$,
  'a complete-profile owner can save an incomplete, canonically trimmed draft'
);
select is(
  (
    select count(*)
    from public.proposal_meeting_details
    where proposal_id = current_setting('test.partial_proposal_id')::uuid
      and exact_meeting_text is null
      and exact_location_visibility = 'participants'
  ),
  1::bigint,
  'draft creation atomically creates the protected meeting record'
);

select throws_ok(
  $$
    select public.publish_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.partial_proposal_id')::uuid
    )
  $$,
  '22023',
  'Published proposals require complete content, schedule, rough location, and exact meeting information.',
  'publication centrally rejects an incomplete draft'
);
select is(
  (
    select lifecycle_state
    from public.proposals
    where id = current_setting('test.partial_proposal_id')::uuid
  ),
  'draft',
  'failed publication leaves the draft state unchanged'
);

select throws_ok(
  $$
    select public.update_own_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.partial_proposal_id')::uuid,
      'Changed idea', null, null, null, null, null, null, null, null, null,
      null, 'participants',
      array['ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid],
      array['useful']::text[]
    )
  $$,
  '22023',
  'One or more proposal skills are not in the catalog.',
  'an atomic proposal update rejects unknown catalog skills'
);
select is(
  (
    select title
    from public.proposals
    where id = current_setting('test.partial_proposal_id')::uuid
  ),
  'Early idea',
  'a rejected atomic update leaves prior draft content unchanged'
);

select set_config(
  'test.restricted_proposal_id',
  public.create_proposal_draft(
    '91000000-0000-4000-8000-000000000001',
    '  Paint a neighborhood mural  ',
    '  Help turn a plain wall into a shared mural.  ',
    '  Bring ideas and help paint a colorful community design.  ',
    statement_timestamp() + interval '2 days',
    statement_timestamp() + interval '2 days 3 hours',
    'Europe/Rome',
    'it',
    '  Trento  ',
    '  Povo  ',
    '  Trento · Povo  ',
    '  Via Private 10, courtyard entrance  ',
    'participants',
    array['d0000000-0000-4000-8001-000000000001'::uuid],
    array['required']::text[]
  )::text,
  true
);

select results_eq(
  $$
    select country_code, locality, public_location_label
    from public.proposals
    where id = current_setting('test.restricted_proposal_id')::uuid
  $$,
  $$values ('IT'::text, 'Trento'::text, 'Trento · Povo'::text)$$,
  'rough location values are normalized without becoming exact meeting data'
);
select results_eq(
  $$
    select importance
    from public.proposal_skills
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  $$,
  $$values ('required'::text)$$,
  'proposal requirements reuse the controlled skill catalog with required semantics'
);
select lives_ok(
  $$
    select public.publish_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.restricted_proposal_id')::uuid
    )
  $$,
  'the owner can publish a valid draft'
);
select lives_ok(
  $$
    select public.publish_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.restricted_proposal_id')::uuid
    )
  $$,
  'repeating publication is idempotent'
);
select is(
  (
    select count(*)
    from private.audit_events
    where action = 'proposal.published'
      and target_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  1::bigint,
  'idempotent publication creates one minimal audit event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'proposal.published'
      and payload ->> 'proposal_id' = current_setting('test.restricted_proposal_id')
  ),
  1::bigint,
  'idempotent publication creates one outbox event'
);
select is(
  (
    select position(
      'Via Private 10' in coalesce(
        (
          select payload::text
          from private.outbox_events
          where event_type = 'proposal.published'
            and payload ->> 'proposal_id' = current_setting('test.restricted_proposal_id')
        ),
        ''
      )
    )
  ),
  0,
  'outbox payloads never contain exact meeting content'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '92000000-0000-4000-8000-000000000002',
  true
);

select is(
  (
    select count(*)
    from public.proposals
    where id = current_setting('test.restricted_proposal_id')::uuid
  ),
  0::bigint,
  'another authenticated user cannot directly read an owner proposal'
);
select is(
  (
    select count(*)
    from public.proposal_meeting_details
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  0::bigint,
  'another authenticated user cannot directly read exact meeting details'
);
select throws_ok(
  $$
    select public.update_own_proposal(
      '92000000-0000-4000-8000-000000000002',
      current_setting('test.restricted_proposal_id')::uuid,
      'Cross-account overwrite', 'Summary', 'Description',
      statement_timestamp() + interval '3 days',
      statement_timestamp() + interval '3 days 1 hour',
      'Europe/Rome', 'IT', 'Trento', null, 'Trento', 'Leaked', 'public',
      array[]::uuid[], array[]::text[]
    )
  $$,
  '42501',
  'The current user does not own this proposal.',
  'cross-user proposal mutation is denied centrally'
);

select set_config(
  'test.user_b_proposal_id',
  public.create_proposal_draft(
    '92000000-0000-4000-8000-000000000002',
    'User B draft', null, null, null, null, null, null, null, null, null,
    null, 'participants', array[]::uuid[], array[]::text[]
  )::text,
  true
);
select throws_ok(
  $$
    select public.update_own_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.user_b_proposal_id')::uuid,
      'Stale user A content', null, null, null, null, null, null, null, null,
      null, null, 'participants', array[]::uuid[], array[]::text[]
    )
  $$,
  '42501',
  'The authenticated user does not match the expected proposal creator.',
  'a stale user-A form cannot mutate the newly authenticated user-B account'
);
select is(
  (
    select title
    from public.proposals
    where id = current_setting('test.user_b_proposal_id')::uuid
  ),
  'User B draft',
  'stale-form rejection leaves the newly authenticated account unchanged'
);

reset role;
set local role anon;

select throws_ok(
  'select id from public.proposals',
  '42501',
  'permission denied for table proposals',
  'anonymous users cannot enumerate proposal rows directly'
);
select throws_ok(
  'select exact_meeting_text from public.proposal_meeting_details',
  '42501',
  'permission denied for table proposal_meeting_details',
  'anonymous users cannot enumerate exact meeting rows directly'
);
select is(
  (
    select count(*)
    from public.list_public_proposals(20, null, null, null, null)
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  1::bigint,
  'a published upcoming proposal appears in signed-out discovery'
);
select is(
  (
    select derived_status
    from public.list_public_proposals(20, null, null, null, null)
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  'upcoming',
  'public discovery returns the time-derived upcoming status'
);
select ok(
  (
    select skills @> '[{"slug":"mural-painting","importance":"required"}]'::jsonb
    from public.list_public_proposals(20, null, null, null, null)
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  'public cards contain controlled required/useful skill descriptors'
);
select is(
  (
    select position(
      'Via Private 10' in row_to_json(public_proposal)::text
    )
    from public.list_public_proposals(20, null, null, null, null) as public_proposal
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  0,
  'public list payloads never contain exact meeting information'
);
select results_eq(
  $$
    select exact_meeting_text, exact_location_restricted
    from public.get_public_proposal(
      current_setting('test.restricted_proposal_id')::uuid
    )
  $$,
  $$values (null::text, true)$$,
  'restricted public detail returns an explicit indicator without the exact value'
);
select is(
  (
    select position('Via Private 10' in row_to_json(public_detail)::text)
    from public.get_public_proposal(
      current_setting('test.restricted_proposal_id')::uuid
    ) as public_detail
  ),
  0,
  'restricted exact meeting content is absent from the complete public detail payload'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);

select is(
  (
    select exact_meeting_text
    from public.get_own_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.restricted_proposal_id')::uuid
    )
  ),
  'Via Private 10, courtyard entrance',
  'the creator can still read participant-restricted exact meeting information'
);

select set_config(
  'test.public_proposal_id',
  public.create_proposal_draft(
    '91000000-0000-4000-8000-000000000001',
    'Community repair workshop',
    'Repair useful household items together.',
    'Bring a small item and learn practical repair skills.',
    statement_timestamp() + interval '4 days',
    statement_timestamp() + interval '4 days 2 hours',
    'Europe/Rome',
    'IT',
    'Trento',
    'Centro storico',
    'Trento · Centro storico',
    'Piazza Pubblica, by the fountain',
    'public',
    array['d0000000-0000-4000-8003-000000000003'::uuid],
    array['useful']::text[]
  )::text,
  true
);
select lives_ok(
  $$
    select public.publish_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.public_proposal_id')::uuid
    )
  $$,
  'the owner can publish a proposal with public exact meeting information'
);
select lives_ok(
  $$
    select public.update_own_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.public_proposal_id')::uuid,
      'Updated community repair workshop',
      'Repair useful household items together.',
      'Bring a small item and learn practical repair skills.',
      statement_timestamp() + interval '4 days',
      statement_timestamp() + interval '4 days 2 hours',
      'Europe/Rome', 'IT', 'Trento', 'Centro storico',
      'Trento · Centro storico', 'Piazza Pubblica, by the fountain', 'public',
      array['d0000000-0000-4000-8003-000000000003'::uuid],
      array['useful']::text[]
    )
  $$,
  'the owner can edit an upcoming published proposal'
);

reset role;
set local role anon;

select is(
  (
    select exact_meeting_text
    from public.get_public_proposal(current_setting('test.public_proposal_id')::uuid)
  ),
  'Piazza Pubblica, by the fountain',
  'public exact meeting information appears only in exact-ID detail'
);
select is(
  (
    select position(
      'Piazza Pubblica' in row_to_json(public_proposal)::text
    )
    from public.list_public_proposals(20, null, null, null, null) as public_proposal
    where proposal_id = current_setting('test.public_proposal_id')::uuid
  ),
  0,
  'even public exact meeting information never appears on discovery cards'
);
select is(
  (
    select count(*)
    from public.list_public_proposals(
      20,
      null,
      null,
      ' trento ',
      array['d0000000-0000-4000-8001-000000000001'::uuid]
    )
  ),
  1::bigint,
  'public discovery filters by rough locality and selected controlled skills'
);
select is(
  (select count(*) from public.list_public_proposals(1, null, null, null, null)),
  1::bigint,
  'public discovery honors the bounded page size'
);
select throws_ok(
  $$select * from public.list_public_proposals(51, null, null, null, null)$$,
  '22023',
  'Proposal page size must be between 1 and 50.',
  'public discovery rejects an excessive page size'
);
select throws_ok(
  $$
    select *
    from public.list_public_proposals(
      20,
      statement_timestamp(),
      null,
      null,
      null
    )
  $$,
  '22023',
  'Proposal cursor values must be supplied together.',
  'public discovery rejects a partial cursor'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$
    select public.cancel_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.restricted_proposal_id')::uuid
    )
  $$,
  'the owner can terminally cancel an own published proposal before it ends'
);
select throws_ok(
  $$
    select public.cancel_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.restricted_proposal_id')::uuid
    )
  $$,
  '55000',
  'Only a published proposal can be cancelled.',
  'a cancelled proposal cannot be restored or cancelled twice'
);
select is(
  (
    select lifecycle_state
    from public.get_own_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.restricted_proposal_id')::uuid
    )
  ),
  'cancelled',
  'cancelled proposals remain canonical owner history'
);
select is(
  (
    select count(*)
    from private.audit_events
    where action = 'proposal.cancelled'
      and target_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  1::bigint,
  'cancellation records one minimal audit event'
);

reset role;
set local role anon;

select is(
  (
    select count(*)
    from public.list_public_proposals(20, null, null, null, null)
    where proposal_id = current_setting('test.restricted_proposal_id')::uuid
  ),
  0::bigint,
  'cancellation removes the proposal from normal discovery immediately'
);
select is(
  (
    select count(*)
    from public.get_public_proposal(current_setting('test.restricted_proposal_id')::uuid)
  ),
  0::bigint,
  'cancelled proposals are absent from public exact-ID detail'
);

reset role;

select is(
  private.derive_proposal_status(
    '2026-01-02 10:00:00+00',
    '2026-01-02 12:00:00+00',
    '2026-01-02 09:59:59+00'
  ),
  'upcoming',
  'status is upcoming immediately before the start boundary'
);
select is(
  private.derive_proposal_status(
    '2026-01-02 10:00:00+00',
    '2026-01-02 12:00:00+00',
    '2026-01-02 10:00:00+00'
  ),
  'happening',
  'status becomes happening exactly at the start boundary'
);
select is(
  private.derive_proposal_status(
    '2026-01-02 10:00:00+00',
    '2026-01-02 12:00:00+00',
    '2026-01-02 12:00:00+00'
  ),
  'just_finished',
  'status becomes just finished exactly at the end boundary'
);
select is(
  private.derive_proposal_status(
    '2026-01-02 10:00:00+00',
    '2026-01-02 12:00:00+00',
    '2026-01-03 11:59:59.999999+00'
  ),
  'just_finished',
  'just finished lasts until immediately before 24 hours after the end'
);
select is(
  private.derive_proposal_status(
    '2026-01-02 10:00:00+00',
    '2026-01-02 12:00:00+00',
    '2026-01-03 12:00:00+00'
  ),
  'completed',
  'status becomes historical exactly 24 hours after the end'
);

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  summary,
  description,
  starts_at,
  ends_at,
  event_timezone,
  country_code,
  locality,
  public_location_label,
  published_at
)
values
  (
    '94000000-0000-4000-8000-000000000004',
    '91000000-0000-4000-8000-000000000001',
    'published',
    'Recently finished proposal',
    'Visible for the 24-hour discovery window.',
    'A deterministic just-finished proposal.',
    statement_timestamp() - interval '25 hours',
    statement_timestamp() - interval '23 hours',
    'Europe/Rome',
    'IT',
    'Trento',
    'Trento · Povo',
    statement_timestamp() - interval '2 days'
  ),
  (
    '95000000-0000-4000-8000-000000000005',
    '91000000-0000-4000-8000-000000000001',
    'published',
    'Historical proposal',
    'Retained but excluded from normal discovery.',
    'A deterministic completed proposal.',
    statement_timestamp() - interval '27 hours',
    statement_timestamp() - interval '25 hours',
    'Europe/Rome',
    'IT',
    'Trento',
    'Trento · Povo',
    statement_timestamp() - interval '3 days'
  );

insert into public.proposal_meeting_details (
  proposal_id,
  exact_meeting_text,
  exact_location_visibility
)
values
  (
    '94000000-0000-4000-8000-000000000004',
    'Public recently finished place',
    'public'
  ),
  (
    '95000000-0000-4000-8000-000000000005',
    'Historical restricted place',
    'participants'
  );

set local role anon;

select is(
  (
    select derived_status
    from public.list_public_proposals(20, null, null, null, null)
    where proposal_id = '94000000-0000-4000-8000-000000000004'
  ),
  'just_finished',
  'normal discovery includes proposals inside the 24-hour just-finished window'
);
select is(
  (
    select count(*)
    from public.list_public_proposals(20, null, null, null, null)
    where proposal_id = '95000000-0000-4000-8000-000000000005'
  ),
  0::bigint,
  'normal discovery excludes proposals older than the 24-hour window'
);
select is(
  (
    select derived_status
    from public.get_public_proposal('95000000-0000-4000-8000-000000000005')
  ),
  'completed',
  'exact-ID public detail retains published historical proposals'
);

reset role;

select is(
  (
    select count(*)
    from public.proposals
    where id = '95000000-0000-4000-8000-000000000005'
  ),
  1::bigint,
  'completed proposals remain canonical historical data'
);

update public.proposals
set
  starts_at = statement_timestamp() - interval '2 hours',
  ends_at = statement_timestamp() + interval '2 hours'
where id = current_setting('test.public_proposal_id')::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select public.update_own_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.public_proposal_id')::uuid,
      'Late edit', 'Summary', 'Description',
      statement_timestamp() - interval '2 hours',
      statement_timestamp() + interval '2 hours',
      'Europe/Rome', 'IT', 'Trento', null, 'Trento', 'Meeting', 'public',
      array[]::uuid[], array[]::text[]
    )
  $$,
  '55000',
  'A published proposal cannot be edited after it starts.',
  'ordinary content and location edits freeze once a published proposal starts'
);

reset role;
update public.proposals
set
  starts_at = statement_timestamp() - interval '3 hours',
  ends_at = statement_timestamp() - interval '1 hour'
where id = current_setting('test.public_proposal_id')::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select public.cancel_proposal(
      '91000000-0000-4000-8000-000000000001',
      current_setting('test.public_proposal_id')::uuid
    )
  $$,
  '55000',
  'A proposal cannot be cancelled after it ends.',
  'owners cannot cancel a published proposal after its end time'
);

select throws_ok(
  $$
    insert into public.skills (id, category_id, slug, label, sort_order)
    values (
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
      'c0000000-0000-4000-8000-000000000001',
      'invented-proposal-skill',
      'Invented proposal skill',
      99
    )
  $$,
  '42501',
  'permission denied for table skills',
  'proposal authors cannot mutate the canonical skill catalog'
);

select * from finish();

rollback;
