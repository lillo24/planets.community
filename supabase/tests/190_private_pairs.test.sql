begin;
select no_plan();
insert into auth.users(id,email) select ('a1010000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'a1-person-'||n||'@planets.invalid' from generate_series(1,5)n;
insert into public.profiles(id,display_name) select id,case when right(id::text,1)='1' then 'Alice' else 'Marco' end
  from auth.users where email like 'a1-person-%';
insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1'
  from auth.users where email like 'a1-person-%';
insert into public.profile_photos(profile_id,object_path,audience)
  select id,id::text||'/a1000000-0000-4000-8000-000000000001.webp','interactions'
  from public.profiles where id::text like 'a101%';
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at) values
 ('a1020000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000001','published','A1 garden',now()+interval '1 day',now()+interval '2 days',now()),
 ('a1020000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000002','published','A1 reverse',now()+interval '1 day',now()+interval '2 days',now());
insert into public.resource_listings(id,owner_profile_id,listing_mode,lifecycle_state,title,description,country_code,locality,public_location_label,published_at)
 values('a1030000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000001','donate','published','A1 tools','Fictional tools for local verification','IT','Trento','Trento',now());
insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
 values('a1040000-0000-4000-8000-000000000001','A1 garden group','Fictional shared Group','informal',false,'published','a1010000-0000-4000-8000-000000000001');
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)
 values('a1040000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000001');
insert into private.group_memberships(group_id,profile_id,admitted_by)
 values('a1040000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001');
