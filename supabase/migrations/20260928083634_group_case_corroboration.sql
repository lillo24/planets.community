create table private.moderation_evidence_requests (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    constraint moderation_evidence_requests_case_id_fkey
      references private.moderation_cases (id) on delete restrict,
  request_kind text not null
    constraint moderation_evidence_requests_kind_valid check (
      request_kind = 'group_corroboration'
    ),
  recipient_profile_id uuid not null
    constraint moderation_evidence_requests_recipient_profile_id_fkey
      references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  constraint moderation_evidence_requests_case_kind_recipient_key
    unique (case_id, request_kind, recipient_profile_id),
  constraint moderation_evidence_requests_id_recipient_key
    unique (id, recipient_profile_id)
);

comment on table private.moderation_evidence_requests is
  'Immutable private evidence invitations snapshotted when a qualifying moderation report is created. The request kind is intentionally explicit so later evidence workflows can use their own kind and RPC contract.';
comment on column private.moderation_evidence_requests.created_at is
  'The cohort snapshot time. Later membership changes never rewrite the invitation.';

create index moderation_evidence_requests_case_id_idx
  on private.moderation_evidence_requests (case_id, created_at, id);
create index moderation_evidence_requests_recipient_created_at_id_idx
  on private.moderation_evidence_requests (
    recipient_profile_id,
    created_at desc,
    id desc
  );

create table private.moderation_evidence_responses (
  id uuid primary key default gen_random_uuid(),
  evidence_request_id uuid not null
    constraint moderation_evidence_responses_request_id_key unique,
  responder_profile_id uuid not null
    constraint moderation_evidence_responses_responder_profile_id_fkey
      references public.profiles (id) on delete restrict,
  client_submission_id uuid not null,
  choice text not null
    constraint moderation_evidence_responses_choice_valid check (
      choice in ('agree', 'disagree', 'unsure')
    ),
  explanation text
    constraint moderation_evidence_responses_explanation_valid check (
      explanation is null
      or (
        explanation = regexp_replace(
          explanation,
          '^[[:space:]]+|[[:space:]]+$',
          '',
          'g'
        )
        and char_length(explanation) between 1 and 4000
      )
    ),
  created_at timestamptz not null default statement_timestamp(),
  constraint moderation_evidence_responses_request_recipient_fkey
    foreign key (evidence_request_id, responder_profile_id)
      references private.moderation_evidence_requests (
        id,
        recipient_profile_id
      ) on delete restrict,
  constraint moderation_evidence_responses_responder_submission_key
    unique (responder_profile_id, client_submission_id)
);

comment on table private.moderation_evidence_responses is
  'One immutable private response per evidence invitation. Identity, choice, and explanation are staff-visible only and are never redistributed to peers.';
comment on column private.moderation_evidence_responses.client_submission_id is
  'Opaque client-generated retry key. Only an exact retry of the same request and canonical payload succeeds.';

create index moderation_evidence_responses_responder_created_at_id_idx
  on private.moderation_evidence_responses (
    responder_profile_id,
    created_at desc,
    id desc
  );

alter table private.moderation_evidence_requests enable row level security;
alter table private.moderation_evidence_responses enable row level security;

revoke all privileges on table private.moderation_evidence_requests
  from public, anon, authenticated, service_role;
revoke all privileges on table private.moderation_evidence_responses
  from public, anon, authenticated, service_role;

create trigger moderation_evidence_requests_append_only
before update or delete on private.moderation_evidence_requests
for each row execute function private.protect_moderation_append_only();

create trigger moderation_evidence_responses_append_only
before update or delete on private.moderation_evidence_responses
for each row execute function private.protect_moderation_append_only();

create function private.snapshot_group_corroboration_requests()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  moderation_case private.moderation_cases%rowtype;
  invitation_count integer;
