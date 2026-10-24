-- RADAR01: private bounded evidence; owner-only policy; no source activation.
alter table private.external_activities add column radar_identity_seen_at timestamptz not null default clock_timestamp();
create index external_radar_official_identity on private.external_activities((content->>'canonical_url')) where content->>'publishable'='true';
alter table private.external_activity_sources
 add column radar_collection_enabled boolean not null default false,
 add column radar_parser_version text check(radar_parser_version is null or radar_parser_version ~ '^[a-z0-9-]{1,100}$'),
 add column radar_parser_qualified boolean not null default false,
 add column radar_qualified_parser_version text,
 add column radar_policy_revision text check(radar_policy_revision is null or radar_policy_revision ~ '^[a-f0-9]{64}$'),
 add column radar_qualified_policy_revision text,
 add column radar_facts_reuse boolean not null default false,
 add column radar_prose_reuse boolean not null default false,
 add column radar_policy_url text check(radar_policy_url is null or private.activity_public_https_url(radar_policy_url));

create table private.external_radar_runs (
 run_id uuid primary key references private.external_activity_runs(run_id) on delete cascade,
 source_id text not null references private.external_activity_sources(source_id),
 parser_version text not null,
 source_version bigint not null,
 started_at timestamptz not null default clock_timestamp(),
 finished_at timestamptz,
 state text not null default 'running' check(state in ('running','success','held','failure')),
 collected integer not null default 0,
 publishable integer not null default 0,
 error_code text,
 check((state='running')=(finished_at is null))
);
create index external_radar_runs_source on private.external_radar_runs(source_id,started_at desc);
create table private.external_radar_candidates (
 source_id text not null references private.external_activity_sources(source_id),
 upstream_id text not null check(length(upstream_id) between 1 and 200),
 revision_digest text not null,
 parser_version text not null,
 title text check(length(title)<=300),
 record jsonb,
 evidence jsonb not null check(octet_length(evidence::text)<=8192),
 published_at timestamptz,
 reason text,
 review text check(review in ('rejected')),
 first_observed_at timestamptz not null,
 last_observed_at timestamptz not null,
 primary key(source_id,upstream_id,revision_digest)
);
create index external_radar_candidates_latest on private.external_radar_candidates(source_id,upstream_id,last_observed_at desc);
create table private.external_radar_documents (
 source_id text not null references private.external_activity_sources(source_id),
 url text not null check(private.activity_public_https_url(url)),
 representation jsonb not null check(octet_length(representation::text)<=2097152),
 fetched_at timestamptz not null,
 primary key(source_id,url)
);
create table private.external_activity_aliases (
 alias_id uuid primary key references private.external_activities(activity_id),
 canonical_id uuid not null references private.external_activities(activity_id),
 evidence_url text not null check(private.activity_public_https_url(evidence_url)),
 source_correction boolean not null default false,
 check(alias_id<>canonical_id)
);
create index external_activity_aliases_canonical on private.external_activity_aliases(canonical_id);
alter table private.external_radar_runs enable row level security;
alter table private.external_radar_candidates enable row level security;
alter table private.external_radar_documents enable row level security;
alter table private.external_activity_aliases enable row level security;
revoke all on private.external_radar_runs,private.external_radar_candidates,private.external_radar_documents,private.external_activity_aliases from public,anon,authenticated,service_role;

create or replace function private.external_source_configuration_version()
returns trigger language plpgsql set search_path='' as $$
begin
 if (new.enabled,new.rights_confirmed,new.official_origin,new.public_link_origins,
     new.supported_kinds,new.display_name,new.attribution,new.license_url,
     new.radar_collection_enabled,new.radar_parser_version,new.radar_parser_qualified,
     new.radar_facts_reuse,new.radar_prose_reuse,new.radar_policy_url,new.radar_policy_revision,new.radar_qualified_parser_version,new.radar_qualified_policy_revision)
  is distinct from (old.enabled,old.rights_confirmed,old.official_origin,old.public_link_origins,
     old.supported_kinds,old.display_name,old.attribution,old.license_url,
     old.radar_collection_enabled,old.radar_parser_version,old.radar_parser_qualified,
     old.radar_facts_reuse,old.radar_prose_reuse,old.radar_policy_url,old.radar_policy_revision,old.radar_qualified_parser_version,old.radar_qualified_policy_revision) then
  new.catalogue_version:=old.catalogue_version+1;
 end if;
 return new;
