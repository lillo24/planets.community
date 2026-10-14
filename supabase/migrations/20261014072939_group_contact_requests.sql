-- D01a: PROVISIONAL REVIEW ONLY; see docs/development/group-contact-contract.md.
-- No direct Data API grants, inherited group membership, or account-deletion FKs.
create table private.group_contact_requests (
  id uuid primary key default gen_random_uuid(),
  source_group_id uuid not null references private.community_groups(id) on delete restrict,
  target_group_id uuid not null references private.community_groups(id) on delete restrict,
  submitter_id uuid not null,
  source_delegate_id uuid references private.group_delegates(id) on delete restrict,
  purpose text not null check (purpose in ('idea','collaboration')),
  title text not null check (char_length(title) between 1 and 120),
  note text not null check (char_length(note) between 1 and 1000),
  public_project_id uuid references public.projects(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','accepted','declined','withdrawn')),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default (clock_timestamp()+interval '7 days'),
  resolved_at timestamptz,
  resolved_by uuid,
  check (source_group_id<>target_group_id),
  check ((status='pending')=(resolved_at is null)),
  check ((resolved_at is null)=(resolved_by is null)),
  check (expires_at>created_at)
);
create index group_contact_request_source_page on private.group_contact_requests(source_group_id,created_at desc,id desc);
create index group_contact_request_target_page on private.group_contact_requests(target_group_id,created_at desc,id desc);
create index group_contact_request_actor_page on private.group_contact_requests(submitter_id,created_at desc,id desc);
create index group_contact_request_delegate_idx on private.group_contact_requests(source_delegate_id);
create index group_contact_request_project_idx on private.group_contact_requests(public_project_id);
create index group_contact_request_pair on private.group_contact_requests(least(source_group_id,target_group_id),greatest(source_group_id,target_group_id),created_at desc);
create table private.group_contact_receipts (
  actor_id uuid not null,
  action_id uuid not null,
  intent_hash text not null,
  result jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,action_id)
);
create trigger group_contact_receipts_append_only before update or delete on private.group_contact_receipts
  for each row execute function private.protect_moderation_append_only();
create trigger group_contact_request_provenance before update on private.group_contact_requests
  for each row execute function private.protect_group_relationship_provenance('status','resolved_at','resolved_by','public_project_id');
alter table private.group_contact_requests enable row level security;
alter table private.group_contact_receipts enable row level security;
revoke all on private.group_contact_requests,private.group_contact_receipts from public,anon,authenticated,service_role;

create function private.group_contact_limits() returns jsonb
language sql immutable set search_path='' as $$
  select '{"title":120,"note":1000,"message":4000,"page":50,"expiry_days":7,"decline_cooldown_days":7,"actor_daily":10,"source_daily":25,"messages_per_minute":30,"coordination_groups":5,"coordination_pending":3,"coordination_daily":10}'::jsonb;
$$;
comment on function private.group_contact_limits() is
  'Provisional finite D bounds; activation requires approval of group-contact-contract.md. Character lengths use PostgreSQL Unicode characters.';

