-- C-R05/R06. Private origin, actual-author drafts and opt-in public invitations.
-- Core C-R01/R02 owns the source access/history and frozen_at send boundary.
create table private.group_discussion_conversions (
  room_id uuid primary key references private.group_discussions(id),
  proposed_by uuid not null,
  title text not null check(title=btrim(title) and char_length(title) between 1 and 120),
  summary text not null check(summary=btrim(summary) and char_length(summary) between 1 and 280),
  version bigint not null default 1 check(version>0),
  review_status text not null default 'pending' check(review_status in ('pending','endorsed','changes_requested')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  project_id uuid unique,
  publisher_id uuid,
  published_at timestamptz,
  frozen_sequence bigint,
  created_at timestamptz not null default clock_timestamp(),
  check((project_id is null)=(publisher_id is null)),
  check((published_at is null)=(frozen_sequence is null))
);
create table private.group_discussion_project_invitations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references private.group_discussion_conversions(room_id),
  project_id uuid not null,
  recipient_id uuid not null,
  publisher_id uuid not null,
  status text not null default 'pending' check(status in ('pending','opened','declined')),
  created_at timestamptz not null default clock_timestamp(),
  unique(room_id,recipient_id)
);
create index discussion_project_invitation_actor_page on private.group_discussion_project_invitations(recipient_id,created_at desc,id desc);
create table private.group_discussion_conversion_receipts (
  actor_id uuid not null, request_id uuid not null, intent jsonb not null,
  result jsonb not null, primary key(actor_id,request_id)
);
alter table private.group_discussion_conversions enable row level security;
alter table private.group_discussion_project_invitations enable row level security;
alter table private.group_discussion_conversion_receipts enable row level security;
revoke all on private.group_discussion_conversions,private.group_discussion_project_invitations,private.group_discussion_conversion_receipts from public,anon,authenticated,service_role;
create trigger discussion_conversion_receipts_immutable before update or delete on private.group_discussion_conversion_receipts
  for each row execute function private.protect_moderation_append_only();
create trigger discussion_project_invitation_provenance before update on private.group_discussion_project_invitations
  for each row execute function private.protect_group_relationship_provenance('status');

create function private.protect_discussion_conversion() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='DELETE' or row(new.room_id,new.proposed_by,new.created_at) is distinct from row(old.room_id,old.proposed_by,old.created_at)
    or old.project_id is not null and row(new.project_id,new.publisher_id,new.title,new.summary) is distinct from row(old.project_id,old.publisher_id,old.title,old.summary)
    or old.published_at is not null then
    raise sqlstate '22023' using message='The conversion origin and published boundary are immutable.';
  end if;
  return new;
end; $$;
create trigger discussion_conversion_provenance before update or delete on private.group_discussion_conversions
  for each row execute function private.protect_discussion_conversion();

