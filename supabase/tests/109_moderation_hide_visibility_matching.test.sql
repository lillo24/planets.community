begin;
select no_plan();
insert into auth.users(id,email) values
  ('fa100000-0000-4000-8000-000000000001','hide-owner@planets.invalid'),
  ('fa100000-0000-4000-8000-000000000002','hide-staff@planets.invalid'),
  ('fa100000-0000-4000-8000-000000000003','hide-searcher@planets.invalid');
insert into public.profiles(id,display_name) select id,'Visibility fixture' from auth.users where id::text like 'fa100000-%';
insert into public.profile_photos(profile_id,object_path,audience)
values('fa100000-0000-4000-8000-000000000001','fa100000-0000-4000-8000-000000000001/fa900000-0000-4000-8000-000000000001.webp','interactions');
insert into private.moderation_staff_roles(profile_id,staff_role) values('fa100000-0000-4000-8000-000000000002','admin');
select set_config('request.jwt.claim.sub','fa100000-0000-4000-8000-000000000001',true);
select set_config('test.hide.tavolo',public.create_recurring_activity_draft(
  'fa100000-0000-4000-8000-000000000001','Hidden Tavolo','Visibility verification','Synthetic activity description','Community',
  'IT','Trento','TN','Trento','Synthetic private meeting','participants','weekly',3,null,'19:00'::time,90,'Europe/Rome',current_date)::text,true);
update public.projects set registration_capacity=10 where id=current_setting('test.hide.tavolo')::uuid;
select public.publish_recurring_activity('fa100000-0000-4000-8000-000000000001',current_setting('test.hide.tavolo')::uuid);
insert into public.resource_listings(id,owner_profile_id,listing_mode,lifecycle_state,title,description,country_code,locality,public_location_label,published_at)
values('fa300000-0000-4000-8000-000000000001','fa100000-0000-4000-8000-000000000001','exchange','published','Hidden trapano','Synthetic matching verification','IT','Trento','Trento',statement_timestamp());
insert into public.project_covers(project_id,object_path)
values(current_setting('test.hide.tavolo')::uuid,'fa100000-0000-4000-8000-000000000001/projects/' || current_setting('test.hide.tavolo') || '/fa900000-0000-4000-8000-000000000002.webp');
insert into public.resource_listing_covers(listing_id,object_path)
values('fa300000-0000-4000-8000-000000000001','fa100000-0000-4000-8000-000000000001/resources/fa300000-0000-4000-8000-000000000001/fa900000-0000-4000-8000-000000000003.webp');
insert into storage.objects(bucket_id,name,owner_id,metadata)
select 'cover-images',object_path,'fa100000-0000-4000-8000-000000000001','{"mimetype":"image/webp","size":64}'::jsonb from public.project_covers where project_id=current_setting('test.hide.tavolo')::uuid
union all select 'cover-images',object_path,'fa100000-0000-4000-8000-000000000001','{"mimetype":"image/webp","size":64}'::jsonb from public.resource_listing_covers where listing_id='fa300000-0000-4000-8000-000000000001';
insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_project_id,project_context_id,target_resource_listing_id,resource_listing_context_id) values
  ('fa200000-0000-4000-8000-000000000001','under_review','fa100000-0000-4000-8000-000000000001','project',current_setting('test.hide.tavolo')::uuid,current_setting('test.hide.tavolo')::uuid,null,null),
  ('fa200000-0000-4000-8000-000000000002','under_review','fa100000-0000-4000-8000-000000000001','resource_listing',null,null,'fa300000-0000-4000-8000-000000000001','fa300000-0000-4000-8000-000000000001');
