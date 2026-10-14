-- D01b: explicit grant-bound conversations; no inherited organizational history.
create table private.group_contact_conversations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid unique references private.group_contact_requests(id) on delete restrict,
  title text not null check(char_length(title) between 1 and 120),
  summary text not null check(char_length(summary) between 1 and 1000),
  conversation_kind text not null default 'bilateral' check(conversation_kind in ('bilateral','coordination')),
  created_at timestamptz not null default clock_timestamp(),
  closed_at timestamptz,
  closed_by uuid,
  last_ordinal bigint not null default 0,
  check((closed_at is null)=(closed_by is null))
);
create table private.group_contact_admissions (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references private.group_contact_conversations(id) on delete restrict,
  profile_id uuid not null,
  group_id uuid not null references private.community_groups(id) on delete restrict,
  delegate_id uuid references private.group_delegates(id) on delete restrict,
  admitted_at timestamptz not null default clock_timestamp(),
  left_at timestamptz,
  unique(conversation_id,profile_id),unique(conversation_id,group_id)
);
create index group_contact_admission_profile_idx on private.group_contact_admissions(profile_id,conversation_id);
create index group_contact_admission_group_idx on private.group_contact_admissions(group_id);
create index group_contact_admission_delegate_idx on private.group_contact_admissions(delegate_id);
create table private.group_contact_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references private.group_contact_conversations(id) on delete restrict,
  admission_id uuid not null references private.group_contact_admissions(id) on delete restrict,
  sender_profile_id uuid not null,
  represented_group_id uuid not null references private.community_groups(id) on delete restrict,
  group_name_at_send text not null,
  body text not null check(char_length(body) between 1 and 4000),
  ordinal bigint not null check(ordinal>0),
  created_at timestamptz not null default clock_timestamp(),
  unique(conversation_id,ordinal)
);
create index group_contact_message_page on private.group_contact_messages(conversation_id,ordinal desc,id desc);
create index group_contact_message_admission_idx on private.group_contact_messages(admission_id);
create index group_contact_message_sender_rate on private.group_contact_messages(sender_profile_id,created_at desc);
create index group_contact_message_group_idx on private.group_contact_messages(represented_group_id);
create trigger group_contact_messages_append_only before update or delete on private.group_contact_messages
  for each row execute function private.protect_moderation_append_only();
create trigger group_contact_admission_provenance before update on private.group_contact_admissions
  for each row execute function private.protect_group_relationship_provenance('left_at');
create trigger group_contact_conversation_provenance before update on private.group_contact_conversations
  for each row execute function private.protect_group_relationship_provenance('closed_at','closed_by','last_ordinal');
alter table private.group_contact_conversations enable row level security;
alter table private.group_contact_admissions enable row level security;
alter table private.group_contact_messages enable row level security;
revoke all on private.group_contact_conversations,private.group_contact_admissions,private.group_contact_messages from public,anon,authenticated,service_role;

create function private.group_contact_can_read(p_chat uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.group_contact_admissions a where a.conversation_id=p_chat and a.profile_id=p_actor and a.left_at is null
    and private.group_contact_representation_valid(a.group_id,p_actor,a.delegate_id));
