begin;
select no_plan();
select is(public.list_external_activities()->>'state','unconfigured','No source is seeded or presented as a successful empty import');
select is((select count(*) from private.external_activity_sources),0::bigint,'Municipal publication is not configured');
select ok((select bool_and(relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='private' and c.relname in ('external_activity_sources','external_activity_runs','external_activities','external_activity_occurrences')),'All external state has RLS');
select ok(not has_table_privilege(r,t,'SELECT,INSERT,UPDATE,DELETE'),r||' has no raw access to '||t)
 from unnest(array['anon','authenticated','service_role']) r cross join unnest(array['private.external_activity_sources','private.external_activity_runs','private.external_activities','private.external_activity_occurrences']) t;
select ok(not has_function_privilege(r,'public.begin_external_activity_import(text)','EXECUTE'),r||' cannot claim imports') from unnest(array['anon','authenticated']) r;
select ok(not has_function_privilege(r,'public.finish_external_activity_import(uuid,text,jsonb,integer,integer,text)','EXECUTE'),r||' cannot publish imports') from unnest(array['anon','authenticated']) r;
select ok(has_function_privilege('service_role','public.begin_external_activity_import(text)','EXECUTE'),'Service can claim bounded imports');
select ok(not has_function_privilege('service_role','private.validate_external_activity(jsonb,text)','EXECUTE'),'Service cannot bypass the publication transaction');
select set_config('test.native_count',(select count(*)::text from public.projects),true);

insert into private.external_activity_sources(source_id,display_name,official_origin)
 values('synthetic-actapi01','Synthetic test calendar','https://api.example.org');
select throws_ok($$update private.external_activity_sources set enabled=true where source_id='synthetic-actapi01'$$,'23514',null,'Cannot enable a source without explicit rights and attribution');
select throws_ok($$select public.begin_external_activity_import('synthetic-actapi01')$$,'55000','Activity source is not enabled and licensed.','Import fails closed while disabled');
update private.external_activity_sources set enabled=true,rights_confirmed=true,attribution='Synthetic fixture only',license_url='https://example.org/license' where source_id='synthetic-actapi01';
select is(public.list_external_activities()->>'state','never_synchronized','Enabled never-imported source is distinct from empty');

create function pg_temp.activity_fixture(p_id text,p_start timestamptz) returns jsonb language sql as $$
 select jsonb_build_object('upstream_id',p_id,'title','Synthetic '||p_id,'description','Synthetic plain text',
  'canonical_url','https://api.example.org/events/'||p_id,'category','culture','source_categories',jsonb_build_array('Exhibition'),
  'discipline',null,'organizer',null,'cost',null,'audience',null,'city','Trento','venue',null,'address',null,
  'status','scheduled','publishable',true,'source_modified_at',null,'occurrences',jsonb_build_array(jsonb_build_object(
   'kind','timed','start',to_char(p_start at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   'end',to_char((p_start+interval '1 hour') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'timezone','Europe/Rome')))
$$;
select set_config('test.activity_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
select throws_ok($$select public.begin_external_activity_import('synthetic-actapi01')$$,'55P03','Activity import already running.','A source-scoped lease rejects concurrent claims');
select throws_ok($$select public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(pg_temp.activity_fixture('bad',now())||'{"contact_email":"excluded@example.org"}'),1)$$,'22023','Invalid activity fields.','Unknown/contact fields cannot enter canonical content');
select is((select count(*) from private.external_activities),0::bigint,'Invalid completion commits no partial rows');
select throws_ok($$select public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(pg_temp.activity_fixture('blank',now())||'{"description":""}'),1)$$,'22023','Invalid activity content.','Required description cannot violate the public reader contract');
select throws_ok($$select public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(pg_temp.activity_fixture('blank',now())||'{"organizer":""}'),1)$$,'22023','Activity content must be bounded plain text.','Unknown optional text must be null rather than a blank public field');
select is(public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(
 pg_temp.activity_fixture('a',now()+interval '1 day'),
 pg_temp.activity_fixture('b',now()+interval '1 day')||'{"category":"sports","discipline":"running"}',
 pg_temp.activity_fixture('unique-target',now()+interval '2 days')||'{"category":"sports","discipline":"rowing"}'
),3)->>'changed','3','Complete import atomically inserts three canonical identities');
select set_config('test.activity_id',(select activity_id::text from private.external_activities where upstream_id='a'),true);
select is((select count(*) from private.external_activity_occurrences),3::bigint,'Occurrence sets are installed with the records');
select is(public.list_external_activities()->>'state','healthy','Successful source is healthy');
select is(jsonb_array_length(public.list_external_activities(p_query=>'unique-target')->'items'),1,'Search applies to the complete catalogue, not a downloaded first page');
select is(jsonb_array_length(public.list_external_activities(p_category=>'sports',p_limit=>1)->'disciplines'),2,'Discipline metadata spans the whole eligible catalogue');
select set_config('test.activity_page',public.list_external_activities(p_limit=>1)::text,true);
select ok((current_setting('test.activity_page')::jsonb)->'next_cursor'<>'null'::jsonb,'A genuine extra row creates a continuation');
select set_config('test.activity_page2',public.list_external_activities(p_limit=>1,p_cursor=>current_setting('test.activity_page')::jsonb->'next_cursor')::text,true);
select isnt(current_setting('test.activity_page')::jsonb->'items'->0->>'id',current_setting('test.activity_page2')::jsonb->'items'->0->>'id','Equal occurrence times use stable UUID ordering without duplicate pages');
select is(current_setting('test.activity_page')::jsonb->>'as_of',current_setting('test.activity_page2')::jsonb->>'as_of','Continuation retains the same occurrence reference');
select throws_ok($$select public.list_external_activities(p_category=>'sports',p_cursor=>current_setting('test.activity_page')::jsonb->'next_cursor')$$,'22023','Activity cursor requires refresh.','Cursor is bound to complete filters');
select throws_ok($$select public.list_external_activities(p_limit=>31)$$,'22023','Invalid activity filters.','Public page size is bounded');

