begin;
select no_plan();
select ok(not has_function_privilege('anon','public.create_cocreate_post_from_event(uuid,uuid,uuid,jsonb)','execute'),'Anonymous cannot create event-related drafts');
select ok(not has_table_privilege(r,'private.cocreate_post_events',p),r||' cannot '||p||' event references')
 from unnest(array['anon','authenticated','service_role'])r cross join unnest(array['SELECT','INSERT','UPDATE','DELETE'])p;
select throws_ok($$select public.get_cocreate_event_context('cd030000-0000-4000-8000-000000000001')$$,'42501',null,'Server gate OFF rejects event handoff context');
update private.cocreate_settings set enabled=true;
insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
 values('synthetic-cocreate-event','Synthetic reviewed calendar','https://api.example.org',true,true,'Synthetic local fixture only','https://example.org/license');
select set_config('ce.run',public.begin_external_activity_import('synthetic-cocreate-event')->>'run_id',true);
select public.finish_external_activity_import(current_setting('ce.run')::uuid,'success',jsonb_build_array(jsonb_build_object(
 'upstream_id','synthetic-event','title','Synthetic public event','description','Public provider description never copied',
 'canonical_url','https://api.example.org/events/synthetic-event','category','culture','source_categories',jsonb_build_array('Synthetic'),
 'city','Trento','venue','Synthetic venue','address','Public venue address never copied','status','scheduled','publishable',true,
 'occurrences',jsonb_build_array(jsonb_build_object('kind','timed','start',to_char((now()+interval '1 day')at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
 'end',to_char((now()+interval '1 day 1 hour')at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'timezone','Europe/Rome')))),1);
select set_config('ce.event',(select activity_id::text from private.external_activities where source_id='synthetic-cocreate-event'),true);
select set_config('ce.original',(select to_jsonb(a)::text from private.external_activities a where activity_id=current_setting('ce.event')::uuid),true);
select set_config('ce.native_count',(select count(*)::text from public.projects),true);
insert into auth.users(id,email) values
 ('cd030000-0000-4000-8000-000000000010','cocreate-event-a@planets.invalid'),
 ('cd030000-0000-4000-8000-000000000011','cocreate-event-b@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic event person' from auth.users where id::text like 'cd030000%';
insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1' from auth.users where id::text like 'cd030000%';
select set_config('request.jwt.claim.sub','cd030000-0000-4000-8000-000000000010',true);
select is(public.get_cocreate_event_context(current_setting('ce.event')::uuid)->>'id',current_setting('ce.event'),'Context is the actual canonical public event');
select set_config('ce.command',gen_random_uuid()::text,true);
select set_config('ce.draft',public.create_cocreate_post_from_event('cd030000-0000-4000-8000-000000000010',current_setting('ce.command')::uuid,current_setting('ce.event')::uuid,
 '{"title":"Reviewed intent","body":"My reviewed public text","locality":"Trento"}'::jsonb)::text,true);
select is(current_setting('ce.draft')::jsonb->>'state','draft','Event action creates an unpublished ordinary post draft');
select is(public.create_cocreate_post_from_event('cd030000-0000-4000-8000-000000000010',current_setting('ce.command')::uuid,current_setting('ce.event')::uuid,
 '{"title":"Reviewed intent","body":"My reviewed public text","locality":"Trento"}'::jsonb),current_setting('ce.draft')::jsonb,'Lost event draft reply reuses exactly one post');
select throws_ok($$select public.create_cocreate_post_from_event('cd030000-0000-4000-8000-000000000010',current_setting('ce.command')::uuid,current_setting('ce.event')::uuid,
 '{"title":"Changed intent"}'::jsonb)$$,'22023',null,'Changed event draft intent cannot reuse its UUID');
select is((select body from private.cocreate_posts where id=(current_setting('ce.draft')::jsonb->>'post_id')::uuid),'My reviewed public text','Provider description/address are not silently copied');
select is(public.get_cocreate_post_event((current_setting('ce.draft')::jsonb->>'post_id')::uuid),null::jsonb,'Unpublished post source is not public');
select public.mutate_cocreate_post('cd030000-0000-4000-8000-000000000010',gen_random_uuid(),'publish',(current_setting('ce.draft')::jsonb->>'post_id')::uuid,1);
select is((select count(*)::text from public.projects),current_setting('ce.native_count'),'Event handoff creates no native Project/Event record');
select is((select to_jsonb(a) from private.external_activities a where activity_id=current_setting('ce.event')::uuid),current_setting('ce.original')::jsonb,'Canonical imported event remains read-only');
select is(public.get_cocreate_post_event((current_setting('ce.draft')::jsonb->>'post_id')::uuid)->'event'->>'activity_id',current_setting('ce.event'),'Published post has a minimal public event reference');
select is((select count(*) from jsonb_object_keys(public.get_cocreate_post_event((current_setting('ce.draft')::jsonb->>'post_id')::uuid)->'event')),8::bigint,'Reference allow-list excludes descriptions, addresses, upstream/control and private fields');
select is((select count(*) from private.cocreate_room_episodes where actor_id='cd030000-0000-4000-8000-000000000010'),0::bigint,'Saving/publishing an event-related post does not join anything');
update private.external_activities set content=jsonb_set(content,'{status}','"cancelled"') where activity_id=current_setting('ce.event')::uuid;
select is(public.get_cocreate_event_context(current_setting('ce.event')::uuid),null::jsonb,'Cancelled event is unavailable for new handoff');
select throws_ok($$select public.create_cocreate_post_from_event('cd030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('ce.event')::uuid,'{}'::jsonb)$$,'42501',null,'Stale composer cannot create a draft from a cancelled event');
select is(public.get_cocreate_post_event((current_setting('ce.draft')::jsonb->>'post_id')::uuid)->'event'->>'status','cancelled','Existing read-only reference truthfully discloses cancellation');
update private.external_activity_sources set enabled=false where source_id='synthetic-cocreate-event';
select is(public.get_cocreate_post_event((current_setting('ce.draft')::jsonb->>'post_id')::uuid),jsonb_build_object('post_id',(current_setting('ce.draft')::jsonb->>'post_id')::uuid,'state','unavailable'),'Withdrawn source never fabricates a functioning event link');
select is(public.create_cocreate_post_from_event('cd030000-0000-4000-8000-000000000010',current_setting('ce.command')::uuid,current_setting('ce.event')::uuid,
 '{"title":"Reviewed intent","body":"My reviewed public text","locality":"Trento"}'::jsonb),current_setting('ce.draft')::jsonb,'Source withdrawal does not lose an already-created author draft receipt');

-- Ordinary literal filters run in SQL before cursor/limit, without ranking.
insert into private.cocreate_topics(id,label,active) values
 ('cd030000-0000-4000-8000-000000000020','Synthetic filter A',true),('cd030000-0000-4000-8000-000000000021','Synthetic filter _ B',true);
insert into private.cocreate_posts(id,author_id,state,title,body,locality,topic_id,created_at,expires_at) values
 ('cd030000-0000-4000-8000-000000000030','cd030000-0000-4000-8000-000000000010','open','100 percent','Public text','Rovereto','cd030000-0000-4000-8000-000000000020',now()+interval '4 seconds',now()+interval '1 day'),
 ('cd030000-0000-4000-8000-000000000031','cd030000-0000-4000-8000-000000000010','open','Literal 100%','Public text','Trento','cd030000-0000-4000-8000-000000000021',now()+interval '3 seconds',now()+interval '1 day'),
 ('cd030000-0000-4000-8000-000000000032','cd030000-0000-4000-8000-000000000010','open','Literal _ marker','Public text','Trento','cd030000-0000-4000-8000-000000000021',now()+interval '2 seconds',now()+interval '1 day');
select is(jsonb_array_length(public.list_cocreate_posts(p_search=>'100%')),1,'Percent is literal text, not a wildcard');
select is(jsonb_array_length(public.list_cocreate_posts(p_search=>'_')),1,'Underscore is literal text, not a wildcard');
select set_config('ce.page',public.list_cocreate_posts(p_locality=>'trento',p_topic_id=>'cd030000-0000-4000-8000-000000000021',p_limit=>1)::text,true);
select is(current_setting('ce.page')::jsonb->0->>'post_id','cd030000-0000-4000-8000-000000000031','Topic and exact broad locality filter before limit');
select is(public.list_cocreate_posts(p_locality=>'Trento',p_topic_id=>'cd030000-0000-4000-8000-000000000021',p_limit=>1,
 p_before_created_at=>(current_setting('ce.page')::jsonb->0->>'created_at')::timestamptz,p_before_id=>(current_setting('ce.page')::jsonb->0->>'post_id')::uuid)->0->>'post_id',
 'cd030000-0000-4000-8000-000000000032','Stable paired cursor keeps the next filtered post');
insert into private.cocreate_hubs(id,topic_id,locality,active) values
 ('cd030000-0000-4000-8000-000000000040','cd030000-0000-4000-8000-000000000021','Trento',true),
 ('cd030000-0000-4000-8000-000000000041','cd030000-0000-4000-8000-000000000020','Rovereto',true);
select is(jsonb_array_length(public.list_cocreate_hubs(p_search=>'_',p_locality=>'Trento',p_limit=>1)),1,'Hub controlled topic/locality/literal text compose before paging');
select public.mutate_cocreate_hub('cd030000-0000-4000-8000-000000000010',gen_random_uuid(),'cd030000-0000-4000-8000-000000000040','join');
select set_config('ce.g1',public.mutate_cocreate_numbered_group('cd030000-0000-4000-8000-000000000010',gen_random_uuid(),'cd030000-0000-4000-8000-000000000040','create',null,null,2)::text,true);
select set_config('ce.g2',public.mutate_cocreate_numbered_group('cd030000-0000-4000-8000-000000000010',gen_random_uuid(),'cd030000-0000-4000-8000-000000000040','create')::text,true);
select set_config('request.jwt.claim.sub','cd030000-0000-4000-8000-000000000011',true);
select public.mutate_cocreate_hub('cd030000-0000-4000-8000-000000000011',gen_random_uuid(),'cd030000-0000-4000-8000-000000000040','join');
select public.mutate_cocreate_numbered_group('cd030000-0000-4000-8000-000000000011',gen_random_uuid(),'cd030000-0000-4000-8000-000000000040','join',(current_setting('ce.g1')::jsonb->>'room_id')::uuid);
select is(public.list_cocreate_numbered_groups('cd030000-0000-4000-8000-000000000040',true,1)->0->>'number','2','Open seats filter before the numeric page limit');
select is(public.list_cocreate_numbered_groups('cd030000-0000-4000-8000-000000000040',false,1)->0->>'number','1','Full groups remain in stable numeric discovery');
select is(jsonb_array_length(public.list_cocreate_numbered_groups('cd030000-0000-4000-8000-000000000040',true,1,2)),0,'Exhausted filtered cursor is a valid empty result');
select * from finish();
rollback;
