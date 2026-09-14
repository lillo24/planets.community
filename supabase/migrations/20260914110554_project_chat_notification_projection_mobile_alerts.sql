alter table public.notifications
  add column chat_id uuid
    constraint notifications_chat_id_fkey
      references public.project_group_chats (id) on delete restrict,
  add column message_id uuid
    constraint notifications_message_id_fkey
      references public.project_chat_messages (id) on delete restrict;

alter table public.notifications
  drop constraint notifications_kind_valid,
  drop constraint notifications_destination_kind_valid,
  drop constraint notifications_participation_category_valid,
  drop constraint notifications_current_participation_project_required,
  drop constraint notifications_destination_matches_kind,
  drop constraint notifications_reference_shape_valid;

alter table public.notifications
  add constraint notifications_kind_valid check (
    notification_kind in (
      'participation_request_received',
      'participation_request_withdrawn',
      'participation_request_accepted',
      'participation_request_rejected',
      'participant_left',
      'participant_removed',
      'chat_message_received'
    )
  ),
  add constraint notifications_destination_kind_valid check (
    destination_kind in (
      'participation_request',
      'project_participation',
      'project_detail',
      'project_chat'
    )
  ),
  add constraint notifications_category_matches_kind check (
    (
      category_slug = 'participation'
      and notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected',
        'participant_left',
        'participant_removed'
      )
    )
    or (
      category_slug = 'chat'
      and notification_kind = 'chat_message_received'
    )
  ),
  add constraint notifications_current_participation_project_required check (
    notification_kind not in (
      'participation_request_received',
      'participation_request_withdrawn',
      'participation_request_accepted',
      'participation_request_rejected',
      'participant_left',
      'participant_removed',
      'chat_message_received'
    )
    or project_id is not null
  ),
  add constraint notifications_destination_matches_kind check (
    (
      notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected'
      )
      and destination_kind = 'participation_request'
    )
    or (
      notification_kind = 'participant_left'
      and destination_kind = 'project_participation'
    )
    or (
      notification_kind = 'participant_removed'
      and destination_kind = 'project_detail'
    )
    or (
      notification_kind = 'chat_message_received'
      and destination_kind = 'project_chat'
    )
  ),
  add constraint notifications_reference_shape_valid check (
    (
      notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_rejected'
      )
      and request_id is not null
      and membership_id is null
      and chat_id is null
      and message_id is null
    )
    or (
      notification_kind = 'participation_request_accepted'
      and request_id is not null
      and membership_id is not null
      and chat_id is null
      and message_id is null
    )
    or (
      notification_kind in ('participant_left', 'participant_removed')
      and request_id is null
      and membership_id is not null
      and chat_id is null
      and message_id is null
    )
    or (
      notification_kind = 'chat_message_received'
      and actor_profile_id is not null
      and request_id is null
      and membership_id is null
      and chat_id is not null
      and message_id is not null
    )
  );

comment on column public.notifications.chat_id is
  'Canonical Project group-chat destination for chat alerts; never notification display copy.';
comment on column public.notifications.message_id is
  'Canonical durable message identity used for provenance only; message bodies never enter notification state.';

create index notifications_chat_id_idx
  on public.notifications (chat_id)
  where chat_id is not null;
create index notifications_message_id_idx
  on public.notifications (message_id)
  where message_id is not null;

alter table private.push_delivery_jobs
  add column chat_id uuid
    constraint push_delivery_jobs_chat_id_fkey
      references public.project_group_chats (id) on delete restrict,
  add column message_id uuid
    constraint push_delivery_jobs_message_id_fkey
      references public.project_chat_messages (id) on delete restrict,
  add constraint push_delivery_jobs_chat_shape_valid check (
    (
      category_slug = 'chat'
      and notification_kind = 'chat_message_received'
      and destination_kind = 'project_chat'
      and project_id is not null
      and project_kind is not null
      and actor_profile_id is not null
      and request_id is null
      and membership_id is null
      and chat_id is not null
      and message_id is not null
    )
    or (
      category_slug <> 'chat'
      and chat_id is null
      and message_id is null
    )
  );

comment on column private.push_delivery_jobs.chat_id is
  'Provider-neutral Project chat destination context for a future trusted adapter.';
comment on column private.push_delivery_jobs.message_id is
  'Canonical message identity for provider-neutral provenance; the message body is never copied.';

