begin;
select no_plan();
-- MAP04 fixture begin
create or replace function pg_temp.map04_place(lat double precision,lon double precision,p_precision text default 'locality')
returns jsonb language sql as $$
 select jsonb_build_object('provider','geoapify','kind',p_precision,
 'result_type',case p_precision when 'locality' then 'city' when 'address' then 'building' else 'amenity' end,
 'label','MAP04 Synthetic Trento','country_code','IT','locality','Trento',
 'latitude',lat,'longitude',lon,'source','openstreetmap',
 'attribution','Powered by Geoapify | © OpenStreetMap contributors',
 'source_license','https://www.openstreetmap.org/copyright','verified_at','2026-10-01T00:00:00Z');
$$;
insert into auth.users(id,email) values
 ('a9410000-0000-4000-8000-000000000001','map04-owner@planets.invalid'),
 ('a9410000-0000-4000-8000-000000000002','map04-member@planets.invalid') on conflict(id) do nothing;
insert into public.profiles(id,display_name) values
 ('a9410000-0000-4000-8000-000000000001','MAP04 synthetic owner'),
 ('a9410000-0000-4000-8000-000000000002','MAP04 synthetic member') on conflict(id) do nothing;
insert into public.proposals(id,creator_profile_id,title,summary,description,starts_at,ends_at,event_timezone,country_code,locality,public_location_label,selected_public_place,approximate_location)
 select ('a9420000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'a9410000-0000-4000-8000-000000000001','MAP04 Garden '||i,'Synthetic keyword summary','Synthetic descriptive token',
 case when i=7 then now()-interval '2 hours' when i=8 then now()-interval '26 hours' else now()+interval '1 day' end,
 case when i=7 then now()-interval '1 hour' when i=8 then now()-interval '25 hours' else now()+interval '2 days' end,
 'Europe/Rome','IT','Trento','MAP04 Synthetic Trento',
 case when i in (3,4) then null else pg_temp.map04_place(case when i=9 then 46.5 else 46.07 end,11.12) end,
 case when i=3 then null else private.selected_place_point(pg_temp.map04_place(case when i=9 then 46.5 else 46.07 end,11.12)) end
 from generate_series(1,9) i;
update public.projects set registration_capacity=10 where id::text like 'a9420000-%';
update public.proposals set lifecycle_state=case when right(id::text,1)='6' then 'cancelled' else 'published' end,
 published_at=now()-interval '1 hour',cancelled_at=case when right(id::text,1)='6' then now() else null end
 where id::text like 'a9420000-%' and right(id::text,1)<>'5';
insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility,exact_location)
 select id,'MAP04 PRIVATE INSTRUCTIONS','participants',private.selected_place_point(pg_temp.map04_place(case when right(id::text,1)='1' then -33.86 else 46.07001 end,case when right(id::text,1)='1' then 151.21 else 11.12001 end,'address'))
 from public.proposals where id::text like 'a9420000-%';
insert into public.proposal_skills(proposal_id,skill_id,importance)
 select 'a9420000-0000-4000-8000-000000000001',id,'required' from public.skills order by id limit 1;
insert into public.recurring_activities(id,creator_profile_id,title,summary,description,topic,country_code,locality,public_location_label,selected_public_place,approximate_location)
 select ('a9440000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'a9410000-0000-4000-8000-000000000001',
 'MAP04 Tavolo '||i,'Synthetic summary','Synthetic description','Gardening','IT','Trento','MAP04 Synthetic Trento',
 pg_temp.map04_place(46.07,11.12),private.selected_place_point(pg_temp.map04_place(46.07,11.12)) from generate_series(1,5)i;
update public.projects set registration_capacity=10 where id::text like 'a9440000-%';
insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from)
 select id,'weekly',1,'12:00',60,'Europe/Rome',current_date from public.recurring_activities where id::text like 'a9440000-%' and right(id::text,1)<>'5';
