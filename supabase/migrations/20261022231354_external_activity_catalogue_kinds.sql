-- ACTCAT02 is additive. V1 continues to return described, dated events only.
-- Configuration, leases and canonical identities remain in the existing tables.
-- Preserve the installed validator OID for already prepared import calls.
create function private.validate_external_event_v1(p_record jsonb,p_origin text)
returns void language plpgsql set search_path='' as $$
declare v_key text; v_value jsonb; v_occ jsonb; v_start timestamptz; v_end timestamptz;
begin
 if jsonb_typeof(p_record)<>'object' or p_record-array['upstream_id','title','description','canonical_url','category','source_categories','discipline','organizer','cost','audience','city','venue','address','status','publishable','source_modified_at','occurrences']<>'{}'::jsonb then
  raise exception 'Invalid activity fields.' using errcode='22023';
 end if;
 foreach v_key in array array['upstream_id','title','description','canonical_url','category','status'] loop
  if jsonb_typeof(p_record->v_key) is distinct from 'string' then raise exception 'Invalid activity text.' using errcode='22023'; end if;
 end loop;
 if length(p_record->>'upstream_id') not between 1 and 200 or length(btrim(p_record->>'title')) not between 1 and 300
  or length(btrim(p_record->>'description')) not between 1 and 12000 or p_record->>'category' not in ('sports','culture','other')
  or p_record->>'status' not in ('scheduled','cancelled','unpublished')
  or jsonb_typeof(p_record->'publishable') is distinct from 'boolean'
  or not private.activity_public_https_url(p_record->>'canonical_url')
  or left(p_record->>'canonical_url',length(p_origin)+1)<>p_origin||'/' then
  raise exception 'Invalid activity content.' using errcode='22023';
 end if;
 foreach v_key in array array['title','description','organizer','cost','audience','city','venue','address','discipline'] loop
  v_value:=p_record->v_key;
  if v_value is not null and v_value<>'null'::jsonb and (
    jsonb_typeof(v_value)<>'string' or length(btrim(p_record->>v_key))=0 or length(p_record->>v_key)>case when v_key='description' then 12000 when v_key in ('cost','audience') then 2000 else 500 end
    or (p_record->>v_key) ~ '<[/!]?[A-Za-z][^>]*>'
    or (p_record->>v_key) ~ '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]') then
   raise exception 'Activity content must be bounded plain text.' using errcode='22023';
  end if;
 end loop;
 if p_record->>'discipline' is not null and p_record->>'discipline' !~ '^[a-z][a-z0-9-]{0,63}$' then
  raise exception 'Invalid discipline.' using errcode='22023';
 end if;
 if jsonb_typeof(p_record->'source_categories') is distinct from 'array' or jsonb_array_length(p_record->'source_categories')>12 then
  raise exception 'Invalid source categories.' using errcode='22023';
 end if;
 if exists(select 1 from jsonb_array_elements(p_record->'source_categories') x where jsonb_typeof(x)<>'string' or length(btrim(x#>>'{}'))=0 or length(x#>>'{}')>100 or (x#>>'{}') ~ '[<>[:cntrl:]]') then
  raise exception 'Invalid source categories.' using errcode='22023';
 end if;
 if p_record->>'source_modified_at' is not null then
  if p_record->>'source_modified_at' !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$' then raise exception 'Invalid modification time.' using errcode='22023'; end if;
  perform (p_record->>'source_modified_at')::timestamptz;
 end if;
 if jsonb_typeof(p_record->'occurrences') is distinct from 'array' or jsonb_array_length(p_record->'occurrences')>200 then
  raise exception 'Invalid occurrences.' using errcode='22023';
 end if;
 for v_occ in select value from jsonb_array_elements(p_record->'occurrences') loop
  if jsonb_typeof(v_occ)<>'object' or v_occ-array['kind','start','end','timezone']<>'{}'::jsonb
   or v_occ->>'kind' is null or v_occ->>'kind' not in ('timed','date','all_day')
   or jsonb_typeof(v_occ->'start') is distinct from 'string'
   or not exists(select 1 from pg_catalog.pg_timezone_names where name=v_occ->>'timezone') then
   raise exception 'Invalid occurrence.' using errcode='22023';
  end if;
  if v_occ->>'kind'='timed' then
   if v_occ->>'start' !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$'
    or (v_occ->>'end' is not null and v_occ->>'end' !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') then raise exception 'Invalid timed occurrence.' using errcode='22023'; end if;
   v_start:=(v_occ->>'start')::timestamptz;
   v_end:=coalesce((v_occ->>'end')::timestamptz,v_start);
  else
   if v_occ->>'start' !~ '^\d{4}-\d{2}-\d{2}$' or (v_occ->>'end' is not null and v_occ->>'end' !~ '^\d{4}-\d{2}-\d{2}$') then raise exception 'Invalid date occurrence.' using errcode='22023'; end if;
   v_start:=(v_occ->>'start')::date::timestamp at time zone (v_occ->>'timezone');
   v_end:=coalesce((v_occ->>'end')::date,(v_occ->>'start')::date+1)::timestamp at time zone (v_occ->>'timezone');
   if v_end<=v_start then raise exception 'Invalid exclusive date end.' using errcode='22023'; end if;
  end if;
  if not isfinite(v_start) or not isfinite(v_end) or v_end<v_start then raise exception 'Invalid occurrence interval.' using errcode='22023'; end if;
 end loop;
end $$;



create or replace function private.validate_external_activity(p_record jsonb,p_origin text)
returns void language plpgsql set search_path='' as $$
declare
 v_kind text:=coalesce(p_record->>'kind','event'); v_schedule jsonb:=p_record->'schedule';
 v_geometry jsonb:=p_record->'geometry'; v_weekly jsonb; v_key text; v_date date;
 v_start date; v_end date; v_days jsonb;
begin
 -- Reuse all proven URL, occurrence and plain-text checks. The temporary
 -- description validates nullability only; it is never stored or published.
 perform private.validate_external_event_v1(
  (p_record-array['kind','schedule','geometry','level','access']) ||
  case when p_record->>'description' is null then '{"description":"validation only"}'::jsonb else '{}'::jsonb end,p_origin);
 if v_kind not in ('event','course','place') or
  (p_record->'kind' is not null and jsonb_typeof(p_record->'kind')<>'string') or
  (v_kind='place' and jsonb_array_length(p_record->'occurrences')<>0) then
  raise exception 'Invalid catalogue kind.' using errcode='22023';
 end if;
 foreach v_key in array array['level','access'] loop
  if p_record->>v_key is not null and (jsonb_typeof(p_record->v_key)<>'string'
   or length(btrim(p_record->>v_key)) not between 1 and 2000
   or (p_record->>v_key) ~ '<[/!]?[A-Za-z][^>]*>|[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]') then
   raise exception 'Invalid catalogue information.' using errcode='22023';
  end if;
 end loop;
 if v_geometry is not null and v_geometry<>'null'::jsonb then
  if jsonb_typeof(v_geometry)<>'object' or v_geometry-array['latitude','longitude','precision','provenance_url']<>'{}'::jsonb
   or jsonb_typeof(v_geometry->'latitude') is distinct from 'number'
   or jsonb_typeof(v_geometry->'longitude') is distinct from 'number'
   or v_geometry->>'precision' is null or v_geometry->>'precision' not in ('venue','locality')
   or not private.activity_public_https_url(v_geometry->>'provenance_url')
   or left(v_geometry->>'provenance_url',length(p_origin)+1)<>p_origin||'/' then
   raise exception 'Invalid published geometry.' using errcode='22023';
  end if;
  if abs((v_geometry->>'latitude')::numeric)>90 or abs((v_geometry->>'longitude')::numeric)>180 then
   raise exception 'Invalid published coordinates.' using errcode='22023';
  end if;
 end if;
 if v_schedule is null or v_schedule='null'::jsonb then return; end if;
 if v_kind<>'course' or jsonb_typeof(v_schedule)<>'object'
  or v_schedule-array['season_start','season_end','timezone','text','weekly','exceptions']<>'{}'::jsonb then
  raise exception 'Invalid course schedule.' using errcode='22023';
 end if;
 foreach v_key in array array['season_start','season_end'] loop
  if v_schedule->>v_key is not null then
   if jsonb_typeof(v_schedule->v_key)<>'string' or v_schedule->>v_key !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'Invalid course date.' using errcode='22023';
   end if;
   v_date:=(v_schedule->>v_key)::date;
   if not isfinite(v_date) then raise exception 'Invalid course date.' using errcode='22023'; end if;
  end if;
 end loop;
 v_start:=(v_schedule->>'season_start')::date; v_end:=(v_schedule->>'season_end')::date;
 if v_start is not null and v_end is not null and (v_end<v_start or v_end-v_start>366) then
  raise exception 'Course term must be bounded to 366 days.' using errcode='22023';
 end if;
 if v_schedule->>'timezone' is not null and (jsonb_typeof(v_schedule->'timezone')<>'string'
  or not exists(select 1 from pg_catalog.pg_timezone_names where name=v_schedule->>'timezone')) then
  raise exception 'Invalid course timezone.' using errcode='22023';
 end if;
 if v_schedule->>'text' is not null and (jsonb_typeof(v_schedule->'text')<>'string'
  or length(btrim(v_schedule->>'text')) not between 1 and 2000
  or v_schedule->>'text' ~ '<[/!]?[A-Za-z][^>]*>|[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]') then
  raise exception 'Invalid course schedule text.' using errcode='22023';
 end if;
 v_weekly:=v_schedule->'weekly';
 if v_weekly is not null and v_weekly<>'null'::jsonb then
  if v_start is null or v_end is null or v_schedule->>'timezone' is null or jsonb_typeof(v_weekly)<>'object'
   or v_weekly-array['days','start_time','end_time']<>'{}'::jsonb
   or jsonb_typeof(v_weekly->'days') is distinct from 'array'
   or v_weekly->>'start_time' is null or v_weekly->>'start_time' !~ '^([01]\d|2[0-3]):[0-5]\d$'
   or (v_weekly->>'end_time' is not null and (v_weekly->>'end_time' !~ '^([01]\d|2[0-3]):[0-5]\d$'
     or v_weekly->>'end_time'<=v_weekly->>'start_time')) then
   raise exception 'Invalid bounded weekly schedule.' using errcode='22023';
  end if;
  v_days:=v_weekly->'days';
  if jsonb_array_length(v_days) not between 1 and 7 or exists(select 1 from jsonb_array_elements(v_days) d
    where jsonb_typeof(d)<>'number' or d::text !~ '^[1-7]$')
   or (select count(distinct d) from jsonb_array_elements(v_days) d)<>jsonb_array_length(v_days) then
   raise exception 'Invalid weekly days.' using errcode='22023';
  end if;
 end if;
 if v_schedule ? 'exceptions' and v_schedule->'exceptions'<>'null'::jsonb then
  if jsonb_typeof(v_schedule->'exceptions')<>'array' or jsonb_array_length(v_schedule->'exceptions')>200 then
   raise exception 'Invalid course exceptions.' using errcode='22023';
  end if;
  for v_key in select value#>>'{}' from jsonb_array_elements(v_schedule->'exceptions') loop
   if v_start is null or v_end is null or v_key is null or v_key !~ '^\d{4}-\d{2}-\d{2}$'
    or v_key::date not between v_start and v_end then
    raise exception 'Invalid course exception date.' using errcode='22023';
   end if;
  end loop;
 end if;
end $$;

-- Dates are evaluated in the supplied course timezone; an unspecified season
-- timezone uses UTC only for season eligibility, never for inferred sessions.
create function private.external_course_current(p_content jsonb,p_now timestamptz)
returns boolean language sql stable set search_path='' as $$
 select coalesce((p_now at time zone coalesce(p_content->'schedule'->>'timezone','UTC'))::date
  between (p_content->'schedule'->>'season_start')::date and (p_content->'schedule'->>'season_end')::date,false)
$$;

create function private.external_catalogue_timing(p_content jsonb,p_as_of timestamptz,p_from date default null,p_to date default null)
returns table(next_at timestamptz,next_occurrence jsonb) language sql stable set search_path='' as $$
 with schedule as (select p_content->'schedule' as s),
 days as (
  select d::date as d,s from schedule cross join lateral generate_series(
   greatest((s->>'season_start')::date,(p_as_of at time zone coalesce(s->>'timezone','UTC'))::date-1)::timestamp,
   least((s->>'season_end')::date,(p_as_of at time zone coalesce(s->>'timezone','UTC'))::date+90)::timestamp,
   interval '1 day') d
  where s->'weekly' is not null and s->'weekly'<>'null'::jsonb
 ), weekly as (
  select (d+(s->'weekly'->>'start_time')::time) at time zone (s->>'timezone') as start_at,
   case when s->'weekly'->>'end_time' is not null then (d+(s->'weekly'->>'end_time')::time) at time zone (s->>'timezone') end as end_at,s,d
  from days where (s->'weekly'->'days') @> to_jsonb(extract(isodow from d)::integer)
   and not coalesce(s->'exceptions','[]'::jsonb) @> to_jsonb(d::text)
 ), occurrences as (
  select case when o->>'kind'='timed' then (o->>'start')::timestamptz
    else (o->>'start')::date::timestamp at time zone (o->>'timezone') end as start_at,
   case when o->>'kind'='timed' then coalesce((o->>'end')::timestamptz,(o->>'start')::timestamptz)
    else coalesce((o->>'end')::date,(o->>'start')::date+1)::timestamp at time zone (o->>'timezone') end as end_at,o
  from jsonb_array_elements(p_content->'occurrences') o
  where coalesce(p_content->>'kind','event')<>'course' or not coalesce(p_content->'schedule'->'exceptions','[]'::jsonb) @>
   to_jsonb((case when o->>'kind'='timed' then ((o->>'start')::timestamptz at time zone
    coalesce(p_content->'schedule'->>'timezone',o->>'timezone'))::date else (o->>'start')::date end)::text)
  union all
  select start_at,coalesce(end_at,start_at),jsonb_build_object('kind','timed',
   'start',to_char(start_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   'end',case when end_at is not null then to_char(end_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') end,
   'timezone',s->>'timezone')
  from weekly
  -- Skip nonexistent spring-forward wall clocks; ambiguous autumn times use
  -- PostgreSQL's standard-time interpretation. No nonexistent lesson is shifted.
  where start_at at time zone (s->>'timezone')=d+(s->'weekly'->>'start_time')::time
   and (end_at is null or end_at at time zone (s->>'timezone')=d+(s->'weekly'->>'end_time')::time)
 )
 select start_at,o from occurrences where (end_at>p_as_of or start_at=end_at and start_at>=p_as_of)
  and start_at<p_as_of+interval '2160 hours'
  and (p_from is null or end_at>p_from::timestamp at time zone (o->>'timezone')
   or start_at=end_at and start_at>=p_from::timestamp at time zone (o->>'timezone'))
  and (p_to is null or start_at<p_to::timestamp at time zone (o->>'timezone'))
 order by start_at,o::text limit 1
$$;

create function private.external_catalogue_rows(p_now timestamptz,p_as_of timestamptz,p_kind text,p_category text,p_from date,p_to date)
returns table(activity_id uuid,source_id text,content jsonb,next_at timestamptz,next_occurrence jsonb,sort_rank integer,sort_key text)
language sql stable set search_path='' as $$
 select a.activity_id,a.source_id,a.content,t.next_at,t.next_occurrence,
  case coalesce(a.content->>'kind','event') when 'event' then 0 when 'course' then case when t.next_at is null then 2 else 1 end else 3 end,
  case when t.next_at is not null then to_char(t.next_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US') else lower(a.content->>'title') end
 from private.external_activities a join private.external_activity_sources s using(source_id)
 left join lateral private.external_catalogue_timing(a.content,p_as_of,p_from,p_to) t on true
 where s.enabled and s.rights_confirmed and a.content->>'publishable'='true' and a.content->>'status'='scheduled'
  and a.last_observed_at>=p_now-case when a.content->>'kind'='place' then interval '30 days' else interval '14 days' end
  and (p_kind is null or coalesce(a.content->>'kind','event')=p_kind)
  and (p_category is null or a.content->>'category'=p_category)
  and case coalesce(a.content->>'kind','event') when 'place' then p_from is null
   when 'course' then private.external_course_current(a.content,p_as_of) and private.external_course_current(a.content,p_now)
    and (p_from is null or t.next_at is not null)
   else t.next_at is not null end
$$;

create function private.external_catalogue_payload(p_activity private.external_activities,p_source private.external_activity_sources,p_now timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select private.external_activity_payload(p_activity,p_source,p_now)||jsonb_build_object(
  'kind',coalesce(p_activity.content->>'kind','event'),
  'stale',p_activity.last_observed_at<p_now-case when p_activity.content->>'kind'='place' then interval '7 days' else interval '72 hours' end)
$$;

create function public.list_external_activities_v2(p_kind text default null,p_category text default null,p_query text default '',p_discipline text default null,p_from date default null,p_to date default null,p_limit integer default 20,p_cursor jsonb default null)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
declare
 v_now timestamptz:=statement_timestamp(); v_as_of timestamptz:=v_now;
 v_query text:=lower(btrim(coalesce(p_query,''))); v_versions jsonb; v_filters jsonb;
 v_items jsonb; v_cursor jsonb; v_facets jsonb; v_success timestamptz; v_failed boolean; v_state text;
begin
 if p_limit is null or p_limit not between 1 and 30 or length(v_query)>120
  or (p_kind is not null and p_kind not in ('event','course','place'))
  or (p_category is not null and p_category not in ('sports','culture','other'))
  or (p_discipline is not null and p_discipline !~ '^[a-z][a-z0-9-]{0,63}$')
  or (p_from is null)<>(p_to is null) or (p_from is not null and
   (not isfinite(p_from) or not isfinite(p_to) or p_to<=p_from or p_to-p_from>90)) then
  raise exception 'Invalid activity filters.' using errcode='22023';
 end if;
 select jsonb_agg(jsonb_build_array(source_id,catalogue_version) order by source_id),min(last_success_at),
  bool_or(last_attempt_state in ('failure','incomplete')) into v_versions,v_success,v_failed
 from private.external_activity_sources where enabled and rights_confirmed;
 v_filters:=jsonb_build_object('kind',p_kind,'category',p_category,'query',v_query,'discipline',p_discipline,'from',p_from,'to',p_to);
 if p_cursor is not null then
  if jsonb_typeof(p_cursor)<>'object' or octet_length(p_cursor::text)>8192
   or p_cursor->'versions' is distinct from v_versions or p_cursor->'filters' is distinct from v_filters
   or p_cursor->>'as_of' is null or p_cursor->>'rank' is null or p_cursor->>'key' is null or p_cursor->>'id' is null then
   raise exception 'Activity cursor requires refresh.' using errcode='22023';
  end if;
  v_as_of:=(p_cursor->>'as_of')::timestamptz;
  if not isfinite(v_as_of) or v_as_of>v_now or v_as_of<v_now-interval '30 minutes' then
   raise exception 'Activity cursor requires refresh.' using errcode='22023';
  end if;
 end if;
 with eligible as materialized (
  select * from private.external_catalogue_rows(v_now,v_as_of,p_kind,p_category,p_from,p_to)
 ), matches as (
  select * from eligible where
   (v_query='' or position(v_query in lower(concat_ws(' ',content->>'title',content->>'description',content->>'city',content->>'venue')))>0)
   and (p_discipline is null or content->>'discipline'=p_discipline)
   and (p_cursor is null or (sort_rank,sort_key,activity_id)>((p_cursor->>'rank')::integer,p_cursor->>'key',(p_cursor->>'id')::uuid))
  order by sort_rank,sort_key,activity_id limit p_limit+1
 ), page as (select * from matches order by sort_rank,sort_key,activity_id limit p_limit)
 select coalesce((select jsonb_agg(private.external_catalogue_payload(a,s,v_now)||jsonb_build_object('next_at',p.next_at,'next_occurrence',p.next_occurrence)
   order by p.sort_rank,p.sort_key,p.activity_id) from page p
   join private.external_activities a using(activity_id) join private.external_activity_sources s on s.source_id=a.source_id),'[]'::jsonb),
  case when (select count(*) from matches)>p_limit then (select jsonb_build_object('versions',v_versions,'filters',v_filters,'as_of',v_as_of,
   'rank',sort_rank,'key',sort_key,'id',activity_id) from page order by sort_rank desc,sort_key desc,activity_id desc limit 1) end,
  jsonb_build_object(
   'disciplines',coalesce((select jsonb_agg(d order by d) from (select distinct content->>'discipline' d from eligible where content->>'discipline' is not null) ds),'[]'::jsonb),
   'kinds',coalesce((select jsonb_agg(k order by k) from (select distinct coalesce(content->>'kind','event') k from eligible) ks),'[]'::jsonb),
   'categories',coalesce((select jsonb_agg(c order by c) from (select distinct content->>'category' c from eligible) cs),'[]'::jsonb))
 into v_items,v_cursor,v_facets;
 v_state:=case when v_versions is null then 'unconfigured'
  when v_failed then 'unavailable' when v_success is null then 'never_synchronized'
  when v_success<v_now-case when p_kind='place' then interval '7 days' else interval '72 hours' end
   or exists(select 1 from jsonb_array_elements(v_items) x where x->>'stale'='true') then 'stale'
  when v_items='[]'::jsonb then 'empty' else 'healthy' end;
 return jsonb_build_object('state',v_state,'as_of',v_as_of,'items',v_items,'next_cursor',v_cursor,
  'facets',v_facets,'disciplines',v_facets->'disciplines','last_success_at',v_success);
end $$;

create function public.get_external_activity_v2(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path='' set statement_timeout='10s' as $$
 select private.external_catalogue_payload(a,s,statement_timestamp())||jsonb_build_object('next_at',t.next_at,'next_occurrence',t.next_occurrence)
 from private.external_activities a join private.external_activity_sources s using(source_id)
 left join lateral private.external_catalogue_timing(a.content,statement_timestamp()) t on true
 where a.activity_id=p_activity_id and s.enabled and s.rights_confirmed
  and a.content->>'publishable'='true' and a.content->>'status'<>'unpublished'
  and a.last_observed_at>=statement_timestamp()-case when a.content->>'kind'='place' then interval '30 days' else interval '14 days' end
  and (coalesce(a.content->>'kind','event')<>'course' or private.external_course_current(a.content,statement_timestamp()))
$$;

revoke all on function private.validate_external_event_v1(jsonb,text),private.validate_external_activity(jsonb,text),
 private.external_course_current(jsonb,timestamptz),private.external_catalogue_timing(jsonb,timestamptz,date,date),
 private.external_catalogue_rows(timestamptz,timestamptz,text,text,date,date),
 private.external_catalogue_payload(private.external_activities,private.external_activity_sources,timestamptz)
 from public,anon,authenticated,service_role;
revoke all on function public.list_external_activities_v2(text,text,text,text,date,date,integer,jsonb),public.get_external_activity_v2(uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.list_external_activities_v2(text,text,text,text,date,date,integer,jsonb),public.get_external_activity_v2(uuid) to anon,authenticated;

comment on function public.list_external_activities_v2(text,text,text,text,date,date,integer,jsonb) is
 'ACTCAT02 catalogue: events, current finite-term courses, places. Event/course observation expires at 14 days; places warn at 7 and expire at 30. Date window is [from,to), max 90 days, excludes places. Ordering: events, timed courses, unknown-session courses, places; UUID breaks ties. Cursor binds filters, enabled-source versions and a 30-minute reference.';

-- Preserve both released V1 RPC signatures and their non-null event shape.
create or replace function public.list_external_activities(p_category text default null,p_query text default '',p_discipline text default null,p_limit integer default 20,p_cursor jsonb default null)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
declare v_source private.external_activity_sources%rowtype; v_now timestamptz:=statement_timestamp(); v_as_of timestamptz:=v_now;
 v_query text:=lower(btrim(coalesce(p_query,''))); v_after timestamptz; v_id uuid; v_items jsonb; v_cursor jsonb; v_disciplines jsonb; v_state text;
begin
 if p_limit is null or p_limit not between 1 and 30 or length(v_query)>120 or (p_category is not null and p_category not in ('sports','culture','other'))
  or (p_discipline is not null and p_discipline !~ '^[a-z][a-z0-9-]{0,63}$') then raise exception 'Invalid activity filters.' using errcode='22023'; end if;
 select * into v_source from private.external_activity_sources where enabled and rights_confirmed;
 if not found then return jsonb_build_object('state','unconfigured','as_of',v_now,'items','[]'::jsonb,'disciplines','[]'::jsonb,'next_cursor',null,'last_success_at',null); end if;
 if p_cursor is not null then
  if jsonb_typeof(p_cursor)<>'object' or octet_length(p_cursor::text)>2048
   or p_cursor->>'source_id' is distinct from v_source.source_id
   or p_cursor->>'version' is distinct from v_source.catalogue_version::text
   or p_cursor->>'category' is distinct from p_category or p_cursor->>'query' is distinct from v_query
   or p_cursor->>'discipline' is distinct from p_discipline then raise exception 'Activity cursor requires refresh.' using errcode='22023'; end if;
  v_as_of:=(p_cursor->>'as_of')::timestamptz; v_after:=(p_cursor->>'next_at')::timestamptz; v_id:=(p_cursor->>'id')::uuid;
  if v_as_of is null or v_after is null or v_id is null or v_as_of>v_now or v_as_of<v_now-interval '30 minutes' then raise exception 'Activity cursor requires refresh.' using errcode='22023'; end if;
 end if;
 with eligible as (
  select a.*,private.external_activity_next(a.activity_id,v_as_of) as next_at
  from private.external_activities a where a.source_id=v_source.source_id and a.last_observed_at>=v_now-interval '14 days'
   and coalesce(a.content->>'kind','event')='event' and a.content->>'description' is not null and a.content->>'publishable'='true' and a.content->>'status'='scheduled'
   and (p_category is null or a.content->>'category'=p_category)
 ), matches as (
  select * from eligible where next_at is not null
   and (v_query='' or position(v_query in lower(concat_ws(' ',content->>'title',content->>'description',content->>'city',content->>'venue')))>0)
   and (p_discipline is null or content->>'discipline'=p_discipline)
   and (v_after is null or (next_at,activity_id)>(v_after,v_id))
  order by next_at,activity_id limit p_limit+1
 ), page as (select * from matches order by next_at,activity_id limit p_limit)
 select coalesce((select jsonb_agg(private.external_activity_payload(a,v_source,v_now)||jsonb_build_object('next_at',p.next_at) order by p.next_at,p.activity_id) from page p join private.external_activities a using(activity_id)),'[]'::jsonb),
  (select jsonb_build_object('source_id',v_source.source_id,'version',v_source.catalogue_version,'as_of',v_as_of,'category',p_category,'query',v_query,'discipline',p_discipline,'next_at',next_at,'id',activity_id)
   from page order by next_at desc,activity_id desc limit 1),
  coalesce((select jsonb_agg(d order by d) from (select distinct content->>'discipline' as d from eligible where next_at is not null and content->>'discipline' is not null) ds),'[]'::jsonb)
 into v_items,v_cursor,v_disciplines;
 -- A full page gets a continuation only if the extra row exists.
 if jsonb_array_length(v_items)<p_limit or not exists(
  select 1 from private.external_activities a where a.source_id=v_source.source_id and a.last_observed_at>=v_now-interval '14 days'
   and coalesce(a.content->>'kind','event')='event' and a.content->>'description' is not null and a.content->>'publishable'='true' and a.content->>'status'='scheduled'
   and (p_category is null or a.content->>'category'=p_category)
   and (v_query='' or position(v_query in lower(concat_ws(' ',a.content->>'title',a.content->>'description',a.content->>'city',a.content->>'venue')))>0)
   and (p_discipline is null or a.content->>'discipline'=p_discipline)
   and (private.external_activity_next(a.activity_id,v_as_of),a.activity_id)>((v_cursor->>'next_at')::timestamptz,(v_cursor->>'id')::uuid)) then v_cursor:=null; end if;
 v_state:=case when v_source.last_success_at is null then case when v_source.last_attempt_state in ('failure','incomplete') then 'unavailable' else 'never_synchronized' end
  when v_source.last_attempt_state in ('failure','incomplete') then 'unavailable'
  when v_source.last_success_at<v_now-interval '72 hours' then 'stale'
  when v_items='[]'::jsonb then 'empty' else 'healthy' end;
 return jsonb_build_object('state',v_state,'as_of',v_as_of,'items',v_items,'disciplines',v_disciplines,'next_cursor',v_cursor,'last_success_at',v_source.last_success_at);
end $$;

create or replace function public.get_external_activity(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select private.external_activity_payload(a,s,statement_timestamp()) from private.external_activities a
 join private.external_activity_sources s using(source_id)
 where a.activity_id=p_activity_id and s.enabled and s.rights_confirmed
  and coalesce(a.content->>'kind','event')='event' and a.content->>'description' is not null and a.content->>'publishable'='true' and a.content->>'status'<>'unpublished'
  and a.last_observed_at>=statement_timestamp()-interval '14 days'
$$;