-- No draft ID/title is disclosed to another manager. They review only the
-- original explicit proposal; the bound editor remains its real author's.
create function public.get_group_discussion_conversion(p_expected_profile_id uuid,p_room_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
  room private.group_discussions%rowtype; conversion private.group_discussion_conversions%rowtype;
  frontier bigint; current_access boolean; role text; result jsonb;
begin
  frontier:=private.group_discussion_history_frontier(p_room_id,actor);
  if frontier is null then raise sqlstate '42501' using message='The planning source is unavailable.'; end if;
  select * into room from private.group_discussions where id=p_room_id;
  current_access:=private.group_discussion_current_access(p_room_id,actor) is not null;
  role:=private.group_authority_role(room.group_id,actor);
  result:=jsonb_build_object('profile_id',actor,'room_id',p_room_id,'can_propose',current_access and room.kind='idea' and room.creator_id=actor and private.group_discussion_admission(p_room_id,actor) is not null and room.frozen_at is null and not room.archived,
    'can_review',current_access and role is not null and room.frozen_at is null and not room.archived,
    'can_publish',current_access and coalesce(role in ('creator','co_creator'),false) and room.frozen_at is null and not room.archived);
  select * into conversion from private.group_discussion_conversions where room_id=p_room_id;
  if not found or (not current_access and (conversion.published_at is null or conversion.frozen_sequence>frontier)) then
    return result||jsonb_build_object('state','none');
  end if;
  return result||jsonb_build_object('state',case when conversion.published_at is not null then 'published' when conversion.project_id is not null then 'draft' else 'proposed' end,
    'version',conversion.version,'title',conversion.title,'summary',conversion.summary,'proposed_by',conversion.proposed_by,
    'review_status',conversion.review_status,'reviewed_by',conversion.reviewed_by,
    'project_id',case when conversion.published_at is not null or conversion.publisher_id=actor then conversion.project_id end,
    'publisher_id',conversion.publisher_id,'published_at',conversion.published_at,'frozen_sequence',conversion.frozen_sequence,
    'can_open_draft',conversion.publisher_id=actor and conversion.published_at is null,
    'can_open_project_chat',conversion.published_at is not null and exists(select 1 from public.project_group_chats c where c.project_id=conversion.project_id)
      and private.profile_has_project_chat_history_entitlement(conversion.project_id,actor),
    'project_chat_id',case when conversion.published_at is not null and private.profile_has_project_chat_history_entitlement(conversion.project_id,actor)
      then (select id from public.project_group_chats where project_id=conversion.project_id) end,
    'can_share_links',conversion.published_at is not null and current_access and private.profile_is_project_manager(conversion.project_id,actor));
end; $$;

create function public.request_group_discussion_publication(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_title text,p_summary text,p_expected_version bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); room private.group_discussions%rowtype;
  conversion private.group_discussion_conversions%rowtype; receipt private.group_discussion_conversion_receipts%rowtype;
  intent jsonb:=jsonb_build_array('propose',p_room_id,p_title,p_summary,p_expected_version); result jsonb;
begin
  if p_client_request_id is null or p_title is null or p_title<>btrim(p_title) or char_length(p_title) not between 1 and 120
    or p_summary is null or p_summary<>btrim(p_summary) or char_length(p_summary) not between 1 and 280 then
    raise sqlstate '22023' using message='A reviewed title and summary are required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('discussion-conversion:'||actor::text||':'||p_client_request_id::text,0));
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room_id) for update;
  select * into room from private.group_discussions where id=p_room_id for update;
  perform private.require_group_actor(actor);
  if room.id is null or room.kind<>'idea' or room.creator_id<>actor or private.group_discussion_admission(p_room_id,actor) is null then
    raise sqlstate '42501' using message='Only the current Idea Creator can request publication.'; end if;
  select * into receipt from private.group_discussion_conversion_receipts where actor_id=actor and request_id=p_client_request_id;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The conversion request identity was reused.'; end if;
    return receipt.result;
  end if;
  if room.archived or room.frozen_at is not null then raise sqlstate '55000' using message='The planning source is read-only.'; end if;
  select * into conversion from private.group_discussion_conversions where room_id=p_room_id;
  if found then
    if conversion.project_id is not null or conversion.version is distinct from p_expected_version then
      raise sqlstate 'PT409' using message='The publication proposal changed. Reload it.'; end if;
    update private.group_discussion_conversions set title=p_title,summary=p_summary,version=version+1,
      review_status='pending',reviewed_by=null,reviewed_at=null where room_id=p_room_id returning * into conversion;
  else
    if p_expected_version is not null then raise sqlstate 'PT409' using message='The publication proposal changed. Reload it.'; end if;
    insert into private.group_discussion_conversions(room_id,proposed_by,title,summary) values(p_room_id,actor,p_title,p_summary) returning * into conversion;
  end if;
  result:=jsonb_build_object('room_id',p_room_id,'version',conversion.version);
  insert into private.group_discussion_conversion_receipts values(actor,p_client_request_id,intent,result);
  perform private.emit_group_discussion_event(p_room_id,'conversion_proposed',actor,null,p_client_request_id);
  return result;
end; $$;

create function public.review_group_discussion_publication(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_version bigint,p_endorse boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); room private.group_discussions%rowtype;
  conversion private.group_discussion_conversions%rowtype; receipt private.group_discussion_conversion_receipts%rowtype;
  intent jsonb:=jsonb_build_array('review',p_room_id,p_expected_version,p_endorse); result jsonb;
