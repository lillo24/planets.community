-- Private operator projections and bounded maintenance. No sources/configuration
-- are seeded. Existing canonical rows, observation expiry and 30-day compact
-- run retention are unchanged; no raw upstream response is retained.
create index external_activity_runs_source_latest
 on private.external_activity_runs(source_id,started_at desc,run_id);

create function private.validate_external_operation_sources(p_source_ids text[])
returns void language plpgsql immutable set search_path='' as $$
begin
 if p_source_ids is null or cardinality(p_source_ids) not between 1 and 4
  or array_ndims(p_source_ids)<>1
  or exists(select 1 from unnest(p_source_ids) x where x is null or x !~ '^[a-z][a-z0-9-]{0,63}$')
  or (select count(distinct x) from unnest(p_source_ids) x)<>cardinality(p_source_ids) then
  raise exception 'Select one to four distinct activity sources.' using errcode='22023';
 end if;
end $$;
revoke all on function private.validate_external_operation_sources(text[]) from public,anon,authenticated,service_role;

create function public.inspect_external_activity_sources(p_source_ids text[])
returns jsonb language plpgsql stable security definer set search_path=''
 set statement_timeout='10s' as $$
declare v_now timestamptz:=statement_timestamp(); v_sources jsonb;
begin
 perform private.validate_external_operation_sources(p_source_ids);
 select jsonb_agg(case when s.source_id is null then
   jsonb_build_object('id',q.id,'configured',false)
  else jsonb_build_object('id',s.source_id,'configured',true,
   'enabled',s.enabled,'rights_confirmed',s.rights_confirmed,
   'last_success_at',s.last_success_at,'last_attempt_state',s.last_attempt_state,
   'lease_state',case when s.lease_token is null then 'idle'
     when s.lease_expires_at>v_now then 'running' else 'expired' end,
   'last_run',case when r.run_id is null then null else jsonb_build_object(
     'started_at',r.started_at,'finished_at',r.finished_at,'state',r.state,
     'fetched',r.fetched_count,'accepted',r.accepted_count,
     'rejected',r.rejected_count,'changed',r.changed_count,'error_code',r.error_code) end,
   -- These are observation-age counts, not availability or public eligibility.
   'observations',jsonb_build_object('total',o.total,'fresh',o.fresh,
     'stale',o.stale,'expired',o.expired,'oldest_at',o.oldest_at,'newest_at',o.newest_at))
  end order by q.ordinality) into v_sources
 from unnest(p_source_ids) with ordinality q(id,ordinality)
 left join private.external_activity_sources s on s.source_id=q.id
 left join lateral (select x.* from private.external_activity_runs x
   where x.source_id=s.source_id order by x.started_at desc,x.run_id limit 1) r on true
 left join lateral (select count(*) as total,
   count(*) filter(where a.last_observed_at>=v_now-case when a.content->>'kind'='place' then interval '7 days' else interval '72 hours' end) as fresh,
   count(*) filter(where a.last_observed_at<v_now-case when a.content->>'kind'='place' then interval '7 days' else interval '72 hours' end
     and a.last_observed_at>=v_now-case when a.content->>'kind'='place' then interval '30 days' else interval '14 days' end) as stale,
   count(*) filter(where a.last_observed_at<v_now-case when a.content->>'kind'='place' then interval '30 days' else interval '14 days' end) as expired,
   min(a.last_observed_at) as oldest_at,max(a.last_observed_at) as newest_at
   from private.external_activities a where a.source_id=s.source_id) o on true;
 return jsonb_build_object('scope','external_activity_operations','as_of',v_now,'sources',v_sources);
end $$;
revoke all on function public.inspect_external_activity_sources(text[]) from public,anon,authenticated;
grant execute on function public.inspect_external_activity_sources(text[]) to service_role;

create function public.maintain_external_activity_imports(p_source_ids text[],p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=''
 set statement_timeout='10s' set lock_timeout='2s' as $$
declare v_source private.external_activity_sources%rowtype; v_now timestamptz:=clock_timestamp();
 v_expired integer:=0; v_pruned integer:=0; v_count integer;
begin
 perform private.validate_external_operation_sources(p_source_ids);
 if p_limit is null or p_limit not between 1 and 100 then
  raise exception 'Maintenance limit must be 1 to 100.' using errcode='22023'; end if;
 -- Same source-before-run ordering as begin/finish. Skip an active holder rather
 -- than contend with imports. Only the selected source's expired lease changes.
 for v_source in select * from private.external_activity_sources
  where source_id=any(p_source_ids) order by source_id for update skip locked loop
  v_now:=clock_timestamp();
  if v_source.lease_expires_at<=v_now then
   update private.external_activity_runs set state='incomplete',finished_at=v_now,error_code='lease_expired'
    where run_id=v_source.lease_token and source_id=v_source.source_id and state='running';
   update private.external_activity_sources set lease_token=null,lease_expires_at=null,
    last_attempt_state=case when last_attempt_state='running' then 'incomplete' else last_attempt_state end
    where source_id=v_source.source_id;
   v_expired:=v_expired+1;
  end if;
  if v_pruned<p_limit then
   with candidates as (select run_id from private.external_activity_runs
     where source_id=v_source.source_id and state<>'running' and started_at<v_now-interval '30 days'
     order by started_at,run_id limit (p_limit-v_pruned) for update skip locked)
   delete from private.external_activity_runs r using candidates c where r.run_id=c.run_id;
   get diagnostics v_count=row_count;
   v_pruned:=v_pruned+v_count;
  end if;
 end loop;
 return jsonb_build_object('scope','external_activity_operations','as_of',v_now,
  'expired_leases',v_expired,'pruned_runs',v_pruned,'limit',p_limit);
end $$;
revoke all on function public.maintain_external_activity_imports(text[],integer) from public,anon,authenticated;
grant execute on function public.maintain_external_activity_imports(text[],integer) to service_role;

-- Preserve the installed command OID/signature/grants and ten-minute fence;
-- replace the predecessor's global unbounded prune with source-scoped bounded
-- maintenance. A competing active source lease still fails before cleanup.
create or replace function public.begin_external_activity_import(p_source_id text)
returns jsonb language plpgsql security definer set search_path='' set lock_timeout='5s' as $$
declare v_source private.external_activity_sources%rowtype; v_token uuid:=gen_random_uuid(); v_now timestamptz;
begin
 select * into v_source from private.external_activity_sources where source_id=p_source_id for update;
 v_now:=clock_timestamp();
 if not found or not v_source.enabled or not v_source.rights_confirmed then
  raise exception 'Activity source is not enabled and licensed.' using errcode='55000'; end if;
 if v_source.lease_expires_at>v_now then raise exception 'Activity import already running.' using errcode='55P03'; end if;
 perform public.maintain_external_activity_imports(array[p_source_id],100);
 insert into private.external_activity_runs(run_id,source_id,started_at) values(v_token,p_source_id,v_now);
 update private.external_activity_sources set lease_token=v_token,lease_expires_at=v_now+interval '10 minutes',last_attempt_state='running' where source_id=p_source_id;
 return jsonb_build_object('run_id',v_token,'started_at',v_now,'lease_expires_at',v_now+interval '10 minutes');
end $$;
