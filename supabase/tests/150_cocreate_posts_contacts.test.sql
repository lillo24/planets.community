begin;
select no_plan();
select ok(relrowsecurity,relname||' has RLS') from pg_class
where relnamespace='private'::regnamespace and relname like 'cocreate_%' and relkind='r';
select ok(not has_table_privilege(r,c.oid,p),r||' cannot '||p||' '||c.relname)
from pg_class c cross join unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE']) p
where c.relnamespace='private'::regnamespace and c.relname like 'cocreate_%' and c.relkind='r';
select ok(not has_function_privilege('authenticated',oid,'EXECUTE'),proname||' helper is private')
from pg_proc where pronamespace='private'::regnamespace and proname like '%cocreate%';
select throws_ok($$select public.list_cocreate_posts()$$,'42501',null,'Disabled public discovery denies direct call');
select throws_ok($$select public.mutate_cocreate_post(null,gen_random_uuid(),'create')$$,'42501',null,'Disabled mutation denies direct call');

update private.cocreate_settings set enabled=true;
insert into auth.users(id,email) values
 ('cb010000-0000-4000-8000-000000000001','cocreate-tap-author@planets.invalid'),
 ('cb010000-0000-4000-8000-000000000002','cocreate-tap-requester@planets.invalid'),
 ('cb010000-0000-4000-8000-000000000003','cocreate-tap-outsider@planets.invalid');
insert into public.profiles(id,display_name)
select id,'Fictional co-creation person' from auth.users where email like 'cocreate-tap-%@planets.invalid'
on conflict(id) do nothing;
insert into private.policy_acceptances(account_id,bundle_version)
select id,'POLICY01-2026-10-08-v1' from auth.users where email like 'cocreate-tap-%@planets.invalid';
select set_config('request.jwt.claim.sub','cb010000-0000-4000-8000-000000000001',true);
select set_config('cocreate.create_key',gen_random_uuid()::text,true);
select set_config('cocreate.draft',(public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.create_key')::uuid,'create',null,null,
 '{"title":"Fictional football","body":"A synthetic public example","locality":"Trento"}')->>'post_id'),true);
select is(public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.create_key')::uuid,'create',null,null,
 '{"title":"Fictional football","body":"A synthetic public example","locality":"Trento"}')->>'post_id',
 current_setting('cocreate.draft'),'Exact create retry returns same post');
select throws_ok($$select public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.create_key')::uuid,'create',null,null,'{"title":"Changed intent"}')$$,
 '22023',null,'Changed-intent retry fails');
select is(public.get_cocreate_post(current_setting('cocreate.draft')::uuid),null::jsonb,'Draft never enters public detail');
select is(jsonb_array_length(public.list_cocreate_posts()),0,'Draft never enters public discovery');
select throws_ok($$select public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',gen_random_uuid(),'edit',
 current_setting('cocreate.draft')::uuid,9,'{"title":"Wrong version"}')$$,'PT409',null,'Stale version rejects edit');
select throws_ok($$select public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',gen_random_uuid(),'edit',
 current_setting('cocreate.draft')::uuid,1,'{"exact_address":"Private data"}')$$,'22023',null,'Unknown content fields reject');