begin
  if p_client_request_id is null or p_endorse is null or p_expected_version is null then raise sqlstate '22023' using message='A review decision is required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('discussion-conversion:'||actor::text||':'||p_client_request_id::text,0));
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room_id) for update;
  select * into room from private.group_discussions where id=p_room_id for update;
  perform private.require_group_actor(actor);
  if room.id is null or not private.group_discussion_group_available(room.group_id) or private.group_authority_role(room.group_id,actor) is null then
    raise sqlstate '42501' using message='A current Group manager must review the proposal.'; end if;
  select * into receipt from private.group_discussion_conversion_receipts where actor_id=actor and request_id=p_client_request_id;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The conversion request identity was reused.'; end if;
    return receipt.result;
  end if;
  select * into conversion from private.group_discussion_conversions where room_id=p_room_id;
  if room.archived or room.frozen_at is not null or conversion.project_id is not null or conversion.version is distinct from p_expected_version then
    raise sqlstate 'PT409' using message='The publication proposal changed. Reload it.'; end if;
  update private.group_discussion_conversions set review_status=case when p_endorse then 'endorsed' else 'changes_requested' end,
    reviewed_by=actor,reviewed_at=clock_timestamp(),version=version+1 where room_id=p_room_id returning * into conversion;
  result:=jsonb_build_object('room_id',p_room_id,'version',conversion.version);
  insert into private.group_discussion_conversion_receipts values(actor,p_client_request_id,intent,result);
  perform private.group_discussion_signal(conversion.proposed_by);
  return result;
end; $$;

-- Taking responsibility creates a meaningful sparse private draft. This is an
-- explicit command, never an effect of opening the editor or reviewing a row.
create function public.create_group_discussion_project_draft(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_version bigint) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); room private.group_discussions%rowtype;
  conversion private.group_discussion_conversions%rowtype; receipt private.group_discussion_conversion_receipts%rowtype;
  intent jsonb:=jsonb_build_array('draft',p_room_id,p_expected_version); destination uuid;
begin
  if p_client_request_id is null or p_expected_version is null then raise sqlstate '22023' using message='A publication proposal and request identity are required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('discussion-conversion:'||actor::text||':'||p_client_request_id::text,0));
  -- Acquire the legacy draft namespace before Group, never vice versa.
  perform pg_advisory_xact_lock(hashtextextended('proposal.draft_create:'||actor::text||':'||p_client_request_id::text,0));
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room_id) for update;
  select * into room from private.group_discussions where id=p_room_id for update;
  perform private.require_group_actor(actor);
  if room.id is null then raise sqlstate '42501' using message='The planning source is unavailable.'; end if;
  select * into receipt from private.group_discussion_conversion_receipts where actor_id=actor and request_id=p_client_request_id;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The conversion request identity was reused.'; end if;
    -- Recovery identifies only the caller's own accepted draft, even after role
    -- loss. It never grants editor/publication rights or another manager access.
    return (receipt.result->>'project_id')::uuid;
  end if;
  perform private.require_project_group_representation(actor,room.group_id);
  select * into conversion from private.group_discussion_conversions where room_id=p_room_id;
  if room.kind<>'idea' or room.archived or room.frozen_at is not null or conversion.version is distinct from p_expected_version then
    raise sqlstate 'PT409' using message='The publication proposal changed. Reload it.'; end if;
  if conversion.project_id is not null then
    raise sqlstate 'PT409' using message='This Idea is already bound to its actual publisher''s private draft. That author must continue it.',detail='conversion_draft_owned';
  end if;
  if conversion.review_status='changes_requested' then raise sqlstate 'PT409' using message='The Idea Creator must revise the proposal before publication.'; end if;
  if exists(select 1 from private.proposal_draft_creations where creator_profile_id=actor and client_request_id=p_client_request_id) then
    raise sqlstate '22023' using message='This request already belongs to another draft intent.'; end if;
  destination:=public.create_group_editor_proposal_draft(actor,p_client_request_id,conversion.title,conversion.summary,
    null,null,null,'Europe/Rome',null,null,null,null,null,'participants',array[]::uuid[],array[]::text[],null,false,room.group_id);
  update private.group_discussion_conversions set project_id=destination,publisher_id=actor,
    review_status='endorsed',reviewed_by=actor,reviewed_at=clock_timestamp(),version=version+1 where room_id=p_room_id;
  insert into private.group_discussion_conversion_receipts values(actor,p_client_request_id,intent,jsonb_build_object('project_id',destination));
  perform private.group_discussion_signal(conversion.proposed_by);
  return destination;
end; $$;

-- AFTER GRP03C's zz_* trigger: source -> Project -> Group -> room. The same
-- transaction covers legacy publish RPCs, so no caller can publish personally,
-- switch Group, freeze without publication, or race a send past the boundary.
create function private.freeze_group_discussion_publication() returns trigger
language plpgsql security definer set search_path='' as $$
declare conversion private.group_discussion_conversions%rowtype; room private.group_discussions%rowtype;
  project public.projects%rowtype; recipient record;
