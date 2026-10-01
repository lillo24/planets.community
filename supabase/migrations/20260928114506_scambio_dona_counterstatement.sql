alter table private.moderation_evidence_requests
  drop constraint moderation_evidence_requests_kind_valid;

alter table private.moderation_evidence_requests
  add constraint moderation_evidence_requests_kind_valid check (
    request_kind in ('group_corroboration', 'resource_counterstatement')
  ),
  add constraint moderation_evidence_requests_id_recipient_kind_key
    unique (id, recipient_profile_id, request_kind);

alter table private.moderation_evidence_responses
  add column request_kind text not null default 'group_corroboration'
    constraint moderation_evidence_responses_request_kind_valid check (
      request_kind = 'group_corroboration'
    ),
  add constraint moderation_evidence_responses_request_recipient_kind_fkey
    foreign key (evidence_request_id, responder_profile_id, request_kind)
      references private.moderation_evidence_requests (
        id,
        recipient_profile_id,
        request_kind
      ) on delete restrict;

comment on column private.moderation_evidence_responses.request_kind is
  'A fixed discriminator that prevents group corroboration responses from attaching to another evidence-request kind.';

create table private.moderation_counterstatements (
  id uuid primary key default gen_random_uuid(),
  evidence_request_id uuid not null
    constraint moderation_counterstatements_request_id_key unique,
  responder_profile_id uuid not null
    constraint moderation_counterstatements_responder_profile_id_fkey
      references public.profiles (id) on delete restrict,
  request_kind text not null default 'resource_counterstatement'
    constraint moderation_counterstatements_request_kind_valid check (
      request_kind = 'resource_counterstatement'
    ),
  client_submission_id uuid not null,
  statement text not null
    constraint moderation_counterstatements_statement_valid check (
      statement = regexp_replace(
        statement,
        '^[[:space:]]+|[[:space:]]+$',
        '',
        'g'
      )
      and char_length(statement) between 10 and 4000
    ),
  created_at timestamptz not null default statement_timestamp(),
  constraint moderation_counterstatements_request_recipient_kind_fkey
    foreign key (evidence_request_id, responder_profile_id, request_kind)
      references private.moderation_evidence_requests (
        id,
        recipient_profile_id,
        request_kind
      ) on delete restrict,
  constraint moderation_counterstatements_responder_submission_key
    unique (responder_profile_id, client_submission_id)
);

comment on table private.moderation_counterstatements is
  'One immutable staff-private free-text statement from the reported counterparty for a canonical Scambio-Dona Resource request episode.';
comment on column private.moderation_counterstatements.client_submission_id is
  'Opaque client retry key. Only an exact retry of the same request and canonical statement succeeds.';

create index moderation_counterstatements_responder_created_at_id_idx
  on private.moderation_counterstatements (
    responder_profile_id,
    created_at desc,
    id desc
  );

alter table private.moderation_counterstatements enable row level security;

revoke all privileges on table private.moderation_counterstatements
  from public, anon, authenticated, service_role;

create trigger moderation_counterstatements_append_only
before update or delete on private.moderation_counterstatements
for each row execute function private.protect_moderation_append_only();

create function private.snapshot_resource_counterstatement_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  moderation_case private.moderation_cases%rowtype;
  resource_request public.resource_listing_requests%rowtype;
  resource_listing public.resource_listings%rowtype;
  expected_subject_id uuid;
  evidence_request_id uuid;
