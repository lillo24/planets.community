-- D01c safety: typed immutable target/context plus case-scoped staff evidence.
-- This is manual review; no sanction, notification, group retaliation or ordinary
-- staff conversation access. Account retention/anonymization remains Plan 10.
alter table private.moderation_cases
  add column target_group_contact_request_id uuid references private.group_contact_requests(id) on delete restrict,
  add column target_group_contact_message_id uuid references private.group_contact_messages(id) on delete restrict,
  add column group_contact_context_id uuid references private.group_contact_conversations(id) on delete restrict;
create index moderation_cases_contact_request_idx on private.moderation_cases(target_group_contact_request_id) where target_group_contact_request_id is not null;
create index moderation_cases_contact_message_idx on private.moderation_cases(target_group_contact_message_id) where target_group_contact_message_id is not null;
create index moderation_cases_contact_context_idx on private.moderation_cases(group_contact_context_id) where group_contact_context_id is not null;
-- Preserve effective legacy constraints verbatim; add one distinct typed branch.
do $$ declare c record; old_expression text; d_shape text:= $shape$
  num_nonnulls(target_group_id,target_proposal_template_id,target_profile_id,target_project_id,target_project_chat_message_id,
    target_resource_listing_id,target_resource_request_id,target_resource_chat_message_id)=0
  and num_nonnulls(project_context_id,resource_listing_context_id,resource_request_context_id,resource_chat_context_id)=0
  and case target_kind when 'group_contact_request' then target_group_contact_request_id is not null and target_group_contact_message_id is null and group_contact_context_id is null
    when 'group_contact_message' then target_group_contact_message_id is not null and target_group_contact_request_id is null and group_contact_context_id is not null else false end
  $shape$;
begin
  for c in select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='private.moderation_cases'::regclass
    and conname=any(array['moderation_cases_target_kind_valid','moderation_cases_one_typed_target','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid'])
  loop
    old_expression:=substring(c.definition from 8 for char_length(c.definition)-8);
    execute format('alter table private.moderation_cases drop constraint %I',c.conname);
    execute format('alter table private.moderation_cases add constraint %I check ((target_kind in (''group_contact_request'',''group_contact_message'') and (%s)) or (target_kind not in (''group_contact_request'',''group_contact_message'') and target_group_contact_request_id is null and target_group_contact_message_id is null and group_contact_context_id is null and (%s)))',c.conname,d_shape,old_expression);
  end loop;
end; $$;
create function private.group_contact_protect_case() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.target_group_contact_request_id is distinct from old.target_group_contact_request_id
    or new.target_group_contact_message_id is distinct from old.target_group_contact_message_id
    or new.group_contact_context_id is distinct from old.group_contact_context_id then
    raise sqlstate '55000' using message='Contact report provenance is immutable.'; end if;
  return new;
end; $$;
create trigger group_contact_case_provenance before update on private.moderation_cases for each row execute function private.group_contact_protect_case();
create table private.group_contact_seen_requests (
  profile_id uuid not null,
  request_id uuid not null references private.group_contact_requests(id) on delete restrict,
  first_seen_at timestamptz not null default clock_timestamp(),
  primary key(profile_id,request_id)
);
create index group_contact_seen_request_idx on private.group_contact_seen_requests(request_id);
alter table private.group_contact_seen_requests enable row level security;
revoke all on private.group_contact_seen_requests from public,anon,authenticated,service_role;
create or replace function public.get_own_group_contact_request(p_expected_profile_id uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); request private.group_contact_requests; result jsonb;
begin
  select * into request from private.group_contact_requests where id=p_request_id;
  if request.id is null then raise sqlstate '42501' using message='The contact request is unavailable.'; end if;
  result:=private.group_contact_request_projection(request,actor);
  if result->>'request_message' is not null and actor<>request.submitter_id then
    insert into private.group_contact_seen_requests(profile_id,request_id) values(actor,request.id) on conflict do nothing;
  end if;
  return result;
end; $$;
alter function public.get_own_structured_request_message_item_v2(uuid,text,uuid) volatile;

do $$ declare definition text:=pg_get_functiondef('public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION public.submit_moderation_report(','FUNCTION private.group_contact_submit_legacy_report('); end; $$;
create or replace function public.submit_moderation_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,p_category text,p_explanation text,
  p_target_kind text,p_target_id uuid,p_context_kind text default null,p_context_id uuid default null)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid; explanation text; existing record; r private.group_contact_requests; m private.group_contact_messages;
  subject uuid; c private.moderation_cases; report private.moderation_reports;
