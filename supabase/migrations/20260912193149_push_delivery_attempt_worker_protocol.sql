alter table private.push_installations
  add column token_version bigint not null default 1
    constraint push_installations_token_version_positive check (
      token_version > 0
    );

comment on column private.push_installations.token_version is
  'Monotonic private generation for provider-token state; trusted delivery results use it to reject stale invalid-token cleanup.';

alter table private.push_delivery_jobs
  add column fanout_at timestamptz,
  add column completed_at timestamptz,
  add column completion_reason text,
  add constraint push_delivery_jobs_lifecycle_valid check (
    (fanout_at is null and completed_at is null and completion_reason is null)
    or (
      fanout_at is not null
      and (
        (completed_at is null and completion_reason is null)
        or (
          completed_at is not null
          and completed_at >= fanout_at
          and completion_reason in ('delivered_or_terminal', 'no_targets')
        )
      )
    )
  );

comment on column private.push_delivery_jobs.fanout_at is
  'When active installations were snapshotted exactly once into delivery targets.';
comment on column private.push_delivery_jobs.completed_at is
  'When fan-out found no targets or every snapshotted target became terminal.';
comment on column private.push_delivery_jobs.completion_reason is
  'Stable aggregate completion reason: delivered_or_terminal or no_targets.';

create index push_delivery_jobs_pending_fanout_idx
  on private.push_delivery_jobs (available_at, created_at, id)
  where fanout_at is null;

create table private.push_delivery_targets (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null
    constraint push_delivery_targets_job_id_fkey
      references private.push_delivery_jobs (id) on delete restrict,
  installation_id uuid not null
    constraint push_delivery_targets_installation_id_fkey
      references private.push_installations (installation_id) on delete restrict,
  platform text not null
    constraint push_delivery_targets_platform_valid check (
      platform in ('android', 'ios')
    ),
  provider text not null
    constraint push_delivery_targets_provider_valid check (provider = 'fcm'),
  status text not null default 'pending'
    constraint push_delivery_targets_status_valid check (
      status in (
        'pending',
        'delivered',
        'invalid_token',
        'permanent_failure',
        'no_longer_registered'
      )
    ),
  available_at timestamptz not null,
  attempt_count integer not null default 0
    constraint push_delivery_targets_attempt_count_valid check (
      attempt_count >= 0
    ),
  lease_owner text,
  lease_id uuid,
  lease_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint push_delivery_targets_job_installation_unique unique (
    job_id,
    installation_id
  ),
  constraint push_delivery_targets_lease_valid check (
    (
      lease_owner is null
      and lease_id is null
      and lease_expires_at is null
    )
    or (
      status = 'pending'
      and lease_owner is not null
      and lease_owner = btrim(lease_owner)
      and char_length(lease_owner) between 1 and 128
      and lease_id is not null
      and lease_expires_at is not null
      and lease_expires_at > updated_at
    )
  ),
  constraint push_delivery_targets_completion_valid check (
    (
      status = 'pending'
      and completed_at is null
    )
    or (
      status <> 'pending'
      and completed_at is not null
      and completed_at >= created_at
    )
  ),
  constraint push_delivery_targets_timestamps_valid check (
    updated_at >= created_at
    and available_at >= created_at
  )
);

comment on table private.push_delivery_targets is
  'Private per-job installation snapshots and lease state; provider tokens are resolved only by the trusted claim routine and are never copied here.';
comment on column private.push_delivery_targets.installation_id is
  'The installation selected at one-time job fan-out; later installations never receive the historical event.';
comment on column private.push_delivery_targets.lease_id is
  'Opaque claim identity required to record a result; a reclaimed target receives a new value.';

create index push_delivery_targets_job_id_idx
  on private.push_delivery_targets (job_id, id);
create index push_delivery_targets_installation_id_idx
  on private.push_delivery_targets (installation_id, id);
create index push_delivery_targets_claimable_idx
  on private.push_delivery_targets (available_at, created_at, id)
  where status = 'pending';
create index push_delivery_targets_expiring_lease_idx
  on private.push_delivery_targets (lease_expires_at, id)
  where status = 'pending' and lease_id is not null;

