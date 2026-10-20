-- D03 additive Requests v3. Installed v1/v2 clients retain their exact kinds.
create or replace function private.group_contact_kind_rank(p_kind text) returns integer
language sql immutable set search_path='' as $$
  select case p_kind when 'project_chat' then 0 when 'resource_chat' then 1 when 'project_request_chat' then 2 when 'group_contact_chat' then 3
    when 'participation_request' then 0 when 'resource_request' then 1 when 'group_contact_request' then 2 when 'group_coordination_proposal' then 3 end;
$$;
create function public.list_own_structured_request_message_items_v3(p_expected_profile_id uuid,p_limit integer,
  p_cursor_activity_at timestamptz default null,p_cursor_item_kind text default null,p_cursor_request_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); old_time timestamptz:=p_cursor_activity_at;
  old_kind text:=p_cursor_item_kind; old_id uuid:=p_cursor_request_id;
begin
  perform private.validate_group_page(p_limit,p_cursor_activity_at,p_cursor_request_id);
  if (p_cursor_item_kind is null)<>(p_cursor_request_id is null) or
    (p_cursor_item_kind is not null and private.group_contact_kind_rank(p_cursor_item_kind) is null) or
    p_cursor_item_kind in ('project_chat','resource_chat','project_request_chat','group_contact_chat') then
    raise sqlstate '22023' using message='Invalid structured request cursor.'; end if;
  if p_cursor_item_kind='group_coordination_proposal' then
    old_time:=p_cursor_activity_at+interval '1 microsecond'; old_kind:='participation_request'; old_id:='00000000-0000-0000-0000-000000000000';
  end if;
  return (with candidates as (
    select value row from jsonb_array_elements(public.list_own_structured_request_message_items_v2(actor,p_limit,old_time,old_kind,old_id))
    union all select private.group_coordination_projection(p,actor) from private.group_coordination_proposals p
      join private.group_coordination_candidate_ids(actor) candidate(id) on candidate.id=p.id where private.group_coordination_visible(p,actor)
  ), page as (
    select row from candidates where p_cursor_request_id is null or
      ((row->>'activity_at')::timestamptz,private.group_contact_kind_rank(row->>'item_kind'),coalesce(row->>'proposal_id',row->>'request_id')::uuid)
      <(p_cursor_activity_at,private.group_contact_kind_rank(p_cursor_item_kind),p_cursor_request_id)
    order by (row->>'activity_at')::timestamptz desc,private.group_contact_kind_rank(row->>'item_kind') desc,coalesce(row->>'proposal_id',row->>'request_id')::uuid desc limit p_limit
  ) select coalesce(jsonb_agg(row order by (row->>'activity_at')::timestamptz desc,private.group_contact_kind_rank(row->>'item_kind') desc,coalesce(row->>'proposal_id',row->>'request_id')::uuid desc),'[]') from page);
end; $$;
create function public.get_own_structured_request_message_item_v3(p_expected_profile_id uuid,p_item_kind text,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if p_item_kind='group_coordination_proposal' then return public.get_own_group_coordination_proposal(p_expected_profile_id,p_request_id); end if;
  return public.get_own_structured_request_message_item_v2(p_expected_profile_id,p_item_kind,p_request_id);
end; $$;

-- Previously disclosed invitations remain reportable after role loss; no report
-- operation returns the note/audience or restores ordinary conversation access.
alter table private.moderation_cases add column target_group_coordination_id uuid references private.group_coordination_proposals(id) on delete restrict;
create index moderation_cases_coordination_idx on private.moderation_cases(target_group_coordination_id) where target_group_coordination_id is not null;
do $$ declare c record; old_expression text;
begin
  for c in select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='private.moderation_cases'::regclass
    and conname=any(array['moderation_cases_target_kind_valid','moderation_cases_one_typed_target','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid'])
  loop
    old_expression:=substring(c.definition from 8 for char_length(c.definition)-8);
    execute format('alter table private.moderation_cases drop constraint %I',c.conname);
    execute format('alter table private.moderation_cases add constraint %I check ((target_kind=''group_coordination_proposal'' and target_group_coordination_id is not null and num_nonnulls(target_group_id,target_proposal_template_id,target_profile_id,target_project_id,target_project_chat_message_id,target_resource_listing_id,target_resource_request_id,target_resource_chat_message_id,target_group_contact_request_id,target_group_contact_message_id,group_contact_context_id,project_context_id,resource_listing_context_id,resource_request_context_id,resource_chat_context_id)=0) or (target_kind<>''group_coordination_proposal'' and target_group_coordination_id is null and (%s)))',c.conname,old_expression);
  end loop;
end; $$;
create function private.group_coordination_case_provenance() returns trigger language plpgsql set search_path='' as $$
begin
  if new.target_group_coordination_id is distinct from old.target_group_coordination_id then raise sqlstate '55000' using message='Coordination report provenance is immutable.'; end if;
  return new;
end; $$;
create trigger group_coordination_case_provenance before update on private.moderation_cases for each row execute function private.group_coordination_case_provenance();
do $$ declare definition text:=pg_get_functiondef('public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION public.submit_moderation_report(','FUNCTION private.group_coordination_submit_previous_report('); end; $$;
create or replace function public.submit_moderation_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,p_category text,p_explanation text,
  p_target_kind text,p_target_id uuid,p_context_kind text default null,p_context_id uuid default null)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid; explanation text; existing record; r private.group_coordination_proposals;
  subject uuid; c private.moderation_cases; report private.moderation_reports;
