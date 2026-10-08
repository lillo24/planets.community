begin;
select no_plan();
insert into auth.users(id,email) values('a9010000-0000-4000-8000-000000000001','map01-tap-owner@planets.invalid'),('a9010000-0000-4000-8000-000000000002','map01-tap-member@planets.invalid'),('a9010000-0000-4000-8000-000000000003','map01-tap-outsider@planets.invalid');
insert into public.profiles(id,display_name) values('a9010000-0000-4000-8000-000000000001','MAP01 Owner'),('a9010000-0000-4000-8000-000000000002','MAP01 Member'),('a9010000-0000-4000-8000-000000000003','MAP01 Outsider');
-- Photo-free incomplete drafts are permitted; location does not introduce a gate.
insert into public.proposals(id,creator_profile_id,country_code,locality,public_location_label,event_timezone)
 values('a9020000-0000-4000-8000-000000000001','a9010000-0000-4000-8000-000000000001','FR','Legacy locality','Legacy manual area','Europe/Paris');
insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility)
 values('a9020000-0000-4000-8000-000000000001','Legacy instructions','participants');
insert into public.recurring_activities(id,creator_profile_id,country_code,locality,public_location_label)
 values('a9020000-0000-4000-8000-000000000002','a9010000-0000-4000-8000-000000000001','FR','Legacy locality','Legacy manual area');
insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text,exact_location_visibility)
 values('a9020000-0000-4000-8000-000000000002','Legacy Tavolo instructions','participants');
insert into public.resource_listings(id,owner_profile_id,listing_mode,country_code,locality,public_location_label)
 values('a9020000-0000-4000-8000-000000000003','a9010000-0000-4000-8000-000000000001','donate','FR','Legacy locality','Legacy manual area');

select is((select enabled from private.location_search_config),false,'Committed database kill switch is disabled');
select ok((select bool_and(relrowsecurity) from pg_class x join pg_namespace n on n.oid=x.relnamespace
 where n.nspname='private' and x.relkind='r' and x.relname like 'location_%'),'Internal location tables have RLS');
select ok(not exists(select 1 from information_schema.role_table_grants where table_name like 'location_%'
 and grantee in ('anon','authenticated','service_role')),'No raw receipt, budget, configuration or mutation grants');
select ok(not has_table_privilege('anon','public.proposal_meeting_details','SELECT'),'Private exact data stays inaccessible through raw Data API');
select ok(not has_table_privilege('authenticated','public.resource_listings','SELECT'),'Resource public points are available only through sanctioned RPCs');
select ok(not has_function_privilege('authenticated','public.issue_location_selections_v1(uuid,jsonb)','EXECUTE'),'Clients cannot forge provider verification');
select ok(not has_function_privilege('anon','public.reserve_location_search_v1(uuid,text,uuid,bigint,text,uuid,text)','EXECUTE'),'Anonymous traffic cannot reserve upstream budget');
select ok(has_function_privilege('service_role','public.reserve_location_search_v1(uuid,text,uuid,bigint,text,uuid,text)','EXECUTE'),'Server has narrow metering RPC');
select ok(not has_function_privilege('service_role','public.apply_item_location_v1(uuid,text,uuid,bigint,uuid,text,uuid,text,uuid)','EXECUTE'),'Server cannot impersonate client durable mutation');
select ok(not has_function_privilege('authenticated','private.consume_location_receipt(uuid,text,uuid,bigint,text,uuid,uuid)','EXECUTE'),'Private receipt consumption is not a public security definer bypass');
select ok((select approximate_location is null and selected_public_place is null and country_code='FR' and event_timezone='Europe/Paris' from public.proposals where id='a9020000-0000-4000-8000-000000000001'),'Untouched international manual data and timezone stay unchanged');
select ok((select public_location is null and selected_public_place is null from public.resource_listings where id='a9020000-0000-4000-8000-000000000003'),'Legacy resources get no invented coordinates');
select set_config('test.map01.budgets',(select count(*)::text from private.location_search_budgets),true);
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',0,'area',gen_random_uuid(),repeat('a',64))->>'status','disabled','Disabled searches reserve no budget');
select is((select count(*) from private.location_search_budgets),current_setting('test.map01.budgets')::bigint,'Disabled search makes zero reservations');
select is(public.get_public_item_location_v1('one_time','a9020000-0000-4000-8000-000000000001'),null::jsonb,'Private drafts have no public projection');

