begin;
select no_plan();
-- Rollback-only synthetic actors. Auth validity is deliberately independent of
-- suspension; the service role must authorize the stored/verified human actor.
insert into auth.users(id,email) select format('bd110000-0000-4000-8000-%s',lpad(n::text,12,'0'))::uuid,
  'modint-location-'||n||'@planets.invalid' from generate_series(1,3) n;
insert into public.profiles(id,display_name) select id,'MODINT location fixture' from auth.users where id::text like 'bd110000-%';
insert into private.moderation_staff_roles(profile_id,staff_role) values('bd110000-0000-4000-8000-000000000001','admin');
insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_profile_id) values
  ('bd120000-0000-4000-8000-000000000001','under_review','bd110000-0000-4000-8000-000000000002','profile','bd110000-0000-4000-8000-000000000002');
insert into public.proposals(id,creator_profile_id,country_code,locality,public_location_label,event_timezone)
 values('bd130000-0000-4000-8000-000000000001','bd110000-0000-4000-8000-000000000002','IT','Synthetic','Synthetic','Europe/Rome');
insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility)
 values('bd130000-0000-4000-8000-000000000001','Private instructions','participants');
insert into public.recurring_activities(id,creator_profile_id,country_code,locality,public_location_label)
 values('bd130000-0000-4000-8000-000000000002','bd110000-0000-4000-8000-000000000002','IT','Synthetic','Synthetic');
insert into public.recurring_activity_meeting_details(recurring_activity_id,exact_meeting_text,exact_location_visibility)
 values('bd130000-0000-4000-8000-000000000002','Private instructions','participants');
insert into public.resource_listings(id,owner_profile_id,listing_mode,country_code,locality,public_location_label)
 values('bd130000-0000-4000-8000-000000000003','bd110000-0000-4000-8000-000000000002','donate','IT','Synthetic','Synthetic');
update private.location_search_config set enabled=true;
create function pg_temp.place() returns jsonb language sql as $$
 select jsonb_build_object('provider','geoapify','kind','locality','result_type','city','country_code','IT',
 'label','Synthetic area','locality','Synthetic','administrative_area',null,'latitude',45,'longitude',12,
 'source','openstreetmap','attribution','Powered by Geoapify | © OpenStreetMap contributors',
 'source_license','https://www.openstreetmap.org/copyright');
$$;
create temporary table scopes(kind text,item uuid,slot text,session uuid,batch uuid,receipt uuid,pending uuid);
do $$
declare k text; i integer:=0; slot text; ready jsonb; pending jsonb; issued jsonb; session uuid;
begin
 for k in select unnest(array['one_time','recurring','resource']) loop
  i:=i+1; slot:=case when k='resource' then 'public' else 'area' end; session:=gen_random_uuid();
  ready:=public.reserve_location_search_v1('bd110000-0000-4000-8000-000000000002',k,
    format('bd130000-0000-4000-8000-%s',lpad(i::text,12,'0'))::uuid,0,slot,session,repeat('a',64));
  issued:=public.issue_location_selections_v1((ready->>'batch_id')::uuid,jsonb_build_array(pg_temp.place()));
  pending:=public.reserve_location_search_v1('bd110000-0000-4000-8000-000000000002',k,
    format('bd130000-0000-4000-8000-%s',lpad(i::text,12,'0'))::uuid,0,slot,gen_random_uuid(),repeat('b',64));
  insert into scopes values(k,format('bd130000-0000-4000-8000-%s',lpad(i::text,12,'0'))::uuid,slot,session,
    (ready->>'batch_id')::uuid,(issued->'suggestions'->0->>'id')::uuid,(pending->>'batch_id')::uuid);
 end loop;
end $$;
select is((select count(*)::int from scopes where receipt is not null and pending is not null),3,
  'Active Creator/Resource owner can reserve and issue all three scopes');
select is(public.resolve_location_selection_v1('bd110000-0000-4000-8000-000000000002',kind,item,0,slot,session,receipt)->>'status','ok',
  kind||': active stored actor resolves receipt') from scopes;
select set_config('test.modint.location.budgets',(select sum(used)::text from private.location_search_budgets),true);
select set_config('test.modint.location.batches',(select count(*)::text from private.location_search_batches),true);
select set_config('test.modint.location.receipts',(select count(*)::text from private.location_selection_receipts),true);
set local role authenticated;
set local request.jwt.claim.sub='bd110000-0000-4000-8000-000000000001';
select set_config('test.modint.location.suspension',public.apply_account_suspension(
 'bd110000-0000-4000-8000-000000000001','bd120000-0000-4000-8000-000000000001','Synthetic access reason','Synthetic private note')::text,true);
