-- MAPMOCK01: public pixels only; additive, default-off mock subcaps inside the
-- existing global quarter-credit ledger. No profile or second provider account.
create table private.mock_basemap_config (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 daily_units_limit integer not null default 800 check(daily_units_limit between 1 and 2000),
 actor_daily_units integer not null default 120 check(actor_daily_units between 1 and 320),
 client_daily_units integer not null default 160 check(client_daily_units between 1 and 400),
 actor_minute_requests integer not null default 24 check(actor_minute_requests between 1 and 30),
 client_minute_requests integer not null default 36 check(client_minute_requests between 1 and 60),
 aggregate_minute_requests integer not null default 60 check(aggregate_minute_requests between 1 and 120)
);
insert into private.mock_basemap_config(singleton) values(true);
alter table private.mock_basemap_config enable row level security;
revoke all on private.mock_basemap_config from public,anon,authenticated,service_role;

-- Lock order: search -> provider -> mock -> baseline. Both the global ledger
-- and tile pending rows are serialized by the SAME installed provider lock.
create function private.reserve_mock_map_provider_v1(p_actor text,p_client text,p_charge boolean)
returns text language plpgsql security definer set search_path='' as $$
declare cfg private.location_provider_config%rowtype; mock private.mock_basemap_config%rowtype;
 day timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
 minute timestamptz := date_trunc('minute',statement_timestamp());
begin
 if p_actor is null or p_actor !~ '^[a-f0-9]{64}$' or p_client is null or p_client !~ '^[a-f0-9]{64}$' or p_charge is null then
  raise exception using errcode='22023',message='Invalid mock map scope'; end if;
 perform 1 from private.location_search_config where singleton for update;
 if not found then return 'unconfigured'; end if;
 select * into cfg from private.location_provider_config where singleton for update;
 if not found or not cfg.enabled or not cfg.tiles_enabled then return 'disabled'; end if;
 if cfg.daily_units_limit=0 then return 'unconfigured'; end if;
 if cfg.blocked_until>statement_timestamp() then return 'unavailable'; end if;
 select * into mock from private.mock_basemap_config where singleton for update;
 if not found or not mock.enabled then return 'disabled'; end if;
 delete from private.location_provider_usage where bucket<day;
 if not p_charge then
  if coalesce((select used from private.location_provider_usage where scope='requests:global' and bucket=minute),0)>=cfg.global_minute_requests
   or coalesce((select used from private.location_provider_usage where scope='requests:mock' and bucket=minute),0)>=least(mock.aggregate_minute_requests,cfg.global_minute_requests/2)
   or coalesce((select used from private.location_provider_usage where scope='requests:mock:actor:'||p_actor and bucket=minute),0)>=mock.actor_minute_requests
   or coalesce((select used from private.location_provider_usage where scope='requests:mock:client:'||p_client and bucket=minute),0)>=mock.client_minute_requests then return 'rate_limited'; end if;
  insert into private.location_provider_usage values('requests:global',minute,1),('requests:mock',minute,1),
   ('requests:mock:actor:'||p_actor,minute,1),('requests:mock:client:'||p_client,minute,1)
   on conflict(scope,bucket) do update set used=private.location_provider_usage.used+1;
  return 'ok';
 end if;
 -- Mock can never spend over one quarter of the configured global allowance,
 -- even after operator configuration lowers the existing global ceiling.
 if coalesce((select used from private.location_provider_usage where scope='units:global' and bucket=day),0)+1>cfg.daily_units_limit
  or coalesce((select used from private.location_provider_usage where scope='units:mock' and bucket=day),0)+1>least(mock.daily_units_limit,cfg.daily_units_limit/4)
  or coalesce((select used from private.location_provider_usage where scope='units:mock:actor:'||p_actor and bucket=day),0)+1>mock.actor_daily_units
  or coalesce((select used from private.location_provider_usage where scope='units:mock:client:'||p_client and bucket=day),0)+1>mock.client_daily_units then return 'budget_exhausted'; end if;
 insert into private.location_provider_usage values('units:global',day,1),('units:mock',day,1),
  ('units:mock:actor:'||p_actor,day,1),('units:mock:client:'||p_client,day,1)
  on conflict(scope,bucket) do update set used=private.location_provider_usage.used+1;
 return 'ok';