-- Synthetic normalized OSM-backed geocoding. This helper is transaction-local.
create function pg_temp.place(p_kind text) returns jsonb language sql as $$
 select jsonb_build_object('provider','geoapify','kind',p_kind,
 'result_type',case p_kind when 'locality' then 'city' when 'address' then 'building' else 'amenity' end,
 'country_code','IT','label',case p_kind when 'locality' then 'Synthetic area' else 'SECRET synthetic exact label' end,
 'locality','Synthetic locality','administrative_area','Synthetic region',
 'latitude',case p_kind when 'locality' then 45 else 44 end,
 'longitude',case p_kind when 'locality' then 12 else 10 end,'confidence',0.9,
 'source','openstreetmap','attribution','Powered by Geoapify | © OpenStreetMap contributors',
 'source_license','https://www.openstreetmap.org/copyright');
$$;
select ok(private.valid_selected_place(pg_temp.place('locality')||jsonb_build_object('verified_at',now())),'Licensed normalized broad data validates');
select ok(not private.valid_selected_place(pg_temp.place('address')||jsonb_build_object('verified_at',now(),'latitude',91)),'Latitude is bounded at canonical boundary');
select ok(not private.valid_selected_place(pg_temp.place('address')||jsonb_build_object('verified_at',now(),'longitude',181)),'Longitude is bounded at canonical boundary');
select ok(not private.valid_selected_place(pg_temp.place('address')||jsonb_build_object('verified_at',now(),'source','unknown')),'Unreviewed source cannot persist');
select ok(not private.valid_selected_place(pg_temp.place('address')||jsonb_build_object('verified_at',now(),'country_code','FR')),'Verified geometry is Italy-only without rewriting manual international rows');
select ok(not private.valid_selected_place(pg_temp.place('address')||jsonb_build_object('verified_at',now(),'kind','locality')),'Precision/result type combinations must agree');
select ok(not private.valid_selected_place(pg_temp.place('address')||jsonb_build_object('verified_at',now(),'raw',jsonb_build_object('secret','x'))),'Opaque provider response fields cannot persist');
update private.location_search_config set enabled=true;

create function pg_temp.receipt(p_actor uuid,p_kind text,p_item uuid,p_slot text,p_precision text)
returns uuid language plpgsql as $$
declare revision bigint; reserve jsonb; issued jsonb;
begin
 if p_kind='one_time' then select location_revision into revision from public.proposals where id=p_item;
 elsif p_kind='recurring' then select location_revision into revision from public.recurring_activities where id=p_item;
 else select location_revision into revision from public.resource_listings where id=p_item; end if;
 reserve:=public.reserve_location_search_v1(p_actor,p_kind,p_item,revision,p_slot,gen_random_uuid(),encode(extensions.digest(gen_random_uuid()::text,'sha256'),'hex'));
 if reserve->>'status'<>'ok' then raise exception 'Fixture reservation failed: %',reserve->>'status'; end if;
 issued:=public.issue_location_selections_v1((reserve->>'batch_id')::uuid,jsonb_build_array(pg_temp.place(p_precision)));
 return (issued->'suggestions'->0->>'id')::uuid;
end;
$$;
select set_config('test.map01.area',pg_temp.receipt('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001','area','locality')::text,true);
select set_config('test.map01.exact',pg_temp.receipt('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001','exact','address')::text,true);
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',1,'area',gen_random_uuid(),repeat('a',64))->>'status','stale_selection','Search checks saved revision before provider calls');
select is(pg_temp.receipt('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001','area','address'),null::uuid,'Exact result cannot be issued as a public area receipt');

set local role authenticated;
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',0,gen_random_uuid(),
 'replace',current_setting('test.map01.area')::uuid,'replace',gen_random_uuid())$$,'22023',null,'Invalid second slot rolls back consumption of first receipt');
select set_config('test.map01.revision',public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',0,'a9030000-0000-4000-8000-000000000001',
 'replace',current_setting('test.map01.area')::uuid,'replace',current_setting('test.map01.exact')::uuid)::text,true);
