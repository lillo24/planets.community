begin;
select no_plan();

-- Provisional organization only. Legacy NULL rows are never classified as Other.
select col_type_is('public','resource_listings','category_slug','text','Listing category is canonical text');
select col_is_null('public','resource_listings','category_slug','Legacy listings remain nullable');
select col_is_null('public','resource_saved_searches','category_slug','Legacy definitions remain unrestricted');
select ok(not has_table_privilege('authenticated','public.resource_listings','UPDATE'),'No direct listing writes');
select ok(not has_table_privilege('authenticated','public.resource_saved_searches','SELECT'),'Saved definitions remain RPC-only');
select ok(not has_function_privilege('anon','public.create_resource_saved_search_v2(uuid,text,text,text,text)','EXECUTE'),'No anonymous save');
select ok(not has_function_privilege('service_role','public.update_own_resource_listing_v2(uuid,uuid,text,text,text,text,text,text,text,text)','EXECUTE'),'Service role cannot use owner writes');
select ok(not has_function_privilege('authenticated','private.resource_listing_matches_saved_search_filters_v2(text,text,text,text,text,text,text,text,text)','EXECUTE'),'Private matcher stays private');
select results_eq(
 $$select private.normalize_resource_category_slug(value) from unnest(array['tools_diy','garden_outdoors','home_furniture','electronics','clothing_accessories','books_learning','sports_hobbies','materials','other']) value$$,
 $$values ('tools_diy'::text),('garden_outdoors'),('home_furniture'),('electronics'),('clothing_accessories'),('books_learning'),('sports_hobbies'),('materials'),('other')$$,
 'Exactly the nine approved organizational slugs are supported');
select throws_ok($$select private.normalize_resource_category_slug('food')$$,'22023','Unsupported resource category.','No unapproved category');

insert into auth.users(id,email) values
 ('c7010000-0000-4000-8000-000000000001','cat01-owner@planets.invalid'),
 ('c7010000-0000-4000-8000-000000000002','cat01-reader@planets.invalid');
insert into public.profiles(id,display_name) values
 ('c7010000-0000-4000-8000-000000000001','CAT01 synthetic owner'),
 ('c7010000-0000-4000-8000-000000000002','CAT01 synthetic reader');
insert into public.profile_photos(profile_id,object_path,audience)
 values ('c7010000-0000-4000-8000-000000000001','c7010000-0000-4000-8000-000000000001/c7010000-0000-4000-8000-000000000001.webp','interactions');

