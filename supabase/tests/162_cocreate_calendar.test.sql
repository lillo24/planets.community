begin;
select no_plan();

select ok(has_function_privilege('authenticated',
 'public.get_cocreate_calendar_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,text)','EXECUTE'),'admitted API is available to authenticated');
select ok(not has_function_privilege(role,
 'public.get_cocreate_calendar_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,text)','EXECUTE'),role||' has no calendar grant')
 from unnest(array['anon','service_role']) role;
select is((select provolatile::text from pg_proc where oid='public.get_cocreate_calendar_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,text)'::regprocedure),'s','calendar is a stable read');
create function pg_temp.cal_actor(n integer) returns uuid language sql immutable as $$
 select ('ca010000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.cal_as(n integer) returns uuid language plpgsql as $$
begin perform set_config('request.jwt.claim.sub',pg_temp.cal_actor(n)::text,true);return pg_temp.cal_actor(n);end;
$$;
insert into auth.users(id,email) select pg_temp.cal_actor(n),'calendar-'||n||'@planets.invalid' from generate_series(1,7)n;
insert into public.profiles(id,display_name) select pg_temp.cal_actor(n),'Synthetic calendar tester '||n from generate_series(1,7)n;
insert into private.policy_acceptances(account_id,bundle_version) select pg_temp.cal_actor(n),'POLICY01-2026-10-08-v1' from generate_series(1,7)n;
update private.cocreate_settings set enabled=true;
select set_config('cal.proposal',(public.propose_cocreate_community(pg_temp.cal_as(1),gen_random_uuid(),
 'videogames','Synthetic calendar Valorant','Synthetic calendar locality')->>'proposal_id'),true);
select public.mutate_cocreate_community_interest(pg_temp.cal_as(2),gen_random_uuid(),current_setting('cal.proposal')::uuid,'interest');
select public.mutate_cocreate_community_interest(pg_temp.cal_as(3),gen_random_uuid(),current_setting('cal.proposal')::uuid,'interest');
select set_config('cal.hub',public.get_cocreate_community_proposal(current_setting('cal.proposal')::uuid)->>'hub_id',true);
create temp table cal_admissions(actor integer primary key, membership jsonb);
insert into cal_admissions select n,public.mutate_cocreate_hub(pg_temp.cal_as(n),gen_random_uuid(),current_setting('cal.hub')::uuid,'join')
 from unnest(array[1,2,3,4,6,7])n;
select set_config('cal.start',date_trunc('day',statement_timestamp())::text,true);
select set_config('cal.end',(date_trunc('day',statement_timestamp())+interval '31 days')::text,true);
create function pg_temp.cal_read(n integer,lim integer default 25,cur text default null) returns jsonb language plpgsql as $$
declare member jsonb;begin
 select membership into member from cal_admissions where actor=n;
 if member is null then select membership into member from cal_admissions where actor=1;end if;
 return public.get_cocreate_calendar_v1(pg_temp.cal_as(n),current_setting('cal.hub')::uuid,
  (member->>'room_id')::uuid,(member->>'episode_id')::uuid,
  current_setting('cal.start')::timestamptz,current_setting('cal.end')::timestamptz,lim,cur);
end; $$;
create temp table cal_meetings(key text primary key,result jsonb);
insert into cal_meetings values ('valorant',public.schedule_cocreate_meeting(pg_temp.cal_as(1),gen_random_uuid(),
 current_setting('cal.hub')::uuid,current_setting('cal.start')::timestamptz+interval '2 days 18 hours',7));
insert into cal_meetings values ('lupus',public.schedule_cocreate_meeting(pg_temp.cal_as(3),gen_random_uuid(),
 current_setting('cal.hub')::uuid,current_setting('cal.start')::timestamptz+interval '2 days 18 hours',2));
create temp table cal_members(actor integer,room_key text,result jsonb);
insert into cal_members select n,'valorant',public.join_cocreate_recruitment(pg_temp.cal_as(n),gen_random_uuid(),
 current_setting('cal.hub')::uuid,(result->>'room_id')::uuid,(result->>'recruitment_id')::uuid)
 from cal_meetings cross join unnest(array[2,3,4])n where key='valorant';
insert into cal_members select 2,'lupus',public.join_cocreate_recruitment(pg_temp.cal_as(2),gen_random_uuid(),
 current_setting('cal.hub')::uuid,(result->>'room_id')::uuid,(result->>'recruitment_id')::uuid) from cal_meetings where key='lupus';
-- Five chat members, four attendees: the calendar must count the meeting.
insert into cal_members select 6,'valorant',public.mutate_cocreate_numbered_group(pg_temp.cal_as(6),gen_random_uuid(),
 current_setting('cal.hub')::uuid,'join',(result->>'room_id')::uuid) from cal_meetings where key='valorant';
select is(jsonb_array_length(pg_temp.cal_read(6)->'meetings'),2,'two groups on one day appear once each');
select is((select x->>'occupied' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'4','calendar uses 4/7 meeting occupancy, not five chat memberships');
select is((select x->>'can_confirm' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'true','current chat member can confirm separately');
select is((select x->>'attending' from jsonb_array_elements(pg_temp.cal_read(4)->'meetings')x where x->>'capacity'='7'),'true','viewer attendance is explicit');
select is((select x->>'can_join' from jsonb_array_elements(pg_temp.cal_read(4)->'meetings')x where x->>'capacity'='2'),'false','full meeting has no newcomer admission');
select is((select x->>'occupied' from jsonb_array_elements(pg_temp.cal_read(4)->'meetings')x where x->>'capacity'='2'),'2','full meeting remains readable');
select is((select x->>'attending' from jsonb_array_elements(pg_temp.cal_read(2)->'meetings')x where x->>'capacity'='2'),'true','full meeting still exposes own attendance review');
select set_config('cal.page1',pg_temp.cal_read(6,1)::text,true);
select is(jsonb_array_length(current_setting('cal.page1')::jsonb->'meetings'),1,'server respects page size');
select ok(current_setting('cal.page1')::jsonb->>'next_cursor' is not null,'a real continuation exists');
select set_config('cal.page2',pg_temp.cal_read(6,1,current_setting('cal.page1')::jsonb->>'next_cursor')::text,true);
select isnt(current_setting('cal.page1')::jsonb->'meetings'->0->>'meeting_id',current_setting('cal.page2')::jsonb->'meetings'->0->>'meeting_id','equal-instant cursor uses meeting UUID tie breaker');
select is(current_setting('cal.page2')::jsonb->>'next_cursor',null::text,'complete pagination terminates exactly');
select throws_ok($$select pg_temp.cal_read(4,1,current_setting('cal.page1')::jsonb->>'next_cursor')$$,'22023',null,'cursor cannot cross actors');
select throws_ok($$select pg_temp.cal_read(6,2,current_setting('cal.page1')::jsonb->>'next_cursor')$$,'22023',null,'cursor cannot change page scope');
select throws_ok($$select pg_temp.cal_read(6,1,'{}')$$,'22023',null,'empty cursor rejected');
select throws_ok($$select pg_temp.cal_read(6,1,'garbage')$$,'22023',null,'malformed cursor rejected');
select throws_ok($$select pg_temp.cal_read(6,1,'[]')$$,'22023',null,'array cursor rejected explicitly');
select throws_ok($$select pg_temp.cal_read(6,1,'null')$$,'22023',null,'null cursor rejected explicitly');
select throws_ok($$select pg_temp.cal_read(6,0)$$,'22023',null,'zero page size rejected');
select throws_ok($$select pg_temp.cal_read(6,51)$$,'22023',null,'unbounded page size rejected');
select set_config('cal.saved_end',current_setting('cal.end'),true);
select set_config('cal.end',(current_setting('cal.start')::timestamptz+interval '63 days')::text,true);
select throws_ok($$select pg_temp.cal_read(6)$$,'22023',null,'window beyond 62 days rejected');
select set_config('cal.end',current_setting('cal.saved_end'),true);
select set_config('cal.saved_start',current_setting('cal.start'),true);
select set_config('cal.start',(current_setting('cal.start')::timestamptz+interval '1 hour')::text,true);
select throws_ok($$select pg_temp.cal_read(6,1,current_setting('cal.page1')::jsonb->>'next_cursor')$$,'22023',null,'cursor bound to exact UTC window');
select set_config('cal.start',current_setting('cal.saved_start'),true);
select throws_ok($$select pg_temp.cal_read(5)$$,'42501',null,'outsider never obtains an implicit community admission');
select is((select count(*)::int from private.cocreate_room_episodes where actor_id=pg_temp.cal_actor(5)),0,'read did not enroll outsider');

-- No chat bodies, manager identity, roster, read token, ACK, or hidden totals.
select is((select count(*)::int from jsonb_object_keys(pg_temp.cal_read(6))),8,'closed envelope contains only scope, rows and continuation');
select is((select count(*)::int from jsonb_object_keys(pg_temp.cal_read(6)->'meetings'->0)),12,'closed meeting allowlist excludes private metadata');
select set_config('cal.acks',(select jsonb_agg(jsonb_build_array(id,read_sequence) order by id)::text from private.cocreate_room_episodes),true);
select pg_temp.cal_read(6);
select is((select jsonb_agg(jsonb_build_array(id,read_sequence) order by id)::text from private.cocreate_room_episodes),current_setting('cal.acks'),'calendar never advances read/unread state');

-- An expired invitation does not expire a still-future meeting or member RSVP.
-- FIX01 review keeps meeting/card availability distinct from actor admission.
create function pg_temp.cal_review(n integer,key text default 'valorant') returns jsonb language plpgsql as $$
declare member jsonb;card uuid;begin
 select membership into member from cal_admissions where actor=n;
 select (result->>'recruitment_id')::uuid into card from cal_meetings where cal_meetings.key=cal_review.key;
 return public.get_cocreate_recruitment_review_v1(pg_temp.cal_as(n),
  (member->>'room_id')::uuid,(member->>'episode_id')::uuid,card);
end; $$;
select is(pg_temp.cal_review(7)->>'can_join','true','fresh eligible review allows deliberate command');
select ok(has_function_privilege('authenticated','public.get_cocreate_recruitment_review_v1(uuid,uuid,uuid,uuid)','EXECUTE'),'review available to authenticated actors');
select ok(not has_function_privilege(role,'public.get_cocreate_recruitment_review_v1(uuid,uuid,uuid,uuid)','EXECUTE'),role||' has no review grant')
 from unnest(array['anon','service_role'])role;
select ok(not has_function_privilege('authenticated','private.cocreate_can_join_recruitment(uuid,uuid)','EXECUTE'),'eligibility helper has no direct client grant');
select is((select count(*)::int from jsonb_object_keys(pg_temp.cal_review(7))),6,'review has its own closed actor-scoped envelope');
select is(pg_temp.cal_review(7)->'recruitment',public.get_cocreate_recruitment_v2(pg_temp.cal_as(7),
 (membership->>'room_id')::uuid,(membership->>'episode_id')::uuid,
 (select (result->>'recruitment_id')::uuid from cal_meetings where key='valorant')),
 'installed eleven-field card payload remains unchanged') from cal_admissions where actor=7;
update private.cocreate_rooms set capacity=5 where id=(select (result->>'room_id')::uuid from cal_meetings where key='valorant');
select is(pg_temp.cal_review(7)->>'can_join','false','full persistent chat denies newcomer with meeting seats');
select is(pg_temp.cal_review(7)->'recruitment'->>'available','true','meeting with seats is not mislabeled full');
select throws_ok($$select public.join_cocreate_recruitment(pg_temp.cal_as(7),gen_random_uuid(),current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'recruitment_id')::uuid) from cal_meetings where key='valorant'$$,'PT409',null,'atomic command independently denies full chat');
update private.cocreate_rooms set capacity=50 where id=(select (result->>'room_id')::uuid from cal_meetings where key='valorant');
update private.cocreate_settings set max_numbered_memberships=1;
select is(pg_temp.cal_review(7)->>'can_join','true','viewer below membership limit stays eligible');
-- Actor 6 has one chat, whereas actor 7 remains General-only.
update private.cocreate_meeting_attendance set attending=false where actor_id=pg_temp.cal_actor(2)
 and meeting_id=(select (result->>'meeting_id')::uuid from cal_meetings where key='lupus');
select is(pg_temp.cal_review(6,'lupus')->'recruitment'->>'available','true','membership-limit review still has meeting seats');
select is(pg_temp.cal_review(6,'lupus')->>'can_join','false','viewer membership limit denies ordinary review action');
update private.cocreate_meeting_attendance set attending=true where actor_id=pg_temp.cal_actor(2)
 and meeting_id=(select (result->>'meeting_id')::uuid from cal_meetings where key='lupus');
update private.cocreate_settings set max_numbered_memberships=50;
select is((select count(*)::int from private.cocreate_room_episodes where actor_id=pg_temp.cal_actor(7)),1,'review never admits a viewer');
select is((select count(*)::int from private.cocreate_meeting_attendance where actor_id=pg_temp.cal_actor(7)),0,'review never creates attendance');

-- Current-member authority survives both block directions and a decline.
select public.block_user(pg_temp.cal_as(2),pg_temp.cal_actor(1));
select is((select x->>'attending' from jsonb_array_elements(pg_temp.cal_read(2)->'meetings')x where x->>'capacity'='7'),'true','blocked creator does not erase current-member attendance');
select is(public.get_cocreate_current_meeting(pg_temp.cal_as(2),(result->>'room_id')::uuid,(result->>'episode_id')::uuid)->>'attending','true','canonical current review agrees while blocked') from cal_members where actor=2 and room_key='valorant';
select set_config('cal.decline',gen_random_uuid()::text,true);
select public.mutate_cocreate_meeting(pg_temp.cal_as(2),current_setting('cal.decline')::uuid,current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'episode_id')::uuid,(select (result->>'meeting_id')::uuid from cal_meetings where key='valorant'),'decline')
 from cal_members where actor=2 and room_key='valorant';
select public.mutate_cocreate_meeting(pg_temp.cal_as(2),current_setting('cal.decline')::uuid,current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'episode_id')::uuid,(select (result->>'meeting_id')::uuid from cal_meetings where key='valorant'),'decline')
 from cal_members where actor=2 and room_key='valorant';
