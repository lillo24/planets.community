-- D-M01/R03 PROVISIONAL REVIEW ONLY. Member kinds never reach legacy parsers.
create function private.member_contact_kind_rank(p_kind text) returns integer
language sql immutable set search_path='' as $$
  select case when p_kind in ('member_contact_request','member_contact_chat') then 4 else private.group_contact_kind_rank(p_kind) end;
$$;
create function public.list_own_structured_request_message_items_v4(p_expected_profile_id uuid,p_limit integer,
  p_cursor_activity_at timestamptz default null,p_cursor_item_kind text default null,p_cursor_request_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); old_time timestamptz:=p_cursor_activity_at; old_kind text:=p_cursor_item_kind; old_id uuid:=p_cursor_request_id;
begin
  perform private.validate_group_page(p_limit,p_cursor_activity_at,p_cursor_request_id);
  if (p_cursor_item_kind is null)<>(p_cursor_request_id is null) or (p_cursor_item_kind is not null and
    p_cursor_item_kind not in ('participation_request','resource_request','group_contact_request','group_coordination_proposal','member_contact_request')) then
    raise sqlstate '22023' using message='Invalid structured request cursor.'; end if;
  if p_cursor_item_kind='member_contact_request' then
    old_time:=p_cursor_activity_at+interval '1 microsecond'; old_kind:='participation_request'; old_id:='00000000-0000-0000-0000-000000000000';
  end if;
  return (with candidates as (
    select value row from jsonb_array_elements(public.list_own_structured_request_message_items_v3(actor,p_limit,old_time,old_kind,old_id))
    union all select private.member_contact_request_projection(r,actor) from private.member_contact_requests r where actor in(r.sender_profile_id,r.recipient_profile_id)
  ), page as (
    select row from candidates where p_cursor_request_id is null or
      ((row->>'activity_at')::timestamptz,private.member_contact_kind_rank(row->>'item_kind'),coalesce(row->>'proposal_id',row->>'request_id')::uuid)
      <(p_cursor_activity_at,private.member_contact_kind_rank(p_cursor_item_kind),p_cursor_request_id)
    order by (row->>'activity_at')::timestamptz desc,private.member_contact_kind_rank(row->>'item_kind') desc,coalesce(row->>'proposal_id',row->>'request_id')::uuid desc limit p_limit
  ) select coalesce(jsonb_agg(row order by (row->>'activity_at')::timestamptz desc,private.member_contact_kind_rank(row->>'item_kind') desc,coalesce(row->>'proposal_id',row->>'request_id')::uuid desc),'[]') from page);