begin
  select * into moderation_case
  from private.moderation_cases as candidate
  where candidate.id = new.case_id;

  if moderation_case.project_context_id is null
    or moderation_case.target_kind not in ('profile', 'project_chat_message') then
    return new;
  end if;

  -- Participation mutations use this same concrete-row/project-row lock order.
  -- Taking it before the membership query makes the creation-time cohort exact.
  perform 1
  from private.lock_project_for_participation(
    moderation_case.project_context_id,
    false
  );

  with eligible_recipients as (
    select project.creator_profile_id as profile_id
    from public.projects as project
    where project.id = moderation_case.project_context_id

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    join public.project_join_requests as originating_request
      on originating_request.id = membership.originating_request_id
      and originating_request.project_id = membership.project_id
      and originating_request.requester_profile_id =
        membership.participant_profile_id
      and originating_request.status = 'accepted'
    where membership.project_id = moderation_case.project_context_id
      and membership.joined_at <= moderation_case.created_at
      and moderation_case.created_at < coalesce(
        membership.left_at,
        membership.removed_at,
        'infinity'::timestamptz
      )
  ), inserted as (
    insert into private.moderation_evidence_requests (
      case_id,
      request_kind,
      recipient_profile_id,
      created_at
    )
    select
      moderation_case.id,
      'group_corroboration',
      eligible.profile_id,
      moderation_case.created_at
    from eligible_recipients as eligible
    where eligible.profile_id not in (
      new.reporter_profile_id,
      moderation_case.subject_profile_id
    )
    on conflict (case_id, request_kind, recipient_profile_id) do nothing
    returning id
  )
  select count(*)::integer into invitation_count from inserted;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'moderation.group_corroboration_snapshotted',
    new.reporter_profile_id,
    'moderation_case',
    moderation_case.id,
    jsonb_build_object(
      'case_id', moderation_case.id,
      'request_count', invitation_count
    ),
    moderation_case.created_at
  );

  return new;
end;
$$;

create trigger moderation_reports_snapshot_group_corroboration
after insert on private.moderation_reports
for each row execute function private.snapshot_group_corroboration_requests();