update private.cocreate_settings set enabled=true;
create temp table a1_fixture(k text primary key,v jsonb); grant all on a1_fixture to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000002',true);
insert into a1_fixture values('request',to_jsonb(public.request_to_join_project('a1010000-0000-4000-8000-000000000002','a1020000-0000-4000-8000-000000000001','A private note')));
insert into a1_fixture values('resource_request',to_jsonb(public.request_resource_listing('a1010000-0000-4000-8000-000000000002','a1030000-0000-4000-8000-000000000001','Private resource note')));
insert into a1_fixture values('member_request',public.submit_member_contact_request('a1010000-0000-4000-8000-000000000002',gen_random_uuid(),'a1040000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000001','Explicit contact consent'));
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000003',true);
select public.request_to_join_project('a1010000-0000-4000-8000-000000000003','a1020000-0000-4000-8000-000000000001','Same name, distinct person');
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000001',true);
insert into a1_fixture values('reverse',to_jsonb(public.request_to_join_project('a1010000-0000-4000-8000-000000000001','a1020000-0000-4000-8000-000000000002','Reversed endpoints')));
select public.accept_resource_listing_request('a1010000-0000-4000-8000-000000000001',(select(v#>>'{}')::uuid from a1_fixture where k='resource_request'));
insert into a1_fixture values('member',public.accept_member_contact_request('a1010000-0000-4000-8000-000000000001',gen_random_uuid(),(select(v->>'request_id')::uuid from a1_fixture where k='member_request')));
insert into a1_fixture values('post',public.mutate_cocreate_post('a1010000-0000-4000-8000-000000000001',gen_random_uuid(),'create',null,null,
 '{"title":"A1 games","body":"Fictional public invitation","locality":"Trento"}'));
select public.mutate_cocreate_post('a1010000-0000-4000-8000-000000000001',gen_random_uuid(),'publish',(select(v->>'post_id')::uuid from a1_fixture where k='post'),1);
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000002',true);
insert into a1_fixture values('interest',public.mutate_cocreate_interest('a1010000-0000-4000-8000-000000000002',gen_random_uuid(),(select(v->>'post_id')::uuid from a1_fixture where k='post'),'request'));
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000001',true);
insert into a1_fixture values('contact',public.mutate_cocreate_interest('a1010000-0000-4000-8000-000000000001',gen_random_uuid(),(select(v->>'post_id')::uuid from a1_fixture where k='post'),'accept',(select(v->>'interest_id')::uuid from a1_fixture where k='interest')));
select is(jsonb_array_length(public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000001')),2,'all four domains group before paging; identical display names stay distinct');
select is(jsonb_array_length(public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000001',1)),1,'pair page size applies after grouping');
select is(jsonb_array_length(public.list_own_private_pair_contexts_v1('a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000002')),5,'both request directions and all other personal contexts remain available');
select throws_ok($$select public.get_own_private_pair_page_v1('a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000004')$$,'42501',null,'public profile knowledge creates no DM');
select throws_ok($$select public.resolve_own_private_pair_v1('a1010000-0000-4000-8000-000000000001','resource_chat','00000000-0000-4000-8000-000000000001')$$,'42501',null,'missing source cannot fall through to another valid pair source');
select throws_ok($$select public.get_own_private_pair_page_v1('a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000002',20,now())$$,'22023',null,'partial mixed cursor rejects');
reset role;
insert into a1_fixture select 'resource_chat',to_jsonb(id) from public.resource_request_chats where request_id=(select(v#>>'{}')::uuid from a1_fixture where k='resource_request');
insert into a1_fixture select 'pair',to_jsonb(conversation_id) from public.participation_conversation_requests where request_id=(select(v#>>'{}')::uuid from a1_fixture where k='request');
-- Deliberate historical fixtures with identical timestamps retain distinct IDs.
insert into public.participation_conversation_messages(conversation_id,sender_profile_id,body,created_at)
 select(v#>>'{}')::uuid,'a1010000-0000-4000-8000-000000000001','Same text','2026-10-24 10:00:00+00' from a1_fixture where k='pair';
insert into public.resource_request_chat_messages(chat_id,sender_profile_id,body,created_at)
 select(v#>>'{}')::uuid,'a1010000-0000-4000-8000-000000000001','Same text','2026-10-24 10:00:00+00' from a1_fixture where k='resource_chat';
insert into public.resource_request_chat_messages(chat_id,sender_profile_id,body,created_at)
 select(v#>>'{}')::uuid,'a1010000-0000-4000-8000-000000000001','Second resource message','2026-10-24 10:00:00+00' from a1_fixture where k='resource_chat';
set local role authenticated;
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000001',true);
select public.send_member_contact_message('a1010000-0000-4000-8000-000000000001',gen_random_uuid(),(select(v->>'chat_id')::uuid from a1_fixture where k='member'),(select(v->>'episode_id')::uuid from a1_fixture where k='member'),'Member source history');
select public.mutate_cocreate_contact('a1010000-0000-4000-8000-000000000001',gen_random_uuid(),(select(v->>'contact_id')::uuid from a1_fixture where k='contact'),'send','People source history');
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000002',true);
insert into a1_fixture values('page',public.get_own_private_pair_page_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',50));
select is((select count(*) from jsonb_array_elements((select v->'items' from a1_fixture where k='page'))m where m->>'body'='Same text'),2::bigint,'identical legitimate bodies and timestamps remain distinct original messages');
select is((public.get_own_private_pair_unread_v1('a1010000-0000-4000-8000-000000000002')->>'private')::int,1,'global badge counts the person once across four unread domains');
select is((public.get_own_message_unread_summary_with_cocreate('a1010000-0000-4000-8000-000000000002')->>'private')::int,4,'installed source conversation counts retain their old contract');
select is((public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000002')->0->>'unread_count')::int,5,'row counts all five incoming human messages');
insert into a1_fixture values('first_resource',(select m from jsonb_array_elements((select v->'items' from a1_fixture where k='page'))m where m->>'item_kind'='resource_message' and m->>'body'='Same text'));
insert into a1_fixture values('second_resource',(select m from jsonb_array_elements((select v->'items' from a1_fixture where k='page'))m where m->>'body'='Second resource message'));
select public.acknowledge_own_private_pair_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',
 (select(v->>'read_boundary')::uuid from a1_fixture where k='page'),array[(select 'resource_message:'||(v->>'item_id') from a1_fixture where k='second_resource')]);
select is((public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000002')->0->>'unread_count')::int,5,'latest viewport cannot swallow an earlier unrendered message in the same source');
select public.acknowledge_own_private_pair_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',
 (select(v->>'read_boundary')::uuid from a1_fixture where k='page'),array[(select 'resource_message:'||(v->>'item_id') from a1_fixture where k='first_resource')]);
select is((public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000002')->0->>'unread_count')::int,4,'only the actually rendered source prefix is acknowledged');
select throws_ok($$select public.acknowledge_own_private_pair_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',
 (select(v->>'read_boundary')::uuid from a1_fixture where k='page'),array['resource_message:00000000-0000-4000-8000-000000000001'])$$,'42501',null,'invented rendered keys fail');
select is(public.get_own_private_pair_page_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',1,
 (select(v->'items'->0->>'created_at')::timestamptz from a1_fixture where k='page'),
 (select v->'items'->0->>'item_kind' from a1_fixture where k='page'),(select(v->'items'->0->>'item_id')::uuid from a1_fixture where k='page'))->>'read_boundary',null::text,'older pages issue no ACK boundary');
insert into a1_fixture values('command',to_jsonb(gen_random_uuid()));
insert into a1_fixture values('send',public.send_own_private_pair_message_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',
 (select(v#>>'{}')::uuid from a1_fixture where k='command'),'resource_chat',(select(v#>>'{}')::uuid from a1_fixture where k='resource_chat'),null,'Immutable retry'));
select is(public.send_own_private_pair_message_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',
 (select(v#>>'{}')::uuid from a1_fixture where k='command'),'resource_chat',(select(v#>>'{}')::uuid from a1_fixture where k='resource_chat'),null,'Immutable retry'),
 (select v from a1_fixture where k='send'),'ambiguous reply replays the original result');
select throws_ok($$select public.send_own_private_pair_message_v1('a1010000-0000-4000-8000-000000000002','a1010000-0000-4000-8000-000000000001',
 (select(v#>>'{}')::uuid from a1_fixture where k='command'),'resource_chat',(select(v#>>'{}')::uuid from a1_fixture where k='resource_chat'),null,'Changed intent')$$,'22023',null,'a frozen command cannot change message or authority');
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000001',true);
select public.reject_project_join_request_as_manager('a1010000-0000-4000-8000-000000000001',(select(v#>>'{}')::uuid from a1_fixture where k='request'));
select throws_ok($$select public.send_own_private_pair_message_v1('a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000002',
 gen_random_uuid(),'participation_request',(select(v#>>'{}')::uuid from a1_fixture where k='request'),null,'Do not switch to reverse request')$$,'PT409',null,'closed selected request cannot switch to another eligible request');
reset role;
update private.cocreate_settings set enabled=false;
set local role authenticated;
select is((select count(*) from jsonb_array_elements(public.get_own_private_pair_page_v1('a1010000-0000-4000-8000-000000000001','a1010000-0000-4000-8000-000000000002',50)->'items')m
 where m->>'source_kind'='cocreate_contact'),0::bigint,'server gate OFF removes People bodies and source metadata from mixed feed');
select throws_ok($$select public.resolve_own_private_pair_v1('a1010000-0000-4000-8000-000000000001','cocreate_contact',(select(v->>'contact_id')::uuid from a1_fixture where k='contact'))$$,'42501',null,'gate OFF exact People link does not reveal another context');
select set_config('request.jwt.claim.sub','a1010000-0000-4000-8000-000000000004',true);
select is(jsonb_array_length(public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000004')),0,'unrelated user has no pair rows');
select throws_ok($$select public.get_own_private_pair_page_v1('a1010000-0000-4000-8000-000000000004','a1010000-0000-4000-8000-000000000001')$$,'42501',null,'unrelated actor cannot read a known pair');
select throws_ok($$select public.list_own_private_pairs_v1('a1010000-0000-4000-8000-000000000001')$$,'42501',null,'expected actor binding is enforced');
reset role;
select ok(not has_function_privilege(r,p.oid,'execute'),r||' cannot execute '||p.proname)
 from pg_proc p cross join unnest(array['anon','service_role'])r
 where p.pronamespace='public'::regnamespace and p.proname like '%private_pair%';
select ok(not has_function_privilege('authenticated',p.oid,'execute'),p.proname||' is private')
 from pg_proc p where p.pronamespace='private'::regnamespace and p.proname like 'a1_%';
select ok(not has_table_privilege(r,c.oid,'select'),r||' has no raw receipt grant')
 from pg_class c cross join unnest(array['anon','authenticated','service_role'])r
 where c.relnamespace='private'::regnamespace and c.relname like 'a1_%' and c.relkind='r';
select * from finish();
rollback;