$$;
create function private.group_contact_can_send(p_chat uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.group_contact_can_read(p_chat,p_actor) and exists(select 1 from private.group_contact_conversations c where c.id=p_chat and c.closed_at is null
    and (select count(*) from private.group_contact_admissions a where a.conversation_id=c.id and a.left_at is null
      and private.group_contact_representation_valid(a.group_id,a.profile_id,a.delegate_id) and private.group_is_public(a.group_id))>=2
    and (c.conversation_kind='coordination' or not exists(select 1 from private.group_contact_admissions a where a.conversation_id=c.id
      and (a.left_at is not null or not private.group_contact_representation_valid(a.group_id,a.profile_id,a.delegate_id))))
    and not exists(select 1 from private.group_contact_admissions a where a.conversation_id=c.id and a.left_at is null and
      private.group_contact_representation_valid(a.group_id,a.profile_id,a.delegate_id) and not private.group_is_public(a.group_id))
    and not exists(select 1 from private.group_contact_admissions a join private.group_contact_admissions b on a.conversation_id=b.conversation_id and a.profile_id<b.profile_id
      where a.conversation_id=c.id and a.left_at is null and b.left_at is null
        and private.group_contact_representation_valid(a.group_id,a.profile_id,a.delegate_id)
        and private.group_contact_representation_valid(b.group_id,b.profile_id,b.delegate_id)
        and private.has_active_user_block_between(a.profile_id,b.profile_id)));
$$;
create function private.group_contact_message_projection(p_message private.group_contact_messages) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',p_message.id,'chat_id',p_message.conversation_id,'sender_profile_id',p_message.sender_profile_id,
    'sender_display_name',(select p.display_name from public.profiles p join auth.users u on u.id=p.id where p.id=p_message.sender_profile_id),
    'represented_group_id',p_message.represented_group_id,'group_name_at_send',p_message.group_name_at_send,
    'body',p_message.body,'ordinal',p_message.ordinal,'created_at',p_message.created_at);
$$;
create function private.group_contact_chat_projection(p_chat uuid,p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c private.group_contact_conversations; m private.group_contact_messages; audience jsonb;
begin
  if not private.group_contact_can_read(p_chat,p_actor) then raise sqlstate '42501' using message='The representative conversation is unavailable.'; end if;
  select * into c from private.group_contact_conversations where id=p_chat;
  select * into m from private.group_contact_messages where conversation_id=p_chat order by ordinal desc,id desc limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('profile_id',a.profile_id,'group_id',a.group_id,'group_name',g.name,
    'display_name',p.display_name,'active',a.left_at is null and private.group_contact_representation_valid(a.group_id,a.profile_id,a.delegate_id)) order by a.group_id),'[]')
    into audience from private.group_contact_admissions a join private.community_groups g on g.id=a.group_id
    left join public.profiles p on p.id=a.profile_id and exists(select 1 from auth.users u where u.id=p.id) where a.conversation_id=p_chat;
  return jsonb_build_object('item_kind','group_contact_chat','chat_id',c.id,'conversation_kind',c.conversation_kind,
    'display_title',c.title,'summary',c.summary,'activity_at',coalesce(m.created_at,c.created_at),'created_at',c.created_at,
    'is_read_only',not private.group_contact_can_send(p_chat,p_actor),'closed_at',c.closed_at,'audience',audience,
    'last_visible_message_id',m.id,'last_visible_message_body',m.body,'last_visible_message_at',m.created_at,
    'last_visible_sender_profile_id',m.sender_profile_id,'last_visible_sender_display_name',
      (select p.display_name from public.profiles p join auth.users u on u.id=p.id where p.id=m.sender_profile_id));
end;
$$;
create function public.get_own_group_contact_conversation(p_expected_profile_id uuid,p_chat_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin return private.group_contact_chat_projection(p_chat_id,actor); end;
$$;
create function public.accept_group_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); hash text; receipt private.group_contact_receipts;
  r private.group_contact_requests; c uuid; result jsonb;