select is(public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',0,'a9030000-0000-4000-8000-000000000001',
 'replace',current_setting('test.map01.area')::uuid,'replace',current_setting('test.map01.exact')::uuid),current_setting('test.map01.revision')::bigint,'Duplicate response retry returns same revision');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',0,'a9030000-0000-4000-8000-000000000001','clear',null,'unchanged',null)$$,'22023',null,'Changed duplicate input is rejected');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',0,gen_random_uuid(),'clear',null,'unchanged',null)$$,'40001',null,'Stale edit cannot clear a newer selection');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',current_setting('test.map01.revision')::bigint,gen_random_uuid(),'replace',gen_random_uuid(),'unchanged',null)$$,'22023',null,'Forged receipt cannot persist a client pin');
select throws_ok($$select public.get_authorized_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001')$$,'42501',null,'Changed-account expected identity rejected');
select ok(public.get_authorized_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001')->'exact_place' is not null,'Creator reads protected selected metadata');
select throws_ok($$select * from private.location_selection_receipts$$,'42501',null,'Receipt table unavailable to client');
reset role;
select is((select extensions.st_srid(approximate_location::extensions.geometry) from public.proposals where id='a9020000-0000-4000-8000-000000000001'),4326,'Public geography uses correct SRID');
select is((select extensions.st_x(approximate_location::extensions.geometry) from public.proposals where id='a9020000-0000-4000-8000-000000000001'),12::double precision,'Longitude is X');
select is((select extensions.st_y(exact_location::extensions.geometry) from public.proposal_meeting_details where proposal_id='a9020000-0000-4000-8000-000000000001'),44::double precision,'Exact latitude is separate');
select is((select exact_meeting_text from public.proposal_meeting_details where proposal_id='a9020000-0000-4000-8000-000000000001'),'Legacy instructions','Selecting an address preserves manual instructions');
select ok(not exists(select 1 from private.audit_events where target_id='a9020000-0000-4000-8000-000000000001' and metadata::text like '%SECRET%'),'Audit payloads exclude exact location');
select ok(not exists(select 1 from private.outbox_events where payload::text like '%SECRET synthetic exact label%'),'Outbox/notification payloads exclude exact location');

-- Prove exact-only choice cannot produce a public area or radius-query input.
select set_config('test.map01.tavolo',pg_temp.receipt('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002','exact','amenity')::text,true);
set local role authenticated;
select is(public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002',0,gen_random_uuid(),'unchanged',null,'replace',current_setting('test.map01.tavolo')::uuid),1::bigint,'Tavolo exact receipt writes atomically');
reset role;
select ok((select approximate_location is null and selected_public_place is null from public.recurring_activities where id='a9020000-0000-4000-8000-000000000002'),'An exact-only Tavolo never gains a public area centroid');
select set_config('test.map01.resource',pg_temp.receipt('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003','public','address')::text,true);
set local role authenticated;
select is(public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003',0,gen_random_uuid(),'replace',current_setting('test.map01.resource')::uuid,'unchanged',null),1::bigint,'Resource public address is owner-only writable');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003',1,gen_random_uuid(),'unchanged',null,'clear',null)$$,'22023',null,'No private Resource pickup boundary invented');
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000003','resource','a9020000-0000-4000-8000-000000000003',1,gen_random_uuid(),'clear',null,'unchanged',null)$$,'42501',null,'Resource non-owner cannot edit');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000003','one_time','a9020000-0000-4000-8000-000000000001',current_setting('test.map01.revision')::bigint,gen_random_uuid(),'clear',null,'unchanged',null)$$,'42501',null,'Project outsider cannot edit');
reset role;

-- MAP03 exact-only Tavolo cannot become a public centroid.
update public.projects set registration_capacity=10 where id='a9020000-0000-4000-8000-000000000002';
insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from)
 values('a9020000-0000-4000-8000-000000000002','weekly',1,'12:00',60,'Europe/Rome',current_date);
