-- C01: review-only until the C00 permissions/history contract is approved.
-- All durable operations serialize on Group -> room, matching GRP03A.
create table private.group_discussions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  creator_id uuid not null,
  title text not null check(title=btrim(title) and char_length(title) between 1 and 120),
  archived boolean not null default false,
  version bigint not null default 1 check(version>0),
  last_sequence bigint not null default 0 check(last_sequence>=0),
  read_secret uuid not null default gen_random_uuid(),
  created_at timestamptz not null default clock_timestamp()
);
create index group_discussions_page on private.group_discussions(group_id,created_at desc,id desc);
create table private.group_discussion_admissions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references private.group_discussions(id) on delete restrict,
  profile_id uuid not null,
  source_kind text not null check(source_kind in ('creator','delegate','membership')),
  source_id uuid not null,
  frontier bigint not null check(frontier>=0),
  read_sequence bigint not null check(read_sequence>=frontier),
  accepted_at timestamptz not null default clock_timestamp(),
  ended_at timestamptz,
  ended_by uuid,
  check((ended_at is null)=(ended_by is null))
);
create unique index group_discussion_current_admission on private.group_discussion_admissions(room_id,profile_id) where ended_at is null;
create index group_discussion_actor_admissions on private.group_discussion_admissions(profile_id,room_id) where ended_at is null;
create index group_discussion_source_admissions on private.group_discussion_admissions(source_kind,source_id) where ended_at is null;
create table private.group_discussion_invitations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references private.group_discussions(id) on delete restrict,
  inviter_id uuid not null,
  recipient_id uuid not null,
  inviter_admission_id uuid not null references private.group_discussion_admissions(id) on delete restrict,
  source_kind text not null check(source_kind in ('creator','delegate','membership')),
  source_id uuid not null,
  status text not null default 'pending' check(status in ('pending','accepted','declined','withdrawn','revoked')),
  created_at timestamptz not null default clock_timestamp()
);
create unique index group_discussion_pending_invitation on private.group_discussion_invitations(room_id,recipient_id) where status='pending';
create index group_discussion_invitation_actor_page on private.group_discussion_invitations(recipient_id,created_at desc,id desc);
create index group_discussion_source_invitations on private.group_discussion_invitations(source_kind,source_id) where status='pending';
create table private.group_discussion_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references private.group_discussions(id) on delete restrict,
  sequence bigint not null check(sequence>0),
  sender_id uuid not null,
  body text not null check(body=regexp_replace(body,'^[[:space:]]+|[[:space:]]+$','','g') and char_length(body) between 1 and 4000),
  created_at timestamptz not null default clock_timestamp(),
  unique(room_id,sequence)
);
create table private.group_discussion_receipts (
  actor_id uuid not null,
  request_id uuid not null,
  intent jsonb not null,
  result jsonb not null,
  primary key(actor_id,request_id)
);
create trigger group_discussion_messages_immutable before update or delete on private.group_discussion_messages
for each row execute function private.protect_moderation_append_only();
create trigger group_discussion_receipts_immutable before update or delete on private.group_discussion_receipts
for each row execute function private.protect_moderation_append_only();
create trigger group_discussion_admission_provenance before update on private.group_discussion_admissions
for each row execute function private.protect_group_relationship_provenance('read_sequence','ended_at','ended_by');
create trigger group_discussion_invitation_provenance before update on private.group_discussion_invitations
for each row execute function private.protect_group_relationship_provenance('status');
create trigger group_discussion_room_provenance before update on private.group_discussions
for each row execute function private.protect_group_relationship_provenance('title','archived','version','last_sequence');