update public.recurring_activities set lifecycle_state=case right(id::text,1) when '2' then 'paused' when '3' then 'ended' else 'published' end,
 published_at=now()-interval '1 hour',paused_at=case when right(id::text,1)='2' then now() else null end,
 ended_at=case when right(id::text,1)='3' then now() else null end
 where id::text like 'a9440000-%' and right(id::text,1)<>'4';
insert into public.resource_listings(id,owner_profile_id,listing_mode,title,description,country_code,locality,public_location_label,selected_public_place,public_location)
 select ('a9430000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'a9410000-0000-4000-8000-000000000001',
 case when i=2 then 'exchange' else 'donate' end,'MAP04 Resource '||i,'Synthetic tools keyword',
 'IT','Trento','MAP04 Synthetic Trento',pg_temp.map04_place(46.07,11.12,case when i=1 then 'address' when i=2 then 'amenity' else 'locality' end),
 private.selected_place_point(pg_temp.map04_place(46.07,11.12)) from generate_series(1,5)i;
update public.resource_listings set lifecycle_state=case when right(id::text,1)='3' then 'closed' else 'published' end,
 published_at=now()-interval '1 hour',closed_at=case when right(id::text,1)='3' then now() else null end
 where id::text like 'a9430000-%' and right(id::text,1)<>'4';
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
 values('a9450000-0000-4000-8000-000000000001','a9420000-0000-4000-8000-000000000001','a9410000-0000-4000-8000-000000000002',
 'accepted',now()-interval '2 days',now()-interval '1 day','a9410000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
 values('a9460000-0000-4000-8000-000000000001','a9420000-0000-4000-8000-000000000001','a9410000-0000-4000-8000-000000000002','a9450000-0000-4000-8000-000000000001',now()-interval '1 day');
insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text,exact_location_visibility,exact_location)
 values('a9440000-0000-4000-8000-000000000001','MAP04 PRIVATE TAVOLO INSTRUCTIONS','participants',private.selected_place_point(pg_temp.map04_place(-33.86,151.21,'address')));
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
 values('a9450000-0000-4000-8000-000000000002','a9440000-0000-4000-8000-000000000001','a9410000-0000-4000-8000-000000000002',
 'accepted',now()-interval '2 days',now()-interval '1 day','a9410000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
 values('a9460000-0000-4000-8000-000000000002','a9440000-0000-4000-8000-000000000001','a9410000-0000-4000-8000-000000000002','a9450000-0000-4000-8000-000000000002',now()-interval '1 day');
-- MAP04 fixture end

create function pg_temp.map04_query() returns jsonb language sql as $$ select '{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000}'::jsonb||jsonb_build_object('reference_time',now()); $$;
select ok(has_function_privilege('anon','public.search_public_geography_v1(jsonb,integer,jsonb)','EXECUTE'),'Anonymous execute');
select ok(has_function_privilege('authenticated','public.search_public_geography_v1(jsonb,integer,jsonb)','EXECUTE'),'Authenticated execute');
select ok(not has_function_privilege('service_role','public.search_public_geography_v1(jsonb,integer,jsonb)','EXECUTE'),'Service role is not a reader');
select ok(not has_function_privilege('anon','private.geo_public_candidates_v1(jsonb,timestamptz,text,uuid)','EXECUTE'),'Internal spatial helper not exposed');
select ok(not has_table_privilege('anon','public.proposals','SELECT') and not has_table_privilege('authenticated','public.resource_listings','SELECT'),'No raw SELECT grants added');
select ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.search_public_geography_v1(jsonb,integer,jsonb)'::regprocedure),'Hardened definer');
select is((select count(*)::integer from pg_indexes where indexname like '%_map04_%' and indexdef like '%USING gist%'),6,'Six scoped spatial indexes');

grant execute on function pg_temp.map04_query() to anon,authenticated;
create temp table baseline as select public.search_public_geography_v1(pg_temp.map04_query()) value;
select is(jsonb_array_length((select value->'items' from baseline)),7,'Only legitimate public discoverable georeferences');
select is((select count(*)::integer from jsonb_array_elements((select value->'items' from baseline)) x where x->>'kind'='one_time'),3,'Two tied Projects and recently finished');
select is((select count(*)::integer from jsonb_array_elements((select value->'items' from baseline)) x where x->>'kind'='recurring'),1,'Published Tavolo with current next occurrence only');
select is((select count(*)::integer from jsonb_array_elements((select value->'items' from baseline)) x where x->>'kind'='resource'),3,'Only published resources');
select ok((select bool_and((x->>'is_approximate')::boolean and x->>'match_precision'='locality_reference') from jsonb_array_elements((select value->'items' from baseline)) x where x->>'kind'<>'resource'),'Projects/Tavoli approximate only');
select is((select x->>'precision' from jsonb_array_elements((select value->'items' from baseline)) x where x->>'item_id'='a9430000-0000-4000-8000-000000000001'),'address','Public address Resource precision');
select is((select x->>'precision' from jsonb_array_elements((select value->'items' from baseline)) x where x->>'item_id'='a9430000-0000-4000-8000-000000000002'),'amenity','Public amenity Resource precision');
select ok(not((select value::text from baseline)~'PRIVATE|exact_location|selected_|receipt|email|participant|distance|total_count|151.21'),'No protected fields, coordinates, distance or total count');
select is(public.search_public_geography_v1(pg_temp.map04_query()||'{"kinds":["resource"],"resource_mode":"exchange"}')->'items'->0->>'listing_mode','exchange','Exchange filter');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"kinds":["resource"],"resource_mode":"donate"}')->'items'),2,'Donate filter');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"proposal_keyword":"Garden 1","resource_keyword":"Resource 2"}')->'items'),3,'Keywords scoped to their supported families; Tavolo unaffected');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||jsonb_build_object('kinds',jsonb_build_array('one_time'),'proposal_skill_ids',jsonb_build_array((select id from public.skills order by id limit 1))))->'items'),1,'Proposal skill filter');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"tavolo_locality":"Elsewhere"}')->'items'),6,'Tavolo locality scoped to family');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"proposal_keyword":"%'' OR true --","resource_keyword":"%'' OR true --"}')->'items'),1,'Literal SQL/wildcard search safety');
select is(public.search_public_geography_v1('{"mode":"bounds","south":46.07,"north":46.08,"west":11.12,"east":11.13}'::jsonb||jsonb_build_object('reference_time',now()))->'items',(select value->'items' from baseline),'Inclusive box edge for points');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"radius_m":1}')->'items'),7,'One-meter radius matches public centers, not venue distances');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"latitude":-33.86,"longitude":151.21,"radius_m":1}')->'items'),0,'Tiny private address probe reveals no Project');
select is(jsonb_array_length(public.search_public_geography_v1('{"mode":"bounds","south":-33.87,"north":-33.85,"west":151.20,"east":151.22}')->'items'),0,'Negative-coordinate shifted private viewport reveals no Project');

