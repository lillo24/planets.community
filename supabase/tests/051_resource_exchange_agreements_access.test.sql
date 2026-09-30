begin;

select no_plan();

-- These transaction-only grants and policies let the test inspect canonical
-- rows after RPC mutations. The final rollback restores production access.
grant select on table
  public.resource_listing_requests,
  public.resource_exchange_agreements,
  public.resource_exchange_agreement_terms,
  public.resource_exchange_agreement_events
to authenticated;
create policy resource_listing_requests_test_inspection
on public.resource_listing_requests for select to authenticated
using (true);
create policy resource_exchange_agreements_test_inspection
on public.resource_exchange_agreements for select to authenticated
using (true);
create policy resource_exchange_agreement_terms_test_inspection
on public.resource_exchange_agreement_terms for select to authenticated
using (true);
create policy resource_exchange_agreement_events_test_inspection
on public.resource_exchange_agreement_events for select to authenticated
using (true);

insert into auth.users (id, email)
values
  ('f5100000-0000-4000-8000-000000000001', 'agreement-owner@planets.invalid'),
  ('f5100000-0000-4000-8000-000000000002', 'agreement-requester-a@planets.invalid'),
  ('f5100000-0000-4000-8000-000000000003', 'agreement-requester-b@planets.invalid'),
  ('f5100000-0000-4000-8000-000000000004', 'agreement-requester-c@planets.invalid'),
  ('f5100000-0000-4000-8000-000000000005', 'agreement-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f5100000-0000-4000-8000-000000000001', 'Agreement Owner'),
  ('f5100000-0000-4000-8000-000000000002', 'Agreement Requester A'),
  ('f5100000-0000-4000-8000-000000000003', 'Agreement Requester B'),
  ('f5100000-0000-4000-8000-000000000004', 'Agreement Requester C'),
  ('f5100000-0000-4000-8000-000000000005', 'Agreement Unrelated');

insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/' || profile.id::text || '.webp',
  'interactions'
from public.profiles as profile
where profile.id::text like 'f5100000-0000-4000-8000-%';

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
    'f5200000-0000-4000-8000-000000000001',
    'f5100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Agreement workbench',
    'Original workbench description for server snapshots.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp()
  ),
  (
    'f5200000-0000-4000-8000-000000000002',
    'f5100000-0000-4000-8000-000000000001',
    'donate',
    'published',
    'Loan drill',
    'Drill used for bounded lending behavior.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp()
  ),
  (
    'f5200000-0000-4000-8000-000000000003',
    'f5100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Closure ladder',
    'Ladder used to prove private coordination survives listing closure.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp()
  ),
  (
    'f5200000-0000-4000-8000-000000000004',
    'f5100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Backfill saw',
    'Saw used for accepted-request agreement backfill.',
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
    'f5300000-0000-4000-8000-000000000001',
    'f5200000-0000-4000-8000-000000000004',
    'f5100000-0000-4000-8000-000000000002',
    'accepted',
    statement_timestamp(),
    'f5100000-0000-4000-8000-000000000001'
  ),
  (
    'f5300000-0000-4000-8000-000000000002',
    'f5200000-0000-4000-8000-000000000004',
    'f5100000-0000-4000-8000-000000000003',
    'rejected',
    statement_timestamp(),
    'f5100000-0000-4000-8000-000000000001'
  );

select is(
  private.ensure_resource_exchange_agreement_for_request(
    'f5300000-0000-4000-8000-000000000001',
    'f5100000-0000-4000-8000-000000000001'
  ),
  private.ensure_resource_exchange_agreement_for_request(
    'f5300000-0000-4000-8000-000000000001',
    'f5100000-0000-4000-8000-000000000001'
  ),
  'accepted-request backfill is idempotent and returns one anchor'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreements
    where request_id = 'f5300000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'an existing accepted request owns exactly one backfilled agreement'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreements
    where request_id = 'f5300000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'a rejected request has no agreement anchor'
);
select throws_ok(
  $$
    select private.ensure_resource_exchange_agreement_for_request(
      'f5300000-0000-4000-8000-000000000002',
      'f5100000-0000-4000-8000-000000000001'
    )
  $$,
  '55000',
  'Only an accepted resource listing request can own an agreement.',
  'the backfill helper rejects non-accepted requests'
);

