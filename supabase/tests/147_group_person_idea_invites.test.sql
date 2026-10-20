-- Transactional authorization probes with synthetic identities. Genuine OTP
-- invocation and the composed UI are separate native/upgrade qualification gates.
begin;
select no_plan();
create function pg_temp.person(n integer) returns uuid language sql as $$
  select ('c1470000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
create function pg_temp.grp(n integer) returns uuid language sql as $$
  select ('c1471000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
create function pg_temp.room(n integer) returns uuid language sql as $$
  select ('c1472000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
insert into auth.users(id,email) select pg_temp.person(n),'selector-'||n||'@planets.invalid' from generate_series(1,6) n;
insert into public.profiles(id,display_name) select pg_temp.person(n),'Fictional selector person '||n from generate_series(1,6) n;
insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
  values(pg_temp.grp(1),'Synthetic selector Group','Synthetic authorization probes.','informal',false,'published',pg_temp.person(1));
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)
  values(pg_temp.grp(1),pg_temp.person(1),pg_temp.person(1));
insert into private.group_memberships(group_id,profile_id,admitted_by)
  select pg_temp.grp(1),pg_temp.person(n),pg_temp.person(1) from generate_series(2,3) n;
insert into private.group_memberships(group_id,profile_id,admitted_by)
  values(pg_temp.grp(1),pg_temp.person(6),pg_temp.person(1));
insert into private.group_delegates(group_id,profile_id,initial_role,delegate_role,granted_by)
  values(pg_temp.grp(1),pg_temp.person(5),'co_organizer','co_organizer',pg_temp.person(1));
insert into private.group_discussions(id,group_id,creator_id,title,purpose,visibility,created_at)
  select pg_temp.room(n),pg_temp.grp(1),pg_temp.person(1),'Synthetic selector Idea '||n,
    'Purpose only; no private transcript.','group','2026-10-20 09:00Z'::timestamptz+n*interval '1 second'
  from generate_series(1,26) n;
insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
  select pg_temp.room(n),pg_temp.person(2),'membership',m.id,0,0
  from generate_series(1,26) n cross join private.group_memberships m
  where m.group_id=pg_temp.grp(1) and m.profile_id=pg_temp.person(2);
update private.group_discussions set last_sequence=1 where id=pg_temp.room(26);
insert into private.group_discussion_messages(room_id,sequence,sender_id,body)
  values(pg_temp.room(26),1,pg_temp.person(1),'Private fixture message never belongs in a destination row.');
insert into private.group_discussions(id,group_id,creator_id,title,kind,visibility)
  select pg_temp.room(0),pg_temp.grp(1),pg_temp.person(1),'General','general','group'
  where not exists(select 1 from private.group_discussions where group_id=pg_temp.grp(1) and kind='general');
-- Thirty newer restricted rooms must not consume the ordinary actor's page.
insert into private.group_discussions(id,group_id,creator_id,title,purpose,visibility,created_at)
  select pg_temp.room(n),pg_temp.grp(1),pg_temp.person(1),'Restricted synthetic Idea '||n,
    'Restricted purpose.','invitation','2026-10-20 12:00Z'::timestamptz+n*interval '1 second'
  from generate_series(101,130) n;
insert into private.group_discussions(id,group_id,creator_id,title,visibility,archived)
  values(pg_temp.room(201),pg_temp.grp(1),pg_temp.person(1),'Archived synthetic Idea','group',true);
insert into private.group_discussions(id,group_id,creator_id,title,visibility,frozen_at)
  values(pg_temp.room(202),pg_temp.grp(1),pg_temp.person(1),'Frozen synthetic Idea','group',clock_timestamp());
create temp table selector_results(kind text primary key,value jsonb);
grant all on selector_results to authenticated;
grant execute on function pg_temp.person(integer),pg_temp.grp(integer),pg_temp.room(integer) to authenticated;

select is((select count(*) from private.group_memberships where profile_id in(pg_temp.person(1),pg_temp.person(5))),0::bigint,
  'Manager test actors have no ordinary membership');
select is((select count(*) from private.group_discussion_admissions where profile_id in(pg_temp.person(1),pg_temp.person(5))),0::bigint,
  'Manager test actors have no actual Idea admission');
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(5)::text,true);
insert into selector_results values('manager',public.list_group_discussion_invite_destinations(pg_temp.person(5),pg_temp.grp(1),pg_temp.person(3)));
select is(jsonb_array_length((select value from selector_results where kind='manager')),25,
  'Current Co-organizer oversight can select without membership/admission');
select is((select value->0->>'visibility' from selector_results where kind='manager'),'invitation',
  'Manager can invite to a restricted Idea');
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
insert into selector_results values('first',public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3)));
select is(jsonb_array_length((select value from selector_results where kind='first')),25,
  'Eligibility precedes limit despite thirty newer inaccessible Ideas');
select is((select value->0->>'room_id' from selector_results where kind='first'),pg_temp.room(26)::text,
  'First eligible page uses stable descending order');
