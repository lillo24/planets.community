begin;
select no_plan();
update private.location_provider_config set enabled=true,daily_units_limit=8000,actor_daily_units=8000;
update private.location_search_config set enabled=true,actor_minute=20;
insert into auth.users(id,email) values
 ('fa020000-0000-4000-8000-000000000001','location02-owner@planets.invalid'),
 ('fa020000-0000-4000-8000-000000000002','location02-member@planets.invalid'),
 ('fa020000-0000-4000-8000-000000000003','location02-pending@planets.invalid');
insert into public.profiles(id,display_name) values
 ('fa020000-0000-4000-8000-000000000001','Synthetic owner'),
 ('fa020000-0000-4000-8000-000000000002','Synthetic member'),
 ('fa020000-0000-4000-8000-000000000003','Synthetic pending');
insert into public.proposals(id,creator_profile_id,title,summary,description,country_code,locality,public_location_label,
 lifecycle_state,published_at,starts_at,ends_at,event_timezone)
 values('fa021000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001',
 'LOCATION02 synthetic','Synthetic summary','Synthetic description','FR','Lyon','Lyon','published',now(),now()+interval '2 days',now()+interval '3 days','Europe/Paris');
insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility)
 values('fa021000-0000-4000-8000-000000000001','SECRET private gate, bell 4','public');
update public.projects set registration_capacity=10 where id='fa021000-0000-4000-8000-000000000001';
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
 values('fa022000-0000-4000-8000-000000000001','fa021000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000002','accepted',now()-interval '2 days',now()-interval '1 day','fa020000-0000-4000-8000-000000000001'),
 ('fa022000-0000-4000-8000-000000000002','fa021000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000003','pending',now(),null,null);
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
 values('fa023000-0000-4000-8000-000000000001','fa021000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000002','fa022000-0000-4000-8000-000000000001',now()-interval '1 day');

create function pg_temp.issue(p_precision text, slot text default 'place') returns uuid language plpgsql as $$
declare batch jsonb; issued jsonb; place jsonb;
begin
 batch := public.reserve_location_search_v1('fa020000-0000-4000-8000-000000000001','one_time','fa021000-0000-4000-8000-000000000001',
   (select location_revision from public.proposals where id='fa021000-0000-4000-8000-000000000001'),slot,gen_random_uuid(),encode(extensions.digest(gen_random_uuid()::text,'sha256'),'hex'));
 if batch->>'status'<>'ok' then raise exception 'Synthetic reserve failed: %',batch->>'status'; end if;
 place := jsonb_build_object('provider','geoapify','kind',p_precision,'result_type',case when p_precision='locality' then 'city' else 'building' end,
   'country_code','IT','label',case when p_precision='locality' then 'Trento, Provincia autonoma di Trento, Trentino-Alto Adige, Italia' else 'Synthetic venue, Via fixture 42, Trento' end,
   'locality','Trento','administrative_area','Provincia autonoma di Trento, Trentino-Alto Adige',
   'latitude',case when p_precision='locality' then 46.07 else 46.12 end,'longitude',case when p_precision='locality' then 11.12 else 11.17 end,
   'source','openstreetmap','attribution','Powered by Geoapify | © OpenStreetMap contributors','source_license','https://www.openstreetmap.org/copyright');
 issued := public.issue_location_selections_v1((batch->>'batch_id')::uuid,jsonb_build_array(place));
 return (issued->'suggestions'->0->>'id')::uuid;
end;
$$;
create function pg_temp.apply(action text, receipt uuid default null) returns bigint language sql as $$
 select public.apply_proposal_place_v1('fa020000-0000-4000-8000-000000000001','fa021000-0000-4000-8000-000000000001',
   (public.get_authorized_item_location_v1('fa020000-0000-4000-8000-000000000001','one_time','fa021000-0000-4000-8000-000000000001')->>'revision')::bigint,
   gen_random_uuid(),action,receipt);