-- Canonical source priority is participation, then authority, then Creator.
-- Raw actor/source UUIDs preserve provenance without blocking account erasure.
create function private.group_discussion_source(p_group uuid,p_actor uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('kind',kind,'id',id) from (
    select 'membership'::text kind,m.id,0 rank from private.group_memberships m
      where m.group_id=p_group and m.profile_id=p_actor and m.ended_at is null
    union all select 'delegate',d.id,1 from private.group_delegates d
      where d.group_id=p_group and d.profile_id=p_actor and d.revoked_at is null
      and private.group_authority_role(p_group,p_actor) is not null
    union all select 'creator',p_actor,2 where private.group_authority_role(p_group,p_actor)='creator'
  ) sources order by rank limit 1;
$$;
create function private.group_discussion_source_current(p_group uuid,p_actor uuid,p_kind text,p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor)
    and private.group_has_accountable_identity(p_group)
    and case p_kind
      when 'creator' then p_id=p_actor and private.group_authority_role(p_group,p_actor)='creator'
      when 'delegate' then exists(select 1 from private.group_delegates d where d.id=p_id
        and d.group_id=p_group and d.profile_id=p_actor and d.revoked_at is null)
        and private.group_authority_role(p_group,p_actor) is not null
      when 'membership' then exists(select 1 from private.group_memberships m where m.id=p_id
        and m.group_id=p_group and m.profile_id=p_actor and m.ended_at is null)
      else false end;
$$;
create function private.group_discussion_group_available(p_group uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.community_groups g where g.id=p_group
    and g.publication_state='published' and not g.directory_suppressed)
    and private.group_has_accountable_identity(p_group);
$$;
create function private.group_discussion_admission(p_room uuid,p_actor uuid) returns uuid
language sql stable security definer set search_path='' as $$
  select a.id from private.group_discussion_admissions a join private.group_discussions r on r.id=a.room_id
  where a.room_id=p_room and a.profile_id=p_actor and a.ended_at is null
    and private.group_discussion_group_available(r.group_id)
    and private.group_discussion_source_current(r.group_id,p_actor,a.source_kind,a.source_id);
$$;
create function private.require_group_discussion(p_room uuid,p_actor uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare admission uuid:=private.group_discussion_admission(p_room,p_actor);
begin
  if admission is null then raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  return admission;
end;
$$;
create function private.group_discussion_invitation_available(p_invitation uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.group_discussion_invitations i
    join private.group_discussions r on r.id=i.room_id where i.id=p_invitation and i.status='pending'
    and not r.archived and private.group_discussion_group_available(r.group_id)
    and private.group_discussion_source_current(r.group_id,i.recipient_id,i.source_kind,i.source_id)
    and private.group_discussion_admission(r.id,i.inviter_id)=i.inviter_admission_id
    and private.group_authority_role(r.group_id,i.inviter_id) is not null
    and not private.has_active_user_block_between(i.inviter_id,i.recipient_id));
$$;

create function private.group_discussion_signal(p_actor uuid) returns void
language sql security definer set search_path='' as $$
  select realtime.send(jsonb_build_object('profile_id',p_actor),'changed','group-discussions:profile:'||p_actor::text,true);
$$;
create function private.group_discussion_topic_allowed(p_topic text) returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and p_topic='group-discussions:profile:'||auth.uid()::text
    and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=auth.uid());
$$;
create policy group_discussion_private_hints on realtime.messages for select to authenticated
using(extension='broadcast' and private.group_discussion_topic_allowed(realtime.topic()));

create function private.end_group_discussion_source() returns trigger
language plpgsql security definer set search_path='' as $$
declare kind text:=case tg_table_name when 'group_memberships' then 'membership' else 'delegate' end; actor uuid;
begin
  for actor in update private.group_discussion_admissions set ended_at=clock_timestamp(),ended_by=coalesce(auth.uid(),new.profile_id)
    where source_kind=kind and source_id=new.id and ended_at is null returning profile_id
  loop perform private.group_discussion_signal(actor); end loop;
  for actor in update private.group_discussion_invitations set status='revoked' where source_kind=kind and source_id=new.id and status='pending' returning recipient_id
  loop perform private.group_discussion_signal(actor); end loop;
  return new;
end;
$$;
create trigger group_memberships_end_discussion_source after update of ended_at on private.group_memberships
for each row when(old.ended_at is null and new.ended_at is not null) execute function private.end_group_discussion_source();
create trigger group_delegates_end_discussion_source after update of revoked_at on private.group_delegates
for each row when(old.revoked_at is null and new.revoked_at is not null) execute function private.end_group_discussion_source();
create function private.invalidate_group_discussion_admission() returns trigger
language plpgsql security definer set search_path='' as $$
declare actor uuid;
begin
  for actor in update private.group_discussion_invitations set status='revoked'
    where inviter_admission_id=new.id and status='pending' returning recipient_id
  loop perform private.group_discussion_signal(actor); end loop;
  perform private.group_discussion_signal(new.profile_id);
  return new;
end; $$;
create trigger group_discussion_admissions_invalidate after update of ended_at on private.group_discussion_admissions
for each row when(old.ended_at is null and new.ended_at is not null) execute function private.invalidate_group_discussion_admission();
create function private.invalidate_group_discussion_group() returns trigger
language plpgsql security definer set search_path='' as $$
declare actor uuid;
begin
  for actor in select a.profile_id from private.group_discussion_admissions a join private.group_discussions r on r.id=a.room_id where r.group_id=new.id and a.ended_at is null
    union select i.recipient_id from private.group_discussion_invitations i join private.group_discussions r on r.id=i.room_id where r.group_id=new.id and i.status='pending'
  loop perform private.group_discussion_signal(actor); end loop;
  return new;
end; $$;
create trigger community_groups_discussion_invalidate after update of publication_state,directory_suppressed on private.community_groups
for each row when(old.publication_state is distinct from new.publication_state or old.directory_suppressed is distinct from new.directory_suppressed)
execute function private.invalidate_group_discussion_group();

create function private.group_discussion_command(p_actor uuid,p_key uuid,p_operation text,p_group uuid,p_room uuid,p_arguments jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_actor); intent jsonb; receipt private.group_discussion_receipts%rowtype;
  room private.group_discussions%rowtype; admission private.group_discussion_admissions%rowtype;
  invitation private.group_discussion_invitations%rowtype; source jsonb; result jsonb; target uuid; object_id uuid;
begin
  if p_key is null or p_arguments is null or p_operation is null then
    raise sqlstate '22023' using message='The discussion command is invalid.'; end if;
  if p_operation in ('create','update') and (p_arguments->>'title' is null or char_length(p_arguments->>'title') not between 1 and 120)
    or p_operation='send' and (p_arguments->>'body' is null or char_length(p_arguments->>'body') not between 1 and 4000) then
    raise sqlstate '22023' using message='The discussion content is invalid.'; end if;
  intent:=jsonb_build_object('operation',p_operation,'group',p_group,'room',p_room,'arguments',p_arguments);
  perform pg_advisory_xact_lock(hashtextextended('group-discussion:'||actor::text||':'||p_key::text,0));
  if p_room is not null then select group_id into p_group from private.group_discussions where id=p_room; end if;
  if p_group is null then raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  if p_operation='invite' then
    target:=(p_arguments->>'profile_id')::uuid;
    if target is null or target=actor then raise sqlstate '22023' using message='The invitation is invalid.'; end if;
    perform private.lock_user_interaction_pair(actor,target);
    perform 1 from private.community_groups where id=p_group for update;
    perform private.assert_user_interaction_available(actor,target);
  elsif p_operation='respond' then
    select * into invitation from private.group_discussion_invitations where id=(p_arguments->>'invitation_id')::uuid and room_id=p_room;
    if invitation.id is null or invitation.recipient_id<>actor then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
    -- The direct pair lock precedes Group/room and is shared with block_user.
    perform private.lock_user_interaction_pair(actor,invitation.inviter_id);
    perform 1 from private.community_groups where id=p_group for update;
  else perform 1 from private.community_groups where id=p_group for update;
  end if;
  if p_room is not null then select * into room from private.group_discussions where id=p_room for update; end if;
  select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_key;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The command identity was reused.'; end if;
    if p_operation not in ('leave','respond') then perform private.require_group_discussion((receipt.result->>'room_id')::uuid,actor); end if;
    return receipt.result;
  end if;
  if p_operation not in ('leave','respond') and not exists(select 1 from public.profiles where id=actor and display_name is not null) then
    raise sqlstate '55000' using message='A complete profile is required.'; end if;
  if p_operation='create' then
    if not private.group_discussion_group_available(p_group) or private.group_authority_role(p_group,actor) is null then
      raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
    source:=private.group_discussion_source(p_group,actor);
    insert into private.group_discussions(group_id,creator_id,title) values(p_group,actor,p_arguments->>'title') returning * into room;
    insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
      values(room.id,actor,source->>'kind',(source->>'id')::uuid,0,0) returning id into object_id;
  elsif p_operation='leave' then
    select * into admission from private.group_discussion_admissions where id=(p_arguments->>'admission_id')::uuid and room_id=p_room and profile_id=actor for update;
    if admission.id is null then raise sqlstate '42501' using message='The admission is unavailable.'; end if;
    update private.group_discussion_admissions set ended_at=coalesce(ended_at,clock_timestamp()),ended_by=coalesce(ended_by,actor) where id=admission.id;
    object_id:=admission.id;
  elsif p_operation='respond' then
    if p_arguments->>'response' is null or p_arguments->>'response' not in ('accepted','declined') then raise sqlstate '22023' using message='The invitation response is invalid.'; end if;
    select i.* into invitation from private.group_discussion_invitations i where i.id=invitation.id for update;
    if p_arguments->>'response'='accepted' then
      if not private.group_discussion_invitation_available(invitation.id) then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
      if private.group_discussion_admission(p_room,actor) is not null then raise sqlstate 'PT409' using message='The discussion membership changed.'; end if;
      insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
        values(p_room,actor,invitation.source_kind,invitation.source_id,room.last_sequence,room.last_sequence) returning id into object_id;
    else
      if invitation.status<>'pending' then raise sqlstate 'PT409' using message='The invitation changed.'; end if;
      object_id:=invitation.id;
    end if;
    update private.group_discussion_invitations set status=p_arguments->>'response' where id=invitation.id;
  else
    select * into admission from private.group_discussion_admissions where id=private.require_group_discussion(p_room,actor);
    if room.archived and p_operation<>'update' then raise sqlstate '55000' using message='The discussion is archived.'; end if;
    if p_operation in ('invite','withdraw','remove','update') and private.group_authority_role(p_group,actor) is null then
      raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
    case p_operation
      when 'send' then
        update private.group_discussions set last_sequence=last_sequence+1 where id=p_room returning * into room;
        insert into private.group_discussion_messages(room_id,sequence,sender_id,body) values(p_room,room.last_sequence,actor,p_arguments->>'body') returning id into object_id;
      when 'invite' then
        source:=private.group_discussion_source(p_group,target);
        if source is null or not private.group_discussion_source_current(p_group,target,source->>'kind',(source->>'id')::uuid) then
          raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
        if private.group_discussion_admission(p_room,target) is not null then raise sqlstate 'PT409' using message='The discussion membership changed.'; end if;
        -- Prior unavailable invites cannot prevent a deliberate current invitation.
        update private.group_discussion_invitations i set status='revoked' where i.room_id=p_room and i.recipient_id=target
          and i.status='pending' and not private.group_discussion_invitation_available(i.id);
        insert into private.group_discussion_invitations(room_id,inviter_id,recipient_id,inviter_admission_id,source_kind,source_id)
          values(p_room,actor,target,admission.id,source->>'kind',(source->>'id')::uuid) returning id into object_id;
        perform private.group_discussion_signal(target);
      when 'withdraw' then
        update private.group_discussion_invitations set status='withdrawn' where id=(p_arguments->>'invitation_id')::uuid and room_id=p_room and status='pending' returning id,recipient_id into object_id,target;
        if object_id is null then raise sqlstate 'PT409' using message='The invitation changed.'; end if;
        perform private.group_discussion_signal(target);
      when 'remove' then
        update private.group_discussion_admissions set ended_at=clock_timestamp(),ended_by=actor
          where id=(p_arguments->>'admission_id')::uuid and room_id=p_room and profile_id<>actor and ended_at is null returning id,profile_id into object_id,target;
        if object_id is null then raise sqlstate 'PT409' using message='The admission changed.'; end if;
        perform private.group_discussion_signal(target);
      when 'update' then
        if p_arguments->>'version' is null or p_arguments->>'archived' is null or jsonb_typeof(p_arguments->'archived')<>'boolean' then raise sqlstate '22023' using message='The discussion content is invalid.'; end if;
        if room.version<>(p_arguments->>'version')::bigint then raise sqlstate 'PT409' using message='The discussion changed.'; end if;
        if room.title is distinct from p_arguments->>'title' or room.archived is distinct from (p_arguments->>'archived')::boolean then
          update private.group_discussions set title=p_arguments->>'title',archived=(p_arguments->>'archived')::boolean,version=version+1 where id=p_room returning * into room;
        end if;
        object_id:=room.id;
      else raise sqlstate '22023' using message='The discussion command is invalid.';
    end case;
  end if;
  result:=jsonb_build_object('room_id',room.id,'object_id',object_id,'version',room.version,'sequence',room.last_sequence);
  insert into private.group_discussion_receipts values(actor,p_key,intent,result);
  for target in select a.profile_id from private.group_discussion_admissions a where a.room_id=room.id
    and private.group_discussion_admission(room.id,a.profile_id)=a.id
  loop perform private.group_discussion_signal(target); end loop;
  if p_operation='update' then
    for target in select recipient_id from private.group_discussion_invitations where room_id=room.id and status='pending'
    loop perform private.group_discussion_signal(target); end loop;
  end if;
  perform private.group_discussion_signal(actor);
  return result;
end;
$$;

create function public.create_group_discussion(p_expected_profile_id uuid,p_client_request_id uuid,p_group_id uuid,p_title text) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'create',p_group_id,null,jsonb_build_object('title',regexp_replace(p_title,'^[[:space:]]+|[[:space:]]+$','','g')));
$$;
create function public.send_group_discussion_message(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_body text) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'send',null,p_room_id,jsonb_build_object('body',regexp_replace(p_body,'^[[:space:]]+|[[:space:]]+$','','g')));
$$;
create function public.invite_group_discussion_member(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_profile_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'invite',null,p_room_id,jsonb_build_object('profile_id',p_profile_id));
$$;
create function public.respond_group_discussion_invitation(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_invitation_id uuid,p_response text) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'respond',null,p_room_id,jsonb_build_object('invitation_id',p_invitation_id,'response',p_response));
$$;
create function public.leave_group_discussion(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_admission_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'leave',null,p_room_id,jsonb_build_object('admission_id',p_admission_id));
$$;
create function public.remove_group_discussion_member(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_admission_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'remove',null,p_room_id,jsonb_build_object('admission_id',p_admission_id));
$$;
create function public.withdraw_group_discussion_invitation(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_invitation_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'withdraw',null,p_room_id,jsonb_build_object('invitation_id',p_invitation_id));
$$;
create function public.update_group_discussion(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_version bigint,p_title text,p_archived boolean) returns jsonb
language sql security definer set search_path='' as $$
  select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'update',null,p_room_id,jsonb_build_object('version',p_expected_version,'title',regexp_replace(p_title,'^[[:space:]]+|[[:space:]]+$','','g'),'archived',p_archived));