set local role anon;
select throws_ok(
  $$
    select *
    from public.get_resource_exchange_agreement(
      'f5100000-0000-4000-8000-000000000002',
      'f5300000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function get_resource_exchange_agreement',
  'anonymous users cannot execute private agreement reads'
);
select throws_ok(
  $$select id from public.resource_exchange_agreements$$,
  '42501',
  'permission denied for table resource_exchange_agreements',
  'anonymous users cannot enumerate private agreement rows'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.main_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000002',
    'f5200000-0000-4000-8000-000000000001',
    'Private request context'
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.accept_resource_listing_request(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_request')::uuid
  ),
  current_setting('test.main_request')::uuid,
  'request acceptance succeeds'
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
    select lifecycle_state, current_terms_id, pending_terms_id
    from public.resource_exchange_agreements
    where id = current_setting('test.main_agreement')::uuid
  $$,
  $$values ('negotiating'::text, null::uuid, null::uuid)$$,
  'acceptance atomically creates one negotiating agreement anchor'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreement_events
    where agreement_id = current_setting('test.main_agreement')::uuid
      and event_kind = 'agreement_created'
  ),
  1::bigint,
  'acceptance records one structured agreement-created event'
);
select is(
  (
    select count(*)
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.main_agreement')::uuid
    )
  ),
  0::bigint,
  'an agreement without proposals returns an empty terms list'
);

