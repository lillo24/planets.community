-- A listing is one reservable lending unit. Only its owner-side accepted LEND
-- terms reserve time; requester-side free text has no canonical resource ID.
-- Existing listing_id and request_id indexes support this join without a
-- second mutable reservation table or a redundant terms-period index.
create function private.active_resource_listing_loan_reservations(
  p_listing_id uuid default null
)
returns table (
  listing_id uuid,
  agreement_id uuid,
  request_id uuid,
  terms_id uuid,
  requester_profile_id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  agreement_lifecycle text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    request.listing_id,
    agreement.id,
    request.id,
    terms.id,
    request.requester_profile_id,
    terms.owner_lend_starts_at,
    terms.owner_lend_ends_at,
    agreement.lifecycle_state
  from public.resource_listing_requests as request
  join public.resource_exchange_agreements as agreement
    on agreement.request_id = request.id
  join public.resource_exchange_agreement_terms as terms
    on terms.id = agreement.current_terms_id
    and terms.agreement_id = agreement.id
  where (p_listing_id is null or request.listing_id = p_listing_id)
    and agreement.lifecycle_state in ('agreed', 'in_progress')
    and terms.owner_transfer_kind = 'lend';
$$;

create function private.resource_listing_loan_period_conflicts(
  p_listing_id uuid,
  p_exclude_agreement_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns boolean
language plpgsql
-- A fresh post-lock snapshot must see another agreement's committed accept.
volatile
security definer
set search_path = ''
as $$
begin
  if p_listing_id is null
    or p_exclude_agreement_id is null
    or p_starts_at is null
    or p_ends_at is null
    or p_ends_at <= p_starts_at then
    raise exception using
      errcode = '22023',
      message = 'A loan conflict check requires a bounded increasing period.';
  end if;

  return exists (
    select 1
    from private.active_resource_listing_loan_reservations(p_listing_id) as reservation
    where reservation.listing_id = p_listing_id
      and reservation.agreement_id <> p_exclude_agreement_id
      and p_starts_at < reservation.ends_at
      and reservation.starts_at < p_ends_at
  );
end;
$$;

-- The same predicate backs the existing agreement read and the owner
-- schedule. A return assertion alone is not a completed agreement, but the
-- owner's canonical return receipt ends the overdue indicator immediately.
create function private.resource_exchange_owner_lend_is_overdue(
  p_agreement_id uuid,
  p_terms_id uuid,
  p_owner_transfer_kind text,
  p_ends_at timestamptz,
  p_lifecycle_state text,
  p_as_of timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    p_owner_transfer_kind = 'lend'
    and p_as_of > p_ends_at
    and p_lifecycle_state not in ('cancelled', 'completed')
    and not exists (
      select 1
      from public.resource_exchange_agreement_events as owner_return_event
      where owner_return_event.agreement_id = p_agreement_id
        and owner_return_event.terms_id = p_terms_id
        and owner_return_event.leg_kind = 'owner_resource'
        and owner_return_event.event_kind = 'resource_return_received'
    ),
    false
  );
$$;

-- Fail deployment rather than silently accepting a pre-existing conflict.
-- No historical rows are rewritten or arbitrarily de-prioritized.
do $$
begin
  if exists (
    select 1
    from private.active_resource_listing_loan_reservations() as earlier
    join private.active_resource_listing_loan_reservations() as later
      on later.listing_id = earlier.listing_id
      and later.agreement_id > earlier.agreement_id
      and earlier.starts_at < later.ends_at
      and later.starts_at < earlier.ends_at
  ) then
    raise exception using
      errcode = '23514',
      message = 'Existing accepted owner-side loans overlap; resolve before applying the reservation domain.';
  end if;
end;
$$;

create or replace function public.accept_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  pending_terms public.resource_exchange_agreement_terms%rowtype;
  transition_time timestamptz := statement_timestamp();
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id
  for update;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may accept terms.';
  end if;

  if agreement.pending_terms_id is distinct from p_expected_pending_terms_id
    or agreement.pending_terms_id is null then
    raise sqlstate 'PT409'
      using message = 'The pending resource exchange terms changed since they were loaded.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed')
    or exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.event_kind in (
          'resource_provided',
          'resource_received',
          'resource_returned',
          'resource_return_received'
        )
    ) then
    raise sqlstate 'PT409'
      using message = 'Agreement terms are frozen after handoff begins or coordination closes.';
  end if;

  select * into pending_terms
  from public.resource_exchange_agreement_terms
  where id = agreement.pending_terms_id
    and agreement_id = agreement.id;

  if pending_terms.proposed_by_profile_id = current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'A terms proposer cannot accept their own proposal.';
  end if;

  if pending_terms.owner_transfer_kind = 'lend'
    and private.resource_listing_loan_period_conflicts(
      request.listing_id,
      agreement.id,
      pending_terms.owner_lend_starts_at,
      pending_terms.owner_lend_ends_at
    ) then
    raise sqlstate 'PT409'
      using message = 'The listing already has an accepted loan for that period.';
  end if;

  update public.resource_exchange_agreements
  set
    current_terms_id = pending_terms.id,
    pending_terms_id = null,
    current_terms_accepted_at = transition_time,
    lifecycle_state = 'agreed'
  where id = agreement.id;

  perform private.record_resource_exchange_agreement_event(
    'terms_accepted',
    agreement.id,
    pending_terms.id,
    null,
    current_profile_id,
    transition_time
  );

  return pending_terms.id;
