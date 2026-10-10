begin;
select no_plan();
insert into auth.users(id,email) values('fa030000-0000-4000-8000-000000000001','idea-pages@planets.invalid');
insert into public.profiles(id,display_name) values('fa030000-0000-4000-8000-000000000001','Synthetic Idea pages');
insert into public.profile_photos(profile_id,object_path,audience)
 values('fa030000-0000-4000-8000-000000000001','fa030000-0000-4000-8000-000000000001/00000000-0000-4000-8000-000000000001.webp','interactions');
insert into public.proposals(id,creator_profile_id,title,summary,description,starts_at,ends_at,event_timezone,country_code,locality,public_location_label)
 select ('fa031000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'fa030000-0000-4000-8000-000000000001','IDEA01A pagination garden '||i,'Meaningful synthetic explanation',
 case when i<=3 then 'Synthetic complete description' end,
 case when i<=3 then now()+i*interval '1 day' end,
 case when i<=3 then now()+(i+2)*interval '1 day' end,
 case when i<=3 then 'Europe/Rome' end,case when i<=3 then 'IT' end,
 case when i<=3 then 'Trento' end,case when i<=3 then 'Trento, Italia' end
 from generate_series(1,5)i;
update public.projects set registration_capacity=10 where id::text like 'fa031000-%';
insert into public.proposal_meeting_details(proposal_id,exact_location_visibility)
 select id,'participants' from public.proposals where id::text like 'fa031000-%';
update public.proposals set lifecycle_state='published',published_at=now()-interval '1 hour',
 definition_phase=case when right(id::text,1)::int<=2 then 'defined' else 'idea' end
 where id::text like 'fa031000-%';
insert into public.proposal_skills(proposal_id,skill_id,importance)
 select 'fa031000-0000-4000-8000-000000000003',id,'required' from public.skills order by id limit 1;
select set_config('test.idea_reference',(now()-interval '30 minutes')::text,true);
create temporary table first_page as select * from public.list_public_proposals_v2(
 p_limit=>2,p_query=>'IDEA01A pagination',p_reference_time=>current_setting('test.idea_reference')::timestamptz);
select results_eq('select proposal_id from first_page',
 $$values ('fa031000-0000-4000-8000-000000000005'::uuid),('fa031000-0000-4000-8000-000000000004'::uuid)$$,
 'null schedules use deterministic descending publication and UUID tie-break');
select is((select count(*) from public.list_public_proposals_v2(p_query=>'IDEA01A pagination',p_definition_phase=>'idea')),3::bigint,'Idea-only filter includes city-less Ideas');
select is((select count(*) from public.list_public_proposals_v2(p_query=>'IDEA01A pagination',p_locality=>' trento ')),3::bigint,'locality opt-in excludes absent city');
select is((select count(*) from public.list_public_proposals_v2(p_query=>'IDEA01A pagination',p_skill_ids=>array[(select skill_id from public.proposal_skills where proposal_id='fa031000-0000-4000-8000-000000000003')])),1::bigint,'skill filter uses canonical skills');
select is((select count(*) from public.list_public_proposals_v2(p_query=>'%pagination%')),0::bigint,'search punctuation is literal, never wildcard interpolation');
select results_eq($$select proposal_id from public.list_public_proposals(p_query=>'IDEA01A pagination')$$,
 $$values ('fa031000-0000-4000-8000-000000000001'::uuid),('fa031000-0000-4000-8000-000000000002'::uuid)$$,
 'old reader preserves strict schedule ordering and only Defined');
select throws_ok($$select * from public.list_public_proposals_v2(p_cursor_published_at=>now()-interval '1 hour',p_cursor_id=>'fa031000-0000-4000-8000-000000000099')$$,'22023',null,'unknown cursor rejected');
select throws_ok($$select * from public.list_public_proposals_v2(p_cursor_published_at=>now()-interval '2 hours',p_cursor_id=>'fa031000-0000-4000-8000-000000000005')$$,'22023',null,'forged publication anchor rejected');
select throws_ok($$select * from public.list_public_proposals_v2(p_locality=>repeat('x',121))$$,'22023',null,'locality bound enforced');
select throws_ok($$select * from public.list_public_proposals_v2(p_skill_ids=>array_fill('fa031000-0000-4000-8000-000000000003'::uuid,array[101]))$$,'22023',null,'skill array bound enforced');
select throws_ok($$select * from public.list_public_proposals_v2(p_skill_ids=>array[null::uuid])$$,'22023',null,'null skill identifier rejected');
select throws_ok($$select * from public.list_public_proposals_v2(p_query=>repeat('x',121))$$,'22023',null,'keyword bound enforced');

-- Real future geometry is still excluded from the installed event Map and SIM01.
update public.proposals set selected_public_place='{"provider":"geoapify","kind":"locality","result_type":"city","label":"Trento","country_code":"IT","locality":"Trento","latitude":46.07,"longitude":11.12,"source":"openstreetmap","attribution":"Powered by Geoapify | © OpenStreetMap contributors","source_license":"https://www.openstreetmap.org/copyright","verified_at":"2026-10-01T00:00:00Z"}'::jsonb,
 approximate_location=extensions.st_setsrid(extensions.st_makepoint(11.12,46.07),4326)::extensions.geography
 where id='fa031000-0000-4000-8000-000000000003';
select is((select count(*) from private.geo_public_candidates_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"kinds":["one_time"],"proposal_skill_ids":[]}'::jsonb,now(),null,null) where item_id='fa031000-0000-4000-8000-000000000003'),0::bigint,'radius Map excludes even geocoded future Idea');
select is((select count(*) from private.geo_public_candidates_v1('{"mode":"bounds","west":11,"south":46,"east":12,"north":47,"kinds":["one_time"],"proposal_skill_ids":[]}'::jsonb,now(),null,null) where item_id='fa031000-0000-4000-8000-000000000003'),0::bigint,'bounds Map excludes Idea');
set local role authenticated;
select set_config('request.jwt.claim.sub','fa030000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.list_similar_active_proposals('fa030000-0000-4000-8000-000000000001','IDEA01A pagination garden') where proposal_id='fa031000-0000-4000-8000-000000000003'),0::bigint,'SIM01 never treats tentative Idea as active event');
select lives_ok($$select public.promote_proposal_idea('fa030000-0000-4000-8000-000000000001','fa031000-0000-4000-8000-000000000003')$$,'promotion retains publication anchor');
select lives_ok($$select public.cancel_proposal('fa030000-0000-4000-8000-000000000001','fa031000-0000-4000-8000-000000000004')$$,'cancel page anchor without invalidating its cursor');
reset role;
-- Publication after page one's frozen reference cannot displace its remaining rows.
insert into public.proposals(id,creator_profile_id,title,summary)
 values('fa031000-0000-4000-8000-000000000006','fa030000-0000-4000-8000-000000000001','IDEA01A pagination new','Meaningful synthetic explanation');
insert into public.proposal_meeting_details(proposal_id,exact_location_visibility)
 values('fa031000-0000-4000-8000-000000000006','participants');
update public.proposals set definition_phase='idea',lifecycle_state='published',published_at=now()
 where id='fa031000-0000-4000-8000-000000000006';
create temporary table second_page as select * from public.list_public_proposals_v2(
 p_limit=>2,p_query=>'IDEA01A pagination',p_reference_time=>current_setting('test.idea_reference')::timestamptz,
 p_cursor_published_at=>now()-interval '1 hour',p_cursor_id=>'fa031000-0000-4000-8000-000000000004');
select results_eq('select proposal_id from second_page',
 $$values ('fa031000-0000-4000-8000-000000000003'::uuid),('fa031000-0000-4000-8000-000000000002'::uuid)$$,
 'promotion/cancellation/new publication cause no duplicates or skipped unchanged rows');
select results_eq($$select proposal_id from public.list_public_proposals_v2(p_limit=>2,p_query=>'IDEA01A pagination',p_reference_time=>current_setting('test.idea_reference')::timestamptz,p_cursor_published_at=>now()-interval '1 hour',p_cursor_id=>'fa031000-0000-4000-8000-000000000002')$$,
 $$values ('fa031000-0000-4000-8000-000000000001'::uuid)$$,'last page exhausts canonical tie order');
select is((select count(*) from public.list_public_proposals_v2(p_query=>'IDEA01A pagination',p_reference_time=>current_setting('test.idea_reference')::timestamptz,p_cursor_published_at=>now()-interval '1 hour',p_cursor_id=>'fa031000-0000-4000-8000-000000000001')),0::bigint,'exhausted cursor returns honest empty page');
select is((select count(*) from private.geo_public_candidates_v1('{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"kinds":["one_time"],"proposal_skill_ids":[]}'::jsonb,now(),null,null) where item_id='fa031000-0000-4000-8000-000000000003'),1::bigint,'explicit promotion enables existing public geometry Map behavior');
select * from finish();
rollback;
