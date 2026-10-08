-- ADR 0008: the source-table locks make cutover atomic with every old writer.
begin;
lock table public.participation_conversation_messages,
  public.project_chat_messages, public.project_join_request_chat_messages,
  public.resource_request_chat_messages in share row exclusive mode;

create table private.message_streams (
  conversation_kind text not null check (conversation_kind in ('project_request_chat','project_chat','resource_chat')),
  chat_id uuid not null,
  last_ordinal bigint not null default 0 check (last_ordinal >= 0),
  primary key (conversation_kind, chat_id)
);
create table private.message_sources (
  source_kind text not null check (source_kind in ('pair','legacy','project','resource')),
  source_id uuid not null,
  conversation_kind text not null,
  chat_id uuid not null,
  ordinal bigint not null check (ordinal > 0),
  sender_profile_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null,
  primary key (source_kind, source_id),
  unique (conversation_kind, chat_id, ordinal),
  foreign key (conversation_kind, chat_id) references private.message_streams(conversation_kind, chat_id) on delete restrict
);
create table private.message_incoming (
  profile_id uuid not null references public.profiles(id) on delete restrict,
  conversation_kind text not null,
  chat_id uuid not null,
  ordinal bigint not null,
  primary key (profile_id, conversation_kind, chat_id, ordinal),
  foreign key (conversation_kind, chat_id, ordinal) references private.message_sources(conversation_kind, chat_id, ordinal) on delete restrict
);
create table private.message_read_frontiers (
  profile_id uuid not null references public.profiles(id) on delete restrict,
  conversation_kind text not null,
  chat_id uuid not null,
  ordinal bigint not null check (ordinal >= 0),
  primary key (profile_id, conversation_kind, chat_id)
);
create table private.message_read_snapshots (
  token uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete restrict,
  conversation_kind text not null,
  chat_id uuid not null,
  ordinal bigint not null check (ordinal >= 0),
  issued_at timestamptz not null default statement_timestamp(),
  unique (profile_id, conversation_kind, chat_id, ordinal)
);
create index message_sources_sender_idx on private.message_sources(sender_profile_id);
create index message_incoming_source_idx on private.message_incoming(conversation_kind,chat_id,ordinal);
create index message_read_snapshots_profile_idx on private.message_read_snapshots(profile_id,issued_at);

alter table private.message_streams enable row level security;
alter table private.message_sources enable row level security;
alter table private.message_incoming enable row level security;
alter table private.message_read_frontiers enable row level security;
alter table private.message_read_snapshots enable row level security;
revoke all on private.message_streams, private.message_sources, private.message_incoming,
  private.message_read_frontiers, private.message_read_snapshots from public,anon,authenticated,service_role;

create function private.message_recipients(p_kind text,p_chat uuid)
returns table(profile_id uuid) language sql stable security definer set search_path='' as $$
  select c.lower_profile_id from public.participation_conversations c where p_kind='project_request_chat' and c.id=p_chat
  union select c.upper_profile_id from public.participation_conversations c where p_kind='project_request_chat' and c.id=p_chat
  union select m.profile_id from public.project_group_chats c cross join lateral private.current_project_manager_profile_ids(c.project_id) m where p_kind='project_chat' and c.id=p_chat
  union select m.participant_profile_id from public.project_group_chats c join public.project_memberships m on m.project_id=c.project_id
    where p_kind='project_chat' and c.id=p_chat and m.left_at is null and m.removed_at is null
  union select l.owner_profile_id from public.resource_request_chats c join public.resource_listing_requests r on r.id=c.request_id
    join public.resource_listings l on l.id=r.listing_id where p_kind='resource_chat' and c.id=p_chat
  union select r.requester_profile_id from public.resource_request_chats c join public.resource_listing_requests r on r.id=c.request_id
    where p_kind='resource_chat' and c.id=p_chat;
