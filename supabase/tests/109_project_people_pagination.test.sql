begin;
select no_plan();

-- A deterministic 500-person Project, including 500 ended episodes and resolved requests.
insert into auth.users(id,email) select
 ('7c510000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'people-page-'||n||'@planets.invalid' from generate_series(1,501) n;
insert into public.profiles(id,display_name) select id,'Page person '||right(id::text,12)
 from auth.users where id::text like '7c510000-%';
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
values('7c540000-0000-4000-8000-000000000001','7c510000-0000-4000-8000-000000000001',
 'published','People pagination',now()+interval '1 day',now()+interval '2 days',now());
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
select ('7c530000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '7c540000-0000-4000-8000-000000000001',
 ('7c510000-0000-4000-8000-'||lpad((2+(n-1)%500)::text,12,'0'))::uuid,
 'accepted',now()-interval '3 days',now()-interval '2 days','7c510000-0000-4000-8000-000000000001'
 from generate_series(1,1000) n;
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at,left_at)
select ('7c520000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '7c540000-0000-4000-8000-000000000001',
 ('7c510000-0000-4000-8000-'||lpad((2+(n-1)%500)::text,12,'0'))::uuid,
 ('7c530000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 now()-interval '2 days',case when n<=500 then now()-interval '1 day' else null end
 from generate_series(1,1000) n;

create function pg_temp.collect_pages(section text) returns uuid[] language plpgsql as $$
declare ids uuid[] := '{}'; batch uuid[]; last_row record; cursor_id uuid;
 cursor_rank integer; cursor_time timestamptz; cursor_pending boolean;
 actor uuid := '7c510000-0000-4000-8000-000000000001';
 project uuid := '7c540000-0000-4000-8000-000000000001';
begin
 loop
  batch := '{}';
  if section='people' then
   for last_row in select * from public.list_current_project_people(actor,project,50,cursor_rank,cursor_id) loop
    batch:=array_append(batch,last_row.profile_id);
    cursor_id:=last_row.profile_id; cursor_rank:=last_row.role_rank;
   end loop;
  elsif section='requests' then
   for last_row in select * from public.page_project_requests_for_manager(actor,project,50,cursor_pending,cursor_time,cursor_id) loop
    batch:=array_append(batch,last_row.request_id);
    cursor_id:=last_row.request_id; cursor_time:=last_row.created_at; cursor_pending:=last_row.status='pending';
   end loop;
  else
   for last_row in select * from public.page_project_history_for_manager(actor,project,50,cursor_time,cursor_id) loop
    batch:=array_append(batch,last_row.membership_id);
    cursor_id:=last_row.membership_id; cursor_time:=last_row.joined_at;
   end loop;
  end if;
  if cardinality(batch)>50 then raise exception 'Page exceeded bound'; end if;
  ids:=ids||batch;
  exit when cardinality(batch)<50;
  if cardinality(ids)>2000 then raise exception 'Cursor did not advance'; end if;
 end loop;
 return ids;
end;
$$;
grant execute on function pg_temp.collect_pages(text) to authenticated;
select set_config('request.jwt.claim.sub','7c510000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is(cardinality(pg_temp.collect_pages('people')),501,'all 500 participants plus Creator are reachable through bounded People pages');
select is((select count(distinct id)::integer from unnest(pg_temp.collect_pages('people')) id),501,'People pages contain no duplicates');
select is(cardinality(pg_temp.collect_pages('requests')),1000,'all resolved requests remain independently pageable');
select is((select count(distinct id)::integer from unnest(pg_temp.collect_pages('requests')) id),1000,'request timestamp ties do not duplicate or skip rows');
select is(cardinality(pg_temp.collect_pages('history')),500,'all ended episodes remain independently pageable');
select is((select count(distinct id)::integer from unnest(pg_temp.collect_pages('history')) id),500,'history timestamp ties do not duplicate or skip episodes');
select throws_ok($$select public.page_project_requests_for_manager('7c510000-0000-4000-8000-000000000001','7c540000-0000-4000-8000-000000000001',50,true,null,null)$$,'22023','Invalid request page or cursor.','partial request cursor rejected');
select throws_ok($$select public.page_project_history_for_manager('7c510000-0000-4000-8000-000000000001','7c540000-0000-4000-8000-000000000001',51)$$,'22023','Invalid history page or cursor.','history bound is enforced');
select throws_ok($$select public.list_project_role_offers('7c510000-0000-4000-8000-000000000001','7c540000-0000-4000-8000-000000000001',null)$$,'22023','Invalid role offer page or cursor.','offer bound cannot be bypassed with null');
reset role;
select * from finish();
rollback;
