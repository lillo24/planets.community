-- External activities have no native Project/Profile/membership identity.
-- No source is seeded: rights confirmation and publication are operator-owned.
create function private.activity_public_https_url(p_url text)
returns boolean language sql immutable set search_path='' as $$
 select p_url is not null and length(p_url)<=2048
  and p_url ~ '^https://[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(/[^[:space:]<>]*)?$'
  and p_url !~ '[[:cntrl:]]' and p_url !~* '^https://[^/]*\.(localhost|local|internal)(/|$)'
$$;

create table private.external_activity_sources (
 source_id text primary key check(source_id ~ '^[a-z][a-z0-9-]{0,63}$'),
 display_name text not null check(length(display_name) between 1 and 200),
 official_origin text not null check(private.activity_public_https_url(official_origin) and official_origin !~ '/$' and position('/' in substring(official_origin from 9))=0),
 enabled boolean not null default false,
 rights_confirmed boolean not null default false,
 attribution text check(length(attribution) between 1 and 1000),
 license_url text check(license_url is null or private.activity_public_https_url(license_url)),
 catalogue_version bigint not null default 0,
 last_success_at timestamptz,
 last_attempt_state text check(last_attempt_state in ('running','success','incomplete','failure')),
 lease_token uuid,
 lease_expires_at timestamptz,
 check(not enabled or (rights_confirmed and attribution is not null and license_url is not null)),
 check((lease_token is null)=(lease_expires_at is null))
);
-- The MVP intentionally supports only one active source, not aggregation.
create unique index external_activity_one_enabled_source on private.external_activity_sources(enabled) where enabled;

create table private.external_activity_runs (
 run_id uuid primary key default gen_random_uuid(),
 source_id text not null references private.external_activity_sources(source_id),
 started_at timestamptz not null,
 finished_at timestamptz,
 state text not null default 'running' check(state in ('running','success','incomplete','failure')),
 fetched_count integer not null default 0 check(fetched_count between 0 and 2000),
 accepted_count integer not null default 0 check(accepted_count between 0 and 2000),
 rejected_count integer not null default 0 check(rejected_count between 0 and 2000),
 changed_count integer not null default 0 check(changed_count between 0 and 2000),
 error_code text check(error_code in ('upstream_error','invalid_payload','limit_exceeded','transport_error','deadline','lease_expired','internal_error')),
 check((state='running')=(finished_at is null))
);
create index external_activity_runs_retention on private.external_activity_runs(started_at);

create table private.external_activities (
 activity_id uuid primary key default gen_random_uuid(),
 source_id text not null references private.external_activity_sources(source_id),
 upstream_id text not null check(length(upstream_id) between 1 and 200),
 content jsonb not null,
 content_hash text not null,
 revision bigint not null default 1,
 last_observed_at timestamptz not null,
 unique(source_id,upstream_id)
);
create index external_activities_source_observed on private.external_activities(source_id,last_observed_at);
create table private.external_activity_occurrences (
 activity_id uuid not null references private.external_activities(activity_id) on delete cascade,
 ordinal integer not null check(ordinal between 1 and 200),
 -- These instants are internal ordering/overlap keys. Date-only public values
 -- stay dates in content; their internal midnight is never an appointment.
 starts_at timestamptz not null check(isfinite(starts_at)),
 ends_at timestamptz not null check(isfinite(ends_at)),
 primary key(activity_id,ordinal),
 check(ends_at>=starts_at)
);
alter table private.external_activity_sources enable row level security;
alter table private.external_activity_runs enable row level security;
alter table private.external_activities enable row level security;
alter table private.external_activity_occurrences enable row level security;
revoke all on private.external_activity_sources,private.external_activity_runs,
 private.external_activities,private.external_activity_occurrences from public,anon,authenticated,service_role;

create function private.validate_external_activity(p_record jsonb,p_origin text)
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

