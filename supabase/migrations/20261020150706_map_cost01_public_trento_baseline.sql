-- MAP-COST01: fixed public cartography only; opt-in does not activate a provider.
-- Twelve z12 tiles cover the measured 340dp initial map at phone widths <=768dp
-- and Povo. No actor, search, item, exact meeting point or overlay enters this tier.
create table private.map_baseline_config (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 license_approved boolean not null default false,
 retention_seconds integer not null default 604800 check(retention_seconds between 1 and 604800),
 revision integer not null default 1 check(revision>0)
);
insert into private.map_baseline_config(singleton) values(true);
create table private.map_baseline_tiles (
 z integer not null check(z=12),
 x integer not null check(x between 2173 and 2175),
 y integer not null check(y between 1454 and 1457),
 revision integer not null check(revision>0),
 token uuid not null default extensions.gen_random_uuid(),
 state text not null check(state in ('pending','ready','failed')),
 acquired_at timestamptz,
 expires_at timestamptz not null,
 image bytea check(octet_length(image) between 45 and 262144),
 primary key(z,x,y),
 check((state='ready' and acquired_at is not null and image is not null)
    or (state<>'ready' and image is null))
);
-- The coordinate CHECKs + PK cap storage at 12 rows / 3 MiB compressed bytes,
-- independent of unrelated high-zoom cache traffic. Lazy pruning is not timed deletion.
alter table private.map_baseline_config enable row level security;
alter table private.map_baseline_tiles enable row level security;
revoke all on private.map_baseline_config,private.map_baseline_tiles from public,anon,authenticated,service_role;

create function private.is_trento_baseline_v2(p_z integer,p_x integer,p_y integer)
returns boolean language sql immutable set search_path='' as $$
 select p_z=12 and p_x between 2173 and 2175 and p_y between 1454 and 1457