insert into selector_results values('second',public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3),25,
  '2026-10-20 09:00:02Z',pg_temp.room(2)));
select is(jsonb_array_length((select value from selector_results where kind='second')),1,
  'Compound cursor reaches the final eligible destination');
select is((select value->0->>'room_id' from selector_results where kind='second'),pg_temp.room(1)::text,
  'Second page does not duplicate or skip the final room');
select is((select array_agg(key order by key) from jsonb_object_keys((select value->0 from selector_results where kind='first')) key),
  array['created_at','group_id','purpose','room_id','target_profile_id','title','visibility'],
  'Projection contains only seven allowed metadata fields');
select is(public.get_own_message_unread_summary_with_contacts_and_discussions(pg_temp.person(2)),
  jsonb_build_object('total',1,'private',0,'groups',1),
  'Combined canonical counts include the human C room once; selector reads never ACK it');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(1),pg_temp.grp(1),pg_temp.person(3))$$,
  '42501',null,'Body identity cannot replace the JWT actor');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(2),pg_temp.person(3))$$,
  '42501',null,'Another Group context cannot disclose destinations');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(4))$$,
  '42501',null,'An outsider cannot be a selected Group person');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(2))$$,
  '22023',null,'A person cannot invite themselves');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3),0)$$,
  '22023',null,'Unbounded/empty limit is rejected');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3),51)$$,
  '22023',null,'Limit above the canonical page maximum is rejected');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3),25,null,pg_temp.room(1))$$,
  '22023',null,'A partial compound cursor is rejected');
select set_config('request.jwt.claim.sub',pg_temp.person(3)::text,true);
select is(public.list_group_discussion_invite_destinations(pg_temp.person(3),pg_temp.grp(1),pg_temp.person(2)),'[]'::jsonb,
  'A current Group person with no invite permission gets a legitimate empty page');
reset role;

insert into private.group_discussion_invitations(room_id,inviter_id,recipient_id,inviter_admission_id,source_kind,source_id)
  select pg_temp.room(1),pg_temp.person(2),pg_temp.person(3),a.id,'membership',m.id
  from private.group_discussion_admissions a cross join private.group_memberships m
  where a.room_id=pg_temp.room(1) and a.profile_id=pg_temp.person(2)
    and m.group_id=pg_temp.grp(1) and m.profile_id=pg_temp.person(3);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
select is(public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3),25,
  '2026-10-20 09:00:02Z',pg_temp.room(2)),'[]'::jsonb,'An available pending invitation removes its destination');
reset role;
update private.group_discussion_admissions set ended_at=clock_timestamp(),ended_by=pg_temp.person(2)
  where room_id=pg_temp.room(1) and profile_id=pg_temp.person(2);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
select is(jsonb_array_length(public.list_group_discussion_invite_destinations(pg_temp.person(1),pg_temp.grp(1),pg_temp.person(3),25,
  '2026-10-20 09:00:02Z',pg_temp.room(2))),1,
  'A stale unavailable pending invitation does not hide a manager destination');
reset role;
insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
  select pg_temp.room(26),pg_temp.person(3),'membership',m.id,0,0 from private.group_memberships m
  where m.group_id=pg_temp.grp(1) and m.profile_id=pg_temp.person(3);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
select ok(not exists(select 1 from jsonb_array_elements(public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3))) item
  where item->>'room_id'=pg_temp.room(26)::text),'An already admitted target is excluded');
select lives_ok($$select public.block_user(p_expected_blocker_profile_id=>pg_temp.person(2),p_blocked_profile_id=>pg_temp.person(3))$$,'Canonical Block completes');
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3))$$,
  '42501',null,'Block immediately removes invitation eligibility');
select lives_ok($$select public.unblock_user(p_expected_blocker_profile_id=>pg_temp.person(2),p_blocked_profile_id=>pg_temp.person(3))$$,'Canonical Unblock completes');
select ok(jsonb_array_length(public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3)))>0,
  'Unblock restores independently valid invitation eligibility');
reset role;
update private.group_memberships set ended_at=clock_timestamp(),ended_by=pg_temp.person(3),end_reason='left'
  where group_id=pg_temp.grp(1) and profile_id=pg_temp.person(3) and ended_at is null;
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(2),pg_temp.grp(1),pg_temp.person(3))$$,
  '42501',null,'Losing the target origin relationship revokes the selector');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
select ok(jsonb_array_length(public.list_group_discussion_invite_destinations(pg_temp.person(1),pg_temp.grp(1),pg_temp.person(6)))>0,
  'The second target has a current People grant before profile removal');
reset role;
-- Use a separate synthetic target with no Block audit provenance. The earlier
-- actors' restrictive historical Block FKs must remain untouched.
delete from public.profiles where id=pg_temp.person(6);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
select throws_ok($$select public.list_group_discussion_invite_destinations(pg_temp.person(1),pg_temp.grp(1),pg_temp.person(6))$$,
  '42501',null,'A removed target profile has no current People grant');
reset role;
select * from finish();
rollback;
