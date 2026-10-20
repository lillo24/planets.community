-- C01 adds a genuine typed case to the existing moderation queue. Report
-- evidence is separate from room membership; staff cannot browse rooms.
alter table private.moderation_cases
  add column target_group_discussion_message_id uuid references private.group_discussion_messages(id) on delete restrict,
  add column group_discussion_evidence jsonb,
  add constraint moderation_cases_discussion_shape check (
    (target_kind='group_discussion_message')=(target_group_discussion_message_id is not null)
    and (target_group_discussion_message_id is null)=(group_discussion_evidence is null));
create index moderation_cases_discussion_message_idx on private.moderation_cases(target_group_discussion_message_id)
where target_group_discussion_message_id is not null;
-- Preserve all predecessor target branches and their exact constraints.
do $$ declare name text; expression text; begin
  foreach name in array array['moderation_cases_target_kind_valid','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid','moderation_cases_one_typed_target'] loop
    select pg_get_expr(conbin,conrelid) into expression from pg_constraint
      where conrelid='private.moderation_cases'::regclass and conname=name;
    if expression is null then raise exception 'The predecessor moderation constraint is missing: %',name; end if;
    if name='moderation_cases_one_typed_target' then
      expression:=replace(expression,'num_nonnulls(', 'num_nonnulls(target_group_discussion_message_id,');
    elsif name='moderation_cases_context_shape_valid' then
      expression:='('||expression||') or (target_kind=''group_discussion_message'' and num_nonnulls(project_context_id,resource_listing_context_id,resource_request_context_id,resource_chat_context_id)=0)';
    else expression:='('||expression||') or target_kind=''group_discussion_message'''; end if;
    execute format('alter table private.moderation_cases drop constraint %I, add constraint %I check (%s)',name,name,expression);
  end loop;
end; $$;
create function private.protect_group_discussion_report_identity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.target_group_discussion_message_id is distinct from old.target_group_discussion_message_id
    or new.group_discussion_evidence is distinct from old.group_discussion_evidence then
    raise sqlstate '55000' using message='Moderation evidence is immutable.'; end if;
  return new;
end; $$;
create trigger moderation_cases_discussion_identity before update on private.moderation_cases
for each row execute function private.protect_group_discussion_report_identity();

create function public.submit_group_discussion_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,p_message_id uuid,p_category text,p_explanation text)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_moderation_identity(p_expected_reporter_profile_id,true);
  explanation text:=regexp_replace(coalesce(p_explanation,''),'^[[:space:]]+|[[:space:]]+$','','g');
  message private.group_discussion_messages%rowtype; room private.group_discussions%rowtype;
  admission private.group_discussion_admissions%rowtype; prior record; new_case private.moderation_cases%rowtype; new_report private.moderation_reports%rowtype;
begin
  if p_client_submission_id is null or p_message_id is null or p_category is null
    or p_category not in ('safety_concern','harassment_abuse','fraud_scam','inappropriate_content_conduct','spam','other')
    or char_length(explanation) not between 10 and 4000 then raise sqlstate '22023' using message='The report request is invalid.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
  select r.id,r.case_id,c.state,r.created_at,r.category,r.explanation,c.target_group_discussion_message_id
    into prior from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id
    where r.reporter_profile_id=actor and r.client_submission_id=p_client_submission_id;
  if found then
    if prior.target_group_discussion_message_id is distinct from p_message_id or prior.category<>p_category or prior.explanation<>explanation then
      raise sqlstate '22023' using message='The report identity was reused.'; end if;
    return query select prior.id,prior.case_id,prior.state,prior.created_at; return;
  end if;
  select * into message from private.group_discussion_messages where id=p_message_id;
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=message.room_id) for update;
  select * into room from private.group_discussions where id=message.room_id for update;
  select * into admission from private.group_discussion_admissions where id=private.require_group_discussion(message.room_id,actor);
  if message.sequence<=admission.frontier or not exists(select 1 from public.profiles where id=message.sender_id) then
    raise sqlstate '42501' using message='The report target is unavailable.'; end if;
  if message.sender_id=actor then raise sqlstate '22023' using message='A profile cannot report itself.'; end if;
  insert into private.moderation_cases(subject_profile_id,target_kind,target_group_discussion_message_id,group_discussion_evidence)
    values(message.sender_id,'group_discussion_message',message.id,jsonb_build_object('message_id',message.id,'room_id',room.id,
      'group_id',room.group_id,'title',room.title,'body',message.body,'sender_id',message.sender_id,'created_at',message.created_at)) returning * into new_case;
  insert into private.moderation_reports(case_id,reporter_profile_id,client_submission_id,category,explanation,created_at)
    values(new_case.id,actor,p_client_submission_id,p_category,explanation,new_case.created_at) returning * into new_report;
  insert into private.moderation_case_events(case_id,actor_profile_id,event_kind,to_state,state_version,created_at)
    values(new_case.id,actor,'report_received','received',0,new_case.created_at);
  insert into private.audit_events(action,actor_user_id,target_type,target_id,metadata)
    values('moderation.report_submitted',actor,'moderation_case',new_case.id,jsonb_build_object('case_id',new_case.id,'report_id',new_report.id,'target_kind','group_discussion_message'));
  return query select new_report.id,new_case.id,new_case.state,new_report.created_at;
end; $$;

-- Released submit signatures/other target behavior stay intact. One namespace
-- must reject using a C key for a legacy report instead of returning its case.
do $$ declare definition text:=pg_get_functiondef('public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure); begin
  if strpos(definition,'FUNCTION public.submit_moderation_report(')=0 then raise exception 'The predecessor report function is missing.'; end if;
  execute replace(definition,'FUNCTION public.submit_moderation_report(','FUNCTION private.submit_pre_discussion_report(');
end; $$;
create or replace function public.submit_moderation_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,p_category text,p_explanation text,p_target_kind text,p_target_id uuid,p_context_kind text default null,p_context_id uuid default null)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_moderation_identity(p_expected_reporter_profile_id,true);
begin
  perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
  if exists(select 1 from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id
    where r.reporter_profile_id=actor and r.client_submission_id=p_client_submission_id and c.target_kind='group_discussion_message') then
    raise sqlstate '22023' using message='The report identity was reused.'; end if;
  return query select * from private.submit_pre_discussion_report(p_expected_reporter_profile_id,p_client_submission_id,p_category,p_explanation,p_target_kind,p_target_id,p_context_kind,p_context_id);
end; $$;
create function public.get_moderation_case_group_discussion(p_expected_staff_profile_id uuid,p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare evidence jsonb;
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select group_discussion_evidence into evidence from private.moderation_cases where id=p_case_id and target_kind='group_discussion_message';
  if evidence is null then raise sqlstate '42501' using message='The report evidence is unavailable.'; end if;
  return evidence;
end; $$;
revoke all on function private.submit_pre_discussion_report(uuid,uuid,text,text,text,uuid,text,uuid),private.protect_group_discussion_report_identity() from public,anon,authenticated,service_role;
revoke all on function public.submit_group_discussion_report(uuid,uuid,uuid,text,text),public.get_moderation_case_group_discussion(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.submit_group_discussion_report(uuid,uuid,uuid,text,text),public.get_moderation_case_group_discussion(uuid,uuid) to authenticated;
comment on function public.get_moderation_case_group_discussion(uuid,uuid) is 'Staff-authorized immutable exact report evidence only; never a room/history browsing capability.';