end;
$$;

create or replace function public.record_resource_exchange_milestone(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_terms_id uuid,
  p_leg_kind text,
  p_event_kind text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  current_terms public.resource_exchange_agreement_terms%rowtype;
  normalized_leg_kind text := lower(nullif(btrim(p_leg_kind), ''));
  normalized_event_kind text := lower(nullif(btrim(p_event_kind), ''));
  expected_actor_profile_id uuid;
  existing_event_id uuid;
  milestone_event_id uuid;
  owner_leg_complete boolean;
  requester_leg_complete boolean;
  transition_time timestamptz := statement_timestamp();
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id
  for update;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may record milestones.';
  end if;

  if agreement.current_terms_id is distinct from p_expected_terms_id
    or agreement.current_terms_id is null then
    raise sqlstate 'PT409'
      using message = 'The accepted resource exchange terms changed since they were loaded.';
  end if;

  select * into current_terms
  from public.resource_exchange_agreement_terms
  where id = agreement.current_terms_id
    and agreement_id = agreement.id;

  if normalized_leg_kind is null
    or normalized_leg_kind not in ('owner_resource', 'requester_resource')
    or normalized_event_kind is null
    or normalized_event_kind not in (
      'resource_provided',
      'resource_received',
      'resource_returned',
      'resource_return_received'
    ) then
    raise exception using
      errcode = '22023',
      message = 'The resource exchange milestone shape is unsupported.';
  end if;

  if normalized_leg_kind = 'owner_resource' then
    expected_actor_profile_id := case normalized_event_kind
      when 'resource_provided' then listing.owner_profile_id
      when 'resource_received' then request.requester_profile_id
      when 'resource_returned' then request.requester_profile_id
      when 'resource_return_received' then listing.owner_profile_id
    end;

    if normalized_event_kind in (
      'resource_returned',
      'resource_return_received'
    ) and current_terms.owner_transfer_kind <> 'lend' then
      raise exception using
        errcode = '22023',
        message = 'Return milestones require a lend owner resource leg.';
    end if;
  else
    if current_terms.requester_transfer_kind = 'none' then
      raise exception using
        errcode = '22023',
        message = 'The agreement has no requester resource leg.';
    end if;

    expected_actor_profile_id := case normalized_event_kind
      when 'resource_provided' then request.requester_profile_id
      when 'resource_received' then listing.owner_profile_id
      when 'resource_returned' then listing.owner_profile_id
      when 'resource_return_received' then request.requester_profile_id
    end;

    if normalized_event_kind in (
      'resource_returned',
      'resource_return_received'
    ) and current_terms.requester_transfer_kind <> 'lend' then
      raise exception using
        errcode = '22023',
        message = 'Return milestones require a lend requester resource leg.';
    end if;
  end if;

  if current_profile_id <> expected_actor_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the provider or recipient assigned to this milestone may record it.';
  end if;

  select event.id into existing_event_id
  from public.resource_exchange_agreement_events as event
  where event.agreement_id = agreement.id
    and event.terms_id = current_terms.id
    and event.leg_kind = normalized_leg_kind
    and event.event_kind = normalized_event_kind;

  if existing_event_id is not null then
    return existing_event_id;
  end if;

  if agreement.lifecycle_state not in ('agreed', 'in_progress')
    or agreement.pending_terms_id is not null then
    raise sqlstate 'PT409'
      using message = 'A milestone requires settled current terms and open coordination.';
  end if;

  milestone_event_id := private.record_resource_exchange_agreement_event(
    normalized_event_kind,
    agreement.id,
    current_terms.id,
    normalized_leg_kind,
    current_profile_id,
    transition_time
  );

  if agreement.lifecycle_state = 'agreed' then
    update public.resource_exchange_agreements
    set lifecycle_state = 'in_progress'
    where id = agreement.id;
  end if;

  owner_leg_complete :=
    exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.terms_id = current_terms.id
        and event.leg_kind = 'owner_resource'
        and event.event_kind = 'resource_provided'
    )
    and exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.terms_id = current_terms.id
        and event.leg_kind = 'owner_resource'
        and event.event_kind = 'resource_received'
    )
    and (
      current_terms.owner_transfer_kind = 'give'
      or (
        exists (
          select 1
          from public.resource_exchange_agreement_events as event
          where event.agreement_id = agreement.id
            and event.terms_id = current_terms.id
            and event.leg_kind = 'owner_resource'
            and event.event_kind = 'resource_returned'
        )
        and exists (
          select 1
          from public.resource_exchange_agreement_events as event
          where event.agreement_id = agreement.id
            and event.terms_id = current_terms.id
            and event.leg_kind = 'owner_resource'
            and event.event_kind = 'resource_return_received'
        )
      )
    );

  requester_leg_complete := current_terms.requester_transfer_kind = 'none'
    or (
      exists (
        select 1
        from public.resource_exchange_agreement_events as event
        where event.agreement_id = agreement.id
          and event.terms_id = current_terms.id
          and event.leg_kind = 'requester_resource'
          and event.event_kind = 'resource_provided'
      )
      and exists (
        select 1
        from public.resource_exchange_agreement_events as event
        where event.agreement_id = agreement.id
          and event.terms_id = current_terms.id
          and event.leg_kind = 'requester_resource'
          and event.event_kind = 'resource_received'
      )
      and (
        current_terms.requester_transfer_kind = 'give'
        or (
          exists (
            select 1
            from public.resource_exchange_agreement_events as event
            where event.agreement_id = agreement.id
              and event.terms_id = current_terms.id
              and event.leg_kind = 'requester_resource'
              and event.event_kind = 'resource_returned'
          )
          and exists (
            select 1
            from public.resource_exchange_agreement_events as event
            where event.agreement_id = agreement.id
              and event.terms_id = current_terms.id
              and event.leg_kind = 'requester_resource'
              and event.event_kind = 'resource_return_received'
          )
        )
      )
    );

  if owner_leg_complete and requester_leg_complete then
    update public.resource_exchange_agreements
    set
      lifecycle_state = 'completed',
      completed_at = transition_time
    where id = agreement.id;

    update public.resource_listing_requests
    set
      coordination_closed_at = transition_time,
      coordination_closed_by_profile_id = current_profile_id
    where id = request.id
      and status = 'accepted'
      and coordination_closed_at is null;

    if not found then
      raise sqlstate 'PT409'
        using message = 'The accepted request coordination is already closed.';
    end if;

    perform private.record_resource_exchange_agreement_event(
      'agreement_completed',
      agreement.id,
      current_terms.id,
      null,
      current_profile_id,
      transition_time + interval '1 microsecond'
    );
  end if;

  return milestone_event_id;
