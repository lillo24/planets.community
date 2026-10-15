-- C-R04: General owns the Group-wide workspace; Ideas retain separate collections.
-- Current scope only: full history does not authorize former users to read mutable links.
-- Forward revision preserves URL/name validation, immutable identity and RPC shapes.
create or replace function public.get_group_discussion_link(p_expected_profile_id uuid,p_room_id uuid,p_link_id uuid,p_expected_admission_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); admission uuid:=private.require_group_discussion_access(p_room_id,actor); link private.group_discussion_links%rowtype;
begin
  if p_expected_admission_id is null or admission<>p_expected_admission_id then raise sqlstate '42501' using message='The discussion link is unavailable.'; end if;
  select l.* into link from private.group_discussion_links l
    where l.id=p_link_id and l.room_id=p_room_id and l.removed_at is null;
  if not found then raise sqlstate '42501' using message='The discussion link is unavailable.'; end if;
  return private.group_discussion_link_payload(actor,admission,link);
end; $$;
create or replace function public.list_group_discussion_links(p_expected_profile_id uuid,p_room_id uuid,p_expected_admission_id uuid default null,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); admission uuid:=private.require_group_discussion_access(p_room_id,actor); items jsonb; archived boolean; manager boolean;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  if p_limit>25 then raise sqlstate '22023' using message='The discussion link page is invalid.'; end if;
  if p_expected_admission_id is not null and admission<>p_expected_admission_id then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  select r.archived or r.frozen_at is not null,not r.archived and r.frozen_at is null and private.group_discussion_can_manage(r.id,actor) into archived,manager from private.group_discussions r where r.id=p_room_id;
  select coalesce(jsonb_agg(private.group_discussion_link_payload(actor,admission,l::private.group_discussion_links) order by l.created_at desc,l.id desc),'[]'::jsonb) into items
    from (select l.* from private.group_discussion_links l
      where l.room_id=p_room_id and l.removed_at is null
        and (p_before_created_at is null or (l.created_at,l.id)<(p_before_created_at,p_before_id))
      order by l.created_at desc,l.id desc limit p_limit) l;
  return jsonb_build_object('profile_id',actor,'room_id',p_room_id,'admission_id',admission,'archived',archived,'can_manage',manager,'items',items);
end; $$;

create or replace function private.group_discussion_link_command(p_actor uuid,p_key uuid,p_room uuid,p_admission uuid,p_operation text,p_link uuid,p_version bigint,p_name text,p_url text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_actor); group_id uuid; room private.group_discussions%rowtype;
  admission uuid; link private.group_discussion_links%rowtype;
  receipt private.group_discussion_receipts%rowtype; intent jsonb; result jsonb; changed boolean:=false;
