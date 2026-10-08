
-- Actor-bound first-creation receipts only; no location/search data or edit history.
create table private.recurring_draft_creations (
 actor_profile_id uuid not null references public.profiles(id) on delete restrict,
 client_request_id uuid not null,
 item_id uuid not null unique references public.projects(id) on delete restrict,
 accepted_intent_hash text not null check (accepted_intent_hash ~ '^[0-9a-f]{64}$'),
 accepted_at timestamptz not null default clock_timestamp(),
 primary key (actor_profile_id, client_request_id)
);
alter table private.recurring_draft_creations enable row level security;
revoke all on private.recurring_draft_creations from public, anon, authenticated, service_role;
create trigger recurring_draft_creations_append_only before update or delete on private.recurring_draft_creations
 for each row execute function private.protect_moderation_append_only();

create function public.create_editor_recurring_activity_draft(
 p_expected_creator_profile_id uuid, p_client_request_id uuid,
 p_title text, p_summary text, p_description text, p_topic text, p_country_code text, p_locality text, p_administrative_area text, p_public_location_label text, p_exact_meeting_text text, p_exact_location_visibility text, p_recurrence_type text, p_weekday integer, p_day_of_month integer, p_local_start_time time without time zone, p_duration_minutes integer, p_event_timezone text, p_effective_from date, p_registration_capacity integer, p_count_organizers_toward_capacity boolean
) returns uuid language plpgsql security definer set search_path = '' set timezone = 'UTC'
as $$
declare
 actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
 receipt private.recurring_draft_creations%rowtype;
 intent_hash text;
 destination uuid;