end;
$$;

create or replace function public.cancel_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  transition_time timestamptz := statement_timestamp();
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id
  for update;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id
  for update;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may cancel coordination.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed')
    or exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.event_kind in (
          'resource_provided',
          'resource_received',
          'resource_returned',
          'resource_return_received'
        )
    ) then
    raise sqlstate 'PT409'
      using message = 'An agreement cannot be cancelled after handoff begins or coordination closes.';
  end if;

  if request.status <> 'accepted'
    or request.coordination_closed_at is not null then
    raise sqlstate 'PT409'
      using message = 'The accepted request coordination is already closed.';
  end if;

  update public.resource_exchange_agreements
  set
    lifecycle_state = 'cancelled',
    pending_terms_id = null,
    cancelled_at = transition_time,
    cancelled_by_profile_id = current_profile_id
  where id = agreement.id;

  update public.resource_listing_requests
  set
    coordination_closed_at = transition_time,
    coordination_closed_by_profile_id = current_profile_id
  where id = request.id;

  perform private.record_resource_exchange_agreement_event(
    'agreement_cancelled',
    agreement.id,
    null,
    null,
    current_profile_id,
    transition_time
  );

  return agreement.id;
end;
$$;

create or replace function public.get_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  agreement_id uuid,
  request_id uuid,
  listing_id uuid,
  owner_profile_id uuid,
  requester_profile_id uuid,
  lifecycle_state text,
  current_terms_id uuid,
  pending_terms_id uuid,
  current_terms_accepted_at timestamptz,
  created_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by_profile_id uuid,
  completed_at timestamptz,
  owner_lend_return_overdue boolean,
  requester_lend_return_overdue boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
