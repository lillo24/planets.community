-- MAP01: nullable additive location records; no live provider activation.
-- Selected objects are limited OSM-backed Geoapify geocoding, never raw responses.
create function private.valid_selected_place(p_place jsonb)
returns boolean language plpgsql stable set search_path = '' as $$
begin
  return p_place is null or coalesce(
    jsonb_typeof(p_place) = 'object'
    and pg_column_size(p_place) < 4096
    and (p_place - array['provider','kind','result_type','label','country_code','locality',
      'administrative_area','latitude','longitude','confidence','source','attribution','source_license','verified_at']) = '{}'::jsonb
    and p_place->>'provider' = 'geoapify'
    and p_place->>'source' = 'openstreetmap'
    and p_place->>'source_license' = 'https://www.openstreetmap.org/copyright'
    and p_place->>'attribution' = 'Powered by Geoapify | © OpenStreetMap contributors'
    and p_place->>'country_code' = 'IT'
    and p_place->>'kind' in ('locality','address','amenity')
    and ((p_place->>'kind' = 'locality' and p_place->>'result_type' in ('city','suburb','district','postcode','county','state'))
      or (p_place->>'kind' = 'address' and p_place->>'result_type' in ('street','building'))
      or (p_place->>'kind' = 'amenity' and p_place->>'result_type' = 'amenity'))
    and jsonb_typeof(p_place->'label') = 'string' and length(p_place->>'label') between 1 and 180
    and jsonb_typeof(p_place->'locality') = 'string' and length(p_place->>'locality') between 1 and 120
    and (p_place->>'administrative_area' is null or
      (jsonb_typeof(p_place->'administrative_area') = 'string' and length(p_place->>'administrative_area') between 1 and 120))
    and (p_place->>'label') !~ '[<>[:cntrl:]]' and (p_place->>'locality') !~ '[<>[:cntrl:]]'
    and coalesce(p_place->>'administrative_area','') !~ '[<>[:cntrl:]]'
    and jsonb_typeof(p_place->'latitude') = 'number' and (p_place->>'latitude')::numeric between -90 and 90
    and jsonb_typeof(p_place->'longitude') = 'number' and (p_place->>'longitude')::numeric between -180 and 180
    and (p_place->>'confidence' is null or (jsonb_typeof(p_place->'confidence') = 'number' and (p_place->>'confidence')::numeric between 0 and 1))
    and (p_place->>'verified_at')::timestamptz > '2026-01-01'::timestamptz, false);
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then return false;
end;
$$;
revoke all on function private.valid_selected_place(jsonb) from public, anon, authenticated, service_role;

create function private.selected_place_point(p_place jsonb)
returns extensions.geography language sql immutable set search_path = '' as $$
  select case when p_place is null then null else
    extensions.st_setsrid(extensions.st_makepoint((p_place->>'longitude')::double precision,
      (p_place->>'latitude')::double precision),4326)::extensions.geography end;
$$;
revoke all on function private.selected_place_point(jsonb) from public, anon, authenticated, service_role;

alter table public.proposals
  add column selected_public_place jsonb,
  add column location_revision bigint not null default 0 check (location_revision >= 0),
  add constraint proposals_selected_place_valid check (private.valid_selected_place(selected_public_place) and (selected_public_place is null or selected_public_place->>'kind' = 'locality')),
  add constraint proposals_selected_point_matches check (selected_public_place is null or (approximate_location is not null and extensions.st_equals(approximate_location::extensions.geometry, private.selected_place_point(selected_public_place)::extensions.geometry)));
comment on column public.proposals.selected_public_place is 'MAP01 verified geocoding with attribution; independent broad area only, never derived from protected exact data.';

alter table public.recurring_activities
  add column selected_public_place jsonb,
  add column location_revision bigint not null default 0 check (location_revision >= 0),
  add constraint recurring_activities_selected_place_valid check (private.valid_selected_place(selected_public_place) and (selected_public_place is null or selected_public_place->>'kind' = 'locality')),
  add constraint recurring_activities_selected_point_matches check (selected_public_place is null or (approximate_location is not null and extensions.st_equals(approximate_location::extensions.geometry, private.selected_place_point(selected_public_place)::extensions.geometry)));
comment on column public.recurring_activities.selected_public_place is 'MAP01 verified geocoding with attribution; independent broad area only, never derived from protected exact data.';

