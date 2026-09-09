create table public.notification_categories (
  slug text primary key
    constraint notification_categories_slug_valid check (
      slug ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'
    ),
  sort_order smallint not null unique
    constraint notification_categories_sort_order_valid check (sort_order >= 0),
  default_in_app_enabled boolean not null,
  default_push_enabled boolean not null,
  user_configurable boolean not null default true
);

comment on table public.notification_categories is
  'System-managed notification categories and channel defaults; absent profile overrides inherit these values.';

insert into public.notification_categories (
  slug,
  sort_order,
  default_in_app_enabled,
  default_push_enabled,
  user_configurable
)
values
  ('participation', 10, true, true, true),
  ('project_activity', 20, true, true, true),
  ('matching', 30, true, true, true),
  ('chat', 40, true, true, true),
  ('resources', 50, true, true, true);

alter table public.notification_categories enable row level security;
revoke all privileges on table public.notification_categories
  from public, anon, authenticated, service_role;

create table public.profile_notification_preferences (
  profile_id uuid not null
    constraint profile_notification_preferences_profile_id_fkey
      references public.profiles (id) on delete cascade,
  category_slug text not null
    constraint profile_notification_preferences_category_slug_fkey
      references public.notification_categories (slug) on delete restrict,
  in_app_enabled boolean not null,
  push_enabled boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, category_slug),
  constraint profile_notification_preferences_updated_at_valid check (
    updated_at >= created_at
  )
);

comment on table public.profile_notification_preferences is
  'Per-profile channel overrides; categories without a row use the controlled catalog defaults.';

create index profile_notification_preferences_category_slug_idx
  on public.profile_notification_preferences (category_slug, profile_id);

alter table public.profile_notification_preferences enable row level security;
revoke all privileges on table public.profile_notification_preferences
  from public, anon, authenticated, service_role;

create function private.set_notification_preference_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

create trigger profile_notification_preferences_set_updated_at
before update on public.profile_notification_preferences
for each row
execute function private.set_notification_preference_updated_at();

create table private.outbox_consumer_receipts (
  outbox_event_id uuid not null
    constraint outbox_consumer_receipts_outbox_event_id_fkey
      references private.outbox_events (id) on delete cascade,
  consumer_key text not null
    constraint outbox_consumer_receipts_consumer_key_valid check (
      consumer_key = btrim(consumer_key)
      and char_length(consumer_key) between 1 and 100
    ),
  processed_at timestamptz not null default now(),
  primary key (outbox_event_id, consumer_key)
);

comment on table private.outbox_consumer_receipts is
  'Independent per-consumer acknowledgements; one consumer receipt never hides an outbox event from another consumer.';

create index outbox_consumer_receipts_consumer_processed_idx
  on private.outbox_consumer_receipts (
    consumer_key,
    processed_at,
    outbox_event_id
  );

revoke all privileges on table private.outbox_consumer_receipts
  from public, anon, authenticated, service_role;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_profile_id uuid not null
    constraint notifications_recipient_profile_id_fkey
      references public.profiles (id) on delete restrict,
  category_slug text not null
    constraint notifications_category_slug_fkey
      references public.notification_categories (slug) on delete restrict,
  notification_kind text not null
    constraint notifications_kind_valid check (
      notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected',
        'participant_left',
        'participant_removed'
      )
    ),
  source_outbox_event_id uuid not null
    constraint notifications_source_outbox_event_id_fkey
      references private.outbox_events (id) on delete restrict,
  project_id uuid
    constraint notifications_project_id_fkey
      references public.projects (id) on delete restrict,
  actor_profile_id uuid
    constraint notifications_actor_profile_id_fkey
      references public.profiles (id) on delete set null,
  request_id uuid
    constraint notifications_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  membership_id uuid
    constraint notifications_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  destination_kind text not null
    constraint notifications_destination_kind_valid check (
      destination_kind in (
        'participation_request',
        'project_participation',
        'project_detail'
      )
    ),
  created_at timestamptz not null,
  read_at timestamptz,
  constraint notifications_read_at_valid check (
    read_at is null or read_at >= created_at
  ),
  constraint notifications_participation_category_valid check (
    category_slug = 'participation'
  ),
  constraint notifications_current_participation_project_required check (
    notification_kind not in (
      'participation_request_received',
      'participation_request_withdrawn',
      'participation_request_accepted',
      'participation_request_rejected',
      'participant_left',
      'participant_removed'
    )
    or project_id is not null
  ),
  constraint notifications_destination_matches_kind check (
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
  ),
  constraint notifications_reference_shape_valid check (
    (
      notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_rejected'
      )
      and request_id is not null
      and membership_id is null
    )
    or (
      notification_kind = 'participation_request_accepted'
      and request_id is not null
      and membership_id is not null
    )
    or (
      notification_kind in ('participant_left', 'participant_removed')
      and request_id is null
      and membership_id is not null
    )
  ),
  constraint notifications_source_recipient_kind_unique unique (
    source_outbox_event_id,
    recipient_profile_id,
    notification_kind
  )
);