begin
  return query
  select
    agreement.id,
    request.id,
    request.listing_id,
    listing.owner_profile_id,
    request.requester_profile_id,
    agreement.lifecycle_state,
    agreement.current_terms_id,
    agreement.pending_terms_id,
    agreement.current_terms_accepted_at,
    agreement.created_at,
    agreement.cancelled_at,
    agreement.cancelled_by_profile_id,
    agreement.completed_at,
    private.resource_exchange_owner_lend_is_overdue(
      agreement.id,
      current_terms.id,
      current_terms.owner_transfer_kind,
      current_terms.owner_lend_ends_at,
      agreement.lifecycle_state,
      statement_timestamp()
    ),
    coalesce(
      current_terms.requester_transfer_kind = 'lend'
      and statement_timestamp() > current_terms.requester_lend_ends_at
      and agreement.lifecycle_state not in ('cancelled', 'completed')
      and not exists (
        select 1
        from public.resource_exchange_agreement_events as requester_return_event
        where requester_return_event.agreement_id = agreement.id
          and requester_return_event.terms_id = current_terms.id
          and requester_return_event.leg_kind = 'requester_resource'
          and requester_return_event.event_kind = 'resource_return_received'
      ),
      false
    )
  from public.resource_exchange_agreements as agreement
  join public.resource_listing_requests as request
    on request.id = agreement.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  left join public.resource_exchange_agreement_terms as current_terms
    on current_terms.id = agreement.current_terms_id
    and current_terms.agreement_id = agreement.id
  where agreement.request_id = p_request_id
    and current_profile_id in (
      listing.owner_profile_id,
      request.requester_profile_id
    );
end;
$$;

comment on function public.accept_resource_exchange_terms(uuid, uuid, uuid) is
  'Accepts exact pending terms, serializing on the listing and rejecting overlapping owner-side LEND reservations with PT409 before any accepted event.';
comment on function public.record_resource_exchange_milestone(uuid, uuid, uuid, text, text) is
  'Records actor-authorized milestones; listing-row serialization makes final completion release visible to competing loan acceptance.';
comment on function public.cancel_resource_exchange_agreement(uuid, uuid) is
  'Cancels pre-handoff coordination; listing-row serialization makes derived loan release visible to competing acceptance.';
comment on function public.get_resource_exchange_agreement(uuid, uuid) is
  'Counterparty agreement read reusing canonical owner-lend overdue truth.';