$$;

create function private.group_discussion_page(p_limit integer,p_time timestamptz,p_id uuid) returns void
language plpgsql immutable set search_path='' as $$
begin
  if p_limit is null or p_limit not between 1 and 50 or (p_time is null)<>(p_id is null) or (p_time is not null and not isfinite(p_time)) then
    raise sqlstate '22023' using message='The discussion page is invalid.'; end if;
end;
$$;
create function private.group_discussion_summary(p_room uuid,p_actor uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('kind','group_discussion','room_id',r.id,'group_id',r.group_id,'group_name',g.name,
    'title',r.title,'archived',r.archived,'version',r.version,'created_at',r.created_at,'admission_id',a.id,
    'can_manage',private.group_authority_role(r.group_id,p_actor) is not null,
    'can_publish',coalesce(not r.archived and private.group_authority_role(r.group_id,p_actor) in ('creator','co_creator'),false),
    'unread_count',(select count(*) from private.group_discussion_messages m where m.room_id=r.id and m.sender_id<>p_actor and m.sequence>greatest(a.frontier,a.read_sequence)),
    'preview',(select m.body from private.group_discussion_messages m where m.room_id=r.id and m.sequence>a.frontier order by m.sequence desc limit 1))
  from private.group_discussions r join private.community_groups g on g.id=r.group_id
  join private.group_discussion_admissions a on a.id=private.group_discussion_admission(r.id,p_actor) where r.id=p_room;
$$;
create function public.get_group_discussion(p_expected_profile_id uuid,p_room_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin perform private.require_group_discussion(p_room_id,actor); return private.group_discussion_summary(p_room_id,actor); end;
$$;
create function public.list_my_discussion_groups(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.group_id desc),'[]') into result from (
    select g.id group_id,g.name,g.created_at,count(r.id) room_count,
      coalesce(sum((private.group_discussion_summary(r.id,actor)->>'unread_count')::bigint),0) unread_count
    from private.community_groups g join private.group_discussions r on r.group_id=g.id
    where private.group_discussion_admission(r.id,actor) is not null
      and (p_before_id is null or (g.created_at,g.id)<(p_before_created_at,p_before_id))
    group by g.id order by g.created_at desc,g.id desc limit p_limit
  ) page;
  return result;
end;
$$;
create function public.list_group_discussions(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  if not private.group_discussion_group_available(p_group_id) or private.group_discussion_source(p_group_id,actor) is null then
    raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  select coalesce(jsonb_agg(private.group_discussion_summary(page.id,actor) order by page.created_at desc,page.id desc),'[]') into result
    from (select r.id,r.created_at from private.group_discussions r where r.group_id=p_group_id
      and private.group_discussion_admission(r.id,actor) is not null
      and (p_before_id is null or (r.created_at,r.id)<(p_before_created_at,p_before_id)) order by r.created_at desc,r.id desc limit p_limit) page;
  return result;
end;
$$;
create function public.list_group_discussion_invitations(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.invitation_id desc),'[]') into result from (
    select i.id invitation_id,i.room_id,i.created_at,i.status,r.title,g.id group_id,g.name group_name,
      coalesce(p.display_name,'Deleted account') inviter_name from private.group_discussion_invitations i
    join private.group_discussions r on r.id=i.room_id join private.community_groups g on g.id=r.group_id
    left join public.profiles p on p.id=i.inviter_id where i.recipient_id=actor and private.group_discussion_invitation_available(i.id)
      and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id)) order by i.created_at desc,i.id desc limit p_limit
  ) page;
  return result;