alter table private.push_delivery_targets enable row level security;
revoke all privileges on table private.push_delivery_targets
  from public, anon, authenticated, service_role;

create table private.push_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null
    constraint push_delivery_attempts_target_id_fkey
      references private.push_delivery_targets (id) on delete restrict,
  attempt_number integer not null
    constraint push_delivery_attempts_attempt_number_positive check (
      attempt_number > 0
    ),
  lease_id uuid not null,
  worker_id text not null
    constraint push_delivery_attempts_worker_id_valid check (
      worker_id = btrim(worker_id)
      and char_length(worker_id) between 1 and 128
    ),
  token_version bigint not null
    constraint push_delivery_attempts_token_version_positive check (
      token_version > 0
    ),
  started_at timestamptz not null,
  finished_at timestamptz,
  outcome text
    constraint push_delivery_attempts_outcome_valid check (
      outcome is null
      or outcome in (
        'delivered',
        'invalid_token',
        'transient_failure',
        'permanent_failure'
      )
    ),
  provider_message_id text
    constraint push_delivery_attempts_provider_message_id_valid check (
      provider_message_id is null
      or (
        provider_message_id = btrim(provider_message_id)
        and char_length(provider_message_id) between 1 and 255
      )
    ),
  provider_error_code text
    constraint push_delivery_attempts_provider_error_code_valid check (
      provider_error_code is null
      or (
        provider_error_code = btrim(provider_error_code)
        and char_length(provider_error_code) between 1 and 128
      )
    ),
  retry_available_at timestamptz,
  constraint push_delivery_attempts_target_attempt_unique unique (
    target_id,
    attempt_number
  ),
  constraint push_delivery_attempts_lease_unique unique (lease_id),
  constraint push_delivery_attempts_result_shape_valid check (
    (
      finished_at is null
      and outcome is null
      and provider_message_id is null
      and provider_error_code is null
      and retry_available_at is null
    )
    or (
      finished_at is not null
      and finished_at >= started_at
      and outcome is not null
      and (
        (
          outcome = 'transient_failure'
          and retry_available_at is not null
          and retry_available_at >= finished_at
        )
        or (
          outcome <> 'transient_failure'
          and retry_available_at is null
        )
      )
    )
  )
);

comment on table private.push_delivery_attempts is
  'Append-only safe delivery-attempt history; stores no provider token, raw provider response, or notification content.';
comment on column private.push_delivery_attempts.token_version is
  'The claimed installation token generation, not the provider token itself.';

create index push_delivery_attempts_target_id_idx
  on private.push_delivery_attempts (target_id, attempt_number);

alter table private.push_delivery_attempts enable row level security;
revoke all privileges on table private.push_delivery_attempts
  from public, anon, authenticated, service_role;