begin
  select * into moderation_case
  from private.moderation_cases as candidate
  where candidate.id = new.case_id;

  if moderation_case.resource_request_context_id is null
    or moderation_case.target_kind not in (
      'profile',
      'resource_request',
      'resource_chat_message'
    ) then
    return new;
  end if;

  select * into resource_request
  from public.resource_listing_requests as request
  where request.id = moderation_case.resource_request_context_id;

  select * into resource_listing
  from public.resource_listings as listing
  where listing.id = resource_request.listing_id;

  if resource_request.id is null
    or resource_listing.id is null
    or moderation_case.resource_listing_context_id <> resource_listing.id
    or new.reporter_profile_id not in (
      resource_listing.owner_profile_id,
      resource_request.requester_profile_id
    )
    or moderation_case.subject_profile_id not in (
      resource_listing.owner_profile_id,
      resource_request.requester_profile_id
    )
    or moderation_case.subject_profile_id = new.reporter_profile_id then
    raise exception using
      errcode = '23514',
      message = 'The moderation Resource counterparty context is inconsistent.';
  end if;

  expected_subject_id := case
    when new.reporter_profile_id = resource_listing.owner_profile_id
      then resource_request.requester_profile_id
    else resource_listing.owner_profile_id
  end;

  if moderation_case.subject_profile_id <> expected_subject_id then
    raise exception using
      errcode = '23514',
      message = 'The moderation Resource counterparty context is inconsistent.';
  end if;

  insert into private.moderation_evidence_requests (
    case_id,
    request_kind,
    recipient_profile_id,
    created_at
  )
  values (
    moderation_case.id,
    'resource_counterstatement',
    moderation_case.subject_profile_id,
    moderation_case.created_at
  )
  on conflict (case_id, request_kind, recipient_profile_id) do nothing
  returning id into evidence_request_id;

  if evidence_request_id is not null then
    insert into private.audit_events (
      action,
      actor_user_id,
      target_type,
      target_id,
      metadata,
      created_at
    )
    values (
      'moderation.resource_counterstatement_requested',
      null,
      'moderation_case',
      moderation_case.id,
      jsonb_build_object(
        'case_id', moderation_case.id,
        'evidence_request_id', evidence_request_id,
        'request_kind', 'resource_counterstatement'
      ),
      moderation_case.created_at
    );
  end if;

  return new;
end;
$$;

create trigger moderation_reports_snapshot_resource_counterstatement
after insert on private.moderation_reports
for each row execute function private.snapshot_resource_counterstatement_request();