begin
  if p_target_kind is distinct from 'group_coordination_proposal' then
    if exists(select 1 from private.moderation_reports mr join private.moderation_cases mc on mc.id=mr.case_id
      where mr.reporter_profile_id=auth.uid() and mr.client_submission_id=p_client_submission_id and mc.target_kind='group_coordination_proposal') then
      perform private.require_group_identity(p_expected_reporter_profile_id);
      raise sqlstate 'PT409' using message='This report action has different submitted intent.';
    end if;
    return query select * from private.group_coordination_submit_previous_report(p_expected_reporter_profile_id,p_client_submission_id,p_category,p_explanation,p_target_kind,p_target_id,p_context_kind,p_context_id); return;
  end if;
  actor:=private.require_group_identity(p_expected_reporter_profile_id);
  explanation:=regexp_replace(coalesce(p_explanation,''),'^[[:space:]]+|[[:space:]]+$','','g');
  if p_client_submission_id is null or p_target_id is null or p_context_kind is not null or p_context_id is not null
    or p_category is null or p_category not in ('safety_concern','harassment_abuse','fraud_scam','inappropriate_content_conduct','spam','other')
    or char_length(explanation) not between 10 and 4000 then raise sqlstate '22023' using message='Invalid coordination report.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
  select mr.*,mc.state,mc.target_kind,mc.target_group_coordination_id target into existing from private.moderation_reports mr join private.moderation_cases mc on mc.id=mr.case_id
    where mr.reporter_profile_id=actor and mr.client_submission_id=p_client_submission_id;
  if found then
    if existing.target_kind<>p_target_kind or existing.target is distinct from p_target_id or existing.category<>p_category or existing.explanation<>explanation then
      raise sqlstate 'PT409' using message='This report action has different submitted intent.'; end if;
    return query select existing.id,existing.case_id,existing.state,existing.created_at; return;
  end if;
  select * into r from private.group_coordination_proposals where id=p_target_id;
  if r.id is null or actor=r.initiator_id or not exists(select 1 from private.group_coordination_seen s where s.proposal_id=r.id and s.profile_id=actor) then
    raise sqlstate '42501' using message='The report target is unavailable.'; end if;
  subject:=r.initiator_id;
  if not exists(select 1 from public.profiles where id=subject) then subject:=null; end if;
  insert into private.moderation_cases(subject_profile_id,target_kind,target_group_coordination_id) values(subject,p_target_kind,r.id) returning * into c;
  insert into private.moderation_reports(case_id,reporter_profile_id,client_submission_id,category,explanation,created_at)
    values(c.id,actor,p_client_submission_id,p_category,explanation,c.created_at) returning * into report;
  insert into private.moderation_case_events(case_id,actor_profile_id,event_kind,to_state,state_version,created_at) values(c.id,actor,'report_received','received',0,c.created_at);
  insert into private.audit_events(action,actor_user_id,target_type,target_id,metadata)
    values('moderation.report_submitted',actor,'moderation_case',c.id,jsonb_build_object('case_id',c.id,'report_id',report.id,'target_kind',c.target_kind));
  return query select report.id,c.id,c.state,c.created_at;
