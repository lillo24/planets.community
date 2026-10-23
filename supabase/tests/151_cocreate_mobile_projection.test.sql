begin;
select no_plan();
select ok(not has_function_privilege('anon','public.get_own_message_unread_summary_with_cocreate(uuid)','execute'),'Anon cannot read own unread');
select ok(not has_function_privilege('authenticated','private.cocreate_signal(uuid)','execute'),'Clients cannot publish invalidations');
select ok(not has_function_privilege('authenticated','private.cocreate_post_change_signal()','execute'),'Trigger remains private');
select throws_ok($$select public.list_cocreate_topics()$$,'42501',null,'Catalogue disabled by default');
update private.cocreate_settings set enabled=true;
insert into private.cocreate_topics(id,label,active) values
 ('cb020000-0000-4000-8000-000000000001','Synthetic active',true),
 ('cb020000-0000-4000-8000-000000000002','Synthetic inactive',false);
select is(jsonb_array_length(public.list_cocreate_topics()),1,'Only curated active topics project');
select is((public.list_cocreate_topics()->0)-'label',jsonb_build_object('topic_id','cb020000-0000-4000-8000-000000000001'),'Topic projection excludes private state');
insert into auth.users(id,email) values
 ('cb020000-0000-4000-8000-000000000003','cocreate-ui-author@planets.invalid'),
 ('cb020000-0000-4000-8000-000000000004','cocreate-ui-reader@planets.invalid');
insert into public.profiles(id,display_name) select id,'Fictional UI person' from auth.users
 where email like 'cocreate-ui-%@planets.invalid' on conflict(id) do nothing;
insert into private.policy_acceptances(account_id,bundle_version)
 select id,'POLICY01-2026-10-08-v1' from auth.users where email like 'cocreate-ui-%@planets.invalid';
insert into private.cocreate_posts(id,author_id,title,body,locality) values
 ('cb020000-0000-4000-8000-000000000005','cb020000-0000-4000-8000-000000000003','Synthetic draft','','');
insert into private.cocreate_contacts(id,post_id,requester_id,author_id,last_sequence) values
 ('cb020000-0000-4000-8000-000000000006','cb020000-0000-4000-8000-000000000005',
 'cb020000-0000-4000-8000-000000000004','cb020000-0000-4000-8000-000000000003',2);
insert into private.cocreate_contact_messages(contact_id,sender_id,sequence,body) values
 ('cb020000-0000-4000-8000-000000000006','cb020000-0000-4000-8000-000000000003',1,'Synthetic one'),
 ('cb020000-0000-4000-8000-000000000006','cb020000-0000-4000-8000-000000000003',2,'Synthetic two');
select set_config('request.jwt.claim.sub','cb020000-0000-4000-8000-000000000004',true);
select ok(public.can_receive_cocreate_signal('cocreate:profile:cb020000-0000-4000-8000-000000000004'),'Own metadata channel allowed');
select ok(not public.can_receive_cocreate_signal('cocreate:profile:cb020000-0000-4000-8000-000000000003'),'Other actor channel denied');
select is(public.list_own_cocreate_contacts_v2('cb020000-0000-4000-8000-000000000004')->0->>'post_title','Synthetic draft','Private versioned title remains distinguishable');
select ok(not (public.list_own_cocreate_contacts('cb020000-0000-4000-8000-000000000004')->0 ? 'post_title'),'Installed reader keeps exact old shape');
select is(public.get_own_message_unread_summary_with_cocreate('cb020000-0000-4000-8000-000000000004')->>'private','1','Conversation counted once for two human messages');
select is(public.get_own_message_unread_summary_with_cocreate('cb020000-0000-4000-8000-000000000004')->>'groups','0','Bilateral contact never counted in Groups');
select lives_ok($$select public.acknowledge_cocreate_contact('cb020000-0000-4000-8000-000000000004',
 'cb020000-0000-4000-8000-000000000006',public.get_cocreate_contact_page('cb020000-0000-4000-8000-000000000004',
 'cb020000-0000-4000-8000-000000000006')->>'read_token')$$,'Rendered contact ACK succeeds');
select is(public.get_own_message_unread_summary_with_cocreate('cb020000-0000-4000-8000-000000000004')->>'total','0','Read frontier clears canonical total');
update private.cocreate_posts set suppressed=true where id='cb020000-0000-4000-8000-000000000005';
select throws_ok($$select public.get_cocreate_contact_page('cb020000-0000-4000-8000-000000000004','cb020000-0000-4000-8000-000000000006')$$,
 '42501',null,'Suppression denies retained contact');
insert into private.cocreate_interests(id,post_id,requester_id,note) values
 ('cb020000-0000-4000-8000-000000000007','cb020000-0000-4000-8000-000000000005',
 'cb020000-0000-4000-8000-000000000004','Secret exit note');
update private.cocreate_settings set enabled=false;
select is(jsonb_array_length(public.list_own_cocreate_interest_exits('cb020000-0000-4000-8000-000000000004')),1,'Pending own request is recoverable with gate OFF');
select ok(not(public.list_own_cocreate_interest_exits('cb020000-0000-4000-8000-000000000004')->0 ? 'note'),'Exit reader exposes no private note');
select lives_ok($$select public.mutate_cocreate_interest('cb020000-0000-4000-8000-000000000004',gen_random_uuid(),
 'cb020000-0000-4000-8000-000000000005','withdraw','cb020000-0000-4000-8000-000000000007')$$,'Own withdrawal is safe with gate OFF and suppressed source');
select is((public.list_own_cocreate_contact_exits('cb020000-0000-4000-8000-000000000004')->0)-'contact_id',
 jsonb_build_object('created_at',(select created_at from private.cocreate_contacts where id='cb020000-0000-4000-8000-000000000006')),
 'Disabled recovery projects only own anchor and creation time');
select throws_ok($$select public.list_own_cocreate_contact_exits('cb020000-0000-4000-8000-000000000003')$$,
 '42501',null,'Disabled recovery rejects wrong expected identity');
select is(public.get_own_message_unread_summary_with_cocreate('cb020000-0000-4000-8000-000000000004')->>'total','0','Disabled domain preserves native unread');
select lives_ok($$select public.mutate_cocreate_contact('cb020000-0000-4000-8000-000000000004',gen_random_uuid(),
 'cb020000-0000-4000-8000-000000000006','close')$$,'Protected own close works after disabled/suppressed');
select * from finish();
rollback;
