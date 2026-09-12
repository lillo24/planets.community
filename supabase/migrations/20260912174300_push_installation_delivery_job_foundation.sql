create table private.push_installations (
  installation_id uuid primary key,
  profile_id uuid not null
    constraint push_installations_profile_id_fkey
      references public.profiles (id) on delete cascade,
  platform text not null
    constraint push_installations_platform_valid check (
      platform in ('android', 'ios')
    ),
  provider text not null default 'fcm'
    constraint push_installations_provider_valid check (provider = 'fcm'),
  provider_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_registered_at timestamptz not null default now(),
  disabled_at timestamptz,
  constraint push_installations_token_state_valid check (
    (
      disabled_at is null
      and provider_token is not null
      and provider_token = btrim(provider_token)
      and char_length(provider_token) between 1 and 4096
    )
    or (
      disabled_at is not null
      and provider_token is null
    )
  ),
  constraint push_installations_timestamps_valid check (
    updated_at >= created_at
    and last_registered_at >= created_at
    and (disabled_at is null or disabled_at >= created_at)
  )
);

comment on table private.push_installations is
  'Private current PLANETS app-installation ownership and FCM registration state; disabled rows retain no provider token.';
comment on column private.push_installations.installation_id is
  'Opaque random app-installation UUID; never a hardware, advertising, account, or email identifier.';
comment on column private.push_installations.provider_token is
  'Private provider registration material; never returned by an ordinary client API or copied into delivery jobs.';

create index push_installations_profile_id_idx
  on private.push_installations (profile_id, installation_id);
create index push_installations_active_profile_platform_idx
  on private.push_installations (profile_id, platform, installation_id)
  where disabled_at is null;
create unique index push_installations_active_provider_token_unique
  on private.push_installations (provider, provider_token)
  where disabled_at is null;

revoke all privileges on table private.push_installations
  from public, anon, authenticated, service_role;

create table private.push_delivery_jobs (
  id uuid primary key default gen_random_uuid(),
  source_outbox_event_id uuid not null
    constraint push_delivery_jobs_source_outbox_event_id_fkey
      references private.outbox_events (id) on delete restrict,
  recipient_profile_id uuid not null
    constraint push_delivery_jobs_recipient_profile_id_fkey
      references public.profiles (id) on delete restrict,
  category_slug text not null
    constraint push_delivery_jobs_category_slug_fkey
      references public.notification_categories (slug) on delete restrict,
  notification_kind text not null
    constraint push_delivery_jobs_notification_kind_valid check (
      notification_kind = btrim(notification_kind)
      and notification_kind ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'
    ),
  actor_profile_id uuid
    constraint push_delivery_jobs_actor_profile_id_fkey
      references public.profiles (id) on delete set null,
  project_id uuid
    constraint push_delivery_jobs_project_id_fkey
      references public.projects (id) on delete restrict,
  project_kind text
    constraint push_delivery_jobs_project_kind_valid check (
      project_kind is null or project_kind in ('one_time', 'recurring')
    ),
  request_id uuid
    constraint push_delivery_jobs_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  membership_id uuid
    constraint push_delivery_jobs_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  destination_kind text not null
    constraint push_delivery_jobs_destination_kind_valid check (
      destination_kind = btrim(destination_kind)
      and destination_kind ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'
    ),
  created_at timestamptz not null,
  available_at timestamptz not null default now(),
  constraint push_delivery_jobs_available_at_valid check (
    available_at >= created_at
  ),
  constraint push_delivery_jobs_project_context_valid check (
    (project_id is null and project_kind is null)
    or (project_id is not null and project_kind is not null)
  ),
  constraint push_delivery_jobs_participation_shape_valid check (
    category_slug <> 'participation'
    or (
      project_id is not null
      and notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected',
        'participant_left',
        'participant_removed'
      )
      and (
        (
          notification_kind in (
            'participation_request_received',
            'participation_request_withdrawn',
            'participation_request_rejected'
          )
          and destination_kind = 'participation_request'
          and request_id is not null
          and membership_id is null
        )
        or (
          notification_kind = 'participation_request_accepted'
          and destination_kind = 'participation_request'
          and request_id is not null
          and membership_id is not null
        )
        or (
          notification_kind = 'participant_left'
          and destination_kind = 'project_participation'
          and request_id is null
          and membership_id is not null
        )
        or (
          notification_kind = 'participant_removed'
          and destination_kind = 'project_detail'
          and request_id is null
          and membership_id is not null
        )
      )
    )
  ),
  constraint push_delivery_jobs_source_recipient_kind_unique unique (
    source_outbox_event_id,
    recipient_profile_id,
    notification_kind
  )
);