reset role;
-- Auth user/session survives. Denial must be reasonless PT403 from the account
-- helper, not invalid credentials, loss of ownership, or the service auth.uid().
select throws_ok(format('select public.reserve_location_search_v1(%L,%L,%L,0,%L,gen_random_uuid(),repeat(''c'',64))',
 'bd110000-0000-4000-8000-000000000002',kind,item,slot),'PT403','Account access is suspended.',
 kind||': suspended actor cannot allocate a new budget/batch') from scopes;
select throws_ok(format('select public.issue_location_selections_v1(%L,jsonb_build_array(pg_temp.place()))',pending),
 'PT403','Account access is suspended.',kind||': old pending batch cannot release results after suspension') from scopes;
select throws_ok(format('select public.resolve_location_selection_v1(%L,%L,%L,0,%L,%L,%L)',
 'bd110000-0000-4000-8000-000000000002',kind,item,slot,session,receipt),
 'PT403','Account access is suspended.',kind||': old issued receipt cannot resolve after suspension') from scopes;
select throws_ok(format('select public.reserve_location_search_v1(%L,%L,%L,0,%L,%L,repeat(''a'',64))',
 'bd110000-0000-4000-8000-000000000002',kind,item,slot,session),'PT403','Account access is suspended.',
 kind||': cached selections cannot bypass current account access') from scopes;
select is((select sum(used) from private.location_search_budgets),current_setting('test.modint.location.budgets')::bigint,'Suspension allocates no additional budgets');
select is((select count(*) from private.location_search_batches),current_setting('test.modint.location.batches')::bigint,'Suspension allocates no new batches');
select is((select count(*) from private.location_selection_receipts),current_setting('test.modint.location.receipts')::bigint,'Suspension publishes no new selection receipts');
set local role authenticated;
set local request.jwt.claim.sub='bd110000-0000-4000-8000-000000000002';
select throws_ok($$select public.get_authorized_item_location_v1('bd110000-0000-4000-8000-000000000002','resource','bd130000-0000-4000-8000-000000000003')$$,
 'PT403',null,'Suspended client protected read denies the actual actor');
select throws_ok($$select public.apply_item_location_v1('bd110000-0000-4000-8000-000000000002','resource','bd130000-0000-4000-8000-000000000003',0,gen_random_uuid(),'clear',null,'unchanged',null)$$,
 'PT403',null,'Suspended client mutation is denied even for manual clear');
select throws_ok($$select public.get_authorized_item_location_v1('bd110000-0000-4000-8000-000000000003','resource','bd130000-0000-4000-8000-000000000003')$$,
 '42501',null,'Expected actor mismatch remains identity failure');
set local request.jwt.claim.sub='bd110000-0000-4000-8000-000000000001';
select public.revoke_account_suspension('bd110000-0000-4000-8000-000000000001',current_setting('test.modint.location.suspension')::uuid,'Synthetic restored','Synthetic private note');
reset role;
select is(public.resolve_location_selection_v1('bd110000-0000-4000-8000-000000000002',kind,item,0,slot,session,receipt)->>'status','ok',
 kind||': revoke restores ordinary receipt access without changing ownership') from scopes;
select ok(not has_function_privilege('authenticated','public.reserve_location_search_v1(uuid,text,uuid,bigint,text,uuid,text)','execute')
 and not has_function_privilege('anon','public.issue_location_selections_v1(uuid,jsonb)','execute')
 and has_function_privilege('service_role','public.resolve_location_selection_v1(uuid,text,uuid,bigint,text,uuid,uuid)','execute'),
 'Service-only grants are unchanged; clients cannot choose another actor');
-- Interaction restriction is not suspension or loss of structural authority.
set local request.jwt.claim.sub='bd110000-0000-4000-8000-000000000001';
select public.apply_moderation_consequence('bd110000-0000-4000-8000-000000000001',
 'bd120000-0000-4000-8000-000000000001','interaction_restriction','Synthetic restriction','Synthetic private note');
select is(public.reserve_location_search_v1('bd110000-0000-4000-8000-000000000002',kind,item,0,slot,session,repeat('a',64))->>'status','ok',
 kind||': restriction preserves ordinary owner location authority') from scopes;