end $$;

create function private.external_radar_source_ready(p_source private.external_activity_sources)
returns boolean language sql stable set search_path='' as $$
 select p_source.enabled and p_source.rights_confirmed and
  ((p_source.radar_parser_version is null and not p_source.radar_collection_enabled and p_source.radar_qualified_parser_version is null and p_source.radar_policy_revision is null and p_source.radar_qualified_policy_revision is null) or
   (p_source.radar_collection_enabled and p_source.radar_parser_qualified and p_source.radar_facts_reuse and p_source.radar_policy_url is not null
    and p_source.radar_qualified_parser_version=p_source.radar_parser_version and p_source.radar_policy_revision is not null
    and p_source.radar_qualified_policy_revision=p_source.radar_policy_revision)) is true
$$;

-- Exact aliases require the same official item URL AND exact schedule/place
-- facts. Neither title resemblance nor another source's freshness is evidence.
create function private.external_radar_resolve_id(p_id uuid)
returns uuid language sql stable set search_path='' as $$
 select case when x.alias_id is null then a.activity_id
   when private.external_radar_source_ready(cs) and ((x.source_correction and c.source_id=a.source_id) or (c.content->>'canonical_url'=x.evidence_url
     and (c.content->'occurrences',c.content->'schedule',c.content->'venue',c.content->'city',c.content->'geometry',c.content->'status')
      is not distinct from (a.content->'occurrences',a.content->'schedule',a.content->'venue',a.content->'city',a.content->'geometry',a.content->'status'))) then x.canonical_id end
 from private.external_activities a join private.external_activity_sources s using(source_id)
 left join private.external_activity_aliases x on x.alias_id=a.activity_id
 left join private.external_activities c on c.activity_id=x.canonical_id
 left join private.external_activity_sources cs on cs.source_id=c.source_id
 where a.activity_id=p_id and private.external_radar_source_ready(s)
$$;

create function public.begin_external_radar_collection(p_source_id text,p_parser_version text)
returns jsonb language plpgsql security definer set search_path='' set statement_timeout='10s' set lock_timeout='5s' as $$
declare s private.external_activity_sources%rowtype; r uuid; t timestamptz:=clock_timestamp(); docs jsonb;
begin
 select * into s from private.external_activity_sources where source_id=p_source_id for update;
 if not found or not s.radar_collection_enabled or s.radar_parser_version is distinct from p_parser_version then
  raise exception 'Collection source/parser not approved.' using errcode='55000'; end if;
 if s.lease_token is not null and s.lease_expires_at>t then raise exception 'Source collection already running.' using errcode='55P03'; end if;
 if s.lease_token is not null then
  update private.external_activity_runs set state='incomplete',finished_at=t,error_code='lease_expired' where run_id=s.lease_token and state='running';
  update private.external_radar_runs set state='failure',finished_at=t,error_code='lease_expired' where run_id=s.lease_token and state='running';
 end if;
 insert into private.external_activity_runs(source_id,started_at) values(p_source_id,t) returning run_id into r;
 insert into private.external_radar_runs(run_id,source_id,parser_version,source_version,started_at) values(r,p_source_id,p_parser_version,s.catalogue_version,t);
 update private.external_activity_sources set lease_token=r,lease_expires_at=t+interval '10 minutes' where source_id=p_source_id;
 select coalesce(jsonb_agg(representation order by url),'[]'::jsonb) into docs from private.external_radar_documents
  where source_id=p_source_id and fetched_at>t-interval '7 days' and representation->>'parser_version'=p_parser_version;
 return jsonb_build_object('run_id',r,'started_at',t,'documents',docs);
end $$;