begin
  if p_key is null or p_admission is null or p_operation not in ('add','edit','remove') or p_operation is null
    or p_operation<>'add' and (p_link is null or p_version is null or p_version<1) then raise sqlstate '22023' using message='The discussion link command is invalid.'; end if;
  if p_operation<>'remove' then
    p_name:=btrim(p_name);p_url:=private.normalize_project_workspace_url(p_url);
    if p_name is null or char_length(p_name) not between 1 and 120 or p_name~'[[:cntrl:]]' then raise sqlstate '22023' using message='A valid discussion link name is required.'; end if;
  end if;
  intent:=jsonb_build_object('operation','link:'||p_operation,'group',null,'room',p_room,
    'arguments',jsonb_build_object('admission',p_admission,'link',p_link,'version',p_version,'name',p_name,'url',p_url));
  -- This is C01's actor/key namespace, shared across all C commands.
  perform pg_advisory_xact_lock(hashtextextended('group-discussion:'||actor::text||':'||p_key::text,0));
  select r.group_id into group_id from private.group_discussions r where r.id=p_room;
  if group_id is null then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  perform 1 from private.community_groups g where g.id=group_id for update;
  select r.* into room from private.group_discussions r where r.id=p_room for update;
  actor:=private.require_group_actor(p_actor);
  admission:=private.require_group_discussion_access(p_room,actor);
  if admission<>p_admission then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  if not private.group_discussion_can_manage(p_room,actor) then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_key;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The command identity was reused.'; end if;
    return receipt.result;
  end if;
  if room.archived or room.frozen_at is not null then raise sqlstate '55000' using message='The discussion is read-only.'; end if;
  if p_operation='add' then
    changed:=true;
    update private.group_discussions r set last_sequence=r.last_sequence+1 where r.id=p_room returning r.* into room;
    insert into private.group_discussion_links(room_id,creator_id,created_sequence,display_name,destination)
      values(p_room,actor,room.last_sequence,p_name,p_url) returning * into link;
  else
    select l.* into link from private.group_discussion_links l where l.id=p_link and l.room_id=p_room
      and l.removed_at is null for update;
    if not found then raise sqlstate '42501' using message='The discussion link is unavailable.'; end if;
    if link.version<>p_version then raise sqlstate 'PT409' using message='The discussion link changed.'; end if;
    if p_operation='remove' then
      changed:=true;
      update private.group_discussion_links l set removed_at=clock_timestamp(),updated_at=clock_timestamp(),version=l.version+1 where l.id=link.id returning l.* into link;
    elsif (link.display_name,link.destination) is distinct from (p_name,p_url) then
      changed:=true;
      update private.group_discussion_links l set display_name=p_name,destination=p_url,updated_at=clock_timestamp(),version=l.version+1 where l.id=link.id returning l.* into link;
    end if;
  end if;
  -- Meaningful workspace edits resurface quiet Ideas; receipt retries and no-op
  -- edits do not invent activity or alter any human-message unread frontier.
  if changed then update private.group_discussions set last_activity_at=clock_timestamp() where id=p_room; end if;
  result:=jsonb_build_object('room_id',p_room,'object_id',link.id,'version',link.version,'sequence',link.created_sequence);
  insert into private.group_discussion_receipts(actor_id,request_id,intent,result) values(actor,p_key,intent,result);
  perform private.signal_group_discussion_room(p_room);
  perform private.group_discussion_signal(actor);
  return result;
end; $$;

