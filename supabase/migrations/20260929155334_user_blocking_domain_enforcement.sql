-- 09B1 stores directional user decisions privately while enforcing one
-- symmetric barrier at every new direct-interaction boundary. The pair lock is
-- always acquired before Project/Resource rows so Block versus Request/Accept
-- has only serial outcomes and does not reverse either domain's lock order.

create table private.user_block_episodes (
  id uuid primary key default gen_random_uuid(),
  blocker_profile_id uuid not null
    constraint user_block_episodes_blocker_profile_id_fkey
      references public.profiles (id) on delete restrict,
  blocked_profile_id uuid not null
    constraint user_block_episodes_blocked_profile_id_fkey
      references public.profiles (id) on delete restrict,
  blocked_at timestamptz not null default now(),
  unblocked_at timestamptz,
  constraint user_block_episodes_profiles_differ check (
    blocker_profile_id <> blocked_profile_id
  ),
  constraint user_block_episodes_interval_valid check (
    unblocked_at is null or unblocked_at >= blocked_at
  )
);

comment on table private.user_block_episodes is
  'Private append-preserved directional user-block episodes. An active episode contributes to a symmetric new-interaction barrier without changing public visibility or accepted coordination.';
comment on column private.user_block_episodes.unblocked_at is
  'Null while active; unblocking closes the episode without deleting history. A later re-block creates a new episode.';

create unique index user_block_episodes_one_active_direction_idx
  on private.user_block_episodes (blocker_profile_id, blocked_profile_id)
  where unblocked_at is null;

create index user_block_episodes_active_outbound_page_idx
  on private.user_block_episodes (
    blocker_profile_id,
    blocked_at desc,
    id desc
  )
  where unblocked_at is null;

create index user_block_episodes_active_inbound_lookup_idx
  on private.user_block_episodes (blocked_profile_id, blocker_profile_id)
  where unblocked_at is null;

alter table private.user_block_episodes enable row level security;

revoke all privileges on table private.user_block_episodes
  from public, anon, authenticated, service_role;

create function private.protect_user_block_episode_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '55000',
      message = 'User block history cannot be deleted.';
  end if;

  if new.id <> old.id
    or new.blocker_profile_id <> old.blocker_profile_id
    or new.blocked_profile_id <> old.blocked_profile_id
    or new.blocked_at <> old.blocked_at then
    raise exception using
      errcode = '55000',
      message = 'User block episode identity is immutable.';
  end if;

  if old.unblocked_at is not null
    and new.unblocked_at is distinct from old.unblocked_at then
    raise exception using
      errcode = '55000',
      message = 'A closed user block episode cannot be changed or reopened.';
  end if;

  return new;
end;
$$;

create trigger user_block_episodes_preserve_history
before update or delete on private.user_block_episodes
for each row execute function private.protect_user_block_episode_history();

create function private.require_complete_blocking_profile(
  p_expected_profile_id uuid
)
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
      message = 'Authentication is required to manage user blocks.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected blocking profile.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to manage user blocks.';
  end if;

  return current_profile_id;
end;
$$;

create function private.lock_user_interaction_pair(
  p_first_profile_id uuid,
  p_second_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  lower_profile_id text;
  upper_profile_id text;
begin
  if p_first_profile_id is null or p_second_profile_id is null then
    raise exception using
      errcode = '22023',
      message = 'A user interaction pair requires two profile identifiers.';
  end if;

  if p_first_profile_id::text < p_second_profile_id::text then
    lower_profile_id := p_first_profile_id::text;
    upper_profile_id := p_second_profile_id::text;
  else
    lower_profile_id := p_second_profile_id::text;
    upper_profile_id := p_first_profile_id::text;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'planets:user-interaction:' || lower_profile_id || ':' || upper_profile_id,
      0
    )
  );
end;
$$;

comment on function private.lock_user_interaction_pair(uuid, uuid) is
  'Acquires the canonical transaction-scoped lock for a sorted profile pair. New-interaction and block operations take it before Project/Resource rows.';