begin
  if new.published_at is null or (tg_op='UPDATE' and old.published_at is not null) then return new; end if;
  select * into conversion from private.group_discussion_conversions where project_id=new.id;
  if not found then return new; end if;
  select * into project from public.projects where id=new.id for update;
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=conversion.room_id) for update;
  select * into room from private.group_discussions where id=conversion.room_id for update;
  select * into conversion from private.group_discussion_conversions where room_id=room.id for update;
  if conversion.published_at is not null or room.frozen_at is not null or room.archived or room.kind<>'idea'
    or project.creator_profile_id<>conversion.publisher_id or auth.uid() is distinct from conversion.publisher_id
    or project.attributed_group_id is distinct from room.group_id or not private.group_discussion_group_available(room.group_id) then
    raise sqlstate 'PT409' using message='The conversion source or publisher changed. Reload before publishing.';
  end if;
  perform private.require_project_group_representation(conversion.publisher_id,room.group_id);
  -- The marker has its own committed ordinal, preventing a person who exited
  -- immediately before conversion from receiving a later origin association.
  update private.group_discussions set frozen_at=new.published_at,version=version+1,last_sequence=last_sequence+1 where id=room.id returning * into room;
  update private.group_discussion_conversions set published_at=new.published_at,frozen_sequence=room.last_sequence,version=version+1 where room_id=room.id;
  -- A stable durable audience of current explicit planners, not Group people or
  -- oversight-only managers. No Project membership, capacity or role is written.
  for recipient in insert into private.group_discussion_project_invitations(room_id,project_id,recipient_id,publisher_id)
    select room.id,new.id,a.profile_id,conversion.publisher_id from private.group_discussion_admissions a
      where a.room_id=room.id and a.id=private.group_discussion_admission(room.id,a.profile_id)
        and a.profile_id<>conversion.publisher_id
        and not private.profile_has_current_project_membership(new.id,a.profile_id)
        and not private.has_active_user_block_between(conversion.publisher_id,a.profile_id)
      on conflict(room_id,recipient_id) do nothing returning id,recipient_id
  loop
    perform private.emit_group_discussion_event(room.id,'project_invitation',conversion.publisher_id,recipient.recipient_id,recipient.id);
    perform private.group_discussion_signal(recipient.recipient_id);
  end loop;
  perform private.emit_group_discussion_event(room.id,'converted',conversion.publisher_id,null,new.id);
  return new;
end; $$;
create trigger zzz_proposals_freeze_discussion_publication after insert or update on public.proposals
  for each row execute function private.freeze_group_discussion_publication();

-- This public-Project invitation projection deliberately contains no source
-- room identity/title/URL/roster. Group exit cannot turn it into a private route.
create function public.list_my_discussion_project_invitations(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc,q.invitation_id desc),'[]'::jsonb) into result from (
    select i.id invitation_id,i.project_id,i.status,i.created_at,p.title,p.summary
    from private.group_discussion_project_invitations i join public.proposals p on p.id=i.project_id
    where i.recipient_id=actor and i.status<>'declined' and private.is_project_publicly_viewable(p.id)
      and not private.has_active_user_block_between(i.publisher_id,actor)
      and not private.profile_has_current_project_membership(i.project_id,actor)
      and (p_before_created_at is null or (i.created_at,i.id)<(p_before_created_at,p_before_id))
    order by i.created_at desc,i.id desc limit p_limit
  ) q;
  return result;
end; $$;
create function public.respond_discussion_project_invitation(p_expected_profile_id uuid,p_invitation_id uuid,p_response text) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); invitation private.group_discussion_project_invitations%rowtype;
begin
  if p_response is null or p_response not in ('opened','declined') then raise sqlstate '22023' using message='A Project invitation response is required.'; end if;
  select * into invitation from private.group_discussion_project_invitations where id=p_invitation_id and recipient_id=actor for update;
  perform private.require_group_identity(actor);
  if not found or invitation.id is null then raise sqlstate '42501' using message='The Project invitation is unavailable.'; end if;
  if invitation.status=p_response then return invitation.project_id; end if;
  if invitation.status='declined' then raise sqlstate 'PT409' using message='The Project invitation was declined.'; end if;
  if p_response='opened' and (private.has_active_user_block_between(invitation.publisher_id,actor)
    or not private.is_project_publicly_viewable(invitation.project_id)) then
    raise sqlstate '42501' using message='The Project invitation is unavailable.'; end if;
  update private.group_discussion_project_invitations set status=p_response where id=invitation.id;
  perform private.group_discussion_signal(actor);
  return invitation.project_id;
end; $$;