create function public.fail_external_radar_collection(p_run_id uuid,p_error_code text)
returns void language plpgsql security definer set search_path='' set statement_timeout='10s' set lock_timeout='5s' as $$
declare s private.external_activity_sources%rowtype; t timestamptz:=clock_timestamp();
begin
 if p_error_code not in ('deadline','collection_failed') then raise exception 'Invalid collection failure.' using errcode='22023'; end if;
 select * into s from private.external_activity_sources where source_id=(select source_id from private.external_radar_runs where run_id=p_run_id) for update;
 if s.lease_token is distinct from p_run_id then raise exception 'Obsolete collection.' using errcode='40001'; end if;
 update private.external_radar_runs set state='failure',finished_at=t,error_code=p_error_code where run_id=p_run_id and state='running';
 update private.external_activity_runs set state='failure',finished_at=t,error_code=case when p_error_code='deadline' then 'deadline' else 'invalid_payload' end where run_id=p_run_id and state='running';
 update private.external_activity_sources set lease_token=null,lease_expires_at=null,last_attempt_state='failure' where source_id=s.source_id;
end $$;

create function public.finish_external_radar_collection(p_run_id uuid,p_candidates jsonb,p_documents jsonb)
returns jsonb language plpgsql security definer set search_path='' set statement_timeout='30s' set lock_timeout='5s' as $$
declare s private.external_activity_sources%rowtype; r private.external_radar_runs%rowtype;
 c jsonb; d jsonb; v_record jsonb; v_records jsonb:='[]'::jsonb; v_digest text; v_result jsonb;
 v_count integer; v_publishable integer:=0; v_reasons jsonb:='[]'::jsonb; t timestamptz:=clock_timestamp();