select set_config(
  'test.terms_one',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    null,
    null,
    'give',
    null,
    null,
    'give',
    'Bookshelf offered in return',
    null,
    null,
    'Private proposal note'
  )::text,
  true
);
select results_eq(
  $$
    select
      terms_id,
      is_current,
      is_pending,
      jsonb_typeof(to_jsonb(projected) -> 'is_current'),
      jsonb_typeof(to_jsonb(projected) -> 'is_pending')
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.main_agreement')::uuid
    ) as projected
  $$,
  format(
    $expected$
      values (%L::uuid, false, true, 'boolean'::text, 'boolean'::text)
    $expected$,
    current_setting('test.terms_one')
  ),
  'a first pending proposal projects non-null false/true JSON booleans'
);
select results_eq(
  $$
    select
      version_number,
      listing_title_snapshot,
      listing_description_snapshot,
      owner_transfer_kind,
      requester_transfer_kind,
      requester_resource_description,
      private_note
    from public.resource_exchange_agreement_terms
    where id = current_setting('test.terms_one')::uuid
  $$,
  $$
    values (
      1,
      'Agreement workbench'::text,
      'Original workbench description for server snapshots.'::text,
      'give'::text,
      'give'::text,
      'Bookshelf offered in return'::text,
      'Private proposal note'::text
    )
  $$,
  'terms snapshot listing content server-side and normalize two-leg input'
);
select throws_ok(
  format(
    $query$
      select public.accept_resource_exchange_terms(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid,
        %L::uuid
      )
    $query$,
    current_setting('test.main_agreement'),
    current_setting('test.terms_one')
  ),
  '42501',
  'A terms proposer cannot accept their own proposal.',
  'a proposer cannot self-accept'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.terms_two',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000002',
    current_setting('test.main_agreement')::uuid,
    null,
    current_setting('test.terms_one')::uuid,
    'give',
    null,
    null,
    'lend',
    'Pressure washer loaned in return',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '10 days',
    null
  )::text,
  true
);
select results_eq(
  $$
    select event_kind, terms_id
    from public.resource_exchange_agreement_events
    where agreement_id = current_setting('test.main_agreement')::uuid
      and event_kind in ('terms_superseded', 'terms_proposed')
    order by created_at, id
  $$,
  format(
    $expected$
      values
        ('terms_proposed'::text, %L::uuid),
        ('terms_superseded'::text, %L::uuid),
        ('terms_proposed'::text, %L::uuid)
    $expected$,
    current_setting('test.terms_one'),
    current_setting('test.terms_one'),
    current_setting('test.terms_two')
  ),
  'counter-proposal preserves the old immutable version and records supersession'
);
select results_eq(
  $$
    select terms_id, is_current, is_pending,
      jsonb_typeof(to_jsonb(projected) -> 'is_current'),
      jsonb_typeof(to_jsonb(projected) -> 'is_pending')
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000002',
      current_setting('test.main_agreement')::uuid
    ) as projected
    order by version_number desc
  $$,
  format(
    $expected$
      values
        (%L::uuid, false, true, 'boolean'::text, 'boolean'::text),
        (%L::uuid, false, false, 'boolean'::text, 'boolean'::text)
    $expected$,
    current_setting('test.terms_two'),
    current_setting('test.terms_one')
  ),
  'a pending counter-proposal leaves its superseded version false/false'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.accept_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid
  ),
  current_setting('test.terms_two')::uuid,
  'the non-proposer accepts the exact pending counter-proposal'
);
select results_eq(
  $$
    select lifecycle_state, current_terms_id, pending_terms_id
    from public.resource_exchange_agreements
    where id = current_setting('test.main_agreement')::uuid
  $$,
  format(
    $expected$values ('agreed'::text, %L::uuid, null::uuid)$expected$,
    current_setting('test.terms_two')
  ),
  'accepted immutable terms become current and clear pending'
);
select results_eq(
  $$
    select terms_id, is_current, is_pending,
      jsonb_typeof(to_jsonb(projected) -> 'is_current'),
      jsonb_typeof(to_jsonb(projected) -> 'is_pending')
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.main_agreement')::uuid
    ) as projected
    order by version_number desc
  $$,
  format(
    $expected$
      values
        (%L::uuid, true, false, 'boolean'::text, 'boolean'::text),
        (%L::uuid, false, false, 'boolean'::text, 'boolean'::text)
    $expected$,
    current_setting('test.terms_two'),
    current_setting('test.terms_one')
  ),
  'accepted current terms and historical terms project true/false and false/false'
);
reset role;
select set_config(
  'test.read_audit_count',
  (select count(*)::text from private.audit_events),
  true
);
select set_config(
  'test.read_outbox_count',
  (select count(*)::text from private.outbox_events),
  true
);
select set_config(
  'test.read_agreement_event_count',
  (select count(*)::text from public.resource_exchange_agreement_events),
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.main_agreement')::uuid
    )
  ),
  2::bigint,
  'the terms projection remains readable after acceptance'
);
reset role;
select is(
  (select count(*) from private.audit_events),
  current_setting('test.read_audit_count')::bigint,
  'reading projected flags creates no audit event'
);
select is(
  (select count(*) from private.outbox_events),
  current_setting('test.read_outbox_count')::bigint,
  'reading projected flags creates no outbox event'
);
select is(
  (select count(*) from public.resource_exchange_agreement_events),
  current_setting('test.read_agreement_event_count')::bigint,
  'reading projected flags creates no agreement-history event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  format(
    $query$
      select public.propose_resource_exchange_terms(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid,
        null,
        null,
        'give', null, null,
        'none', null, null, null, null
      )
    $query$,
    current_setting('test.main_agreement')
  ),
  'PT409',
  'The resource exchange agreement terms changed since they were loaded.',
  'stale current/pending pointers fail with PT409'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000005',
  true
);
select is(
  (
    select count(*)
    from public.get_resource_exchange_agreement(
      'f5100000-0000-4000-8000-000000000005',
      current_setting('test.main_request')::uuid
    )
  ),
  0::bigint,
  'an unrelated authenticated user cannot read an agreement by request ID'
);
select throws_ok(
  format(
    $query$
      select *
      from public.list_resource_exchange_agreement_terms(
        'f5100000-0000-4000-8000-000000000005',
        %L::uuid
      )
    $query$,
    current_setting('test.main_agreement')
  ),
  '42501',
  'The current user cannot read this resource exchange agreement.',
  'an unrelated authenticated user cannot list private terms'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.shape_give_none',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid,
    null,
    'give', null, null,
    'none', null, null, null,
    '   '
  )::text,
  true
);
select is(
  (
    select bool_and(is_current is not null and is_pending is not null)
      and bool_and(
        jsonb_typeof(to_jsonb(projected) -> 'is_current') = 'boolean'
        and jsonb_typeof(to_jsonb(projected) -> 'is_pending') = 'boolean'
      )
      and count(*) filter (where is_current) = 1
      and count(*) filter (where is_pending) = 1
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.main_agreement')::uuid
    ) as projected
  ),
  true,
  'a current version plus pending replacement has one non-null true flag each'
);
select is(
  (
    select private_note
    from public.resource_exchange_agreement_terms
    where id = current_setting('test.shape_give_none')::uuid
  ),
  null,
  'blank private notes normalize to null'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select is(
  public.reject_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000002',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.shape_give_none')::uuid
  ),
  current_setting('test.shape_give_none')::uuid,
  'the non-proposer may reject give to none terms'
);
select results_eq(
  $$
    select is_current, is_pending,
      jsonb_typeof(to_jsonb(projected) -> 'is_current'),
      jsonb_typeof(to_jsonb(projected) -> 'is_pending')
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000002',
      current_setting('test.main_agreement')::uuid
    ) as projected
    where terms_id = current_setting('test.shape_give_none')::uuid
  $$,
  $$values (false, false, 'boolean'::text, 'boolean'::text)$$,
  'a rejected replacement becomes a historical false/false row'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.shape_lend_none',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid,
    null,
    'lend',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    'none', null, null, null, null
  )::text,
  true
);
select is(
  public.withdraw_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.shape_lend_none')::uuid
  ),
  current_setting('test.shape_lend_none')::uuid,
  'the proposer may withdraw lend to none terms'
);
select is(
  (
    select bool_and(is_current is not null and is_pending is not null)
      and bool_and(
        jsonb_typeof(to_jsonb(projected) -> 'is_current') = 'boolean'
        and jsonb_typeof(to_jsonb(projected) -> 'is_pending') = 'boolean'
      )
      and count(*) filter (where is_current) = 1
      and count(*) filter (where is_pending) = 0
      and bool_and(
        case
          when terms_id = current_setting('test.terms_two')::uuid
            then is_current and not is_pending
          else not is_current and not is_pending
        end
      )
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.main_agreement')::uuid
    ) as projected
  ),
  true,
  'a withdrawn replacement is historical while accepted current terms remain true/false'
);