alter table public.resource_listings
  add column selected_public_place jsonb,
  add column location_revision bigint not null default 0 check (location_revision >= 0),
  add column public_location extensions.geography(point,4326),
  add constraint resource_listings_selected_place_valid check (private.valid_selected_place(selected_public_place)),
  add constraint resource_listings_selected_point_matches check (selected_public_place is null or (public_location is not null and extensions.st_equals(public_location::extensions.geometry, private.selected_place_point(selected_public_place)::extensions.geometry)));
comment on column public.resource_listings.selected_public_place is 'MAP01 verified geocoding with attribution; canonical public listing location; no membership privacy boundary.';

alter table public.proposal_meeting_details add column selected_exact_place jsonb,
  add constraint proposal_meeting_details_selected_place_valid check (private.valid_selected_place(selected_exact_place) and (selected_exact_place is null or selected_exact_place->>'kind' in ('address','amenity'))),
  add constraint proposal_meeting_details_selected_point_matches check (selected_exact_place is null or (exact_location is not null and extensions.st_equals(exact_location::extensions.geometry, private.selected_place_point(selected_exact_place)::extensions.geometry)));
comment on column public.proposal_meeting_details.selected_exact_place is 'Protected selected address/amenity; shares canonical meeting visibility and current-entitlement reads.';

alter table public.recurring_activity_meeting_details add column selected_exact_place jsonb,
  add constraint recurring_activity_meeting_details_selected_place_valid check (private.valid_selected_place(selected_exact_place) and (selected_exact_place is null or selected_exact_place->>'kind' in ('address','amenity'))),
  add constraint recurring_activity_meeting_details_selected_point_matches check (selected_exact_place is null or (exact_location is not null and extensions.st_equals(exact_location::extensions.geometry, private.selected_place_point(selected_exact_place)::extensions.geometry)));
comment on column public.recurring_activity_meeting_details.selected_exact_place is 'Protected selected address/amenity; shares canonical meeting visibility and current-entitlement reads.';

-- All legacy content RPCs retain their signatures. Text edits erase derived pins.
-- No new grants/policies are added to the five existing RLS-protected tables.
create function private.invalidate_selected_public_location()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if row(new.country_code,new.locality,new.administrative_area,new.public_location_label)
    is distinct from row(old.country_code,old.locality,old.administrative_area,old.public_location_label)
    and new.selected_public_place is not distinct from old.selected_public_place then
    new.selected_public_place := null;
    if tg_table_name = 'resource_listings' then new.public_location := null;
    else new.approximate_location := null; end if;
  end if;
  if (to_jsonb(new) - array['location_revision','updated_at']) is distinct from
     (to_jsonb(old) - array['location_revision','updated_at']) then
    new.location_revision := old.location_revision + 1;
  end if;
  return new;
end;
$$;
create function private.invalidate_selected_exact_location()
returns trigger language plpgsql security definer set search_path = '' as $$
declare parent_id uuid;
begin
  if new.exact_meeting_text is distinct from old.exact_meeting_text
    and new.selected_exact_place is not distinct from old.selected_exact_place then
    new.selected_exact_place := null; new.exact_location := null;
  end if;
  if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    if tg_table_name = 'proposal_meeting_details' then
      parent_id := new.proposal_id;
      update public.proposals set location_revision = location_revision + 1 where id = parent_id;
    else
      parent_id := new.recurring_activity_id;
      update public.recurring_activities set location_revision = location_revision + 1 where id = parent_id;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.invalidate_selected_public_location(), private.invalidate_selected_exact_location() from public, anon, authenticated, service_role;
create trigger map01_invalidate_public before update on public.proposals for each row execute function private.invalidate_selected_public_location();
create trigger map01_invalidate_public before update on public.recurring_activities for each row execute function private.invalidate_selected_public_location();
create trigger map01_invalidate_public before update on public.resource_listings for each row execute function private.invalidate_selected_public_location();
create trigger map01_invalidate_exact before update on public.proposal_meeting_details for each row execute function private.invalidate_selected_exact_location();
create trigger map01_invalidate_exact before update on public.recurring_activity_meeting_details for each row execute function private.invalidate_selected_exact_location();