comment on table private.push_delivery_jobs is
  'Private recipient-level semantic push eligibility projected from domain events; 06C2 will fan jobs out to active installations.';
comment on column private.push_delivery_jobs.created_at is
  'Canonical source-event chronology, not provider-attempt time.';
comment on column private.push_delivery_jobs.available_at is
  'Earliest time a future 06C2 worker may claim this recipient-level job.';
comment on column private.push_delivery_jobs.project_id is
  'Optional project context for future standalone categories; every current participation job requires it.';

create index push_delivery_jobs_available_idx
  on private.push_delivery_jobs (available_at, created_at, id);
create index push_delivery_jobs_recipient_created_at_idx
  on private.push_delivery_jobs (recipient_profile_id, created_at desc, id desc);
create index push_delivery_jobs_category_slug_idx
  on private.push_delivery_jobs (category_slug, created_at, id);
create index push_delivery_jobs_project_id_idx
  on private.push_delivery_jobs (project_id)
  where project_id is not null;
create index push_delivery_jobs_actor_profile_id_idx
  on private.push_delivery_jobs (actor_profile_id)
  where actor_profile_id is not null;
create index push_delivery_jobs_request_id_idx
  on private.push_delivery_jobs (request_id)
  where request_id is not null;
create index push_delivery_jobs_membership_id_idx
  on private.push_delivery_jobs (membership_id)
  where membership_id is not null;

revoke all privileges on table private.push_delivery_jobs
  from public, anon, authenticated, service_role;

create function private.require_push_identity(p_expected_profile_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required for push registration.';
  end if;

  if p_expected_profile_id is null or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected push-registration identity.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user has no profile identity.';
  end if;

  return current_profile_id;
end;
$$;

create function private.resolve_participation_notification_event(
  p_outbox_event_id uuid
)
returns table (
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
stable
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  request_record record;
  membership_record record;
  v_recipient_profile_id uuid;
  v_actor_profile_id uuid;
  v_project_id uuid;
  v_payload_actor_profile_id uuid;
  v_payload_project_id uuid;
  v_payload_requester_profile_id uuid;
  v_payload_participant_profile_id uuid;
  v_request_id uuid;
  v_membership_id uuid;
  v_notification_kind text;
  v_destination_kind text;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed'
    );

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Participation notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  begin
    v_payload_actor_profile_id := (source_event.payload ->> 'actor_profile_id')::uuid;
    v_payload_project_id := (source_event.payload ->> 'project_id')::uuid;

    if source_event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected'
    ) then
      v_request_id := (source_event.payload ->> 'request_id')::uuid;
      v_payload_requester_profile_id :=
        (source_event.payload ->> 'requester_profile_id')::uuid;
      if source_event.event_type = 'project.join_request_accepted' then
        v_membership_id := (source_event.payload ->> 'membership_id')::uuid;
      end if;
    else
      v_membership_id := (source_event.payload ->> 'membership_id')::uuid;
      v_payload_participant_profile_id :=
        (source_event.payload ->> 'participant_profile_id')::uuid;
    end if;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection could not validate identifiers for outbox event %s.',
          source_event.id
        );
  end;

  if source_event.event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected'
  ) then
    select
      request.id as request_id,
      request.project_id,
      request.requester_profile_id,
      project.creator_profile_id,
      project.project_kind
    into request_record
    from public.project_join_requests as request
    join public.projects as project on project.id = request.project_id
    where request.id = v_request_id;

    if not found
      or v_payload_project_id is distinct from request_record.project_id
      or v_payload_requester_profile_id
        is distinct from request_record.requester_profile_id
      or source_event.payload ->> 'project_kind'
        is distinct from request_record.project_kind then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection could not validate outbox event %s against its canonical join request.',
          source_event.id
        );
    end if;

    v_project_id := request_record.project_id;

    if source_event.event_type = 'project.join_requested' then
      v_recipient_profile_id := request_record.creator_profile_id;
      v_actor_profile_id := request_record.requester_profile_id;
      v_notification_kind := 'participation_request_received';
      v_destination_kind := 'participation_request';
    elsif source_event.event_type = 'project.join_request_withdrawn' then
      v_recipient_profile_id := request_record.creator_profile_id;
      v_actor_profile_id := request_record.requester_profile_id;
      v_notification_kind := 'participation_request_withdrawn';
      v_destination_kind := 'participation_request';
    elsif source_event.event_type = 'project.join_request_accepted' then
      select membership.id
      into v_membership_id
      from public.project_memberships as membership
      where membership.id = v_membership_id
        and membership.originating_request_id = request_record.request_id
        and membership.project_id = request_record.project_id
        and membership.participant_profile_id = request_record.requester_profile_id;

      if not found then
        raise exception using
          errcode = '55000',
          message = format(
            'Notification projection could not validate outbox event %s against its canonical membership.',
            source_event.id
          );
      end if;

      v_recipient_profile_id := request_record.requester_profile_id;
      v_actor_profile_id := request_record.creator_profile_id;
      v_notification_kind := 'participation_request_accepted';
      v_destination_kind := 'participation_request';
    else
      v_recipient_profile_id := request_record.requester_profile_id;
      v_actor_profile_id := request_record.creator_profile_id;
      v_notification_kind := 'participation_request_rejected';
      v_destination_kind := 'participation_request';
    end if;
  else
    select
      membership.id as membership_id,
      membership.project_id,
      membership.participant_profile_id,
      project.creator_profile_id,
      project.project_kind
    into membership_record
    from public.project_memberships as membership
    join public.projects as project on project.id = membership.project_id
    where membership.id = v_membership_id;

    if not found
      or v_payload_project_id is distinct from membership_record.project_id
      or v_payload_participant_profile_id
        is distinct from membership_record.participant_profile_id
      or source_event.payload ->> 'project_kind'
        is distinct from membership_record.project_kind then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection could not validate outbox event %s against its canonical membership.',
          source_event.id
        );
    end if;

    v_project_id := membership_record.project_id;

    if source_event.event_type = 'project.participant_left' then
      v_recipient_profile_id := membership_record.creator_profile_id;
      v_actor_profile_id := membership_record.participant_profile_id;
      v_notification_kind := 'participant_left';
      v_destination_kind := 'project_participation';
    else
      v_recipient_profile_id := membership_record.participant_profile_id;
      v_actor_profile_id := membership_record.creator_profile_id;
      v_notification_kind := 'participant_removed';
      v_destination_kind := 'project_detail';
    end if;
  end if;

  if v_payload_actor_profile_id is distinct from v_actor_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Notification projection found an invalid actor for outbox event %s.',
        source_event.id
      );
  end if;

  return query select
    'participation'::text,
    v_notification_kind,
    v_recipient_profile_id,
    v_actor_profile_id,
    v_project_id,
    case
      when source_event.payload ->> 'project_kind' in ('one_time', 'recurring')
        then source_event.payload ->> 'project_kind'
    end,
    v_request_id,
    v_membership_id,
    v_destination_kind,
    source_event.created_at;