create function private.complete_push_delivery_job_if_terminal(
  p_job_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Serialize aggregate completion per job. The terminal check runs in the
  -- following statement so a waiter receives a fresh READ COMMITTED snapshot
  -- after another target result commits.
  perform job.id
  from private.push_delivery_jobs as job
  where job.id = p_job_id
  for update;

  update private.push_delivery_jobs as job
  set
    completed_at = statement_timestamp(),
    completion_reason = 'delivered_or_terminal'
  where job.id = p_job_id
    and job.fanout_at is not null
    and job.completed_at is null
    and exists (
      select 1
      from private.push_delivery_targets as target
      where target.job_id = job.id
    )
    and not exists (
      select 1
      from private.push_delivery_targets as target
      where target.job_id = job.id
        and target.status = 'pending'
    );
end;
$$;

create function private.prepare_push_delivery_jobs(
  p_limit integer default 100
)
returns table (
  jobs_prepared integer,
  targets_created integer,
  jobs_without_targets integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  job_record private.push_delivery_jobs%rowtype;
  prepare_time timestamptz;
  inserted_count integer;
  prepared_count integer := 0;
  target_count integer := 0;
  no_target_count integer := 0;
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery preparation batch size must be between 1 and 100.';
  end if;

  for job_record in
    select job.*
    from private.push_delivery_jobs as job
    where job.fanout_at is null
      and job.available_at <= statement_timestamp()
    order by job.available_at, job.created_at, job.id
    limit p_limit
    for update of job skip locked
  loop
    prepare_time := statement_timestamp();

    insert into private.push_delivery_targets (
      job_id,
      installation_id,
      platform,
      provider,
      status,
      available_at,
      created_at,
      updated_at
    )
    select
      job_record.id,
      installation.installation_id,
      installation.platform,
      installation.provider,
      'pending',
      prepare_time,
      prepare_time,
      prepare_time
    from private.push_installations as installation
    where installation.profile_id = job_record.recipient_profile_id
      and installation.disabled_at is null
      and installation.provider_token is not null
    order by installation.installation_id
    on conflict on constraint push_delivery_targets_job_installation_unique
      do nothing;

    get diagnostics inserted_count = row_count;
    target_count := target_count + inserted_count;
    prepared_count := prepared_count + 1;

    if inserted_count = 0 then
      update private.push_delivery_jobs as job
      set
        fanout_at = prepare_time,
        completed_at = prepare_time,
        completion_reason = 'no_targets'
      where job.id = job_record.id;
      no_target_count := no_target_count + 1;
    else
      update private.push_delivery_jobs as job
      set fanout_at = prepare_time
      where job.id = job_record.id;
    end if;
  end loop;

  return query select prepared_count, target_count, no_target_count;
end;
$$;

create function private.claim_push_delivery_targets(
  p_worker_id text,
  p_limit integer,
  p_lease_seconds integer
)
returns table (
  target_id uuid,
  job_id uuid,
  lease_id uuid,
  lease_expires_at timestamptz,
  attempt_number integer,
  installation_id uuid,
  platform text,
  provider text,
  provider_token text,
  token_version bigint,
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  stale_target record;
  candidate record;
  new_lease_id uuid;
  claim_time timestamptz;
  claim_expires_at timestamptz;
  new_attempt_number integer;
begin
  if p_worker_id is null
    or p_worker_id <> btrim(p_worker_id)
    or char_length(p_worker_id) not between 1 and 128 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery worker ID must contain 1 to 128 trimmed characters.';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery claim batch size must be between 1 and 100.';
  end if;

  if p_lease_seconds is null or p_lease_seconds < 1 or p_lease_seconds > 3600 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery lease must be between 1 and 3600 seconds.';
  end if;

  -- First retire a bounded set of stale installation snapshots. This pass is
  -- separate so inactive targets cannot consume the requested claim capacity.
  for stale_target in
    select
      target.id as candidate_target_id,
      target.job_id as candidate_job_id
    from private.push_delivery_targets as target
    join private.push_delivery_jobs as job
      on job.id = target.job_id
    left join private.push_installations as installation
      on installation.installation_id = target.installation_id
      and installation.profile_id = job.recipient_profile_id
      and installation.disabled_at is null
      and installation.provider_token is not null
    where target.status = 'pending'
      and target.available_at <= statement_timestamp()
      and (
        target.lease_id is null
        or target.lease_expires_at <= statement_timestamp()
      )
      and installation.installation_id is null
    order by target.available_at, target.created_at, target.id
    limit p_limit
    for update of target skip locked
  loop
    update private.push_delivery_targets as target
    set
      status = 'no_longer_registered',
      lease_owner = null,
      lease_id = null,
      lease_expires_at = null,
      updated_at = statement_timestamp(),
      completed_at = statement_timestamp()
    where target.id = stale_target.candidate_target_id;

    perform private.complete_push_delivery_job_if_terminal(
      stale_target.candidate_job_id
    );
  end loop;

  for candidate in
    select
      target.id as candidate_target_id,
      target.job_id as candidate_job_id,
      target.installation_id as candidate_installation_id,
      installation.platform as candidate_platform,
      installation.provider as candidate_provider,
      installation.provider_token as candidate_provider_token,
      installation.token_version as candidate_token_version,
      job.category_slug as candidate_category_slug,
      job.notification_kind as candidate_notification_kind,
      job.recipient_profile_id as candidate_recipient_profile_id,
      job.actor_profile_id as candidate_actor_profile_id,
      job.project_id as candidate_project_id,
      job.project_kind as candidate_project_kind,
      job.request_id as candidate_request_id,
      job.membership_id as candidate_membership_id,
      job.destination_kind as candidate_destination_kind,
      job.created_at as candidate_source_created_at
    from private.push_delivery_targets as target
    join private.push_delivery_jobs as job
      on job.id = target.job_id
    join private.push_installations as installation
      on installation.installation_id = target.installation_id
      and installation.profile_id = job.recipient_profile_id
      and installation.disabled_at is null
      and installation.provider_token is not null
    where target.status = 'pending'
      and target.available_at <= statement_timestamp()
      and (
        target.lease_id is null
        or target.lease_expires_at <= statement_timestamp()
      )
    order by target.available_at, target.created_at, target.id
    limit p_limit
    for update of target, installation skip locked
  loop
    claim_time := statement_timestamp();
    claim_expires_at := claim_time
      + pg_catalog.make_interval(secs => p_lease_seconds);
    new_lease_id := gen_random_uuid();

    update private.push_delivery_targets as target
    set
      attempt_count = target.attempt_count + 1,
      lease_owner = p_worker_id,
      lease_id = new_lease_id,
      lease_expires_at = claim_expires_at,
      updated_at = claim_time
    where target.id = candidate.candidate_target_id
    returning target.attempt_count into new_attempt_number;

    insert into private.push_delivery_attempts (
      target_id,
      attempt_number,
      lease_id,
      worker_id,
      token_version,
      started_at
    )
    values (
      candidate.candidate_target_id,
      new_attempt_number,
      new_lease_id,
      p_worker_id,
      candidate.candidate_token_version,
      claim_time
    );

    return query select
      candidate.candidate_target_id,
      candidate.candidate_job_id,
      new_lease_id,
      claim_expires_at,
      new_attempt_number,
      candidate.candidate_installation_id,
      candidate.candidate_platform,
      candidate.candidate_provider,
      candidate.candidate_provider_token,
      candidate.candidate_token_version,
      candidate.candidate_category_slug,
      candidate.candidate_notification_kind,
      candidate.candidate_recipient_profile_id,
      candidate.candidate_actor_profile_id,
      candidate.candidate_project_id,
      candidate.candidate_project_kind,
      candidate.candidate_request_id,
      candidate.candidate_membership_id,
      candidate.candidate_destination_kind,
      candidate.candidate_source_created_at;
  end loop;
end;
$$;

create function private.record_push_delivery_result(
  p_target_id uuid,
  p_lease_id uuid,
  p_token_version bigint,
  p_outcome text,
  p_provider_message_id text default null,
  p_provider_error_code text default null,
  p_retry_after_seconds integer default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_record record;
  attempt_record private.push_delivery_attempts%rowtype;
  result_time timestamptz := statement_timestamp();
  retry_time timestamptz;
begin
  if p_target_id is null or p_lease_id is null or p_token_version is null
    or p_token_version < 1 then
    raise exception using
      errcode = '22023',
      message = 'A valid target, lease, and token version are required.';
  end if;

  if p_outcome is null
    or p_outcome not in (
      'delivered',
      'invalid_token',
      'transient_failure',
      'permanent_failure'
    ) then
    raise exception using
      errcode = '22023',
      message = 'Push delivery outcome is unsupported.';
  end if;

  if p_provider_message_id is not null and (
    p_provider_message_id <> btrim(p_provider_message_id)
    or char_length(p_provider_message_id) not between 1 and 255
  ) then
    raise exception using
      errcode = '22023',
      message = 'Provider message ID must contain 1 to 255 trimmed characters.';
  end if;

  if p_provider_error_code is not null and (
    p_provider_error_code <> btrim(p_provider_error_code)
    or char_length(p_provider_error_code) not between 1 and 128
  ) then
    raise exception using
      errcode = '22023',
      message = 'Provider error code must contain 1 to 128 trimmed characters.';
  end if;

  if p_outcome = 'transient_failure' then
    if p_retry_after_seconds is null
      or p_retry_after_seconds < 1
      or p_retry_after_seconds > 86400 then
      raise exception using
        errcode = '22023',
        message = 'Transient push retry delay must be between 1 and 86400 seconds.';
    end if;
    retry_time := result_time
      + pg_catalog.make_interval(secs => p_retry_after_seconds);
  elsif p_retry_after_seconds is not null then
    raise exception using
      errcode = '22023',
      message = 'Only a transient push failure may schedule a retry.';
  end if;

  select
    target.*,
    job.recipient_profile_id
  into target_record
  from private.push_delivery_targets as target
  join private.push_delivery_jobs as job
    on job.id = target.job_id
  where target.id = p_target_id
  for update of target;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Push delivery target was not found.';
  end if;

  if target_record.status <> 'pending'
    or target_record.lease_id is distinct from p_lease_id
    or target_record.lease_expires_at is null
    or target_record.lease_expires_at <= result_time then
    raise exception using
      errcode = '55000',
      message = 'Push delivery lease is unavailable, expired, or superseded.';
  end if;

  select attempt.* into attempt_record
  from private.push_delivery_attempts as attempt
  where attempt.target_id = p_target_id
    and attempt.lease_id = p_lease_id
  for update;

  if not found
    or attempt_record.finished_at is not null
    or attempt_record.token_version <> p_token_version then
    raise exception using
      errcode = '55000',
      message = 'Push delivery attempt is unavailable or uses a stale token version.';
  end if;

  update private.push_delivery_attempts as attempt
  set
    finished_at = result_time,
    outcome = p_outcome,
    provider_message_id = p_provider_message_id,
    provider_error_code = p_provider_error_code,
    retry_available_at = retry_time
  where attempt.id = attempt_record.id;

  if p_outcome = 'transient_failure' then
    update private.push_delivery_targets as target
    set
      available_at = retry_time,
      lease_owner = null,
      lease_id = null,
      lease_expires_at = null,
      updated_at = result_time
    where target.id = p_target_id;
  else
    update private.push_delivery_targets as target
    set
      status = p_outcome,
      lease_owner = null,
      lease_id = null,
      lease_expires_at = null,
      updated_at = result_time,
      completed_at = result_time
    where target.id = p_target_id;

    if p_outcome = 'invalid_token' then
      update private.push_installations as installation
      set
        provider_token = null,
        token_version = installation.token_version + 1,
        updated_at = result_time,
        disabled_at = result_time
      where installation.installation_id = target_record.installation_id
        and installation.profile_id = target_record.recipient_profile_id
        and installation.disabled_at is null
        and installation.token_version = p_token_version;
    end if;

    perform private.complete_push_delivery_job_if_terminal(
      target_record.job_id
    );
  end if;

  return p_outcome;
end;
$$;

create or replace function public.register_own_push_installation(
  p_expected_profile_id uuid,
  p_installation_id uuid,
  p_platform text,
  p_provider_token text
)
returns table (
  installation_id uuid,
  platform text,
  provider text,
  last_registered_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_push_identity(
    p_expected_profile_id
  );
  registration_time timestamptz := statement_timestamp();
  installation_lock_key bigint;
  token_lock_key bigint;
begin
  if p_installation_id is null then
    raise exception using
      errcode = '22023',
      message = 'A valid push installation ID is required.';
  end if;

  if p_platform is null or p_platform not in ('android', 'ios') then
    raise exception using
      errcode = '22023',
      message = 'Push platform must be android or ios.';
  end if;

  if p_provider_token is null
    or p_provider_token <> btrim(p_provider_token)
    or char_length(p_provider_token) not between 1 and 4096 then
    raise exception using
      errcode = '22023',
      message = 'A valid push provider token is required.';
  end if;

  installation_lock_key := pg_catalog.hashtextextended(
    'push-installation:' || p_installation_id::text,
    0
  );
  token_lock_key := pg_catalog.hashtextextended(
    'push-token:fcm:' || p_provider_token,
    0
  );

  if installation_lock_key <= token_lock_key then
    perform pg_catalog.pg_advisory_xact_lock(installation_lock_key);
    if installation_lock_key <> token_lock_key then
      perform pg_catalog.pg_advisory_xact_lock(token_lock_key);
    end if;
  else
    perform pg_catalog.pg_advisory_xact_lock(token_lock_key);
    perform pg_catalog.pg_advisory_xact_lock(installation_lock_key);
  end if;

  perform installation.installation_id
  from private.push_installations as installation
  where installation.installation_id = p_installation_id
    or (
      installation.provider = 'fcm'
      and installation.provider_token = p_provider_token
      and installation.disabled_at is null
    )
  order by installation.installation_id
  for update;

  update private.push_installations as installation
  set
    provider_token = null,
    token_version = installation.token_version + 1,
    updated_at = registration_time,
    disabled_at = registration_time
  where installation.installation_id <> p_installation_id
    and installation.provider = 'fcm'
    and installation.provider_token = p_provider_token
    and installation.disabled_at is null;

  insert into private.push_installations as existing (
    installation_id,
    profile_id,
    platform,
    provider,
    provider_token,
    token_version,
    created_at,
    updated_at,
    last_registered_at,
    disabled_at
  )
  values (
    p_installation_id,
    current_profile_id,
    p_platform,
    'fcm',
    p_provider_token,
    1,
    registration_time,
    registration_time,
    registration_time,
    null
  )
  on conflict on constraint push_installations_pkey do update
  set
    profile_id = excluded.profile_id,
    platform = excluded.platform,
    provider = excluded.provider,
    provider_token = excluded.provider_token,
    token_version = case
      when existing.disabled_at is not null
        or existing.provider_token is distinct from excluded.provider_token
        then existing.token_version + 1
      else existing.token_version
    end,
    updated_at = excluded.updated_at,
    last_registered_at = excluded.last_registered_at,
    disabled_at = null;

  return query
  select
    installation.installation_id,
    installation.platform,
    installation.provider,
    installation.last_registered_at
  from private.push_installations as installation
  where installation.installation_id = p_installation_id;
end;
$$;

create or replace function public.unregister_own_push_installation(
  p_expected_profile_id uuid,
  p_installation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_push_identity(
    p_expected_profile_id
  );
  installation_record private.push_installations%rowtype;
  unregister_time timestamptz := statement_timestamp();
begin
  if p_installation_id is null then
    raise exception using
      errcode = '22023',
      message = 'A valid push installation ID is required.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'push-installation:' || p_installation_id::text,
      0
    )
  );

  select installation.* into installation_record
  from private.push_installations as installation
  where installation.installation_id = p_installation_id
  for update;

  if not found then
    return false;
  end if;

  if installation_record.profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The push installation is unavailable to the authenticated identity.';
  end if;

  if installation_record.disabled_at is not null then
    return false;
  end if;

  update private.push_installations as installation
  set
    provider_token = null,
    token_version = installation.token_version + 1,
    updated_at = unregister_time,
    disabled_at = unregister_time
  where installation.installation_id = p_installation_id;

  return true;
end;
$$;

revoke all privileges on function private.complete_push_delivery_job_if_terminal(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.prepare_push_delivery_jobs(integer)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.claim_push_delivery_targets(text, integer, integer)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.record_push_delivery_result(uuid, uuid, bigint, text, text, text, integer)
  from public, anon, authenticated, service_role;

grant usage on schema private to service_role;
grant execute on function private.prepare_push_delivery_jobs(integer)
  to service_role;
grant execute on function private.claim_push_delivery_targets(text, integer, integer)
  to service_role;
grant execute on function private.record_push_delivery_result(uuid, uuid, bigint, text, text, text, integer)
  to service_role;

comment on function private.prepare_push_delivery_jobs(integer) is
  'Service-only one-time fan-out from available recipient jobs to current active installations; returns aggregate counts and no tokens.';
comment on function private.claim_push_delivery_targets(text, integer, integer) is
  'Service-only SKIP LOCKED claim boundary; returns current private token material only to a trusted direct-database worker.';
comment on function private.record_push_delivery_result(uuid, uuid, bigint, text, text, text, integer) is
  'Service-only lease- and token-version-guarded delivery result transition with bounded provider metadata.';
comment on function public.register_own_push_installation(uuid, uuid, text, text) is
  'Registers or atomically transfers one opaque app installation while advancing a private token generation only when token state changes.';
comment on function public.unregister_own_push_installation(uuid, uuid) is
  'Disables an owned app installation idempotently, clears its private token, and advances its private token generation.';
