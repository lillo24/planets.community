-- D02: references, never conversion or audience copying. The experimental
-- authorization default is the post author AND current numbered creator.
create table private.cocreate_post_groups (
 post_id uuid primary key references private.cocreate_posts(id),room_id uuid not null references private.cocreate_rooms(id),
 linked_by uuid not null,linked_at timestamptz not null default clock_timestamp()
);
create table private.cocreate_project_sources (
 proposal_id uuid primary key references public.proposals(id) on delete cascade,
 room_id uuid not null references private.cocreate_rooms(id),creator_id uuid not null,
 created_at timestamptz not null default clock_timestamp()
);
create index cocreate_post_group_room on private.cocreate_post_groups(room_id,post_id);
create index cocreate_project_source_room on private.cocreate_project_sources(room_id,created_at desc,proposal_id desc);
alter table private.cocreate_post_groups enable row level security;
alter table private.cocreate_project_sources enable row level security;
revoke all on private.cocreate_post_groups,private.cocreate_project_sources from public,anon,authenticated,service_role;

create function private.cocreate_post_group_signal(p_room uuid) returns void
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 for person in select p.author_id from private.cocreate_post_groups s join private.cocreate_posts p on p.id=s.post_id where s.room_id=p_room
  union select c.requester_id from private.cocreate_post_groups s join private.cocreate_contacts c on c.post_id=s.post_id where s.room_id=p_room
 loop perform private.cocreate_signal(person);end loop;
end; $$;
create function private.cocreate_source_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='cocreate_rooms' then perform private.cocreate_post_group_signal(new.id);
 else perform private.cocreate_post_group_signal(new.room_id);end if;
 return null;
end; $$;
create trigger cocreate_source_capacity_signal after update of capacity,archived,suppressed on private.cocreate_rooms
 for each row execute function private.cocreate_source_change_signal();
create trigger cocreate_source_seat_signal after insert or update of ended_at on private.cocreate_room_episodes
 for each row execute function private.cocreate_source_change_signal();

create function private.cocreate_linked_group(p_post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare room uuid;result jsonb;
begin
 select room_id into room from private.cocreate_post_groups where post_id=p_post;
 if not found then return null;end if;
 if not private.cocreate_numbered_public(room) then return jsonb_build_object('state','unavailable');end if;
 select jsonb_build_object('state','available','group',private.cocreate_numbered_projection(r.id),
  'topic_label',t.label,'locality',h.locality) into result
 from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id join private.cocreate_topics t on t.id=h.topic_id where r.id=room;
 return result;
end; $$;
create function public.get_own_cocreate_post_link(p_expected_profile_id uuid,p_post_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);result jsonb;
begin
 select jsonb_build_object('profile_id',actor,'post_id',id,'version',version,'title',title,'link',private.cocreate_linked_group(id)) into result
 from private.cocreate_posts where id=p_post_id and author_id=actor;
 if result is null then raise sqlstate '42501' using message='Only this post author manages its source reference.';end if;
 return result;
end; $$;
create function public.get_cocreate_contact_group(p_expected_profile_id uuid,p_contact_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 contact private.cocreate_contacts:=private.require_cocreate_contact(p_contact_id,actor);
begin
 -- A closed/withdrawn contact has history, but no continuing join invitation.
 if contact.closed_at is not null or not exists(select 1 from private.cocreate_interests
  where post_id=contact.post_id and requester_id=contact.requester_id and state='accepted') then
  return jsonb_build_object('profile_id',actor,'contact_id',contact.id,'link',null);end if;
 return jsonb_build_object('profile_id',actor,'contact_id',contact.id,'link',private.cocreate_linked_group(contact.post_id));
end; $$;
create function public.list_own_cocreate_manageable_groups(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_joined_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_joined_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(p) order by p.joined_at desc,p.episode_id desc),'[]'::jsonb) from (
  select r.id room_id,r.hub_id,t.label topic_label,h.locality,e.id episode_id,false closed,e.muted,e.joined_at,
   private.cocreate_room_unread(e) unread_count,r.kind,r.group_number number
  from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id join private.cocreate_topics t on t.id=h.topic_id
   join private.cocreate_room_episodes e on e.room_id=r.id and e.actor_id=actor and e.ended_at is null
  where r.kind='numbered' and r.manager_id=actor and private.cocreate_numbered_public(r.id) and private.cocreate_hub_member(h.id,actor)
   and (p_before_id is null or (e.joined_at,e.id)<(p_before_joined_at,p_before_id))
  order by e.joined_at desc,e.id desc limit p_limit)p);
end; $$;
create function public.mutate_cocreate_post_group(p_expected_profile_id uuid,p_command_id uuid,p_post_id uuid,
 p_expected_version bigint,p_operation text,p_hub_id uuid default null,p_room_id uuid default null,p_episode_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);post private.cocreate_posts;
 prior private.cocreate_room_receipts;intent text;result jsonb;