begin
 select * into s from private.external_activity_sources where source_id=(select source_id from private.external_radar_runs where run_id=p_run_id) for update;
 select * into r from private.external_radar_runs where run_id=p_run_id;
 if r.run_id is null or r.state<>'running' or s.lease_token is distinct from p_run_id or s.lease_expires_at<=t then raise exception 'Obsolete collection.' using errcode='40001'; end if;
 if jsonb_typeof(p_candidates) is distinct from 'array' or jsonb_array_length(p_candidates)>2000 or octet_length(p_candidates::text)>8388608
  or jsonb_typeof(p_documents) is distinct from 'array' or jsonb_array_length(p_documents)>64 or octet_length(p_documents::text)>8388608 then
  raise exception 'Collection exceeds bounded contract.' using errcode='22023'; end if;
 v_count:=jsonb_array_length(p_candidates);
 if (select count(distinct value->>'upstream_id') from jsonb_array_elements(p_candidates))<>v_count then raise exception 'Duplicate collection identity.' using errcode='22023'; end if;
 if not s.enabled then v_reasons:=v_reasons||'"public_disabled"'::jsonb; end if;
 if not s.rights_confirmed or not s.radar_facts_reuse or s.radar_policy_url is null or s.radar_policy_revision is null or s.radar_qualified_policy_revision is distinct from s.radar_policy_revision then v_reasons:=v_reasons||'"rights_held"'::jsonb; end if;
 if not s.radar_parser_qualified or s.radar_parser_version<>r.parser_version or s.radar_qualified_parser_version is distinct from r.parser_version then v_reasons:=v_reasons||'"parser_unqualified"'::jsonb; end if;
 if not s.radar_collection_enabled or s.catalogue_version<>r.source_version then v_reasons:=v_reasons||'"source_configuration_changed"'::jsonb; end if;
 for c in select value from jsonb_array_elements(p_candidates) loop
  if c-array['upstream_id','title','record','evidence','published_at','reason']<>'{}'::jsonb
   or jsonb_typeof(c->'evidence') is distinct from 'object' or (c->'evidence')-array['url','content_digest','parser_version','fetched_at','fields']<>'{}'::jsonb
   or not private.activity_public_https_url(c->'evidence'->>'url')
   or left(c->'evidence'->>'url',length(s.official_origin)+1)<>s.official_origin||'/'
   or c->'evidence'->>'parser_version' is distinct from r.parser_version
   or coalesce(c->'evidence'->>'content_digest','') !~ '^[a-f0-9]{64}$' or jsonb_typeof(c->'evidence'->'fields') is distinct from 'object'
   or length(c->>'reason')>100 then raise exception 'Invalid bounded candidate evidence.' using errcode='22023'; end if;
  v_record:=nullif(c->'record','null'::jsonb);
  if v_record is not null then
   if not s.radar_prose_reuse and v_record->>'description' is not null then raise exception 'Prose reuse not approved.' using errcode='22023'; end if;
   perform private.validate_external_activity_source(v_record,s);
  end if;
  v_digest:=encode(extensions.digest((jsonb_build_object('record',v_record,'reason',c->>'reason','parser',r.parser_version))::text,'sha256'),'hex');
  insert into private.external_radar_candidates(source_id,upstream_id,revision_digest,parser_version,title,record,evidence,published_at,reason,first_observed_at,last_observed_at)
   values(s.source_id,c->>'upstream_id',v_digest,r.parser_version,c->>'title',v_record,c->'evidence',(c->>'published_at')::timestamptz,c->>'reason',r.started_at,r.started_at)
   on conflict(source_id,upstream_id,revision_digest) do update set evidence=excluded.evidence,last_observed_at=excluded.last_observed_at,reason=excluded.reason;
  if v_reasons='[]'::jsonb and v_record is not null and c->>'reason' is null and not exists(
   select 1 from private.external_radar_candidates where source_id=s.source_id and upstream_id=c->>'upstream_id' and revision_digest=v_digest and review='rejected') then
   if exists(select 1 from private.external_activities other
      where other.source_id<>s.source_id and other.content->>'canonical_url'=v_record->>'canonical_url'
       and other.content->>'publishable'='true'
       and (other.content->'occurrences',other.content->'schedule',other.content->'venue',other.content->'city',other.content->'geometry',other.content->'status')
        is distinct from (v_record->'occurrences',v_record->'schedule',v_record->'venue',v_record->'city',v_record->'geometry',v_record->'status')) then
    update private.external_radar_candidates set reason='source_conflict' where source_id=s.source_id and upstream_id=c->>'upstream_id' and revision_digest=v_digest;
   else
    v_records:=v_records||jsonb_build_array(v_record);v_publishable:=v_publishable+1;
   end if;
  end if;
 end loop;
 -- Cache only a complete traversal; 304 never promotes an unfetched detail.
 for d in select value from jsonb_array_elements(p_documents) loop
  if d-array['url','parser_version','context','content_digest','etag','last_modified','fetched_at','parsed']<>'{}'::jsonb
   or d->>'parser_version' is distinct from r.parser_version or left(d->>'url',length(s.official_origin)+1)<>s.official_origin||'/'
   or jsonb_typeof(d->'parsed') is distinct from 'array' then raise exception 'Invalid document revision.' using errcode='22023'; end if;
  insert into private.external_radar_documents values(s.source_id,d->>'url',d,(d->>'fetched_at')::timestamptz)
   on conflict(source_id,url) do update set representation=excluded.representation,fetched_at=excluded.fetched_at;
 end loop;
 delete from private.external_radar_documents where source_id=s.source_id and url not in (select value->>'url' from jsonb_array_elements(p_documents));
 -- An unobserved former item is not cancelled or refreshed by absence.
 if v_reasons='[]'::jsonb and v_count>0 and v_publishable=0 and exists(
   select 1 from private.external_radar_candidates where source_id=s.source_id and last_observed_at=r.started_at
    and (review='rejected' or reason not in ('outside_area','outside_window'))) then
  v_reasons:=v_reasons||'"candidate_review_required"'::jsonb;
 end if;
 if v_reasons='[]'::jsonb then
  v_result:=public.finish_external_activity_import(p_run_id,'success',v_records,v_count,v_count-v_publishable,null);
  perform private.reconcile_external_radar_aliases(s.source_id);
 else
  update private.external_activity_runs set state='success',finished_at=t,fetched_count=v_count,rejected_count=v_count where run_id=p_run_id;
  update private.external_activity_sources set lease_token=null,lease_expires_at=null where source_id=s.source_id;
 end if;
 update private.external_radar_runs set state=case when v_reasons='[]'::jsonb then 'success' else 'held' end,finished_at=t,collected=v_count,publishable=v_publishable where run_id=p_run_id;
 return jsonb_build_object('state',case when v_reasons='[]'::jsonb then 'success' else 'collected_held' end,'publishable',v_publishable,'changed',coalesce((v_result->>'changed')::integer,0),'source_reasons',v_reasons);
