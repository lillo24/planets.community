-- A1: presentation identity is an unordered profile pair; consent, transcripts,
-- source ordinals and installed RPCs remain owned by their original domains.
begin;

create function private.a1_actor(p_expected uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected);
begin
  if not private.cocreate_account_available(actor) then
    raise sqlstate '42501' using message='The personal identity is unavailable.'; end if;
  return actor;
end; $$;

create function private.a1_cocreate_actor(p_actor uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_cocreate_actor(p_actor);
  return true;
exception when insufficient_privilege then return false;
end; $$;

-- This is the complete unpaginated authorization inventory, never an API grant.
-- Resource endpoints come from the immutable listing/request relationship;
-- representatives, managers and Group coordination are deliberately absent.
create function private.a1_sources(p_actor uuid, p_peer uuid default null)
returns table(kind text,id uuid,peer uuid,title text,created_at timestamptz,
  can_send boolean,episode_id uuid,management_id uuid,activity_at timestamptz)
language sql stable security definer set search_path='' as $$
  with eligible(kind,id,peer,title,created_at,can_send,episode_id,management_id,activity_at) as (
  select 'project_request_chat',c.id,
    case when c.lower_profile_id=p_actor then c.upper_profile_id else c.lower_profile_id end,
    'Project / Tavolo',c.activated_at,
    exists(select 1 from public.participation_conversation_requests a where a.conversation_id=c.id
      and private.participation_request_allows_conversation_send(a.request_id)),null::uuid,c.id,
    (select max(greatest(r.created_at,coalesce(r.resolved_at,r.created_at)))
      from public.participation_conversation_requests a join public.project_join_requests r on r.id=a.request_id where a.conversation_id=c.id)
  from public.participation_conversations c
  where p_actor in(c.lower_profile_id,c.upper_profile_id)
    and (p_peer is null or (p_peer<>p_actor and p_peer in(c.lower_profile_id,c.upper_profile_id)))
    and private.profile_can_access_participation_conversation(c.id,p_actor)
  union all
  select 'resource_chat',c.id,
    case when l.owner_profile_id=p_actor then r.requester_profile_id else l.owner_profile_id end,
    l.title,c.activated_at,
    r.status='accepted' and r.coordination_closed_at is null and a.lifecycle_state not in('completed','cancelled'),
    null::uuid,r.id,case when p_actor in(l.owner_profile_id,r.requester_profile_id) then
      (select g.activity_at from public.get_own_resource_request_chat(p_actor,c.id)g) end
  from public.resource_request_chats c join public.resource_listing_requests r on r.id=c.request_id
  join public.resource_listings l on l.id=r.listing_id
  join public.resource_exchange_agreements a on a.request_id=r.id
  where p_actor in(l.owner_profile_id,r.requester_profile_id)
    and (p_peer is null or (p_peer<>p_actor and p_peer in(l.owner_profile_id,r.requester_profile_id)))
    and private.can_read_message_conversation('resource_chat',c.id,p_actor)
  union all
  select 'member_contact_chat',p.id,
    case when p_actor=p.low_profile_id then p.high_profile_id else p.low_profile_id end,
    r.group_name,p.created_at,private.member_contact_can_send(p.id,p_actor,e.id),
    case when e.ended_at is null then e.id end,p.id,greatest(e.accepted_at,coalesce(e.ended_at,e.accepted_at))
  from private.member_contact_pairs p
  cross join lateral(select e.* from private.member_contact_episodes e where e.pair_id=p.id
    order by e.accepted_at desc,e.id desc limit 1)e
  join private.member_contact_requests r on r.id=e.request_id
  where p_actor in(p.low_profile_id,p.high_profile_id)
    and (p_peer is null or (p_peer<>p_actor and p_peer in(p.low_profile_id,p.high_profile_id)))
    and private.member_contact_can_read(p.id,p_actor)
  union all
  select 'cocreate_contact',c.id,case when c.author_id=p_actor then c.requester_id else c.author_id end,
    p.title,c.created_at,c.closed_at is null,null::uuid,c.id,greatest(c.created_at,coalesce(c.closed_at,c.created_at))
  from private.cocreate_contacts c join private.cocreate_posts p on p.id=c.post_id
  where p_actor in(c.author_id,c.requester_id)
    and (p_peer is null or (p_peer<>p_actor and p_peer in(c.author_id,c.requester_id)))
    and private.a1_cocreate_actor(p_actor)
    and private.cocreate_account_available(c.author_id) and private.cocreate_account_available(c.requester_id)
    and not p.suppressed and not private.has_active_user_block_between(c.author_id,c.requester_id)
  ) select * from eligible s where private.cocreate_account_available(p_actor) and private.cocreate_account_available(s.peer);
$$;

-- Bound each indexed source BEFORE the mixed merge; never materialize a whole
-- transcript for the list or the first history page. ACK lookups use original IDs.
create index a1_member_chronology_idx on private.member_contact_messages(pair_id,created_at desc,id desc);
create index a1_cocreate_chronology_idx on private.cocreate_contact_messages(contact_id,created_at desc,id desc);
create function private.a1_messages(p_actor uuid,p_peer uuid,p_limit integer default null,
  p_before_created_at timestamptz default null,p_before_item_kind text default null,
  p_before_item_id uuid default null,p_keys text[] default null)
returns table(item_kind text,item_id uuid,source_kind text,source_id uuid,
  sender_profile_id uuid,sender_display_name text,body text,created_at timestamptz,
  ordinal bigint,context_id uuid)
language sql stable security definer set search_path='' as $$
  with sources as materialized(select * from private.a1_sources(p_actor,p_peer))
  select 'participation_message',m.id,s.kind,s.id,m.sender_profile_id,p.display_name,m.body,m.created_at,
    ms.ordinal,null::uuid from sources s
  cross join lateral(select m.* from public.participation_conversation_messages m
    where s.kind='project_request_chat' and m.conversation_id=s.id
      and (p_before_item_id is null or (m.created_at,'participation_message' collate "C",m.id)
        <(p_before_created_at,p_before_item_kind collate "C",p_before_item_id))
      and (p_keys is null or m.id=any(select split_part(k,':',2)::uuid from unnest(p_keys)k where split_part(k,':',1)='participation_message'))
    order by m.created_at desc,m.id desc limit p_limit)m
  join public.profiles p on p.id=m.sender_profile_id
  join private.message_sources ms on ms.source_kind='pair' and ms.source_id=m.id
  union all
  select 'participation_legacy_message',m.id,s.kind,s.id,m.sender_profile_id,p.display_name,m.body,m.created_at,
    ms.ordinal,a.request_id from sources s
  join public.participation_conversation_requests a on s.kind='project_request_chat' and a.conversation_id=s.id
  cross join lateral(select m.* from public.project_join_request_chat_messages m where m.chat_id=a.legacy_chat_id
    and (p_before_item_id is null or (m.created_at,'participation_legacy_message' collate "C",m.id)
      <(p_before_created_at,p_before_item_kind collate "C",p_before_item_id))
    and (p_keys is null or m.id=any(select split_part(k,':',2)::uuid from unnest(p_keys)k where split_part(k,':',1)='participation_legacy_message'))
    order by m.created_at desc,m.id desc limit p_limit)m
  join public.profiles p on p.id=m.sender_profile_id
  join private.message_sources ms on ms.source_kind='legacy' and ms.source_id=m.id
  union all
  select 'resource_message',m.id,s.kind,s.id,m.sender_profile_id,p.display_name,m.body,m.created_at,
    ms.ordinal,s.management_id from sources s
  cross join lateral(select m.* from public.resource_request_chat_messages m where s.kind='resource_chat' and m.chat_id=s.id
    and (p_before_item_id is null or (m.created_at,'resource_message' collate "C",m.id)
      <(p_before_created_at,p_before_item_kind collate "C",p_before_item_id))
    and (p_keys is null or m.id=any(select split_part(k,':',2)::uuid from unnest(p_keys)k where split_part(k,':',1)='resource_message'))
    order by m.created_at desc,m.id desc limit p_limit)m
  join public.profiles p on p.id=m.sender_profile_id
  join private.message_sources ms on ms.source_kind='resource' and ms.source_id=m.id
  union all
  select 'member_contact_message',m.id,s.kind,s.id,m.sender_profile_id,m.sender_display_name,m.body,m.created_at,
    m.ordinal,m.episode_id from sources s
  cross join lateral(select m.* from private.member_contact_messages m where s.kind='member_contact_chat' and m.pair_id=s.id
    and private.member_contact_message_readable(m,p_actor)
    and (p_before_item_id is null or (m.created_at,'member_contact_message' collate "C",m.id)
      <(p_before_created_at,p_before_item_kind collate "C",p_before_item_id))
    and (p_keys is null or m.id=any(select split_part(k,':',2)::uuid from unnest(p_keys)k where split_part(k,':',1)='member_contact_message'))
    order by m.created_at desc,m.id desc limit p_limit)m
  union all
  select 'cocreate_contact_message',m.id,s.kind,s.id,m.sender_id,p.display_name,m.body,m.created_at,
    m.sequence,s.id from sources s
  cross join lateral(select m.* from private.cocreate_contact_messages m where s.kind='cocreate_contact' and m.contact_id=s.id
    and (p_before_item_id is null or (m.created_at,'cocreate_contact_message' collate "C",m.id)
      <(p_before_created_at,p_before_item_kind collate "C",p_before_item_id))
    and (p_keys is null or m.id=any(select split_part(k,':',2)::uuid from unnest(p_keys)k where split_part(k,':',1)='cocreate_contact_message'))
    order by m.created_at desc,m.id desc limit p_limit)m
  join public.profiles p on p.id=m.sender_id;
$$;

create function private.a1_unread(p_actor uuid)
returns table(source_kind text,source_id uuid,ordinal bigint)
language sql stable security definer set search_path='' as $$
  with sources as materialized(select * from private.a1_sources(p_actor))
  select s.kind,s.id,i.ordinal from sources s
  join private.message_incoming i on i.profile_id=p_actor and i.conversation_kind=s.kind and i.chat_id=s.id
  left join private.message_read_frontiers f on f.profile_id=p_actor and f.conversation_kind=s.kind and f.chat_id=s.id
  where i.ordinal>coalesce(f.ordinal,0)
  union all
  select s.kind,s.id,i.ordinal from sources s join private.member_contact_incoming i on s.kind='member_contact_chat'
    and i.profile_id=p_actor and i.pair_id=s.id
  join private.member_contact_messages m on m.pair_id=i.pair_id and m.ordinal=i.ordinal
  left join private.member_contact_read_frontiers f on f.profile_id=p_actor and f.pair_id=s.id
  where i.ordinal>coalesce(f.ordinal,0) and private.member_contact_message_readable(m,p_actor)
  union all
  select s.kind,s.id,m.sequence from sources s join private.cocreate_contact_messages m
    on s.kind='cocreate_contact' and m.contact_id=s.id and m.sender_id<>p_actor
  left join private.cocreate_contact_reads r on r.contact_id=s.id and r.actor_id=p_actor
  where m.sequence>coalesce(r.read_sequence,0);
$$;

-- Management contexts are independent of human-message paging. Each pending
-- participation request is a distinct send witness: a race cannot switch Projects.
create function private.a1_contexts(p_actor uuid,p_peer uuid)
returns table(kind text,id uuid,source_id uuid,title text,status text,can_send boolean,
  episode_id uuid,created_at timestamptz)
language sql stable security definer set search_path='' as $$
  select 'participation_request',r.id,s.id,coalesce(p.title,t.title),r.status,
    private.participation_request_allows_conversation_send(r.id),null::uuid,r.created_at
  from private.a1_sources(p_actor,p_peer)s
  join public.participation_conversation_requests a on s.kind='project_request_chat' and a.conversation_id=s.id
  join public.project_join_requests r on r.id=a.request_id
  left join public.proposals p on p.id=r.project_id
  left join public.recurring_activities t on t.id=r.project_id
  union all
  select s.kind,s.id,s.id,s.title,
    case when s.can_send then 'open' else 'closed' end,s.can_send,s.episode_id,s.created_at
  from private.a1_sources(p_actor,p_peer)s where s.kind<>'project_request_chat';
$$;

create function public.list_own_private_pair_contexts_v1(p_expected_profile_id uuid,p_peer_profile_id uuid,
  p_limit integer default 25,p_before_kind text default null,p_before_id uuid default null,p_only_writable boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id);
begin
  if p_limit is null or p_limit not between 1 and 50 or p_only_writable is null
    or (p_before_kind is null)<>(p_before_id is null)
    or (p_before_kind is not null and p_before_kind not in('participation_request','resource_chat','member_contact_chat','cocreate_contact')) then
    raise sqlstate '22023' using message='Invalid personal context page.'; end if;
  if not exists(select 1 from private.a1_sources(actor,p_peer_profile_id) where peer=p_peer_profile_id) then
    raise sqlstate '42501' using message='The personal conversation is unavailable.'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(c) order by c.kind collate "C",c.id),'[]') from (
    select * from private.a1_contexts(actor,p_peer_profile_id)c
    where (not p_only_writable or c.can_send) and (p_before_id is null or (c.kind collate "C",c.id)>(p_before_kind collate "C",p_before_id))
    order by c.kind collate "C",c.id limit p_limit)c);