begin
  if p_action_id is null or p_request_id is null then raise sqlstate '22023' using message='Invalid contact action.'; end if;
  hash:=private.group_command_hash(jsonb_build_object('operation','accept','target',p_request_id));
  perform pg_advisory_xact_lock(hashtextextended('group.contact.action:'||actor::text||':'||p_action_id::text,0));
  select * into receipt from private.group_contact_receipts where actor_id=actor and action_id=p_action_id;
  if found then
    if hash<>receipt.intent_hash then raise sqlstate 'PT409' using message='This action has different submitted intent.'; end if;
    return receipt.result||jsonb_build_object('replayed',true);
  end if;
  select * into r from private.group_contact_requests where id=p_request_id;
  if r.id is null then raise sqlstate '42501' using message='The contact request is unavailable.'; end if;
  perform private.group_contact_lock(array[r.source_group_id,r.target_group_id],array[actor,r.submitter_id],r.target_group_id,r.submitter_id);
  perform private.require_group_actor(actor);
  select * into r from private.group_contact_requests where id=p_request_id for update;
  if actor=r.submitter_id or private.group_authority_role(r.target_group_id,actor) is null then raise sqlstate '42501' using message='The contact request is unavailable.'; end if;
  if r.status<>'pending' or r.expires_at<=clock_timestamp() or not private.group_contact_triage_available(r) then
    raise sqlstate 'PT409' using message='This contact request is no longer available for acceptance.';
  end if;
  insert into private.group_contact_conversations(request_id,title,summary) values(r.id,r.title,r.note) returning id into c;
  insert into private.group_contact_admissions(conversation_id,profile_id,group_id,delegate_id) values
    (c,r.submitter_id,r.source_group_id,r.source_delegate_id),(c,actor,r.target_group_id,private.group_contact_delegate(r.target_group_id,actor));
  update private.group_contact_requests set status='accepted',resolved_at=clock_timestamp(),resolved_by=actor where id=r.id;
  result:=jsonb_build_object('request_id',r.id,'chat_id',c,'outcome','accepted','replayed',false);
  insert into private.group_contact_receipts values(actor,p_action_id,hash,result,clock_timestamp());
  perform private.audit_group_relationship('group.contact_accepted',actor,r.target_group_id,r.id);
  return result;
end;
$$;
create function private.group_contact_conversation_command(p_expected uuid,p_action uuid,p_chat uuid,p_operation text,p_body text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected); hash text; receipt private.group_contact_receipts; result jsonb;
  groups uuid[]; people uuid[]; admission private.group_contact_admissions; message private.group_contact_messages; next_ordinal bigint; body text;
begin
  if p_action is null or p_chat is null or p_operation not in ('send','close','leave') then raise sqlstate '22023' using message='Invalid conversation action.'; end if;
  hash:=private.group_command_hash(jsonb_build_object('operation',p_operation,'target',p_chat,'body',p_body));
  perform pg_advisory_xact_lock(hashtextextended('group.contact.action:'||actor::text||':'||p_action::text,0));
  select * into receipt from private.group_contact_receipts where actor_id=actor and action_id=p_action;
  if found then
    if hash<>receipt.intent_hash then raise sqlstate 'PT409' using message='This action has different submitted intent.'; end if;
    return receipt.result||jsonb_build_object('replayed',true);
  end if;
  select array_agg(group_id order by group_id),array_agg(profile_id order by profile_id) into groups,people
    from private.group_contact_admissions where conversation_id=p_chat;
  if p_operation='send' then
    perform pg_advisory_xact_lock(hashtextextended('group.contact.quota:'||actor::text,0));
    perform private.group_contact_lock(groups,people);
  else perform 1 from private.community_groups g where g.id=any(groups) order by g.id for update; end if;
  perform private.require_group_identity(actor);
  perform 1 from private.group_contact_conversations where id=p_chat for update;
  select * into admission from private.group_contact_admissions where conversation_id=p_chat and profile_id=actor for update;
  if admission.id is null then raise sqlstate '42501' using message='The representative conversation is unavailable.'; end if;
  if p_operation='send' then
    if not private.group_contact_can_send(p_chat,actor) then raise sqlstate '42501' using message='Sending is unavailable. Refresh the conversation.'; end if;
    body:=regexp_replace(coalesce(p_body,''),'^[[:space:]]+|[[:space:]]+$','','g');
    if char_length(body) not between 1 and (private.group_contact_limits()->>'message')::integer then raise sqlstate '22023' using message='The message must contain between 1 and 4,000 characters.'; end if;
    if (select count(*) from private.group_contact_messages where sender_profile_id=actor and created_at>clock_timestamp()-interval '1 minute')>=(private.group_contact_limits()->>'messages_per_minute')::integer then
      raise sqlstate 'PT429' using message='The message limit has been reached. Try later.'; end if;
    update private.group_contact_conversations set last_ordinal=last_ordinal+1 where id=p_chat returning last_ordinal into next_ordinal;
    insert into private.group_contact_messages(conversation_id,admission_id,sender_profile_id,represented_group_id,group_name_at_send,body,ordinal)
      select p_chat,admission.id,actor,admission.group_id,g.name,body,next_ordinal from private.community_groups g where g.id=admission.group_id returning * into message;
    result:=jsonb_build_object('chat_id',p_chat,'message_id',message.id,'outcome','sent','replayed',false);
  elsif p_operation='close' then
    if admission.left_at is not null or exists(select 1 from private.group_contact_conversations where id=p_chat and closed_at is not null) then
      raise sqlstate 'PT409' using message='This conversation is already closed or left.'; end if;
    update private.group_contact_conversations set closed_at=clock_timestamp(),closed_by=actor where id=p_chat;
    result:=jsonb_build_object('chat_id',p_chat,'outcome','closed','replayed',false);
  else
    if admission.left_at is not null then raise sqlstate 'PT409' using message='This conversation has already been left.'; end if;
    update private.group_contact_admissions set left_at=clock_timestamp() where id=admission.id;
    result:=jsonb_build_object('chat_id',p_chat,'outcome','left','replayed',false);
  end if;
  insert into private.group_contact_receipts values(actor,p_action,hash,result,clock_timestamp());
  if p_operation<>'send' then perform private.audit_group_relationship('group.contact_'||p_operation,actor,admission.group_id,p_chat); end if;
  return result;