create function public.list_own_group_corroboration_requests(
  p_expected_recipient_profile_id uuid,
  p_pending_only boolean default false,
  p_limit integer default 20,
  p_before_created_at timestamptz default null,
  p_before_request_id uuid default null
)
returns table (
  request_id uuid,
  case_id uuid,
  case_state text,
  target_kind text,
  target_summary text,
  context_summary text,
  response_choice text,
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
      message = 'The corroboration filter is invalid.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Corroboration page size must be between 1 and 50.';
  end if;

  if (p_before_created_at is null) <> (p_before_request_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both corroboration cursor values must be provided together.';
  end if;

  return query
  select
    request.id,
    moderation_case.id,
    moderation_case.state,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    response.choice,
    response.created_at,
    response.id is null and moderation_case.state <> 'completed',
    request.created_at
  from private.moderation_evidence_requests as request
  join private.moderation_cases as moderation_case
    on moderation_case.id = request.case_id
  left join private.moderation_evidence_responses as response
    on response.evidence_request_id = request.id
  where request.recipient_profile_id = recipient_id
    and request.request_kind = 'group_corroboration'
    and (
      not p_pending_only
      or (
        response.id is null
        and moderation_case.state <> 'completed'
      )
    )
    and (
      p_before_created_at is null
      or (request.created_at, request.id)
        < (p_before_created_at, p_before_request_id)
    )
  order by request.created_at desc, request.id desc
  limit p_limit;
end;
$$;

create function public.get_own_group_corroboration_request(
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
  response_choice text,
  response_explanation text,
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
    response.choice,
    response.explanation,
    response.created_at,
    response.id is null and moderation_case.state <> 'completed',
    request.created_at
  from private.moderation_evidence_requests as request
  join private.moderation_cases as moderation_case
    on moderation_case.id = request.case_id
  join private.moderation_reports as report
    on report.case_id = moderation_case.id
  left join private.moderation_evidence_responses as response
    on response.evidence_request_id = request.id
  where request.id = p_request_id
    and request.recipient_profile_id = recipient_id
    and request.request_kind = 'group_corroboration';
end;
$$;

create function public.submit_group_corroboration_response(
  p_expected_recipient_profile_id uuid,
  p_request_id uuid,
  p_client_submission_id uuid,
  p_choice text,
  p_explanation text default null
)
returns table (
  response_id uuid,
  choice text,
  explanation text,
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
  normalized_explanation text := nullif(
    regexp_replace(
      coalesce(p_explanation, ''),
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    ),
    ''
  );
  request_case_id uuid;
  current_case private.moderation_cases%rowtype;
  current_request private.moderation_evidence_requests%rowtype;
  existing_response private.moderation_evidence_responses%rowtype;
  new_response private.moderation_evidence_responses%rowtype;
begin
  if p_request_id is null
    or p_client_submission_id is null
    or p_choice not in ('agree', 'disagree', 'unsure')
    or char_length(coalesce(normalized_explanation, '')) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'The corroboration response is invalid.';
  end if;

  select request.case_id into request_case_id
  from private.moderation_evidence_requests as request
  where request.id = p_request_id
    and request.request_kind = 'group_corroboration';

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The corroboration request does not exist.';
  end if;

  -- State transitions lock the case first. Keeping that order makes the
  -- response-versus-completion boundary deterministic.
  select * into current_case
  from private.moderation_cases as moderation_case
  where moderation_case.id = request_case_id
  for update;

  select * into current_request
  from private.moderation_evidence_requests as request
  where request.id = p_request_id
  for update;

  if current_request.recipient_profile_id <> recipient_id then
    raise exception using
      errcode = '42501',
      message = 'The corroboration request is unavailable.';
  end if;

  select * into existing_response
  from private.moderation_evidence_responses as response
  where response.evidence_request_id = current_request.id;

  if found then
    if existing_response.responder_profile_id = recipient_id
      and existing_response.client_submission_id = p_client_submission_id
      and existing_response.choice = p_choice
      and existing_response.explanation is not distinct from normalized_explanation then
      return query select
        existing_response.id,
        existing_response.choice,
        existing_response.explanation,
        existing_response.created_at;
      return;
    end if;

    raise sqlstate 'PT409'
      using message = 'A final response has already been submitted for this request.';
  end if;

  if current_case.state = 'completed' then
    raise sqlstate 'PT409'
      using message = 'The moderation case is already completed.';
  end if;

  insert into private.moderation_evidence_responses (
    evidence_request_id,
    responder_profile_id,
    client_submission_id,
    choice,
    explanation
  )
  values (
    current_request.id,
    recipient_id,
    p_client_submission_id,
    p_choice,
    normalized_explanation
  )
  returning * into new_response;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'moderation.group_corroboration_responded',
    null,
    'moderation_case',
    current_case.id,
    jsonb_build_object(
      'case_id', current_case.id,
      'response_id', new_response.id
    ),
    new_response.created_at
  );

  return query select
    new_response.id,
    new_response.choice,
    new_response.explanation,
    new_response.created_at;
exception
  when unique_violation then
    select * into existing_response
    from private.moderation_evidence_responses as response
    where response.evidence_request_id = p_request_id;

    if found
      and existing_response.responder_profile_id = recipient_id
      and existing_response.client_submission_id = p_client_submission_id
      and existing_response.choice = p_choice
      and existing_response.explanation is not distinct from normalized_explanation then
      return query select
        existing_response.id,
        existing_response.choice,
        existing_response.explanation,
        existing_response.created_at;
      return;
    end if;
    raise;
end;
$$;

create function public.get_moderation_case_corroboration(
  p_expected_staff_profile_id uuid,
  p_case_id uuid
)
returns table (
  invited_count bigint,
  responded_count bigint,
  pending_count bigint,
  agree_count bigint,
  disagree_count bigint,
  unsure_count bigint,
  responses jsonb
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
    count(request.id),
    count(response.id),
    count(request.id) - count(response.id),
    count(response.id) filter (where response.choice = 'agree'),
    count(response.id) filter (where response.choice = 'disagree'),
    count(response.id) filter (where response.choice = 'unsure'),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'response_id', response.id,
          'responder_profile_id', response.responder_profile_id,
          'responder_display_name', responder.display_name,
          'choice', response.choice,
          'explanation', response.explanation,
          'created_at', response.created_at
        ) order by response.created_at, response.id
      ) filter (where response.id is not null),
      '[]'::jsonb
    )
  from private.moderation_cases as moderation_case
  left join private.moderation_evidence_requests as request
    on request.case_id = moderation_case.id
    and request.request_kind = 'group_corroboration'
  left join private.moderation_evidence_responses as response
    on response.evidence_request_id = request.id
  left join public.profiles as responder
    on responder.id = response.responder_profile_id
  where moderation_case.id = p_case_id
  group by moderation_case.id;
end;
$$;

comment on function public.list_own_group_corroboration_requests(uuid, boolean, integer, timestamptz, uuid) is
  'Returns only the expected recipient own bounded corroboration summaries. Pending reads omit unanswered requests after case completion.';
comment on function public.get_own_group_corroboration_request(uuid, uuid) is
  'Returns one assigned recipient own request, original reporter wording without reporter identity, and only that recipient own response.';
comment on function public.submit_group_corroboration_response(uuid, uuid, uuid, text, text) is
  'Appends one final staff-private agree/disagree/unsure response; exact client retries are idempotent and conflicting attempts fail.';
comment on function public.get_moderation_case_corroboration(uuid, uuid) is
  'Returns staff-only corroboration evidence counts and identified submitted responses. Group membership is an eligibility proxy, not proof of witnessing the event.';

revoke all privileges on function private.snapshot_group_corroboration_requests()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_group_corroboration_requests(uuid, boolean, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_group_corroboration_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.submit_group_corroboration_response(uuid, uuid, uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_moderation_case_corroboration(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.list_own_group_corroboration_requests(uuid, boolean, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_own_group_corroboration_request(uuid, uuid)
  to authenticated;
grant execute on function public.submit_group_corroboration_response(uuid, uuid, uuid, text, text)
  to authenticated;
grant execute on function public.get_moderation_case_corroboration(uuid, uuid)
  to authenticated;