comment on table public.notifications is
  'Recipient-owned semantic notification state projected from private outbox events; private source payloads are never copied.';
comment on column public.notifications.destination_kind is
  'Backend-route-agnostic semantic target interpreted with project_id, project kind, and request_id when the target is participation_request.';
comment on column public.notifications.project_id is
  'Optional project context at the notification-domain boundary; current participation kinds require it through a checked invariant.';
comment on column public.notifications.source_outbox_event_id is
  'Projection provenance and idempotency identity; omitted from ordinary inbox API results.';

create index notifications_recipient_created_at_idx
  on public.notifications (recipient_profile_id, created_at desc, id desc);
create index notifications_recipient_unread_idx
  on public.notifications (recipient_profile_id, created_at desc, id desc)
  where read_at is null;
create index notifications_category_slug_idx
  on public.notifications (category_slug);
create index notifications_project_id_idx
  on public.notifications (project_id);
create index notifications_actor_profile_id_idx
  on public.notifications (actor_profile_id)
  where actor_profile_id is not null;
create index notifications_request_id_idx
  on public.notifications (request_id)
  where request_id is not null;
create index notifications_membership_id_idx
  on public.notifications (membership_id)
  where membership_id is not null;

alter table public.notifications enable row level security;
revoke all privileges on table public.notifications
  from public, anon, authenticated, service_role;

create index outbox_events_notification_sources_available_idx
  on private.outbox_events (available_at, created_at, id)
  where event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed'
  );

comment on table private.outbox_events is
  'Transaction-local event handoff records; each downstream consumer acknowledges independently in private.outbox_consumer_receipts.';
comment on column private.outbox_events.published_at is
  'Legacy/global dispatcher metadata only; independent consumers must acknowledge events in private.outbox_consumer_receipts and must not use this field as their receipt.';

-- Existing source events predate notification support. Mark them processed for this
-- consumer without creating a surprise historical inbox; future consumers remain free
-- to make their own explicit backfill decision.
insert into private.outbox_consumer_receipts (outbox_event_id, consumer_key)
select event.id, 'notifications.v1'
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

create function private.require_notification_identity(p_expected_profile_id uuid)
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
      message = 'Authentication is required for notifications.';
  end if;

  if p_expected_profile_id is null or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected notification identity.';
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