end; $$;

create function public.list_own_private_pairs_v1(p_expected_profile_id uuid,p_limit integer default 20,
  p_before_activity_at timestamptz default null,p_before_peer_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id);
begin
  perform private.validate_group_page(p_limit,p_before_activity_at,p_before_peer_id);
  return (with sources as materialized(select * from private.a1_sources(actor)),
    peers as(select peer,bool_or(can_send) can_send,max(activity_at) activated_at from sources group by peer),
    rows as(
      select q.peer peer_profile_id,p.display_name,
        least(actor,q.peer)::text||':'||greatest(actor,q.peer)::text pair_key,
        greatest(q.activated_at,coalesce(m.created_at,q.activated_at)) activity_at,
        not q.can_send is_read_only,m.item_id last_message_id,m.body last_message_body,
        m.sender_profile_id last_sender_profile_id,m.sender_display_name last_sender_display_name,
        case when m.item_id is null then 'empty' when q.activated_at>m.created_at then 'context' else 'message' end latest_activity_kind,
        (select count(*) from private.a1_unread(actor)u join sources s on s.kind=u.source_kind and s.id=u.source_id
          where s.peer=q.peer) unread_count
      from peers q join public.profiles p on p.id=q.peer
      left join lateral(select * from private.a1_messages(actor,q.peer,1)
        order by created_at desc,item_kind collate "C" desc,item_id desc limit 1)m on true
    ) select coalesce(jsonb_agg(to_jsonb(r) order by activity_at desc,peer_profile_id desc),'[]') from (
      select * from rows where p_before_peer_id is null or (activity_at,peer_profile_id)<(p_before_activity_at,p_before_peer_id)
      order by activity_at desc,peer_profile_id desc limit p_limit)r);