end;
$$;
create function public.send_group_contact_message(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid,p_body text) returns jsonb
language sql security definer set search_path='' as $$ select private.group_contact_conversation_command(p_expected_profile_id,p_action_id,p_chat_id,'send',p_body); $$;
create function public.close_group_contact_conversation(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.group_contact_conversation_command(p_expected_profile_id,p_action_id,p_chat_id,'close'); $$;
create function public.leave_group_contact_conversation(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.group_contact_conversation_command(p_expected_profile_id,p_action_id,p_chat_id,'leave'); $$;

-- Dedicated unread receipts avoid modifying installed clients' kind allowlists,
-- restrictive account FKs, or existing Project/Resource former-history rules.
create table private.group_contact_incoming (
  profile_id uuid not null,
  conversation_id uuid not null references private.group_contact_conversations(id) on delete restrict,
  ordinal bigint not null,
  primary key(profile_id,conversation_id,ordinal),
  foreign key(conversation_id,ordinal) references private.group_contact_messages(conversation_id,ordinal) on delete restrict
);
create table private.group_contact_read_frontiers (
  profile_id uuid not null,
  conversation_id uuid not null references private.group_contact_conversations(id) on delete restrict,
  ordinal bigint not null,
  primary key(profile_id,conversation_id)
);
create table private.group_contact_read_snapshots (
  token uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  conversation_id uuid not null references private.group_contact_conversations(id) on delete restrict,
  ordinal bigint not null,
  issued_at timestamptz not null default clock_timestamp(),
  unique(profile_id,conversation_id,ordinal)
);
create index group_contact_incoming_message_idx on private.group_contact_incoming(conversation_id,ordinal);
create index group_contact_snapshot_chat_idx on private.group_contact_read_snapshots(conversation_id);
alter table private.group_contact_incoming enable row level security;
alter table private.group_contact_read_frontiers enable row level security;
alter table private.group_contact_read_snapshots enable row level security;
revoke all on private.group_contact_incoming,private.group_contact_read_frontiers,private.group_contact_read_snapshots from public,anon,authenticated,service_role;
create function private.group_contact_unread(p_actor uuid,p_chat uuid) returns bigint
language sql stable security definer set search_path='' as $$
  select count(*) from private.group_contact_incoming i where i.profile_id=p_actor and i.conversation_id=p_chat
    and private.group_contact_can_read(p_chat,p_actor) and i.ordinal>coalesce((select ordinal from private.group_contact_read_frontiers where profile_id=p_actor and conversation_id=p_chat),0);
$$;
create function private.group_contact_signal(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor) then
    perform realtime.send(jsonb_build_object('profile_id',p_actor),'group.contact_changed','group-contact:profile:'||p_actor::text,true);
  end if;
end; $$;
create function private.group_contact_record_message() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  for recipient in select a.profile_id from private.group_contact_admissions a where a.conversation_id=new.conversation_id and a.profile_id<>new.sender_profile_id
    and private.group_contact_can_read(new.conversation_id,a.profile_id) order by a.profile_id
  loop
    insert into private.group_contact_incoming values(recipient,new.conversation_id,new.ordinal);
    perform private.group_contact_signal(recipient);
  end loop;
  return new;
end; $$;
create trigger group_contact_message_receipts after insert on private.group_contact_messages
  for each row execute function private.group_contact_record_message();
create function public.can_receive_group_contact_signal(p_topic text) returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and p_topic='group-contact:profile:'||auth.uid()::text
    and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=auth.uid());
$$;
create policy group_contact_signal_receive on realtime.messages for select to authenticated
  using(extension='broadcast' and public.can_receive_group_contact_signal((select realtime.topic())));
create function public.get_own_group_contact_feed(p_expected_profile_id uuid,p_chat_id uuid,p_limit integer default 20,p_before_ordinal bigint default null,p_before_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); items jsonb; token uuid; frontier bigint;
begin
  if not private.group_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The representative conversation is unavailable.'; end if;
  if p_limit is null or p_limit not between 1 and 50 or (p_before_ordinal is null)<>(p_before_id is null) or p_before_ordinal<=0 then
    raise sqlstate '22023' using message='Invalid feed page or cursor.'; end if;
  select coalesce(jsonb_agg(private.group_contact_message_projection(m) order by m.ordinal desc,m.id desc),'[]'),coalesce(max(m.ordinal),0) into items,frontier from
    (select m.* from private.group_contact_messages m where m.conversation_id=p_chat_id
      and (p_before_id is null or (m.ordinal,m.id)<(p_before_ordinal,p_before_id)) order by m.ordinal desc,m.id desc limit p_limit) m;
  if p_before_id is null then
    delete from private.group_contact_read_snapshots where profile_id=actor and issued_at<clock_timestamp()-interval '7 days';
    insert into private.group_contact_read_snapshots(profile_id,conversation_id,ordinal) values(actor,p_chat_id,frontier)
      on conflict(profile_id,conversation_id,ordinal) do update set issued_at=clock_timestamp() returning group_contact_read_snapshots.token into token;
  end if;
  return jsonb_build_object('items',items,'read_boundary',token);
end; $$;
create function public.acknowledge_group_contact_read(p_expected_profile_id uuid,p_chat_id uuid,p_boundary uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); snapshot private.group_contact_read_snapshots;
begin
  select * into snapshot from private.group_contact_read_snapshots where token=p_boundary and profile_id=actor and conversation_id=p_chat_id and issued_at>=clock_timestamp()-interval '7 days';
  if snapshot.token is null or not private.group_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The read boundary is unavailable.'; end if;
  insert into private.group_contact_read_frontiers values(actor,p_chat_id,snapshot.ordinal) on conflict(profile_id,conversation_id)
    do update set ordinal=greatest(private.group_contact_read_frontiers.ordinal,excluded.ordinal);
  perform private.group_contact_signal(actor);
end; $$;
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'group_contact_%') or
      (n.nspname='public' and p.proname=any(array['get_own_group_contact_conversation','accept_group_contact_request','send_group_contact_message','close_group_contact_conversation','leave_group_contact_conversation','can_receive_group_contact_signal','get_own_group_contact_feed','acknowledge_group_contact_read']))
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