create function public.begin_external_activity_import(p_source_id text)
returns jsonb language plpgsql security definer set search_path='' set lock_timeout='5s' as $$
declare v_source private.external_activity_sources%rowtype; v_token uuid:=gen_random_uuid(); v_now timestamptz:=clock_timestamp();
begin
 select * into v_source from private.external_activity_sources where source_id=p_source_id for update;
 v_now:=clock_timestamp();
 if not found or not v_source.enabled or not v_source.rights_confirmed then raise exception 'Activity source is not enabled and licensed.' using errcode='55000'; end if;
 if v_source.lease_expires_at>v_now then raise exception 'Activity import already running.' using errcode='55P03'; end if;
 -- A bounded lease fences late completions and requires no managed scheduler.
 update private.external_activity_runs set state='incomplete',finished_at=v_now,error_code='lease_expired'
  where run_id=v_source.lease_token and state='running';
 delete from private.external_activity_runs where started_at<v_now-interval '30 days' and state<>'running';
 insert into private.external_activity_runs(run_id,source_id,started_at) values(v_token,p_source_id,v_now);
 update private.external_activity_sources set lease_token=v_token,lease_expires_at=v_now+interval '10 minutes',last_attempt_state='running' where source_id=p_source_id;
 return jsonb_build_object('run_id',v_token,'started_at',v_now,'lease_expires_at',v_now+interval '10 minutes');
end $$;

create function public.finish_external_activity_import(p_run_id uuid,p_state text,p_records jsonb default '[]',p_fetched integer default 0,p_rejected integer default 0,p_error_code text default null)
returns jsonb language plpgsql security definer set search_path='' set statement_timeout='30s' set lock_timeout='5s' as $$
declare v_source private.external_activity_sources%rowtype; v_run private.external_activity_runs%rowtype;
 v_record jsonb; v_occ jsonb; v_id uuid; v_old_hash text; v_hash text; v_ordinal integer;
 v_start timestamptz; v_end timestamptz; v_changed integer:=0; v_count integer; v_now timestamptz:=clock_timestamp();
begin
 select * into v_source from private.external_activity_sources where source_id=(select source_id from private.external_activity_runs where run_id=p_run_id) for update;
 v_now:=clock_timestamp();
 select * into v_run from private.external_activity_runs where run_id=p_run_id;
 if v_run.run_id is null or v_source.lease_token is distinct from p_run_id or v_source.lease_expires_at<=v_now or v_run.state<>'running' then
  raise exception 'Obsolete activity import completion.' using errcode='40001';
 end if;
 if p_state is null or p_state not in ('success','incomplete','failure') or p_fetched is null or p_rejected is null
  or p_fetched not between 0 and 2000 or p_rejected not between 0 and p_fetched
  or jsonb_typeof(p_records) is distinct from 'array' or octet_length(p_records::text)>10485760 then
  raise exception 'Invalid import completion.' using errcode='22023';
 end if;
 v_count:=jsonb_array_length(p_records);
 if p_state='success' then
  if not v_source.enabled or not v_source.rights_confirmed then raise exception 'Activity source disabled.' using errcode='55000'; end if;
  if p_error_code is not null or v_count+p_rejected<>p_fetched or v_count>2000
   or (select count(distinct value->>'upstream_id') from jsonb_array_elements(p_records))<>v_count then raise exception 'Invalid complete snapshot.' using errcode='22023'; end if;
  -- Validate the whole batch before touching any catalogue/occurrence state.
  for v_record in select value from jsonb_array_elements(p_records) loop perform private.validate_external_activity(v_record,v_source.official_origin); end loop;
  for v_record in select value from jsonb_array_elements(p_records) loop
   v_id:=null; v_old_hash:=null;
   v_hash:=md5(v_record::text);
   select activity_id,content_hash into v_id,v_old_hash from private.external_activities where source_id=v_source.source_id and upstream_id=v_record->>'upstream_id';
   if v_id is null then
    insert into private.external_activities(source_id,upstream_id,content,content_hash,last_observed_at)
     values(v_source.source_id,v_record->>'upstream_id',v_record,v_hash,v_run.started_at) returning activity_id into v_id;
   else
    update private.external_activities set content=v_record,content_hash=v_hash,last_observed_at=v_run.started_at,
     revision=revision+case when content_hash<>v_hash then 1 else 0 end where activity_id=v_id;
   end if;
   if v_old_hash is distinct from v_hash then
    v_changed:=v_changed+1;
    delete from private.external_activity_occurrences where activity_id=v_id;
    v_ordinal:=0;
    for v_occ in select value from jsonb_array_elements(v_record->'occurrences') loop
     v_ordinal:=v_ordinal+1;
     if v_occ->>'kind'='timed' then
      v_start:=(v_occ->>'start')::timestamptz; v_end:=coalesce((v_occ->>'end')::timestamptz,v_start);
     else
      v_start:=(v_occ->>'start')::date::timestamp at time zone (v_occ->>'timezone');
      v_end:=coalesce((v_occ->>'end')::date,(v_occ->>'start')::date+1)::timestamp at time zone (v_occ->>'timezone');
     end if;
     insert into private.external_activity_occurrences values(v_id,v_ordinal,v_start,v_end);
    end loop;
   end if;
  end loop;
  update private.external_activity_sources set last_success_at=v_run.started_at,catalogue_version=catalogue_version+1 where source_id=v_source.source_id;
 else
  if v_count<>0 or p_error_code is null then raise exception 'Failed imports cannot carry catalogue writes.' using errcode='22023'; end if;
 end if;
 update private.external_activity_runs set state=p_state,finished_at=v_now,fetched_count=p_fetched,accepted_count=v_count,rejected_count=p_rejected,changed_count=v_changed,error_code=p_error_code where run_id=p_run_id;
 update private.external_activity_sources set lease_token=null,lease_expires_at=null,last_attempt_state=p_state where source_id=v_source.source_id;
 return jsonb_build_object('state',p_state,'fetched',p_fetched,'accepted',v_count,'rejected',p_rejected,'changed',v_changed);