set local role authenticated;
select set_config('request.jwt.claim.sub','c7010000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.create_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','donate',null,null,null,null,null,null,'unknown')$$,'22023','Unsupported resource category.','Invalid draft category fails explicitly');
select set_config('cat01.legacy',public.create_resource_listing_draft('c7010000-0000-4000-8000-000000000001','donate','CAT01 Legacy drill','Synthetic category fixture','IT','Trento',null,'Trento')::text,true);
select lives_ok($$select public.publish_resource_listing('c7010000-0000-4000-8000-000000000001',current_setting('cat01.legacy')::uuid)$$,'Old client publication still accepts omitted category');
select is((select category_slug from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.legacy')::uuid)),null::text,'Legacy publication stays unclassified');
select set_config('cat01.null_draft',public.create_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','donate',null,null,null,null,null,null,null)::text,true);
select is((select category_slug from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.null_draft')::uuid)),null::text,'V2 incomplete draft may be unset');
select set_config('cat01.tools',public.create_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','donate','CAT01 Tools drill','Synthetic category fixture','IT','Trento',null,'Trento',' Tools_DIY ')::text,true);
select set_config('cat01.tools2',public.create_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','exchange','CAT01 Exchange drill','Synthetic category fixture','IT','Trento',null,'Trento','tools_diy')::text,true);
select set_config('cat01.materials',public.create_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','donate','CAT01 Materials','Synthetic category fixture','IT','Trento',null,'Trento','materials')::text,true);
select is((select category_slug from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid)),'tools_diy','Write normalizes case and whitespace');
select set_config('cat01.receipt',public.create_editor_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','c7020000-0000-4000-8000-000000000001','donate','CAT01 Receipt',null,null,null,null,null,'books_learning')::text,true);
select is(public.create_editor_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','c7020000-0000-4000-8000-000000000001','donate','CAT01 Receipt',null,null,null,null,null,'books_learning'),current_setting('cat01.receipt')::uuid,'Creation retry keeps one categorized draft');
select throws_ok($$select public.create_editor_resource_listing_draft_v2('c7010000-0000-4000-8000-000000000001','c7020000-0000-4000-8000-000000000001','donate','CAT01 Receipt',null,null,null,null,null,'other')$$,'22023','The recorded draft creation intent differs.','Creation receipt binds category');
select is(public.recover_editor_resource_listing_draft('c7010000-0000-4000-8000-000000000001','c7020000-0000-4000-8000-000000000001'),current_setting('cat01.receipt')::uuid,'Existing recovery API finds V2 receipt');
select public.publish_resource_listing('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid);
select public.publish_resource_listing('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools2')::uuid);
select public.publish_resource_listing('c7010000-0000-4000-8000-000000000001',current_setting('cat01.materials')::uuid);
select set_config('cat01.published_at',(select published_at::text from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid)),true);
select lives_ok($$select public.update_own_resource_listing('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid,'donate','CAT01 Tools drill','Synthetic category fixture','IT','Trento',null,'Trento')$$,'Old edits of categorized rows remain legitimate');
select is((select category_slug from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid)),'tools_diy','Old edit preserves category');

select set_config('request.jwt.claim.sub','c7010000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.update_own_resource_listing_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.tools')::uuid,'donate','CAT01 Hacked','Synthetic category fixture','IT','Trento',null,'Trento','other')$$,'42501',null,'Other owner cannot classify a listing');
select is((select count(*) from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.tools')::uuid)),0::bigint,'Owner category read stays scoped');
select throws_ok($$select public.create_resource_saved_search_v2('c7010000-0000-4000-8000-000000000001',null,null,null,'tools_diy')$$,'42501',null,'Stale saved-search identity fails closed');
select set_config('cat01.search',public.create_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',null,null,null,' Tools_DIY ')::text,true);
select set_config('cat01.search_other',public.create_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',null,null,null,'materials')::text,true);
select set_config('cat01.search_legacy',public.create_resource_saved_search('c7010000-0000-4000-8000-000000000002','CAT01',null,null)::text,true);
select is((select category_slug from public.get_own_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.search')::uuid)),'tools_diy','Category-only definition round-trips');
select is((select count(*) from public.list_own_resource_saved_searches_v2('c7010000-0000-4000-8000-000000000002')),3::bigint,'V2 lists full category-aware definitions');
select is((select count(*) from public.list_own_resource_saved_searches('c7010000-0000-4000-8000-000000000002')),1::bigint,'V1 lists only representable NULL-category definitions');
select is((select count(*) from public.get_own_resource_saved_search('c7010000-0000-4000-8000-000000000002',current_setting('cat01.search')::uuid)),0::bigint,'V1 cannot misrepresent a category-only definition');
select throws_ok($$select public.create_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',null,null,null,'tools_diy')$$,'PT409','That resource saved search already exists.','Category participates in semantic duplicates');
select throws_ok($$select public.create_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',null,null,null,'unknown')$$,'22023','Unsupported resource category.','Saved-search unknown category rejected');
select throws_ok($$select public.create_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',null,null,null,null)$$,'22023',null,'All-empty definition still invalid');
select lives_ok($$select public.update_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.search_other')::uuid,'CAT01','exchange','Trento','books_learning')$$,'Category-aware edit stores whole tuple');
select results_eq($$select query,listing_mode,locality,category_slug from public.get_own_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.search_other')::uuid)$$,$$values ('CAT01'::text,'exchange'::text,'Trento'::text,'books_learning'::text)$$,'Edited definition keeps all dimensions');
select lives_ok($$select public.update_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.search_other')::uuid,null,null,null,'materials')$$,'Category-only edit remains valid');

reset role;
-- Projection chronology is explicit and synthetic, independent of execution speed.
update public.resource_saved_searches set created_at=now()-interval '2 days' where profile_id='c7010000-0000-4000-8000-000000000002';
alter table public.resource_saved_searches disable trigger resource_saved_searches_set_updated_at;
update public.resource_saved_searches set updated_at=now()-interval '1 day' where profile_id='c7010000-0000-4000-8000-000000000002';
alter table public.resource_saved_searches enable trigger resource_saved_searches_set_updated_at;

set local role anon;
select is((select count(*) from public.list_public_resource_listings_v2(50,null,null,null,null,'CAT01',null)),4::bigint,'All includes legacy NULL and explicit categories');
select is((select count(*) from public.list_public_resource_listings_v2(50,null,null,null,null,'CAT01','tools_diy')),2::bigint,'Specific category excludes legacy NULL');
select is((select count(*) from public.list_public_resource_listings_v2(50,null,null,'DONATE',' trento ','Drill',' TOOLS_DIY ')),1::bigint,'Category conjoins mode, literal query and exact locality');
select is((select count(*) from public.list_public_resource_listings_v2(50,null,null,null,null,'CAT01','other')),0::bigint,'Unclassified never means Other');
select is((select category_slug from public.get_public_resource_listing_v2(current_setting('cat01.legacy')::uuid)),null::text,'Legacy detail never invents classification');
select is((select category_slug from public.get_public_resource_listing_v2(current_setting('cat01.tools')::uuid)),'tools_diy','Public detail exposes explicit classification');
select throws_ok($$select * from public.list_public_resource_listings_v2(20,null,null,null,null,null,'unknown')$$,'22023','Unsupported resource category.','Public filter validates slug');
select throws_ok($$select * from public.list_public_resource_listings_v2(20,now(),null,null,null,null,'tools_diy')$$,'22023',null,'Paired cursor contract retained');
select results_eq(
 $$with first_page as (select * from public.list_public_resource_listings_v2(1,null,null,null,null,'CAT01','tools_diy'))
   select listing_id from first_page union all
   select listing_id from public.list_public_resource_listings_v2(1,(select published_at from first_page),(select listing_id from first_page),null,null,'CAT01','tools_diy')$$,
 $$select listing_id from public.list_public_resource_listings_v2(50,null,null,null,null,'CAT01','tools_diy')$$,
 'Category applies before keyset limit; tied pages equal bounded full result');
select is((select count(*) from public.list_public_resource_listings(50,null,null,null,null,'CAT01')),4::bigint,'Legacy public endpoint remains compatible');
select throws_ok($$select * from public.list_own_resource_saved_searches_v2(null)$$,'42501',null,'Anonymous cannot read category definitions');
reset role;

select ok(private.resource_listing_matches_saved_search_filters_v2('donate','Drill','fixture','Trento',null,null,null,'tools_diy','tools_diy'),'Category-only predicate matches exact classification');
select ok(not private.resource_listing_matches_saved_search_filters_v2('donate','Drill','fixture','Trento',null,null,null,null,'tools_diy'),'Restricted definition rejects legacy listing');
select ok(not private.resource_listing_matches_saved_search_filters_v2('donate','Drill','fixture','Trento',null,null,null,'materials','tools_diy'),'Different classification does not match');
select ok(private.resource_listing_matches_saved_search_filters_v2('donate','Drill','fixture','Trento',null,null,null,null,null),'Legacy unrestricted predicate remains valid');
select ok(not private.resource_listing_matches_saved_search_filters_v2('donate','Drill','fixture','Trento','exchange','Drill','Trento','tools_diy','tools_diy'),'Mode remains independent conjunction');
select ok(not private.resource_listing_matches_saved_search_filters_v2('donate','Drill','fixture','Trento',null,'%','Trento','tools_diy','tools_diy'),'Literal keyword semantics retained');

set local role service_role;
select lives_ok($$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,'Category-aware publication projection succeeds');
reset role;
select is((select count(*) from private.resource_saved_search_listing_matches where saved_search_id=current_setting('cat01.search')::uuid),2::bigint,'Only the two explicit Tools listings match category-only definition');
select is((select count(*) from private.resource_saved_search_listing_matches where saved_search_id=current_setting('cat01.search_other')::uuid),1::bigint,'Different category has its own exact match');
select is((select count(*) from private.resource_saved_search_listing_matches where saved_search_id=current_setting('cat01.search_legacy')::uuid),4::bigint,'Existing unrestricted definition still matches legacy and categorized rows');
select ok(not exists(select 1 from private.outbox_events where event_type='resource_saved_search.matched' and payload->>'saved_search_id'=current_setting('cat01.search') and (payload ? 'category_slug' or payload::text like '%tools_diy%')),'Match events remain identifier-only');
select set_config('cat01.match_event',(select id::text from private.outbox_events where event_type='resource_saved_search.matched' and payload->>'saved_search_id'=current_setting('cat01.search') and payload->>'listing_id'=current_setting('cat01.tools') limit 1),true);
select is((select count(*) from private.resolve_saved_search_matching_notification_event(current_setting('cat01.match_event')::uuid)),1::bigint,'Current category match can project a notification');
set local role service_role;
select lives_ok($$select * from public.process_notification_outbox_batch(100)$$,'Category matches project through existing notification pipeline');
select lives_ok($$select * from public.process_push_outbox_batch(100)$$,'Category matches project through existing push pipeline');
reset role;
select is((select count(*) from public.notifications where recipient_profile_id='c7010000-0000-4000-8000-000000000002' and resource_listing_id=current_setting('cat01.tools')::uuid and notification_kind='matching_available'),1::bigint,'Overlapping category and keyword definitions produce one notification');
select is((select count(*) from private.push_delivery_jobs where recipient_profile_id='c7010000-0000-4000-8000-000000000002' and resource_listing_id=current_setting('cat01.tools')::uuid and notification_kind='matching_available'),1::bigint,'Overlapping definitions produce one push job');
select set_config('cat01.materials_event',(select id::text from private.outbox_events where event_type='resource_saved_search.matched' and payload->>'saved_search_id'=current_setting('cat01.search_other') limit 1),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','c7010000-0000-4000-8000-000000000002',true);
select public.update_resource_saved_search_v2('c7010000-0000-4000-8000-000000000002',current_setting('cat01.search_other')::uuid,null,null,null,'books_learning');
reset role;
select is((select count(*) from private.resolve_saved_search_matching_notification_event(current_setting('cat01.materials_event')::uuid)),0::bigint,'Category edit updates saved-search version and suppresses stale delivery');

set local role authenticated;
select set_config('request.jwt.claim.sub','c7010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.update_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid,'donate','CAT01 Tools drill','Synthetic category fixture','IT','Trento',null,'Trento','electronics')$$,'Published owner may change classification');
select is((select published_at from public.get_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid)),current_setting('cat01.published_at')::timestamptz,'Category edit preserves publication timestamp');
reset role;
select is((select count(*) from private.resolve_saved_search_matching_notification_event(current_setting('cat01.match_event')::uuid)),0::bigint,'Notification revalidation suppresses changed listing category');
select is((select count(*) from private.outbox_events where event_type='resource_listing.published' and payload->>'listing_id'=current_setting('cat01.tools')),1::bigint,'Category edit creates no new publication/backfill');
set local role authenticated;
select public.update_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools')::uuid,'donate','CAT01 Tools drill','Synthetic category fixture','IT','Trento',null,'Trento','tools_diy');
select public.close_resource_listing('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools2')::uuid);
select throws_ok($$select public.update_own_resource_listing_v2('c7010000-0000-4000-8000-000000000001',current_setting('cat01.tools2')::uuid,'exchange','CAT01 Exchange drill','Synthetic category fixture','IT','Trento',null,'Trento','other')$$,'55000',null,'Closed listing remains terminal');
reset role;

create function pg_temp.cat01_place() returns jsonb language sql as $$
 select jsonb_build_object('provider','geoapify','kind','locality','result_type','city',
 'label','CAT01 Synthetic Trento','country_code','IT','locality','Trento','latitude',46.07,'longitude',11.12,
 'source','openstreetmap','attribution','Powered by Geoapify | © OpenStreetMap contributors',
 'source_license','https://www.openstreetmap.org/copyright','verified_at','2026-10-01T00:00:00Z')
$$;
update public.resource_listings set selected_public_place=pg_temp.cat01_place(),public_location=private.selected_place_point(pg_temp.cat01_place())
 where owner_profile_id='c7010000-0000-4000-8000-000000000001' and lifecycle_state='published';
insert into public.proposals(id,creator_profile_id,definition_phase,title,summary,description,starts_at,ends_at,event_timezone,country_code,locality,public_location_label,selected_public_place,approximate_location)
 values ('c7030000-0000-4000-8000-000000000001','c7010000-0000-4000-8000-000000000001','defined','CAT01 Project','Synthetic summary','Synthetic description',now()+interval '1 day',now()+interval '2 days','Europe/Rome','IT','Trento','CAT01 Synthetic Trento',pg_temp.cat01_place(),private.selected_place_point(pg_temp.cat01_place()));
update public.projects set registration_capacity=10 where id='c7030000-0000-4000-8000-000000000001';
update public.proposals set lifecycle_state='published',published_at=now() where id='c7030000-0000-4000-8000-000000000001';
insert into public.recurring_activities(id,creator_profile_id,title,summary,description,topic,country_code,locality,public_location_label,selected_public_place,approximate_location)
 values ('c7030000-0000-4000-8000-000000000002','c7010000-0000-4000-8000-000000000001','CAT01 Table','Synthetic summary','Synthetic description','Synthetic topic','IT','CAT01','CAT01 Synthetic Trento',pg_temp.cat01_place(),private.selected_place_point(pg_temp.cat01_place()));
update public.projects set registration_capacity=10 where id='c7030000-0000-4000-8000-000000000002';
insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from)
 values ('c7030000-0000-4000-8000-000000000002','weekly',1,'12:00',60,'Europe/Rome',current_date);
update public.recurring_activities set lifecycle_state='published',published_at=now() where id='c7030000-0000-4000-8000-000000000002';
create function pg_temp.cat01_geo() returns jsonb language sql as $$
 select '{"mode":"radius","latitude":46.07,"longitude":11.12,"radius_m":5000,"proposal_keyword":"CAT01","tavolo_locality":"CAT01","resource_keyword":"CAT01"}'::jsonb||jsonb_build_object('reference_time',now())
$$;
create temp table cat01_map as select public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":"tools_diy"}') value;
select is((select count(*) from jsonb_array_elements((select value->'items' from cat01_map)) item where item->>'kind'='resource'),1::bigint,'Radius filters categorized Resource candidates before pagination');
select is((select count(*) from jsonb_array_elements((select value->'items' from cat01_map)) item where item->>'item_id' in ('c7030000-0000-4000-8000-000000000001','c7030000-0000-4000-8000-000000000002')),2::bigint,'Mixed All retains Project and Tavolo');
select is(public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":" Tools_DIY "}')->'items',(select value->'items' from cat01_map),'Geography normalizes category slug');
select is(public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":null}')->>'query_key',public.search_public_geography_v1(pg_temp.cat01_geo())->>'query_key','Null category preserves legacy map cursor identity');
select is(public.search_public_geography_v1((pg_temp.cat01_geo()-array['mode','latitude','longitude','radius_m'])||'{"mode":"bounds","south":46.06,"north":46.08,"west":11.11,"east":11.13,"resource_category_slug":"tools_diy"}')->'items',(select value->'items' from cat01_map),'Bounds and radius share category predicate');
select throws_ok($$select public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":"unknown"}')$$,'22023','Unsupported resource category.','Geographic unknown category rejected');
select throws_ok($$select public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":123}')$$,'22023',null,'Geographic category must be text');
select throws_ok($$select public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":"materials"}',1,public.search_public_geography_v1(pg_temp.cat01_geo()||'{"resource_category_slug":"tools_diy"}',1)->'next_cursor')$$,'22023',null,'Map cursor is category-bound');

select * from finish();
rollback;