create table private.location_search_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  global_daily integer not null default 1000 check (global_daily between 1 and 2000),
  actor_daily integer not null default 80 check (actor_daily between 1 and 200),
  actor_minute integer not null default 10 check (actor_minute between 1 and 20)
);
insert into private.location_search_config default values;
create table private.location_search_budgets (
  scope text not null, bucket timestamptz not null, used integer not null check (used >= 0),
  primary key(scope,bucket)
);
create table private.location_search_batches (
  id uuid primary key default gen_random_uuid(),
  actor uuid not null references public.profiles(id) on delete restrict,
  item_kind text not null check (item_kind in ('one_time','recurring','resource')),
  item_id uuid not null, revision bigint not null check (revision >= 0),
  slot text not null check (slot in ('area','exact','public')), session_id uuid not null,
  query_hash text not null check (query_hash ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz not null default (statement_timestamp() + interval '5 minutes'),
  ready boolean not null default false
);
create index location_search_batches_lookup on private.location_search_batches(actor,item_id,session_id,query_hash);
create table private.location_selection_receipts (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references private.location_search_batches(id) on delete cascade,
  place jsonb not null check (private.valid_selected_place(place)),
  used_request uuid
);
create index location_selection_receipts_batch on private.location_selection_receipts(batch_id);
create table private.location_write_receipts (
  actor uuid not null references public.profiles(id) on delete restrict,
  request_id uuid not null, item_kind text not null, item_id uuid not null,
  input jsonb not null, revision bigint not null, primary key(actor,request_id)
);
alter table private.location_search_config enable row level security;
revoke all on private.location_search_config from public, anon, authenticated, service_role;
alter table private.location_search_budgets enable row level security;
revoke all on private.location_search_budgets from public, anon, authenticated, service_role;
alter table private.location_search_batches enable row level security;
revoke all on private.location_search_batches from public, anon, authenticated, service_role;
alter table private.location_selection_receipts enable row level security;
revoke all on private.location_selection_receipts from public, anon, authenticated, service_role;
alter table private.location_write_receipts enable row level security;
revoke all on private.location_write_receipts from public, anon, authenticated, service_role;

-- Parent-first locking follows existing structural-edit RPCs. Recheck identity,
-- moderation, draft ownership, Co-creator authority and terminal/time constraints.
create function private.lock_location_item(p_actor uuid,p_kind text,p_item uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare owner_id uuid; state text; starts timestamptz; revision bigint;
begin
  if p_actor is null or not exists(select 1 from public.profiles where id=p_actor) then
    raise exception using errcode='42501',message='Location actor unavailable.';
  end if;
  if p_kind='one_time' then
    select creator_profile_id,lifecycle_state,starts_at,location_revision into owner_id,state,starts,revision
      from public.proposals where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state not in ('draft','published') or (state='published' and starts<=statement_timestamp()) then
      raise exception using errcode='55000',message='Location item is immutable.';
    end if;
  elsif p_kind='recurring' then
    select creator_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.recurring_activities where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state='ended' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  elsif p_kind='resource' then
    select owner_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.resource_listings where id=p_item for update;
    if owner_id is null or owner_id<>p_actor then raise exception using errcode='42501',message='Location edit unavailable.'; end if;
    if state='closed' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return revision;
end;
$$;
revoke all on function private.lock_location_item(uuid,text,uuid) from public, anon, authenticated, service_role;

-- Only the authenticated Edge adapter may call these three service-only RPCs.
-- An unavailable transaction/meter denies the call before upstream traffic.
create function public.reserve_location_search_v1(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_session uuid,p_query_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg private.location_search_config%rowtype; batch private.location_search_batches%rowtype;
  current_revision bigint; daily timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
  minute timestamptz := date_trunc('minute',statement_timestamp()); used_count integer;
begin
  current_revision := private.lock_location_item(p_actor,p_kind,p_item);
  if p_revision is distinct from current_revision then return jsonb_build_object('status','stale_selection'); end if;
  if p_session is null or p_query_hash is null or p_query_hash !~ '^[a-f0-9]{64}$'
    or p_slot is null or (p_kind='resource' and p_slot<>'public') or (p_kind<>'resource' and p_slot not in ('area','exact')) then
    raise exception using errcode='22023',message='Invalid location search scope.';
  end if;
  select * into cfg from private.location_search_config where singleton for update;
  if not found or not cfg.enabled then return jsonb_build_object('status','disabled'); end if;
  -- Remove expired derived data without retaining provider responses/search text.
  delete from private.location_search_batches where expires_at<=statement_timestamp();
  delete from private.location_search_budgets where bucket<daily;
  select * into batch from private.location_search_batches
    where actor=p_actor and item_kind=p_kind and item_id=p_item and revision=p_revision
      and slot=p_slot and session_id=p_session and query_hash=p_query_hash and expires_at>statement_timestamp()
    order by expires_at desc limit 1;
  if found then
    if not batch.ready then return jsonb_build_object('status','search_pending'); end if;
    return jsonb_build_object('status','ok','cached',true,'suggestions',coalesce(
      (select jsonb_agg(jsonb_build_object('id',r.id,'place',r.place,'expires_at',batch.expires_at) order by r.id)
       from private.location_selection_receipts r where r.batch_id=batch.id and r.used_request is null),'[]'::jsonb));
  end if;
  select used into used_count from private.location_search_budgets where scope='global' and bucket=daily;
  if coalesce(used_count,0)>=cfg.global_daily then return jsonb_build_object('status','budget_exhausted'); end if;
  select used into used_count from private.location_search_budgets where scope='actor:'||p_actor and bucket=daily;
  if coalesce(used_count,0)>=cfg.actor_daily then return jsonb_build_object('status','budget_exhausted'); end if;
  select used into used_count from private.location_search_budgets where scope='minute:'||p_actor and bucket=minute;
  if coalesce(used_count,0)>=cfg.actor_minute then return jsonb_build_object('status','rate_limited'); end if;
  insert into private.location_search_budgets(scope,bucket,used) values ('global',daily,1),('actor:'||p_actor,daily,1),('minute:'||p_actor,minute,1)
    on conflict(scope,bucket) do update set used=private.location_search_budgets.used+1;
  insert into private.location_search_batches(actor,item_kind,item_id,revision,slot,session_id,query_hash)
    values(p_actor,p_kind,p_item,p_revision,p_slot,p_session,p_query_hash) returning * into batch;
  return jsonb_build_object('status','ok','cached',false,'batch_id',batch.id);
end;
$$;

create function public.issue_location_selections_v1(p_batch uuid,p_places jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare batch private.location_search_batches%rowtype; place jsonb;
begin
  select * into batch from private.location_search_batches where id=p_batch;
  if not found or batch.expires_at<=statement_timestamp() then return jsonb_build_object('status','expired_selection'); end if;
  if private.lock_location_item(batch.actor,batch.item_kind,batch.item_id)<>batch.revision then
    return jsonb_build_object('status','stale_selection');
  end if;
  select * into batch from private.location_search_batches where id=p_batch for update;
  if batch.ready then raise exception using errcode='22023',message='Selection batch already issued.'; end if;
  if not coalesce((select enabled from private.location_search_config where singleton),false) then return jsonb_build_object('status','disabled'); end if;
  if jsonb_typeof(p_places) is distinct from 'array' or jsonb_array_length(p_places)>5 or pg_column_size(p_places)>20000 then
    raise exception using errcode='22023',message='Invalid normalized selection list.';
  end if;
  for place in select value from jsonb_array_elements(p_places) loop
    place := place || jsonb_build_object('verified_at',statement_timestamp());
    if not private.valid_selected_place(place) then raise exception using errcode='22023',message='Invalid normalized selection.'; end if;
    -- A single Italy-wide search returns all supported kinds; slot filters only
    -- its selectable normalized results and never synthesizes a public area.
    if (batch.slot='area' and place->>'kind'<>'locality') or
       (batch.slot='exact' and place->>'kind'='locality') then continue; end if;
    insert into private.location_selection_receipts(batch_id,place) values(p_batch,place);
  end loop;
  update private.location_search_batches set ready=true where id=p_batch;
  return jsonb_build_object('status','ok','suggestions',coalesce(
    (select jsonb_agg(jsonb_build_object('id',r.id,'place',r.place,'expires_at',batch.expires_at) order by r.id)
     from private.location_selection_receipts r where r.batch_id=p_batch),'[]'::jsonb));
end;
$$;

create function public.resolve_location_selection_v1(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_session uuid,p_receipt uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selection record;
begin
  if private.lock_location_item(p_actor,p_kind,p_item) is distinct from p_revision then return jsonb_build_object('status','stale_selection'); end if;
  if not coalesce((select enabled from private.location_search_config where singleton),false) then return jsonb_build_object('status','disabled'); end if;
  select r.id,r.place,b.expires_at into selection from private.location_selection_receipts r
    join private.location_search_batches b on b.id=r.batch_id
    where r.id=p_receipt and r.used_request is null and b.actor=p_actor and b.item_kind=p_kind
      and b.item_id=p_item and b.revision=p_revision and b.slot=p_slot and b.session_id=p_session;
  if not found or selection.expires_at<=statement_timestamp() then return jsonb_build_object('status','expired_selection'); end if;
  return jsonb_build_object('status','ok','selection',to_jsonb(selection));
end;
$$;
revoke all on function public.reserve_location_search_v1(uuid,text,uuid,bigint,text,uuid,text),
  public.issue_location_selections_v1(uuid,jsonb),public.resolve_location_selection_v1(uuid,text,uuid,bigint,text,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.reserve_location_search_v1(uuid,text,uuid,bigint,text,uuid,text),
  public.issue_location_selections_v1(uuid,jsonb),public.resolve_location_selection_v1(uuid,text,uuid,bigint,text,uuid,uuid) to service_role;

create function private.consume_location_receipt(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_receipt uuid,p_request uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selected jsonb;
begin
  if not coalesce((select enabled from private.location_search_config where singleton),false) then
    raise exception using errcode='55000',message='Location search is disabled.';
  end if;
  select r.place into selected from private.location_selection_receipts r
    join private.location_search_batches b on b.id=r.batch_id
    where r.id=p_receipt and r.used_request is null and b.actor=p_actor and b.item_kind=p_kind
      and b.item_id=p_item and b.revision=p_revision and b.slot=p_slot and b.expires_at>statement_timestamp()
    for update of r;
  if not found then raise exception using errcode='22023',message='Selection unavailable or expired.'; end if;
  update private.location_selection_receipts set used_request=p_request where id=p_receipt;
  return selected;
end;
$$;
revoke all on function private.consume_location_receipt(uuid,text,uuid,bigint,text,uuid,uuid) from public,anon,authenticated,service_role;

-- A purpose-limited mutation accepts ONLY receipts, never geometry/labels.
-- Clear removes the derived record/point and keeps legacy user-authored text.
create function public.apply_item_location_v1(p_expected_profile_id uuid,p_kind text,p_item uuid,p_expected_revision bigint,
  p_request_id uuid,p_public_action text,p_public_receipt uuid,p_exact_action text,p_exact_receipt uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare current_actor uuid := private.require_resource_listing_identity(p_expected_profile_id);
  revision bigint; input jsonb; retry private.location_write_receipts%rowtype; public_place jsonb; exact_place jsonb;
begin
  revision := private.lock_location_item(current_actor,p_kind,p_item);
  if p_request_id is null or p_expected_revision is null or p_public_action is null or p_exact_action is null
    or p_public_action not in ('unchanged','replace','clear') or p_exact_action not in ('unchanged','replace','clear')
    or (p_public_action='replace') is distinct from (p_public_receipt is not null)
    or (p_exact_action='replace') is distinct from (p_exact_receipt is not null)
    or (p_kind='resource' and p_exact_action<>'unchanged') then
    raise exception using errcode='22023',message='Invalid location mutation.';
  end if;
  input := jsonb_build_array(p_kind,p_item,p_expected_revision,p_public_action,p_public_receipt,p_exact_action,p_exact_receipt);
  select w.* into retry from private.location_write_receipts w where w.actor=current_actor and w.request_id=p_request_id;
  if found then
    if retry.input is distinct from input then raise exception using errcode='22023',message='Location retry input changed.'; end if;
    if retry.revision<>revision then raise exception using errcode='40001',message='Location retry superseded.'; end if;
    return retry.revision;
  end if;
  if revision<>p_expected_revision then raise exception using errcode='40001',message='Location revision changed.'; end if;
  if p_public_action='replace' then public_place := private.consume_location_receipt(current_actor,p_kind,p_item,revision,
    case when p_kind='resource' then 'public' else 'area' end,p_public_receipt,p_request_id); end if;
  if p_exact_action='replace' then exact_place := private.consume_location_receipt(current_actor,p_kind,p_item,revision,'exact',p_exact_receipt,p_request_id); end if;
  if p_public_action<>'unchanged' then
    if p_kind='one_time' then
      update public.proposals set selected_public_place=public_place, approximate_location=private.selected_place_point(public_place),
        country_code=coalesce(public_place->>'country_code',country_code),locality=coalesce(public_place->>'locality',locality),
        administrative_area=case when public_place is null then administrative_area else public_place->>'administrative_area' end,
        public_location_label=coalesce(public_place->>'label',public_location_label) where id=p_item;
    elsif p_kind='recurring' then
      update public.recurring_activities set selected_public_place=public_place, approximate_location=private.selected_place_point(public_place),
        country_code=coalesce(public_place->>'country_code',country_code),locality=coalesce(public_place->>'locality',locality),
        administrative_area=case when public_place is null then administrative_area else public_place->>'administrative_area' end,
        public_location_label=coalesce(public_place->>'label',public_location_label) where id=p_item;
    else
      update public.resource_listings set selected_public_place=public_place,public_location=private.selected_place_point(public_place),
        country_code=coalesce(public_place->>'country_code',country_code),locality=coalesce(public_place->>'locality',locality),
        administrative_area=case when public_place is null then administrative_area else public_place->>'administrative_area' end,
        public_location_label=coalesce(public_place->>'label',public_location_label) where id=p_item;
    end if;
  end if;
  if p_exact_action<>'unchanged' then
    if p_kind='one_time' then
      update public.proposal_meeting_details set selected_exact_place=exact_place,exact_location=private.selected_place_point(exact_place) where proposal_id=p_item;
    else
      update public.recurring_activity_meeting_details set selected_exact_place=exact_place,exact_location=private.selected_place_point(exact_place) where recurring_activity_id=p_item;
    end if;
  end if;
  revision := private.lock_location_item(current_actor,p_kind,p_item);
  insert into private.location_write_receipts values(current_actor,p_request_id,p_kind,p_item,input,revision);
  insert into private.audit_events(action,actor_user_id,target_type,target_id)
    values('location.updated',current_actor,p_kind,p_item);
  -- No provider content or location enters generic audit/outbox notifications.
  return revision;
end;
$$;
revoke all on function public.apply_item_location_v1(uuid,text,uuid,bigint,uuid,text,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.apply_item_location_v1(uuid,text,uuid,bigint,uuid,text,uuid,text,uuid) to authenticated;

create function public.get_public_item_location_v1(p_kind text,p_item uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if p_kind='one_time' then
    if not exists(select 1 from public.get_public_proposal(p_item)) then return null; end if;
    select jsonb_build_object('public_place',p.selected_public_place,'exact_place',
      case when m.exact_location_visibility='public' then m.selected_exact_place else null end)
      into result from public.proposals p join public.proposal_meeting_details m on m.proposal_id=p.id where p.id=p_item;
  elsif p_kind='recurring' then
    if not exists(select 1 from public.get_public_recurring_activity(p_item)) then return null; end if;
    select jsonb_build_object('public_place',p.selected_public_place,'exact_place',
      case when m.exact_location_visibility='public' then m.selected_exact_place else null end)
      into result from public.recurring_activities p join public.recurring_activity_meeting_details m on m.recurring_activity_id=p.id where p.id=p_item;
  elsif p_kind='resource' then
    if not exists(select 1 from public.get_public_resource_listing(p_item)) then return null; end if;
    select jsonb_build_object('public_place',selected_public_place,'exact_place',null)
      into result from public.resource_listings where id=p_item;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return result;
end;
$$;
create function public.get_authorized_item_location_v1(p_expected_profile_id uuid,p_kind text,p_item uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_resource_listing_identity(p_expected_profile_id); result jsonb;
begin
  if p_kind='resource' then
    if not exists(select 1 from public.get_own_resource_listing(actor,p_item)) then
      raise exception using errcode='42501',message='Location read unavailable.';
    end if;
    select jsonb_build_object('revision',location_revision,'public_place',selected_public_place,'exact_place',null)
      into result from public.resource_listings where id=p_item;
  elsif p_kind in ('one_time','recurring') then
    -- Reuse effective canonical membership/manager rules, including revocation.
    perform * from public.get_project_participant_meeting_details(actor,p_item);
    if p_kind='one_time' then
      select jsonb_build_object('revision',p.location_revision,'public_place',p.selected_public_place,'exact_place',m.selected_exact_place)
        into result from public.proposals p join public.proposal_meeting_details m on m.proposal_id=p.id where p.id=p_item;
    else
      select jsonb_build_object('revision',p.location_revision,'public_place',p.selected_public_place,'exact_place',m.selected_exact_place)
        into result from public.recurring_activities p join public.recurring_activity_meeting_details m on m.recurring_activity_id=p.id where p.id=p_item;
    end if;
    if result is null then raise exception using errcode='22023',message='Location item kind mismatch.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return result;
end;
$$;
revoke all on function public.get_public_item_location_v1(text,uuid),public.get_authorized_item_location_v1(uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_public_item_location_v1(text,uuid) to anon,authenticated;
grant execute on function public.get_authorized_item_location_v1(uuid,text,uuid) to authenticated;