end $$;

create function private.external_activity_payload(p_activity private.external_activities,p_source private.external_activity_sources,p_now timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select (p_activity.content-array['upstream_id','publishable'])||jsonb_build_object(
  'id',p_activity.activity_id,'revision',p_activity.revision,'observed_at',p_activity.last_observed_at,
  'stale',p_activity.last_observed_at<p_now-interval '72 hours',
  'source',jsonb_build_object('id',p_source.source_id,'name',p_source.display_name,'attribution',p_source.attribution,'license_url',p_source.license_url))
$$;
create function private.external_activity_next(p_id uuid,p_as_of timestamptz)
returns timestamptz language sql stable set search_path='' as $$
 select min(starts_at) from private.external_activity_occurrences
 where activity_id=p_id and (ends_at>p_as_of or starts_at=ends_at and starts_at>=p_as_of)
  and starts_at<p_as_of+interval '2160 hours'
$$;

create function public.list_external_activities(p_category text default null,p_query text default '',p_discipline text default null,p_limit integer default 20,p_cursor jsonb default null)
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
   and a.content->>'publishable'='true' and a.content->>'status'='scheduled'
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
   and a.content->>'publishable'='true' and a.content->>'status'='scheduled'
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

create function public.get_external_activity(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select private.external_activity_payload(a,s,statement_timestamp()) from private.external_activities a
 join private.external_activity_sources s using(source_id)
 where a.activity_id=p_activity_id and s.enabled and s.rights_confirmed
  and a.content->>'publishable'='true' and a.content->>'status'<>'unpublished'
  and a.last_observed_at>=statement_timestamp()-interval '14 days'
$$;

revoke all on function private.activity_public_https_url(text),private.validate_external_activity(jsonb,text),
 private.external_activity_payload(private.external_activities,private.external_activity_sources,timestamptz),
 private.external_activity_next(uuid,timestamptz) from public,anon,authenticated,service_role;
revoke all on function public.begin_external_activity_import(text),public.finish_external_activity_import(uuid,text,jsonb,integer,integer,text),
 public.list_external_activities(text,text,text,integer,jsonb),public.get_external_activity(uuid) from public,anon,authenticated,service_role;
grant execute on function public.begin_external_activity_import(text),public.finish_external_activity_import(uuid,text,jsonb,integer,integer,text) to service_role;
grant execute on function public.list_external_activities(text,text,text,integer,jsonb),public.get_external_activity(uuid) to anon,authenticated;

comment on function public.list_external_activities(text,text,text,integer,jsonb) is 'Licensed enabled external catalogue only. Cursor binds all filters, source version and a 30-minute occurrence reference. Current disable and 14-day per-record observation expiry apply on every page.';
comment on table private.external_activity_sources is 'Database-owner configuration. No seeded/enabled source. Rights confirmation and attribution/license are independent from importer credentials. One enabled source for ACTAPI01.';