$$;
create function private.can_read_message_conversation(p_kind text,p_chat uuid,p_profile uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select case p_kind
    when 'project_request_chat' then private.profile_can_access_participation_conversation(p_chat,p_profile)
    when 'project_chat' then exists (select 1 from public.project_group_chats c where c.id=p_chat
      and private.profile_has_project_chat_history_entitlement(c.project_id,p_profile))
    when 'resource_chat' then exists (select 1 from private.message_recipients(p_kind,p_chat) r where r.profile_id=p_profile)
    else false end;
$$;
create function private.message_history_cutoff(p_kind text,p_chat uuid,p_profile uuid)
returns timestamptz language sql stable security definer set search_path='' as $$
  -- Compose the canonical history predicate once per conversation. Infinity is
  -- readable only for a current manager/member; former history uses the existing
  -- latest-ended-membership limit. This is the same predicate as the feed.
  select case when not private.can_read_message_conversation(p_kind,p_chat,p_profile) then null
    when p_kind<>'project_chat' then 'infinity'::timestamptz
    else (select case when private.profile_can_read_project_chat_message(c.project_id,p_profile,'infinity'::timestamptz)
      then 'infinity'::timestamptz else private.latest_project_membership_end(c.project_id,p_profile) end
      from public.project_group_chats c where c.id=p_chat) end;
$$;

create function private.signal_message_unread(p_profile uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform realtime.send(jsonb_build_object('profile_id',p_profile),'messages.unread_changed',
    'message-unread:profile:' || p_profile::text,true);
end;
$$;
create function private.can_receive_message_unread(p_topic text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and p_topic='message-unread:profile:' || auth.uid()::text;
$$;
create policy message_unread_receive on realtime.messages for select to authenticated
using (extension='broadcast' and private.can_receive_message_unread((select realtime.topic())));

-- Historical sources acquire metadata, but no incoming receipts. This happens once,
-- under source locks; neither sign-in nor demo rerun establishes a new baseline.
insert into private.message_streams(conversation_kind,chat_id)
select 'project_request_chat',id from public.participation_conversations
union all select 'project_chat',id from public.project_group_chats
union all select 'resource_chat',id from public.resource_request_chats;
with history as (
  select 'pair'::text source_kind,id source_id,'project_request_chat'::text conversation_kind,conversation_id chat_id,sender_profile_id,created_at from public.participation_conversation_messages
  union all select 'legacy',m.id,'project_request_chat',a.conversation_id,m.sender_profile_id,m.created_at from public.project_join_request_chat_messages m
    join public.participation_conversation_requests a on a.legacy_chat_id=m.chat_id
  union all select 'project',id,'project_chat',chat_id,sender_profile_id,created_at from public.project_chat_messages
  union all select 'resource',id,'resource_chat',chat_id,sender_profile_id,created_at from public.resource_request_chat_messages
)
insert into private.message_sources(source_kind,source_id,conversation_kind,chat_id,ordinal,sender_profile_id,created_at)
select source_kind,source_id,conversation_kind,chat_id,
  row_number() over(partition by conversation_kind,chat_id order by created_at,source_kind,source_id),sender_profile_id,created_at from history;
update private.message_streams s set last_ordinal=coalesce((select max(m.ordinal) from private.message_sources m
  where m.conversation_kind=s.conversation_kind and m.chat_id=s.chat_id),0);

create function private.record_message_unread()
returns trigger language plpgsql security definer set search_path='' as $$
declare kind text; chat uuid; source text; next_ordinal bigint; recipient uuid;
begin
  case tg_table_name
    when 'participation_conversation_messages' then kind:='project_request_chat'; chat:=new.conversation_id; source:='pair';
    when 'project_join_request_chat_messages' then kind:='project_request_chat'; source:='legacy';
      select a.conversation_id into strict chat from public.participation_conversation_requests a where a.legacy_chat_id=new.chat_id;
    when 'project_chat_messages' then kind:='project_chat'; chat:=new.chat_id; source:='project';
    when 'resource_request_chat_messages' then kind:='resource_chat'; chat:=new.chat_id; source:='resource';
  end case;
  -- Last lock in a send. Readers/acknowledgements never lock this row and then a
  -- Project. UPDATE serialization is held until transaction commit, unlike a sequence.
  insert into private.message_streams(conversation_kind,chat_id,last_ordinal) values(kind,chat,1)
  on conflict (conversation_kind,chat_id) do update set last_ordinal=private.message_streams.last_ordinal+1
  returning last_ordinal into next_ordinal;
  insert into private.message_sources values(source,new.id,kind,chat,next_ordinal,new.sender_profile_id,new.created_at);
  for recipient in select r.profile_id from private.message_recipients(kind,chat) r where r.profile_id<>new.sender_profile_id order by r.profile_id loop
    insert into private.message_incoming values(recipient,kind,chat,next_ordinal);
    perform private.signal_message_unread(recipient);
  end loop;
  return new;
end;
$$;
create trigger msg02_record_pair after insert on public.participation_conversation_messages for each row execute function private.record_message_unread();
create trigger msg02_record_legacy after insert on public.project_join_request_chat_messages for each row execute function private.record_message_unread();
create trigger msg02_record_project after insert on public.project_chat_messages for each row execute function private.record_message_unread();
create trigger msg02_record_resource after insert on public.resource_request_chat_messages for each row execute function private.record_message_unread();

create function private.own_message_unread(p_profile uuid)
returns table(conversation_kind text,chat_id uuid,unread_count bigint)
language sql stable security definer set search_path='' as $$
  with candidates as materialized (
    select distinct i.conversation_kind,i.chat_id from private.message_incoming i where i.profile_id=p_profile
  ), readable as materialized (
    select c.conversation_kind,c.chat_id,private.message_history_cutoff(c.conversation_kind,c.chat_id,p_profile) cutoff,
      coalesce(f.ordinal,0) frontier from candidates c left join private.message_read_frontiers f
      on f.profile_id=p_profile and f.conversation_kind=c.conversation_kind and f.chat_id=c.chat_id
  )
  select i.conversation_kind,i.chat_id,count(*) from readable r
  join private.message_incoming i using(conversation_kind,chat_id)
  join private.message_sources m using(conversation_kind,chat_id,ordinal)
  where i.profile_id=p_profile and i.ordinal>r.frontier and m.created_at<=r.cutoff
  group by i.conversation_kind,i.chat_id;
$$;
create function public.get_own_message_unread_summary(p_expected_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_participation_identity(p_expected_profile_id); result jsonb;
begin
  select jsonb_build_object('total',count(*),'private',count(*) filter(where conversation_kind<>'project_chat'),
    'groups',count(*) filter(where conversation_kind='project_chat')) into result from private.own_message_unread(actor);
  return result;
end;
$$;

create function public.list_own_scoped_conversation_items_v3(
  p_expected_profile_id uuid,p_scope text,p_limit integer,
  p_cursor_activity_at timestamptz default null,p_cursor_item_kind text default null,p_cursor_chat_id uuid default null
)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg((to_jsonb(item)-'ordinality')||jsonb_build_object('unread_count',coalesce(u.unread_count,0))
    order by item.ordinality),'[]'::jsonb)
  from public.list_own_scoped_conversation_items(p_expected_profile_id,p_scope,p_limit,p_cursor_activity_at,p_cursor_item_kind,p_cursor_chat_id) with ordinality item
  left join private.own_message_unread(p_expected_profile_id) u on u.conversation_kind=item.item_kind and u.chat_id=item.chat_id;
$$;

create function public.get_own_message_feed_page(
  p_expected_profile_id uuid,p_kind text,p_chat_id uuid,p_limit integer,
  p_before_created_at timestamptz default null,p_before_item_kind text default null,p_before_item_id uuid default null,
  p_only_pending boolean default false
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_participation_identity(p_expected_profile_id); items jsonb; frontier bigint; boundary uuid;
begin
  if not private.can_read_message_conversation(p_kind,p_chat_id,actor) then
    raise exception using errcode='42501',message='The message conversation is unavailable.';
  end if;
  if p_limit is null or p_limit not between 1 and 50 or p_only_pending is null then
    raise exception using errcode='22023',message='Invalid message page.';
  end if;
  -- Both projections run in ONE statement snapshot. Never issue a token from a
  -- later independent max() query, which could swallow an intervening arrival.
  if p_kind='project_request_chat' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,
      case x.item_kind when 'request' then 0 when 'legacy_message' then 1 else 2 end desc,x.item_id desc),'[]'::jsonb),
      (select s.last_ordinal from private.message_streams s where s.conversation_kind=p_kind and s.chat_id=p_chat_id)
    into items,frontier from public.list_own_participation_conversation_items(actor,p_chat_id,p_limit,p_before_created_at,p_before_item_kind,p_before_item_id,p_only_pending) x;
  elsif p_kind='project_chat' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,case x.item_kind when 'message' then 1 else 0 end desc,x.item_id desc),'[]'::jsonb),
      (select s.last_ordinal from private.message_streams s where s.conversation_kind=p_kind and s.chat_id=p_chat_id)
    into items,frontier from public.list_own_project_chat_feed(actor,p_chat_id,p_limit,p_before_created_at,p_before_item_kind,p_before_item_id) x;
  else
    if p_before_item_kind is not null and p_before_item_kind<>'message' then
      raise exception using errcode='22023',message='Invalid Resource message cursor.';
    end if;
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.message_id desc),'[]'::jsonb),
      (select s.last_ordinal from private.message_streams s where s.conversation_kind=p_kind and s.chat_id=p_chat_id)
    into items,frontier from public.list_own_resource_request_chat_messages(actor,p_chat_id,p_limit,p_before_created_at,p_before_item_id) x;
  end if;
  if p_before_created_at is null and not p_only_pending then
    -- Empty new conversations have zero. Readers never lock/create a stream:
    -- a still-uncommitted writer must not block issuing the earlier snapshot.
    frontier:=coalesce(frontier,0);
    delete from private.message_read_snapshots where profile_id=actor and issued_at<statement_timestamp()-interval '7 days';
    insert into private.message_read_snapshots(profile_id,conversation_kind,chat_id,ordinal)
    values(actor,p_kind,p_chat_id,frontier) on conflict(profile_id,conversation_kind,chat_id,ordinal)
    do update set issued_at=statement_timestamp() returning token into boundary;
  end if;
  return jsonb_build_object('items',items,'read_boundary',boundary);