select is((select x->>'occupied' from jsonb_array_elements(pg_temp.cal_read(2)->'meetings')x where x->>'capacity'='7'),'3','blocked decline releases exactly one place');
select is((select x->>'can_confirm' from jsonb_array_elements(pg_temp.cal_read(2)->'meetings')x where x->>'capacity'='7'),'true','declined current member retains canonical review/confirm authority');
select public.mutate_cocreate_meeting(pg_temp.cal_as(2),gen_random_uuid(),current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'episode_id')::uuid,(select (result->>'meeting_id')::uuid from cal_meetings where key='valorant'),'attend')
 from cal_members where actor=2 and room_key='valorant';
select public.unblock_user(pg_temp.cal_as(2),pg_temp.cal_actor(1));
select public.block_user(pg_temp.cal_as(1),pg_temp.cal_actor(2));
select is((select x->>'attending' from jsonb_array_elements(pg_temp.cal_read(2)->'meetings')x where x->>'capacity'='7'),'true','reverse block preserves exact current episode review');
select public.unblock_user(pg_temp.cal_as(1),pg_temp.cal_actor(2));
select public.block_user(pg_temp.cal_as(7),pg_temp.cal_actor(1));
select is(jsonb_array_length(pg_temp.cal_read(7)->'meetings'),1,'blocked card-only viewer contributes no row or continuation');
select is(pg_temp.cal_review(7)->>'can_join','false','blocked card-only review cannot join');
select throws_ok($$select public.join_cocreate_recruitment(pg_temp.cal_as(7),gen_random_uuid(),current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'recruitment_id')::uuid) from cal_meetings where key='valorant'$$,'42501',null,'blocked newcomer command remains denied');
select public.unblock_user(pg_temp.cal_as(7),pg_temp.cal_actor(1));
update auth.users set banned_until=statement_timestamp()+interval '1 day' where id=pg_temp.cal_actor(1);
select is((select x->>'can_confirm' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'true','nonattending current member retains review during creator unavailability');
select is(jsonb_array_length(pg_temp.cal_read(7)->'meetings'),1,'unavailable creator still omitted for card-only viewer');
update auth.users set banned_until=null where id=pg_temp.cal_actor(1);
select public.block_user(pg_temp.cal_as(6),pg_temp.cal_actor(1));
select public.mutate_cocreate_numbered_group(pg_temp.cal_as(6),gen_random_uuid(),current_setting('cal.hub')::uuid,
 'leave',(result->>'room_id')::uuid,(result->>'episode_id')::uuid) from cal_members where actor=6 and room_key='valorant';
select is(jsonb_array_length(pg_temp.cal_read(6)->'meetings'),1,'ended membership cannot retain blocked calendar exception');
select throws_ok($$select public.get_cocreate_current_meeting(pg_temp.cal_as(6),
 (result->>'room_id')::uuid,(result->>'episode_id')::uuid) from cal_members where actor=6 and room_key='valorant'$$,
 '42501',null,'old exact episode loses canonical current-meeting review');
select public.unblock_user(pg_temp.cal_as(6),pg_temp.cal_actor(1));
select public.mutate_cocreate_numbered_group(pg_temp.cal_as(6),gen_random_uuid(),current_setting('cal.hub')::uuid,
 'join',(result->>'room_id')::uuid) from cal_meetings where key='valorant';

update private.cocreate_recruitments set created_at=statement_timestamp()-interval '8 days',expires_at=statement_timestamp()-interval '1 second'
 where id=(select (result->>'recruitment_id')::uuid from cal_meetings where key='valorant');
select is((select x->>'can_confirm' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'true','member can confirm after recruitment expiry');
select public.mutate_cocreate_meeting(pg_temp.cal_as(2),gen_random_uuid(),current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'episode_id')::uuid,(select (result->>'meeting_id')::uuid from cal_meetings where key='lupus'),'decline')
 from cal_members where actor=2 and room_key='lupus';
select is((select x->>'can_join' from jsonb_array_elements(pg_temp.cal_read(4)->'meetings')x where x->>'capacity'='2'),'true','decline reopens a place without leaving chat');

-- Former General episode sees only its own frontier and has no new authority.
select public.mutate_cocreate_hub(pg_temp.cal_as(4),gen_random_uuid(),current_setting('cal.hub')::uuid,'leave',
 (membership->>'episode_id')::uuid) from cal_admissions where actor=4;
insert into cal_meetings values ('later',public.schedule_cocreate_meeting(pg_temp.cal_as(2),gen_random_uuid(),
 current_setting('cal.hub')::uuid,current_setting('cal.start')::timestamptz+interval '3 days 18 hours',5));
select is(pg_temp.cal_review(4)->>'can_join','false','former General review remains historical without new admission');
select throws_ok($$select pg_temp.cal_review(4,'later')$$,'42501',null,'new review cannot cross exact frozen General history');
select is(jsonb_array_length(pg_temp.cal_read(4)->'meetings'),2,'former episode cannot see a later card through aggregation or count');
select ok(not exists(select 1 from jsonb_array_elements(pg_temp.cal_read(4)->'meetings')x where (x->>'can_join')::boolean or (x->>'can_confirm')::boolean or (x->>'attending')::boolean),'former history does not grant fresh attendance');
select public.mutate_cocreate_meeting(pg_temp.cal_as(1),gen_random_uuid(),current_setting('cal.hub')::uuid,
 (result->>'room_id')::uuid,(result->>'episode_id')::uuid,(result->>'meeting_id')::uuid,'repost') from cal_meetings where key='valorant';
select is(jsonb_array_length(pg_temp.cal_read(6)->'meetings'),3,'repost is deduplicated by canonical meeting ID');
select isnt((select x->>'recruitment_id' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),
 (select result->>'recruitment_id' from cal_meetings where key='valorant'),'current eligible repost is preferred');
select is((select x->>'recruitment_id' from jsonb_array_elements(pg_temp.cal_read(4)->'meetings')x where x->>'capacity'='7'),
 (select result->>'recruitment_id' from cal_meetings where key='valorant'),'repost outside frozen frontier cannot replace permitted old card');
insert into cal_members select 6,'later',public.join_cocreate_recruitment(pg_temp.cal_as(6),gen_random_uuid(),
 current_setting('cal.hub')::uuid,(result->>'room_id')::uuid,(result->>'recruitment_id')::uuid) from cal_meetings where key='later';
select throws_ok($$select pg_temp.cal_read(6,1,current_setting('cal.page1')::jsonb->>'next_cursor')$$,'22023',null,'membership changes invalidate continuation scope');

-- A meeting with no authorized card is visible only in its current room review.
select set_config('cal.hidden_room',public.mutate_cocreate_numbered_group(pg_temp.cal_as(1),gen_random_uuid(),current_setting('cal.hub')::uuid,'create',p_capacity=>50)::text,true);
insert into private.cocreate_meetings(room_id,creator_id,starts_at,capacity)
 values((current_setting('cal.hidden_room')::jsonb->>'room_id')::uuid,pg_temp.cal_actor(1),current_setting('cal.start')::timestamptz+interval '4 days',7);
select is(jsonb_array_length(pg_temp.cal_read(6)->'meetings'),3,'General membership alone cannot reveal private meeting');
select is(jsonb_array_length(pg_temp.cal_read(1)->'meetings'),4,'current numbered episode retains permitted meeting review');
update private.cocreate_rooms set suppressed=true where id=(select (result->>'room_id')::uuid from cal_meetings where key='valorant');
select is(jsonb_array_length(pg_temp.cal_read(6)->'meetings'),2,'suppression removes row and its markers/count source');
update private.cocreate_rooms set suppressed=false where id=(select (result->>'room_id')::uuid from cal_meetings where key='valorant');
update private.cocreate_meetings set cancelled_at=clock_timestamp() where id=(select (result->>'meeting_id')::uuid from cal_meetings where key='valorant');
select is((select x->>'state' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'cancelled','cancellation is an explicit readable lifecycle');
select is((select x->>'can_confirm' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'false','cancelled meeting cannot confirm');
update private.cocreate_meetings set cancelled_at=null,created_at=statement_timestamp()-interval '3 days',starts_at=statement_timestamp()-interval '1 second'
 where id=(select (result->>'meeting_id')::uuid from cal_meetings where key='valorant');
select is((select x->>'state' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'past','past meeting remains a separate neutral state');
select is((select x->>'can_confirm' from jsonb_array_elements(pg_temp.cal_read(6)->'meetings')x where x->>'capacity'='7'),'false','past meeting cannot confirm');

-- A real second community cannot substitute its hub into the first admission.
select set_config('cal.other_proposal',public.propose_cocreate_community(pg_temp.cal_as(1),gen_random_uuid(),
 'boardgames','Synthetic calendar Lupus','Synthetic other locality')->>'proposal_id',true);
select public.mutate_cocreate_community_interest(pg_temp.cal_as(2),gen_random_uuid(),current_setting('cal.other_proposal')::uuid,'interest');
select public.mutate_cocreate_community_interest(pg_temp.cal_as(3),gen_random_uuid(),current_setting('cal.other_proposal')::uuid,'interest');
select set_config('cal.other_hub',public.get_cocreate_community_proposal(current_setting('cal.other_proposal')::uuid)->>'hub_id',true);
select throws_ok($$select public.get_cocreate_calendar_v1(pg_temp.cal_as(6),current_setting('cal.other_hub')::uuid,
 (membership->>'room_id')::uuid,(membership->>'episode_id')::uuid,current_setting('cal.start')::timestamptz,current_setting('cal.end')::timestamptz)
 from cal_admissions where actor=6$$,'42501',null,'cross-hub admission cannot reveal a different community calendar');
select throws_ok($$select public.get_cocreate_calendar_v1(pg_temp.cal_as(6),current_setting('cal.hub')::uuid,
 (membership->>'room_id')::uuid,(membership->>'episode_id')::uuid,current_setting('cal.start')::timestamptz,current_setting('cal.end')::timestamptz)
 from cal_admissions where actor=1$$,'42501',null,'another actor episode cannot replace exact admission');
update private.cocreate_categories set active=false where id='videogames';
select throws_ok($$select pg_temp.cal_read(6)$$,'42501',null,'disabled category immediately denies calendar');
update private.cocreate_categories set active=true where id='videogames';
delete from private.policy_acceptances where account_id=pg_temp.cal_actor(6);
select throws_ok($$select pg_temp.cal_read(6)$$,'42501',null,'policy loss immediately denies calendar');
insert into private.policy_acceptances(account_id,bundle_version) values(pg_temp.cal_actor(6),'POLICY01-2026-10-08-v1');
update private.cocreate_settings set enabled=false;
select throws_ok($$select pg_temp.cal_read(6)$$,'42501',null,'experiment OFF fails closed');
select * from finish();
rollback;