set local role anon;
select is(jsonb_array_length(public.list_external_activities()->'items'),3,'Anonymous viewers receive the deliberate public projection');
select ok(not (public.get_external_activity(current_setting('test.activity_id')::uuid) ? 'upstream_id'),'Internal upstream identifiers are not public');
select ok(not (public.get_external_activity(current_setting('test.activity_id')::uuid) ? 'publishable'),'Publication controls are not a public mutation contract');
select throws_ok($$select public.begin_external_activity_import('synthetic-actapi01')$$,'42501',null,'Anonymous callers cannot claim imports');
reset role;
set local role authenticated;
select is(jsonb_array_length(public.list_external_activities()->'items'),3,'Authenticated public read has identical eligibility');
select throws_ok($$select public.finish_external_activity_import(gen_random_uuid(),'success')$$,'42501',null,'Authenticated callers cannot finish imports');
reset role;

select set_config('test.activity_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
select is(public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(
 pg_temp.activity_fixture('a',now()+interval '1 day'),
 pg_temp.activity_fixture('b',now()+interval '1 day')||'{"category":"sports","discipline":"running"}',
 pg_temp.activity_fixture('unique-target',now()+interval '2 days')||'{"category":"sports","discipline":"rowing"}'
),3)->>'changed','0','Repeated unchanged import creates no content revision or duplicate');
select is((select count(*) from private.external_activities),3::bigint,'Stable upstream identity is unique');
select is((select max(revision) from private.external_activities),1::bigint,'Observation alone does not fabricate changed content');
select ok((select bool_and(content->>'source_modified_at' is null) from private.external_activities),'Unknown upstream modification remains unknown');
select throws_ok($$select public.list_external_activities(p_cursor=>current_setting('test.activity_page')::jsonb->'next_cursor')$$,'22023','Activity cursor requires refresh.','A new complete catalogue version resets old cursors');

select set_config('test.activity_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
select is(public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(pg_temp.activity_fixture('a',now()+interval '3 days')||'{"title":"Changed synthetic title"}'),1)->>'changed','1','Changed records update their original identity');
select is((select revision from private.external_activities where upstream_id='a'),2::bigint,'Content revision increments on actual change');
select is((select count(*) from private.external_activity_occurrences where activity_id=current_setting('test.activity_id')::uuid),1::bigint,'Old occurrences are replaced rather than appended');
select is((select activity_id::text from private.external_activities where upstream_id='a'),current_setting('test.activity_id'),'Changed record keeps internal identity');
select is((select count(*) from private.external_activities),3::bigint,'Absence from the moving window never deletes another record');