$$;
grant execute on function pg_temp.apply(text,uuid) to authenticated;
select ok(not has_function_privilege('anon','public.apply_proposal_place_v1(uuid,uuid,bigint,uuid,text,uuid)','execute'),'Anonymous cannot mutate');
select ok(not has_function_privilege('service_role','public.apply_proposal_place_v1(uuid,uuid,bigint,uuid,text,uuid)','execute'),'Edge cannot impersonate place writes');
select is((select country_code from public.proposals where id='fa021000-0000-4000-8000-000000000001'),'FR','Legacy international city stays unchanged');
select is((select exact_meeting_text from public.get_public_proposal('fa021000-0000-4000-8000-000000000001')),null::text,'Legacy public setting never publishes directions');
select set_config('test.receipt',pg_temp.issue('address')::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.apply('replace',current_setting('test.receipt')::uuid)$$,'Exact selection commits through mixed-slot receipt');
select is(public.get_authorized_item_location_v1('fa020000-0000-4000-8000-000000000001','one_time','fa021000-0000-4000-8000-000000000001')->>'exact_is_public','false','New exact selection resets former public setting to private');
select is((select exact_meeting_text from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000001','fa021000-0000-4000-8000-000000000001')),'SECRET private gate, bell 4','Directions survive exact selection');
select is(public.get_public_item_location_v1('one_time','fa021000-0000-4000-8000-000000000001')->'exact_place','null'::jsonb,'Private selected point unavailable through public RPC');
select is(public.get_location_preview_v1('one_time','fa021000-0000-4000-8000-000000000001','public_detail')->'place','null'::jsonb,'Exact fallback city text has no fabricated public preview geometry');
select lives_ok($$select pg_temp.apply('public')$$,'Deliberate scoped switch publishes exact selected place');
select is(public.get_public_item_location_v1('one_time','fa021000-0000-4000-8000-000000000001')->'exact_place'->>'latitude','46.12','Public exact point is the verified coordinate');
select is(public.get_location_preview_v1('one_time','fa021000-0000-4000-8000-000000000001','card')->'place','null'::jsonb,'Even public exact place never becomes card geometry');
select is((select exact_meeting_text from public.get_public_proposal('fa021000-0000-4000-8000-000000000001')),'Synthetic venue, Via fixture 42, Trento','Compatibility detail field exposes selected label only');
select ok((select row_to_json(p)::text not like '%SECRET%' from public.get_public_proposal('fa021000-0000-4000-8000-000000000001') p),'Public detail contains no directions');
select throws_ok($$select private.consume_location_receipt(null,null,null,null,null,null,null)$$,'42501',null,'Client cannot forge canonical selection');
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000003',true);
select throws_ok($$select * from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000003','fa021000-0000-4000-8000-000000000001')$$,'42501',null,'Pending participant has no directions even for public exact address');
select throws_ok($$select public.apply_proposal_place_v1('fa020000-0000-4000-8000-000000000003','fa021000-0000-4000-8000-000000000001',0,gen_random_uuid(),'participants')$$,'42501',null,'Pending participant cannot toggle visibility');
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000002',true);
select is((select exact_meeting_text from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000002','fa021000-0000-4000-8000-000000000001')),'SECRET private gate, bell 4','Current participant can read directions');
select throws_ok($$select public.apply_proposal_place_v1('fa020000-0000-4000-8000-000000000002','fa021000-0000-4000-8000-000000000001',0,gen_random_uuid(),'participants')$$,'42501',null,'Read membership does not grant structural write');
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select set_config('test.old_revision',(public.get_authorized_item_location_v1('fa020000-0000-4000-8000-000000000001','one_time','fa021000-0000-4000-8000-000000000001')->>'revision'),true);
select lives_ok($$select pg_temp.apply('participants')$$,'Switch OFF revokes public exact place');
select throws_ok($$select public.apply_proposal_place_v1('fa020000-0000-4000-8000-000000000001','fa021000-0000-4000-8000-000000000001',current_setting('test.old_revision')::bigint,gen_random_uuid(),'public')$$,'40001',null,'Stale visibility update cannot resurrect exact publication');
reset role;
select ok((select selected_public_place is null and approximate_location is null from public.proposals where id='fa021000-0000-4000-8000-000000000001'),'Exact receipt never manufactures Discovery geometry');
update public.project_memberships set removed_at=now(),removed_by_profile_id='fa020000-0000-4000-8000-000000000001' where id='fa023000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.get_authorized_item_location_v1('fa020000-0000-4000-8000-000000000002','one_time','fa021000-0000-4000-8000-000000000001')$$,'42501',null,'Membership removal revokes private selected place');
select throws_ok($$select * from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000002','fa021000-0000-4000-8000-000000000001')$$,'42501',null,'Membership removal revokes directions');
reset role;
select set_config('test.receipt',pg_temp.issue('locality')::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub','fa020000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.apply('replace',current_setting('test.receipt')::uuid)$$,'Broad selection deliberately replaces exact selection');
select is(public.get_public_item_location_v1('one_time','fa021000-0000-4000-8000-000000000001')->'public_place'->>'latitude','46.07','Independently verified city creates its own Discovery point');
select throws_ok($$select pg_temp.apply('public')$$,'22023',null,'No meaningless public toggle for city-only place');
reset role;
select set_config('test.receipt',pg_temp.issue('address')::text,true);
set local role authenticated;
select lives_ok($$select pg_temp.apply('replace',current_setting('test.receipt')::uuid)$$,'Reselect exact place with independently matching broad area');
select is(public.get_public_item_location_v1('one_time','fa021000-0000-4000-8000-000000000001')->'public_place'->>'latitude','46.07','Matching independently selected city is retained, never rounded from exact point');
select is(public.get_public_item_location_v1('one_time','fa021000-0000-4000-8000-000000000001')->'exact_place','null'::jsonb,'Reselection is private again');
reset role;
update private.location_search_config set enabled=false;
set local role authenticated;
select lives_ok($$select pg_temp.apply('clear')$$,'Offline manual path can deliberately clear stale points');
select is((select exact_meeting_text from public.get_project_participant_meeting_details('fa020000-0000-4000-8000-000000000001','fa021000-0000-4000-8000-000000000001')),'SECRET private gate, bell 4','Clearing place does not silently clear directions');
set local role anon;
select is(public.get_public_item_location_v1('one_time','fa021000-0000-4000-8000-000000000001')->'exact_place','null'::jsonb,'Cleared exact place remains unavailable anonymously');
select ok((select bool_and(row_to_json(p)::text not like '%SECRET%') from public.list_public_proposals() p),'Public lists never include private arrival directions');
select * from finish();
rollback;