-- Query-scoped mixed-kind pages: identical points/timestamps cannot affect ordering.
do $$ declare c jsonb; p jsonb; got jsonb:='[]'; i integer:=0; begin
 loop
  p:=public.search_public_geography_v1(pg_temp.map04_query(),2,c);
  got:=got||(p->'items'); i:=i+1;
  exit when not(p->>'has_more')::boolean;
  c:=p->'next_cursor';
  if i>10 then raise exception 'Pagination did not terminate'; end if;
 end loop;
 perform set_config('map04.pages',got::text,true);
end $$;
select is(current_setting('map04.pages')::jsonb,(select value->'items' from baseline),'All mixed-kind tied pages exactly equal one bounded page');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query()||'{"radius_m":2000}',2,public.search_public_geography_v1(pg_temp.map04_query(),2)->'next_cursor')$$,'22023',null,'Changed viewport rejects cursor');

-- Anon/current-member/removed-member and private visibility are equivalent.
set local role anon;
select is(public.search_public_geography_v1(pg_temp.map04_query())->'items',current_setting('map04.pages')::jsonb,'Anon sees exactly public references');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a9410000-0000-4000-8000-000000000002',true);
select is(public.search_public_geography_v1(pg_temp.map04_query())->'items',current_setting('map04.pages')::jsonb,'Current member sees same public references');
reset role;
update public.project_memberships set removed_at=now(),removed_by_profile_id='a9410000-0000-4000-8000-000000000001' where id in ('a9460000-0000-4000-8000-000000000001','a9460000-0000-4000-8000-000000000002');
update public.proposal_meeting_details set exact_location_visibility='public',exact_location=private.selected_place_point(pg_temp.map04_place(-20,-30,'address')) where proposal_id='a9420000-0000-4000-8000-000000000001';
update public.recurring_activity_meeting_details set exact_location_visibility='public',exact_location=private.selected_place_point(pg_temp.map04_place(-20,-30,'address')) where recurring_activity_id='a9440000-0000-4000-8000-000000000001';
set local role authenticated;
select is(public.search_public_geography_v1(pg_temp.map04_query())->'items',current_setting('map04.pages')::jsonb,'Removed member and public exact visibility cannot alter geo output');
reset role;
update public.proposals set selected_public_place=null,approximate_location=null where id='a9420000-0000-4000-8000-000000000001';
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query())->'items'),6,'Clearing selected public point immediately removes pin');
update public.resource_listings set selected_public_place=pg_temp.map04_place(-20,-30,'address'),public_location=private.selected_place_point(pg_temp.map04_place(-20,-30)) where id='a9430000-0000-4000-8000-000000000001';
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query())->'items'),5,'Changed public point immediately stops matching');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"latitude":-20,"longitude":-30,"radius_m":1}')->'items'),1,'Negative precise public Resource point matches new area');
select throws_ok($$select public.search_public_geography_v1(null)$$,'22023',null,'Reject Null object');
select throws_ok($$select public.search_public_geography_v1('{}'::jsonb)$$,'22023',null,'Reject Missing mode');
select throws_ok($$select public.search_public_geography_v1('{"mode":"nearby"}'::jsonb)$$,'22023',null,'Reject Unsupported mode');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":91,"longitude":11,"radius_m":1}'::jsonb)$$,'22023',null,'Reject Latitude');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46,"longitude":181,"radius_m":1}'::jsonb)$$,'22023',null,'Reject Longitude');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":"NaN","longitude":11,"radius_m":1}'::jsonb)$$,'22023',null,'Reject NaN string');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46,"longitude":11,"radius_m":0}'::jsonb)$$,'22023',null,'Reject Zero radius');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46,"longitude":11,"radius_m":100001}'::jsonb)$$,'22023',null,'Reject Oversized radius');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46,"longitude":11,"radius_m":1,"south":46}'::jsonb)$$,'22023',null,'Reject Mixed mode');
select throws_ok($$select public.search_public_geography_v1('{"mode":"bounds","south":47,"north":46,"west":11,"east":12}'::jsonb)$$,'22023',null,'Reject Reversed latitude');
select throws_ok($$select public.search_public_geography_v1('{"mode":"bounds","south":46,"north":47,"west":179,"east":-179}'::jsonb)$$,'22023',null,'Reject Antimeridian');
select throws_ok($$select public.search_public_geography_v1('{"mode":"bounds","south":46,"north":47,"west":-170,"east":170}'::jsonb)$$,'22023',null,'Reject Global longitude span');
select throws_ok($$select public.search_public_geography_v1('{"mode":"bounds","south":-1,"north":3,"west":0,"east":4}'::jsonb)$$,'22023',null,'Reject Viewport area cap');
select throws_ok($$select public.search_public_geography_v1('{"mode":"bounds","south":86,"north":87,"west":1,"east":2}'::jsonb)$$,'22023',null,'Reject Polar bounds');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46,"longitude":11,"radius_m":1,"srid":3857}'::jsonb)$$,'22023',null,'Reject Client SRID not accepted');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"kinds":[]}'::jsonb)$$,'22023',null,'Reject Empty kinds');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"kinds":["proposal"]}'::jsonb)$$,'22023',null,'Reject Unknown kind');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"kinds":[null]}'::jsonb)$$,'22023',null,'Reject Null kind');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"proposal_skill_ids":["not-uuid"]}'::jsonb)$$,'22023',null,'Reject Skill IDs');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"proposal_skill_ids":["a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001","a9410000-0000-4000-8000-000000000001"]}'::jsonb)$$,'22023',null,'Reject Skill array cap');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"resource_mode":"loan"}'::jsonb)$$,'22023',null,'Reject Unknown resource mode');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"proposal_keyword":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'::jsonb)$$,'22023',null,'Reject Keyword cap');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"reference_time":"infinity"}'::jsonb)$$,'22023',null,'Reject Infinite reference');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"reference_time":"2001-01-01T00:00:00Z"}'::jsonb)$$,'22023',null,'Reject Expired reference');
select throws_ok($$select public.search_public_geography_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"reference_time":"2100-01-01T00:00:00Z"}'::jsonb)$$,'22023',null,'Reject Future reference');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query(),51)$$,'22023',null,'Page cap');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query(),0)$$,'22023',null,'Zero page');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query(),20,'{}')$$,'22023',null,'Malformed cursor');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query(),20,'{"query_key":"x","reference_time":"now","kind":"one_time","item_id":"invalid"}')$$,'22023',null,'Invalid cursor tuple');
select is(jsonb_array_length(public.search_public_geography_v1(pg_temp.map04_query()||'{"latitude":11.12,"longitude":46.07,"radius_m":1}')->'items'),0,'Latitude and longitude never swapped');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query()||'{"kinds":null}')$$,'22023',null,'Null kinds reject');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query()||'{"proposal_skill_ids":{}}')$$,'22023',null,'Object skills reject');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query()||'{"resource_keyword":true}')$$,'22023',null,'Boolean keyword reject');
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query(),20,'[]')$$,'22023',null,'Array cursor reject');
-- Cross-family lifecycle parity against the existing canonical list RPCs.
select ok(not exists(select 1 from jsonb_array_elements(public.search_public_geography_v1(pg_temp.map04_query())->'items') x
 where x->>'kind'='one_time' and not exists(select 1 from public.list_public_proposals(50,null,null,'Trento',null,null) l where l.proposal_id=(x->>'item_id')::uuid)), 'Proposal list parity');