-- Explicit v2 entry points keep the existing strict collection shape. The
-- admission_id wire field now identifies the current access scope (including
-- observed General/manager access); it never grants ordinary room membership.
create function public.get_group_discussion_link_v2(p_expected_profile_id uuid,p_room_id uuid,p_link_id uuid,p_expected_admission_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select public.get_group_discussion_link(p_expected_profile_id,p_room_id,p_link_id,p_expected_admission_id);
$$;
create function public.list_group_discussion_links_v2(p_expected_profile_id uuid,p_room_id uuid,p_expected_admission_id uuid default null,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id);
begin
  -- Direct Group workspace entry is a deliberate current collection read.
  -- Ensuring its scope does not mark any message rendered or acknowledge it.
  perform private.ensure_group_discussion_access(p_room_id,actor);
  return public.list_group_discussion_links(actor,p_room_id,p_expected_admission_id,p_limit,p_before_created_at,p_before_id);
end;
$$;
create function public.add_group_discussion_link_v2(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_admission_id uuid,p_name text,p_url text) returns jsonb
language sql security definer set search_path='' as $$
  select public.add_group_discussion_link(p_expected_profile_id,p_client_request_id,p_room_id,p_expected_admission_id,p_name,p_url);
$$;
create function public.update_group_discussion_link_v2(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_admission_id uuid,p_link_id uuid,p_expected_version bigint,p_name text,p_url text) returns jsonb
language sql security definer set search_path='' as $$
  select public.update_group_discussion_link(p_expected_profile_id,p_client_request_id,p_room_id,p_expected_admission_id,p_link_id,p_expected_version,p_name,p_url);
$$;
create function public.remove_group_discussion_link_v2(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_admission_id uuid,p_link_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path='' as $$
  select public.remove_group_discussion_link(p_expected_profile_id,p_client_request_id,p_room_id,p_expected_admission_id,p_link_id,p_expected_version);
$$;

-- Only an independently authorized Project chat can be mapped to a folder.
-- Group-only roles cannot use a guessed chat ID to obtain Project metadata.
create function public.list_own_group_project_chat_folders(p_expected_profile_id uuid,p_chat_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_participation_identity(p_expected_profile_id); result jsonb;
begin
  if p_chat_ids is null or cardinality(p_chat_ids)>25 or array_position(p_chat_ids,null) is not null then
    raise sqlstate '22023' using message='The Project chat selection is invalid.';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('chat_id',c.id,'group_id',g.id,'group_name',g.name) order by c.id),'[]') into result
  from public.project_group_chats c join public.projects p on p.id=c.project_id
  join private.community_groups g on g.id=p.attributed_group_id
  where c.id=any(p_chat_ids) and private.can_read_message_conversation('project_chat',c.id,actor)
    and private.group_discussion_group_available(g.id);
  return result;
end; $$;

-- Same Project-chat authorization and v5 wire shape; Group scope is applied
-- BEFORE keyset/limit. Never download a global chat list to filter in the client.
create function public.list_group_project_conversations(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_activity_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_participation_identity(p_expected_profile_id); result jsonb;
begin
  perform private.group_discussion_page(p_limit,p_before_activity_at,p_before_id);
  if not private.group_discussion_group_available(p_group_id) or not (
    private.group_discussion_source(p_group_id,actor) is not null or exists (
      select 1 from public.projects p join public.project_group_chats c on c.project_id=p.id
      where p.attributed_group_id=p_group_id and private.can_read_message_conversation('project_chat',c.id,actor)
    )) then raise sqlstate '42501' using message='The Group Project conversations are unavailable.'; end if;
  select coalesce(jsonb_agg(to_jsonb(page) order by page.activity_at desc,page.chat_id desc),'[]') into result from (
    select 'project_chat'::text item_kind,c.id chat_id,
      greatest(c.activated_at,coalesce(m.created_at,c.activated_at),coalesce(e.created_at,c.activated_at)) activity_at,
      coalesce(proposal.title,recurring.title) display_title,
      case when p.creator_profile_id=actor then 'creator'
        when exists(select 1 from public.project_delegates d where d.project_id=p.id and d.delegate_profile_id=actor and d.revoked_at is null) then 'delegate'
        when private.profile_has_current_project_membership(p.id,actor) then 'current_member' else 'former_member' end viewer_role,
      not private.profile_has_current_project_chat_entitlement(p.id,actor) is_read_only,
      m.id last_visible_message_id,m.body last_visible_message_body,m.created_at last_visible_message_at,
      m.sender_profile_id last_visible_sender_profile_id,m.display_name last_visible_sender_display_name,
      p.id project_id,p.project_kind,
      null::uuid resource_request_id,null::uuid resource_agreement_id,null::uuid resource_listing_id,
      null::uuid resource_counterparty_profile_id,null::text resource_counterparty_display_name,
      null::text agreement_lifecycle,null::timestamptz coordination_closed_at,
      null::uuid project_request_id,null::uuid project_request_project_id,null::text project_request_project_kind,
      null::text project_request_project_title,null::uuid project_request_counterparty_profile_id,
      null::text project_request_counterparty_display_name,null::text project_request_status,
      null::text project_request_message,null::timestamptz project_request_resolved_at,
      null::uuid accepted_project_group_chat_id,null::integer pending_count,
      coalesce(u.unread_count,0) unread_count,null::text latest_request_activity_status,
      case when m.created_at is null or e.created_at>m.created_at then e.label end latest_group_system_event_label,
      case when public.can_read_public_cover_image_object(cover.object_path) then cover.object_path end group_cover_object_path
    from public.projects p join public.project_group_chats c on c.project_id=p.id
    left join public.proposals proposal on proposal.id=p.id and p.project_kind='one_time'
    left join public.recurring_activities recurring on recurring.id=p.id and p.project_kind='recurring'
    left join public.project_covers cover on cover.project_id=p.id
    left join private.own_message_unread(actor) u on u.conversation_kind='project_chat' and u.chat_id=c.id
    left join lateral (
      select msg.id,msg.body,msg.created_at,msg.sender_profile_id,sender.display_name
      from public.project_chat_messages msg join public.profiles sender on sender.id=msg.sender_profile_id
      where msg.chat_id=c.id and private.profile_can_read_project_chat_message(p.id,actor,msg.created_at)
      order by msg.created_at desc,msg.id desc limit 1
    ) m on true
    left join lateral (
      select event.created_at,case event.requirement_kind when 'skill' then skill.label when 'resource' then need.title end label
      from public.project_chat_system_events event
      left join public.skills skill on skill.id=event.skill_id
      left join public.project_resource_needs need on need.id=event.resource_need_id
      where event.chat_id=c.id and private.profile_can_read_project_chat_message(p.id,actor,event.created_at)
      order by event.created_at desc,event.id desc limit 1
    ) e on true
    where p.attributed_group_id=p_group_id and private.can_read_message_conversation('project_chat',c.id,actor)
      and (p_before_id is null or (greatest(c.activated_at,coalesce(m.created_at,c.activated_at),coalesce(e.created_at,c.activated_at)),c.id)<(p_before_activity_at,p_before_id))
    order by activity_at desc,c.id desc limit p_limit
  ) page;
  return result;
end; $$;

revoke all on function public.get_group_discussion_link_v2(uuid,uuid,uuid,uuid),
  public.list_group_discussion_links_v2(uuid,uuid,uuid,integer,timestamptz,uuid),
  public.add_group_discussion_link_v2(uuid,uuid,uuid,uuid,text,text),
  public.update_group_discussion_link_v2(uuid,uuid,uuid,uuid,uuid,bigint,text,text),
  public.remove_group_discussion_link_v2(uuid,uuid,uuid,uuid,uuid,bigint),
  public.list_own_group_project_chat_folders(uuid,uuid[]),
  public.list_group_project_conversations(uuid,uuid,integer,timestamptz,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_group_discussion_link_v2(uuid,uuid,uuid,uuid),
  public.list_group_discussion_links_v2(uuid,uuid,uuid,integer,timestamptz,uuid),
  public.add_group_discussion_link_v2(uuid,uuid,uuid,uuid,text,text),
  public.update_group_discussion_link_v2(uuid,uuid,uuid,uuid,uuid,bigint,text,text),
  public.remove_group_discussion_link_v2(uuid,uuid,uuid,uuid,uuid,bigint),
  public.list_own_group_project_chat_folders(uuid,uuid[]),
  public.list_group_project_conversations(uuid,uuid,integer,timestamptz,uuid)
  to authenticated;
comment on table private.group_discussion_links is 'Private named HTTPS collection: General is Group-wide, each Idea independent. Current access required, all current links visible, former history grants no mutable collection. Immutable provenance, CAS and soft removal.';

-- One header per Group, including Project-only actors. Compose both domains
-- before pagination; can_read_ideas prevents an unauthorized planning request.
create or replace function public.list_my_discussion_groups_v2(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  with idea_groups as (
    select r.group_id,count(*) room_count,sum(private.group_discussion_unread_count(r.id,actor)) unread_count
    from private.group_discussions r where private.group_discussion_summary_v2(r.id,actor) is not null
    group by r.group_id
  ), project_groups as (
    select p.attributed_group_id group_id,count(*) room_count,coalesce(sum(u.unread_count),0) unread_count
    from public.projects p join public.project_group_chats c on c.project_id=p.id
    left join private.own_message_unread(actor) u on u.conversation_kind='project_chat' and u.chat_id=c.id
    where p.attributed_group_id is not null and private.group_discussion_group_available(p.attributed_group_id)
      and private.can_read_message_conversation('project_chat',c.id,actor)
    group by p.attributed_group_id
  )
  select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.group_id desc),'[]') into result from (
    select g.id group_id,g.name,g.created_at,i.group_id is not null can_read_ideas,
      coalesce(i.room_count,0)+coalesce(p.room_count,0) room_count,
      coalesce(i.unread_count,0)+coalesce(p.unread_count,0) unread_count
    from private.community_groups g left join idea_groups i on i.group_id=g.id left join project_groups p on p.group_id=g.id
    where (i.group_id is not null or p.group_id is not null)
      and (p_before_id is null or (g.created_at,g.id)<(p_before_created_at,p_before_id))
    order by g.created_at desc,g.id desc limit p_limit
  ) page;
  return result;
end; $$;