$$;
create function private.basemap_tile_payload_v2(p_z integer,p_x integer,p_y integer,p_image bytea,p_expiry timestamptz,p_acquired timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('status','ok','cached',true,
  'source',jsonb_build_object('z',p_z,'x',p_x,'y',p_y,'style','osm-carto','version',1,'dimension',256,'density',1),
  'acquired_at',p_acquired,'expires_at',p_expiry,'server_time',statement_timestamp(),
  'budget_exhausted',false,'retry_after_seconds',0,'image_base64',replace(encode(p_image,'base64'),E'\n',''))
$$;
create function private.basemap_ancestor_v2(p_z integer,p_x integer,p_y integer)
returns jsonb language sql stable security definer set search_path='' as $$
 select private.basemap_tile_payload_v2(t.z,t.x,t.y,t.image,
  least(t.expires_at,t.acquired_at+make_interval(secs=>c.retention_seconds)),t.acquired_at)
 from private.map_baseline_tiles t cross join private.map_baseline_config c
 where c.singleton and c.enabled and c.license_approved and t.revision=c.revision
  and p_z between 13 and 18 and t.z=12 and t.x=(p_x >> (p_z-12)) and t.y=(p_y >> (p_z-12))
  and t.state='ready' and least(t.expires_at,t.acquired_at+make_interval(secs=>c.retention_seconds))>statement_timestamp()
$$;
-- Add the calendar day while still in UTC timestamp space. Adding a day to
-- timestamptz first would inherit a session timezone's daylight-saving boundary.
create function private.basemap_retry_v2(p_now timestamptz)
returns integer language sql immutable strict set search_path='' as $$
 select greatest(1,ceil(extract(epoch from
  ((date_trunc('day',p_now at time zone 'UTC')+interval '1 day') at time zone 'UTC')-p_now))::integer)
$$;
revoke all on function private.is_trento_baseline_v2(integer,integer,integer),
 private.basemap_tile_payload_v2(integer,integer,integer,bytea,timestamptz,timestamptz),
 private.basemap_ancestor_v2(integer,integer,integer),private.basemap_retry_v2(timestamptz) from public,anon,authenticated,service_role;

-- Versioned service-only tile API. Existing tile/center contracts are untouched.
-- Lock order remains search config -> shared provider config -> baseline config.
create function public.reserve_basemap_tile_v2(p_actor uuid,p_z integer,p_x integer,p_y integer,p_cache_only boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.location_provider_config%rowtype; baseline private.map_baseline_config%rowtype;
 tile private.map_baseline_tiles%rowtype; cached private.map_provider_cache%rowtype;
 status text; key text; is_base boolean; ancestor jsonb; expiry timestamptz; retry integer;
begin
 if p_z is null or p_z not between 7 and 18 or p_x is null or p_y is null
  or p_x<0 or p_y<0 or p_x>=power(2,p_z) or p_y>=power(2,p_z) or p_cache_only is null then
  raise exception using errcode='22023',message='Invalid basemap tile.'; end if;
 if p_actor is null then return jsonb_build_object('status','guest_disabled'); end if;
 if not exists(select 1 from public.profiles where id=p_actor) then
  raise exception using errcode='42501',message='Map provider actor unavailable.'; end if;
 status := private.reserve_location_provider_v1('tile',p_actor,false);
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
 status := private.reserve_location_provider_v1('tile',p_actor,true);
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
revoke all on function public.reserve_basemap_tile_v2(uuid,integer,integer,integer,boolean) from public,anon,authenticated,service_role;
grant execute on function public.reserve_basemap_tile_v2(uuid,integer,integer,integer,boolean) to service_role;

create function public.finish_basemap_tile_v2(p_z integer,p_x integer,p_y integer,p_token uuid,p_image_base64 text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.location_provider_config%rowtype; baseline private.map_baseline_config%rowtype;
 cached private.map_provider_cache%rowtype; bytes_value bytea; result jsonb; key text; expiry timestamptz;
begin
 if p_z is null or p_z not between 7 and 18 or p_x is null or p_y is null or p_x<0 or p_y<0
  or p_x>=power(2,p_z) or p_y>=power(2,p_z) or p_token is null then
  raise exception using errcode='22023',message='Invalid basemap tile.'; end if;
 perform 1 from private.location_search_config where singleton for update;
 select * into cfg from private.location_provider_config where singleton for update;
 select * into baseline from private.map_baseline_config where singleton for update;
 if cfg.singleton is null or not cfg.enabled or not cfg.tiles_enabled or cfg.daily_units_limit=0
  or not cfg.cache_license_approved or cfg.tile_cache_seconds=0 or baseline.singleton is null or not baseline.enabled or not baseline.license_approved then
  delete from private.map_baseline_tiles where z=p_z and x=p_x and y=p_y and token=p_token and state='pending';
  return jsonb_build_object('status','disabled');
 end if;
 key := encode(extensions.digest('tile:v1:osm-carto:'||p_z||':'||p_x||':'||p_y,'sha256'),'hex');
 if not private.is_trento_baseline_v2(p_z,p_x,p_y) then
  result := public.finish_map_provider_v1(key,p_token,null,p_image_base64);
  if result->>'status'<>'ok' then return result; end if;
  select * into cached from private.map_provider_cache where cache_key=key;
  return private.basemap_tile_payload_v2(p_z,p_x,p_y,cached.image,cached.expires_at,null) || '{"cached":false}'::jsonb;
 end if;
 perform 1 from private.map_baseline_tiles where z=p_z and x=p_x and y=p_y and token=p_token
  and state='pending' and revision=baseline.revision and expires_at>statement_timestamp() for update;
 if not found then return jsonb_build_object('status','expired'); end if;
 if p_image_base64 is null then
  update private.map_baseline_tiles set state='failed',expires_at=statement_timestamp()+interval '15 seconds' where z=p_z and x=p_x and y=p_y;
  update private.location_provider_config set failure_streak=least(failure_streak+1,5),
   blocked_until=case when failure_streak>=4 then statement_timestamp()+interval '1 minute' else blocked_until end where singleton;
  return jsonb_build_object('status','unavailable');
 end if;
 if length(p_image_base64)>350000 then raise exception using errcode='22023',message='Invalid map tile.'; end if;
 bytes_value := decode(p_image_base64,'base64');
 if octet_length(bytes_value) not between 45 and 262144 or encode(substring(bytes_value from 1 for 8),'hex')<>'89504e470d0a1a0a'
  or encode(substring(bytes_value from 13 for 12),'hex')<>'494844520000010000000100'
  or encode(substring(bytes_value from octet_length(bytes_value)-11 for 12),'hex')<>'0000000049454e44ae426082' then
  raise exception using errcode='22023',message='Invalid map tile.'; end if;
 expiry := statement_timestamp()+make_interval(secs=>baseline.retention_seconds);
 update private.map_baseline_tiles set state='ready',image=bytes_value,acquired_at=statement_timestamp(),expires_at=expiry
  where z=p_z and x=p_x and y=p_y;
 update private.location_provider_config set failure_streak=0,blocked_until=null where singleton;
 return private.basemap_tile_payload_v2(p_z,p_x,p_y,bytes_value,expiry,statement_timestamp()) || '{"cached":false}'::jsonb;
end;
$$;
revoke all on function public.finish_basemap_tile_v2(integer,integer,integer,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.finish_basemap_tile_v2(integer,integer,integer,uuid,text) to service_role;
