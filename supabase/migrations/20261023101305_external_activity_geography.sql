-- ACTGEO01: external catalogue scope only; native geography is unchanged.
alter table private.external_activities add column published_point extensions.geography(Point,4326)
 generated always as (case when content->'geometry' is not null and content->'geometry'<>'null'::jsonb
  then extensions.st_setsrid(extensions.st_makepoint((content->'geometry'->>'longitude')::double precision,
   (content->'geometry'->>'latitude')::double precision),4326)::extensions.geography end) stored;
create index external_activities_geo_radius on private.external_activities using gist(published_point) where published_point is not null;
create index external_activities_geo_bounds on private.external_activities using gist((published_point::extensions.geometry)) where published_point is not null;

-- A database-local cursor key is private durable configuration, never returned.
-- Rotating it invalidates short-lived cursors; it grants no record authority.
create table private.external_catalogue_cursor_key (
 singleton boolean primary key default true check(singleton),
 key bytea not null check(octet_length(key)=32)
);
alter table private.external_catalogue_cursor_key enable row level security;
revoke all on private.external_catalogue_cursor_key from public,anon,authenticated,service_role;
insert into private.external_catalogue_cursor_key(singleton,key) values(true,extensions.gen_random_bytes(32));
create function private.external_catalogue_cursor_signature(p_payload jsonb)
returns text language sql stable set search_path='' as $$
 select encode(extensions.hmac(convert_to(p_payload::text,'UTF8'),key,'sha256'),'hex')
 from private.external_catalogue_cursor_key where singleton
$$;