select set_config('test.success',(select last_success_at::text from private.external_activity_sources where source_id='synthetic-actapi01'),true);
select set_config('test.content',(select md5(string_agg(content::text,',' order by upstream_id)) from private.external_activities),true);
select set_config('test.activity_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
select is(public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'incomplete','[]',0,0,'upstream_error')->>'state','incomplete','Failed page is an explicit incomplete run');
select is((select md5(string_agg(content::text,',' order by upstream_id)) from private.external_activities),current_setting('test.content'),'Incomplete import preserves the entire valid catalogue');
select is((select last_success_at::text from private.external_activity_sources where source_id='synthetic-actapi01'),current_setting('test.success'),'Incomplete import cannot advance the completeness checkpoint');
select is(public.list_external_activities()->>'state','unavailable','Source failure is distinguishable while retaining previous records');

update private.external_activities set last_observed_at=statement_timestamp()-interval '73 hours' where upstream_id='a';
select is(public.get_external_activity(current_setting('test.activity_id')::uuid)->>'stale','true','Individual records become stale after 72 hours');
update private.external_activity_sources set last_success_at=statement_timestamp(),last_attempt_state='success';
select is(public.get_external_activity(current_setting('test.activity_id')::uuid)->>'stale','true','Source-wide success never refreshes a missing record');
update private.external_activities set last_observed_at=statement_timestamp()-interval '15 days' where upstream_id='a';
select is(public.get_external_activity(current_setting('test.activity_id')::uuid),null::jsonb,'Fourteen-day observation expiry removes exact public access');
select is(jsonb_array_length(public.list_external_activities(p_query=>'Changed synthetic')->'items'),0,'Old future end dates cannot keep an unobserved item in discovery');

select set_config('test.activity_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
update private.external_activity_sources set lease_expires_at=clock_timestamp()-interval '1 second';
select set_config('test.new_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
select is((select state from private.external_activity_runs where run_id=current_setting('test.activity_run')::uuid),'incomplete','Expired lease gets an explicit incomplete outcome');
select throws_ok($$select public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success')$$,'40001','Obsolete activity import completion.','Late completion cannot overwrite a newer lease');
select is(public.finish_external_activity_import(current_setting('test.new_run')::uuid,'success')->>'accepted','0','A complete empty source result is a genuine success, without absence deletion');

select set_config('test.activity_run',public.begin_external_activity_import('synthetic-actapi01')->>'run_id',true);
select lives_ok($$select public.finish_external_activity_import(current_setting('test.activity_run')::uuid,'success',jsonb_build_array(
 pg_temp.activity_fixture('dates',now())||jsonb_build_object('publishable',false,'occurrences',jsonb_build_array(jsonb_build_object('kind','all_day','start','2026-10-25','end','2026-10-26','timezone','Europe/Rome')))
),1)$$,'Rome all-day autumn DST interval is accepted without claiming an appointment');
select is((select extract(epoch from o.ends_at-o.starts_at)::integer from private.external_activity_occurrences o join private.external_activities a using(activity_id) where a.upstream_id='dates'),90000,'Exclusive Rome date interval preserves the 25-hour autumn day');
select is((select content->'occurrences'->0->>'start' from private.external_activities where upstream_id='dates'),'2026-10-25','Canonical date-only start remains a date');
select is(private.external_activity_next(current_setting('test.activity_id')::uuid,statement_timestamp()+interval '10 days'),null::timestamptz,'Expired dates leave upcoming discovery independently of freshness');

update private.external_activities set last_observed_at=statement_timestamp(),content=jsonb_set(content,'{status}','"cancelled"') where upstream_id='a';
select is(public.get_external_activity(current_setting('test.activity_id')::uuid)->>'status','cancelled','Exact detail can truthfully disclose explicit cancellation');
select is(jsonb_array_length(public.list_external_activities(p_query=>'Changed synthetic')->'items'),0,'Cancelled records are excluded from ordinary discovery');
update private.external_activities set content=jsonb_set(content,'{status}','"unpublished"') where upstream_id='a';
select is(public.get_external_activity(current_setting('test.activity_id')::uuid),null::jsonb,'Explicit unpublication denies exact access');
update private.external_activity_sources set enabled=false;
select is(public.list_external_activities()->>'state','unconfigured','Operator disable immediately gates reads');
select is(public.get_external_activity((select activity_id from private.external_activities where upstream_id='b')),null::jsonb,'Disable also gates exact detail');
select is((select count(*)::text from public.projects),current_setting('test.native_count'),'No native Project records are created or changed');
select * from finish();
rollback;