create index push_delivery_jobs_chat_id_idx
  on private.push_delivery_jobs (chat_id)
  where chat_id is not null;
create index push_delivery_jobs_message_id_idx
  on private.push_delivery_jobs (message_id)
  where message_id is not null;

drop index private.outbox_events_notification_sources_available_idx;
create index outbox_events_notification_sources_available_idx
  on private.outbox_events (available_at, created_at, id)
  where event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed',
    'project.chat_message_sent'
  );

create function private.resolve_chat_message_notification_event(
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
  chat_id uuid,
  message_id uuid,
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
  message_record record;
  v_payload_chat_id uuid;
  v_payload_project_id uuid;
  v_payload_message_id uuid;
  v_payload_sender_profile_id uuid;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type = 'project.chat_message_sent';

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Project chat notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> 5
    or not source_event.payload ?& array[
      'chat_id',
      'project_id',
      'project_kind',
      'message_id',
      'sender_profile_id'
    ] then
    raise exception using
      errcode = '55000',
      message = format(
        'Project chat notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    v_payload_chat_id := (source_event.payload ->> 'chat_id')::uuid;
    v_payload_project_id := (source_event.payload ->> 'project_id')::uuid;
    v_payload_message_id := (source_event.payload ->> 'message_id')::uuid;
    v_payload_sender_profile_id :=
      (source_event.payload ->> 'sender_profile_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Project chat notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  select
    message.id as message_id,
    message.chat_id,
    message.sender_profile_id,
    message.created_at,
    chat.project_id,
    project.project_kind,
    project.creator_profile_id
  into message_record
  from public.project_chat_messages as message
  join public.project_group_chats as chat on chat.id = message.chat_id
  join public.projects as project on project.id = chat.project_id
  join public.profiles as sender on sender.id = message.sender_profile_id
  where message.id = v_payload_message_id;

  if not found
    or v_payload_chat_id is distinct from message_record.chat_id
    or v_payload_project_id is distinct from message_record.project_id
    or v_payload_sender_profile_id
      is distinct from message_record.sender_profile_id
    or source_event.payload ->> 'project_kind'
      is distinct from message_record.project_kind then
    raise exception using
      errcode = '55000',
      message = format(
        'Project chat notification event %s does not match its canonical message.',
        source_event.id
      );
  end if;

  return query
  select
    'chat'::text,
    'chat_message_received'::text,
    recipient.recipient_profile_id,
    message_record.sender_profile_id,
    message_record.project_id,
    message_record.project_kind,
    null::uuid,
    null::uuid,
    message_record.chat_id,
    message_record.message_id,
    'project_chat'::text,
    message_record.created_at
  from (
    select message_record.creator_profile_id as recipient_profile_id
    union
    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = message_record.project_id
      and membership.joined_at <= message_record.created_at
      and (
        coalesce(membership.left_at, membership.removed_at) is null
        or message_record.created_at
          < coalesce(membership.left_at, membership.removed_at)
      )
  ) as recipient
  where recipient.recipient_profile_id <> message_record.sender_profile_id
  order by recipient.recipient_profile_id;
end;
$$;

create function private.resolve_notification_event(
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
  chat_id uuid,
  message_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_event_type text;
begin
  select event.event_type into v_event_type
  from private.outbox_events as event
  where event.id = p_outbox_event_id;

  if not found then
    raise exception using
      errcode = '55000',
      message = format('Notification event %s is unavailable.', p_outbox_event_id);
  end if;

  if v_event_type = 'project.chat_message_sent' then
    return query
    select *
    from private.resolve_chat_message_notification_event(p_outbox_event_id);
    return;
  end if;

  if v_event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed'
  ) then
    return query
    select
      resolved.category_slug,
      resolved.notification_kind,
      resolved.recipient_profile_id,
      resolved.actor_profile_id,
      resolved.project_id,
      resolved.project_kind,
      resolved.request_id,
      resolved.membership_id,
      null::uuid,
      null::uuid,
      resolved.destination_kind,
      resolved.source_created_at
    from private.resolve_participation_notification_event(
      p_outbox_event_id
    ) as resolved;
    return;
  end if;

  raise exception using
    errcode = '55000',
    message = format('Notification event %s is unsupported.', p_outbox_event_id);
end;
$$;

revoke all privileges on function private.resolve_chat_message_notification_event(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resolve_notification_event(uuid)
  from public, anon, authenticated, service_role;

comment on function private.resolve_chat_message_notification_event(uuid) is
  'Validates an identifier-only Project chat outbox event against canonical message state and returns recipients entitled at message.created_at, excluding the sender.';
comment on function private.resolve_notification_event(uuid) is
  'Normalizes supported participation and Project chat events into zero or more recipient-level semantic alert rows.';

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
      'project.participant_removed',
      'project.chat_message_sent'
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
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
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
          message = 'The resolved notification category is unavailable.';
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
          created_at,
          chat_id,
          message_id
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
          resolved_event.source_created_at,
          resolved_event.chat_id,
          resolved_event.message_id
        )
        on conflict (
          source_outbox_event_id,
          recipient_profile_id,
          notification_kind
        ) do nothing;

        get diagnostics v_inserted_count = row_count;
        v_notifications_created :=
          v_notifications_created + v_inserted_count;
      else
        v_notifications_suppressed := v_notifications_suppressed + 1;
      end if;
    end loop;

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

create or replace function public.process_push_outbox_batch(
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
      'project.participant_removed',
      'project.chat_message_sent'
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
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
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
          message = 'The resolved notification category is unavailable.';
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
          available_at,
          chat_id,
          message_id
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
          statement_timestamp(),
          resolved_event.chat_id,
          resolved_event.message_id
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
    end loop;

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

-- Chat messages predating 06D are deliberately acknowledged for both alert
-- consumers without creating retrospective notifications or push jobs.
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
select
  event.id,
  consumer.consumer_key,
  statement_timestamp()
from private.outbox_events as event
cross join (
  values ('notifications.v1'::text), ('push.v1'::text)
) as consumer(consumer_key)
where event.event_type = 'project.chat_message_sent'
on conflict do nothing;

drop function public.list_own_notifications(uuid, integer, timestamptz, uuid);

create function public.list_own_notifications(
  p_expected_profile_id uuid,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  notification_id uuid,
  category_slug text,
  notification_kind text,
  created_at timestamptz,
  read_at timestamptz,
  project_id uuid,
  project_kind text,
  destination_kind text,
  request_id uuid,
  chat_id uuid,
  message_id uuid,
  project_title text,
  actor_profile_id uuid,
  actor_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification page size must be between 1 and 100.';
  end if;

  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Notification pagination requires both cursor timestamp and cursor ID.';
  end if;

  return query
  select
    notification.id,
    notification.category_slug,
    notification.notification_kind,
    notification.created_at,
    notification.read_at,
    notification.project_id,
    project.project_kind,
    notification.destination_kind,
    notification.request_id,
    notification.chat_id,
    notification.message_id,
    case
      when project.project_kind = 'one_time' then proposal.title
      when project.project_kind = 'recurring' then activity.title
    end,
    notification.actor_profile_id,
    actor.display_name
  from public.notifications as notification
  left join public.projects as project on project.id = notification.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  left join public.profiles as actor on actor.id = notification.actor_profile_id
  where notification.recipient_profile_id = current_profile_id
    and (
      p_cursor_created_at is null
      or (notification.created_at, notification.id)
        < (p_cursor_created_at, p_cursor_id)
    )
  order by notification.created_at desc, notification.id desc
  limit p_limit;
end;
$$;

revoke all privileges on function public.list_own_notifications(uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_own_notifications(uuid, integer, timestamptz, uuid)
  to authenticated;

comment on function public.list_own_notifications(uuid, integer, timestamptz, uuid) is
  'Returns one expected profile''s semantic notification page with safe Project/actor display context and optional chat/message identifiers, never message bodies or outbox payloads.';

drop function private.claim_push_delivery_targets(text, integer, integer);

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
  chat_id uuid,
  message_id uuid,
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

  -- Retire a bounded set of snapshots whose installations are no longer
  -- active before filling the requested claim capacity.
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
      job.chat_id as candidate_chat_id,
      job.message_id as candidate_message_id,
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
      candidate.candidate_chat_id,
      candidate.candidate_message_id,
      candidate.candidate_destination_kind,
      candidate.candidate_source_created_at;
  end loop;
end;
$$;

revoke all privileges on function private.claim_push_delivery_targets(text, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function private.claim_push_delivery_targets(text, integer, integer)
  to service_role;

comment on function private.claim_push_delivery_targets(text, integer, integer) is
  'Claims due delivery targets with expiring leases and returns the current private provider token plus provider-neutral notification semantics, including optional chat/message identifiers, only to service_role.';
