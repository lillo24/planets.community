begin;
select no_plan();
select ok(not has_function_privilege(r,'public.inspect_external_activity_sources(text[])','EXECUTE'),r||' cannot inspect private operations') from unnest(array['anon','authenticated']) r;
select ok(not has_function_privilege(r,'public.maintain_external_activity_imports(text[],integer)','EXECUTE'),r||' cannot mutate leases/retention') from unnest(array['anon','authenticated']) r;
select ok(has_function_privilege('service_role','public.inspect_external_activity_sources(text[])','EXECUTE'),'Service can inspect sanitized operations');
select ok(has_function_privilege('service_role','public.maintain_external_activity_imports(text[],integer)','EXECUTE'),'Service can maintain selected metadata');
select ok(not has_table_privilege(r,'private.external_activity_sources','SELECT,INSERT,UPDATE,DELETE'),r||' still cannot read/configure raw sources') from unnest(array['anon','authenticated','service_role']) r;
select ok(not has_function_privilege(r,'private.validate_external_operation_sources(text[])','EXECUTE'),r||' cannot execute private validator') from unnest(array['anon','authenticated','service_role']) r;
select throws_ok($$select public.inspect_external_activity_sources('{}')$$,'22023',null,'No implicit all-source inspection');
select throws_ok($$select public.inspect_external_activity_sources(array['a','a'])$$,'22023',null,'Duplicate source IDs rejected');
select throws_ok($$select public.inspect_external_activity_sources(array['a','b','c','d','e'])$$,'22023',null,'Inspection capped at four');
select throws_ok($$select public.maintain_external_activity_imports(array['a'],0)$$,'22023',null,'Maintenance lower bound');
select throws_ok($$select public.maintain_external_activity_imports(array['a'],101)$$,'22023',null,'Maintenance upper bound');
select is(public.inspect_external_activity_sources(array['not-configured'])->'sources'->0,'{"id":"not-configured","configured":false}'::jsonb,'Unconfigured is explicit, not healthy empty');
insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
 values('ops-a','Synthetic A','https://example.org',true,true,'Synthetic attribution','https://example.org/license'),
 ('ops-b','Synthetic B','https://example.org',true,true,'Synthetic attribution','https://example.org/license');
insert into private.external_activities(source_id,upstream_id,content,content_hash,last_observed_at)
 select 'ops-a',n::text,'{"kind":"place"}'::jsonb,'synthetic',now()-n*interval '1 day' from unnest(array[1,8,31]) n;
select is(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0->'observations'->>'fresh','1','Place observation fresh age');
select is(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0->'observations'->>'stale','1','Place stale age distinct from expired');
select is(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0->'observations'->>'expired','1','Expiry is inspection/visibility, not deletion');
select ok(not(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0 ?| array['official_origin','public_link_origins','lease_token','run_id','content']),'Only bounded operator projection, no URLs/tokens/payloads');
select set_config('test.run',public.begin_external_activity_import('ops-a')->>'run_id',true);
select is(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0->>'lease_state','running','Active lease inspection');
select is((public.maintain_external_activity_imports(array['ops-a'])->>'expired_leases')::int,0,'Maintenance cannot clear live lease');
update private.external_activity_sources set lease_expires_at=clock_timestamp()-interval '1 second' where source_id='ops-a';
select is(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0->>'lease_state','expired','Expired distinct from running');
select is((public.maintain_external_activity_imports(array['ops-b'])->>'expired_leases')::int,0,'Other-source maintenance cannot clear A');
select is((public.maintain_external_activity_imports(array['ops-a'])->>'expired_leases')::int,1,'Selected expired lease recovered');
select is((select state from private.external_activity_runs where run_id=current_setting('test.run')::uuid),'incomplete','Interrupted run becomes incomplete');
select is((select error_code from private.external_activity_runs where run_id=current_setting('test.run')::uuid),'lease_expired','Exact lease error code');
select throws_ok($$select public.finish_external_activity_import(current_setting('test.run')::uuid,'success','[]',0)$$,'40001','Obsolete activity import completion.','Late completion fenced after maintenance');
insert into private.external_activity_runs(source_id,started_at,finished_at,state)
 select 'ops-a',now()-interval '31 days',now()-interval '31 days','success' from generate_series(1,105);
insert into private.external_activity_runs(source_id,started_at,finished_at,state)
 values('ops-b',now()-interval '31 days',now()-interval '31 days','success');
select is((public.maintain_external_activity_imports(array['ops-a'],3)->>'pruned_runs')::int,3,'Explicit smaller prune bound');
select is((public.maintain_external_activity_imports(array['ops-a'])->>'pruned_runs')::int,100,'Default prune cap');
select is((select count(*) from private.external_activity_runs where source_id='ops-a' and started_at<now()-interval '30 days'),2::bigint,'Bounded remaining rows survive for next maintenance');
select is((select count(*) from private.external_activity_runs where source_id='ops-b'),1::bigint,'Unselected retention untouched');
select is((select count(*) from private.external_activities where source_id='ops-a'),3::bigint,'Canonical/provenance rows never deleted by maintenance');
update private.external_activity_sources set enabled=false where source_id='ops-a';
select is((public.maintain_external_activity_imports(array['ops-a'])->>'pruned_runs')::int,2,'Maintenance works while source disabled/no refresh succeeds');
select is(public.inspect_external_activity_sources(array['ops-a'])->'sources'->0->>'enabled','false','Disabled operator state explicit');
select * from finish();
rollback;