create function public.list_own_moderation_evidence_requests(
  p_expected_recipient_profile_id uuid,
  p_pending_only boolean default false,
  p_limit integer default 50
)
returns table (
  request_id uuid,
  request_kind text,
  case_state text,
  target_kind text,
  target_summary text,
  context_summary text,
  responded_at timestamptz,
  can_respond boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  recipient_id uuid := private.require_moderation_identity(
    p_expected_recipient_profile_id,
    true
  );
begin
  if p_pending_only is null then
    raise exception using
      errcode = '22023',
      message = 'The moderation evidence filter is invalid.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Moderation evidence page size must be between 1 and 50.';
  end if;

  return query
  select
    request.id,
    request.request_kind,
    moderation_case.state,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    coalesce(corroboration.created_at, counterstatement.created_at),
    corroboration.id is null
      and counterstatement.id is null
      and moderation_case.state <> 'completed',
    request.created_at
  from private.moderation_evidence_requests as request
  join private.moderation_cases as moderation_case
    on moderation_case.id = request.case_id
  left join private.moderation_evidence_responses as corroboration
    on corroboration.evidence_request_id = request.id
    and request.request_kind = 'group_corroboration'
  left join private.moderation_counterstatements as counterstatement
    on counterstatement.evidence_request_id = request.id
    and request.request_kind = 'resource_counterstatement'
  where request.recipient_profile_id = recipient_id
    and (
      not p_pending_only
      or (
        corroboration.id is null
        and counterstatement.id is null
        and moderation_case.state <> 'completed'
      )
    )
  order by
    case when p_pending_only then request.created_at end asc,
    case when p_pending_only then request.id end asc,
    case when not p_pending_only then request.created_at end desc,
    case when not p_pending_only then request.id end desc
  limit p_limit;
end;
$$;

create function public.get_own_resource_counterstatement_request(
  p_expected_recipient_profile_id uuid,
  p_request_id uuid
)
returns table (
  request_id uuid,
  case_id uuid,
  case_state text,
  category text,
  explanation text,
  target_kind text,
  target_summary text,
  context_summary text,
  statement text,
  submitted_at timestamptz,
  can_respond boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  recipient_id uuid := private.require_moderation_identity(
    p_expected_recipient_profile_id,
    true
  );
begin
  return query
  select
    request.id,
    moderation_case.id,
    moderation_case.state,
    report.category,
    report.explanation,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    counterstatement.statement,
    counterstatement.created_at,
    counterstatement.id is null and moderation_case.state <> 'completed',
    request.created_at
  from private.moderation_evidence_requests as request
  join private.moderation_cases as moderation_case
    on moderation_case.id = request.case_id
  join private.moderation_reports as report
    on report.case_id = moderation_case.id
  left join private.moderation_counterstatements as counterstatement
    on counterstatement.evidence_request_id = request.id
  where request.id = p_request_id
    and request.recipient_profile_id = recipient_id
    and request.request_kind = 'resource_counterstatement';
end;
$$;

create function public.submit_resource_counterstatement(
  p_expected_recipient_profile_id uuid,
  p_request_id uuid,
  p_client_submission_id uuid,
  p_statement text
)
returns table (
  counterstatement_id uuid,
  statement text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient_id uuid := private.require_moderation_identity(
    p_expected_recipient_profile_id,
    true
  );
  normalized_statement text := regexp_replace(
    coalesce(p_statement, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  request_case_id uuid;
  current_case private.moderation_cases%rowtype;
  current_request private.moderation_evidence_requests%rowtype;
  current_report private.moderation_reports%rowtype;
  resource_request public.resource_listing_requests%rowtype;
  resource_listing public.resource_listings%rowtype;
  expected_subject_id uuid;
  existing_counterstatement private.moderation_counterstatements%rowtype;
  new_counterstatement private.moderation_counterstatements%rowtype;
begin
  if p_request_id is null
    or p_client_submission_id is null
    or char_length(normalized_statement) not between 10 and 4000 then
    raise exception using
      errcode = '22023',
      message = 'The counterparty statement must contain between 10 and 4,000 characters.';
  end if;

  select request.case_id into request_case_id
  from private.moderation_evidence_requests as request
  where request.id = p_request_id
    and request.recipient_profile_id = recipient_id
    and request.request_kind = 'resource_counterstatement';

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The counterparty statement request is unavailable.';
  end if;

  -- Moderation state transitions lock the case first. Use the same order so a
  -- statement racing completion has one deterministic winner.
  select * into current_case
  from private.moderation_cases as moderation_case
  where moderation_case.id = request_case_id
  for update;

  select * into current_request
  from private.moderation_evidence_requests as request
  where request.id = p_request_id
  for update;

  select * into current_report
  from private.moderation_reports as report
  where report.case_id = current_case.id;

  select * into resource_request
  from public.resource_listing_requests as request
  where request.id = current_case.resource_request_context_id;

  select * into resource_listing
  from public.resource_listings as listing
  where listing.id = resource_request.listing_id;

  expected_subject_id := case
    when current_report.reporter_profile_id = resource_listing.owner_profile_id
      then resource_request.requester_profile_id
    when current_report.reporter_profile_id = resource_request.requester_profile_id
      then resource_listing.owner_profile_id
    else null
  end;

  if current_request.recipient_profile_id <> recipient_id
    or current_request.request_kind <> 'resource_counterstatement'
    or current_case.subject_profile_id <> recipient_id
    or current_case.resource_request_context_id is null
    or current_case.resource_listing_context_id <> resource_listing.id
    or expected_subject_id is null
    or expected_subject_id <> recipient_id then
    raise exception using
      errcode = '42501',
      message = 'The counterparty statement request is unavailable.';
  end if;

  select * into existing_counterstatement
  from private.moderation_counterstatements as counterstatement
  where counterstatement.evidence_request_id = current_request.id;

  if found then
    if existing_counterstatement.responder_profile_id = recipient_id
      and existing_counterstatement.client_submission_id = p_client_submission_id
      and existing_counterstatement.statement = normalized_statement then
      return query select
        existing_counterstatement.id,
        existing_counterstatement.statement,
        existing_counterstatement.created_at;
      return;
    end if;

    raise sqlstate 'PT409'
      using message = 'A final counterparty statement has already been submitted.';
  end if;

  if current_case.state = 'completed' then
    raise sqlstate 'PT409'
      using message = 'The moderation case is already completed.';
  end if;

  insert into private.moderation_counterstatements (
    evidence_request_id,
    responder_profile_id,
    client_submission_id,
    statement
  )
  values (
    current_request.id,
    recipient_id,
    p_client_submission_id,
    normalized_statement
  )
  returning * into new_counterstatement;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'moderation.resource_counterstatement_submitted',
    null,
    'moderation_case',
    current_case.id,
    jsonb_build_object(
      'case_id', current_case.id,
      'evidence_request_id', current_request.id,
      'counterstatement_id', new_counterstatement.id,
      'request_kind', 'resource_counterstatement'
    ),
    new_counterstatement.created_at
  );

  return query select
    new_counterstatement.id,
    new_counterstatement.statement,
    new_counterstatement.created_at;
exception
  when unique_violation then
    select * into existing_counterstatement
    from private.moderation_counterstatements as counterstatement
    where counterstatement.evidence_request_id = p_request_id;

    if found
      and existing_counterstatement.responder_profile_id = recipient_id
      and existing_counterstatement.client_submission_id = p_client_submission_id
      and existing_counterstatement.statement = normalized_statement then
      return query select
        existing_counterstatement.id,
        existing_counterstatement.statement,
        existing_counterstatement.created_at;
      return;
    end if;
    raise;
end;
$$;

create function public.get_moderation_case_counterstatement(
  p_expected_staff_profile_id uuid,
  p_case_id uuid
)
returns table (
  request_id uuid,
  recipient_profile_id uuid,
  recipient_display_name text,
  statement text,
  submitted_at timestamptz,
  requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);

  return query
  select
    request.id,
    request.recipient_profile_id,
    recipient.display_name,
    counterstatement.statement,
    counterstatement.created_at,
    request.created_at
  from private.moderation_evidence_requests as request
  join public.profiles as recipient
    on recipient.id = request.recipient_profile_id
  left join private.moderation_counterstatements as counterstatement
    on counterstatement.evidence_request_id = request.id
  where request.case_id = p_case_id
    and request.request_kind = 'resource_counterstatement';
end;
$$;

comment on function public.list_own_moderation_evidence_requests(uuid, boolean, integer) is
  'Returns a bounded recipient-owned discriminated review-request list. Pending rows are oldest first for fair single-session prompting; history is newest first.';
comment on function public.get_own_resource_counterstatement_request(uuid, uuid) is
  'Returns one assigned subject own Resource counterstatement request, original accusation without a reporter identity field, and only that subject own statement.';
comment on function public.submit_resource_counterstatement(uuid, uuid, uuid, text) is
  'Appends one final staff-private Resource counterparty statement after canonical counterparty revalidation; exact client retries are idempotent.';
comment on function public.get_moderation_case_counterstatement(uuid, uuid) is
  'Returns staff-only pending or submitted Resource counterparty evidence with the assigned recipient identity.';

revoke all privileges on function private.snapshot_resource_counterstatement_request()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_moderation_evidence_requests(uuid, boolean, integer)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_resource_counterstatement_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.submit_resource_counterstatement(uuid, uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_moderation_case_counterstatement(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.list_own_moderation_evidence_requests(uuid, boolean, integer)
  to authenticated;
grant execute on function public.get_own_resource_counterstatement_request(uuid, uuid)
  to authenticated;
grant execute on function public.submit_resource_counterstatement(uuid, uuid, uuid, text)
  to authenticated;
grant execute on function public.get_moderation_case_counterstatement(uuid, uuid)
  to authenticated;