end;
$$;
create function private.group_discussion_read_token(p_admission uuid,p_sequence bigint,p_message uuid,p_secret uuid) returns text
language sql immutable set search_path='' as $$
  select p_sequence::text||':'||p_message::text||':'||encode(extensions.hmac(p_admission::text||':'||p_sequence::text||':'||p_message::text,p_secret::text,'sha256'),'hex');
$$;
create function public.list_group_discussion_people(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.require_group_discussion(p_room_id,actor);
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.admission_id desc),'[]') into result from (
    select a.id admission_id,a.profile_id,a.accepted_at created_at,coalesce(p.display_name,'Deleted account') display_name,
      private.group_authority_role(r.group_id,a.profile_id) manager_role from private.group_discussion_admissions a
      join private.group_discussions r on r.id=a.room_id left join public.profiles p on p.id=a.profile_id
    where a.room_id=p_room_id and private.group_discussion_admission(p_room_id,a.profile_id)=a.id
      and (p_before_id is null or (a.accepted_at,a.id)<(p_before_created_at,p_before_id)) order by a.accepted_at desc,a.id desc limit p_limit
  ) page; return result;
end; $$;
create function public.list_group_discussion_managed_invitations(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.require_group_discussion(p_room_id,actor);
  if private.group_authority_role((select group_id from private.group_discussions where id=p_room_id),actor) is null then
    raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.invitation_id desc),'[]') into result from (
    select i.id invitation_id,i.recipient_id,i.created_at,coalesce(p.display_name,'Deleted account') recipient_name
    from private.group_discussion_invitations i left join public.profiles p on p.id=i.recipient_id
    where i.room_id=p_room_id and private.group_discussion_invitation_available(i.id)
      and (p_before_id is null or (i.created_at,i.id)<(p_before_created_at,p_before_id)) order by i.created_at desc,i.id desc limit p_limit
  ) page; return result;
