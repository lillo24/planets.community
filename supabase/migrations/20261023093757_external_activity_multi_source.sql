-- ACTSRC02: independent sources; no source is seeded or enabled.
drop index private.external_activity_one_enabled_source;

create function private.external_source_origins_valid(p_origins text[])
returns boolean language sql immutable set search_path='' as $$
 select cardinality(p_origins) between 0 and 4
  and not exists(select 1 from unnest(p_origins) u where u is null
    or not private.activity_public_https_url(u) or u ~ '/$'
    or position('/' in substring(u from 9))<>0)
  and cardinality(p_origins)=(select count(distinct u) from unnest(p_origins) u)
$$;
alter table private.external_activity_sources
 add column public_link_origins text[] not null default '{}' check(private.external_source_origins_valid(public_link_origins)),
 add column supported_kinds text[] not null default array['event','course','place']
  check(cardinality(supported_kinds) between 1 and 3 and supported_kinds <@ array['event','course','place']::text[] and array_position(supported_kinds,null) is null);

create function private.external_source_configuration_version()
returns trigger language plpgsql set search_path='' as $$
begin
 if (new.enabled,new.rights_confirmed,new.official_origin,new.public_link_origins,
     new.supported_kinds,new.display_name,new.attribution,new.license_url)
  is distinct from (old.enabled,old.rights_confirmed,old.official_origin,old.public_link_origins,
     old.supported_kinds,old.display_name,old.attribution,old.license_url) then
  new.catalogue_version:=old.catalogue_version+1;
 end if;
 return new;
end $$;
create trigger external_source_configuration_version before update on private.external_activity_sources
 for each row execute function private.external_source_configuration_version();

create function private.validate_external_activity_source(p_record jsonb,p_source private.external_activity_sources)
returns void language plpgsql set search_path='' as $$
declare v_url text; v_validation jsonb;
begin
 if coalesce(p_record->>'kind','event')<>all(p_source.supported_kinds)
  or (p_record ? 'link_scope' and (jsonb_typeof(p_record->'link_scope') is distinct from 'string'
    or p_record->>'link_scope' not in ('item','dataset'))) then
  raise exception 'Invalid source capability or link scope.' using errcode='22023';
 end if;
 if p_record->>'canonical_url' is null then raise exception 'Invalid source public link.' using errcode='22023'; end if;
 foreach v_url in array array[p_record->>'canonical_url',p_record->'geometry'->>'provenance_url'] loop
  if v_url is not null and (not private.activity_public_https_url(v_url) or not exists(
    select 1 from unnest(array[p_source.official_origin]||p_source.public_link_origins) o
     where left(v_url,length(o)+1)=o||'/')) then
   raise exception 'Invalid source public link.' using errcode='22023';
  end if;
 end loop;
 -- Validate all existing bounded fields/rules with the proven validator. Actual
 -- links above are checked separately against this source's owner-only policy.
 v_validation:=(p_record-'link_scope')||jsonb_build_object('canonical_url',p_source.official_origin||'/validation-only');
 if p_record->'geometry' is not null and p_record->'geometry'<>'null'::jsonb then
  v_validation:=v_validation||jsonb_build_object('geometry',p_record->'geometry'||
   jsonb_build_object('provenance_url',p_source.official_origin||'/validation-only'));
 end if;
 perform private.validate_external_activity(v_validation,p_source.official_origin);
end $$;

create or replace function public.finish_external_activity_import(p_run_id uuid,p_state text,p_records jsonb default '[]',p_fetched integer default 0,p_rejected integer default 0,p_error_code text default null)
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
  for v_record in select value from jsonb_array_elements(p_records) loop perform private.validate_external_activity_source(v_record,v_source); end loop;
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