end;
$$;
revoke all on function private.reserve_mock_map_provider_v1(text,text,boolean) from public,anon,authenticated,service_role;

-- Extract the installed v2 cache/ancestor algorithm without changing its normal
-- actor, payload, cache key, expiry, lock, rate or charging contract.
create function private.reserve_basemap_tile_internal_v3(p_actor uuid,p_mock_actor text,p_mock_client text,p_z integer,p_x integer,p_y integer,p_cache_only boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.location_provider_config%rowtype; baseline private.map_baseline_config%rowtype;
 tile private.map_baseline_tiles%rowtype; cached private.map_provider_cache%rowtype;
 status text; key text; is_base boolean; ancestor jsonb; expiry timestamptz; retry integer;
begin
 if p_z is null or p_z not between 7 and 18 or p_x is null or p_y is null
  or p_x<0 or p_y<0 or p_x>=power(2,p_z) or p_y>=power(2,p_z) or p_cache_only is null then
  raise exception using errcode='22023',message='Invalid basemap tile.'; end if;
 if p_mock_actor is null then
  if p_mock_client is not null then raise exception using errcode='22023',message='Invalid map scope'; end if;
  if p_actor is null then return jsonb_build_object('status','guest_disabled'); end if;
  if not exists(select 1 from public.profiles where id=p_actor) then
   raise exception using errcode='42501',message='Map provider actor unavailable.'; end if;
 elsif p_actor is not null then raise exception using errcode='22023',message='Invalid map scope'; end if;
 status := case when p_mock_actor is null then private.reserve_location_provider_v1('tile',p_actor,false)
  else private.reserve_mock_map_provider_v1(p_mock_actor,p_mock_client,false) end;
 select * into cfg from private.location_provider_config where singleton;
 if status<>'ok' then
  retry := case when status='rate_limited' then greatest(1,ceil(extract(epoch from date_trunc('minute',statement_timestamp())+interval '1 minute'-statement_timestamp()))::integer)
   when status='unavailable' and cfg.blocked_until>statement_timestamp() then ceil(extract(epoch from cfg.blocked_until-statement_timestamp()))::integer else 0 end;
  return jsonb_build_object('status',status,'retry_after_seconds',retry);
 end if;
 select * into baseline from private.map_baseline_config where singleton for update;
 if not found or not baseline.enabled then return jsonb_build_object('status','disabled'); end if;
 if not baseline.license_approved or not cfg.cache_license_approved or cfg.tile_cache_seconds=0 then
  return jsonb_build_object('status','unconfigured'); end if;
 delete from private.map_baseline_tiles where revision<>baseline.revision or expires_at<=statement_timestamp()
  or state='ready' and acquired_at+make_interval(secs=>baseline.retention_seconds)<=statement_timestamp();
 delete from private.map_provider_cache where expires_at<=statement_timestamp();
 is_base := private.is_trento_baseline_v2(p_z,p_x,p_y);
 key := encode(extensions.digest('tile:v1:osm-carto:'||p_z||':'||p_x||':'||p_y,'sha256'),'hex');
 if is_base then
  select * into tile from private.map_baseline_tiles where z=p_z and x=p_x and y=p_y;
  if found then
   if tile.state<>'ready' then return jsonb_build_object('status',case tile.state when 'pending' then 'pending' else 'unavailable' end,'retry_after_seconds',30); end if;
   expiry := least(tile.expires_at,tile.acquired_at+make_interval(secs=>baseline.retention_seconds));
   return private.basemap_tile_payload_v2(p_z,p_x,p_y,tile.image,expiry,tile.acquired_at);
  end if;
 end if;
 -- Preserve exact ordinary ready hits before any upstream charge, including at cap.
 select * into cached from private.map_provider_cache where cache_key=key and kind='tile';
 if found then
  if cached.state<>'ready' then return jsonb_build_object('status',case cached.state when 'pending' then 'pending' else 'unavailable' end,'retry_after_seconds',30); end if;
  return private.basemap_tile_payload_v2(p_z,p_x,p_y,cached.image,cached.expires_at,null);
 end if;
 if p_cache_only then
  ancestor := private.basemap_ancestor_v2(p_z,p_x,p_y);
  return coalesce(ancestor,jsonb_build_object('status','cache_miss','retry_after_seconds',0));
 end if;
 status := case when p_mock_actor is null then private.reserve_location_provider_v1('tile',p_actor,true)
  else private.reserve_mock_map_provider_v1(p_mock_actor,p_mock_client,true) end;
 if status<>'ok' then
  if status='budget_exhausted' then
   retry := private.basemap_retry_v2(statement_timestamp());
   ancestor := private.basemap_ancestor_v2(p_z,p_x,p_y);
   return coalesce(ancestor,jsonb_build_object('status',status)) || jsonb_build_object('budget_exhausted',true,'retry_after_seconds',retry);
  end if;
  return jsonb_build_object('status',status);
 end if;
 if is_base then
  insert into private.map_baseline_tiles(z,x,y,revision,state,expires_at)
   values(p_z,p_x,p_y,baseline.revision,'pending',statement_timestamp()+interval '30 seconds') returning token into tile.token;
  return jsonb_build_object('status','ok','cached',false,'token',tile.token);
 end if;
 insert into private.map_provider_cache(cache_key,kind,expires_at)
  values(key,'tile',statement_timestamp()+make_interval(secs=>least(cfg.tile_cache_seconds,30))) returning token into cached.token;
 return jsonb_build_object('status','ok','cached',false,'token',cached.token);
end;
$$;

revoke all on function private.reserve_basemap_tile_internal_v3(uuid,text,text,integer,integer,integer,boolean) from public,anon,authenticated,service_role;

create or replace function public.reserve_basemap_tile_v2(p_actor uuid,p_z integer,p_x integer,p_y integer,p_cache_only boolean)
returns jsonb language sql security definer set search_path='' as $$
 select private.reserve_basemap_tile_internal_v3(p_actor,null,null,p_z,p_x,p_y,p_cache_only)
$$;
-- CREATE OR REPLACE retains the installed OID/ACL/result signature.

create function public.reserve_mock_basemap_tile_v1(p_actor_scope text,p_client_scope text,p_z integer,p_x integer,p_y integer,p_cache_only boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_actor_scope is null or p_client_scope is null then
  raise exception using errcode='22023',message='Invalid mock map scope'; end if;
 return private.reserve_basemap_tile_internal_v3(null,p_actor_scope,p_client_scope,p_z,p_x,p_y,p_cache_only);
end;
$$;
create function public.finish_mock_basemap_tile_v1(p_z integer,p_x integer,p_y integer,p_token uuid,p_image_base64 text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform 1 from private.location_search_config where singleton for update;
 perform 1 from private.location_provider_config where singleton for update;
 perform 1 from private.mock_basemap_config where singleton and enabled for update;
 if not found then return jsonb_build_object('status','disabled'); end if;
 return public.finish_basemap_tile_v2(p_z,p_x,p_y,p_token,p_image_base64);
end;
$$;
revoke all on function public.reserve_mock_basemap_tile_v1(text,text,integer,integer,integer,boolean),
 public.finish_mock_basemap_tile_v1(integer,integer,integer,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.reserve_mock_basemap_tile_v1(text,text,integer,integer,integer,boolean),
 public.finish_mock_basemap_tile_v1(integer,integer,integer,uuid,text) to service_role;