end $$;

create function public.inspect_external_radar_candidates(p_source_id text,p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
begin
 if p_limit not between 1 and 100 then raise exception 'Invalid candidate page size.' using errcode='22023'; end if;
 return jsonb_build_object('scope','external_radar_private','source_id',p_source_id,'candidates',coalesce((
  select jsonb_agg(to_jsonb(c) order by c.last_observed_at desc,c.upstream_id) from (
   select upstream_id,revision_digest,parser_version,title,record,evidence,published_at,reason,review,last_observed_at from private.external_radar_candidates
   where source_id=p_source_id order by last_observed_at desc,upstream_id limit p_limit) c),'[]'::jsonb));
end $$;

create function public.reject_external_radar_candidate(p_source_id text,p_upstream_id text,p_revision_digest text)
returns boolean language plpgsql security definer set search_path='' set statement_timeout='10s' as $$
begin
 -- Review rejects one exact revision. It cannot grant source rights or approve
 -- an ambiguous candidate. Correct the source recipe/evidence and re-collect.
 perform 1 from private.external_activity_sources where source_id=p_source_id for update;
 update private.external_radar_candidates set review='rejected' where source_id=p_source_id and upstream_id=p_upstream_id and revision_digest=p_revision_digest;
 if not found then raise exception 'Unknown exact candidate revision.' using errcode='22023'; end if;
 update private.external_activities a set content=jsonb_set(content,'{publishable}','false'),content_hash=md5(jsonb_set(content,'{publishable}','false')::text),revision=revision+1
  where source_id=p_source_id and upstream_id=p_upstream_id and content=(select record from private.external_radar_candidates where source_id=p_source_id and upstream_id=p_upstream_id and revision_digest=p_revision_digest);
 update private.external_activity_sources set catalogue_version=catalogue_version+1 where source_id=p_source_id;
 return true;
end $$;

create function public.maintain_external_radar_evidence(p_source_id text,p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path='' set statement_timeout='10s' as $$
declare n integer; d integer; s private.external_activity_sources%rowtype; t timestamptz:=clock_timestamp();
begin
 if p_limit not between 1 and 100 then raise exception 'Invalid maintenance bound.' using errcode='22023'; end if;
 select * into s from private.external_activity_sources where source_id=p_source_id for update skip locked;
 if not found or s.lease_expires_at>t then return jsonb_build_object('candidates_pruned',0,'documents_pruned',0,'skipped_busy',true); end if;
 if s.lease_token is not null then
  update private.external_activity_runs set state='incomplete',finished_at=t,error_code='lease_expired' where run_id=s.lease_token and state='running';
  update private.external_activity_sources set lease_token=null,lease_expires_at=null,last_attempt_state='incomplete' where source_id=p_source_id;
 end if;
 update private.external_radar_runs r set state='failure',finished_at=coalesce(a.finished_at,t),error_code='lease_expired'
  from private.external_activity_runs a where r.source_id=p_source_id and r.state='running' and r.run_id=a.run_id and a.state<>'running';
 -- Keep at most the three latest revisions per identity, and never retain
 -- evidence beyond 30 days. Canonical facts/identities are not deleted.
 with ranked as (select source_id,upstream_id,revision_digest,last_observed_at,row_number() over(partition by source_id,upstream_id order by last_observed_at desc,revision_digest) rn
   from private.external_radar_candidates where source_id=p_source_id), doomed as (
   select * from ranked where rn>3 or last_observed_at<statement_timestamp()-interval '30 days' limit p_limit)
 delete from private.external_radar_candidates c using doomed x where (c.source_id,c.upstream_id,c.revision_digest)=(x.source_id,x.upstream_id,x.revision_digest);
 get diagnostics n=row_count;
 with doomed as (select source_id,url from private.external_radar_documents where source_id=p_source_id and fetched_at<statement_timestamp()-interval '7 days' limit p_limit)
 delete from private.external_radar_documents d using doomed x where (d.source_id,d.url)=(x.source_id,x.url);
 get diagnostics d=row_count;
 return jsonb_build_object('candidates_pruned',n,'documents_pruned',d);
end $$;

revoke all on function private.external_radar_source_ready(private.external_activity_sources),private.external_radar_resolve_id(uuid) from public,anon,authenticated,service_role;
revoke all on function public.begin_external_radar_collection(text,text),public.finish_external_radar_collection(uuid,jsonb,jsonb),public.fail_external_radar_collection(uuid,text),public.inspect_external_radar_candidates(text,integer),public.reject_external_radar_candidate(text,text,text),public.maintain_external_radar_evidence(text,integer) from public,anon,authenticated,service_role;
grant execute on function public.begin_external_radar_collection(text,text),public.finish_external_radar_collection(uuid,jsonb,jsonb),public.fail_external_radar_collection(uuid,text),public.inspect_external_radar_candidates(text,integer),public.reject_external_radar_candidate(text,text,text),public.maintain_external_radar_evidence(text,integer) to service_role;

create or replace function private.validate_external_activity_source(p_record jsonb,p_source private.external_activity_sources)
returns void language plpgsql set search_path='' as $$
declare v_url text; v_validation jsonb;
begin
 if p_record->>'activity_type' is not null and p_record->>'activity_type' not in ('music','theatre-cinema','talks','workshops','social','exhibitions','outings') then
  raise exception 'Invalid activity type.' using errcode='22023'; end if;
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
 v_validation:=(p_record-array['link_scope','activity_type'])||jsonb_build_object('canonical_url',p_source.official_origin||'/validation-only');
 if p_record->'geometry' is not null and p_record->'geometry'<>'null'::jsonb then
  v_validation:=v_validation||jsonb_build_object('geometry',p_record->'geometry'||
   jsonb_build_object('provenance_url',p_source.official_origin||'/validation-only'));
 end if;
 perform private.validate_external_activity(v_validation,p_source.official_origin);
end $$;

create or replace function private.external_catalogue_rows(p_now timestamptz,p_as_of timestamptz,p_kind text,p_category text,p_from date,p_to date)
returns table(activity_id uuid,source_id text,content jsonb,next_at timestamptz,next_occurrence jsonb,sort_rank integer,sort_key text)
language sql stable set search_path='' as $$
 select a.activity_id,a.source_id,a.content,t.next_at,t.next_occurrence,
  case coalesce(a.content->>'kind','event') when 'event' then 0 when 'course' then case when t.next_at is null then 2 else 1 end else 3 end,
  case when t.next_at is not null then to_char(t.next_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US') else lower(a.content->>'title') end
 from private.external_activities a join private.external_activity_sources s using(source_id)
 left join lateral private.external_catalogue_timing(a.content,p_as_of,p_from,p_to) t on true
 where private.external_radar_source_ready(s) and not exists(select 1 from private.external_activity_aliases x where x.alias_id=a.activity_id) and a.content->>'publishable'='true' and a.content->>'status'='scheduled'
  and a.last_observed_at>=p_now-case when a.content->>'kind'='place' then interval '30 days' else interval '14 days' end
  and (p_kind is null or coalesce(a.content->>'kind','event')=p_kind)
  and (p_category is null or a.content->>'category'=p_category)
  and case coalesce(a.content->>'kind','event') when 'place' then p_from is null
   when 'course' then private.external_course_current(a.content,p_as_of) and private.external_course_current(a.content,p_now)
    and (p_from is null or t.next_at is not null)
   else t.next_at is not null end
$$;

create or replace function public.get_external_activity_v2(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path='' set statement_timeout='10s' as $$
 select private.external_catalogue_payload(a,s,statement_timestamp())||jsonb_build_object('next_at',t.next_at,'next_occurrence',t.next_occurrence)
 from private.external_activities a join private.external_activity_sources s using(source_id)
 left join lateral private.external_catalogue_timing(a.content,statement_timestamp()) t on true
 where a.activity_id=private.external_radar_resolve_id(p_activity_id) and private.external_radar_source_ready(s)
  and a.content->>'publishable'='true' and a.content->>'status'<>'unpublished'
  and a.last_observed_at>=statement_timestamp()-case when a.content->>'kind'='place' then interval '30 days' else interval '14 days' end
  and (coalesce(a.content->>'kind','event')<>'course' or private.external_course_current(a.content,statement_timestamp()))
$$;

create or replace function public.get_external_activity(p_activity_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select private.external_activity_payload(a,s,statement_timestamp()) from private.external_activities a
 join private.external_activity_sources s using(source_id)
 where a.activity_id=private.external_radar_resolve_id(p_activity_id) and private.external_radar_source_ready(s)
  and coalesce(a.content->>'kind','event')='event' and a.content->>'description' is not null and a.content->>'publishable'='true' and a.content->>'status'<>'unpublished'
  and a.last_observed_at>=statement_timestamp()-interval '14 days'
$$;

create or replace function private.external_activity_payload(p_activity private.external_activities,p_source private.external_activity_sources,p_now timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select (p_activity.content-array['upstream_id','publishable','kind','schedule','geometry','level','access','link_scope','activity_type'])||jsonb_build_object(
  'id',p_activity.activity_id,'revision',p_activity.revision,'observed_at',p_activity.last_observed_at,
  'stale',p_activity.last_observed_at<p_now-interval '72 hours',
  'source',jsonb_build_object('id',p_source.source_id,'name',p_source.display_name,'attribution',p_source.attribution,'license_url',p_source.license_url))
$$;

create or replace function private.external_catalogue_payload(p_activity private.external_activities,p_source private.external_activity_sources,p_now timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select private.external_activity_payload(p_activity,p_source,p_now)||jsonb_build_object(
  'activity_type',p_activity.content->'activity_type','kind',coalesce(p_activity.content->>'kind','event'),'schedule',p_activity.content->'schedule',
  'geometry',p_activity.content->'geometry','level',p_activity.content->'level','access',p_activity.content->'access',
  'link_scope',coalesce(p_activity.content->>'link_scope','item'),
  'stale',p_activity.last_observed_at<p_now-case when p_activity.content->>'kind'='place' then interval '7 days' else interval '72 hours' end)
$$;

create or replace function public.list_external_activities_v4(p_kind text default null,p_category text default null,p_query text default '',p_discipline text default null,p_from date default null,p_to date default null,p_limit integer default 20,p_cursor jsonb default null,p_area jsonb default null,p_map_only boolean default false,p_activity_type text default null)
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
 if p_activity_type is not null and p_activity_type not in ('music','theatre-cinema','talks','workshops','social','exhibitions','outings') then raise exception 'Invalid activity type.' using errcode='22023'; end if;
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
 from private.external_activity_sources where private.external_radar_source_ready(external_activity_sources);
 v_filters:=jsonb_build_object('kind',p_kind,'category',p_category,'query',v_query,'discipline',p_discipline,'from',p_from,'to',p_to,'area',v_area,'map_only',p_map_only,'activity_type',p_activity_type);
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
   where (p_activity_type is null or r.content->>'activity_type'=p_activity_type)
    and (v_query='' or position(v_query in lower(concat_ws(' ',r.content->>'title',r.content->>'description',r.content->>'city',r.content->>'venue')))>0)
    and (p_discipline is null or r.content->>'discipline'=p_discipline)
    and (not p_map_only or a.published_point is not null)
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
   'activity_types',coalesce((select jsonb_agg(d order by d) from (select distinct content->>'activity_type' d from eligible where content->>'activity_type' is not null) types),'[]'::jsonb),
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
revoke all on function public.list_external_activities_v4(text,text,text,text,date,date,integer,jsonb,jsonb,boolean,text) from public,anon,authenticated,service_role;
grant execute on function public.list_external_activities_v4(text,text,text,text,date,date,integer,jsonb,jsonb,boolean,text) to anon,authenticated;

create function private.guard_external_radar_promotion()
returns trigger language plpgsql set search_path='' as $$
declare s private.external_activity_sources%rowtype;
begin
 select * into s from private.external_activity_sources where source_id=new.source_id;
 if (s.radar_parser_version is not null or s.radar_collection_enabled or s.radar_qualified_parser_version is not null or s.radar_policy_revision is not null or s.radar_qualified_policy_revision is not null) and new.content->>'publishable'='true' and (
  not private.external_radar_source_ready(s) or not exists(
   select 1 from private.external_radar_candidates c join private.external_radar_runs r on r.source_id=c.source_id
    where c.source_id=new.source_id and c.upstream_id=new.upstream_id and c.record=new.content
     and c.reason is null and c.review is null and c.parser_version=s.radar_parser_version
     and r.run_id=s.lease_token and r.state='running' and r.source_version=s.catalogue_version
     and c.last_observed_at=r.started_at)) then
  raise exception 'Radar promotion requires current qualified evidence.' using errcode='55000';
 end if;
 return new;
end $$;
create trigger guard_external_radar_promotion before insert or update of content,last_observed_at on private.external_activities
 for each row execute function private.guard_external_radar_promotion();

create function private.reconcile_external_radar_aliases(p_source_id text)
returns void language plpgsql set search_path='' as $$
begin
 -- Correction removes only the disproven alias, never an activity identity.
 delete from private.external_activity_aliases x using private.external_activities a,private.external_activities c
  where not x.source_correction and a.activity_id=x.alias_id and c.activity_id=x.canonical_id and (a.source_id=p_source_id or c.source_id=p_source_id)
   and (a.content->>'canonical_url'<>c.content->>'canonical_url' or
    (a.content->'occurrences',a.content->'schedule',a.content->'venue',a.content->'city',a.content->'geometry',a.content->'status')
     is distinct from (c.content->'occurrences',c.content->'schedule',c.content->'venue',c.content->'city',c.content->'geometry',c.content->'status'));
 insert into private.external_activity_aliases(alias_id,canonical_id,evidence_url)
 select a.activity_id,canonical.activity_id,a.content->>'canonical_url' from private.external_activities a
 join private.external_activity_sources s using(source_id)
 cross join lateral (
  select c.activity_id from private.external_activities c join private.external_activity_sources cs using(source_id)
  where (c.radar_identity_seen_at,c.activity_id)<(a.radar_identity_seen_at,a.activity_id) and c.source_id<>a.source_id and private.external_radar_source_ready(cs)
   and c.content->>'publishable'='true' and c.content->>'canonical_url'=a.content->>'canonical_url'
   and (a.content->'occurrences',a.content->'schedule',a.content->'venue',a.content->'city',a.content->'geometry',a.content->'status')
    is not distinct from (c.content->'occurrences',c.content->'schedule',c.content->'venue',c.content->'city',c.content->'geometry',c.content->'status')
   and not exists(select 1 from private.external_activity_aliases x where x.alias_id=c.activity_id)
  order by c.radar_identity_seen_at,c.activity_id limit 1) canonical
 where private.external_radar_source_ready(s) and a.content->>'publishable'='true'
  and not exists(select 1 from private.external_activity_aliases protected where protected.canonical_id=a.activity_id)
  and a.content->>'canonical_url' in (select content->>'canonical_url' from private.external_activities where source_id=p_source_id)
 on conflict(alias_id) do update set canonical_id=excluded.canonical_id,evidence_url=excluded.evidence_url where not external_activity_aliases.source_correction;
end $$;
revoke all on function private.guard_external_radar_promotion(),private.reconcile_external_radar_aliases(text) from public,anon,authenticated,service_role;

create function public.inspect_external_radar_status(p_source_ids text[])
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='10s' as $$
begin
 if cardinality(p_source_ids) not between 1 and 4 then raise exception 'Invalid source batch.' using errcode='22023'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.source_id,'collection_enabled',s.radar_collection_enabled,
  'parser_version',s.radar_parser_version,'parser_qualified',s.radar_parser_qualified,'facts_reuse',s.radar_facts_reuse,
  'last_collection_at',(select max(started_at) from private.external_radar_runs where source_id=s.source_id and state in ('success','held'))))
 from private.external_activity_sources s where s.source_id=any(p_source_ids)),'[]'::jsonb);
end $$;
revoke all on function public.inspect_external_radar_status(text[]) from public,anon,authenticated,service_role;
grant execute on function public.inspect_external_radar_status(text[]) to service_role;
