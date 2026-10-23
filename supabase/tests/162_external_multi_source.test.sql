begin;
select no_plan();
select ok(not exists(select 1 from pg_indexes where indexname='external_activity_one_enabled_source'),'One-active-source restriction removed additively');
select is((select count(*) from private.external_activity_sources),0::bigint,'No source is seeded or enabled');
insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url,public_link_origins)
 values('synthetic-source-a','Synthetic A','https://api.example.org',true,true,'Synthetic attribution','https://example.org/license',array['https://municipal.example.org']),
 ('synthetic-source-b','Synthetic B','https://api.example.org',true,true,'Synthetic attribution','https://example.org/license','{}');
select throws_ok($$update private.external_activity_sources set public_link_origins=array['http://unsafe.example.org'] where source_id='synthetic-source-a'$$,'23514',null,'Owner origin configuration rejects insecure origins');
select throws_ok($$update private.external_activity_sources set public_link_origins=array['https://safe.example.org/path'] where source_id='synthetic-source-a'$$,'23514',null,'Origins cannot smuggle an arbitrary path policy');
create function pg_temp.source_record(p_origin text,p_title text,p_discipline text) returns jsonb language sql as $$
 select jsonb_build_object('upstream_id','collision','title',p_title,'description','Synthetic content',
  'canonical_url',p_origin||'/item','category','sports','discipline',p_discipline,
  'source_categories','[]'::jsonb,'status','scheduled','publishable',true,
  'occurrences',jsonb_build_array(jsonb_build_object('kind','timed','start',now()+interval '1 day','end',now()+interval '2 days','timezone','UTC')))
$$;
select set_config('test.a',public.begin_external_activity_import('synthetic-source-a')->>'run_id',true);
select lives_ok($$select set_config('test.b',public.begin_external_activity_import('synthetic-source-b')->>'run_id',true)$$,'Independent A/B leases can coexist');
select throws_ok($$select public.begin_external_activity_import('synthetic-source-a')$$,'55P03','Activity import already running.','A/A lease exclusion retained');
select is(public.finish_external_activity_import(current_setting('test.a')::uuid,'success',jsonb_build_array(pg_temp.source_record('https://municipal.example.org','Synthetic A','running')||'{"link_scope":"dataset"}'),1)->>'accepted','1','A accepts approved public origin distinct from API origin');
select is(public.finish_external_activity_import(current_setting('test.b')::uuid,'success',jsonb_build_array(pg_temp.source_record('https://api.example.org','Synthetic B','yoga')),1)->>'accepted','1','B imports independently');
select is((select count(distinct activity_id) from private.external_activities),2::bigint,'Same upstream string in two sources has distinct canonical UUIDs');
select is(jsonb_array_length(public.list_external_activities_v2()->'items'),2,'V2 reads both sources');
select is(jsonb_array_length(public.list_external_activities()->'items'),2,'Released event reader reads both sources');
select is(jsonb_array_length(public.list_external_activities_v2(p_limit=>1)->'disciplines'),2,'Facets span both sources before pagination');
select set_config('test.cursor',(public.list_external_activities_v2(p_limit=>1)->'next_cursor')::text,true);
select set_config('test.first',(public.list_external_activities_v2(p_limit=>1)->'items'->0->>'id'),true);
select isnt(public.list_external_activities_v2(p_limit=>1,p_cursor=>current_setting('test.cursor')::jsonb)->'items'->0->>'id',current_setting('test.first'),'Equal sort times traverse distinct UUIDs without duplicates');
select throws_ok($$select public.list_external_activities_v2(p_category=>'culture',p_cursor=>current_setting('test.cursor')::jsonb)$$,'22023','Activity cursor requires refresh.','Cursor binds complete category filters');
select set_config('test.a_id',(select activity_id::text from private.external_activities where source_id='synthetic-source-a'),true);
select is(public.get_external_activity_v2(current_setting('test.a_id')::uuid)->>'link_scope','dataset','V2 exposes typed dataset action scope');
select ok(not(public.get_external_activity(current_setting('test.a_id')::uuid) ?| array['link_scope','kind','schedule','geometry','access','level']),'V1 keeps its released event shape');
select ok(not(public.get_external_activity_v2(current_setting('test.a_id')::uuid)->'source' ?| array['public_link_origins','enabled','rights_confirmed','lease_token']),'Public source projection excludes owner configuration');
select set_config('test.a',public.begin_external_activity_import('synthetic-source-a')->>'run_id',true);
select throws_ok($$select public.finish_external_activity_import(current_setting('test.a')::uuid,'success',jsonb_build_array(pg_temp.source_record('https://unapproved.example.org','Synthetic A','running')),1)$$,'22023','Invalid source public link.','Other-source or arbitrary origins cannot enter A');
select is(public.finish_external_activity_import(current_setting('test.a')::uuid,'failure','[]',0,0,'upstream_error')->>'state','failure','Source A failure recorded independently');
select is(public.list_external_activities_v2()->>'state','partial','Healthy B plus failed A is partial');
select is(public.list_external_activities()->>'state','unavailable','V1 retains compatible health vocabulary');
select is(jsonb_array_length(public.list_external_activities_v2()->'items'),2,'Partial health retains valid source snapshots');
select is((public.list_external_activities_v2()->'sources'->>'failed')::integer,1,'Only sanitized failed aggregate is public');
select set_config('test.a_observed',(select last_observed_at::text from private.external_activities where source_id='synthetic-source-a'),true);
select set_config('test.b',public.begin_external_activity_import('synthetic-source-b')->>'run_id',true);
select is(public.finish_external_activity_import(current_setting('test.b')::uuid,'success',jsonb_build_array(pg_temp.source_record('https://api.example.org','Synthetic B','yoga')),1)->>'changed','0','Unchanged B preserves revision');
select is((select last_observed_at::text from private.external_activities where source_id='synthetic-source-a'),current_setting('test.a_observed'),'B success cannot refresh A observation');
update private.external_activity_sources set enabled=false where source_id='synthetic-source-a';
select is(jsonb_array_length(public.list_external_activities_v2()->'items'),1,'Disabling A retains B');
select is(public.get_external_activity_v2(current_setting('test.a_id')::uuid),null::jsonb,'Disabled A exact detail is denied');
select throws_ok($$select public.list_external_activities_v2(p_cursor=>current_setting('test.cursor')::jsonb)$$,'22023','Activity cursor requires refresh.','Source-set changes fence old continuations');
update private.external_activity_sources set enabled=true where source_id='synthetic-source-a';
select throws_ok($$select public.list_external_activities_v2(p_cursor=>current_setting('test.cursor')::jsonb)$$,'22023','Activity cursor requires refresh.','Disable/re-enable cannot resurrect the old source version');
select set_config('test.a',public.begin_external_activity_import('synthetic-source-a')->>'run_id',true);
update private.external_activity_sources set enabled=false where source_id='synthetic-source-a';
select throws_ok($$select public.finish_external_activity_import(current_setting('test.a')::uuid,'success','[]',0)$$,'55000','Activity source disabled.','Mid-run disable prevents publication');
select is(jsonb_array_length(public.list_external_activities_v2()->'items'),1,'Mid-run A disable does not affect B');
select ok(not has_table_privilege(r,'private.external_activity_sources','SELECT,INSERT,UPDATE,DELETE'),r||' cannot read/configure raw source state') from unnest(array['anon','authenticated','service_role']) r;
select ok(not has_function_privilege(r,'private.validate_external_activity_source(jsonb,private.external_activity_sources)','EXECUTE'),r||' cannot bypass source policy') from unnest(array['anon','authenticated','service_role']) r;
select * from finish();
rollback;