create function private.has_active_directional_user_block(
  p_blocker_profile_id uuid,
  p_blocked_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_blocker_profile_id is not null
    and p_blocked_profile_id is not null
    and exists (
      select 1
      from private.user_block_episodes as episode
      where episode.blocker_profile_id = p_blocker_profile_id
        and episode.blocked_profile_id = p_blocked_profile_id
        and episode.unblocked_at is null
    )
$$;

create function private.has_active_user_block_between(
  p_first_profile_id uuid,
  p_second_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_first_profile_id is not null
    and p_second_profile_id is not null
    and p_first_profile_id <> p_second_profile_id
    and (
      private.has_active_directional_user_block(
        p_first_profile_id,
        p_second_profile_id
      )
      or private.has_active_directional_user_block(
        p_second_profile_id,
        p_first_profile_id
      )
    )
$$;

comment on function private.has_active_user_block_between(uuid, uuid) is
  'Canonical symmetric barrier predicate: true when either directional block episode for the profile pair is active.';

create function private.assert_user_interaction_available(
  p_first_profile_id uuid,
  p_second_profile_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if private.has_active_user_block_between(
    p_first_profile_id,
    p_second_profile_id
  ) then
    raise sqlstate 'PT409'
      using message = 'This interaction is unavailable.';
  end if;
end;
$$;

create function private.close_pending_direct_requests_for_user_block(
  p_blocker_profile_id uuid,
  p_blocked_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  transition_time timestamptz := statement_timestamp();
  project_candidate record;
  project_record record;
  project_request public.project_join_requests%rowtype;
  project_status text;
  project_action text;
  resource_candidate record;
  resource_listing public.resource_listings%rowtype;
  resource_request public.resource_listing_requests%rowtype;
  resource_status text;
  resource_action text;
begin
  -- Pair lock is already held. Preserve each Project's established concrete
  -- row -> shared Project row -> request row order, and visit Projects by UUID.
  for project_candidate in
    select request.id, request.project_id
    from public.project_join_requests as request
    join public.projects as project on project.id = request.project_id
    where request.status = 'pending'
      and (
        (
          request.requester_profile_id = p_blocker_profile_id
          and project.creator_profile_id = p_blocked_profile_id
        )
        or (
          project.creator_profile_id = p_blocker_profile_id
          and request.requester_profile_id = p_blocked_profile_id
        )
      )
    order by request.project_id, request.id
  loop
    select * into project_record
    from private.lock_project_for_participation(
      project_candidate.project_id,
      false
    );

    select * into project_request
    from public.project_join_requests as request
    where request.id = project_candidate.id
    for update;

    if project_request.status = 'pending'
      and project_request.requester_profile_id = p_blocker_profile_id
      and project_record.creator_profile_id = p_blocked_profile_id then
      project_status := 'withdrawn';
      project_action := 'project.join_request_withdrawn';
    elsif project_request.status = 'pending'
      and project_record.creator_profile_id = p_blocker_profile_id
      and project_request.requester_profile_id = p_blocked_profile_id then
      project_status := 'rejected';
      project_action := 'project.join_request_rejected';
    else
      continue;
    end if;

    update public.project_join_requests
    set
      status = project_status,
      resolved_at = transition_time,
      resolved_by_profile_id = p_blocker_profile_id
    where id = project_request.id;

    perform private.record_project_participation_event(
      project_action,
      p_blocker_profile_id,
      project_request.project_id,
      jsonb_build_object(
        'project_kind', project_record.project_kind,
        'request_id', project_request.id,
        'requester_profile_id', project_request.requester_profile_id,
        'status', project_status
      )
    );
  end loop;

  -- Resource transitions preserve listing -> request row order and visit
  -- listings/requests by UUID after every affected Project has been processed.
  for resource_candidate in
    select request.id, request.listing_id
    from public.resource_listing_requests as request
    join public.resource_listings as listing on listing.id = request.listing_id
    where request.status = 'pending'
      and (
        (
          request.requester_profile_id = p_blocker_profile_id
          and listing.owner_profile_id = p_blocked_profile_id
        )
        or (
          listing.owner_profile_id = p_blocker_profile_id
          and request.requester_profile_id = p_blocked_profile_id
        )
      )
    order by request.listing_id, request.id
  loop
    select * into resource_listing
    from public.resource_listings as listing
    where listing.id = resource_candidate.listing_id
    for update;

    select * into resource_request
    from public.resource_listing_requests as request
    where request.id = resource_candidate.id
    for update;

    if resource_request.status = 'pending'
      and resource_request.requester_profile_id = p_blocker_profile_id
      and resource_listing.owner_profile_id = p_blocked_profile_id then
      resource_status := 'withdrawn';
      resource_action := 'resource_listing.request_withdrawn';
    elsif resource_request.status = 'pending'
      and resource_listing.owner_profile_id = p_blocker_profile_id
      and resource_request.requester_profile_id = p_blocked_profile_id then
      resource_status := 'rejected';
      resource_action := 'resource_listing.request_rejected';
    else
      continue;
    end if;

    update public.resource_listing_requests
    set
      status = resource_status,
      resolved_at = transition_time,
      resolved_by_profile_id = p_blocker_profile_id
    where id = resource_request.id;

    perform private.record_resource_listing_request_event(
      resource_action,
      resource_request.id,
      resource_listing.id,
      resource_listing.owner_profile_id,
      resource_request.requester_profile_id,
      p_blocker_profile_id
    );
  end loop;
end;
$$;

create function public.block_user(
  p_expected_blocker_profile_id uuid,
  p_blocked_profile_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_blocking_profile(
    p_expected_blocker_profile_id
  );
  block_episode_id uuid;
begin
  if p_blocked_profile_id is null
    or p_blocked_profile_id = current_profile_id then
    raise exception using
      errcode = '22023',
      message = 'A profile cannot block itself.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = p_blocked_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'The target profile is unavailable.';
  end if;

  perform private.lock_user_interaction_pair(
    current_profile_id,
    p_blocked_profile_id
  );

  select episode.id into block_episode_id
  from private.user_block_episodes as episode
  where episode.blocker_profile_id = current_profile_id
    and episode.blocked_profile_id = p_blocked_profile_id
    and episode.unblocked_at is null;

  if block_episode_id is null then
    insert into private.user_block_episodes (
      blocker_profile_id,
      blocked_profile_id
    )
    values (current_profile_id, p_blocked_profile_id)
    returning id into block_episode_id;

    insert into private.audit_events (
      action,
      actor_user_id,
      target_type,
      target_id,
      metadata
    )
    values (
      'user.blocked',
      current_profile_id,
      'user_block_episode',
      block_episode_id,
      jsonb_build_object(
        'blocker_profile_id', current_profile_id,
        'blocked_profile_id', p_blocked_profile_id
      )
    );
  end if;

  perform private.close_pending_direct_requests_for_user_block(
    current_profile_id,
    p_blocked_profile_id
  );

  return block_episode_id;
end;
$$;

create function public.unblock_user(
  p_expected_blocker_profile_id uuid,
  p_blocked_profile_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_blocking_profile(
    p_expected_blocker_profile_id
  );
  block_episode_id uuid;
  transition_time timestamptz := statement_timestamp();
begin
  if p_blocked_profile_id is null
    or p_blocked_profile_id = current_profile_id then
    raise exception using
      errcode = '22023',
      message = 'A profile cannot unblock itself.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = p_blocked_profile_id
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'The target profile is unavailable.';
  end if;

  perform private.lock_user_interaction_pair(
    current_profile_id,
    p_blocked_profile_id
  );

  select episode.id into block_episode_id
  from private.user_block_episodes as episode
  where episode.blocker_profile_id = current_profile_id
    and episode.blocked_profile_id = p_blocked_profile_id
    and episode.unblocked_at is null
  for update;

  if block_episode_id is null then
    select episode.id into block_episode_id
    from private.user_block_episodes as episode
    where episode.blocker_profile_id = current_profile_id
      and episode.blocked_profile_id = p_blocked_profile_id
    order by episode.blocked_at desc, episode.id desc
    limit 1;

    return block_episode_id;
  end if;

  update private.user_block_episodes
  set unblocked_at = transition_time
  where id = block_episode_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    'user.unblocked',
    current_profile_id,
    'user_block_episode',
    block_episode_id,
    jsonb_build_object(
      'blocker_profile_id', current_profile_id,
      'blocked_profile_id', p_blocked_profile_id
    )
  );

  return block_episode_id;
end;
$$;

create function public.list_own_blocked_profiles(
  p_expected_blocker_profile_id uuid,
  p_limit integer default 50,
  p_cursor_blocked_at timestamptz default null,
  p_cursor_block_episode_id uuid default null
)
returns table (
  block_episode_id uuid,
  blocked_profile_id uuid,
  blocked_display_name text,
  blocked_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_blocking_profile(
    p_expected_blocker_profile_id
  );
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Blocked-profile page size must be between 1 and 50.';
  end if;

  if (p_cursor_blocked_at is null)
    <> (p_cursor_block_episode_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Blocked-profile cursor values must be supplied together.';
  end if;

  return query
  select
    episode.id,
    episode.blocked_profile_id,
    profile.display_name,
    episode.blocked_at
  from private.user_block_episodes as episode
  join public.profiles as profile on profile.id = episode.blocked_profile_id
  where episode.blocker_profile_id = current_profile_id
    and episode.unblocked_at is null
    and (
      p_cursor_blocked_at is null
      or (episode.blocked_at, episode.id)
        < (p_cursor_blocked_at, p_cursor_block_episode_id)
    )
  order by episode.blocked_at desc, episode.id desc
  limit p_limit;
end;
$$;

-- Preserve the reviewed domain implementations as private cores. Public
-- wrappers acquire the pair lock first, enforce the symmetric barrier, then
-- delegate without duplicating the existing Project/Resource validations.
alter function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) set schema private;
alter function private.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) rename to request_to_join_project_without_block;

create function public.request_to_join_project(
  p_expected_requester_profile_id uuid,
  p_project_id uuid,
  p_request_message text default null,
  p_skill_ids uuid[] default '{}'::uuid[],
  p_resource_need_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  organizer_profile_id uuid;
begin
  select project.creator_profile_id into organizer_profile_id
  from public.projects as project
  where project.id = p_project_id;

  if organizer_profile_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  perform private.lock_user_interaction_pair(
    current_profile_id,
    organizer_profile_id
  );
  perform private.assert_user_interaction_available(
    current_profile_id,
    organizer_profile_id
  );

  return private.request_to_join_project_without_block(
    p_expected_requester_profile_id,
    p_project_id,
    p_request_message,
    p_skill_ids,
    p_resource_need_ids
  );
end;
$$;

alter function public.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) set schema private;
alter function private.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) rename to accept_project_join_request_without_block;

create function public.accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid,
  p_needed_skill_ids uuid[],
  p_already_found_skill_ids uuid[],
  p_extra_skill_ids uuid[],
  p_needed_resource_need_ids uuid[],
  p_already_found_resource_need_ids uuid[],
  p_extra_resource_need_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_creator_profile_id
  );
  requester_profile_id uuid;
  organizer_profile_id uuid;
begin
  select
    request.requester_profile_id,
    project.creator_profile_id
  into requester_profile_id, organizer_profile_id
  from public.project_join_requests as request
  join public.projects as project on project.id = request.project_id
  where request.id = p_request_id;

  if requester_profile_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The join request does not exist.';
  end if;

  if organizer_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can accept join requests.';
  end if;

  perform private.lock_user_interaction_pair(
    organizer_profile_id,
    requester_profile_id
  );
  perform private.assert_user_interaction_available(
    organizer_profile_id,
    requester_profile_id
  );

  return private.accept_project_join_request_without_block(
    p_expected_creator_profile_id,
    p_request_id,
    p_needed_skill_ids,
    p_already_found_skill_ids,
    p_extra_skill_ids,
    p_needed_resource_need_ids,
    p_already_found_resource_need_ids,
    p_extra_resource_need_ids
  );
end;
$$;

alter function public.request_resource_listing(uuid, uuid, text)
  set schema private;
alter function private.request_resource_listing(uuid, uuid, text)
  rename to request_resource_listing_without_block;

create function public.request_resource_listing(
  p_expected_requester_profile_id uuid,
  p_listing_id uuid,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_requester_profile_id,
    true
  );
  owner_profile_id uuid;
begin
  select listing.owner_profile_id into owner_profile_id
  from public.resource_listings as listing
  where listing.id = p_listing_id;

  if owner_profile_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing does not exist.';
  end if;

  perform private.lock_user_interaction_pair(
    current_profile_id,
    owner_profile_id
  );
  perform private.assert_user_interaction_available(
    current_profile_id,
    owner_profile_id
  );

  return private.request_resource_listing_without_block(
    p_expected_requester_profile_id,
    p_listing_id,
    p_message
  );
end;
$$;

alter function public.accept_resource_listing_request(uuid, uuid)
  set schema private;
alter function private.accept_resource_listing_request(uuid, uuid)
  rename to accept_resource_listing_request_without_block;

create function public.accept_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
  owner_profile_id uuid;
  requester_profile_id uuid;
begin
  select
    listing.owner_profile_id,
    request.requester_profile_id
  into owner_profile_id, requester_profile_id
  from public.resource_listing_requests as request
  join public.resource_listings as listing on listing.id = request.listing_id
  where request.id = p_request_id;

  if requester_profile_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  if owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the listing owner can accept this resource listing request.';
  end if;

  perform private.lock_user_interaction_pair(
    owner_profile_id,
    requester_profile_id
  );
  perform private.assert_user_interaction_available(
    owner_profile_id,
    requester_profile_id
  );

  return private.accept_resource_listing_request_without_block(
    p_expected_owner_profile_id,
    p_request_id
  );
end;
$$;

-- Public photos and owners' own photos remain available. The block predicate is
-- applied only to interaction-audience delivery, including exact Storage paths
-- and the existing public Project/Resource context helpers.
create or replace function private.can_view_profile_photo(
  p_viewer_profile_id uuid,
  p_subject_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos as photo
    where photo.profile_id = p_subject_profile_id
      and (
        p_viewer_profile_id = p_subject_profile_id
        or photo.audience = 'public'
        or (
          photo.audience = 'interactions'
          and p_viewer_profile_id is not null
          and not private.has_active_user_block_between(
            p_viewer_profile_id,
            p_subject_profile_id
          )
          and (
            private.has_profile_photo_organizer_interaction(
              p_viewer_profile_id,
              p_subject_profile_id
            )
            or private.has_resource_profile_photo_interaction(
              p_viewer_profile_id,
              p_subject_profile_id
            )
          )
        )
      )
  )
$$;

create or replace function public.can_read_public_project_creator_photo_object(
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos as photo
    where photo.object_path = p_object_path
      and private.has_public_project_creator_photo_context(photo.profile_id)
      and (
        photo.profile_id = (select auth.uid())
        or photo.audience = 'public'
        or not private.has_active_user_block_between(
          (select auth.uid()),
          photo.profile_id
        )
      )
  )
$$;

create or replace function public.get_project_creator_profile_photo_for_viewer(
  p_project_id uuid
)
returns table (
  profile_id uuid,
  object_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.projects as project
  join public.profile_photos as photo
    on photo.profile_id = project.creator_profile_id
  where project.id = p_project_id
    and (
      project.creator_profile_id = (select auth.uid())
      or (
        private.is_project_publicly_viewable(project.id)
        and (
          photo.audience = 'public'
          or not private.has_active_user_block_between(
            (select auth.uid()),
            photo.profile_id
          )
        )
      )
    )
$$;

create or replace function public.can_read_public_resource_listing_owner_photo_object(
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos as photo
    where photo.object_path = p_object_path
      and private.has_public_resource_listing_owner_photo_context(
        photo.profile_id
      )
      and (
        photo.profile_id = (select auth.uid())
        or photo.audience = 'public'
        or not private.has_active_user_block_between(
          (select auth.uid()),
          photo.profile_id
        )
      )
  )
$$;

create or replace function public.get_resource_listing_owner_profile_photo_for_viewer(
  p_listing_id uuid
)
returns table (
  profile_id uuid,
  object_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.resource_listings as listing
  join public.profile_photos as photo
    on photo.profile_id = listing.owner_profile_id
  where listing.id = p_listing_id
    and (
      listing.owner_profile_id = (select auth.uid())
      or (
        listing.lifecycle_state = 'published'
        and (
          photo.audience = 'public'
          or not private.has_active_user_block_between(
            (select auth.uid()),
            photo.profile_id
          )
        )
      )
    )
$$;

comment on column public.profile_photos.audience is
  'Photo audience: public, or interactions meaning a current qualifying Project or Scambio-Dona relationship. Either active directional user block revokes interaction-only delivery without affecting public photos or accepted operational access.';

revoke all privileges on function private.protect_user_block_episode_history()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_complete_blocking_profile(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.lock_user_interaction_pair(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.has_active_directional_user_block(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.has_active_user_block_between(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.assert_user_interaction_available(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.close_pending_direct_requests_for_user_block(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.request_to_join_project_without_block(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function private.accept_project_join_request_without_block(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function private.request_resource_listing_without_block(
  uuid,
  uuid,
  text
) from public, anon, authenticated, service_role;
revoke all privileges on function private.accept_resource_listing_request_without_block(
  uuid,
  uuid
) from public, anon, authenticated, service_role;

revoke all privileges on function public.block_user(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.unblock_user(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_blocked_profiles(
  uuid,
  integer,
  timestamptz,
  uuid
) from public, anon, authenticated, service_role;
revoke all privileges on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function public.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function public.request_resource_listing(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.accept_resource_listing_request(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.block_user(uuid, uuid) to authenticated;
grant execute on function public.unblock_user(uuid, uuid) to authenticated;
grant execute on function public.list_own_blocked_profiles(
  uuid,
  integer,
  timestamptz,
  uuid
) to authenticated;
grant execute on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) to authenticated;
grant execute on function public.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) to authenticated;
grant execute on function public.request_resource_listing(uuid, uuid, text)
  to authenticated;
grant execute on function public.accept_resource_listing_request(uuid, uuid)
  to authenticated;

comment on function public.block_user(uuid, uuid) is
  'Idempotently activates the caller-owned directional block, atomically closes direct pending requests with ordinary withdrawn/rejected semantics, and emits no block notification/outbox event.';
comment on function public.unblock_user(uuid, uuid) is
  'Closes only the caller-owned active directional block episode; retries return the latest episode and never resurrect prior interactions.';
comment on function public.list_own_blocked_profiles(uuid, integer, timestamptz, uuid) is
  'Returns a bounded keyset page of only the caller''s active outbound blocks with target ID, display identity, and blocked timestamp; inbound and reciprocal state are never disclosed.';
comment on function public.request_to_join_project(uuid, uuid, text, uuid[], uuid[]) is
  'Serializes the requester/creator pair before the canonical Project request implementation and returns a direction-safe unavailable conflict while either user block is active.';
comment on function public.accept_project_join_request(uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid[], uuid[]) is
  'Serializes the creator/requester pair before canonical acceptance and contribution triage so a block that wins first cannot become a new membership.';
comment on function public.request_resource_listing(uuid, uuid, text) is
  'Serializes the requester/owner pair before the canonical Resource request implementation and returns a direction-safe unavailable conflict while either user block is active.';
comment on function public.accept_resource_listing_request(uuid, uuid) is
  'Serializes the owner/requester pair before canonical acceptance so a block that wins first cannot open a new agreement/chat episode.';
comment on function private.close_pending_direct_requests_for_user_block(uuid, uuid) is
  'With the canonical pair lock held, closes pair-connected pending Project then Resource requests in deterministic UUID order using ordinary identifier-only transition events.';
comment on function private.can_view_profile_photo(uuid, uuid) is
  'Authorizes the current canonical owner/public photo, or an interaction-audience photo only when a qualifying relationship exists and no active user block exists in either direction.';
comment on function public.get_project_creator_profile_photo_for_viewer(uuid) is
  'Returns the exact Project organizer photo under existing public-context rules, except a blocked authenticated pair receives only public-audience photos; authorization reason remains private.';
comment on function public.get_resource_listing_owner_profile_photo_for_viewer(uuid) is
  'Returns the exact Resource owner photo under existing public-context rules, except a blocked authenticated pair receives only public-audience photos; authorization reason remains private.';

-- 07C2 convergence: once active co-creators/managers are integrated, the
-- organizer identities resolved before private.lock_user_interaction_pair must
-- include every profile with applicant-management authority. The generic pair
-- lock and block predicate require no redesign.