select is((select count(*)::int from public.get_public_recurring_activity(current_setting('test.hide.tavolo')::uuid,5,statement_timestamp())),1,'Published Tavolo initially visible');
select ok(exists(select 1 from public.list_public_recurring_activity_occurrences(current_setting('test.hide.tavolo')::uuid,statement_timestamp(),statement_timestamp()+interval '14 days')),'Published occurrences initially visible');
select set_config('request.jwt.claim.sub','fa100000-0000-4000-8000-000000000002',true);
select set_config('test.hide.tavolo_episode',public.apply_moderation_consequence('fa100000-0000-4000-8000-000000000002','fa200000-0000-4000-8000-000000000001','content_hide','User-facing hide','Private hide note')::text,true);
select set_config('test.hide.resource_episode',public.apply_moderation_consequence('fa100000-0000-4000-8000-000000000002','fa200000-0000-4000-8000-000000000002','content_hide','User-facing hide','Private hide note')::text,true);
select is_empty($$select * from public.get_public_recurring_activity(current_setting('test.hide.tavolo')::uuid,5,statement_timestamp())$$,'Hidden Tavolo detail absent');
select is_empty($$select * from public.list_public_recurring_activities(statement_timestamp()) where recurring_activity_id=current_setting('test.hide.tavolo')::uuid$$,'Hidden Tavolo list absent');
select is_empty($$select * from public.list_public_recurring_activity_occurrences(current_setting('test.hide.tavolo')::uuid,statement_timestamp(),statement_timestamp()+interval '14 days')$$,'Hidden Tavolo occurrences absent');
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is_empty($$select name from storage.objects where bucket_id='cover-images'$$,'Known cover paths cannot bypass Storage policies');
reset role;
select set_config('request.jwt.claim.sub','fa100000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id='cover-images'),2,'Owner retains cover management reads and bytes');
select public.pause_recurring_activity('fa100000-0000-4000-8000-000000000001',current_setting('test.hide.tavolo')::uuid);
select is_empty($$select * from public.get_public_recurring_activity(current_setting('test.hide.tavolo')::uuid,5,statement_timestamp())$$,'Hidden paused historical detail absent');
select public.resume_recurring_activity('fa100000-0000-4000-8000-000000000001',current_setting('test.hide.tavolo')::uuid);
select is_empty($$select * from public.get_public_recurring_activity(current_setting('test.hide.tavolo')::uuid,5,statement_timestamp())$$,'Owner resume cannot clear hide');
select public.end_recurring_activity('fa100000-0000-4000-8000-000000000001',current_setting('test.hide.tavolo')::uuid);
select is_empty($$select * from public.get_public_recurring_activity(current_setting('test.hide.tavolo')::uuid,5,statement_timestamp())$$,'Hidden ended historical detail absent');
reset role;
select set_config('request.jwt.claim.sub','fa100000-0000-4000-8000-000000000002',true);
select public.revoke_moderation_consequence('fa100000-0000-4000-8000-000000000002',current_setting('test.hide.tavolo_episode')::uuid,'Unhide','Private revoke note');
select is((select lifecycle_state from public.recurring_activities where id=current_setting('test.hide.tavolo')::uuid),'ended','Unhide never resumes ended Tavolo');
select is((select count(*)::int from public.get_public_recurring_activity(current_setting('test.hide.tavolo')::uuid,5,statement_timestamp())),1,'Unhide restores ordinary historical detail');
select is_empty($$select * from public.list_public_recurring_activities(statement_timestamp()) where recurring_activity_id=current_setting('test.hide.tavolo')::uuid$$,'Unhide does not restore ended active discovery');
select set_config('request.jwt.claim.sub','fa100000-0000-4000-8000-000000000003',true);
select public.create_resource_saved_search('fa100000-0000-4000-8000-000000000003','trapano',null,null);
insert into private.outbox_events(event_type,payload) values('resource_listing.published',jsonb_build_object('listing_id','fa300000-0000-4000-8000-000000000001','owner_profile_id','fa100000-0000-4000-8000-000000000001','listing_mode','exchange'));
select public.process_resource_saved_search_matching_outbox_batch(100);
select is((select count(*)::int from private.resource_saved_search_listing_matches where listing_id='fa300000-0000-4000-8000-000000000001'),0,'Hidden listing creates no new saved-search match');
select set_config('request.jwt.claim.sub','fa100000-0000-4000-8000-000000000002',true);
select public.revoke_moderation_consequence('fa100000-0000-4000-8000-000000000002',current_setting('test.hide.resource_episode')::uuid,'Unhide','Private revoke note');
insert into private.outbox_events(event_type,payload) values('resource_listing.published',jsonb_build_object('listing_id','fa300000-0000-4000-8000-000000000001','owner_profile_id','fa100000-0000-4000-8000-000000000001','listing_mode','exchange'));
select public.process_resource_saved_search_matching_outbox_batch(100);
select is((select count(*)::int from private.resource_saved_search_listing_matches where listing_id='fa300000-0000-4000-8000-000000000001'),1,'Visible listing can create new match');
select public.apply_moderation_consequence('fa100000-0000-4000-8000-000000000002','fa200000-0000-4000-8000-000000000002','content_hide','Hide again','Private hide note');
select is_empty($$select resolved.* from private.outbox_events event cross join lateral private.resolve_saved_search_matching_notification_event(event.id) resolved where event.event_type='resource_saved_search.matched'$$,'Hidden historical match cannot create new delivery');
select is((select count(*)::int from private.resource_saved_search_listing_matches where listing_id='fa300000-0000-4000-8000-000000000001'),1,'Hide preserves historical match fact');
select * from finish();
rollback;