create function private.group_contact_representation_valid(p_group uuid,p_actor uuid,p_delegate uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(private.group_authority_role(p_group,p_actor) is not null and
    case when p_delegate is null then exists(select 1 from private.community_group_managers m where m.group_id=p_group and m.profile_id=p_actor)
    else exists(select 1 from private.group_delegates d where d.id=p_delegate and d.group_id=p_group and d.profile_id=p_actor and d.revoked_at is null) end,false);
$$;
create function private.group_contact_delegate(p_group uuid,p_actor uuid) returns uuid
language sql stable security definer set search_path='' as $$
  select d.id from private.group_delegates d where d.group_id=p_group and d.profile_id=p_actor and d.revoked_at is null
    and not exists(select 1 from private.community_group_managers m where m.group_id=p_group and m.profile_id=p_actor);
$$;

-- Actor/action (caller) -> sorted pair locks -> sorted groups -> identities.
-- Snapshot the target triage audience BEFORE group locks, and recheck after waits.
create function private.group_contact_lock(p_groups uuid[],p_people uuid[],p_triage_group uuid default null,p_submitter uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare before_ids uuid[]; after_ids uuid[]; pair record;
begin
  select coalesce(array_agg(profile_id order by profile_id),'{}') into before_ids
    from private.current_group_manager_profile_ids(p_triage_group);
  for pair in
    select distinct least(a,b) lo,greatest(a,b) hi from unnest(p_people) a cross join unnest(p_people) b where a<>b
    union select least(p_submitter,m),greatest(p_submitter,m) from unnest(before_ids) m where p_submitter<>m
    order by lo,hi
  loop perform private.lock_user_interaction_pair(pair.lo,pair.hi); end loop;
  perform 1 from private.community_groups g where g.id=any(p_groups) order by g.id for update;
  -- Account and profile erasure/incompleteness serialize with each decision.
  perform 1 from auth.users a where a.id=any(p_people) or a.id in
    (select m.profile_id from private.community_group_managers m where m.group_id=any(p_groups)) order by a.id for share;
  perform 1 from public.profiles p where p.id=any(p_people) or p.id in
    (select m.profile_id from private.community_group_managers m where m.group_id=any(p_groups)) order by p.id for share;
  select coalesce(array_agg(profile_id order by profile_id),'{}') into after_ids from private.current_group_manager_profile_ids(p_triage_group);
  if before_ids<>after_ids then raise sqlstate 'PT409' using message='This interaction is unavailable. Refresh and retry.'; end if;
end;
$$;
create function private.group_contact_triage_available(p_request private.group_contact_requests) returns boolean
language sql stable security definer set search_path='' as $$
  select private.group_contact_representation_valid(p_request.source_group_id,p_request.submitter_id,p_request.source_delegate_id)
    and private.group_is_public(p_request.source_group_id) and private.group_is_public(p_request.target_group_id)
    and not exists(select 1 from private.current_group_manager_profile_ids(p_request.target_group_id) m
      where m.profile_id=p_request.submitter_id or private.has_active_user_block_between(p_request.submitter_id,m.profile_id));
$$;
create function private.group_contact_request_visible(p_request private.group_contact_requests,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select p_request.submitter_id=p_actor or
    (private.group_authority_role(p_request.target_group_id,p_actor) is not null
      and private.group_is_public(p_request.target_group_id)
      and (p_request.status<>'pending' or p_request.expires_at<=clock_timestamp() or private.group_contact_triage_available(p_request)));
$$;
create function private.group_contact_request_projection(p_request private.group_contact_requests,p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare own_live boolean := p_actor=p_request.submitter_id and private.group_contact_representation_valid(p_request.source_group_id,p_actor,p_request.source_delegate_id);
  triage boolean := p_request.status='pending' and p_request.expires_at>clock_timestamp() and private.group_contact_triage_available(p_request)
    and private.group_authority_role(p_request.target_group_id,p_actor) is not null;
  content boolean := own_live or triage;
begin
  if not private.group_contact_request_visible(p_request,p_actor) then raise sqlstate '42501' using message='The contact request is unavailable.'; end if;
  return jsonb_build_object('item_kind','group_contact_request','request_id',p_request.id,
    'viewer_role',case when p_actor=p_request.submitter_id then 'requester' else 'delegate' end,
    'status',case when p_request.status='pending' and p_request.expires_at<=clock_timestamp() then 'expired' else p_request.status end,
    'created_at',p_request.created_at,'resolved_at',p_request.resolved_at,'expires_at',p_request.expires_at,
    'activity_at',coalesce(p_request.resolved_at,p_request.created_at),'purpose',case when content or p_actor<>p_request.submitter_id then p_request.purpose end,
    'title',case when content or p_actor<>p_request.submitter_id then p_request.title end,
    'request_message',case when content then p_request.note end,
    'source_group_id',case when content then p_request.source_group_id end,'target_group_id',case when content then p_request.target_group_id end,
    'source_group_name',case when content then (select name from private.community_groups where id=p_request.source_group_id) end,
    'target_group_name',case when content then (select name from private.community_groups where id=p_request.target_group_id) end,
    'requester_profile_id',case when content then p_request.submitter_id end,
    'requester_display_name',case when content then (select display_name from public.profiles where id=p_request.submitter_id) end,
    'public_project_id',case when content and private.is_project_publicly_viewable(p_request.public_project_id) then p_request.public_project_id end,
    'can_review',triage and p_actor<>p_request.submitter_id,'can_withdraw',p_actor=p_request.submitter_id and p_request.status='pending');
end;
$$;

create function public.list_my_contact_groups(p_expected_profile_id uuid,p_limit integer default 20,p_cursor_created_at timestamptz default null,p_cursor_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_cursor_created_at,p_cursor_id);
  return (select coalesce(jsonb_agg(to_jsonb(g) order by g.created_at desc,g.id desc),'[]') from
    (select g.id,g.name,g.created_at,private.group_authority_role(g.id,actor) authority_role
      from private.community_groups g where private.group_is_public(g.id) and private.group_authority_role(g.id,actor) is not null
      and (p_cursor_id is null or (g.created_at,g.id)<(p_cursor_created_at,p_cursor_id)) order by g.created_at desc,g.id desc limit p_limit) g);
end;
$$;
create function public.get_own_group_contact_request(p_expected_profile_id uuid,p_request_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); request private.group_contact_requests;
begin
  select * into request from private.group_contact_requests where id=p_request_id;
  if request.id is null then raise sqlstate '42501' using message='The contact request is unavailable.'; end if;
  return private.group_contact_request_projection(request,actor);
end;
$$;
create function public.list_own_group_contact_requests(p_expected_profile_id uuid,p_limit integer default 20,p_cursor_activity_at timestamptz default null,p_cursor_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_cursor_activity_at,p_cursor_id);
  return (select coalesce(jsonb_agg(private.group_contact_request_projection(r,actor) order by coalesce(r.resolved_at,r.created_at) desc,r.id desc),'[]') from
    (select r.* from private.group_contact_requests r where private.group_contact_request_visible(r,actor)
      and (p_cursor_id is null or (coalesce(r.resolved_at,r.created_at),r.id)<(p_cursor_activity_at,p_cursor_id))
      order by coalesce(r.resolved_at,r.created_at) desc,r.id desc limit p_limit) r);
end;
$$;
create function private.group_contact_command(p_expected uuid,p_action uuid,p_operation text,p_target uuid,p_intent jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected); hash text; receipt private.group_contact_receipts;
  request private.group_contact_requests; source uuid; target uuid; title text; note text; reference uuid; result jsonb; now_at timestamptz;
begin
  if p_action is null or p_target is null or p_operation not in ('submit','decline','withdraw') then
    raise sqlstate '22023' using message='Invalid contact action.';
  end if;
  hash:=private.group_command_hash(jsonb_build_object('operation',p_operation,'target',p_target,'intent',p_intent));
  perform pg_advisory_xact_lock(hashtextextended('group.contact.action:'||actor::text||':'||p_action::text,0));
  select * into receipt from private.group_contact_receipts where actor_id=actor and action_id=p_action;
  if found then
    if receipt.intent_hash<>hash then raise sqlstate 'PT409' using message='This action has different submitted intent.'; end if;
    return receipt.result||jsonb_build_object('replayed',true);
  end if;
  if p_operation='submit' then
    perform pg_advisory_xact_lock(hashtextextended('group.contact.quota:'||actor::text,0));
    source:=(p_intent->>'source_group_id')::uuid; target:=p_target;
    title:=regexp_replace(coalesce(p_intent->>'title',''),'^[[:space:]]+|[[:space:]]+$','','g');
    note:=regexp_replace(coalesce(p_intent->>'note',''),'^[[:space:]]+|[[:space:]]+$','','g');
    reference:=(p_intent->>'public_project_id')::uuid;
    if source is null or source=target or p_intent->>'purpose' not in ('idea','collaboration') or p_intent->>'purpose' is null
      or char_length(title) not between 1 and (private.group_contact_limits()->>'title')::integer
      or char_length(note) not between 1 and (private.group_contact_limits()->>'note')::integer then
      raise sqlstate '22023' using message='Invalid contact purpose or content.';
    end if;
    perform private.group_contact_lock(array[source,target],array[actor],target,actor);
    perform private.require_group_actor(actor);
    if not private.group_is_public(source) or not private.group_is_public(target) or private.group_authority_role(source,actor) is null
      or private.group_authority_role(target,actor) is not null then raise sqlstate '42501' using message='This contact context is unavailable.'; end if;
    request.source_group_id:=source; request.target_group_id:=target; request.submitter_id:=actor; request.source_delegate_id:=private.group_contact_delegate(source,actor);
    if not private.group_contact_triage_available(request) then raise sqlstate 'PT409' using message='This interaction is unavailable.'; end if;
    if reference is not null and not private.is_project_publicly_viewable(reference) then raise sqlstate '42501' using message='The public reference is unavailable.'; end if;
    now_at:=clock_timestamp();
    if exists(select 1 from private.group_contact_requests r where least(r.source_group_id,r.target_group_id)=least(source,target)
      and greatest(r.source_group_id,r.target_group_id)=greatest(source,target) and
      ((r.status='pending' and r.expires_at>now_at) or (r.status='declined' and r.resolved_at>now_at-make_interval(days=>(private.group_contact_limits()->>'decline_cooldown_days')::integer)))) then
      raise sqlstate 'PT409' using message='A contact attempt is pending or cooling down.';
    end if;
    if (select count(*) from private.group_contact_requests where submitter_id=actor and created_at>now_at-interval '24 hours')>=(private.group_contact_limits()->>'actor_daily')::integer
      or (select count(*) from private.group_contact_requests where source_group_id=source and created_at>now_at-interval '24 hours')>=(private.group_contact_limits()->>'source_daily')::integer then
      raise sqlstate 'PT429' using message='The contact request limit has been reached. Try later.';
    end if;
    insert into private.group_contact_requests(source_group_id,target_group_id,submitter_id,source_delegate_id,purpose,title,note,public_project_id)
      values(source,target,actor,request.source_delegate_id,p_intent->>'purpose',title,note,reference) returning * into request;
  else
    select * into request from private.group_contact_requests where id=p_target;
    if request.id is null then raise sqlstate '42501' using message='The contact request is unavailable.'; end if;
    -- Own withdrawal is a safety exit: no public eligibility, profile completion or block prerequisite.
    if p_operation='withdraw' then
      perform 1 from private.community_groups g where g.id in(request.source_group_id,request.target_group_id) order by g.id for update;
    else
      perform private.group_contact_lock(array[request.source_group_id,request.target_group_id],array[actor,request.submitter_id],request.target_group_id,request.submitter_id);
    end if;
    perform private.require_group_identity(actor);
    select * into request from private.group_contact_requests where id=p_target for update;
    if (p_operation='withdraw' and actor<>request.submitter_id) or
      (p_operation='decline' and (actor=request.submitter_id or private.group_authority_role(request.target_group_id,actor) is null)) then
      raise sqlstate '42501' using message='The contact request is unavailable.';
    end if;
    if request.status<>'pending' or (p_operation='decline' and (request.expires_at<=clock_timestamp() or not private.group_contact_triage_available(request))) then
      raise sqlstate 'PT409' using message='This contact request is no longer available for that action.';
    end if;
    update private.group_contact_requests set status=case when p_operation='withdraw' then 'withdrawn' else 'declined' end,
      resolved_at=clock_timestamp(),resolved_by=actor where id=request.id returning * into request;
  end if;
  result:=jsonb_build_object('request_id',request.id,'outcome',request.status,'replayed',false);
  insert into private.group_contact_receipts values(actor,p_action,hash,result,clock_timestamp());
  perform private.audit_group_relationship('group.contact_'||p_operation,actor,request.source_group_id,request.id);
  return result;
end;
$$;
create function public.submit_group_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_source_group_id uuid,p_target_group_id uuid,p_purpose text,p_title text,p_note text,p_public_project_id uuid default null) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_contact_command(p_expected_profile_id,p_action_id,'submit',p_target_group_id,
    jsonb_build_object('source_group_id',p_source_group_id,'purpose',p_purpose,'title',p_title,'note',p_note,'public_project_id',p_public_project_id));
$$;
create function public.decline_group_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.group_contact_command(p_expected_profile_id,p_action_id,'decline',p_request_id,'{}'); $$;
create function public.withdraw_group_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.group_contact_command(p_expected_profile_id,p_action_id,'withdraw',p_request_id,'{}'); $$;
create function public.recover_group_contact_action(p_expected_profile_id uuid,p_action_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin return (select result||jsonb_build_object('replayed',true) from private.group_contact_receipts where actor_id=actor and action_id=p_action_id); end;
$$;

do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'group_contact_%') or
      (n.nspname='public' and p.proname=any(array['list_my_contact_groups','get_own_group_contact_request','list_own_group_contact_requests','submit_group_contact_request','decline_group_contact_request','withdraw_group_contact_request','recover_group_contact_action']))
  loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