end;
$$;

create function public.register_own_push_installation(
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

  -- A token or installation may not be concurrently reassigned through two
  -- successful registrations. Explicit key order avoids lock inversions;
  -- hash collisions only serialize unrelated registrations.
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
    updated_at = registration_time,
    disabled_at = registration_time
  where installation.installation_id <> p_installation_id
    and installation.provider = 'fcm'
    and installation.provider_token = p_provider_token
    and installation.disabled_at is null;

  insert into private.push_installations (
    installation_id,
    profile_id,
    platform,
    provider,
    provider_token,
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
    registration_time,
    registration_time,
    registration_time,
    null
  )
  on conflict (installation_id) do update
  set
    profile_id = excluded.profile_id,
    platform = excluded.platform,
    provider = excluded.provider,
    provider_token = excluded.provider_token,
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

create function public.unregister_own_push_installation(
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
    updated_at = unregister_time,
    disabled_at = unregister_time
  where installation.installation_id = p_installation_id;

  return true;
end;
$$;

create or replace function public.process_notification_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  notifications_created integer,
  notifications_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  v_in_app_enabled boolean;
  v_processed_count integer := 0;
  v_notifications_created integer := 0;
  v_notifications_suppressed integer := 0;
  v_inserted_count integer;
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'notifications.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    select * into resolved_event
    from private.resolve_participation_notification_event(source_event.id);

    select coalesce(
      preference.in_app_enabled,
      category.default_in_app_enabled
    )
    into v_in_app_enabled
    from public.notification_categories as category
    left join public.profile_notification_preferences as preference
      on preference.profile_id = resolved_event.recipient_profile_id
      and preference.category_slug = category.slug
    where category.slug = resolved_event.category_slug;

    if v_in_app_enabled is null then
      raise exception using
        errcode = '55000',
        message = 'The participation notification category is unavailable.';
    end if;

    if v_in_app_enabled then
      insert into public.notifications (
        recipient_profile_id,
        category_slug,
        notification_kind,
        source_outbox_event_id,
        project_id,
        actor_profile_id,
        request_id,
        membership_id,
        destination_kind,
        created_at
      )
      values (
        resolved_event.recipient_profile_id,
        resolved_event.category_slug,
        resolved_event.notification_kind,
        source_event.id,
        resolved_event.project_id,
        resolved_event.actor_profile_id,
        resolved_event.request_id,
        resolved_event.membership_id,
        resolved_event.destination_kind,
        resolved_event.source_created_at
      )
      on conflict (
        source_outbox_event_id,
        recipient_profile_id,
        notification_kind
      ) do nothing;

      get diagnostics v_inserted_count = row_count;
      v_notifications_created := v_notifications_created + v_inserted_count;
    else
      v_notifications_suppressed := v_notifications_suppressed + 1;
    end if;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'notifications.v1', statement_timestamp())
    on conflict do nothing;

    v_processed_count := v_processed_count + 1;
  end loop;

  return query select
    v_processed_count,
    v_notifications_created,
    v_notifications_suppressed;
end;
$$;

create function public.process_push_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  jobs_created integer,
  jobs_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  v_push_enabled boolean;
  v_processed_count integer := 0;
  v_jobs_created integer := 0;
  v_jobs_suppressed integer := 0;
  v_inserted_count integer;
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception using
      errcode = '22023',
      message = 'Push projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'push.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    select * into resolved_event
    from private.resolve_participation_notification_event(source_event.id);

    select coalesce(
      preference.push_enabled,
      category.default_push_enabled
    )
    into v_push_enabled
    from public.notification_categories as category
    left join public.profile_notification_preferences as preference
      on preference.profile_id = resolved_event.recipient_profile_id
      and preference.category_slug = category.slug
    where category.slug = resolved_event.category_slug;

    if v_push_enabled is null then
      raise exception using
        errcode = '55000',
        message = 'The participation notification category is unavailable.';
    end if;

    if v_push_enabled then
      insert into private.push_delivery_jobs (
        source_outbox_event_id,
        recipient_profile_id,
        category_slug,
        notification_kind,
        actor_profile_id,
        project_id,
        project_kind,
        request_id,
        membership_id,
        destination_kind,
        created_at,
        available_at
      )
      values (
        source_event.id,
        resolved_event.recipient_profile_id,
        resolved_event.category_slug,
        resolved_event.notification_kind,
        resolved_event.actor_profile_id,
        resolved_event.project_id,
        resolved_event.project_kind,
        resolved_event.request_id,
        resolved_event.membership_id,
        resolved_event.destination_kind,
        resolved_event.source_created_at,
        statement_timestamp()
      )
      on conflict (
        source_outbox_event_id,
        recipient_profile_id,
        notification_kind
      ) do nothing;

      get diagnostics v_inserted_count = row_count;
      v_jobs_created := v_jobs_created + v_inserted_count;
    else
      v_jobs_suppressed := v_jobs_suppressed + 1;
    end if;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'push.v1', statement_timestamp())
    on conflict do nothing;

    v_processed_count := v_processed_count + 1;
  end loop;

  return query select
    v_processed_count,
    v_jobs_created,
    v_jobs_suppressed;