-- Project-only users get null, including no usable source route. Both checks
-- run on the server before any private origin field is constructed.
create function public.get_project_discussion_origin(p_expected_profile_id uuid,p_project_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); conversion private.group_discussion_conversions%rowtype; frontier bigint;
begin
  if not private.profile_has_project_chat_history_entitlement(p_project_id,actor) then return null; end if;
  select * into conversion from private.group_discussion_conversions where project_id=p_project_id and published_at is not null;
  if not found then return null; end if;
  frontier:=private.group_discussion_history_frontier(conversion.room_id,actor);
  if frontier is null or frontier<conversion.frozen_sequence then return null; end if;
  return jsonb_build_object('profile_id',actor,'project_id',p_project_id,'room_id',conversion.room_id,'published_at',conversion.published_at,'frozen_sequence',conversion.frozen_sequence);
end; $$;

-- Deliberate selected-link sharing uses the canonical Project Add receipt and
-- C's exact current-access/version check. Nothing copies automatically.
create function public.share_discussion_link_to_project(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_project_id uuid,p_expected_access_id uuid,p_link_id uuid,p_expected_version bigint) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); room private.group_discussions%rowtype;
  link private.group_discussion_links%rowtype; receipt private.group_discussion_conversion_receipts%rowtype;
  intent jsonb:=jsonb_build_array('share-link',p_room_id,p_project_id,p_expected_access_id,p_link_id,p_expected_version); destination uuid;
begin
  if p_client_request_id is null or p_expected_access_id is null or p_expected_version is null then raise sqlstate '22023' using message='A reviewed source link and destination are required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('discussion-conversion:'||actor::text||':'||p_client_request_id::text,0));
  perform private.require_project_workspace_manager(actor,p_project_id);
  perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room_id) for update;
  select * into room from private.group_discussions where id=p_room_id for update;
  perform private.require_group_actor(actor);
  if private.require_group_discussion_access(p_room_id,actor)<>p_expected_access_id
    or not exists(select 1 from private.group_discussion_conversions where room_id=p_room_id and project_id=p_project_id and published_at is not null) then
    raise sqlstate '42501' using message='The source link or Project destination is unavailable.'; end if;
  select * into receipt from private.group_discussion_conversion_receipts where actor_id=actor and request_id=p_client_request_id;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The conversion request identity was reused.'; end if;
    return (receipt.result->>'link_id')::uuid;
  end if;
  select * into link from private.group_discussion_links where id=p_link_id and room_id=p_room_id and removed_at is null;
  if not found then raise sqlstate '42501' using message='The source link is unavailable.'; end if;
  if link.version<>p_expected_version then raise sqlstate 'PT409' using message='The source link changed. Review it again.'; end if;
  destination:=public.save_project_workspace_link(actor,p_project_id,link.display_name,link.destination,null,p_client_request_id,null);
  insert into private.group_discussion_conversion_receipts values(actor,p_client_request_id,intent,jsonb_build_object('link_id',destination));
  return destination;
end; $$;

revoke all on function private.protect_discussion_conversion(),private.freeze_group_discussion_publication() from public,anon,authenticated,service_role;
revoke all on function public.get_group_discussion_conversion(uuid,uuid),public.request_group_discussion_publication(uuid,uuid,uuid,text,text,bigint),public.review_group_discussion_publication(uuid,uuid,uuid,bigint,boolean),public.create_group_discussion_project_draft(uuid,uuid,uuid,bigint),public.list_my_discussion_project_invitations(uuid,integer,timestamptz,uuid),public.respond_discussion_project_invitation(uuid,uuid,text),public.get_project_discussion_origin(uuid,uuid),public.share_discussion_link_to_project(uuid,uuid,uuid,uuid,uuid,uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function public.get_group_discussion_conversion(uuid,uuid),public.request_group_discussion_publication(uuid,uuid,uuid,text,text,bigint),public.review_group_discussion_publication(uuid,uuid,uuid,bigint,boolean),public.create_group_discussion_project_draft(uuid,uuid,uuid,bigint),public.list_my_discussion_project_invitations(uuid,integer,timestamptz,uuid),public.respond_discussion_project_invitation(uuid,uuid,text),public.get_project_discussion_origin(uuid,uuid),public.share_discussion_link_to_project(uuid,uuid,uuid,uuid,uuid,uuid,bigint) to authenticated;
comment on table private.group_discussion_conversions is 'Private stable planning origin. A bound draft belongs solely to its actual publisher; role loss never transfers it. Publication freezes source ordinal transactionally.';
comment on table private.group_discussion_project_invitations is 'Option A: public Project detail invitation only. Opened is not accepted participation; ordinary Join remains required. No admission/capacity/role effects.';