end; $$;
create function public.list_group_discussion_messages(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); admission private.group_discussion_admissions%rowtype; result jsonb; newest private.group_discussion_messages%rowtype; secret uuid;
begin
  if p_limit is null or p_limit not between 1 and 50 or p_before_sequence<=0 then raise sqlstate '22023' using message='The discussion page is invalid.'; end if;
  select * into admission from private.group_discussion_admissions where id=private.require_group_discussion(p_room_id,actor);
  select coalesce(jsonb_agg(to_jsonb(page) order by page.sequence desc),'[]') into result from (
    select m.id message_id,m.sequence,m.sender_id,coalesce(p.display_name,'Deleted account') sender_name,m.body,m.created_at
    from private.group_discussion_messages m left join public.profiles p on p.id=m.sender_id
    where m.room_id=p_room_id and m.sequence>admission.frontier and (p_before_sequence is null or m.sequence<p_before_sequence)
    order by m.sequence desc limit p_limit
  ) page;
  if p_before_sequence is null then
    select * into newest from private.group_discussion_messages where room_id=p_room_id and sequence>admission.frontier order by sequence desc limit 1;
    select read_secret into secret from private.group_discussions where id=p_room_id;
  end if;
  return jsonb_build_object('items',result,'snapshot_token',case when newest.id is not null then private.group_discussion_read_token(admission.id,newest.sequence,newest.id,secret) end);