select set_config(
  'test.shape_lend_give',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid,
    null,
    'lend',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    'give', 'Timber supplied in return', null, null, null
  )::text,
  true
);
select is(
  public.withdraw_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.shape_lend_give')::uuid
  ),
  current_setting('test.shape_lend_give')::uuid,
  'lend to give terms are valid and withdrawable'
);

select set_config(
  'test.shape_lend_lend',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid,
    null,
    'lend',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    'lend',
    'Pressure washer supplied temporarily',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '3 days',
    null
  )::text,
  true
);
select is(
  public.withdraw_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.shape_lend_lend')::uuid
  ),
  current_setting('test.shape_lend_lend')::uuid,
  'lend to lend terms are valid and withdrawable'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreement_terms
    where agreement_id = current_setting('test.main_agreement')::uuid
      and (
        (owner_transfer_kind = 'give' and requester_transfer_kind = 'none')
        or (owner_transfer_kind = 'lend' and requester_transfer_kind = 'none')
        or (owner_transfer_kind = 'give' and requester_transfer_kind = 'give')
        or (owner_transfer_kind = 'give' and requester_transfer_kind = 'lend')
        or (owner_transfer_kind = 'lend' and requester_transfer_kind = 'give')
        or (owner_transfer_kind = 'lend' and requester_transfer_kind = 'lend')
      )
  ),
  6::bigint,
  'all six supported two-leg transfer combinations are retained as versions'
);

select throws_ok(
  format(
    $query$
      select public.propose_resource_exchange_terms(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid, %L::uuid, null,
        'lend', null, null,
        'none', null, null, null, null
      )
    $query$,
    current_setting('test.main_agreement'),
    current_setting('test.terms_two')
  ),
  '22023',
  'A lend owner leg requires a bounded increasing period.',
  'owner lending requires both increasing timestamps'
);
select throws_ok(
  format(
    $query$
      select public.propose_resource_exchange_terms(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid, %L::uuid, null,
        'give', null, null,
        'none', 'unexpected resource', null, null, null
      )
    $query$,
    current_setting('test.main_agreement'),
    current_setting('test.terms_two')
  ),
  '22023',
  'A none requester leg cannot contain a resource or lending dates.',
  'requester none rejects resource content'
);
select throws_ok(
  format(
    $query$
      select public.propose_resource_exchange_terms(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid, %L::uuid, null,
        'give', null, null,
        'give', 'x', null, null, null
      )
    $query$,
    current_setting('test.main_agreement'),
    current_setting('test.terms_two')
  ),
  '22023',
  'A requester resource description must contain 2 to 500 characters.',
  'requester give/lend description is bounded'
);