create function public.list_own_notification_preferences(
  p_expected_profile_id uuid
)
returns table (
  category_slug text,
  sort_order smallint,
  in_app_enabled boolean,
  push_enabled boolean,
  has_override boolean,
  user_configurable boolean
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
  return query
  select
    category.slug,
    category.sort_order,
    coalesce(preference.in_app_enabled, category.default_in_app_enabled),
    coalesce(preference.push_enabled, category.default_push_enabled),
    preference.profile_id is not null,
    category.user_configurable
  from public.notification_categories as category
  left join public.profile_notification_preferences as preference
    on preference.profile_id = current_profile_id
    and preference.category_slug = category.slug
  order by category.sort_order, category.slug;
end;
$$;

create function public.set_own_notification_preference(
  p_expected_profile_id uuid,
  p_category_slug text,
  p_in_app_enabled boolean,
  p_push_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
begin
  if p_category_slug is null
    or p_in_app_enabled is null
    or p_push_enabled is null then
    raise exception using
      errcode = '22023',
      message = 'Notification category and channel preferences are required.';
  end if;

  if not exists (
    select 1
    from public.notification_categories as category
    where category.slug = p_category_slug
      and category.user_configurable
  ) then
    raise exception using
      errcode = '22023',
      message = 'The notification category is unknown or not user-configurable.';
  end if;

  insert into public.profile_notification_preferences (
    profile_id,
    category_slug,
    in_app_enabled,
    push_enabled
  )
  values (
    current_profile_id,
    p_category_slug,
    p_in_app_enabled,
    p_push_enabled
  )
  on conflict (profile_id, category_slug) do update
  set
    in_app_enabled = excluded.in_app_enabled,
    push_enabled = excluded.push_enabled;
end;
$$;

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

create function public.get_own_unread_notification_count(
  p_expected_profile_id uuid
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
  unread_count bigint;
begin
  select count(*) into unread_count
  from public.notifications as notification
  where notification.recipient_profile_id = current_profile_id
    and notification.read_at is null;

  return unread_count;
end;
$$;

create function public.mark_notification_read(
  p_expected_profile_id uuid,
  p_notification_id uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
  effective_read_at timestamptz;
begin
  update public.notifications as notification
  set read_at = coalesce(notification.read_at, statement_timestamp())
  where notification.id = p_notification_id
    and notification.recipient_profile_id = current_profile_id
  returning notification.read_at into effective_read_at;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The notification is unavailable to the authenticated identity.';
  end if;

  return effective_read_at;
end;
$$;

create function public.mark_all_notifications_read(
  p_expected_profile_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
  affected_count integer;
begin
  update public.notifications as notification
  set read_at = statement_timestamp()
  where notification.recipient_profile_id = current_profile_id
    and notification.read_at is null;

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

create function public.process_notification_outbox_batch(
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
  request_record record;
  membership_record record;
  v_recipient_profile_id uuid;
  v_actor_profile_id uuid;
  v_project_id uuid;
  v_request_id uuid;
  v_membership_id uuid;
  v_notification_kind text;
  v_destination_kind text;
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
    v_recipient_profile_id := null;
    v_actor_profile_id := null;
    v_project_id := null;
    v_request_id := null;
    v_membership_id := null;
    v_notification_kind := null;
    v_destination_kind := null;

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
      where request.id = (source_event.payload ->> 'request_id')::uuid;

      if not found
        or (source_event.payload ->> 'project_id')::uuid
          is distinct from request_record.project_id
        or (source_event.payload ->> 'requester_profile_id')::uuid
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
      v_request_id := request_record.request_id;

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
        where membership.id = (source_event.payload ->> 'membership_id')::uuid
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
      where membership.id = (source_event.payload ->> 'membership_id')::uuid;

      if not found
        or (source_event.payload ->> 'project_id')::uuid
          is distinct from membership_record.project_id
        or (source_event.payload ->> 'participant_profile_id')::uuid
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
      v_membership_id := membership_record.membership_id;

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

    if (source_event.payload ->> 'actor_profile_id')::uuid
      is distinct from v_actor_profile_id then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection found an invalid actor for outbox event %s.',
          source_event.id
        );
    end if;

    select coalesce(
      preference.in_app_enabled,
      category.default_in_app_enabled
    )
    into v_in_app_enabled
    from public.notification_categories as category
    left join public.profile_notification_preferences as preference
      on preference.profile_id = v_recipient_profile_id
      and preference.category_slug = category.slug
    where category.slug = 'participation';

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
        v_recipient_profile_id,
        'participation',
        v_notification_kind,
        source_event.id,
        v_project_id,
        v_actor_profile_id,
        v_request_id,
        v_membership_id,
        v_destination_kind,
        source_event.created_at
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

revoke all privileges on function private.set_notification_preference_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_notification_identity(uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.list_own_notification_preferences(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.set_own_notification_preference(uuid, text, boolean, boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_notifications(uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_unread_notification_count(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.mark_notification_read(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.mark_all_notifications_read(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.process_notification_outbox_batch(integer)
  from public, anon, authenticated, service_role;

grant execute on function public.list_own_notification_preferences(uuid)
  to authenticated;
grant execute on function public.set_own_notification_preference(uuid, text, boolean, boolean)
  to authenticated;
grant execute on function public.list_own_notifications(uuid, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_own_unread_notification_count(uuid)
  to authenticated;
grant execute on function public.mark_notification_read(uuid, uuid)
  to authenticated;
grant execute on function public.mark_all_notifications_read(uuid)
  to authenticated;
grant execute on function public.process_notification_outbox_batch(integer)
  to service_role;

comment on function public.list_own_notification_preferences(uuid) is
  'Returns every controlled category with effective values for the expected authenticated profile.';
comment on function public.set_own_notification_preference(uuid, text, boolean, boolean) is
  'Upserts one future-facing category/channel override for the expected authenticated profile.';
comment on function public.list_own_notifications(uuid, integer, timestamptz, uuid) is
  'Returns a keyset-paginated private inbox with semantic request/project targets plus safe current presentation context, never raw source payload.';
comment on function public.process_notification_outbox_batch(integer) is
  'Service-only, concurrency-safe notifications.v1 projector for the six Plan 05A participation events.';
