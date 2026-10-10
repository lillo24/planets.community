begin;
select no_plan();

insert into auth.users(id,email) values
 ('fa010000-0000-4000-8000-000000000001','location01-owner@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000002','location01-peer@planets.invalid');
insert into public.profiles(id,display_name) values
 ('fa010000-0000-4000-8000-000000000001','Location owner'),
 ('fa010000-0000-4000-8000-000000000002','Location peer');
insert into public.profile_photos(profile_id,object_path,audience)
 select id,id::text||'/00000000-0000-4000-8000-000000000001.webp','interactions'
 from public.profiles where id::text like 'fa010000-%';

create function pg_temp.city_draft(city text default 'Trento', country text default 'IT', zone text default 'Europe/Rome')
returns uuid language sql as $$
 select public.create_proposal_draft(
 'fa010000-0000-4000-8000-000000000001', 'City-only defined Project',
 'Make something together.', 'An ordinary scheduled activity.',
 statement_timestamp()+interval '2 days',statement_timestamp()+interval '2 days 3 hours',
 zone,country,city,null,city,null,'participants',array[]::uuid[],array[]::text[],5)
$$;
create function pg_temp.exact_details(item uuid, instructions text, visibility text)
returns void language sql as $$
 select public.update_own_proposal(
 'fa010000-0000-4000-8000-000000000001',item,p.title,p.summary,p.description,
 p.starts_at,p.ends_at,p.event_timezone,p.country_code,p.locality,p.administrative_area,
 p.public_location_label,instructions,visibility,array[]::uuid[],array[]::text[],5)
 from public.proposals p where p.id=item
$$;

grant execute on function pg_temp.city_draft(text,text,text), pg_temp.exact_details(uuid,text,text) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select set_config('test.city_id',pg_temp.city_draft()::text,true);
select lives_ok($$select public.publish_proposal('fa010000-0000-4000-8000-000000000001',current_setting('test.city_id')::uuid)$$,
 'city-only draft publishes through canonical policy');
select results_eq($$select lifecycle_state,country_code,locality,public_location_label,approximate_location is null,selected_public_place is null
 from public.proposals where id=current_setting('test.city_id')::uuid$$,
 $$values ('published'::text,'IT'::text,'Trento'::text,'Trento'::text,true,true)$$,
 'manual city is canonical public text without invented geometry');
select results_eq($$select exact_meeting_text,exact_location_restricted from public.get_public_proposal(current_setting('test.city_id')::uuid)$$,
 $$values (null::text,false)$$,'absence is not projected as a hidden venue');
select is((select count(*) from public.list_public_proposals() where proposal_id=current_setting('test.city_id')::uuid),1::bigint,
 'city-only Project appears once in ordinary List');
select is((select count(*) from public.get_project_participant_meeting_details('fa010000-0000-4000-8000-000000000001',current_setting('test.city_id')::uuid)
 where exact_meeting_text is null and exact_location is null),1::bigint,'authorized owner receives a successful null meeting row');
select set_config('test.blank_id',pg_temp.city_draft('')::text,true);
select throws_ok($$select public.publish_proposal('fa010000-0000-4000-8000-000000000001',current_setting('test.blank_id')::uuid)$$,
 '22023',null,'blank city saves as a draft but cannot publish as defined');
select throws_ok($$select pg_temp.city_draft('Trento','ITA')$$,'22023',null,'malformed country still fails');
select set_config('test.bad_zone',pg_temp.city_draft('Trento','IT','Not/AZone')::text,true);
select throws_ok($$select public.publish_proposal('fa010000-0000-4000-8000-000000000001',current_setting('test.bad_zone')::uuid)$$,
 '22023',null,'recognized schedule timezone remains mandatory');

select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select throws_ok($$select * from public.get_project_participant_meeting_details('fa010000-0000-4000-8000-000000000002',current_setting('test.city_id')::uuid)$$,
 '42501',null,'absence does not grant unrelated access to protected reads');
select set_config('test.city_request',public.request_to_join_project('fa010000-0000-4000-8000-000000000002',current_setting('test.city_id')::uuid,null)::text,true);
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.accept_project_join_request('fa010000-0000-4000-8000-000000000001',current_setting('test.city_request')::uuid)$$,
 'normal join/accept works without exact instructions');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.get_project_participant_meeting_details('fa010000-0000-4000-8000-000000000002',current_setting('test.city_id')::uuid)
 where exact_meeting_text is null),1::bigint,'current participant can read a legitimately absent exact place');
select lives_ok($$select * from public.get_own_project_group_chat('fa010000-0000-4000-8000-000000000002',current_setting('test.city_id')::uuid)$$,
 'Project chat entitlement remains available');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.exact_details(current_setting('test.city_id')::uuid,'Private side entrance','participants')$$,
 'published future Project can add precise instructions');
select results_eq($$select exact_meeting_text,exact_location_restricted from public.get_public_proposal(current_setting('test.city_id')::uuid)$$,
 $$values (null::text,true)$$,'participant-only instructions stay private');
select lives_ok($$select pg_temp.exact_details(current_setting('test.city_id')::uuid,'Public meeting entrance','public')$$,
 'explicit public visibility remains supported');
select results_eq($$select exact_meeting_text,exact_location_restricted from public.get_public_proposal(current_setting('test.city_id')::uuid)$$,
 $$values ('Public meeting entrance'::text,false)$$,'explicitly public instructions round trip');

reset role;
-- Synthetic point fixture only. The normal update RPC must invalidate both
-- protected geometry and provenance when the organizer clears instructions.
update public.proposal_meeting_details set selected_exact_place=jsonb_build_object(
 'provider','geoapify','kind','address','result_type','building','label','Synthetic entrance',
 'country_code','IT','locality','Trento','administrative_area',null,'latitude',46.07,'longitude',11.12,
 'source','openstreetmap','source_license','https://www.openstreetmap.org/copyright',
 'attribution','Powered by Geoapify | © OpenStreetMap contributors','verified_at',statement_timestamp()),
 exact_location=extensions.st_setsrid(extensions.st_makepoint(11.12,46.07),4326)::extensions.geography
 where proposal_id=current_setting('test.city_id')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.exact_details(current_setting('test.city_id')::uuid,null,'participants')$$,
 'clearing exact instructions keeps the Project published');
select is((select count(*) from public.proposal_meeting_details where proposal_id=current_setting('test.city_id')::uuid
 and exact_meeting_text is null and exact_location is null and selected_exact_place is null),1::bigint,
 'clearing invalidates stale precise coordinates and provenance');
select results_eq($$select exact_meeting_text,exact_location_restricted from public.get_public_proposal(current_setting('test.city_id')::uuid)$$,
 $$values (null::text,false)$$,'cleared venue no longer claims private presence');

set local role anon;
select results_eq($$select exact_meeting_text,exact_location_restricted from public.get_public_proposal(current_setting('test.city_id')::uuid)$$,
 $$values (null::text,false)$$,'anonymous detail has truthful absence');
select throws_ok($$select * from public.proposal_meeting_details$$,'42501',null,'anonymous users still cannot read protected storage');
select is(jsonb_array_length(public.search_public_geography_v1('{"mode":"bounds","south":45.9,"north":46.2,"west":10.9,"east":11.4,"kinds":["one_time"]}'::jsonb)->'items'),0,
 'manual-only city is excluded from coordinate-based Map');

select * from finish();
rollback;