end; $$;

create function public.get_own_private_pair_unread_v1(p_expected_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id); groups bigint; pairs bigint; legacy jsonb;
begin
  legacy:=public.get_own_message_unread_summary_with_cocreate(actor);
  groups:=(legacy->>'groups')::bigint;
  select count(distinct s.peer) into pairs from private.a1_sources(actor)s
    where exists(select 1 from private.a1_unread(actor)u where u.source_kind=s.kind and u.source_id=s.id);
  return jsonb_build_object('total',pairs+groups,'private',pairs,'groups',groups);
end; $$;

-- Private, expiring newest-page bounds. No new message store or account FK.
create table private.a1_read_snapshots(
  token uuid primary key default gen_random_uuid(),actor uuid not null,peer uuid not null,
  frontiers jsonb not null,issued_at timestamptz not null default statement_timestamp()
);
create index a1_read_snapshots_actor_idx on private.a1_read_snapshots(actor,issued_at);
create index a1_read_snapshots_pair_idx on private.a1_read_snapshots(actor,peer,issued_at desc);
alter table private.a1_read_snapshots enable row level security;
revoke all on private.a1_read_snapshots from public,anon,authenticated,service_role;

create function public.get_own_private_pair_page_v1(p_expected_profile_id uuid,p_peer_profile_id uuid,
  p_limit integer default 30,p_before_created_at timestamptz default null,
  p_before_item_kind text default null,p_before_item_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id); items jsonb; bounds jsonb; boundary uuid;