begin
 if p_client_request_id is null then
  raise exception using errcode='22023', message='A draft creation request ID is required.';
 end if;
 intent_hash := encode(extensions.digest(jsonb_build_array(p_title, p_summary, p_description, p_topic, p_country_code, p_locality, p_administrative_area, p_public_location_label, p_exact_meeting_text, p_exact_location_visibility, p_recurrence_type, p_weekday, p_day_of_month, p_local_start_time, p_duration_minutes, p_event_timezone, p_effective_from, p_registration_capacity, p_count_organizers_toward_capacity)::text, 'sha256'), 'hex');
 perform pg_advisory_xact_lock(hashtextextended('recurring_activity.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
 perform private.require_expected_identity(p_expected_creator_profile_id);
 select * into receipt from private.recurring_draft_creations
  where actor_profile_id=actor and client_request_id=p_client_request_id;
 if found then
  if receipt.accepted_intent_hash <> intent_hash then
   raise exception using errcode='22023', message='The recorded draft creation intent differs.';
  end if;
  if not exists(select 1 from public.projects where id=receipt.item_id and creator_profile_id=actor) then
   raise exception using errcode='P0002', message='The recorded draft destination is unavailable.';
  end if;
  return receipt.item_id;
 end if;
 destination := public.create_recurring_activity_draft(p_expected_creator_profile_id, p_title, p_summary, p_description, p_topic, p_country_code, p_locality, p_administrative_area, p_public_location_label, p_exact_meeting_text, p_exact_location_visibility, p_recurrence_type, p_weekday, p_day_of_month, p_local_start_time, p_duration_minutes, p_event_timezone, p_effective_from, p_registration_capacity, p_count_organizers_toward_capacity);
 insert into private.recurring_draft_creations values(actor,p_client_request_id,destination,intent_hash,clock_timestamp());
 return destination;
end;
$$;
create function public.recover_editor_recurring_activity_draft(p_expected_creator_profile_id uuid, p_client_request_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
 actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
 destination uuid;
begin
 if p_client_request_id is null then
  raise exception using errcode='22023', message='A draft creation request ID is required.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('recurring_activity.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
 perform private.require_expected_identity(p_expected_creator_profile_id);
 select item_id into destination from private.recurring_draft_creations
  where actor_profile_id=actor and client_request_id=p_client_request_id;
 if found and not exists(select 1 from public.projects where id=destination and creator_profile_id=actor) then
  raise exception using errcode='P0002', message='The recorded draft destination is unavailable.';
 end if;
 return destination;
end;
$$;
revoke all on function public.create_editor_recurring_activity_draft(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time without time zone, integer, text, date, integer, boolean) from public,anon,authenticated,service_role;
grant execute on function public.create_editor_recurring_activity_draft(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time without time zone, integer, text, date, integer, boolean) to authenticated;
revoke all on function public.recover_editor_recurring_activity_draft(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.recover_editor_recurring_activity_draft(uuid,uuid) to authenticated;


-- Actor-bound first-creation receipts only; no location/search data or edit history.
create table private.resource_draft_creations (
 actor_profile_id uuid not null references public.profiles(id) on delete restrict,
 client_request_id uuid not null,
 item_id uuid not null unique references public.resource_listings(id) on delete restrict,
 accepted_intent_hash text not null check (accepted_intent_hash ~ '^[0-9a-f]{64}$'),
 accepted_at timestamptz not null default clock_timestamp(),
 primary key (actor_profile_id, client_request_id)
);
alter table private.resource_draft_creations enable row level security;
revoke all on private.resource_draft_creations from public, anon, authenticated, service_role;
create trigger resource_draft_creations_append_only before update or delete on private.resource_draft_creations
 for each row execute function private.protect_moderation_append_only();

create function public.create_editor_resource_listing_draft(
 p_expected_owner_profile_id uuid, p_client_request_id uuid,
 p_listing_mode text, p_title text, p_description text, p_country_code text, p_locality text, p_administrative_area text, p_public_location_label text
) returns uuid language plpgsql security definer set search_path = '' set timezone = 'UTC'
as $$
declare
 actor uuid := private.require_expected_identity(p_expected_owner_profile_id);
 receipt private.resource_draft_creations%rowtype;
 intent_hash text;
 destination uuid;
begin
 if p_client_request_id is null then
  raise exception using errcode='22023', message='A draft creation request ID is required.';
 end if;
 intent_hash := encode(extensions.digest(jsonb_build_array(p_listing_mode, p_title, p_description, p_country_code, p_locality, p_administrative_area, p_public_location_label)::text, 'sha256'), 'hex');
 perform pg_advisory_xact_lock(hashtextextended('resource_listing.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
 perform private.require_expected_identity(p_expected_owner_profile_id);
 select * into receipt from private.resource_draft_creations
  where actor_profile_id=actor and client_request_id=p_client_request_id;
 if found then
  if receipt.accepted_intent_hash <> intent_hash then
   raise exception using errcode='22023', message='The recorded draft creation intent differs.';
  end if;
  if not exists(select 1 from public.resource_listings where id=receipt.item_id and owner_profile_id=actor) then
   raise exception using errcode='P0002', message='The recorded draft destination is unavailable.';
  end if;
  return receipt.item_id;
 end if;
 destination := public.create_resource_listing_draft(p_expected_owner_profile_id, p_listing_mode, p_title, p_description, p_country_code, p_locality, p_administrative_area, p_public_location_label);
 insert into private.resource_draft_creations values(actor,p_client_request_id,destination,intent_hash,clock_timestamp());
 return destination;
end;
$$;
create function public.recover_editor_resource_listing_draft(p_expected_owner_profile_id uuid, p_client_request_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
 actor uuid := private.require_expected_identity(p_expected_owner_profile_id);
 destination uuid;
begin
 if p_client_request_id is null then
  raise exception using errcode='22023', message='A draft creation request ID is required.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('resource_listing.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
 perform private.require_expected_identity(p_expected_owner_profile_id);
 select item_id into destination from private.resource_draft_creations
  where actor_profile_id=actor and client_request_id=p_client_request_id;
 if found and not exists(select 1 from public.resource_listings where id=destination and owner_profile_id=actor) then
  raise exception using errcode='P0002', message='The recorded draft destination is unavailable.';
 end if;
 return destination;
end;
$$;
revoke all on function public.create_editor_resource_listing_draft(uuid, uuid, text, text, text, text, text, text, text) from public,anon,authenticated,service_role;
grant execute on function public.create_editor_resource_listing_draft(uuid, uuid, text, text, text, text, text, text, text) to authenticated;
revoke all on function public.recover_editor_resource_listing_draft(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.recover_editor_resource_listing_draft(uuid,uuid) to authenticated;