end; $$;
do $$ declare definition text:=pg_get_functiondef('private.moderation_target_summary(private.moderation_cases)'::regprocedure);
begin execute replace(definition,'FUNCTION private.moderation_target_summary(','FUNCTION private.group_coordination_previous_target_summary('); end; $$;
create or replace function private.moderation_target_summary(p_case private.moderation_cases) returns text language sql stable security definer set search_path='' as $$
  select case when p_case.target_kind='group_coordination_proposal' then 'Group coordination invitation' else private.group_coordination_previous_target_summary(p_case) end;
$$;
-- Reuse the existing narrow staff evidence shape; source_room_id is deliberately
-- absent, and this exact case never opens a participant conversation history.
do $$ declare definition text:=pg_get_functiondef('public.get_moderation_case_group_contact(uuid,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION public.get_moderation_case_group_contact(','FUNCTION private.group_coordination_previous_case_evidence('); end; $$;
create or replace function public.get_moderation_case_group_contact(p_expected_staff_profile_id uuid,p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c private.moderation_cases; result jsonb;
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select * into c from private.moderation_cases where id=p_case_id;
  if c.target_kind='group_coordination_proposal' then
    select jsonb_build_object('kind',c.target_kind,'target_id',r.id,'human_id',r.initiator_id,
      'source_group_id',(select s.group_id from private.group_coordination_seats s where s.proposal_id=r.id and s.profile_id=r.initiator_id and s.source_admission_id is not null),
      'target_group_id',null,'purpose',null,'title',r.title,'body',r.note,'created_at',r.created_at) into result from private.group_coordination_proposals r where r.id=c.target_group_coordination_id;
    if result is null then raise sqlstate '42501' using message='The contact case evidence is unavailable.'; end if;
    return result;
  end if;
  return private.group_coordination_previous_case_evidence(p_expected_staff_profile_id,p_case_id);
end; $$;
do $$ declare definition text; predicate text:='where report.reporter_profile_id = reporter_id';
begin
  definition:=pg_get_functiondef('public.list_own_moderation_reports_v2(uuid,integer,timestamptz,uuid)'::regprocedure);
  if strpos(definition,predicate)=0 then raise exception 'Review the effective report-history predicate.'; end if;
  execute replace(definition,'FUNCTION public.list_own_moderation_reports_v2(','FUNCTION public.list_own_moderation_reports_v3(');
  execute replace(definition,predicate,predicate||' and moderation_case.target_kind<>''group_coordination_proposal''');
  definition:=pg_get_functiondef('public.list_own_moderation_reports(uuid,integer,timestamptz,uuid)'::regprocedure);
  execute replace(definition,predicate,predicate||' and moderation_case.target_kind<>''group_coordination_proposal''');
end; $$;

-- All pending named participants must clear staged audience/confirm controls
-- when an identity changes. The D02 trigger already invalidates their own form.
create function private.group_coordination_identity_access() returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid; subject uuid:=coalesce(new.id,old.id);
begin
  for recipient in select distinct b.profile_id from private.group_coordination_seats a join private.group_coordination_seats b on b.proposal_id=a.proposal_id
    where a.profile_id=subject and a.is_current and b.is_current and b.profile_id is not null order by b.profile_id
  loop perform private.group_contact_access_signal(recipient); end loop;
  return coalesce(new,old);
end; $$;
create trigger group_coordination_profile_update_access after update of display_name on public.profiles for each row when(old.display_name is distinct from new.display_name) execute function private.group_coordination_identity_access();
create trigger group_coordination_profile_delete_access after delete on public.profiles for each row execute function private.group_coordination_identity_access();
-- Auth DELETE uses D02's sole reviewed Auth trigger; replace its function body
-- to call this supplemental invalidation, preserving the no-creation invariant.
do $$ declare definition text:=pg_get_functiondef('private.group_contact_identity_access()'::regprocedure);
begin execute replace(definition,'perform private.group_contact_access_signal(subject);','perform private.group_contact_access_signal(subject); perform private.group_coordination_invalidate_identity(subject);'); end; $$;
create function private.group_coordination_invalidate_identity(p_subject uuid) returns void language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  for recipient in select distinct b.profile_id from private.group_coordination_seats a join private.group_coordination_seats b on b.proposal_id=a.proposal_id
    where a.profile_id=p_subject and a.is_current and b.is_current and b.profile_id is not null order by b.profile_id
  loop perform private.group_contact_access_signal(recipient); end loop;
end; $$;
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'group_coordination_%') or (n.nspname='public' and p.proname in ('list_own_structured_request_message_items_v3','get_own_structured_request_message_item_v3','list_own_moderation_reports_v3'))
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