create function private.external_catalogue_area(p_area jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare v_mode text; k text; n numeric; s double precision; w double precision; e double precision; north double precision;
begin
 if p_area is null then return null; end if;
 if jsonb_typeof(p_area)<>'object' or octet_length(p_area::text)>1024 then
  raise exception 'Invalid external geographic area.' using errcode='22023';
 end if;
 v_mode:=p_area->>'mode';
 if v_mode='radius' then
  if p_area-array['mode','latitude','longitude','radius_m']<>'{}'::jsonb then raise exception 'Invalid external geographic area.' using errcode='22023'; end if;
  foreach k in array array['latitude','longitude','radius_m'] loop
   if jsonb_typeof(p_area->k) is distinct from 'number' then raise exception 'Invalid external geographic area.' using errcode='22023'; end if;
   n:=(p_area->>k)::numeric;
   if (k='latitude' and n not between -90 and 90) or (k='longitude' and n not between -180 and 180)
    or (k='radius_m' and n not between 1 and 100000) then raise exception 'Invalid external geographic area.' using errcode='22023'; end if;
  end loop;
  return jsonb_build_object('mode','radius','latitude',(p_area->>'latitude')::double precision,
   'longitude',(p_area->>'longitude')::double precision,'radius_m',(p_area->>'radius_m')::double precision);
 elsif v_mode='bounds' then
  if p_area-array['mode','south','west','north','east']<>'{}'::jsonb then raise exception 'Invalid external geographic area.' using errcode='22023'; end if;
  foreach k in array array['south','west','north','east'] loop
   if jsonb_typeof(p_area->k) is distinct from 'number' then raise exception 'Invalid external geographic area.' using errcode='22023'; end if;
  end loop;
  s:=(p_area->>'south')::double precision; w:=(p_area->>'west')::double precision;
  north:=(p_area->>'north')::double precision; e:=(p_area->>'east')::double precision;
  if not(s between -85 and 85 and north between -85 and 85 and w between -180 and 180 and e between -180 and 180
   and s<north and w<e and north-s<=4 and e-w<=4) then
   raise exception 'Invalid external geographic area.' using errcode='22023';
  end if;
  if extensions.st_area(extensions.st_makeenvelope(w,s,e,north,4326)::extensions.geography)>50000000000 then
   raise exception 'External viewport exceeds 50000 square kilometers; narrow the area.' using errcode='22023';
  end if;
  return jsonb_build_object('mode','bounds','south',s,'west',w,'north',north,'east',e);
 end if;
 raise exception 'Invalid external geographic area.' using errcode='22023';
end $$;

create function private.external_catalogue_spatial_candidates(p_area jsonb)
returns setof uuid language plpgsql stable set search_path='' as $$
begin
 if p_area->>'mode'='radius' then
  return query select activity_id from private.external_activities where published_point is not null and
   extensions.st_dwithin(published_point,extensions.st_setsrid(extensions.st_makepoint((p_area->>'longitude')::double precision,
    (p_area->>'latitude')::double precision),4326)::extensions.geography,(p_area->>'radius_m')::double precision);
 elsif p_area->>'mode'='bounds' then
  return query select activity_id from private.external_activities where published_point is not null and
   (published_point::extensions.geometry) operator(extensions.&&) extensions.st_makeenvelope((p_area->>'west')::double precision,
    (p_area->>'south')::double precision,(p_area->>'east')::double precision,(p_area->>'north')::double precision,4326);
 end if;
end $$;

create function public.list_external_activities_v3(p_kind text default null,p_category text default null,p_query text default '',p_discipline text default null,p_from date default null,p_to date default null,p_limit integer default 20,p_cursor jsonb default null,p_area jsonb default null,p_map_only boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
declare
 v_now timestamptz:=statement_timestamp(); v_as_of timestamptz:=v_now;
 v_query text:=lower(btrim(coalesce(p_query,''))); v_versions jsonb; v_filters jsonb;
 v_items jsonb; v_cursor jsonb; v_facets jsonb; v_success timestamptz; v_failed boolean; v_state text; v_sources jsonb; v_ok integer; v_never integer; v_area jsonb; v_candidates integer; v_center extensions.geography;
begin
 v_area:=private.external_catalogue_area(p_area);
 if v_area->>'mode'='radius' then
  v_center:=extensions.st_setsrid(extensions.st_makepoint((v_area->>'longitude')::double precision,(v_area->>'latitude')::double precision),4326)::extensions.geography;
 end if;
 if p_map_only is null then raise exception 'Invalid external geographic scope.' using errcode='22023'; end if;
 if p_limit is null or p_limit not between 1 and 30 or length(v_query)>120
  or (p_kind is not null and p_kind not in ('event','course','place'))
  or (p_category is not null and p_category not in ('sports','culture','other'))
  or (p_discipline is not null and p_discipline !~ '^[a-z][a-z0-9-]{0,63}$')
  or (p_from is null)<>(p_to is null) or (p_from is not null and
   (not isfinite(p_from) or not isfinite(p_to) or p_to<=p_from or p_to-p_from>90)) then
  raise exception 'Invalid activity filters.' using errcode='22023';
 end if;
 select jsonb_agg(jsonb_build_array(source_id,catalogue_version) order by source_id),min(last_success_at),
  bool_or(last_attempt_state in ('failure','incomplete')),
  count(*) filter(where last_success_at is not null and last_attempt_state not in ('failure','incomplete')),
  count(*) filter(where last_success_at is null),
  jsonb_build_object('configured',count(*),'failed',count(*) filter(where last_attempt_state in ('failure','incomplete')),'pending',count(*) filter(where last_success_at is null))
 into v_versions,v_success,v_failed,v_ok,v_never,v_sources
 from private.external_activity_sources where enabled and rights_confirmed;
 v_filters:=jsonb_build_object('kind',p_kind,'category',p_category,'query',v_query,'discipline',p_discipline,'from',p_from,'to',p_to,'area',v_area,'map_only',p_map_only);
 if p_cursor is not null then
  if jsonb_typeof(p_cursor)<>'object' or octet_length(p_cursor::text)>8192
   or p_cursor-array['versions','filters','as_of','rank','key','id','signature']<>'{}'::jsonb then
   raise exception 'Activity cursor requires refresh.' using errcode='22023';
  end if;
  if p_cursor->>'signature' is distinct from private.external_catalogue_cursor_signature(p_cursor-'signature')
   or p_cursor->'versions' is distinct from v_versions or p_cursor->'filters' is distinct from v_filters
   or p_cursor->>'as_of' is null or p_cursor->>'rank' is null or p_cursor->>'key' is null or p_cursor->>'id' is null then
   raise exception 'Activity cursor requires refresh.' using errcode='22023';
  end if;
  v_as_of:=(p_cursor->>'as_of')::timestamptz;
  if not isfinite(v_as_of) or v_as_of>v_now or v_as_of<v_now-interval '15 minutes' then
   raise exception 'Activity cursor requires refresh.' using errcode='22023';
  end if;
 end if;
 with eligible as materialized (
  select r.*,a.published_point from private.external_catalogue_rows(v_now,v_as_of,p_kind,p_category,p_from,p_to) r
   join private.external_activities a using(activity_id)
   where (not p_map_only or a.published_point is not null)
    and (v_area is null or r.activity_id in (select private.external_catalogue_spatial_candidates(v_area)))
 ), matches as (
  select * from eligible where
   (v_query='' or position(v_query in lower(concat_ws(' ',content->>'title',content->>'description',content->>'city',content->>'venue')))>0)
   and (p_discipline is null or content->>'discipline'=p_discipline)
   and (p_cursor is null or (sort_rank,sort_key,activity_id)>((p_cursor->>'rank')::integer,p_cursor->>'key',(p_cursor->>'id')::uuid))
  order by sort_rank,sort_key,activity_id limit p_limit+1
 ), page as (select * from matches order by sort_rank,sort_key,activity_id limit p_limit)
 select coalesce((select jsonb_agg(private.external_catalogue_payload(a,s,v_now)||jsonb_build_object('next_at',p.next_at,'next_occurrence',p.next_occurrence,
   'map_identity','external_activity:'||p.activity_id::text,
   'distance_m',case when v_center is not null and a.content->'geometry'->>'precision'='venue' then round(extensions.st_distance(a.published_point,v_center)) end)
   order by p.sort_rank,p.sort_key,p.activity_id) from page p
   join private.external_activities a using(activity_id) join private.external_activity_sources s on s.source_id=a.source_id),'[]'::jsonb),
  case when (select count(*) from matches)>p_limit then (select jsonb_build_object('versions',v_versions,'filters',v_filters,'as_of',v_as_of,
   'rank',sort_rank,'key',sort_key,'id',activity_id) from page order by sort_rank desc,sort_key desc,activity_id desc limit 1) end,
  jsonb_build_object(
   'disciplines',coalesce((select jsonb_agg(d order by d) from (select distinct content->>'discipline' d from eligible where content->>'discipline' is not null) ds),'[]'::jsonb),
   'kinds',coalesce((select jsonb_agg(k order by k) from (select distinct coalesce(content->>'kind','event') k from eligible) ks),'[]'::jsonb),
   'categories',coalesce((select jsonb_agg(c order by c) from (select distinct content->>'category' c from eligible) cs),'[]'::jsonb))
  ,(select count(*) from eligible where
    (v_query='' or position(v_query in lower(concat_ws(' ',content->>'title',content->>'description',content->>'city',content->>'venue')))>0)
    and (p_discipline is null or content->>'discipline'=p_discipline))
 into v_items,v_cursor,v_facets,v_candidates;
 if (p_map_only or v_area is not null) and v_candidates>2000 then
  raise exception 'More than 2000 external spatial candidates; narrow the area or filters.' using errcode='54000';
 end if;
 if v_cursor is not null then v_cursor:=v_cursor||jsonb_build_object('signature',private.external_catalogue_cursor_signature(v_cursor)); end if;
 v_state:=case when v_versions is null then 'unconfigured'
  when (v_failed or v_never>0) and v_ok>0 then 'partial'
  when v_failed then 'unavailable' when v_success is null then 'never_synchronized'
  when v_success<v_now-case when p_kind='place' then interval '7 days' else interval '72 hours' end
   or exists(select 1 from jsonb_array_elements(v_items) x where x->>'stale'='true') then 'stale'
  when v_items='[]'::jsonb then 'empty' else 'healthy' end;
 return jsonb_build_object('state',v_state,'as_of',v_as_of,'items',v_items,'next_cursor',v_cursor,
  'facets',v_facets,'disciplines',v_facets->'disciplines','last_success_at',v_success,'sources',v_sources,'scope','external_activities');
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
 raise exception 'Invalid external area or cursor; refresh.' using errcode='22023';
end $$;

revoke all on function private.external_catalogue_cursor_signature(jsonb),private.external_catalogue_area(jsonb),private.external_catalogue_spatial_candidates(jsonb)
 from public,anon,authenticated,service_role;
revoke all on function public.list_external_activities_v3(text,text,text,text,date,date,integer,jsonb,jsonb,boolean) from public,anon,authenticated,service_role;
grant execute on function public.list_external_activities_v3(text,text,text,text,date,date,integer,jsonb,jsonb,boolean) to anon,authenticated;
comment on function public.list_external_activities_v3(text,text,text,text,date,date,integer,jsonb,jsonb,boolean) is
 'ACTGEO01 external catalogue only. Same canonical eligibility/filter helper as V2; mapped subset is explicit. MAP04 radius 1..100000m, bounds <=4 degrees/50000km2, 2000 matching spatial candidates. HMAC cursor binds full filters/area/source versions/order/reference, expires in 15min. Venue-only rounded geodesic distance from explicit reference. Native map scopes unchanged.';