end;
$$;

-- Events already present when push.v1 is introduced are acknowledged without
-- creating jobs, preventing future provider setup from delivering old alerts.
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
select
  event.id,
  'push.v1',
  statement_timestamp()
from private.outbox_events as event
where event.event_type in (
  'project.join_requested',
  'project.join_request_withdrawn',
  'project.join_request_accepted',
  'project.join_request_rejected',
  'project.participant_left',
  'project.participant_removed'
)
on conflict do nothing;

revoke all privileges on function private.require_push_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resolve_participation_notification_event(uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.register_own_push_installation(uuid, uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.unregister_own_push_installation(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.process_notification_outbox_batch(integer)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.process_push_outbox_batch(integer)
  from public, anon, authenticated, service_role;

grant execute on function public.register_own_push_installation(uuid, uuid, text, text)
  to authenticated;
grant execute on function public.unregister_own_push_installation(uuid, uuid)
  to authenticated;
grant execute on function public.process_notification_outbox_batch(integer)
  to service_role;
grant execute on function public.process_push_outbox_batch(integer)
  to service_role;

comment on function private.resolve_participation_notification_event(uuid) is
  'Validates one supported source event against canonical request, membership, and project state and returns shared channel-neutral semantic notification facts.';
comment on function public.register_own_push_installation(uuid, uuid, text, text) is
  'Registers or atomically transfers one opaque app installation for the expected authenticated profile without returning its private FCM token.';
comment on function public.unregister_own_push_installation(uuid, uuid) is
  'Disables an owned app installation idempotently and clears its private provider token.';
comment on function public.process_notification_outbox_batch(integer) is
  'Service-only, concurrency-safe notifications.v1 projector using the shared semantic resolver for the six Plan 05A participation events.';
comment on function public.process_push_outbox_batch(integer) is
  'Service-only, concurrency-safe push.v1 projector creating recipient-level jobs from push preference state without provider delivery.';
