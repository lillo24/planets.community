-- Preserve the already-integrated scoped chat projection as a private base so
-- this late correction can extend its strict result without copying or
-- changing its scope, activity, ordering, cursor, or pagination behavior.
alter function public.list_own_scoped_message_chat_items(
  uuid,
  text,
  integer,
  timestamptz,
  text,
  uuid
) set schema private;

alter function private.list_own_scoped_message_chat_items(
  uuid,
  text,
  integer,
  timestamptz,
  text,
  uuid
) rename to list_own_scoped_message_chat_items_base;

revoke all privileges on function
  private.list_own_scoped_message_chat_items_base(
    uuid,
    text,
    integer,
    timestamptz,
    text,
    uuid
  ) from public, anon, authenticated, service_role;

create function public.list_own_scoped_message_chat_items(
  p_expected_profile_id uuid,
  p_scope text,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_chat_id uuid default null
)
returns table (
  item_kind text,
  chat_id uuid,
  activity_at timestamptz,
  display_title text,
  viewer_role text,
  is_read_only boolean,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  project_id uuid,
  project_kind text,
  resource_request_id uuid,
  resource_agreement_id uuid,
  resource_listing_id uuid,
  resource_counterparty_profile_id uuid,
  resource_counterparty_display_name text,
  agreement_lifecycle text,
  coordination_closed_at timestamptz,
  project_request_id uuid,
  project_request_project_id uuid,
  project_request_project_kind text,
  project_request_project_title text,
  project_request_counterparty_profile_id uuid,
  project_request_counterparty_display_name text,
  project_request_status text,
  project_request_message text,
  project_request_resolved_at timestamptz,
  accepted_project_group_chat_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  with current_identity as (
    select private.require_participation_identity(
      p_expected_profile_id
    ) as profile_id
  ),
  base_items as (
    select *
    from private.list_own_scoped_message_chat_items_base(
      p_expected_profile_id,
      p_scope,
      p_limit,
      p_cursor_activity_at,
      p_cursor_item_kind,
      p_cursor_chat_id
    )
  )
  select
    item.item_kind,
    item.chat_id,
    item.activity_at,
    item.display_title,
    item.viewer_role,
    item.is_read_only,
    item.last_visible_message_id,
    item.last_visible_message_body,
    item.last_visible_message_at,
    item.last_visible_sender_profile_id,
    item.last_visible_sender_display_name,
    item.project_id,
    item.project_kind,
    item.resource_request_id,
    item.resource_agreement_id,
    item.resource_listing_id,
    case
      when item.item_kind <> 'resource_chat' then null::uuid
      when listing.owner_profile_id = identity.profile_id
        then resource_request.requester_profile_id
      else listing.owner_profile_id
    end as resource_counterparty_profile_id,
    case
      when item.item_kind <> 'resource_chat' then null::text
      when listing.owner_profile_id = identity.profile_id
        then requester.display_name
      else owner_profile.display_name
    end as resource_counterparty_display_name,
    item.agreement_lifecycle,
    item.coordination_closed_at,
    item.project_request_id,
    item.project_request_project_id,
    item.project_request_project_kind,
    item.project_request_project_title,
    item.project_request_counterparty_profile_id,
    item.project_request_counterparty_display_name,
    item.project_request_status,
    item.project_request_message,
    item.project_request_resolved_at,
    item.accepted_project_group_chat_id
  from base_items as item
  cross join current_identity as identity
  left join public.resource_listing_requests as resource_request
    on resource_request.id = item.resource_request_id
    and item.item_kind = 'resource_chat'
  left join public.resource_listings as listing
    on listing.id = item.resource_listing_id
    and item.item_kind = 'resource_chat'
  left join public.profiles as requester
    on requester.id = resource_request.requester_profile_id
  left join public.profiles as owner_profile
    on owner_profile.id = listing.owner_profile_id
  order by
    item.activity_at desc,
    case item.item_kind
      when 'project_chat' then 0
      when 'resource_chat' then 1
      when 'project_request_chat' then 2
    end desc,
    item.chat_id desc
$$;

revoke all privileges on function
  public.list_own_scoped_message_chat_items(
    uuid,
    text,
    integer,
    timestamptz,
    text,
    uuid
  ) from public, anon, authenticated, service_role;
grant execute on function
  public.list_own_scoped_message_chat_items(
    uuid,
    text,
    integer,
    timestamptz,
    text,
    uuid
  ) to authenticated;

comment on function public.list_own_scoped_message_chat_items(
  uuid,
  text,
  integer,
  timestamptz,
  text,
  uuid
) is
  'Returns one identity-bound page of private or group chat rows. Resource rows include the canonical opposite party; all other discriminator branches keep those fields null.';

-- Current Project photo interaction is directional for managers viewing a
-- requester/participant, while the reverse private-chat context intentionally
-- exposes only the immutable Creator photo rather than every manager photo.
create function private.has_current_project_profile_photo_interaction(
  p_viewer_profile_id uuid,
  p_subject_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_viewer_profile_id is not null
    and p_subject_profile_id is not null
    and p_viewer_profile_id <> p_subject_profile_id
    and exists (
      select 1
      from public.projects as project
      where (
        private.profile_is_project_manager(
          project.id,
          p_viewer_profile_id
        )
        and (
          exists (
            select 1
            from public.project_join_requests as request
            where request.project_id = project.id
              and request.requester_profile_id = p_subject_profile_id
              and request.status = 'pending'
          )
          or private.profile_has_current_project_membership(
            project.id,
            p_subject_profile_id
          )
        )
      )
      or (
        project.creator_profile_id = p_subject_profile_id
        and (
          exists (
            select 1
            from public.project_join_requests as request
            where request.project_id = project.id
              and request.requester_profile_id = p_viewer_profile_id
              and request.status = 'pending'
          )
          or private.profile_has_current_project_membership(
            project.id,
            p_viewer_profile_id
          )
        )
      )
    )
$$;

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
            private.has_current_project_profile_photo_interaction(
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

revoke all privileges on function
  private.has_current_project_profile_photo_interaction(uuid, uuid)
  from public, anon, authenticated, service_role;

comment on function private.has_current_project_profile_photo_interaction(
  uuid,
  uuid
) is
  'Authorizes active Project managers to view pending requester/current participant photos and current requesters/participants to view only the immutable Creator photo; rejected, withdrawn, revoked, left, and removed history does not qualify.';
comment on function private.can_view_profile_photo(uuid, uuid) is
  'Authorizes the current canonical owner/public photo, or an interaction-audience photo only for a current Project/Resource relationship with no active user block in either direction.';
comment on column public.profile_photos.audience is
  'Photo audience: public, or interactions meaning a current qualifying Project or Scambio-Dona relationship. Project managers may view pending/current people, while those people may view only the immutable Project Creator; active blocks and historical relationships fail closed.';
