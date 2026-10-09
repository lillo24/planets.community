-- MAP05: shared quarter-credit ceiling and authenticated, transient map adapters.
-- No provider is activated by this migration. Existing public discovery is unchanged.
create table private.location_provider_config (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 daily_units_limit integer not null default 0 check(daily_units_limit between 0 and 8000),
 actor_daily_units integer not null default 320 check(actor_daily_units between 1 and 8000),
 actor_minute_requests integer not null default 120 check(actor_minute_requests between 1 and 120),
 global_minute_requests integer not null default 600 check(global_minute_requests between 1 and 600),
 center_enabled boolean not null default false,
 tiles_enabled boolean not null default false,
 cache_license_approved boolean not null default false,
 tile_cache_seconds integer not null default 0 check(tile_cache_seconds between 0 and 3600),
 failure_streak integer not null default 0 check(failure_streak between 0 and 5),
 blocked_until timestamptz
);
insert into private.location_provider_config(singleton) values(true);
create table private.location_provider_usage (
 scope text not null, bucket timestamptz not null,
 used integer not null check(used>=0), primary key(scope,bucket)
);
create table private.map_provider_cache (
 cache_key text primary key check(cache_key ~ '^[a-f0-9]{64}$'),
 kind text not null check(kind in ('center','tile')),
 actor uuid references public.profiles(id) on delete restrict,
 token uuid not null default extensions.gen_random_uuid(),
 state text not null default 'pending' check(state in ('pending','ready','failed')),
 expires_at timestamptz not null,
 centers jsonb,
 image bytea check(octet_length(image)<=262144),
 check((kind='center' and actor is not null and image is null)
    or (kind='tile' and actor is null and centers is null))
);
create index map_provider_cache_expiry on private.map_provider_cache(expires_at);
alter table private.location_provider_config enable row level security;
alter table private.location_provider_usage enable row level security;
alter table private.map_provider_cache enable row level security;
revoke all on private.location_provider_config,private.location_provider_usage,private.map_provider_cache
 from public,anon,authenticated,service_role;

-- Preserve already reserved current-day credits on an upgrade. Whole-credit
-- legacy counters stay unchanged; only the new ledger uses quarter-credit units.
insert into private.location_provider_usage(scope,bucket,used)
select 'units:global',bucket,sum(used*4)::integer from (
 select bucket,used from private.location_search_budgets where scope='global'
 union all select bucket,used from private.location_preview_usage where scope='credits:global'
) old where bucket=date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC'
group by bucket;
insert into private.location_provider_usage(scope,bucket,used)
select scope,bucket,sum(used*4)::integer from (
 select 'units:'||scope as scope,bucket,used from private.location_search_budgets where scope like 'actor:%'
 union all select 'units:actor:'||substring(scope from 9),bucket,used
 from private.location_preview_usage where scope like 'credits:%' and scope<>'credits:global'
) old where bucket=date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC'
group by scope,bucket;

-- All consumers lock search-config FIRST, then the shared config. No network
-- is performed in these short transactions. Cache requests still use rate limits.
create function private.reserve_location_provider_v1(p_consumer text,p_actor uuid,p_charge boolean)
returns text language plpgsql security definer set search_path='' as $$
declare cfg private.location_provider_config%rowtype; units integer; actor_scope text;
 day timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
 minute timestamptz := date_trunc('minute',statement_timestamp());