update public.recurring_activities set lifecycle_state='published',published_at=now(),title='MAP03 synthetic Tavolo',summary='Synthetic summary',description='Synthetic description' where id='a9020000-0000-4000-8000-000000000002';
set local role anon;
select is(public.get_location_preview_v1('recurring','a9020000-0000-4000-8000-000000000002','card')->'place','null'::jsonb,'MAP03 exact-only Tavolo card has no public point');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000001',true);
select is(public.get_location_preview_v1('recurring','a9020000-0000-4000-8000-000000000002','protected_detail','a9010000-0000-4000-8000-000000000001')->'place'->>'kind','amenity','MAP03 Tavolo creator exact detail');
reset role;
-- Exact read policy is evaluated on every request; legacy public RPCs stay narrow.
update public.projects set registration_capacity=10 where id='a9020000-0000-4000-8000-000000000001';
update public.proposals set lifecycle_state='published',published_at=now(),title='Location privacy fixture',
 summary='Synthetic summary',description='Synthetic description',starts_at=now()+interval '2 days',
 ends_at=now()+interval '3 days',event_timezone='Europe/Rome' where id='a9020000-0000-4000-8000-000000000001';
update public.resource_listings set lifecycle_state='published',published_at=now(),title='Resource fixture',description='Synthetic description' where id='a9020000-0000-4000-8000-000000000003';
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
 values('a9040000-0000-4000-8000-000000000001','a9020000-0000-4000-8000-000000000001','a9010000-0000-4000-8000-000000000002','accepted',now()-interval '2 days',now()-interval '1 day','a9010000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
 values('a9050000-0000-4000-8000-000000000001','a9020000-0000-4000-8000-000000000001','a9010000-0000-4000-8000-000000000002','a9040000-0000-4000-8000-000000000001',now()-interval '1 day');
set local role anon;
select is(public.get_public_item_location_v1('one_time','a9020000-0000-4000-8000-000000000001')->'exact_place','null'::jsonb,'Anonymous exact-ID projection has no participant-only point/reference/label');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','card')->'place'->>'kind','locality','MAP03 independent Project card locality');
select is(public.get_location_preview_v1('resource','a9020000-0000-4000-8000-000000000003','card')->'place'->>'kind','address','MAP03 Resource public precision');
select throws_ok($$select public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','protected_detail','a9010000-0000-4000-8000-000000000002')$$,'42501',null,'MAP03 anonymous protected denied');
select ok((public.get_public_item_location_v1('one_time','a9020000-0000-4000-8000-000000000001')->'public_place'->>'latitude')='45','Anonymous reads independent area only');
select ok(public.get_public_item_location_v1('resource','a9020000-0000-4000-8000-000000000003')->'public_place'->>'kind'='address','Published Resource location is canonical public data');
select ok((select to_jsonb(x)::text not like '%SECRET%' from public.get_public_proposal('a9020000-0000-4000-8000-000000000001') x),'Legacy public detail cannot leak selected exact metadata');
select ok((select bool_and(to_jsonb(x)::text not like '%SECRET%') from public.list_public_proposals() x),'Legacy public browse cannot leak selected exact metadata');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000002',true);
select ok(public.get_authorized_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001')->'exact_place'->>'label' like 'SECRET%','Current member reads protected exact selected place');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','protected_detail','a9010000-0000-4000-8000-000000000002')->'place'->>'latitude','44','MAP03 accepted member exact detail');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','card')->'place'->>'latitude','45','MAP03 member card remains broad');
select throws_ok($$select public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','protected_detail','a9010000-0000-4000-8000-000000000001')$$,'42501',null,'MAP03 actor mismatch fails closed');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001',0,gen_random_uuid(),'clear',null,'unchanged',null)$$,'42501',null,'Ordinary member has read but no structural write authority');
reset role;
-- Accepted organizer roles reuse the existing canonical structural distinction.
set local role authenticated;
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000001',true);
select set_config('test.map01.offer',public.create_project_role_offer('a9010000-0000-4000-8000-000000000001','a9020000-0000-4000-8000-000000000001','a9050000-0000-4000-8000-000000000001','co_organizer')::text,true);
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000002',true);
select set_config('test.map01.delegate',public.accept_project_role_offer('a9010000-0000-4000-8000-000000000002',current_setting('test.map01.offer')::uuid)::text,true);
select ok(public.get_authorized_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001')->'exact_place'->>'label' like 'SECRET%','Co-organizer can read canonical protected location');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','protected_detail','a9010000-0000-4000-8000-000000000002')->>'audience','protected','MAP03 active delegate entitlement');
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001',0,gen_random_uuid(),'unchanged',null,'unchanged',null)$$,'42501',null,'Co-organizer cannot structurally edit location');
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000001',true);
select public.revoke_project_delegate('a9010000-0000-4000-8000-000000000001',current_setting('test.map01.delegate')::uuid);
select set_config('test.map01.offer',public.create_project_role_offer('a9010000-0000-4000-8000-000000000001','a9020000-0000-4000-8000-000000000001','a9050000-0000-4000-8000-000000000001','co_creator')::text,true);
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000002',true);
select set_config('test.map01.delegate',public.accept_project_role_offer('a9010000-0000-4000-8000-000000000002',current_setting('test.map01.offer')::uuid)::text,true);
reset role;
select set_config('test.map01.cocreator',pg_temp.receipt('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001','exact','address')::text,true);
set local role authenticated;
select set_config('test.map01.cocreator_revision',(public.get_authorized_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001')->>'revision'),true);
select lives_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001',current_setting('test.map01.cocreator_revision')::bigint,gen_random_uuid(),'unchanged',null,'replace',current_setting('test.map01.cocreator')::uuid)$$,'Current Co-creator may replace a verified location');
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000001',true);
select public.revoke_project_delegate('a9010000-0000-4000-8000-000000000001',current_setting('test.map01.delegate')::uuid);
reset role;
update public.project_memberships set removed_at=now(),removed_by_profile_id='a9010000-0000-4000-8000-000000000001' where id='a9050000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.get_authorized_item_location_v1('a9010000-0000-4000-8000-000000000002','one_time','a9020000-0000-4000-8000-000000000001')$$,'42501',null,'Removed member loses exact data immediately');
select throws_ok($$select public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','protected_detail','a9010000-0000-4000-8000-000000000002')$$,'42501',null,'MAP03 removed member denied');
reset role;
update public.proposal_meeting_details set exact_location_visibility='public' where proposal_id='a9020000-0000-4000-8000-000000000001';
set local role anon;
select ok(public.get_public_item_location_v1('one_time','a9020000-0000-4000-8000-000000000001')->'exact_place'->>'label' like 'SECRET%','Explicit canonical public exact visibility permits detail projection');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','public_detail')->'place'->>'kind','address','MAP03 public exact detail');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','card')->'place'->>'kind','locality','MAP03 public exact never becomes card precision');
reset role;
update public.proposal_meeting_details set exact_location_visibility='participants' where proposal_id='a9020000-0000-4000-8000-000000000001';
select is(public.get_public_item_location_v1('one_time','a9020000-0000-4000-8000-000000000001')->'exact_place','null'::jsonb,'Visibility revocation removes public precision');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','public_detail')->'place'->>'kind','locality','MAP03 visibility revocation removes detail precision');
select ok(private.proposal_template_reusable_content('a9020000-0000-4000-8000-000000000001')::text not like '%SECRET%','Template reusable allowlist excludes source-private place metadata/points');

-- A legacy manual edit drops verified public data rather than leaving an old pin.
set local role authenticated;
select set_config('request.jwt.claim.sub','a9010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.update_own_resource_listing('a9010000-0000-4000-8000-000000000001','a9020000-0000-4000-8000-000000000003','donate','Resource fixture','Synthetic description','FR','Changed manual locality',null,'Changed manual text')$$,'Legacy Resource signature remains usable');
reset role;
select ok((select selected_public_place is null and public_location is null and country_code='FR' from public.resource_listings where id='a9020000-0000-4000-8000-000000000003'),'Legacy manual Resource edit clears old verified pin');
update public.proposal_meeting_details set exact_meeting_text='Changed instructions' where proposal_id='a9020000-0000-4000-8000-000000000001';
select ok((select selected_exact_place is null and exact_location is null from public.proposal_meeting_details where proposal_id='a9020000-0000-4000-8000-000000000001'),'Manual exact edit clears old verified pin');
select set_config('test.map01.revision',(select location_revision::text from public.proposals where id='a9020000-0000-4000-8000-000000000001'),true);
set local role authenticated;
select lives_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','one_time','a9020000-0000-4000-8000-000000000001',current_setting('test.map01.revision')::bigint,gen_random_uuid(),'clear',null,'clear',null)$$,'Clear works without provider access and preserves manual drafts');
reset role;
select is((select public_location_label from public.proposals where id='a9020000-0000-4000-8000-000000000001'),'Synthetic area','Clear preserves current public text');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','card')->'place','null'::jsonb,'MAP03 retained text cannot recreate a point');
select is(public.get_location_preview_v1('one_time','a9020000-0000-4000-8000-000000000001','card')->'legacy'->>'country_code','IT','MAP03 safe legacy country retained');

-- Expiry, cross-item and kill-switch checks at the durable boundary.
select set_config('test.map01.resource',pg_temp.receipt('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003','public','address')::text,true);
update private.location_search_batches set expires_at=now()-interval '1 second' where id=(select batch_id from private.location_selection_receipts where id=current_setting('test.map01.resource')::uuid);
select set_config('test.map01.resource_revision',(select location_revision::text from public.resource_listings where id='a9020000-0000-4000-8000-000000000003'),true);
set local role authenticated;
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003',current_setting('test.map01.resource_revision')::bigint,gen_random_uuid(),'replace',current_setting('test.map01.resource')::uuid,'unchanged',null)$$,'22023',null,'Expired receipt cannot become durable');
reset role;
update private.location_search_config set enabled=false;
set local role authenticated;
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003',current_setting('test.map01.resource_revision')::bigint,gen_random_uuid(),'replace',current_setting('test.map01.resource')::uuid,'unchanged',null)$$,'55000',null,'Kill switch prevents durable replacement');
select lives_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003',current_setting('test.map01.resource_revision')::bigint,gen_random_uuid(),'clear',null,'unchanged',null)$$,'Kill switch leaves manual fallback/clear usable');
reset role;
update public.resource_listings set lifecycle_state='closed',closed_at=now() where id='a9020000-0000-4000-8000-000000000003';
set local role authenticated;
select throws_ok($$select public.apply_item_location_v1('a9010000-0000-4000-8000-000000000001','resource','a9020000-0000-4000-8000-000000000003',0,gen_random_uuid(),'clear',null,'unchanged',null)$$,'55000',null,'Closed resources cannot be geocoded/edited');
reset role;

-- Enforceable metering: global, per-actor daily and per-minute reservations.
update private.location_search_config set enabled=true,global_daily=1,actor_daily=80,actor_minute=10;
delete from private.location_search_batches; delete from private.location_search_budgets;
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002',(select location_revision from public.recurring_activities where id='a9020000-0000-4000-8000-000000000002'),'exact',gen_random_uuid(),repeat('b',64))->>'status','ok','Budget allows first request');
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002',(select location_revision from public.recurring_activities where id='a9020000-0000-4000-8000-000000000002'),'exact',gen_random_uuid(),repeat('c',64))->>'status','budget_exhausted','Global cap is enforced before second provider call');
update private.location_search_config set global_daily=1000,actor_daily=1;
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002',(select location_revision from public.recurring_activities where id='a9020000-0000-4000-8000-000000000002'),'exact',gen_random_uuid(),repeat('c',64))->>'status','budget_exhausted','Per-actor daily cap enforced');
update private.location_search_config set actor_daily=80,actor_minute=1;
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002',(select location_revision from public.recurring_activities where id='a9020000-0000-4000-8000-000000000002'),'exact',gen_random_uuid(),repeat('c',64))->>'status','rate_limited','Per-actor minute cap enforced');
delete from private.location_search_config;
select is(public.reserve_location_search_v1('a9010000-0000-4000-8000-000000000001','recurring','a9020000-0000-4000-8000-000000000002',(select location_revision from public.recurring_activities where id='a9020000-0000-4000-8000-000000000002'),'exact',gen_random_uuid(),repeat('c',64))->>'status','disabled','Missing metering configuration fails closed');
select * from finish();
rollback;