begin
 if p_command_id is null or p_post_id is null or p_expected_version is null or p_expected_version<1
  or p_operation is null or p_operation not in('link','clear')
  or (p_operation='link')<>(p_hub_id is not null) or (p_operation='link')<>(p_room_id is not null)
  or (p_operation='link')<>(p_episode_id is not null) then raise sqlstate '22023' using message='Invalid post source command.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.post.actor:'||actor::text,0));
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 if p_operation='link' then perform private.cocreate_lock_hub(p_hub_id);end if;
 select * into post from private.cocreate_posts where id=p_post_id and author_id=actor for update;
 if not found then raise sqlstate '42501' using message='Only this post author manages its source reference.';end if;
 intent:=private.group_command_hash(jsonb_build_array('post_group',p_post_id,p_expected_version,p_operation,p_hub_id,p_room_id,p_episode_id));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The post source command intent differs.';end if;
  return prior.result;
 end if;
 if post.version<>p_expected_version then raise sqlstate 'PT409' using message='Review the current post version before linking.';end if;
 if p_operation='link' then
  perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
  if post.suppressed or not exists(select 1 from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id
   and manager_id=actor and kind='numbered' and private.cocreate_numbered_public(id))
   then raise sqlstate '42501' using message='Only your current numbered group can be linked to this post.';end if;
  insert into private.cocreate_post_groups(post_id,room_id,linked_by) values(post.id,p_room_id,actor)
   on conflict(post_id) do update set room_id=excluded.room_id,linked_by=excluded.linked_by,linked_at=clock_timestamp();
 else delete from private.cocreate_post_groups where post_id=post.id;end if;
 update private.cocreate_posts set version=version+1 where id=post.id returning * into post;
 result:=jsonb_build_object('post_id',post.id,'version',post.version,'operation',p_operation);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;

create function public.create_cocreate_project_draft(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,p_room_id uuid,p_episode_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);prior private.cocreate_room_receipts;
 intent text;result jsonb;destination uuid;
begin
 if p_command_id is null or p_hub_id is null or p_room_id is null or p_episode_id is null then
  raise sqlstate '22023' using message='Invalid personal Project draft command.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.cocreate_lock_hub(p_hub_id);
 intent:=private.group_command_hash(jsonb_build_array('personal_project_draft',p_hub_id,p_room_id,p_episode_id));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The Project draft intent differs.';end if;
  if not exists(select 1 from public.proposals where id=(prior.result->>'proposal_id')::uuid and creator_profile_id=actor)
   then raise sqlstate 'P0002' using message='The recorded personal draft is unavailable.';end if;
  return prior.result;
 end if;
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 if not exists(select 1 from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and kind='numbered' and manager_id=actor
  and private.cocreate_numbered_public(id)) then raise sqlstate '42501' using message='Only this current group creator can start a personal Project draft.';end if;
 -- Ordinary sparse draft, no group text, private locations, roster, capacity or
 -- membership copied. The native editor remains the publication authority.
 if exists(select 1 from private.proposal_draft_creations where creator_profile_id=actor and client_request_id=p_command_id)
  then raise sqlstate '22023' using message='This draft command belongs to an existing native creation intent.';end if;
 destination:=public.create_editor_proposal_draft(actor,p_command_id,null,null,null,null,null,'Europe/Rome',
  null,null,null,null,null,'participants',array[]::uuid[],array[]::text[],null,false);
 insert into private.cocreate_project_sources(proposal_id,room_id,creator_id) values(destination,p_room_id,actor);
 result:=jsonb_build_object('proposal_id',destination,'hub_id',p_hub_id,'room_id',p_room_id);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;
create function public.list_cocreate_group_projects(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid,
 p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 -- Public native reads decide availability. A source reference never exposes a
 -- personal draft to the rest of the group or upgrades native Project rights.
 return (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc,p.proposal_id desc),'[]'::jsonb) from (
  select s.proposal_id,s.created_at from private.cocreate_project_sources s
  where s.room_id=p_room_id and exists(select 1 from public.get_public_proposal(s.proposal_id))
   and (p_before_id is null or (s.created_at,s.proposal_id)<(p_before_created_at,p_before_id))
  order by s.created_at desc,s.proposal_id desc limit p_limit)p);
end; $$;
do $$ declare signature text;begin
 foreach signature in array array[
 'public.get_own_cocreate_post_link(uuid,uuid)', 'public.get_cocreate_contact_group(uuid,uuid)',
 'public.list_own_cocreate_manageable_groups(uuid,integer,timestamptz,uuid)',
 'public.mutate_cocreate_post_group(uuid,uuid,uuid,bigint,text,uuid,uuid,uuid)',
 'public.create_cocreate_project_draft(uuid,uuid,uuid,uuid,uuid)',
 'public.list_cocreate_group_projects(uuid,uuid,uuid,integer,timestamptz,uuid)'] loop
  execute 'revoke all on function '||signature||' from public,anon,authenticated';
  execute 'grant execute on function '||signature||' to authenticated';
 end loop;
end; $$;
revoke all on function private.cocreate_linked_group(uuid) from public,anon,authenticated,service_role;
revoke all on function private.cocreate_post_group_signal(uuid),private.cocreate_source_change_signal() from public,anon,authenticated,service_role;