begin
  if p_target_kind not in ('group_contact_request','group_contact_message') or p_target_kind is null then
    if exists(select 1 from private.moderation_reports mr join private.moderation_cases mc on mc.id=mr.case_id
      where mr.reporter_profile_id=auth.uid() and mr.client_submission_id=p_client_submission_id and mc.target_kind in ('group_contact_request','group_contact_message')) then
      perform private.require_group_identity(p_expected_reporter_profile_id);
      raise sqlstate 'PT409' using message='This report action has different submitted intent.';
    end if;
    return query select * from private.group_contact_submit_legacy_report(p_expected_reporter_profile_id,p_client_submission_id,p_category,p_explanation,p_target_kind,p_target_id,p_context_kind,p_context_id);
    return;
  end if;
  actor:=private.require_group_identity(p_expected_reporter_profile_id);
  explanation:=regexp_replace(coalesce(p_explanation,''),'^[[:space:]]+|[[:space:]]+$','','g');
  if p_client_submission_id is null or p_target_id is null or p_context_kind is not null or p_context_id is not null
    or p_category is null or p_category not in ('safety_concern','harassment_abuse','fraud_scam','inappropriate_content_conduct','spam','other')
    or char_length(explanation) not between 10 and 4000 then raise sqlstate '22023' using message='Invalid contact report.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
  select mr.id,mr.case_id,mr.created_at,mr.category,mr.explanation,mc.state,mc.target_kind,
    coalesce(mc.target_group_contact_request_id,mc.target_group_contact_message_id) target into existing
    from private.moderation_reports mr join private.moderation_cases mc on mc.id=mr.case_id where mr.reporter_profile_id=actor and mr.client_submission_id=p_client_submission_id;
  if found then
    if existing.target_kind<>p_target_kind or existing.target<>p_target_id or existing.category<>p_category or existing.explanation<>explanation then
      raise sqlstate 'PT409' using message='This report action has different submitted intent.'; end if;
    return query select existing.id,existing.case_id,existing.state,existing.created_at; return;
  end if;
  if p_target_kind='group_contact_request' then
    select * into r from private.group_contact_requests where id=p_target_id;
    if r.id is null or actor=r.submitter_id or not (
      exists(select 1 from private.group_contact_seen_requests s where s.profile_id=actor and s.request_id=r.id)
      or (r.resolved_by=actor and r.status in ('accepted','declined'))
      or (r.status='pending' and r.expires_at>clock_timestamp() and private.group_contact_triage_available(r) and private.group_authority_role(r.target_group_id,actor) is not null)) then
      raise sqlstate '42501' using message='The report target is unavailable.'; end if;
    subject:=r.submitter_id;
  else
    select * into m from private.group_contact_messages where id=p_target_id;
    if m.id is null or m.sender_profile_id=actor or not exists(select 1 from private.group_contact_admissions a left join private.group_delegates d on d.id=a.delegate_id
      where a.profile_id=actor and a.conversation_id=m.conversation_id and a.admitted_at<=m.created_at
        and (a.left_at is null or m.created_at<=a.left_at) and (d.revoked_at is null or m.created_at<=d.revoked_at)) then
      raise sqlstate '42501' using message='The report target is unavailable.'; end if;
    subject:=m.sender_profile_id;
  end if;
  -- An already erased subject is neutral. Existing report/account retention FKs
  -- stay unchanged; Plan 10 owns their later deletion/anonymization operations.
  if not exists(select 1 from public.profiles where id=subject) then subject:=null; end if;
  insert into private.moderation_cases(subject_profile_id,target_kind,target_group_contact_request_id,target_group_contact_message_id,group_contact_context_id)
    values(subject,p_target_kind,r.id,m.id,m.conversation_id) returning * into c;
  insert into private.moderation_reports(case_id,reporter_profile_id,client_submission_id,category,explanation,created_at)
    values(c.id,actor,p_client_submission_id,p_category,explanation,c.created_at) returning * into report;
  insert into private.moderation_case_events(case_id,actor_profile_id,event_kind,to_state,state_version,created_at)
    values(c.id,actor,'report_received','received',0,c.created_at);
  insert into private.audit_events(action,actor_user_id,target_type,target_id,metadata)
    values('moderation.report_submitted',actor,'moderation_case',c.id,jsonb_build_object('case_id',c.id,'report_id',report.id,'target_kind',c.target_kind));
  return query select report.id,c.id,c.state,c.created_at;
end; $$;
do $$ declare definition text:=pg_get_functiondef('private.moderation_target_summary(private.moderation_cases)'::regprocedure);
begin execute replace(definition,'FUNCTION private.moderation_target_summary(','FUNCTION private.group_contact_legacy_target_summary('); end; $$;
create or replace function private.moderation_target_summary(p_case private.moderation_cases) returns text
language sql stable security definer set search_path='' as $$
  select case p_case.target_kind when 'group_contact_request' then 'Group contact request' when 'group_contact_message' then 'Representative conversation message'
    else private.group_contact_legacy_target_summary(p_case) end;