create function public.list_owned_resource_listing_loan_schedule(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns table (
  listing_id uuid,
  agreement_id uuid,
  request_id uuid,
  terms_id uuid,
  requester_profile_id uuid,
  requester_display_name text,
  starts_at timestamptz,
  ends_at timestamptz,
  agreement_lifecycle text,
  is_overdue boolean,
  is_at_risk boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
begin
  if not exists (
    select 1
    from public.resource_listings as listing
    where listing.id = p_listing_id
      and listing.owner_profile_id = current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this resource listing.';
  end if;

  return query
  with active as (
    select
      reservation.*,
      private.resource_exchange_owner_lend_is_overdue(
        reservation.agreement_id,
        reservation.terms_id,
        'lend',
        reservation.ends_at,
        reservation.agreement_lifecycle,
        statement_timestamp()
      ) as overdue
    from private.active_resource_listing_loan_reservations(p_listing_id) as reservation
  )
  select
    active.listing_id,
    active.agreement_id,
    active.request_id,
    active.terms_id,
    active.requester_profile_id,
    requester.display_name,
    active.starts_at,
    active.ends_at,
    active.agreement_lifecycle,
    active.overdue,
    exists (
      select 1
      from active as earlier
      where earlier.agreement_id <> active.agreement_id
        and earlier.ends_at <= active.starts_at
        and earlier.overdue
    )
  from active
  join public.profiles as requester
    on requester.id = active.requester_profile_id
  order by active.starts_at, active.ends_at, active.agreement_id;
end;
$$;

create function public.check_resource_exchange_pending_loan_availability(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
returns table (
  is_lend boolean,
  is_available boolean
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  candidate_agreement public.resource_exchange_agreements%rowtype;
  candidate_request public.resource_listing_requests%rowtype;
  candidate_listing public.resource_listings%rowtype;
  candidate_terms public.resource_exchange_agreement_terms%rowtype;
begin
  select * into candidate_agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The pending agreement is unavailable to this profile.';
  end if;

  select * into candidate_request
  from public.resource_listing_requests
  where id = candidate_agreement.request_id;
  select * into candidate_listing
  from public.resource_listings
  where id = candidate_request.listing_id;

  if current_profile_id not in (
    candidate_listing.owner_profile_id,
    candidate_request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The pending agreement is unavailable to this profile.';
  end if;

  if p_expected_pending_terms_id is null
    or candidate_agreement.pending_terms_id is distinct from
      p_expected_pending_terms_id then
    raise sqlstate 'PT409'
      using message = 'The pending resource exchange terms changed since they were loaded.';
  end if;

  select * into candidate_terms
  from public.resource_exchange_agreement_terms
  where id = candidate_agreement.pending_terms_id
    and agreement_id = candidate_agreement.id;

  is_lend := candidate_terms.owner_transfer_kind = 'lend';
  if is_lend then
    is_available := not private.resource_listing_loan_period_conflicts(
      candidate_request.listing_id,
      candidate_agreement.id,
      candidate_terms.owner_lend_starts_at,
      candidate_terms.owner_lend_ends_at
    );
  else
    is_available := true;
  end if;
  return next;
end;
$$;

comment on function private.active_resource_listing_loan_reservations(uuid) is
  'Canonical listing-owner LEND reservations derived from current accepted terms and agreed/in-progress lifecycle; not a mutable ledger.';
comment on function private.resource_listing_loan_period_conflicts(uuid, uuid, timestamptz, timestamptz) is
  'Half-open same-listing overlap test excluding one agreement; callers serialize writes by locking the listing first.';
comment on function private.resource_exchange_owner_lend_is_overdue(uuid, uuid, text, timestamptz, text, timestamptz) is
  'Shared read-time owner-lend overdue predicate based on expected end and canonical return receipt.';
comment on function public.list_owned_resource_listing_loan_schedule(uuid, uuid) is
  'Owner-only chronological active listing-side loan schedule with derived overdue and at-risk indicators; no FIFO priority or private terms.';
comment on function public.check_resource_exchange_pending_loan_availability(uuid, uuid, uuid) is
  'Counterparty-only informational availability for one exact pending terms version; acceptance is the authoritative serialized check.';

revoke all privileges on function private.active_resource_listing_loan_reservations(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resource_listing_loan_period_conflicts(uuid, uuid, timestamptz, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resource_exchange_owner_lend_is_overdue(uuid, uuid, text, timestamptz, text, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_owned_resource_listing_loan_schedule(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.check_resource_exchange_pending_loan_availability(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_owned_resource_listing_loan_schedule(uuid, uuid)
  to authenticated;
grant execute on function public.check_resource_exchange_pending_loan_availability(uuid, uuid, uuid)
  to authenticated;