begin
 if p_consumer is null or p_consumer not in ('editor','static','center','tile') or p_charge is null then
  raise exception using errcode='22023',message='Invalid provider reservation.'; end if;
 perform 1 from private.location_search_config where singleton for update;
 if not found then return 'unconfigured'; end if;
 select * into cfg from private.location_provider_config where singleton for update;
 if not found or not cfg.enabled then return 'disabled'; end if;
 if cfg.daily_units_limit=0 then return 'unconfigured'; end if;
 if cfg.blocked_until>statement_timestamp() then return 'unavailable'; end if;
 if p_consumer in ('center','tile') and p_actor is null then return 'guest_disabled'; end if;
 if p_consumer='center' and not cfg.center_enabled or p_consumer='tile' and not cfg.tiles_enabled then return 'disabled'; end if;
 actor_scope := coalesce(p_actor::text,'anonymous');
 delete from private.location_provider_usage where bucket<day;
 if not p_charge then
  if coalesce((select used from private.location_provider_usage where scope='requests:global' and bucket=minute),0)>=cfg.global_minute_requests
   or coalesce((select used from private.location_provider_usage where scope='requests:'||actor_scope and bucket=minute),0)>=cfg.actor_minute_requests then return 'rate_limited'; end if;
  insert into private.location_provider_usage values('requests:global',minute,1),('requests:'||actor_scope,minute,1)
   on conflict(scope,bucket) do update set used=private.location_provider_usage.used+1;
  return 'ok';
 end if;
 units := case p_consumer when 'tile' then 1 when 'static' then 16 else 4 end;
 if coalesce((select used from private.location_provider_usage where scope='units:global' and bucket=day),0)+units>cfg.daily_units_limit
  or coalesce((select used from private.location_provider_usage where scope='units:actor:'||actor_scope and bucket=day),0)+units>cfg.actor_daily_units then return 'budget_exhausted'; end if;
 insert into private.location_provider_usage values('units:global',day,units),('units:actor:'||actor_scope,day,units)
  on conflict(scope,bucket) do update set used=private.location_provider_usage.used+excluded.used;
 return 'ok';
end;
$$;
revoke all on function private.reserve_location_provider_v1(text,uuid,boolean) from public,anon,authenticated,service_role;

