-- Scambio-Dona photo visibility is intentionally relationship-specific.
-- Pending requests are directional (listing owner -> requester), while an
-- accepted request authorizes both counterpart directions only for as long as
-- its canonical coordination remains open. Listing closure does not terminate
-- an already-accepted coordination relationship.
create function private.has_resource_profile_photo_interaction(
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
      from public.resource_listing_requests as request
      join public.resource_listings as listing
        on listing.id = request.listing_id
      where (
        request.status = 'pending'
        and listing.owner_profile_id = p_viewer_profile_id
        and request.requester_profile_id = p_subject_profile_id
      )
      or (
        request.status = 'accepted'
        and request.coordination_closed_at is null
        and (
          (
            listing.owner_profile_id = p_viewer_profile_id
            and request.requester_profile_id = p_subject_profile_id
          )
          or (
            listing.owner_profile_id = p_subject_profile_id
            and request.requester_profile_id = p_viewer_profile_id
          )
        )
      )
    )
$$;

comment on function private.has_resource_profile_photo_interaction(uuid, uuid) is
  'Returns whether Scambio-Dona currently authorizes viewer-to-subject photo access: owner-to-requester while pending, or either direction while accepted coordination remains open.';

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

comment on function private.can_view_profile_photo(uuid, uuid) is
  'Authorizes only the current canonical photo for its owner, the public audience, or a current qualifying Project or Scambio-Dona interaction.';

create function private.has_public_resource_listing_owner_photo_context(
  p_owner_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_owner_profile_id is not null
    and exists (
      select 1
      from public.resource_listings as listing
      where listing.owner_profile_id = p_owner_profile_id
        and listing.lifecycle_state = 'published'
    )
$$;

comment on function private.has_public_resource_listing_owner_photo_context(uuid) is
  'Returns whether an owner currently has any publicly viewable Resource listing; used only for exact current-object Storage delivery.';

create function public.can_read_public_resource_listing_owner_photo_object(
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
  )
$$;

comment on function public.can_read_public_resource_listing_owner_photo_object(text) is
  'Authorizes only a current canonical opaque photo path whose owner currently has a published Resource listing context.';

create function public.get_resource_listing_owner_profile_photo_for_viewer(
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
      or listing.lifecycle_state = 'published'
    )
$$;

comment on function public.get_resource_listing_owner_profile_photo_for_viewer(uuid) is
  'Returns zero or one current owner photo for an exact Resource listing when the caller owns it or its canonical public detail is viewable; audience and authorization reason remain private.';

-- Storage receives an exact object path rather than a listing ID. This policy
-- therefore permits only exact current opaque paths for owners with a current
-- public listing. Operation filtering deliberately withholds bucket listing;
-- stale/replaced objects and owners with only draft/closed listings stay denied.
create policy "Public Resource listing context can read canonical owner photos"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'profile-photos'
  and storage.allow_any_operation(
    array['object.get_authenticated_info', 'object.get_authenticated']
  )
  and name ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
  and public.can_read_public_resource_listing_owner_photo_object(
    storage.objects.name
  )
);

create or replace function public.publish_resource_listing(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_resource_listing_identity(
    p_expected_owner_profile_id
  );
  listing public.resource_listings%rowtype;
begin
  select * into listing
  from public.resource_listings
  where id = p_listing_id
  for update;

  if listing.id is null or listing.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this resource listing.';
  end if;

  if listing.lifecycle_state = 'published' then
    return listing.id;
  end if;

  if listing.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft resource listing can be published.';
  end if;

  perform private.assert_resource_listing_publishable(p_listing_id);

  if not private.has_current_profile_photo(current_profile_id) then
    raise exception using
      errcode = 'PT422',
      message = 'A current profile photo is required for this trust-sensitive action.';
  end if;

  update public.resource_listings
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_listing_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    'resource_listing.published',
    current_profile_id,
    'resource_listing',
    p_listing_id,
    jsonb_build_object('listing_mode', listing.listing_mode)
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'resource_listing.published',
    jsonb_build_object(
      'listing_id', p_listing_id,
      'owner_profile_id', current_profile_id,
      'listing_mode', listing.listing_mode
    )
  );

  return p_listing_id;
end;
$$;

create or replace function public.request_resource_listing(
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
  normalized_message text := nullif(btrim(p_message), '');
  listing public.resource_listings%rowtype;
  request_id uuid;
begin
  if normalized_message is not null
    and char_length(normalized_message) > 500 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing request message must contain at most 500 characters.';
  end if;

  select * into listing
  from public.resource_listings
  where id = p_listing_id
  for update;

  if listing.id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing does not exist.';
  end if;

  if listing.lifecycle_state <> 'published' then
    raise exception using
      errcode = '55000',
      message = 'Only a published resource listing can be requested.';
  end if;

  if listing.owner_profile_id = current_profile_id then
    raise exception using
      errcode = '22023',
      message = 'A listing owner cannot request their own resource listing.';
  end if;

  if exists (
    select 1
    from public.resource_listing_requests as existing_request
    where existing_request.listing_id = p_listing_id
      and existing_request.requester_profile_id = current_profile_id
      and (
        existing_request.status = 'pending'
        or (
          existing_request.status = 'accepted'
          and existing_request.coordination_closed_at is null
        )
      )
  ) then
    raise sqlstate 'PT409'
      using message = 'An active request already exists for this resource listing.';
  end if;

  if not private.has_current_profile_photo(current_profile_id) then
    raise exception using
      errcode = 'PT422',
      message = 'A current profile photo is required for this trust-sensitive action.';
  end if;

  insert into public.resource_listing_requests (
    listing_id,
    requester_profile_id,
    request_message
  )
  values (p_listing_id, current_profile_id, normalized_message)
  returning id into request_id;

  perform private.record_resource_listing_request_event(
    'resource_listing.request_created',
    request_id,
    listing.id,
    listing.owner_profile_id,
    current_profile_id,
    current_profile_id
  );

  return request_id;
end;
$$;

comment on column public.profile_photos.audience is
  'Photo audience: public, or interactions meaning a current qualifying Project relationship or Scambio-Dona pending/accepted-open relationship; relationship direction follows each domain policy.';

revoke all privileges on function private.has_resource_profile_photo_interaction(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.has_public_resource_listing_owner_photo_context(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.can_read_public_resource_listing_owner_photo_object(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_resource_listing_owner_profile_photo_for_viewer(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.publish_resource_listing(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.request_resource_listing(uuid, uuid, text)
  from public, anon, authenticated, service_role;

grant execute on function public.can_read_public_resource_listing_owner_photo_object(text)
  to anon, authenticated;
grant execute on function public.get_resource_listing_owner_profile_photo_for_viewer(uuid)
  to anon, authenticated;
grant execute on function public.publish_resource_listing(uuid, uuid)
  to authenticated;
grant execute on function public.request_resource_listing(uuid, uuid, text)
  to authenticated;

comment on function public.publish_resource_listing(uuid, uuid) is
  'Validates and idempotently publishes an own Resource listing draft; the actual draft-to-published transition requires a current canonical profile photo.';
comment on function public.request_resource_listing(uuid, uuid, text) is
  'Atomically creates one pending Resource listing request after preserving existing validations and locks; every new request requires a current canonical requester photo.';