$$;
create function public.get_moderation_case_group_contact(p_expected_staff_profile_id uuid,p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c private.moderation_cases; result jsonb;
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select * into c from private.moderation_cases where id=p_case_id;
  if c.target_kind='group_contact_request' then
    select jsonb_build_object('kind',c.target_kind,'target_id',r.id,'human_id',r.submitter_id,'source_group_id',r.source_group_id,'target_group_id',r.target_group_id,
      'purpose',r.purpose,'title',r.title,'body',r.note,'created_at',r.created_at) into result from private.group_contact_requests r where r.id=c.target_group_contact_request_id;
  elsif c.target_kind='group_contact_message' then
    select jsonb_build_object('kind',c.target_kind,'target_id',m.id,'human_id',m.sender_profile_id,'source_group_id',m.represented_group_id,'target_group_id',null,
      'purpose',null,'title',null,'body',m.body,'created_at',m.created_at) into result from private.group_contact_messages m where m.id=c.target_group_contact_message_id;
  end if;
  if result is null then raise sqlstate '42501' using message='The contact case evidence is unavailable.'; end if;
  return result;
end; $$;

-- Blocking already takes the canonical sorted pair lock. Serialize D closure
-- after existing Project/Resource/group transitions; do not acquire new pairs.
do $$ declare definition text:=pg_get_functiondef('private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure);
  prefix text:='perform private.close_pending_project_resource_requests_for_user_block(p_blocker_profile_id,p_blocked_profile_id);';
begin
  if strpos(definition,prefix)=0 then raise exception 'The effective legacy group block hook changed; review lock ordering.'; end if;
  execute replace(replace(definition,prefix,''),'FUNCTION private.close_pending_direct_requests_for_user_block(','FUNCTION private.group_contact_legacy_block_convergence(');
end; $$;
create or replace function private.close_pending_direct_requests_for_user_block(p_blocker_profile_id uuid,p_blocked_profile_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare groups uuid[]; item record;
begin
  perform private.close_pending_project_resource_requests_for_user_block(p_blocker_profile_id,p_blocked_profile_id);
  -- Reserve the complete legacy + D group set in one global order before the
  -- old group hook acquires any row. Never append a lower source-group lock.
  select array_agg(distinct g order by g) into groups from (
    select r.group_id g from private.group_join_requests r where r.status='pending' and
      ((r.requester_id=p_blocker_profile_id and private.group_authority_role(r.group_id,p_blocked_profile_id) is not null)
        or (r.requester_id=p_blocked_profile_id and private.group_authority_role(r.group_id,p_blocker_profile_id) is not null))
    union all select g from private.group_contact_requests r cross join lateral unnest(array[r.source_group_id,r.target_group_id]) g
      where r.status='pending' and ((r.submitter_id=p_blocker_profile_id and private.group_authority_role(r.target_group_id,p_blocked_profile_id) is not null)
        or (r.submitter_id=p_blocked_profile_id and private.group_authority_role(r.target_group_id,p_blocker_profile_id) is not null))
  ) affected;
  perform 1 from private.community_groups g where g.id=any(groups) order by g.id for update;
  perform private.group_contact_legacy_block_convergence(p_blocker_profile_id,p_blocked_profile_id);
  for item in update private.group_contact_requests r set status=case when r.submitter_id=p_blocker_profile_id then 'withdrawn' else 'declined' end,
    resolved_at=clock_timestamp(),resolved_by=p_blocker_profile_id where r.status='pending'
    and ((r.submitter_id=p_blocker_profile_id and private.group_authority_role(r.target_group_id,p_blocked_profile_id) is not null)
      or (r.submitter_id=p_blocked_profile_id and private.group_authority_role(r.target_group_id,p_blocker_profile_id) is not null)) returning r.submitter_id
  loop perform private.group_contact_signal(item.submitter_id); end loop;
  -- Generic own-account invalidation reveals no direction or affected chat.
  perform private.group_contact_signal(p_blocker_profile_id); perform private.group_contact_signal(p_blocked_profile_id);
end; $$;
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname like 'group_contact_%'
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature); end loop;
end; $$;
revoke all on function public.get_moderation_case_group_contact(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_moderation_case_group_contact(uuid,uuid) to authenticated;

-- Old personal report-history parsers reject new target kinds. Preserve the old
-- allowlist BEFORE its keyset limit; v2 retains the complete new-client scope.
do $$ declare definition text:=pg_get_functiondef('public.list_own_moderation_reports(uuid,integer,timestamptz,uuid)'::regprocedure);
  predicate text:='where report.reporter_profile_id = reporter_id';
begin
  if strpos(definition,predicate)=0 then raise exception 'The effective personal report projection changed; review compatibility.'; end if;
  execute replace(definition,'FUNCTION public.list_own_moderation_reports(','FUNCTION public.list_own_moderation_reports_v2(');
  execute replace(definition,predicate,predicate||' and moderation_case.target_kind not in (''group_contact_request'',''group_contact_message'')');
end; $$;
revoke all on function public.list_own_moderation_reports_v2(uuid,integer,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_own_moderation_reports_v2(uuid,integer,timestamptz,uuid) to authenticated;