select ok(not exists(select 1 from jsonb_array_elements(public.search_public_geography_v1(pg_temp.map04_query())->'items') x
 where x->>'kind'='recurring' and not exists(select 1 from public.list_public_recurring_activities(now(),50,null,null,'Trento') l where l.recurring_activity_id=(x->>'item_id')::uuid and l.next_starts_at=(x->>'starts_at')::timestamptz)), 'Tavolo list and frozen occurrence parity');
select ok(not exists(select 1 from jsonb_array_elements(public.search_public_geography_v1(pg_temp.map04_query())->'items') x
 where x->>'kind'='resource' and not exists(select 1 from public.list_public_resource_listings(50,null,null,null,'Trento',null) l where l.listing_id=(x->>'item_id')::uuid)), 'Resource list parity');
insert into public.resource_listings(id,owner_profile_id,listing_mode,lifecycle_state,published_at,title,description,country_code,locality,public_location_label,selected_public_place,public_location)
 select ('a9470000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'a9410000-0000-4000-8000-000000000001','donate','published',now()-interval '1 hour',
 'MAP04 dense fixture','Synthetic density','IT','Trento','Synthetic Trento',pg_temp.map04_place(46.07,11.12),private.selected_place_point(pg_temp.map04_place(46.07,11.12)) from generate_series(1,2001)i;
select throws_ok($$select public.search_public_geography_v1(pg_temp.map04_query())$$,'54000',null,'Dense search fails explicitly before enrichment');
select * from finish();
rollback;