select set_config('cocreate.publish_key',gen_random_uuid()::text,true);
select lives_ok($$select public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.publish_key')::uuid,'publish',current_setting('cocreate.draft')::uuid,1)$$,'Owner explicitly publishes');
select is(public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.publish_key')::uuid,'publish',current_setting('cocreate.draft')::uuid,1)->>'version','2','Publish retry retains version');
select is(jsonb_array_length(public.list_cocreate_posts('football','trento')),1,'Public literal filters match');
select is(jsonb_array_length(public.list_cocreate_posts('%','Trento')),0,'Search wildcard is literal');
select ok(not (public.get_cocreate_post(current_setting('cocreate.draft')::uuid) ?| array['author_id','note','requests','contact_id']),
 'Public projection has no identity/request/contact fields');
select throws_ok($$select public.list_cocreate_posts('', '', null, 0)$$,'22023',null,'Zero page bound rejects');
select throws_ok($$select public.list_cocreate_posts('', '', null, 25, now(), null)$$,'22023',null,'Partial cursor rejects');
select throws_ok($$select public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000001',gen_random_uuid(),
 current_setting('cocreate.draft')::uuid,'request')$$,'42501',null,'Self-interest rejects');

select set_config('request.jwt.claim.sub','cb010000-0000-4000-8000-000000000002',true);
select set_config('cocreate.interest_key',gen_random_uuid()::text,true);
select set_config('cocreate.interest',(public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.interest_key')::uuid,current_setting('cocreate.draft')::uuid,'request',null,'Private note')->>'interest_id'),true);
select is(public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.interest_key')::uuid,current_setting('cocreate.draft')::uuid,'request',null,'Private note')->>'interest_id',
 current_setting('cocreate.interest'),'Uncertain request retry creates no second interest');
select throws_ok($$select public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000002',gen_random_uuid(),
 current_setting('cocreate.draft')::uuid,'request')$$,'PT409',null,'Fresh duplicate is explicit conflict');
select is(jsonb_array_length(public.list_own_cocreate_contacts('cb010000-0000-4000-8000-000000000002')),0,'Pending interest opens no chat');
select throws_ok($$select public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000002',gen_random_uuid(),
 current_setting('cocreate.draft')::uuid,'accept',current_setting('cocreate.interest')::uuid)$$,'42501',null,'Requester cannot accept themselves');
select set_config('request.jwt.claim.sub','cb010000-0000-4000-8000-000000000003',true);
select is(jsonb_array_length(public.list_own_cocreate_interests('cb010000-0000-4000-8000-000000000003',
 current_setting('cocreate.draft')::uuid)),0,'Another author/reader sees no notes or request identity');
select throws_ok($$select public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000003',gen_random_uuid(),'close',
 current_setting('cocreate.draft')::uuid,2)$$,'42501',null,'Another author cannot manage the post');
select set_config('request.jwt.claim.sub','cb010000-0000-4000-8000-000000000001',true);
select set_config('cocreate.accept_key',gen_random_uuid()::text,true);
select set_config('cocreate.contact',(public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.accept_key')::uuid,current_setting('cocreate.draft')::uuid,'accept',
 current_setting('cocreate.interest')::uuid)->>'contact_id'),true);
select is(public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.accept_key')::uuid,current_setting('cocreate.draft')::uuid,'accept',
 current_setting('cocreate.interest')::uuid)->>'contact_id',current_setting('cocreate.contact'),'Duplicate acceptance returns same bilateral anchor');
select is((select count(*) from private.cocreate_contacts where post_id=current_setting('cocreate.draft')::uuid),1::bigint,'Exactly one accepted contact exists');
select set_config('cocreate.send_key',gen_random_uuid()::text,true);
select set_config('cocreate.message',(public.mutate_cocreate_contact('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.send_key')::uuid,current_setting('cocreate.contact')::uuid,'send','Private human message')->>'message_id'),true);
select is(public.mutate_cocreate_contact('cb010000-0000-4000-8000-000000000001',current_setting('cocreate.send_key')::uuid,
 current_setting('cocreate.contact')::uuid,'send','Private human message')->>'message_id',current_setting('cocreate.message'),'Send retry is immutable and exact');
select throws_ok($$select public.mutate_cocreate_contact('cb010000-0000-4000-8000-000000000001',current_setting('cocreate.send_key')::uuid,
 current_setting('cocreate.contact')::uuid,'send','Changed human message')$$,'22023',null,'Changed send retry fails');
select lives_ok($$select public.mutate_cocreate_post('cb010000-0000-4000-8000-000000000001',gen_random_uuid(),'close',
 current_setting('cocreate.draft')::uuid,2)$$,'Owner closes discovery');