reset role;
select throws_ok(
  format(
    'update public.resource_exchange_agreement_terms set private_note = %L where id = %L::uuid',
    'rewritten history',
    current_setting('test.terms_one')
  ),
  '55000',
  'Resource exchange agreement terms are immutable.',
  'accepted and historical terms cannot be mutated'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  format(
    $query$
      select public.record_resource_exchange_milestone(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid,
        %L::uuid,
        'requester_resource',
        'resource_provided'
      )
    $query$,
    current_setting('test.main_agreement'),
    current_setting('test.terms_two')
  ),
  '42501',
  'Only the provider or recipient assigned to this milestone may record it.',
  'owner cannot claim the requester provided their resource'
);
select set_config(
  'test.owner_provided_event',
  public.record_resource_exchange_milestone(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid,
    'owner_resource',
    'resource_provided'
  )::text,
  true
);
select is(
  (
    select agreement.lifecycle_state = 'in_progress'
      and bool_and(projected.is_current is not null)
      and bool_and(projected.is_pending is not null)
      and bool_and(
        jsonb_typeof(to_jsonb(projected) -> 'is_current') = 'boolean'
        and jsonb_typeof(to_jsonb(projected) -> 'is_pending') = 'boolean'
      )
      and count(*) filter (where projected.is_current) = 1
      and count(*) filter (where projected.is_pending) = 0
      and bool_and(
        case
          when projected.terms_id = current_setting('test.terms_two')::uuid
            then projected.is_current and not projected.is_pending
          else not projected.is_current and not projected.is_pending
        end
      )
    from public.resource_exchange_agreements as agreement
    cross join lateral public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      agreement.id
    ) as projected
    where agreement.id = current_setting('test.main_agreement')::uuid
    group by agreement.lifecycle_state
  ),
  true,
  'in-progress projection keeps one current true/false row and historical false/false rows'
);
select is(
  public.record_resource_exchange_milestone(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.main_agreement')::uuid,
    current_setting('test.terms_two')::uuid,
    'owner_resource',
    'resource_provided'
  ),
  current_setting('test.owner_provided_event')::uuid,
  'duplicate canonical milestone returns existing success'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreement_events
    where agreement_id = current_setting('test.main_agreement')::uuid
      and terms_id = current_setting('test.terms_two')::uuid
      and leg_kind = 'owner_resource'
      and event_kind = 'resource_provided'
  ),
  1::bigint,
  'duplicate milestone creates no duplicate history'
);
select throws_ok(
  format(
    $query$
      select public.propose_resource_exchange_terms(
        'f5100000-0000-4000-8000-000000000001',
        %L::uuid, %L::uuid, null,
        'give', null, null,
        'none', null, null, null, null
      )
    $query$,
    current_setting('test.main_agreement'),
    current_setting('test.terms_two')
  ),
  'PT409',
  'Agreement terms are frozen after handoff begins or coordination closes.',
  'the first milestone freezes terms'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000002',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.terms_two')::uuid,
  'owner_resource',
  'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000002',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.terms_two')::uuid,
  'requester_resource',
  'resource_provided'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.terms_two')::uuid,
  'requester_resource',
  'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.terms_two')::uuid,
  'requester_resource',
  'resource_returned'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000002',
  current_setting('test.main_agreement')::uuid,
  current_setting('test.terms_two')::uuid,
  'requester_resource',
  'resource_return_received'
);
select results_eq(
  $$
    select lifecycle_state, completed_at is not null
    from public.resource_exchange_agreements
    where id = current_setting('test.main_agreement')::uuid
  $$,
  $$values ('completed'::text, true)$$,
  'all required give plus lend confirmations auto-complete the agreement'
);
select is(
  (
    select bool_and(is_current is not null and is_pending is not null)
      and bool_and(
        jsonb_typeof(to_jsonb(projected) -> 'is_current') = 'boolean'
        and jsonb_typeof(to_jsonb(projected) -> 'is_pending') = 'boolean'
      )
      and count(*) filter (where is_current) = 1
      and count(*) filter (where is_pending) = 0
      and bool_and(
        case
          when terms_id = current_setting('test.terms_two')::uuid
            then is_current and not is_pending
          else not is_current and not is_pending
        end
      )
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000002',
      current_setting('test.main_agreement')::uuid
    ) as projected
  ),
  true,
  'completed projection retains current true/false and historical false/false rows'
);
select results_eq(
  $$
    select status, coordination_closed_at is not null,
      coordination_closed_by_profile_id
    from public.resource_listing_requests
    where id = current_setting('test.main_request')::uuid
  $$,
  $$
    values (
      'accepted'::text,
      true,
      'f5100000-0000-4000-8000-000000000002'::uuid
    )
  $$,
  'completion closes coordination while preserving accepted request history'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreement_events
    where agreement_id = current_setting('test.main_agreement')::uuid
      and event_kind = 'agreement_completed'
  ),
  1::bigint,
  'automatic completion is recorded exactly once'
);
select results_eq(
  $$
    select active_request_count
    from public.get_public_resource_listing(
      'f5200000-0000-4000-8000-000000000001'
    )
  $$,
  $$values (0::bigint)$$,
  'completed coordination no longer counts as active public interest'
);
select set_config(
  'test.repeat_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000002',
    'f5200000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select ok(
  current_setting('test.repeat_request')::uuid is not null,
  'the same requester may start a new episode after completion'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events as event
    cross join lateral jsonb_object_keys(event.payload) as payload_key
    where event.event_type like 'resource_exchange.%'
      and payload_key not in (
        'agreement_id',
        'request_id',
        'listing_id',
        'owner_profile_id',
        'requester_profile_id',
        'terms_id',
        'agreement_event_id',
        'actor_profile_id'
      )
  ),
  0::bigint,
  'agreement outbox events contain identifier keys only'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type like 'resource_exchange.%'
      and (
        payload::text like '%Private proposal note%'
        or payload::text like '%Pressure washer loaned in return%'
        or payload::text like '%Original workbench description%'
      )
  ),
  0::bigint,
  'agreement outbox events contain no private terms or listing snapshot text'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.repeat_request')::uuid
);
select set_config(
  'test.cancel_negotiating_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.repeat_request')::uuid
  ),
  true
);
select set_config(
  'test.cancel_withdrawn_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.cancel_negotiating_agreement')::uuid,
    null,
    null,
    'give', null, null,
    'none', null, null, null, null
  )::text,
  true
);
select public.withdraw_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.cancel_negotiating_agreement')::uuid,
  current_setting('test.cancel_withdrawn_terms')::uuid
);
select set_config(
  'test.cancel_rejected_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.cancel_negotiating_agreement')::uuid,
    null,
    null,
    'give', null, null,
    'none', null, null, null, null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select public.reject_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000002',
  current_setting('test.cancel_negotiating_agreement')::uuid,
  current_setting('test.cancel_rejected_terms')::uuid
);
select is(
  public.cancel_resource_exchange_agreement(
    'f5100000-0000-4000-8000-000000000002',
    current_setting('test.cancel_negotiating_agreement')::uuid
  ),
  current_setting('test.cancel_negotiating_agreement')::uuid,
  'the requester may cancel negotiating coordination before handoff'
);
select results_eq(
  $$
    select agreement.lifecycle_state, request.status,
      request.coordination_closed_at is not null
    from public.resource_exchange_agreements as agreement
    join public.resource_listing_requests as request
      on request.id = agreement.request_id
    where agreement.id =
      current_setting('test.cancel_negotiating_agreement')::uuid
  $$,
  $$values ('cancelled'::text, 'accepted'::text, true)$$,
  'cancellation closes coordination but retains accepted request history'
);
select is(
  (
    select bool_and(
      is_current is not null
      and is_pending is not null
      and not is_current
      and not is_pending
      and jsonb_typeof(to_jsonb(projected) -> 'is_current') = 'boolean'
      and jsonb_typeof(to_jsonb(projected) -> 'is_pending') = 'boolean'
    )
      and count(*) = 2
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000002',
      current_setting('test.cancel_negotiating_agreement')::uuid
    ) as projected
  ),
  true,
  'cancelled pending-only agreement retains rejected and withdrawn false/false history'
);
select set_config(
  'test.after_cancel_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000002',
    'f5200000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select ok(
  current_setting('test.after_cancel_request')::uuid is not null,
  'the same requester may request again after cancellation'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.after_cancel_request')::uuid
);
select set_config(
  'test.cancel_agreed_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.after_cancel_request')::uuid
  ),
  true
);
select set_config(
  'test.cancel_agreed_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.cancel_agreed_agreement')::uuid,
    null,
    null,
    'give', null, null,
    'none', null, null, null, null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000002',
  true
);
select public.accept_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000002',
  current_setting('test.cancel_agreed_agreement')::uuid,
  current_setting('test.cancel_agreed_terms')::uuid
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select is(
  public.cancel_resource_exchange_agreement(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.cancel_agreed_agreement')::uuid
  ),
  current_setting('test.cancel_agreed_agreement')::uuid,
  'the owner may cancel agreed coordination before handoff'
);
select is(
  (
    select count(*)
    from public.resource_exchange_agreement_terms
    where agreement_id =
      current_setting('test.cancel_agreed_agreement')::uuid
  ),
  1::bigint,
  'cancellation retains accepted immutable terms history'
);
select results_eq(
  $$
    select terms_id, is_current, is_pending,
      jsonb_typeof(to_jsonb(projected) -> 'is_current'),
      jsonb_typeof(to_jsonb(projected) -> 'is_pending')
    from public.list_resource_exchange_agreement_terms(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.cancel_agreed_agreement')::uuid
    ) as projected
  $$,
  format(
    $expected$
      values (%L::uuid, true, false, 'boolean'::text, 'boolean'::text)
    $expected$,
    current_setting('test.cancel_agreed_terms')
  ),
  'cancelled agreement retains accepted current terms as true/false booleans'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.overdue_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000003',
    'f5200000-0000-4000-8000-000000000002',
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.overdue_request')::uuid
);
select set_config(
  'test.overdue_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.overdue_request')::uuid
  ),
  true
);
select set_config(
  'test.future_loan_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.overdue_agreement')::uuid,
    null,
    null,
    'lend',
    statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days',
    'none', null, null, null, null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select public.accept_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.overdue_agreement')::uuid,
  current_setting('test.future_loan_terms')::uuid
);
select results_eq(
  $$
    select owner_lend_return_overdue, requester_lend_return_overdue
    from public.get_resource_exchange_agreement(
      'f5100000-0000-4000-8000-000000000003',
      current_setting('test.overdue_request')::uuid
    )
  $$,
  $$values (false, false)$$,
  'a future lend deadline is not overdue'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.past_loan_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.overdue_agreement')::uuid,
    current_setting('test.future_loan_terms')::uuid,
    null,
    'lend',
    statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day',
    'none', null, null, null, null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select public.accept_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.overdue_agreement')::uuid,
  current_setting('test.past_loan_terms')::uuid
);
select results_eq(
  $$
    select owner_lend_return_overdue, requester_lend_return_overdue
    from public.get_resource_exchange_agreement(
      'f5100000-0000-4000-8000-000000000003',
      current_setting('test.overdue_request')::uuid
    )
  $$,
  $$values (true, false)$$,
  'a past lend deadline remains derived overdue until return receipt'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.overdue_agreement')::uuid,
  current_setting('test.past_loan_terms')::uuid,
  'owner_resource',
  'resource_provided'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.overdue_agreement')::uuid,
  current_setting('test.past_loan_terms')::uuid,
  'owner_resource',
  'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.overdue_agreement')::uuid,
  current_setting('test.past_loan_terms')::uuid,
  'owner_resource',
  'resource_returned'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.overdue_agreement')::uuid,
  current_setting('test.past_loan_terms')::uuid,
  'owner_resource',
  'resource_return_received'
);
select results_eq(
  $$
    select lifecycle_state, owner_lend_return_overdue
    from public.get_resource_exchange_agreement(
      'f5100000-0000-4000-8000-000000000001',
      current_setting('test.overdue_request')::uuid
    )
  $$,
  $$values ('completed'::text, false)$$,
  'return receipt completes a one-leg lend and clears derived overdue truth'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.close_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000004',
    'f5200000-0000-4000-8000-000000000003',
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.close_request')::uuid
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
select set_config(
  'test.close_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.close_agreement')::uuid,
    null,
    null,
    'give', null, null,
    'none', null, null, null, null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select public.accept_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.close_agreement')::uuid,
  current_setting('test.close_terms')::uuid
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.close_agreement')::uuid,
  current_setting('test.close_terms')::uuid,
  'owner_resource',
  'resource_provided'
);
select public.close_resource_listing(
  'f5100000-0000-4000-8000-000000000001',
  'f5200000-0000-4000-8000-000000000003'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select throws_ok(
  format(
    $query$
      select public.cancel_resource_exchange_agreement(
        'f5100000-0000-4000-8000-000000000004',
        %L::uuid
      )
    $query$,
    current_setting('test.close_agreement')
  ),
  'PT409',
  'An agreement cannot be cancelled after handoff begins or coordination closes.',
  'cancellation loses cleanly after the first milestone'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.close_agreement')::uuid,
  current_setting('test.close_terms')::uuid,
  'owner_resource',
  'resource_received'
);
select results_eq(
  $$
    select lifecycle_state
    from public.get_resource_exchange_agreement(
      'f5100000-0000-4000-8000-000000000004',
      current_setting('test.close_request')::uuid
    )
  $$,
  $$values ('completed'::text)$$,
  'accepted private coordination remains readable and completable after listing close'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.two_give_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000003',
    'f5200000-0000-4000-8000-000000000004',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_give_request')::uuid
);
select set_config(
  'test.two_give_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.two_give_request')::uuid
  ),
  true
);
select set_config(
  'test.two_give_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.two_give_agreement')::uuid,
    null,
    null,
    'give', null, null,
    'give', 'Hand tools offered in return', null, null, null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select public.accept_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.two_give_agreement')::uuid,
  current_setting('test.two_give_terms')::uuid
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_give_agreement')::uuid,
  current_setting('test.two_give_terms')::uuid,
  'owner_resource',
  'resource_provided'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000003',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.two_give_agreement')::uuid,
  current_setting('test.two_give_terms')::uuid,
  'owner_resource',
  'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000003',
  current_setting('test.two_give_agreement')::uuid,
  current_setting('test.two_give_terms')::uuid,
  'requester_resource',
  'resource_provided'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_give_agreement')::uuid,
  current_setting('test.two_give_terms')::uuid,
  'requester_resource',
  'resource_received'
);
select is(
  (
    select lifecycle_state
    from public.resource_exchange_agreements
    where id = current_setting('test.two_give_agreement')::uuid
  ),
  'completed'::text,
  'two give legs complete only after both provider/recipient pairs exist'
);

