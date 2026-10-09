-- MAP04: public references only; no meeting-details access or provider calls.
-- Separate geography/expression GiST indexes support radius and inclusive point boxes.
create index proposals_map04_radius on public.proposals using gist (approximate_location)
  where lifecycle_state='published' and approximate_location is not null and selected_public_place is not null;
create index proposals_map04_bounds on public.proposals using gist ((approximate_location::extensions.geometry))
  where lifecycle_state='published' and approximate_location is not null and selected_public_place is not null;
create index recurring_activities_map04_radius on public.recurring_activities using gist (approximate_location)
  where lifecycle_state='published' and approximate_location is not null and selected_public_place is not null;
create index recurring_activities_map04_bounds on public.recurring_activities using gist ((approximate_location::extensions.geometry))
  where lifecycle_state='published' and approximate_location is not null and selected_public_place is not null;
create index resource_listings_map04_radius on public.resource_listings using gist (public_location)
  where lifecycle_state='published' and public_location is not null and selected_public_place is not null;
create index resource_listings_map04_bounds on public.resource_listings using gist ((public_location::extensions.geometry))
  where lifecycle_state='published' and public_location is not null and selected_public_place is not null;

-- Cheap spatial/filter candidates are capped BEFORE recurring occurrence/card enrichment.
create function private.geo_public_candidates_v1(
  p_query jsonb, p_reference timestamptz, p_after_kind text, p_after_id uuid
) returns table(kind text,item_id uuid)
language plpgsql stable set search_path='' as $$
declare v_center extensions.geography; v_box extensions.geometry;
begin
  if p_query->>'mode'='radius' then
    v_center:=extensions.st_setsrid(extensions.st_makepoint((p_query->>'longitude')::double precision,(p_query->>'latitude')::double precision),4326)::extensions.geography;
    return query
    (select 'one_time'::text, p.id from public.proposals p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'one_time'
      and (p_after_kind is null or ('one_time'::text,p.id)>(p_after_kind,p_after_id))
      and p.ends_at > p_reference - interval '24 hours' and p.ends_at > statement_timestamp() - interval '24 hours'
      and (p_query->>'proposal_locality' is null or lower(p.locality)=p_query->>'proposal_locality')
      and (p_query->>'proposal_keyword' is null or strpos(lower(p.title),p_query->>'proposal_keyword')>0 or strpos(lower(p.summary),p_query->>'proposal_keyword')>0 or strpos(lower(p.description),p_query->>'proposal_keyword')>0)
      and (jsonb_array_length(p_query->'proposal_skill_ids')=0 or exists(select 1 from public.proposal_skills s where s.proposal_id=p.id and s.skill_id in (select value::uuid from jsonb_array_elements_text(p_query->'proposal_skill_ids'))))
      and extensions.st_dwithin(p.approximate_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001)
    union all
    (select 'recurring'::text, p.id from public.recurring_activities p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'recurring'
      and (p_after_kind is null or ('recurring'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'tavolo_locality' is null or lower(p.locality)=p_query->>'tavolo_locality')
      and extensions.st_dwithin(p.approximate_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001)
    union all
    (select 'resource'::text, p.id from public.resource_listings p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.public_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'resource'
      and (p_after_kind is null or ('resource'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'resource_locality' is null or lower(p.locality)=p_query->>'resource_locality')
      and (p_query->>'resource_mode' is null or p.listing_mode=p_query->>'resource_mode')
      and (p_query->>'resource_keyword' is null or strpos(lower(p.title),p_query->>'resource_keyword')>0 or strpos(lower(p.description),p_query->>'resource_keyword')>0)
      and extensions.st_dwithin(p.public_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001);
  else
    v_box:=extensions.st_makeenvelope((p_query->>'west')::double precision,(p_query->>'south')::double precision,(p_query->>'east')::double precision,(p_query->>'north')::double precision,4326);
    return query
    (select 'one_time'::text, p.id from public.proposals p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'one_time'
      and (p_after_kind is null or ('one_time'::text,p.id)>(p_after_kind,p_after_id))
      and p.ends_at > p_reference - interval '24 hours' and p.ends_at > statement_timestamp() - interval '24 hours'
      and (p_query->>'proposal_locality' is null or lower(p.locality)=p_query->>'proposal_locality')
      and (p_query->>'proposal_keyword' is null or strpos(lower(p.title),p_query->>'proposal_keyword')>0 or strpos(lower(p.summary),p_query->>'proposal_keyword')>0 or strpos(lower(p.description),p_query->>'proposal_keyword')>0)
      and (jsonb_array_length(p_query->'proposal_skill_ids')=0 or exists(select 1 from public.proposal_skills s where s.proposal_id=p.id and s.skill_id in (select value::uuid from jsonb_array_elements_text(p_query->'proposal_skill_ids'))))
      and (p.approximate_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001)
    union all
    (select 'recurring'::text, p.id from public.recurring_activities p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'recurring'
      and (p_after_kind is null or ('recurring'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'tavolo_locality' is null or lower(p.locality)=p_query->>'tavolo_locality')
      and (p.approximate_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001)
    union all
    (select 'resource'::text, p.id from public.resource_listings p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.public_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'resource'
      and (p_after_kind is null or ('resource'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'resource_locality' is null or lower(p.locality)=p_query->>'resource_locality')
      and (p_query->>'resource_mode' is null or p.listing_mode=p_query->>'resource_mode')
      and (p_query->>'resource_keyword' is null or strpos(lower(p.title),p_query->>'resource_keyword')>0 or strpos(lower(p.description),p_query->>'resource_keyword')>0)
      and (p.public_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001);
  end if;
end;
$$;
revoke all on function private.geo_public_candidates_v1(jsonb,timestamptz,text,uuid) from public,anon,authenticated,service_role;

create function public.search_public_geography_v1(
  p_query jsonb, p_limit integer default 20, p_cursor jsonb default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  q jsonb; v_mode text; v_key text; v_reference timestamptz;
  v_reference_text text; v_after_kind text; v_after_id uuid;
  v_kinds jsonb; v_skills jsonb; v_candidates jsonb; v_rows jsonb; v_items jsonb;
  v_more boolean; v_next jsonb; v_last jsonb; k text; n double precision;
  v_south double precision; v_north double precision; v_west double precision; v_east double precision;
begin
  if p_query is null or jsonb_typeof(p_query)<>'object' or pg_column_size(p_query)>8192
    or p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode='22023',message='Geographic query must be an object <=8192 bytes; page size must be 1..50.';
  end if;
  if (p_query-array['mode','latitude','longitude','radius_m','south','west','north','east','kinds',
      'proposal_keyword','proposal_locality','proposal_skill_ids','tavolo_locality',
      'resource_keyword','resource_locality','resource_mode','reference_time'])<>'{}'::jsonb then
    raise exception using errcode='22023',message='Unsupported geographic query fields.';
  end if;
  v_mode:=p_query->>'mode';
  if v_mode is null or v_mode not in ('radius','bounds') then
    raise exception using errcode='22023',message='Geographic mode must be radius or bounds.';
  end if;
  if v_mode='radius' then
    if p_query ?| array['south','west','north','east'] then
      raise exception using errcode='22023',message='Radius and bounds inputs are mutually exclusive.';
    end if;
    foreach k in array array['latitude','longitude','radius_m'] loop
      if jsonb_typeof(p_query->k) is distinct from 'number' then
        raise exception using errcode='22023',message='Radius requires numeric latitude, longitude and radius_m.';
      end if;
      n:=(p_query->>k)::double precision;
      if (k='latitude' and not(n between -90 and 90))
        or (k='longitude' and not(n between -180 and 180))
        or (k='radius_m' and not(n between 1 and 100000)) then
        raise exception using errcode='22023',message='Invalid center or radius; radius_m must be 1..100000.';
      end if;
    end loop;
    q:=jsonb_build_object('mode',v_mode,'latitude',(p_query->>'latitude')::double precision,
      'longitude',(p_query->>'longitude')::double precision,'radius_m',(p_query->>'radius_m')::double precision);
  else
    if p_query ?| array['latitude','longitude','radius_m'] then
      raise exception using errcode='22023',message='Radius and bounds inputs are mutually exclusive.';
    end if;
    foreach k in array array['south','west','north','east'] loop
      if jsonb_typeof(p_query->k) is distinct from 'number' then
        raise exception using errcode='22023',message='Bounds require numeric south, west, north and east.';
      end if;
    end loop;
    v_south:=(p_query->>'south')::double precision; v_north:=(p_query->>'north')::double precision;
    v_west:=(p_query->>'west')::double precision; v_east:=(p_query->>'east')::double precision;
    if not(v_south between -85 and 85 and v_north between -85 and 85
      and v_west between -180 and 180 and v_east between -180 and 180
      and v_south<v_north and v_west<v_east and v_north-v_south<=4 and v_east-v_west<=4) then
      raise exception using errcode='22023',message='Invalid bounds: no poles/antimeridian; ordered spans must be >0 and <=4 degrees.';
    end if;
    if extensions.st_area(extensions.st_makeenvelope(v_west,v_south,v_east,v_north,4326)::extensions.geography)>50000000000 then
      raise exception using errcode='22023',message='Viewport exceeds 50000 square kilometers; narrow the area.';
    end if;
    q:=jsonb_build_object('mode',v_mode,'south',v_south,'west',v_west,'north',v_north,'east',v_east);
  end if;
  v_kinds:=coalesce(p_query->'kinds','["one_time","recurring","resource"]'::jsonb);
  if jsonb_typeof(v_kinds)<>'array' or jsonb_array_length(v_kinds) not between 1 and 3
    or exists(select 1 from jsonb_array_elements(v_kinds) x where jsonb_typeof(x)<>'string' or x#>>'{}' not in ('one_time','recurring','resource')) then
    raise exception using errcode='22023',message='Kinds must contain 1..3 supported families.';
  end if;
  select jsonb_agg(x order by x) into v_kinds from (select distinct value x from jsonb_array_elements_text(v_kinds)) s;
  v_skills:=coalesce(p_query->'proposal_skill_ids','[]'::jsonb);
  if jsonb_typeof(v_skills)<>'array' or jsonb_array_length(v_skills)>20
    or exists(select 1 from jsonb_array_elements(v_skills) x where jsonb_typeof(x)<>'string'
      or (x#>>'{}')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise exception using errcode='22023',message='Proposal skills must contain at most 20 UUID strings.';
  end if;
  select coalesce(jsonb_agg(x order by x),'[]'::jsonb) into v_skills from (select distinct value::uuid x from jsonb_array_elements_text(v_skills)) s;
  q:=q||jsonb_build_object('kinds',v_kinds,'proposal_skill_ids',v_skills);
  foreach k in array array['proposal_keyword','proposal_locality','tavolo_locality','resource_keyword','resource_locality','resource_mode'] loop
    if p_query ? k and p_query->k<>'null'::jsonb and
      (jsonb_typeof(p_query->k)<>'string' or char_length(p_query->>k)>120 or (p_query->>k)~'[[:cntrl:]]') then
      raise exception using errcode='22023',message='Geographic filters must be strings <=120 characters without controls.';
    end if;
    q:=q||jsonb_build_object(k,nullif(lower(btrim(p_query->>k)),''));
  end loop;
  if q->>'resource_mode' is not null and q->>'resource_mode' not in ('donate','exchange') then
    raise exception using errcode='22023',message='Resource mode must be donate or exchange.';
  end if;
  if p_cursor is not null then
    if jsonb_typeof(p_cursor)<>'object' or pg_column_size(p_cursor)>1024
      or p_cursor-array['query_key','reference_time','kind','item_id']<>'{}'::jsonb
      or not(p_cursor ?& array['query_key','reference_time','kind','item_id'])
      or coalesce(p_cursor->>'query_key','')!~'^[0-9a-f]{64}$'
      or coalesce(p_cursor->>'kind','') not in ('one_time','recurring','resource')
      or coalesce(p_cursor->>'item_id','')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or exists(select 1 from jsonb_each(p_cursor) x where jsonb_typeof(x.value)<>'string') then
      raise exception using errcode='22023',message='Malformed geographic cursor.';
    end if;
    v_after_kind:=p_cursor->>'kind'; v_after_id:=(p_cursor->>'item_id')::uuid;
  end if;
  if p_query ? 'reference_time' and jsonb_typeof(p_query->'reference_time')<>'string' then
    raise exception using errcode='22023',message='Reference time must be an ISO timestamp.';
  end if;
  v_reference:=coalesce(p_query->>'reference_time',p_cursor->>'reference_time',statement_timestamp()::text)::timestamptz;
  if not isfinite(v_reference) or v_reference<statement_timestamp()-interval '15 minutes'
    or v_reference>statement_timestamp()+interval '1 minute' then
    raise exception using errcode='22023',message='Reference time expired or future; refresh geographic search.';
  end if;
  v_reference_text:=to_char(v_reference at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
  q:=jsonb_strip_nulls(q||jsonb_build_object('reference_time',v_reference_text));
  v_key:=encode(extensions.digest(q::text,'sha256'),'hex');
  if p_cursor is not null and (p_cursor->>'query_key'<>v_key
    or (p_cursor->>'reference_time')::timestamptz<>v_reference
    or not(v_kinds ? v_after_kind)) then
    raise exception using errcode='22023',message='Cursor does not belong to this geographic query; refresh.';
  end if;

  select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into v_candidates
    from private.geo_public_candidates_v1(q,v_reference,v_after_kind,v_after_id) c;
  if jsonb_array_length(v_candidates)>2000 then
    raise exception using errcode='54000',message='More than 2000 spatial candidates; narrow the area or filters.';
  end if;
  with ids as materialized (select * from jsonb_to_recordset(v_candidates) as x(kind text,item_id uuid)),
  cards as (
    select 'one_time'::text kind,p.id item_id,p.approximate_location point,p.selected_public_place place,
      p.title,cover.object_path cover_object_path,p.starts_at,p.ends_at,p.event_timezone,
      private.derive_proposal_status(p.starts_at,p.ends_at,v_reference) derived_status,null::text listing_mode
    from ids join public.proposals p on ids.kind='one_time' and p.id=ids.item_id
    left join public.project_covers cover on cover.project_id=p.id
    union all
    select 'recurring',p.id,p.approximate_location,p.selected_public_place,p.title,cover.object_path,
      occurrence.starts_at,occurrence.ends_at,occurrence.event_timezone,null::text,null::text
    from ids join public.recurring_activities p on ids.kind='recurring' and p.id=ids.item_id
    cross join lateral private.next_recurring_activity_occurrence(p.id,v_reference) occurrence
    left join public.project_covers cover on cover.project_id=p.id
    union all
    select 'resource',p.id,p.public_location,p.selected_public_place,p.title,cover.object_path,
      null::timestamptz,null::timestamptz,null::text,null::text,p.listing_mode
    from ids join public.resource_listings p on ids.kind='resource' and p.id=ids.item_id
    left join public.resource_listing_covers cover on cover.listing_id=p.id
  ), page as (select * from cards order by kind,item_id limit p_limit+1)
  select coalesce(jsonb_agg(jsonb_build_object(
    'kind',kind,'item_id',item_id,'latitude',extensions.st_y(point::extensions.geometry),
    'longitude',extensions.st_x(point::extensions.geometry),'precision',place->>'kind',
    'is_approximate',place->>'kind'='locality',
    'match_precision',case when place->>'kind'='locality' then 'locality_reference' else 'public_point' end,
    'title',title,'cover_object_path',cover_object_path,'public_location_label',place->>'label',
    'starts_at',starts_at,'ends_at',ends_at,'event_timezone',event_timezone,
    'derived_status',derived_status,'listing_mode',listing_mode) order by kind,item_id),'[]'::jsonb)
    into v_rows from page;
  v_more:=jsonb_array_length(v_rows)>p_limit;
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into v_items
    from jsonb_array_elements(v_rows) with ordinality where ordinality<=p_limit;
  if v_more then
    v_last:=v_items->(p_limit-1);
    v_next:=jsonb_build_object('query_key',v_key,'reference_time',v_reference_text,
      'kind',v_last->>'kind','item_id',v_last->>'item_id');
  end if;
  return jsonb_build_object('query_key',v_key,'reference_time',v_reference_text,'items',v_items,
    'has_more',v_more,'next_cursor',v_next,'attribution',jsonb_build_object(
      'geoapify_url','https://www.geoapify.com/','openstreetmap_url','https://www.openstreetmap.org/copyright'));
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
  raise exception using errcode='22023',message='Malformed geographic coordinates, filters, cursor or reference time.';
end;
$$;
revoke all on function public.search_public_geography_v1(jsonb,integer,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.search_public_geography_v1(jsonb,integer,jsonb) to anon,authenticated;
comment on function public.search_public_geography_v1(jsonb,integer,jsonb) is
  'MAP04 bounded public reference search. Locality points are approximate references, never venues or municipal extents. Query-scoped kind/UUID keyset; 15-minute reference snapshot; 2000 candidate cap. No private geometry/distance/count.';