select is(public.get_cocreate_post(current_setting('cocreate.draft')::uuid),null::jsonb,'Closed post disappears publicly');
select is(jsonb_array_length(public.get_cocreate_contact_page('cb010000-0000-4000-8000-000000000001',
 current_setting('cocreate.contact')::uuid)->'messages'),1,'Post closure retains accepted history');
select set_config('request.jwt.claim.sub','cb010000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.get_cocreate_contact_page('cb010000-0000-4000-8000-000000000003',
 current_setting('cocreate.contact')::uuid)$$,'42501',null,'Outsider cannot read accepted history');
select throws_ok($$select public.get_moderation_case_cocreate('cb010000-0000-4000-8000-000000000003',gen_random_uuid())$$,'42501',null,'Ordinary user gets no staff evidence');
select set_config('request.jwt.claim.sub','cb010000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.mutate_cocreate_interest('cb010000-0000-4000-8000-000000000002',gen_random_uuid(),
 current_setting('cocreate.draft')::uuid,'withdraw',current_setting('cocreate.interest')::uuid)$$,'PT409',null,'Acceptance wins before withdrawal');
select is(public.list_own_cocreate_contacts('cb010000-0000-4000-8000-000000000002')->0->>'unread_count','1','Only incoming human messages count unread');
select set_config('cocreate.token',public.get_cocreate_contact_page('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.contact')::uuid)->>'read_token',true);
select lives_ok($$select public.acknowledge_cocreate_contact('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.contact')::uuid,current_setting('cocreate.token'))$$,'Rendered page receipt acknowledges');
select is(public.list_own_cocreate_contacts('cb010000-0000-4000-8000-000000000002')->0->>'unread_count','0','ACK uses canonical frontier');
select throws_ok($$select public.acknowledge_cocreate_contact('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.contact')::uuid,'1.forged')$$,'22023',null,'Forged ACK rejects');
select set_config('cocreate.report_key',gen_random_uuid()::text,true);
select set_config('cocreate.case',(select case_id::text from public.submit_cocreate_report('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.report_key')::uuid,'cocreate_contact_message',current_setting('cocreate.message')::uuid,
 'spam','Synthetic report explanation')),true);
select is((select count(*) from private.moderation_reports where client_submission_id=current_setting('cocreate.report_key')::uuid),1::bigint,'Genuine typed report enters canonical queue');
select lives_ok($$select public.submit_cocreate_report('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.report_key')::uuid,'cocreate_contact_message',current_setting('cocreate.message')::uuid,
 'spam','Synthetic report explanation')$$,'Report exact retry recovers');
select lives_ok($$select public.block_user('cb010000-0000-4000-8000-000000000002','cb010000-0000-4000-8000-000000000001')$$,'Canonical block composes without domain replacement');
select throws_ok($$select public.get_cocreate_contact_page('cb010000-0000-4000-8000-000000000002',
 current_setting('cocreate.contact')::uuid)$$,'42501',null,'Retained contact ID cannot bypass active block');
select lives_ok($$select public.submit_cocreate_report('cb010000-0000-4000-8000-000000000002',gen_random_uuid(),
 'cocreate_contact_message',current_setting('cocreate.message')::uuid,'spam','Report remains available after blocking')$$,'Block does not disable report evidence');
update private.cocreate_settings set enabled=false;
select lives_ok($$select public.mutate_cocreate_contact('cb010000-0000-4000-8000-000000000002',gen_random_uuid(),
 current_setting('cocreate.contact')::uuid,'close')$$,'Own exit works while disabled and blocked');
set local role anon;
select throws_ok($$select public.list_own_cocreate_posts(null)$$,'42501',null,'Guest has no owner-list grant');
select throws_ok($$select * from private.cocreate_contact_messages$$,'42501',null,'Guest cannot query private messages');
reset role;
select * from finish();
rollback;