select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.two_lend_request',
  public.request_resource_listing(
    'f5100000-0000-4000-8000-000000000004',
    'f5200000-0000-4000-8000-000000000004',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.accept_resource_listing_request(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_lend_request')::uuid
);
select set_config(
  'test.two_lend_agreement',
  (
    select id::text
    from public.resource_exchange_agreements
    where request_id = current_setting('test.two_lend_request')::uuid
  ),
  true
);
select set_config(
  'test.two_lend_terms',
  public.propose_resource_exchange_terms(
    'f5100000-0000-4000-8000-000000000001',
    current_setting('test.two_lend_agreement')::uuid,
    null,
    null,
    'lend', statement_timestamp(), statement_timestamp() + interval '7 days',
    'lend', 'Reciprocal tool loan', statement_timestamp(),
    statement_timestamp() + interval '7 days', null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select public.accept_resource_exchange_terms(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'owner_resource',
  'resource_provided'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'owner_resource',
  'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'owner_resource',
  'resource_returned'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'requester_resource',
  'resource_provided'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000001',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'owner_resource',
  'resource_return_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'requester_resource',
  'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000001',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'requester_resource',
  'resource_returned'
);
select set_config(
  'request.jwt.claim.sub',
  'f5100000-0000-4000-8000-000000000004',
  true
);
select public.record_resource_exchange_milestone(
  'f5100000-0000-4000-8000-000000000004',
  current_setting('test.two_lend_agreement')::uuid,
  current_setting('test.two_lend_terms')::uuid,
  'requester_resource',
  'resource_return_received'
);
select is(
  (
    select lifecycle_state
    from public.resource_exchange_agreements
    where id = current_setting('test.two_lend_agreement')::uuid
  ),
  'completed'::text,
  'two lend legs complete only after all eight statements exist'
);
select is(
  (
    select count(*)
    from public.get_public_resource_listing(
      'f5200000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'the closed listing remains absent from public detail'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type like 'resource_exchange.%'
      and event_type not in (
        'resource_exchange.agreement_created',
        'resource_exchange.terms_proposed',
        'resource_exchange.terms_superseded',
        'resource_exchange.terms_accepted',
        'resource_exchange.terms_rejected',
        'resource_exchange.terms_withdrawn',
        'resource_exchange.agreement_cancelled',
        'resource_exchange.milestone_recorded',
        'resource_exchange.agreement_completed'
      )
  ),
  0::bigint,
  'only the bounded agreement transition event taxonomy is emitted'
);

select * from finish();

rollback;
