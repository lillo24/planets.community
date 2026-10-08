-- MAP03: read-only projections and disabled, separately metered static images.
-- Existing list DTOs, editor projections and raw table grants are unchanged.
create function private.location_preview_place(p_place jsonb)
returns jsonb language sql immutable set search_path = '' as $$
 select case when p_place is null then null else jsonb_build_object(
  'kind',p_place->'kind','label',p_place->'label','locality',p_place->'locality',
  'country_code',p_place->'country_code','latitude',p_place->'latitude',
  'longitude',p_place->'longitude') end;
$$;
revoke all on function private.location_preview_place(jsonb) from public,anon,authenticated,service_role;

create function public.get_location_preview_v1(p_kind text,p_item uuid,p_view text,p_expected_profile_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare source jsonb; place jsonb; revision bigint; scope text; audience text := 'public';
 city text; country text;
begin
 if p_view not in ('card','public_detail','protected_detail') or p_view is null then
  raise exception using errcode='22023',message='Invalid preview view.';
 end if;
 if p_view='protected_detail' then
  if p_kind not in ('one_time','recurring') or p_expected_profile_id is null then
   raise exception using errcode='42501',message='Protected preview unavailable.';
  end if;
  source := public.get_authorized_item_location_v1(p_expected_profile_id,p_kind,p_item);
  audience := 'protected';
 else
  if p_expected_profile_id is not null then
   raise exception using errcode='22023',message='Public preview has no actor scope.';
  end if;
  source := public.get_public_item_location_v1(p_kind,p_item);
 end if;
 if source is null then return null; end if;
 if p_kind='one_time' then select location_revision,locality,country_code into revision,city,country from public.proposals where id=p_item;
 elsif p_kind='recurring' then select location_revision,locality,country_code into revision,city,country from public.recurring_activities where id=p_item;
 elsif p_kind='resource' then select location_revision,locality,country_code into revision,city,country from public.resource_listings where id=p_item;
 else raise exception using errcode='22023',message='Invalid preview kind.'; end if;
 -- Cards NEVER select Project exact data, including explicitly public exact.
 place := case when p_view<>'card' and p_kind<>'resource' then
  coalesce(source->'exact_place',source->'public_place') else source->'public_place' end;
 -- JSON null must not mask a non-null independent public place.
 if place='null'::jsonb then place := source->'public_place'; end if;
 if place='null'::jsonb then place := null; end if;
 place := private.location_preview_place(place);
 scope := case when place->>'kind' in ('address','amenity') then 'exact' else 'area' end;
 return jsonb_build_object('item_kind',p_kind,'item_id',p_item,'revision',revision,
  'scope',scope,'audience',audience,'place',place,'legacy',jsonb_build_object('locality',city,'country_code',country),'image_key',
  case when place is null then null else encode(extensions.digest(
   jsonb_build_array('osm-carto:512x256:scale1:pitch0:bearing0:v1',scope,
    place->'latitude',place->'longitude')::text,'sha256'),'hex') end);
end;
$$;
revoke all on function public.get_location_preview_v1(text,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_location_preview_v1(text,uuid,text,uuid) to anon,authenticated;

create function public.get_public_location_previews_v1(p_items jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare item jsonb; result jsonb := '[]'; preview jsonb;
begin
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items)>50 then
  raise exception using errcode='22023',message='Preview batch requires at most 50 items.';
 end if;
 for item in select distinct value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(item)<>'object' or item - array['kind','id']<>'{}'::jsonb
   or item->>'kind' not in ('one_time','recurring','resource') or item->>'id' is null then
   raise exception using errcode='22023',message='Invalid preview batch item.';
  end if;
  preview := public.get_location_preview_v1(item->>'kind',(item->>'id')::uuid,'card');
  result := result || jsonb_build_array(jsonb_build_object('kind',item->>'kind','id',item->>'id','preview',preview));
 end loop;
 return result;
end;
$$;
revoke all on function public.get_public_location_previews_v1(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.get_public_location_previews_v1(jsonb) to anon,authenticated;

create table private.location_preview_config (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 cache_license_approved boolean not null default false,
 daily_credit_limit integer not null default 0 check(daily_credit_limit between 0 and 2000),
 account_daily_credit_limit integer not null default 0 check(account_daily_credit_limit between 0 and 2000)
);
insert into private.location_preview_config(singleton) values(true);
create table private.location_preview_usage (
 scope text not null, bucket timestamptz not null, used integer not null check(used>=0),
 primary key(scope,bucket)
);
-- Only independently PUBLIC LOCALITY images may enter this bounded cache.
-- There are no item, actor, exact-point or meeting-instruction columns.
create table private.location_preview_images (
 image_key text primary key check(image_key ~ '^[a-f0-9]{64}$'),
 token uuid not null default extensions.gen_random_uuid(),
 expires_at timestamptz not null,
 state text not null default 'pending' check(state in ('pending','ready','failed')),
 image bytea check(octet_length(image)<=524288)
);
alter table private.location_preview_config enable row level security;
alter table private.location_preview_usage enable row level security;
alter table private.location_preview_images enable row level security;
revoke all on private.location_preview_config,private.location_preview_usage,private.location_preview_images from public,anon,authenticated,service_role;

-- Edge-only: image key/cacheability comes from the canonical read, never request
-- options. Fixed four-credit reservation covers request + <=6 raster tiles/4
-- + at most one circle marker, rounded UP (3.5 -> 4). Failures are not refunded.
create function public.reserve_location_preview_v1(p_image_key text,p_cacheable boolean,p_actor uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg private.location_preview_config%rowtype; cached private.location_preview_images%rowtype;
 day timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
 minute timestamptz := date_trunc('minute',statement_timestamp()); used integer; search_used integer; actor_scope text;
begin
 if p_image_key is null or p_image_key !~ '^[a-f0-9]{64}$' or p_cacheable is null then
  raise exception using errcode='22023',message='Invalid rendering scope.';
 end if;
 -- Same lock order as autocomplete; account ceiling spans BOTH services.
 perform 1 from private.location_search_config where singleton for update;
 if not found then return jsonb_build_object('status','unconfigured'); end if;
 select * into cfg from private.location_preview_config where singleton for update;
 if not found or not cfg.enabled then return jsonb_build_object('status','disabled'); end if;
 if not cfg.cache_license_approved or cfg.daily_credit_limit<4 or cfg.account_daily_credit_limit<4 then
  return jsonb_build_object('status','unconfigured'); end if;
 actor_scope := coalesce(p_actor::text,'anonymous');
 delete from private.location_preview_usage where bucket<day;
 delete from private.location_preview_images where expires_at<=statement_timestamp();
 select u.used into used from private.location_preview_usage u where u.scope='minute:global' and bucket=minute;
 if coalesce(used,0)>=60 then return jsonb_build_object('status','rate_limited'); end if;
 select u.used into used from private.location_preview_usage u where u.scope='minute:'||actor_scope and bucket=minute;
 if coalesce(used,0)>=12 then return jsonb_build_object('status','rate_limited'); end if;
 insert into private.location_preview_usage values('minute:global',minute,1),('minute:'||actor_scope,minute,1)
  on conflict(scope,bucket) do update set used=private.location_preview_usage.used+1;
 if p_cacheable then
  select * into cached from private.location_preview_images where image_key=p_image_key;
  if found then return jsonb_build_object('status',case cached.state when 'ready' then 'ok' else 'unavailable' end,
   'cached',true,'image_base64',case when cached.state='ready' then encode(cached.image,'base64') else null end); end if;
 end if;
 select u.used into used from private.location_preview_usage u where u.scope='credits:global' and bucket=day;
 select b.used into search_used from private.location_search_budgets b where b.scope='global' and bucket=day;
 if coalesce(used,0)+4>cfg.daily_credit_limit or coalesce(used,0)+coalesce(search_used,0)+4>cfg.account_daily_credit_limit then
  return jsonb_build_object('status','budget_exhausted'); end if;
 select u.used into used from private.location_preview_usage u where u.scope='credits:'||actor_scope and bucket=day;
 if coalesce(used,0)+4>80 then return jsonb_build_object('status','budget_exhausted'); end if;
 insert into private.location_preview_usage values('credits:global',day,4),('credits:'||actor_scope,day,4)
  on conflict(scope,bucket) do update set used=private.location_preview_usage.used+4;
 if p_cacheable then
  insert into private.location_preview_images(image_key,expires_at) values(p_image_key,day+interval '1 day') returning * into cached;
 end if;
 return jsonb_build_object('status','ok','cached',false,'token',cached.token);
end;
$$;
revoke all on function public.reserve_location_preview_v1(text,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function public.reserve_location_preview_v1(text,boolean,uuid) to service_role;

create function public.finish_location_preview_v1(p_image_key text,p_token uuid,p_image_base64 text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare bytes_value bytea;
begin
 if p_image_base64 is not null then
  if length(p_image_base64)>710000 then raise exception using errcode='22023',message='Invalid preview image.'; end if;
  bytes_value := decode(p_image_base64,'base64');
  if octet_length(bytes_value) not between 45 and 524288 or encode(substring(bytes_value from 1 for 8),'hex')<>'89504e470d0a1a0a'
   or encode(substring(bytes_value from 13 for 12),'hex')<>'494844520000020000000100'
   or encode(substring(bytes_value from octet_length(bytes_value)-11 for 12),'hex')<>'0000000049454e44ae426082' then
   raise exception using errcode='22023',message='Invalid preview image.';
  end if;
 end if;
 update private.location_preview_images set state=case when bytes_value is null then 'failed' else 'ready' end,
  image=bytes_value where image_key=p_image_key and token=p_token and state='pending';
 if not found then raise exception using errcode='P0002',message='Preview claim unavailable.'; end if;
end;
$$;
revoke all on function public.finish_location_preview_v1(text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.finish_location_preview_v1(text,uuid,text) to service_role;

-- Preserve MAP01 search semantics, adding only the shared credit ceiling.
create or replace function public.reserve_location_search_v1(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_session uuid,p_query_hash text)
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
  -- Rendering shares an account ceiling with autocomplete. The search-config
  -- row lock above serializes both meters; cache hits consume no new credits.
  if not exists(select 1 from private.location_preview_config where singleton) then
    return jsonb_build_object('status','metering_unavailable');
  end if;
  if exists(select 1 from private.location_preview_config c where singleton
    and (c.enabled or c.account_daily_credit_limit>0)
    and coalesce((select used from private.location_preview_usage where scope='credits:global' and bucket=daily),0)
      +coalesce((select used from private.location_search_budgets where scope='global' and bucket=daily),0)+1
      >c.account_daily_credit_limit) then
    return jsonb_build_object('status','budget_exhausted');
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