end; $$;
create function public.get_own_structured_request_message_item_v4(p_expected_profile_id uuid,p_item_kind text,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if p_item_kind='member_contact_request' then return public.get_own_member_contact_request(p_expected_profile_id,p_request_id); end if;
  return public.get_own_structured_request_message_item_v3(p_expected_profile_id,p_item_kind,p_request_id);
end; $$;
create function public.list_own_scoped_conversation_items_v7(p_expected_profile_id uuid,p_scope text,p_limit integer,
  p_cursor_activity_at timestamptz default null,p_cursor_item_kind text default null,p_cursor_chat_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); old_time timestamptz:=p_cursor_activity_at; old_kind text:=p_cursor_item_kind; old_id uuid:=p_cursor_chat_id;
begin
  perform private.validate_group_page(p_limit,p_cursor_activity_at,p_cursor_chat_id);
  if p_scope is null or p_scope not in ('private','groups') or (p_cursor_item_kind is null)<>(p_cursor_chat_id is null)
    or (p_cursor_item_kind is not null and (p_cursor_item_kind not in ('project_chat','resource_chat','project_request_chat','group_contact_chat','member_contact_chat')
      or (p_scope='groups' and p_cursor_item_kind not in ('project_chat','group_contact_chat'))
      or (p_scope='private' and p_cursor_item_kind not in ('resource_chat','project_request_chat','member_contact_chat')))) then
    raise sqlstate '22023' using message='Invalid conversation scope or cursor.'; end if;
  if p_cursor_item_kind='member_contact_chat' then
    old_time:=p_cursor_activity_at+interval '1 microsecond'; old_kind:='resource_chat'; old_id:='00000000-0000-0000-0000-000000000000';
  end if;
  return (with candidates as (
    select value row from jsonb_array_elements(public.list_own_scoped_conversation_items_v6(actor,p_scope,p_limit,old_time,old_kind,old_id))
    union all select private.member_contact_chat_projection(p.id,actor) from private.member_contact_pairs p
      where p_scope='private' and actor in(p.low_profile_id,p.high_profile_id) and private.member_contact_can_read(p.id,actor)
  ), page as (
    select row from candidates where p_cursor_chat_id is null or
      ((row->>'activity_at')::timestamptz,private.member_contact_kind_rank(row->>'item_kind'),(row->>'chat_id')::uuid)
      <(p_cursor_activity_at,private.member_contact_kind_rank(p_cursor_item_kind),p_cursor_chat_id)
    order by (row->>'activity_at')::timestamptz desc,private.member_contact_kind_rank(row->>'item_kind') desc,(row->>'chat_id')::uuid desc limit p_limit
  ) select coalesce(jsonb_agg(row order by (row->>'activity_at')::timestamptz desc,private.member_contact_kind_rank(row->>'item_kind') desc,(row->>'chat_id')::uuid desc),'[]') from page);
end; $$;
create function public.get_own_message_unread_summary_v3(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); legacy jsonb; extra bigint;
begin
  legacy:=public.get_own_message_unread_summary_v2(actor);
  select count(*) into extra from private.member_contact_pairs p where actor in(p.low_profile_id,p.high_profile_id) and private.member_contact_unread(actor,p.id)>0;
  return jsonb_build_object('total',(legacy->>'total')::bigint+extra,'private',(legacy->>'private')::bigint+extra,'groups',(legacy->>'groups')::bigint);
end; $$;
create function public.acknowledge_own_message_read_v3(p_expected_profile_id uuid,p_kind text,p_chat_id uuid,p_boundary uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  if p_kind='member_contact_chat' then perform public.acknowledge_member_contact_read(actor,p_chat_id,p_boundary);
  else perform public.acknowledge_own_message_read_v2(actor,p_kind,p_chat_id,p_boundary); end if;
  return public.get_own_message_unread_summary_v3(actor);
end; $$;

-- Preserve every effective existing Block hook. Reserve the complete Group set
-- before delegation so no later hook acquires a lower Group row after a higher one.
do $$ declare definition text:=pg_get_functiondef('private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION private.close_pending_direct_requests_for_user_block(','FUNCTION private.member_contact_previous_block_convergence('); end; $$;
create or replace function private.close_pending_direct_requests_for_user_block(p_blocker_profile_id uuid,p_blocked_profile_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare groups uuid[]; pair private.member_contact_pairs;
begin
  select array_agg(distinct g order by g) into groups from (
    select r.group_id g from private.group_join_requests r where r.status='pending' and
      ((r.requester_id=p_blocker_profile_id and private.group_authority_role(r.group_id,p_blocked_profile_id) is not null)
        or (r.requester_id=p_blocked_profile_id and private.group_authority_role(r.group_id,p_blocker_profile_id) is not null))
    union all select g from private.group_contact_requests r cross join lateral unnest(array[r.source_group_id,r.target_group_id]) g
      where r.status='pending' and ((r.submitter_id=p_blocker_profile_id and private.group_authority_role(r.target_group_id,p_blocked_profile_id) is not null)
        or (r.submitter_id=p_blocked_profile_id and private.group_authority_role(r.target_group_id,p_blocker_profile_id) is not null))
    union all select p.group_id from private.member_contact_pairs p where p.low_profile_id=least(p_blocker_profile_id,p_blocked_profile_id)
      and p.high_profile_id=greatest(p_blocker_profile_id,p_blocked_profile_id)
  ) affected;
  perform 1 from private.community_groups where id=any(groups) order by id for update;
  perform private.member_contact_previous_block_convergence(p_blocker_profile_id,p_blocked_profile_id);
  for pair in select * from private.member_contact_pairs p where p.low_profile_id=least(p_blocker_profile_id,p_blocked_profile_id)
    and p.high_profile_id=greatest(p_blocker_profile_id,p_blocked_profile_id) order by p.id for update
  loop
    update private.member_contact_requests set status=case when sender_profile_id=p_blocker_profile_id then 'withdrawn' else 'declined' end,
      resolved_at=clock_timestamp(),resolved_by=p_blocker_profile_id,activity_at=clock_timestamp() where pair_id=pair.id and status='pending';
    delete from private.member_contact_read_snapshots where pair_id=pair.id;
    perform private.member_contact_signal(pair.low_profile_id,true);
    perform private.member_contact_signal(pair.high_profile_id,true);
  end loop;
end; $$;

alter table private.moderation_cases
  add column target_member_contact_request_id uuid references private.member_contact_requests(id) on delete restrict,
  add column target_member_contact_message_id uuid references private.member_contact_messages(id) on delete restrict,
  add column member_contact_context_id uuid references private.member_contact_pairs(id) on delete restrict;
create index moderation_cases_member_request on private.moderation_cases(target_member_contact_request_id) where target_member_contact_request_id is not null;
create index moderation_cases_member_message on private.moderation_cases(target_member_contact_message_id) where target_member_contact_message_id is not null;
create index moderation_cases_member_context on private.moderation_cases(member_contact_context_id) where member_contact_context_id is not null;
-- Enumerate pre-existing typed UUID references from the effective schema. This
-- preserves peer constraints if C lands before these forward migrations.
do $$ declare c record; old_expression text; prior_columns text; member_shape text;
begin
  select string_agg(quote_ident(attname),',' order by attnum) into prior_columns from pg_attribute where attrelid='private.moderation_cases'::regclass and attnum>0 and not attisdropped
    and atttypid='uuid'::regtype and (attname like 'target_%' or attname like '%_context_id')
    and attname not in('target_member_contact_request_id','target_member_contact_message_id','member_contact_context_id');
  member_shape:='num_nonnulls('||prior_columns||')=0 and case target_kind when ''member_contact_request'' then target_member_contact_request_id is not null and target_member_contact_message_id is null and member_contact_context_id is null when ''member_contact_message'' then target_member_contact_message_id is not null and target_member_contact_request_id is null and member_contact_context_id is not null else false end';
  for c in select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='private.moderation_cases'::regclass
    and conname=any(array['moderation_cases_target_kind_valid','moderation_cases_one_typed_target','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid'])
  loop
    old_expression:=substring(c.definition from 8 for char_length(c.definition)-8);
    execute format('alter table private.moderation_cases drop constraint %I',c.conname);
    execute format('alter table private.moderation_cases add constraint %I check ((target_kind in (''member_contact_request'',''member_contact_message'') and (%s)) or (target_kind not in (''member_contact_request'',''member_contact_message'') and target_member_contact_request_id is null and target_member_contact_message_id is null and member_contact_context_id is null and (%s)))',c.conname,member_shape,old_expression);
  end loop;
end; $$;
create function private.member_contact_protect_case() returns trigger language plpgsql set search_path='' as $$
begin
  if new.target_member_contact_request_id is distinct from old.target_member_contact_request_id or
    new.target_member_contact_message_id is distinct from old.target_member_contact_message_id or new.member_contact_context_id is distinct from old.member_contact_context_id then
    raise sqlstate '55000' using message='Personal contact report provenance is immutable.'; end if;
  return new;
end; $$;
create trigger member_contact_case_provenance before update on private.moderation_cases for each row execute function private.member_contact_protect_case();
do $$ declare definition text:=pg_get_functiondef('public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION public.submit_moderation_report(','FUNCTION private.member_contact_submit_previous_report('); end; $$;
create or replace function public.submit_moderation_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,p_category text,p_explanation text,
  p_target_kind text,p_target_id uuid,p_context_kind text default null,p_context_id uuid default null)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid; explanation text; existing record; r private.member_contact_requests; m private.member_contact_messages; subject uuid; c private.moderation_cases; report private.moderation_reports;
begin
  if p_target_kind is null or p_target_kind not in ('member_contact_request','member_contact_message') then
    if exists(select 1 from private.moderation_reports mr join private.moderation_cases mc on mc.id=mr.case_id
      where mr.reporter_profile_id=auth.uid() and mr.client_submission_id=p_client_submission_id and mc.target_kind in ('member_contact_request','member_contact_message')) then
      perform private.require_group_identity(p_expected_reporter_profile_id); raise sqlstate 'PT409' using message='This report action has different submitted intent.';
    end if;
    return query select * from private.member_contact_submit_previous_report(p_expected_reporter_profile_id,p_client_submission_id,p_category,p_explanation,p_target_kind,p_target_id,p_context_kind,p_context_id); return;
  end if;
  actor:=private.require_group_identity(p_expected_reporter_profile_id);
  explanation:=regexp_replace(coalesce(p_explanation,''),'^[[:space:]]+|[[:space:]]+$','','g');
  if p_client_submission_id is null or p_target_id is null or p_category is null
    or p_category not in ('safety_concern','harassment_abuse','fraud_scam','inappropriate_content_conduct','spam','other') or char_length(explanation) not between 10 and 4000
    or (p_target_kind='member_contact_request' and (p_context_kind is not null or p_context_id is not null))
    or (p_target_kind='member_contact_message' and (p_context_kind is distinct from 'member_contact_chat' or p_context_id is null)) then
    raise sqlstate '22023' using message='Invalid personal contact report.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
  select mr.*,mc.state,mc.target_kind,coalesce(mc.target_member_contact_request_id,mc.target_member_contact_message_id) target,mc.member_contact_context_id context
    into existing from private.moderation_reports mr join private.moderation_cases mc on mc.id=mr.case_id where mr.reporter_profile_id=actor and mr.client_submission_id=p_client_submission_id;
  if found then
    if existing.target_kind<>p_target_kind or existing.target is distinct from p_target_id or existing.context is distinct from p_context_id or existing.category<>p_category or existing.explanation<>explanation then
      raise sqlstate 'PT409' using message='This report action has different submitted intent.'; end if;
    return query select existing.id,existing.case_id,existing.state,existing.created_at; return;
  end if;
  if p_target_kind='member_contact_request' then
    select * into r from private.member_contact_requests where id=p_target_id;
    if r.id is null or actor<>r.recipient_profile_id or not exists(select 1 from private.member_contact_seen_requests where profile_id=actor and request_id=r.id) then
      raise sqlstate '42501' using message='The report target is unavailable.'; end if;
    subject:=r.sender_profile_id;
  else
    select * into m from private.member_contact_messages where id=p_target_id;
    if m.id is null or m.pair_id<>p_context_id or m.sender_profile_id=actor or not private.member_contact_message_readable(m,actor) then
      raise sqlstate '42501' using message='The report target is unavailable.'; end if;
    subject:=m.sender_profile_id;
  end if;
  if not exists(select 1 from public.profiles where id=subject) then subject:=null; end if;
  insert into private.moderation_cases(subject_profile_id,target_kind,target_member_contact_request_id,target_member_contact_message_id,member_contact_context_id)
    values(subject,p_target_kind,r.id,m.id,p_context_id) returning * into c;
  insert into private.moderation_reports(case_id,reporter_profile_id,client_submission_id,category,explanation,created_at)
    values(c.id,actor,p_client_submission_id,p_category,explanation,c.created_at) returning * into report;
  insert into private.moderation_case_events(case_id,actor_profile_id,event_kind,to_state,state_version,created_at) values(c.id,actor,'report_received','received',0,c.created_at);
  insert into private.audit_events(action,actor_user_id,target_type,target_id,metadata)
    values('moderation.report_submitted',actor,'moderation_case',c.id,jsonb_build_object('case_id',c.id,'report_id',report.id,'target_kind',c.target_kind));
  return query select report.id,c.id,c.state,c.created_at;
end; $$;
do $$ declare definition text:=pg_get_functiondef('private.moderation_target_summary(private.moderation_cases)'::regprocedure);
begin execute replace(definition,'FUNCTION private.moderation_target_summary(','FUNCTION private.member_contact_previous_target_summary('); end; $$;
create or replace function private.moderation_target_summary(p_case private.moderation_cases) returns text language sql stable security definer set search_path='' as $$
  select case p_case.target_kind when 'member_contact_request' then 'Personal conversation request' when 'member_contact_message' then 'Personal conversation message' else private.member_contact_previous_target_summary(p_case) end;
$$;
do $$ declare definition text:=pg_get_functiondef('public.get_moderation_case_group_contact(uuid,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION public.get_moderation_case_group_contact(','FUNCTION private.member_contact_previous_case_evidence('); end; $$;
create or replace function public.get_moderation_case_group_contact(p_expected_staff_profile_id uuid,p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c private.moderation_cases; result jsonb;
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select * into c from private.moderation_cases where id=p_case_id;
  if c.target_kind='member_contact_request' then
    select jsonb_build_object('kind',c.target_kind,'target_id',r.id,'human_id',r.sender_profile_id,'source_group_id',p.group_id,'target_group_id',null,
      'purpose',null,'title',r.group_name,'body',r.note,'created_at',r.created_at) into result from private.member_contact_requests r join private.member_contact_pairs p on p.id=r.pair_id where r.id=c.target_member_contact_request_id;
  elsif c.target_kind='member_contact_message' then
    select jsonb_build_object('kind',c.target_kind,'target_id',m.id,'human_id',m.sender_profile_id,'source_group_id',p.group_id,'target_group_id',null,
      'purpose',null,'title',r.group_name,'body',m.body,'created_at',m.created_at) into result from private.member_contact_messages m join private.member_contact_pairs p on p.id=m.pair_id
      join private.member_contact_episodes e on e.id=m.episode_id join private.member_contact_requests r on r.id=e.request_id where m.id=c.target_member_contact_message_id;
  else return private.member_contact_previous_case_evidence(p_expected_staff_profile_id,p_case_id); end if;
  if result is null then raise sqlstate '42501' using message='The personal contact case evidence is unavailable.'; end if;
  return result;
end; $$;
-- Exact old versions keep their supported kinds. New v4 includes all predecessors.
do $$ declare definition text; predicate text:='where report.reporter_profile_id = reporter_id'; name text;
begin
  definition:=pg_get_functiondef('public.list_own_moderation_reports_v3(uuid,integer,timestamptz,uuid)'::regprocedure);
  if strpos(definition,predicate)=0 then raise exception 'Review effective own report predicate.'; end if;
  execute replace(definition,'FUNCTION public.list_own_moderation_reports_v3(','FUNCTION public.list_own_moderation_reports_v4(');
  foreach name in array array['list_own_moderation_reports','list_own_moderation_reports_v2','list_own_moderation_reports_v3'] loop
    definition:=pg_get_functiondef(format('public.%I(uuid,integer,timestamptz,uuid)',name)::regprocedure);
    if strpos(definition,predicate)=0 then raise exception 'Review effective own report predicate: %',name; end if;
    execute replace(definition,predicate,predicate||' and moderation_case.target_kind not in (''member_contact_request'',''member_contact_message'')');
  end loop;
end; $$;
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'member_contact_%') or (n.nspname='public' and p.proname in
      ('list_own_structured_request_message_items_v4','get_own_structured_request_message_item_v4','list_own_scoped_conversation_items_v7',
       'get_own_message_unread_summary_v3','acknowledge_own_message_read_v3','list_own_moderation_reports_v4'))
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
