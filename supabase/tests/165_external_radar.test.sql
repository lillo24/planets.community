begin;
select no_plan();

select ok(not has_table_privilege(r,t,'SELECT,INSERT,UPDATE,DELETE'),format('%s denied raw radar table %s',r,t))
 from unnest(array['anon','authenticated','service_role']) r cross join unnest(array[
  'private.external_radar_runs','private.external_radar_candidates','private.external_radar_documents','private.external_activity_aliases']) t;
select ok((select relrowsecurity from pg_class where oid=t::regclass),format('RLS enabled %s',t)) from unnest(array[
 'private.external_radar_runs','private.external_radar_candidates','private.external_radar_documents','private.external_activity_aliases']) t;

select ok(not has_function_privilege(r,f,'EXECUTE'),format('%s denied radar operator %s',r,f))
 from unnest(array['anon','authenticated']) r cross join unnest(array[
 'public.begin_external_radar_collection(text,text)','public.finish_external_radar_collection(uuid,jsonb,jsonb)',
 'public.fail_external_radar_collection(uuid,text)','public.inspect_external_radar_candidates(text,integer)',
 'public.reject_external_radar_candidate(text,text,text)','public.maintain_external_radar_evidence(text,integer)',
 'public.inspect_external_radar_status(text[])']) f;
select ok(has_function_privilege('service_role',f,'EXECUTE'),format('service operator only %s',f)) from unnest(array[
 'public.begin_external_radar_collection(text,text)','public.finish_external_radar_collection(uuid,jsonb,jsonb)',
 'public.fail_external_radar_collection(uuid,text)','public.inspect_external_radar_candidates(text,integer)',
 'public.reject_external_radar_candidate(text,text,text)','public.maintain_external_radar_evidence(text,integer)',
 'public.inspect_external_radar_status(text[])']) f;
select ok(has_function_privilege(r,'public.list_external_activities_v4(text,text,text,text,date,date,integer,jsonb,jsonb,boolean,text)','EXECUTE'),format('%s may read V4',r)) from unnest(array['anon','authenticated']) r;
select ok(not has_function_privilege('service_role','public.list_external_activities_v4(text,text,text,text,date,date,integer,jsonb,jsonb,boolean,text)','EXECUTE'),'service role gains no public read surface');
select ok(has_function_privilege('anon','public.list_external_activities_v3(text,text,text,text,date,date,integer,jsonb,jsonb,boolean)','EXECUTE'),'installed V3 remains readable');
select ok(not has_function_privilege(r,f,'EXECUTE'),format('%s denied private helper %s',r,f)) from unnest(array['anon','authenticated','service_role']) r cross join unnest(array[
 'private.guard_external_radar_promotion()','private.reconcile_external_radar_aliases(text)','private.external_radar_resolve_id(uuid)']) f;
select throws_ok($$select private.validate_external_activity_source('{"activity_type":"invented"}',null::private.external_activity_sources)$$,'22023','Invalid activity type.','server owns activity type vocabulary');
select throws_ok($$select public.list_external_activities_v4(p_activity_type=>'invented')$$,'22023','Invalid activity type.','V4 refuses unsupported family before paging');
select is((select count(*)::integer from private.external_activity_sources where radar_collection_enabled),0,'migration enables no collectors');
select is((select count(*)::integer from private.external_activity_sources where enabled),0,'migration enables no public sources');
select * from finish();
rollback;