create or replace function private.external_activity_payload(p_activity private.external_activities,p_source private.external_activity_sources,p_now timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select (p_activity.content-array['upstream_id','publishable','kind','schedule','geometry','level','access','link_scope'])||jsonb_build_object(
  'id',p_activity.activity_id,'revision',p_activity.revision,'observed_at',p_activity.last_observed_at,
  'stale',p_activity.last_observed_at<p_now-interval '72 hours',
  'source',jsonb_build_object('id',p_source.source_id,'name',p_source.display_name,'attribution',p_source.attribution,'license_url',p_source.license_url))
$$;
create or replace function private.external_catalogue_payload(p_activity private.external_activities,p_source private.external_activity_sources,p_now timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select private.external_activity_payload(p_activity,p_source,p_now)||jsonb_build_object(
  'kind',coalesce(p_activity.content->>'kind','event'),'schedule',p_activity.content->'schedule',
  'geometry',p_activity.content->'geometry','level',p_activity.content->'level','access',p_activity.content->'access',
  'link_scope',coalesce(p_activity.content->>'link_scope','item'),
  'stale',p_activity.last_observed_at<p_now-case when p_activity.content->>'kind'='place' then interval '7 days' else interval '72 hours' end)
$$;
create or replace function public.list_external_activities_v2(p_kind text default null,p_category text default null,p_query text default '',p_discipline text default null,p_from date default null,p_to date default null,p_limit integer default 20,p_cursor jsonb default null)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
declare
 v_now timestamptz:=statement_timestamp(); v_as_of timestamptz:=v_now;
 v_query text:=lower(btrim(coalesce(p_query,''))); v_versions jsonb; v_filters jsonb;
 v_items jsonb; v_cursor jsonb; v_facets jsonb; v_success timestamptz; v_failed boolean; v_state text; v_sources jsonb; v_ok integer; v_never integer;
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
  bool_or(last_attempt_state in ('failure','incomplete')),
  count(*) filter(where last_success_at is not null and last_attempt_state not in ('failure','incomplete')),
  count(*) filter(where last_success_at is null),
  jsonb_build_object('configured',count(*),'failed',count(*) filter(where last_attempt_state in ('failure','incomplete')),'pending',count(*) filter(where last_success_at is null))
 into v_versions,v_success,v_failed,v_ok,v_never,v_sources
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
  when (v_failed or v_never>0) and v_ok>0 then 'partial'
  when v_failed then 'unavailable' when v_success is null then 'never_synchronized'
  when v_success<v_now-case when p_kind='place' then interval '7 days' else interval '72 hours' end
   or exists(select 1 from jsonb_array_elements(v_items) x where x->>'stale'='true') then 'stale'
  when v_items='[]'::jsonb then 'empty' else 'healthy' end;
 return jsonb_build_object('state',v_state,'as_of',v_as_of,'items',v_items,'next_cursor',v_cursor,
  'facets',v_facets,'disciplines',v_facets->'disciplines','last_success_at',v_success,'sources',v_sources);
end $$;

create or replace function public.list_external_activities(p_category text default null,p_query text default '',p_discipline text default null,p_limit integer default 20,p_cursor jsonb default null)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
declare
 p_kind text:='event'; p_from date; p_to date;
 v_now timestamptz:=statement_timestamp(); v_as_of timestamptz:=v_now;
 v_query text:=lower(btrim(coalesce(p_query,''))); v_versions jsonb; v_filters jsonb;
 v_items jsonb; v_cursor jsonb; v_facets jsonb; v_success timestamptz; v_failed boolean; v_state text; v_ok integer; v_never integer;
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
  bool_or(last_attempt_state in ('failure','incomplete')),
  count(*) filter(where last_success_at is not null and last_attempt_state not in ('failure','incomplete')),
  count(*) filter(where last_success_at is null)
 into v_versions,v_success,v_failed,v_ok,v_never
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
  select * from private.external_catalogue_rows(v_now,v_as_of,p_kind,p_category,p_from,p_to) where content->>'description' is not null
 ), matches as (
  select * from eligible where
   (v_query='' or position(v_query in lower(concat_ws(' ',content->>'title',content->>'description',content->>'city',content->>'venue')))>0)
   and (p_discipline is null or content->>'discipline'=p_discipline)
   and (p_cursor is null or (sort_rank,sort_key,activity_id)>((p_cursor->>'rank')::integer,p_cursor->>'key',(p_cursor->>'id')::uuid))
  order by sort_rank,sort_key,activity_id limit p_limit+1
 ), page as (select * from matches order by sort_rank,sort_key,activity_id limit p_limit)
 select coalesce((select jsonb_agg(private.external_activity_payload(a,s,v_now)||jsonb_build_object('next_at',p.next_at)
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
  when (v_failed or v_never>0) and v_ok>0 then 'unavailable'
  when v_failed then 'unavailable' when v_success is null then 'never_synchronized'
  when v_success<v_now-case when p_kind='place' then interval '7 days' else interval '72 hours' end
   or exists(select 1 from jsonb_array_elements(v_items) x where x->>'stale'='true') then 'stale'
  when v_items='[]'::jsonb then 'empty' else 'healthy' end;
 return jsonb_build_object('state',v_state,'as_of',v_as_of,'items',v_items,'next_cursor',v_cursor,
  'disciplines',v_facets->'disciplines','last_success_at',v_success);
end $$;

revoke all on function private.external_source_origins_valid(text[]),
 private.external_source_configuration_version(),
 private.validate_external_activity_source(jsonb,private.external_activity_sources)
 from public,anon,authenticated,service_role;
comment on table private.external_activity_sources is
 'ACTSRC02 database-owner-only per-source rights, enabled state, public-link origins and capabilities. No source is seeded/enabled; import credentials cannot configure sources. API fetch destinations are separately code-owned.';
comment on function public.list_external_activities_v2(text,text,text,text,date,date,integer,jsonb) is
 'ACTSRC02 cross-source V2. Complete filters/source versions bind cursors; config changes increment versions. Sanitized partial health retains healthy records. No upstream IO. V1 remains event-only and uses legacy unavailable for partial health.';