end;
$$;
create function public.acknowledge_group_discussion_read(p_expected_profile_id uuid,p_room_id uuid,p_snapshot_token text) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); room private.group_discussions%rowtype; admission private.group_discussion_admissions%rowtype; message private.group_discussion_messages%rowtype;
begin
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room_id) for update;
  select * into room from private.group_discussions where id=p_room_id for update;
  select * into admission from private.group_discussion_admissions where id=private.require_group_discussion(p_room_id,actor);
  if p_snapshot_token is null or p_snapshot_token !~ '^[0-9]+:[0-9a-f-]{36}:[0-9a-f]{64}$' then raise sqlstate '22023' using message='The read snapshot is invalid.'; end if;
  select * into message from private.group_discussion_messages where room_id=p_room_id and id=split_part(p_snapshot_token,':',2)::uuid and sequence>admission.frontier;
  if message.id is null or p_snapshot_token<>private.group_discussion_read_token(admission.id,message.sequence,message.id,room.read_secret) then
    raise sqlstate '22023' using message='The read snapshot is invalid.'; end if;
  update private.group_discussion_admissions set read_sequence=greatest(read_sequence,message.sequence) where id=admission.id;
  perform private.group_discussion_signal(actor);
end;
$$;
create function public.get_group_discussion_unread(p_expected_profile_id uuid) returns bigint
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result bigint;
begin
  select count(*) into result from private.group_discussion_messages m join private.group_discussion_admissions a
    on a.id=private.group_discussion_admission(m.room_id,actor) where m.sender_id<>actor and m.sequence>greatest(a.frontier,a.read_sequence);
  return result;
end;
$$;

-- The schema default-deny harness remains authoritative. No API role (including
-- service_role) gets direct data or private command privileges.
do $$ declare object record; begin
  for object in select c.oid::regclass as name from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private' and c.relkind='r' and c.relname like 'group_discussion%'
  loop execute format('alter table %s enable row level security',object.name);
    execute format('revoke all on table %s from public,anon,authenticated,service_role',object.name); end loop;
  for object in select p.oid::regprocedure as name,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and (p.proname like '%group_discussion%' or p.proname='list_my_discussion_groups')
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',object.name);
    if object.nspname='public' or object.proname='group_discussion_topic_allowed' then
      execute format('grant execute on function %s to authenticated',object.name); end if;
  end loop;
end; $$;
comment on table private.group_discussion_admissions is 'C00 provisional explicit admission bound to one Group episode; message sequences above frontier only, current entitlement required.';
comment on function public.list_group_discussion_messages(uuid,uuid,integer,bigint) is 'Newest-first bounded sequence page; only a newest page issues an admission-bound read token. Client acknowledges after foreground newest rendering only.';