begin
  if p_peer_profile_id is null or p_peer_profile_id=actor or p_limit is null or p_limit not between 1 and 50
    or num_nonnulls(p_before_created_at,p_before_item_kind,p_before_item_id) not in(0,3)
    or (p_before_item_kind is not null and p_before_item_kind not in('context','participation_message','participation_legacy_message',
      'resource_message','member_contact_message','cocreate_contact_message')) then
    raise sqlstate '22023' using message='Invalid personal history page.'; end if;
  if not exists(select 1 from private.a1_sources(actor,p_peer_profile_id) where peer=p_peer_profile_id) then
    raise sqlstate '42501' using message='The personal conversation is unavailable.'; end if;
  -- One SQL snapshot for page and source high-water marks. A token is not a
  -- blanket ACK: only explicitly rendered messages may advance a source prefix.
  with messages as materialized(select * from private.a1_messages(actor,p_peer_profile_id,p_limit,p_before_created_at,p_before_item_kind,p_before_item_id)),
    source_bounds as(
      select s.kind source_kind,s.id source_id,coalesce(case
        when s.kind in('project_request_chat','resource_chat') then
          (select last_ordinal from private.message_streams where conversation_kind=s.kind and chat_id=s.id)
        when s.kind='member_contact_chat' then (select last_ordinal from private.member_contact_pairs where id=s.id)
        else (select last_sequence from private.cocreate_contacts where id=s.id) end,0) ordinal
      from private.a1_sources(actor,p_peer_profile_id)s
    ),
    events as(
      select 'context'::text item_kind,c.id item_id,
        case when c.kind='participation_request' then 'project_request_chat' else c.kind end source_kind,
        c.source_id,null::uuid sender_profile_id,null::text sender_display_name,null::text body,
        c.created_at,null::bigint ordinal,c.id context_id,c.kind context_kind,c.title,c.status
      from private.a1_contexts(actor,p_peer_profile_id)c
    ), feed as(
      select m.*,null::text context_kind,null::text title,null::text status from messages m
      union all select * from events
    ), page as(
      select * from feed f where p_before_item_id is null or
        (f.created_at,f.item_kind collate "C",f.item_id)<(p_before_created_at,p_before_item_kind collate "C",p_before_item_id)
      order by f.created_at desc,f.item_kind collate "C" desc,f.item_id desc limit p_limit
    )
  select (select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('management_id',case when p.item_kind='context' then
      case when p.context_kind='participation_request' then p.context_id else
        (select s.management_id from private.a1_sources(actor,p_peer_profile_id)s where s.kind=p.source_kind and s.id=p.source_id) end end)
      order by created_at desc,item_kind collate "C" desc,item_id desc),'[]') from page p),
    (select coalesce(jsonb_agg(jsonb_build_object('kind',source_kind,'id',source_id,'ordinal',ordinal)),'[]')
      from source_bounds b)
  into items,bounds;
  if p_before_item_id is null then
    delete from private.a1_read_snapshots s where s.actor=p_expected_profile_id and s.issued_at<statement_timestamp()-interval '7 days';
    select s.token into boundary from private.a1_read_snapshots s where s.actor=p_expected_profile_id
      and s.peer=p_peer_profile_id and s.frontiers=bounds order by s.issued_at desc limit 1;
    if boundary is null then
      insert into private.a1_read_snapshots(actor,peer,frontiers) values(actor,p_peer_profile_id,bounds) returning token into boundary;
    else update private.a1_read_snapshots s set issued_at=statement_timestamp() where s.token=boundary;
    end if;
  end if;
  return jsonb_build_object('profile_id',actor,'peer_profile_id',p_peer_profile_id,
    'display_name',(select display_name from public.profiles where id=p_peer_profile_id),
    'has_resource_coordination',exists(select 1 from private.a1_sources(actor,p_peer_profile_id)s where s.kind='resource_chat' and s.can_send),
    'items',items,'read_boundary',boundary);