end;
$$;
create function public.acknowledge_own_message_read(p_expected_profile_id uuid,p_kind text,p_chat_id uuid,p_boundary uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_participation_identity(p_expected_profile_id); boundary private.message_read_snapshots%rowtype;
begin
  select * into boundary from private.message_read_snapshots where token=p_boundary and profile_id=actor
    and conversation_kind=p_kind and chat_id=p_chat_id and issued_at>=statement_timestamp()-interval '7 days';
  if not found or not private.can_read_message_conversation(p_kind,p_chat_id,actor) then
    raise exception using errcode='42501',message='The message read boundary is unavailable.';
  end if;
  insert into private.message_read_frontiers values(actor,p_kind,p_chat_id,boundary.ordinal)
    on conflict(profile_id,conversation_kind,chat_id) do update
    set ordinal=greatest(private.message_read_frontiers.ordinal,excluded.ordinal);
  perform private.signal_message_unread(actor);
  return public.get_own_message_unread_summary(actor);
end;
$$;

-- Access-change invalidations contain no conversation identity or private state.
create function private.signal_message_access_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid; creator uuid; pair_chat uuid;
begin
  if tg_table_name in ('project_memberships','project_delegates') then
    -- O(1) admission/revocation work, even for the capacity verifier's large
    -- groups. Other members' unread eligibility did not change.
    recipient:=case when tg_table_name='project_memberships' then (to_jsonb(new)->>'participant_profile_id')::uuid
      else (to_jsonb(new)->>'delegate_profile_id')::uuid end;
    select creator_profile_id into creator from public.projects where id=new.project_id;
    if recipient is not null then perform private.signal_message_unread(recipient); end if;
    if creator is not null and creator<>recipient then perform private.signal_message_unread(creator); end if;
  elsif tg_table_name='participation_conversation_requests' then
    for recipient in select r.profile_id from private.message_recipients('project_request_chat',new.conversation_id) r loop
      perform private.signal_message_unread(recipient);
    end loop;
  elsif tg_table_name='project_join_requests' then
    select a.conversation_id into pair_chat from public.participation_conversation_requests a where a.request_id=new.id;
    for recipient in select r.profile_id from private.message_recipients('project_request_chat',pair_chat) r loop
      perform private.signal_message_unread(recipient);
    end loop;
  elsif tg_table_name='resource_listing_requests' then
    select c.id into pair_chat from public.resource_request_chats c where c.request_id=new.id;
    for recipient in select r.profile_id from private.message_recipients('resource_chat',pair_chat) r loop
      perform private.signal_message_unread(recipient);
    end loop;
  end if;
  return new;
end;
$$;
create trigger msg02_membership_access after insert or update on public.project_memberships for each row execute function private.signal_message_access_change();
create trigger msg02_delegate_access after insert or update on public.project_delegates for each row execute function private.signal_message_access_change();
create trigger msg02_pair_access after insert on public.participation_conversation_requests for each row execute function private.signal_message_access_change();
create trigger msg02_pair_read_only after update of status on public.project_join_requests for each row execute function private.signal_message_access_change();
create trigger msg02_resource_read_only after update of status,coordination_closed_at on public.resource_listing_requests for each row execute function private.signal_message_access_change();

revoke all on function private.message_recipients(text,uuid),private.can_read_message_conversation(text,uuid,uuid),
  private.message_history_cutoff(text,uuid,uuid),private.signal_message_unread(uuid),private.can_receive_message_unread(text),
  private.record_message_unread(),private.own_message_unread(uuid),private.signal_message_access_change()
  from public,anon,authenticated,service_role;
grant execute on function private.can_receive_message_unread(text) to authenticated;
revoke all on function public.get_own_message_unread_summary(uuid),public.list_own_scoped_conversation_items_v3(uuid,text,integer,timestamptz,text,uuid),
  public.get_own_message_feed_page(uuid,text,uuid,integer,timestamptz,text,uuid,boolean),public.acknowledge_own_message_read(uuid,text,uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_own_message_unread_summary(uuid),public.list_own_scoped_conversation_items_v3(uuid,text,integer,timestamptz,text,uuid),
  public.get_own_message_feed_page(uuid,text,uuid,integer,timestamptz,text,uuid,boolean),public.acknowledge_own_message_read(uuid,text,uuid,uuid) to authenticated;

comment on table private.message_incoming is 'MSG02 send-time eligible incoming human messages only. No pre-cutover backlog or first-admission/re-entry backscroll receipts.';
comment on table private.message_streams is 'MSG02 transactional commit serialization acquired after domain locks, not a timestamp/UUID/sequence read frontier.';
comment on function public.get_own_message_feed_page(uuid,text,uuid,integer,timestamptz,text,uuid,boolean) is 'Versioned feed envelope. Newest history and private read boundary use one snapshot; old pages and pending-only previews cannot acknowledge.';

-- Activity-only projection. Keep the shared resolver and push consumer intact.
create or replace function public.list_own_notifications(
  p_expected_profile_id uuid,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  notification_id uuid,
  category_slug text,
  notification_kind text,
  created_at timestamptz,
  read_at timestamptz,
  project_id uuid,
  project_kind text,
  destination_kind text,
  request_id uuid,
  chat_id uuid,
  message_id uuid,
  project_title text,
  actor_profile_id uuid,
  actor_display_name text,
  resource_listing_id uuid,
  resource_listing_title text,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  resource_exchange_event_kind text,
  resource_exchange_leg_kind text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification page size must be between 1 and 100.';
  end if;

  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Notification pagination requires both cursor timestamp and cursor ID.';
  end if;

  return query
  select
    notification.id,
    notification.category_slug,
    notification.notification_kind,
    notification.created_at,
    notification.read_at,
    notification.project_id,
    project.project_kind,
    notification.destination_kind,
    notification.request_id,
    notification.chat_id,
    notification.message_id,
    case
      when project.project_kind = 'one_time' then proposal.title
      when project.project_kind = 'recurring' then recurring.title
    end,
    notification.actor_profile_id,
    actor.display_name,
    notification.resource_listing_id,
    listing.title,
    notification.resource_request_id,
    notification.resource_chat_id,
    notification.resource_chat_message_id,
    notification.resource_agreement_id,
    notification.resource_agreement_event_id,
    agreement_event.event_kind,
    agreement_event.leg_kind
  from public.notifications as notification
  left join public.projects as project on project.id = notification.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as recurring
    on recurring.id = project.id
    and project.project_kind = 'recurring'
  left join public.resource_listings as listing
    on listing.id = notification.resource_listing_id
  left join public.resource_exchange_agreement_events as agreement_event
    on agreement_event.id = notification.resource_agreement_event_id
  left join public.profiles as actor on actor.id = notification.actor_profile_id
  where notification.recipient_profile_id = current_profile_id
    and notification.notification_kind not in ('chat_message_received','resource_chat_message_received')
    and (
      p_cursor_created_at is null
      or (notification.created_at, notification.id)
        < (p_cursor_created_at, p_cursor_id)
    )
  order by notification.created_at desc, notification.id desc
  limit p_limit;
end;
$$;

create or replace function public.get_own_unread_notification_count(
  p_expected_profile_id uuid
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
  unread_count bigint;
begin
  select count(*) into unread_count
  from public.notifications as notification
  where notification.recipient_profile_id = current_profile_id
    and notification.notification_kind not in ('chat_message_received','resource_chat_message_received')
    and notification.read_at is null;

  return unread_count;
end;
$$;

create or replace function public.mark_all_notifications_read(
  p_expected_profile_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
  affected_count integer;
begin
  update public.notifications as notification
  set read_at = statement_timestamp()
  where notification.recipient_profile_id = current_profile_id
    and notification.notification_kind not in ('chat_message_received','resource_chat_message_received')
    and notification.read_at is null;

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

create or replace function public.process_notification_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  notifications_created integer,
  notifications_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  in_app_enabled boolean;
  resolved_processed_count integer := 0;
  resolved_notifications_created integer := 0;
  resolved_notifications_suppressed integer := 0;
  inserted_count integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed',
      'project.chat_message_sent',
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed',
      'resource_chat.message_sent',
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed',
      'resource_saved_search.matched',
      'project.delegate_role_offered'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'notifications.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
      select coalesce(
        preference.in_app_enabled,
        category.default_in_app_enabled
      )
      into in_app_enabled
      from public.notification_categories as category
      left join public.profile_notification_preferences as preference
        on preference.profile_id = resolved_event.recipient_profile_id
        and preference.category_slug = category.slug
      where category.slug = resolved_event.category_slug;

      if in_app_enabled is null then
        raise exception using
          errcode = '55000',
          message = 'The resolved notification category is unavailable.';
      end if;

      if in_app_enabled and resolved_event.notification_kind not in ('chat_message_received','resource_chat_message_received') then
        if resolved_event.category_slug = 'matching'
          and resolved_event.notification_kind = 'matching_available' then
          insert into public.notifications (
            recipient_profile_id,
            category_slug,
            notification_kind,
            source_outbox_event_id,
            project_id,
            actor_profile_id,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            source_event.id,
            resolved_event.project_id,
            resolved_event.actor_profile_id,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict do nothing;

          get diagnostics inserted_count = row_count;
          if inserted_count = 0 then
            resolved_notifications_suppressed :=
              resolved_notifications_suppressed + 1;
          else
            resolved_notifications_created :=
              resolved_notifications_created + inserted_count;
          end if;
        else
          insert into public.notifications (
            recipient_profile_id,
            category_slug,
            notification_kind,
            source_outbox_event_id,
            project_id,
            actor_profile_id,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            source_event.id,
            resolved_event.project_id,
            resolved_event.actor_profile_id,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict (
            source_outbox_event_id,
            recipient_profile_id,
            notification_kind
          ) do nothing;

          get diagnostics inserted_count = row_count;
          resolved_notifications_created :=
            resolved_notifications_created + inserted_count;
        end if;
      else
        resolved_notifications_suppressed :=
          resolved_notifications_suppressed + 1;
      end if;
    end loop;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'notifications.v1', statement_timestamp())
    on conflict do nothing;

    resolved_processed_count := resolved_processed_count + 1;
  end loop;

  return query select
    resolved_processed_count,
    resolved_notifications_created,
    resolved_notifications_suppressed;
end;
$$;
commit;