-- Visible fixtures contain real selected metadata/points; hide must suppress
-- Proposal, Tavolo and Resource projections, not merely an already-empty JSON.
update public.projects set registration_capacity=10 where id in ('bd130000-0000-4000-8000-000000000001','bd130000-0000-4000-8000-000000000002');
update public.proposals set lifecycle_state='published',published_at=now(),title='Synthetic location Project',
 summary='Synthetic',description='Synthetic',starts_at=now()+interval '2 days',ends_at=now()+interval '3 days',
 selected_public_place=pg_temp.place()||jsonb_build_object('verified_at',now()),
 approximate_location=private.selected_place_point(pg_temp.place()) where id='bd130000-0000-4000-8000-000000000001';
update public.recurring_activities set lifecycle_state='published',published_at=now(),title='Synthetic location Tavolo',
 summary='Synthetic',description='Synthetic',topic='Synthetic',
 selected_public_place=pg_temp.place()||jsonb_build_object('verified_at',now()),
 approximate_location=private.selected_place_point(pg_temp.place()) where id='bd130000-0000-4000-8000-000000000002';
insert into public.recurring_activity_schedules(recurring_activity_id,recurrence_type,weekday,local_start_time,duration_minutes,event_timezone,effective_from)
 values('bd130000-0000-4000-8000-000000000002','weekly',1,'18:00',60,'Europe/Rome',current_date);
update public.resource_listings set lifecycle_state='published',published_at=now(),title='Synthetic location Resource',description='Synthetic',
 selected_public_place=pg_temp.place()||jsonb_build_object('verified_at',now()),
 public_location=private.selected_place_point(pg_temp.place()) where id='bd130000-0000-4000-8000-000000000003';
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
 values('bd140000-0000-4000-8000-000000000001','bd130000-0000-4000-8000-000000000001','bd110000-0000-4000-8000-000000000003','accepted',now()-interval '2 days',now()-interval '1 day','bd110000-0000-4000-8000-000000000002');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
 values('bd150000-0000-4000-8000-000000000001','bd130000-0000-4000-8000-000000000001','bd110000-0000-4000-8000-000000000003','bd140000-0000-4000-8000-000000000001',now()-interval '1 day');
grant select on scopes to anon,authenticated;
set local role anon;
select is(public.get_public_item_location_v1(kind,item)->'public_place'->>'label','Synthetic area',kind||': canonical visible public location remains public') from scopes;
reset role;
do $$
declare s record; case_id uuid;
begin
 for s in select * from scopes loop
  insert into private.moderation_cases(state,subject_profile_id,target_kind,target_project_id,project_context_id,target_resource_listing_id,resource_listing_context_id)
   values('under_review','bd110000-0000-4000-8000-000000000002',case when s.kind='resource' then 'resource_listing' else 'project' end,
    case when s.kind<>'resource' then s.item end,case when s.kind<>'resource' then s.item end,
    case when s.kind='resource' then s.item end,case when s.kind='resource' then s.item end) returning id into case_id;
  perform public.apply_moderation_consequence('bd110000-0000-4000-8000-000000000001',case_id,'content_hide','Synthetic content reason','Synthetic private note');
 end loop;
end $$;
set local role anon;
select is(public.get_public_item_location_v1(kind,item),null::jsonb,kind||': content hide suppresses the public selected location') from scopes;
reset role;
set local role authenticated;
set local request.jwt.claim.sub='bd110000-0000-4000-8000-000000000002';
select lives_ok(format('select public.get_authorized_item_location_v1(%L,%L,%L)',
 'bd110000-0000-4000-8000-000000000002',kind,item),kind||': content hide preserves entitled owner location read') from scopes;
set local request.jwt.claim.sub='bd110000-0000-4000-8000-000000000003';
select lives_ok($$select public.get_authorized_item_location_v1('bd110000-0000-4000-8000-000000000003','one_time','bd130000-0000-4000-8000-000000000001')$$,
 'Content hide preserves existing accepted member protected read');
reset role;
select is((select count(*)::int from public.project_memberships where id='bd150000-0000-4000-8000-000000000001' and left_at is null and removed_at is null),1,'Existing membership remains stored');
select is((select lifecycle_state from public.proposals where id='bd130000-0000-4000-8000-000000000001'),'published','Hide does not rewrite owner lifecycle');
select * from finish();
rollback;