end; $$;

create function public.acknowledge_own_private_pair_v1(p_expected_profile_id uuid,p_peer_profile_id uuid,
  p_boundary uuid,p_rendered_keys text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id); snapshot private.a1_read_snapshots;
  candidate record; first_unseen bigint; advance bigint; changed boolean:=false; affected integer; rendered jsonb;
begin
  if p_rendered_keys is null or cardinality(p_rendered_keys) not between 1 and 200 then
    raise sqlstate '22023' using message='A rendered batch requires 1 through 200 original message keys.'; end if;
  if exists(select 1 from unnest(p_rendered_keys)k where k is null or k !~ '^[a-z_]+:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise sqlstate '22023' using message='Invalid original message key.'; end if;
  select * into snapshot from private.a1_read_snapshots s where s.token=p_boundary and s.actor=p_expected_profile_id
    and s.peer=p_peer_profile_id and s.issued_at>=statement_timestamp()-interval '7 days';
  if not found or not exists(select 1 from private.a1_sources(actor,p_peer_profile_id) where peer=p_peer_profile_id) then
    raise sqlstate '42501' using message='The personal read boundary is unavailable.'; end if;
  select coalesce(jsonb_agg(to_jsonb(m)),'[]') into rendered
    from private.a1_messages(actor,p_peer_profile_id,null,null,null,null,p_rendered_keys)m;
  -- Reject unknown/revoked/gated keys; never interpret one domain's ID in another.
  if exists(select 1 from unnest(p_rendered_keys) k where not exists(
    select 1 from jsonb_to_recordset(rendered)m(item_kind text,item_id uuid,source_kind text,source_id uuid,ordinal bigint),
      jsonb_array_elements(snapshot.frontiers)b
    where m.item_kind||':'||m.item_id::text=k and b->>'kind'=m.source_kind
      and (b->>'id')::uuid=m.source_id and m.ordinal<=(b->>'ordinal')::bigint)) then
    raise sqlstate '42501' using message='The rendered personal history changed.'; end if;
  for candidate in select m.source_kind,m.source_id,max(m.ordinal) ordinal
    from jsonb_to_recordset(rendered)m(item_kind text,item_id uuid,source_kind text,source_id uuid,ordinal bigint)
    where m.item_kind||':'||m.item_id::text=any(p_rendered_keys)
    group by m.source_kind,m.source_id order by m.source_kind,m.source_id
  loop
    if not exists(select 1 from private.a1_sources(actor,p_peer_profile_id)s where s.kind=candidate.source_kind and s.id=candidate.source_id) then
      raise sqlstate '42501' using message='The rendered personal source is no longer available.'; end if;
    -- Preserve monotonic source semantics without marking unloaded/offscreen
    -- incoming messages read. Historical/outgoing gaps require no receipt.
    -- Count original incoming gaps independently of a concurrently revoked
    -- projection. Gate-off must never make an unrendered gap look empty.
    select min(u.ordinal) into first_unseen from (
      select i.ordinal from private.message_incoming i left join private.message_read_frontiers f
        on f.profile_id=actor and f.conversation_kind=candidate.source_kind and f.chat_id=candidate.source_id
        where i.profile_id=actor and i.conversation_kind=candidate.source_kind and i.chat_id=candidate.source_id
          and i.ordinal>coalesce(f.ordinal,0)
      union all
      select i.ordinal from private.member_contact_incoming i left join private.member_contact_read_frontiers f
        on f.profile_id=actor and f.pair_id=candidate.source_id
        where candidate.source_kind='member_contact_chat' and i.profile_id=actor and i.pair_id=candidate.source_id
          and i.ordinal>coalesce(f.ordinal,0)
      union all
      select m.sequence from private.cocreate_contact_messages m left join private.cocreate_contact_reads f
        on f.actor_id=actor and f.contact_id=candidate.source_id
        where candidate.source_kind='cocreate_contact' and m.contact_id=candidate.source_id and m.sender_id<>actor
          and m.sequence>coalesce(f.read_sequence,0)
    )u where u.ordinal<=candidate.ordinal
      and not exists(select 1 from jsonb_to_recordset(rendered)m(source_kind text,source_id uuid,ordinal bigint,item_kind text,item_id uuid)
        where m.source_kind=candidate.source_kind and m.source_id=candidate.source_id and m.ordinal=u.ordinal
          and m.item_kind||':'||m.item_id::text=any(p_rendered_keys));
    advance:=least(candidate.ordinal,coalesce(first_unseen-1,candidate.ordinal));
    if candidate.source_kind in('project_request_chat','resource_chat') then
      insert into private.message_read_frontiers values(actor,candidate.source_kind,candidate.source_id,advance)
      on conflict(profile_id,conversation_kind,chat_id) do update set ordinal=excluded.ordinal
        where private.message_read_frontiers.ordinal<excluded.ordinal;
    elsif candidate.source_kind='member_contact_chat' then
      insert into private.member_contact_read_frontiers values(actor,candidate.source_id,advance)
      on conflict(profile_id,pair_id) do update set ordinal=excluded.ordinal where private.member_contact_read_frontiers.ordinal<excluded.ordinal;
    else
      insert into private.cocreate_contact_reads values(candidate.source_id,actor,advance)
      on conflict(contact_id,actor_id) do update set read_sequence=excluded.read_sequence where private.cocreate_contact_reads.read_sequence<excluded.read_sequence;
    end if;
    get diagnostics affected=row_count;
    changed:=changed or affected>0;
  end loop;
  if changed then perform private.signal_message_unread(actor); end if;
  return public.get_own_private_pair_unread_v1(actor);
end; $$;

create table private.a1_send_receipts(
  actor uuid not null,command_id uuid not null,intent_hash text not null,result jsonb not null,
  primary key(actor,command_id)
);
alter table private.a1_send_receipts enable row level security;
revoke all on private.a1_send_receipts from public,anon,authenticated,service_role;

create function public.send_own_private_pair_message_v1(p_expected_profile_id uuid,p_peer_profile_id uuid,
  p_command_id uuid,p_context_kind text,p_context_id uuid,p_episode_id uuid,p_body text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id); context record;
  intent text; prior private.a1_send_receipts; result jsonb; legacy uuid;
begin
  if p_command_id is null or p_context_id is null or p_context_kind is null
    or p_context_kind not in('participation_request','resource_chat','member_contact_chat','cocreate_contact') or p_body is null
    or char_length(btrim(p_body)) not between 1 and 4000 then
    raise sqlstate '22023' using message='Invalid personal send intent.'; end if;
  intent:=private.group_command_hash(jsonb_build_array(p_peer_profile_id,p_context_kind,p_context_id,p_episode_id,p_body));
  perform pg_advisory_xact_lock(hashtextextended('a1.command:'||actor::text||':'||p_command_id::text,0));
  select * into context from private.a1_contexts(actor,p_peer_profile_id)c
    where c.kind=p_context_kind and c.id=p_context_id;
  if not found then raise sqlstate '42501' using message='The selected personal context is unavailable.'; end if;
  select * into prior from private.a1_send_receipts r where r.actor=p_expected_profile_id and r.command_id=p_command_id;
  if found then
    if prior.intent_hash<>intent then raise sqlstate '22023' using message='The personal send intent differs.'; end if;
    return prior.result;
  end if;
  if not context.can_send or context.episode_id is distinct from p_episode_id then
    raise sqlstate 'PT409' using message='The selected personal context changed; refresh before sending.'; end if;
  -- Original domain writers own final locks, authority, rates, outbox and audit.
  case p_context_kind
    when 'participation_request' then
      select legacy_chat_id into strict legacy from public.participation_conversation_requests where request_id=p_context_id;
      select to_jsonb(m) into result from public.send_project_join_request_chat_message(actor,legacy,p_body)m;
    when 'resource_chat' then
      select to_jsonb(m) into result from public.send_resource_request_chat_message(actor,p_context_id,p_body)m;
    when 'member_contact_chat' then
      result:=public.send_member_contact_message(actor,p_command_id,p_context_id,p_episode_id,p_body);
    when 'cocreate_contact' then
      result:=public.mutate_cocreate_contact(actor,p_command_id,p_context_id,'send',p_body);
    else raise sqlstate '22023' using message='Unsupported personal context.';
  end case;
  result:=jsonb_build_object('command_id',p_command_id,'context_kind',p_context_kind,'context_id',p_context_id,'result',result);
  insert into private.a1_send_receipts values(actor,p_command_id,intent,result);
  return result;
end; $$;

-- Exact links are resolved BEFORE opening the pair. An inaccessible source never
-- falls through to a different readable source with the same person.
create function public.resolve_own_private_pair_v1(p_expected_profile_id uuid,p_context_kind text,p_context_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.a1_actor(p_expected_profile_id); peer uuid; result jsonb;
begin
  select s.peer into peer from private.a1_sources(actor)s where s.kind=p_context_kind and s.id=p_context_id;
  if p_context_kind='participation_request' then
    select s.peer into peer from private.a1_sources(actor)s
      join public.participation_conversation_requests a on s.kind='project_request_chat' and a.conversation_id=s.id
      where a.request_id=p_context_id;
  end if;
  if peer is null then raise sqlstate '42501' using message='The personal source is unavailable.'; end if;
  select to_jsonb(c) into result from private.a1_contexts(actor,peer)c where c.kind=p_context_kind and c.id=p_context_id;
  return jsonb_build_object('profile_id',actor,'peer_profile_id',peer,'context_kind',p_context_kind,'context_id',p_context_id,'context',result);
end; $$;

-- Account/policy changes must also invalidate warm native-only pairs. The hint
-- addresses each own account and contains no peer, source, status or body.
create function private.a1_emit_identity_hint(p_changed uuid) returns void
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  for recipient in
    select p_changed
    union select case when lower_profile_id=p_changed then upper_profile_id else lower_profile_id end
      from public.participation_conversations where p_changed in(lower_profile_id,upper_profile_id)
    union select case when l.owner_profile_id=p_changed then r.requester_profile_id else l.owner_profile_id end
      from public.resource_request_chats c join public.resource_listing_requests r on r.id=c.request_id
      join public.resource_listings l on l.id=r.listing_id where p_changed in(l.owner_profile_id,r.requester_profile_id)
    union select case when low_profile_id=p_changed then high_profile_id else low_profile_id end
      from private.member_contact_pairs where p_changed in(low_profile_id,high_profile_id)
    union select case when author_id=p_changed then requester_id else author_id end
      from private.cocreate_contacts where p_changed in(author_id,requester_id)
  loop perform private.signal_message_unread(recipient); end loop;
end; $$;
create function private.a1_policy_identity_hint() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform private.a1_emit_identity_hint(case when tg_op='DELETE' then old.account_id else new.account_id end);
  return null;
end; $$;
-- Extend the existing reviewed account/profile metadata hook by one call. Its
-- existing room/contact audiences and Auth trigger definitions remain intact.
create or replace function private.cocreate_access_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if tg_table_name='users' then
  if new.deleted_at is not null and old.deleted_at is null then perform private.cocreate_end_erased_memberships(new.id);end if;
 end if;
 if tg_table_name='cocreate_settings' then
  for person in select author_id from private.cocreate_posts union select requester_id from private.cocreate_interests
   union select actor_id from private.cocreate_room_episodes
  loop perform private.cocreate_signal(person);end loop;
 else
  perform private.a1_emit_identity_hint(new.id);
  if not exists(select 1 from private.cocreate_posts where author_id=new.id)
   and not exists(select 1 from private.cocreate_interests where requester_id=new.id)
   and not exists(select 1 from private.cocreate_contacts where new.id in(author_id,requester_id))
   and not exists(select 1 from private.cocreate_room_episodes where actor_id=new.id) then return null;end if;
  perform private.cocreate_signal(new.id);
  for person in select case when c.author_id=new.id then c.requester_id else c.author_id end
   from private.cocreate_contacts c where new.id in(c.author_id,c.requester_id)
   union select e.actor_id from private.cocreate_room_episodes e where e.ended_at is null and exists(
    select 1 from private.cocreate_room_episodes mine where mine.room_id=e.room_id and mine.actor_id=new.id and mine.ended_at is null)
  loop perform private.cocreate_signal(person);end loop;
 end if;
 return null;
end; $$;
create trigger a1_policy_hint after insert or update or delete on private.policy_acceptances
  for each row execute function private.a1_policy_identity_hint();

create function private.a1_native_message_hint() returns trigger
language plpgsql security definer set search_path='' as $$
declare source uuid; kind text; recipient uuid;
begin
  if tg_table_name='participation_conversation_messages' then kind:='project_request_chat';source:=new.conversation_id;
  elsif tg_table_name='project_join_request_chat_messages' then kind:='project_request_chat';
    select conversation_id into source from public.participation_conversation_requests where legacy_chat_id=new.chat_id;
  else kind:='resource_chat';source:=new.chat_id;
  end if;
  -- The existing writer already hints incoming recipients. Invalidate the
  -- sender's other devices as well, without creating another activity alert.
  for recipient in select profile_id from private.message_recipients(kind,source) where profile_id=new.sender_profile_id
  loop perform private.signal_message_unread(recipient); end loop;
  return null;
end; $$;
create trigger a1_pair_message_hint after insert on public.participation_conversation_messages
  for each row execute function private.a1_native_message_hint();
create trigger a1_legacy_message_hint after insert on public.project_join_request_chat_messages
  for each row execute function private.a1_native_message_hint();
create trigger a1_resource_message_hint after insert on public.resource_request_chat_messages
  for each row execute function private.a1_native_message_hint();

revoke all on function private.a1_actor(uuid),private.a1_cocreate_actor(uuid),private.a1_sources(uuid,uuid),private.a1_messages(uuid,uuid,integer,timestamptz,text,uuid,text[]),
  private.a1_unread(uuid),private.a1_contexts(uuid,uuid),private.a1_emit_identity_hint(uuid),
  private.a1_policy_identity_hint(),private.a1_native_message_hint() from public,anon,authenticated,service_role;
revoke all on function public.list_own_private_pair_contexts_v1(uuid,uuid,integer,text,uuid,boolean),
  public.list_own_private_pairs_v1(uuid,integer,timestamptz,uuid),public.get_own_private_pair_unread_v1(uuid),
  public.get_own_private_pair_page_v1(uuid,uuid,integer,timestamptz,text,uuid),
  public.acknowledge_own_private_pair_v1(uuid,uuid,uuid,text[]),
  public.send_own_private_pair_message_v1(uuid,uuid,uuid,text,uuid,uuid,text),
  public.resolve_own_private_pair_v1(uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_own_private_pair_contexts_v1(uuid,uuid,integer,text,uuid,boolean),
  public.list_own_private_pairs_v1(uuid,integer,timestamptz,uuid),public.get_own_private_pair_unread_v1(uuid),
  public.get_own_private_pair_page_v1(uuid,uuid,integer,timestamptz,text,uuid),
  public.acknowledge_own_private_pair_v1(uuid,uuid,uuid,text[]),
  public.send_own_private_pair_message_v1(uuid,uuid,uuid,text,uuid,uuid,text),
  public.resolve_own_private_pair_v1(uuid,text,uuid) to authenticated;
commit;