-- Only verified Edge actors reach this narrow service-only boundary. Guests are
-- deliberately denied: no installation IDs or forwarded-IP headers are trusted.
create function public.reserve_map_provider_v1(p_actor uuid,p_kind text,p_cache_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.location_provider_config%rowtype; cached private.map_provider_cache%rowtype;
 status text; ttl integer;
begin
 if p_kind is null or p_kind not in ('center','tile') or p_cache_key is null or p_cache_key !~ '^[a-f0-9]{64}$' then
  raise exception using errcode='22023',message='Invalid map provider scope.'; end if;
 if p_actor is null then return jsonb_build_object('status','guest_disabled'); end if;
 if not exists(select 1 from public.profiles where id=p_actor) then
  raise exception using errcode='42501',message='Map provider actor unavailable.'; end if;
 status := private.reserve_location_provider_v1(p_kind,p_actor,false);
 if status<>'ok' then return jsonb_build_object('status',status); end if;
 select * into cfg from private.location_provider_config where singleton;
 if not cfg.cache_license_approved or p_kind='tile' and cfg.tile_cache_seconds=0 then
  return jsonb_build_object('status','unconfigured'); end if;
 delete from private.map_provider_cache where expires_at<=statement_timestamp();
 select * into cached from private.map_provider_cache where cache_key=p_cache_key;
 if found then
  if cached.kind<>p_kind or p_kind='center' and cached.actor<>p_actor then
   raise exception using errcode='42501',message='Map provider scope mismatch.'; end if;
  if cached.state<>'ready' then return jsonb_build_object('status',case cached.state when 'pending' then 'pending' else 'unavailable' end); end if;
  return jsonb_build_object('status','ok','cached',true,
   'suggestions',case when p_kind='center' then coalesce((select jsonb_agg(jsonb_build_object('id',c->>'id','label',c->'center'->>'label','expires_at',cached.expires_at)) from jsonb_array_elements(cached.centers) c),'[]'::jsonb) else null end,
   'image_base64',case when p_kind='tile' then encode(cached.image,'base64') else null end);
 end if;
 status := private.reserve_location_provider_v1(p_kind,p_actor,true);
 if status<>'ok' then return jsonb_build_object('status',status); end if;
 -- Pending reservations expire independently of cache retention; upstream
 -- failures/timeouts are charged and never retried by an invisible background job.
 ttl := case p_kind when 'center' then 300 else cfg.tile_cache_seconds end;
 insert into private.map_provider_cache(cache_key,kind,actor,expires_at)
  values(p_cache_key,p_kind,case when p_kind='center' then p_actor else null end,
   statement_timestamp()+make_interval(secs=>least(ttl,30))) returning * into cached;
 return jsonb_build_object('status','ok','cached',false,'token',cached.token);
end;
$$;
revoke all on function public.reserve_map_provider_v1(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.reserve_map_provider_v1(uuid,text,text) to service_role;

create function public.finish_map_provider_v1(p_cache_key text,p_token uuid,p_centers jsonb default null,p_image_base64 text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cached private.map_provider_cache%rowtype; cfg private.location_provider_config%rowtype;
 bytes_value bytea; centers_value jsonb := '[]'::jsonb; center jsonb; ttl integer;
begin
 perform 1 from private.location_search_config where singleton for update;
 select * into cfg from private.location_provider_config where singleton for update;
 select * into cached from private.map_provider_cache where cache_key=p_cache_key and token=p_token and state='pending' and expires_at>statement_timestamp() for update;
 if not found then return jsonb_build_object('status','expired'); end if;
 if cfg.singleton is null or not cfg.enabled or cfg.daily_units_limit=0 or not cfg.cache_license_approved
  or cached.kind='tile' and not cfg.tiles_enabled or cached.kind='center' and not cfg.center_enabled then
  delete from private.map_provider_cache where cache_key=p_cache_key;
  return jsonb_build_object('status','disabled'); end if;
 if p_centers is null and p_image_base64 is null then
  update private.map_provider_cache set state='failed',expires_at=statement_timestamp()+interval '15 seconds' where cache_key=p_cache_key;
  update private.location_provider_config set failure_streak=least(failure_streak+1,5),
   blocked_until=case when failure_streak>=4 then statement_timestamp()+interval '1 minute' else blocked_until end where singleton;
  return jsonb_build_object('status','unavailable');
 end if;
 if cached.kind='center' then
  if p_image_base64 is not null or jsonb_typeof(p_centers) is distinct from 'array' or jsonb_array_length(p_centers)>5 then
   raise exception using errcode='22023',message='Invalid map centers.'; end if;
  for center in select value from jsonb_array_elements(p_centers) loop
   if jsonb_typeof(center) is distinct from 'object' or (center-array['label','latitude','longitude','country_code'])<>'{}'::jsonb
    or jsonb_typeof(center->'label') is distinct from 'string' or length(btrim(center->>'label')) not between 1 and 240
    or (center->>'label') ~ '[[:cntrl:]]' or center->>'country_code' is distinct from 'it'
    or jsonb_typeof(center->'latitude') is distinct from 'number' or jsonb_typeof(center->'longitude') is distinct from 'number'
    or not ((center->>'latitude')::numeric between -90 and 90) or not ((center->>'longitude')::numeric between -180 and 180) then
    raise exception using errcode='22023',message='Invalid map center.'; end if;
   centers_value := centers_value || jsonb_build_array(jsonb_build_object('id',extensions.gen_random_uuid(),'center',center));
  end loop;
  ttl := 300;
 else
  if p_centers is not null or p_image_base64 is null or length(p_image_base64)>350000 then
   raise exception using errcode='22023',message='Invalid map tile.'; end if;
  bytes_value := decode(p_image_base64,'base64');
  if octet_length(bytes_value) not between 45 and 262144 or encode(substring(bytes_value from 1 for 8),'hex')<>'89504e470d0a1a0a'
   or encode(substring(bytes_value from 13 for 12),'hex')<>'494844520000010000000100'
   or encode(substring(bytes_value from octet_length(bytes_value)-11 for 12),'hex')<>'0000000049454e44ae426082' then
   raise exception using errcode='22023',message='Invalid map tile.'; end if;
  ttl := cfg.tile_cache_seconds;
  centers_value := null;
 end if;
 update private.map_provider_cache set state='ready',centers=centers_value,image=bytes_value,
  expires_at=statement_timestamp()+make_interval(secs=>ttl) where cache_key=p_cache_key;
 update private.location_provider_config set failure_streak=0,blocked_until=null where singleton;
 return jsonb_build_object('status','ok','suggestions',case when cached.kind='center' then
  coalesce((select jsonb_agg(jsonb_build_object('id',c->>'id','label',c->'center'->>'label','expires_at',statement_timestamp()+interval '5 minutes')) from jsonb_array_elements(centers_value) c),'[]'::jsonb) else null end);
end;
$$;
revoke all on function public.finish_map_provider_v1(text,uuid,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.finish_map_provider_v1(text,uuid,jsonb,text) to service_role;

create function public.resolve_map_center_v1(p_actor uuid,p_suggestion uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare status text; center_value jsonb;
begin
 if p_actor is null then return jsonb_build_object('status','guest_disabled'); end if;
 status := private.reserve_location_provider_v1('center',p_actor,false);
 if status<>'ok' then return jsonb_build_object('status',status); end if;
 select c->'center' into center_value from private.map_provider_cache b,
  lateral jsonb_array_elements(b.centers) c
  where b.actor=p_actor and b.kind='center' and b.state='ready' and b.expires_at>statement_timestamp()
   and c->>'id'=p_suggestion::text limit 1;
 if center_value is null then return jsonb_build_object('status','expired'); end if;
 return jsonb_build_object('status','ok','center',center_value);
end;
$$;
revoke all on function public.resolve_map_center_v1(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.resolve_map_center_v1(uuid,uuid) to service_role;


-- Preserve legacy feature quotas and signatures; every uncached upstream
-- request now also reserves the common account ledger. Existing caches are gated.
create or replace function public.reserve_location_preview_v1(p_image_key text,p_cacheable boolean,p_actor uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg private.location_preview_config%rowtype; cached private.location_preview_images%rowtype;
 day timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
 minute timestamptz := date_trunc('minute',statement_timestamp()); used integer; search_used integer; actor_scope text;
 provider_status text;
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
  provider_status := private.reserve_location_provider_v1('static',p_actor,false);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
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
  provider_status := private.reserve_location_provider_v1('static',p_actor,true);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
 insert into private.location_preview_usage values('credits:global',day,4),('credits:'||actor_scope,day,4)
  on conflict(scope,bucket) do update set used=private.location_preview_usage.used+4;
 if p_cacheable then
  insert into private.location_preview_images(image_key,expires_at) values(p_image_key,day+interval '1 day') returning * into cached;
 end if;
 return jsonb_build_object('status','ok','cached',false,'token',cached.token);
end;
$$;


-- Preserve legacy feature quotas and signatures; every uncached upstream
-- request now also reserves the common account ledger. Existing caches are gated.
create or replace function public.reserve_location_search_v1(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_session uuid,p_query_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg private.location_search_config%rowtype; batch private.location_search_batches%rowtype;
  current_revision bigint; daily timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
  minute timestamptz := date_trunc('minute',statement_timestamp()); used_count integer;
 provider_status text;
begin
  current_revision := private.lock_location_item(p_actor,p_kind,p_item);
  if p_revision is distinct from current_revision then return jsonb_build_object('status','stale_selection'); end if;
  if p_session is null or p_query_hash is null or p_query_hash !~ '^[a-f0-9]{64}$'
    or p_slot is null or (p_kind='resource' and p_slot<>'public') or (p_kind<>'resource' and p_slot not in ('area','exact')) then
    raise exception using errcode='22023',message='Invalid location search scope.';
  end if;
  select * into cfg from private.location_search_config where singleton for update;
  if not found or not cfg.enabled then return jsonb_build_object('status','disabled'); end if;
  provider_status := private.reserve_location_provider_v1('editor',p_actor,false);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
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
  provider_status := private.reserve_location_provider_v1('editor',p_actor,true);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
  insert into private.location_search_budgets(scope,bucket,used) values ('global',daily,1),('actor:'||p_actor,daily,1),('minute:'||p_actor,minute,1)
    on conflict(scope,bucket) do update set used=private.location_search_budgets.used+1;
  insert into private.location_search_batches(actor,item_kind,item_id,revision,slot,session_id,query_hash)
    values(p_actor,p_kind,p_item,p_revision,p_slot,p_session,p_query_hash) returning * into batch;
  return jsonb_build_object('status','ok','cached',false,'batch_id',batch.id);
end;
$$;
