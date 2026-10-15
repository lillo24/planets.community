-- Approved PARALLEL-CD-2026-10-15-v1 C revision. Existing rows/IDs are retained.
drop trigger group_discussion_room_provenance on private.group_discussions;
drop trigger group_discussion_admission_provenance on private.group_discussion_admissions;
alter table private.community_groups
  add column idea_creation_policy text not null default 'managers' check(idea_creation_policy in ('managers','members')),
  add column idea_settings_version bigint not null default 1 check(idea_settings_version>0);
alter table private.group_discussions
  add column kind text not null default 'idea' check(kind in ('idea','general')),
  add column visibility text not null default 'invitation' check(visibility in ('group','invitation')),
  add column purpose text not null default '' check(purpose=btrim(purpose) and char_length(purpose)<=500),
  add column frozen_at timestamptz,
  add column last_activity_at timestamptz not null default clock_timestamp(),
  add column invitation_link_version bigint not null default 1;
update private.group_discussions r set last_activity_at=coalesce((select max(m.created_at) from private.group_discussion_messages m where m.room_id=r.id),r.created_at);
create unique index group_discussion_one_general on private.group_discussions(group_id) where kind='general';
alter table private.group_discussions add constraint group_discussion_general_shape check(kind<>'general' or (visibility='group' and not archived and frozen_at is null));
alter table private.group_discussion_admissions add column end_sequence bigint,add column end_snapshot jsonb;
-- Old exited episodes did not retain a safe sequence boundary. Conservatively
-- grant zero history for those historical rows rather than inventing a frontier.
update private.group_discussion_admissions a set end_sequence=0,end_snapshot=jsonb_build_object('title',r.title,'purpose','','visibility','invitation','group_name',g.name,'version',r.version,'archived',r.archived,'frozen',false,'created_at',r.created_at)
from private.group_discussions r join private.community_groups g on g.id=r.group_id where a.room_id=r.id and a.ended_at is not null;
alter table private.group_discussion_invitations alter column inviter_admission_id drop not null;
create table private.group_discussion_views (
  id uuid primary key default gen_random_uuid(), room_id uuid not null references private.group_discussions(id),profile_id uuid not null,
  access_kind text not null check(access_kind in ('general','oversight')),
  read_sequence bigint not null check(read_sequence>=0),observed_sequence bigint not null check(observed_sequence>=0),
  created_at timestamptz not null default clock_timestamp(),ended_at timestamptz,end_sequence bigint,end_snapshot jsonb
);
create unique index group_discussion_current_view on private.group_discussion_views(room_id,profile_id,access_kind) where ended_at is null;
create index group_discussion_actor_views on private.group_discussion_views(profile_id,room_id);
create table private.group_discussion_preferences (
  room_id uuid not null references private.group_discussions(id),profile_id uuid not null,muted boolean not null default false,
  hidden boolean not null default false,primary key(room_id,profile_id)
);
create table private.group_discussion_invitation_links (
  room_id uuid primary key references private.group_discussions(id),token_hash text not null unique,
  issuer_id uuid not null,issued_at timestamptz not null default clock_timestamp(),expires_at timestamptz not null,revoked_at timestamptz
);
create table private.group_discussion_events (
  id uuid primary key default gen_random_uuid(),room_id uuid not null references private.group_discussions(id),event_kind text not null,
  actor_id uuid not null,target_id uuid,object_id uuid,sequence bigint not null,visibility text not null,created_at timestamptz not null default clock_timestamp()
);
create unique index group_discussion_event_once on private.group_discussion_events(room_id,event_kind,object_id,coalesce(target_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index group_discussion_events_page on private.group_discussion_events(created_at desc,id desc);
create table private.group_discussion_notice_reads(profile_id uuid not null,event_id uuid not null references private.group_discussion_events(id),primary key(profile_id,event_id));
create trigger group_discussion_room_provenance before update on private.group_discussions for each row
execute function private.protect_group_relationship_provenance('title','archived','version','last_sequence','purpose','visibility','frozen_at','last_activity_at','invitation_link_version');
create trigger group_discussion_admission_provenance before update on private.group_discussion_admissions for each row
execute function private.protect_group_relationship_provenance('read_sequence','ended_at','ended_by','end_sequence','end_snapshot');
create trigger group_discussion_view_provenance before update on private.group_discussion_views for each row
execute function private.protect_group_relationship_provenance('read_sequence','observed_sequence','ended_at','end_sequence','end_snapshot');
create trigger group_discussion_events_immutable before update or delete on private.group_discussion_events
for each row execute function private.protect_moderation_append_only();

create function private.group_discussion_person_current(p_group uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor)
 and private.group_discussion_group_available(p_group) and private.group_discussion_source(p_group,p_actor) is not null;
$$;
create or replace function private.group_discussion_admission(p_room uuid,p_actor uuid) returns uuid
language sql stable security definer set search_path='' as $$
 select a.id from private.group_discussion_admissions a join private.group_discussions r on r.id=a.room_id
 where a.room_id=p_room and a.profile_id=p_actor and a.ended_at is null
 and private.group_discussion_person_current(r.group_id,p_actor);
$$;
create function private.group_discussion_can_manage(p_room uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select private.group_discussion_person_current(r.group_id,p_actor)
 and (private.group_authority_role(r.group_id,p_actor) is not null or (r.kind='idea' and r.creator_id=p_actor and private.group_discussion_admission(r.id,p_actor) is not null))
 from private.group_discussions r where r.id=p_room),false);
$$;
create function private.group_discussion_can_read_current(p_room uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select private.group_discussion_person_current(r.group_id,p_actor)
 and (r.kind='general' or private.group_authority_role(r.group_id,p_actor) is not null or private.group_discussion_admission(r.id,p_actor) is not null)
 from private.group_discussions r where r.id=p_room),false);
$$;
create function private.group_discussion_current_access(p_room uuid,p_actor uuid) returns uuid
language sql stable security definer set search_path='' as $$
 select coalesce(private.group_discussion_admission(p_room,p_actor),(select v.id from private.group_discussion_views v
 join private.group_discussions r on r.id=v.room_id where v.room_id=p_room and v.profile_id=p_actor and v.ended_at is null
 and private.group_discussion_person_current(r.group_id,p_actor)
 and (v.access_kind='general' and r.kind='general' or v.access_kind='oversight' and private.group_authority_role(r.group_id,p_actor) is not null)
 order by v.created_at desc,v.id desc limit 1));
$$;
create function private.require_group_discussion_access(p_room uuid,p_actor uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare access_id uuid:=private.group_discussion_current_access(p_room,p_actor);
begin if access_id is null then raise sqlstate '42501' using message='The discussion is unavailable.'; end if; return access_id; end;
$$;
create function private.group_discussion_snapshot(p_room uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('title',r.title,'purpose',r.purpose,'visibility',r.visibility,'group_name',g.name,'version',r.version,'archived',r.archived,'frozen',r.frozen_at is not null,'created_at',r.created_at)
 from private.group_discussions r join private.community_groups g on g.id=r.group_id where r.id=p_room;
$$;
create function private.group_discussion_history_frontier(p_room uuid,p_actor uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select case when private.group_discussion_can_read_current(r.id,p_actor) then r.last_sequence else
 (select max(h.frontier) from (select a.end_sequence frontier from private.group_discussion_admissions a where a.room_id=r.id and a.profile_id=p_actor and a.ended_at is not null
 union all select v.end_sequence from private.group_discussion_views v where v.room_id=r.id and v.profile_id=p_actor and v.ended_at is not null) h) end
 from private.group_discussions r where r.id=p_room and private.group_discussion_group_available(r.group_id)
 and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor);
$$;
create function private.ensure_group_discussion_access(p_room uuid,p_actor uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare r private.group_discussions%rowtype; result uuid; scope_kind text;
begin
 perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room) for update;
 select * into r from private.group_discussions where id=p_room for update;
 if not private.group_discussion_can_read_current(p_room,p_actor) then raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
 result:=private.group_discussion_admission(p_room,p_actor);
 if result is not null then return result; end if;
 scope_kind:=case when r.kind='general' then 'general' else 'oversight' end;
 insert into private.group_discussion_views(room_id,profile_id,access_kind,read_sequence,observed_sequence)
 values(p_room,p_actor,scope_kind,r.last_sequence,0)
 on conflict(room_id,profile_id,access_kind) where ended_at is null do update set read_sequence=private.group_discussion_views.read_sequence
 returning id into result;
 return result;
end; $$;

create function private.signal_group_discussion_room(p_room uuid) returns void
language sql security definer set search_path='' as $$
 select realtime.send(jsonb_build_object('group_id',r.group_id),'changed','group-discussions:group:'||r.group_id::text,true)
 from private.group_discussions r where r.id=p_room;
$$;
create or replace function private.group_discussion_topic_allowed(p_topic text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=auth.uid())
 and (p_topic='group-discussions:profile:'||auth.uid()::text or exists(select 1 from private.community_groups g
 where p_topic='group-discussions:group:'||g.id::text and private.group_discussion_person_current(g.id,auth.uid())));
$$;
create function private.group_discussion_unread_count(p_room uuid,p_actor uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select count(*) from private.group_discussion_messages m where m.room_id=p_room and m.sender_id<>p_actor
 and private.group_discussion_can_read_current(p_room,p_actor) and m.sequence>coalesce(
 (select greatest(a.frontier,a.read_sequence) from private.group_discussion_admissions a where a.id=private.group_discussion_admission(p_room,p_actor)),
 (select v.read_sequence from private.group_discussion_views v where v.id=private.group_discussion_current_access(p_room,p_actor)),
 (select r.last_sequence from private.group_discussions r where r.id=p_room));
$$;
create function private.group_discussion_summary_v2(p_room uuid,p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r private.group_discussions%rowtype; g private.community_groups%rowtype; snapshot jsonb; access_id uuid; joined uuid;
 current_read boolean; discover boolean; historical boolean; manager boolean; prefs private.group_discussion_preferences%rowtype;
begin
 select * into r from private.group_discussions where id=p_room;
 select * into g from private.community_groups where id=r.group_id;
 joined:=private.group_discussion_admission(p_room,p_actor); current_read:=private.group_discussion_can_read_current(p_room,p_actor);
 discover:=private.group_discussion_person_current(r.group_id,p_actor) and (r.visibility='group' or current_read);
 historical:=not current_read and private.group_discussion_history_frontier(p_room,p_actor) is not null;
 if not coalesce(discover or current_read or historical,false) then return null; end if;
 access_id:=private.group_discussion_current_access(p_room,p_actor);
 snapshot:=private.group_discussion_snapshot(p_room);
 if historical then
  select h.id,h.snapshot into access_id,snapshot from (
   select a.id,a.end_sequence frontier,a.end_snapshot snapshot,a.ended_at ended from private.group_discussion_admissions a where a.room_id=p_room and a.profile_id=p_actor and a.ended_at is not null
   union all select v.id,v.end_sequence,v.end_snapshot,v.ended_at from private.group_discussion_views v where v.room_id=p_room and v.profile_id=p_actor and v.ended_at is not null
  ) h order by h.frontier desc,h.ended desc,h.id desc limit 1;
 end if;
 select * into prefs from private.group_discussion_preferences where room_id=p_room and profile_id=p_actor;
 manager:=private.group_discussion_can_manage(p_room,p_actor);
 return jsonb_build_object('kind','group_discussion','room_id',r.id,'group_id',r.group_id,'group_name',snapshot->>'group_name',
  'title',snapshot->>'title','purpose',coalesce(snapshot->>'purpose',''),'room_kind',r.kind,'visibility',coalesce(snapshot->>'visibility',r.visibility),'creator_id',r.creator_id,
  'created_at',r.created_at,'version',(snapshot->>'version')::bigint,'archived',(snapshot->>'archived')::boolean,
  'admission_id',joined,'access_id',access_id,'access',case when joined is not null then 'joined' when current_read and r.kind='general' then 'general' when current_read then 'oversight' when historical then 'former' else 'discoverable' end,
  'can_join',private.group_discussion_person_current(r.group_id,p_actor) and r.kind='idea' and joined is null and not r.archived and r.frozen_at is null and (r.visibility='group' or private.group_authority_role(r.group_id,p_actor) is not null),
  'can_send',current_read and not r.archived and r.frozen_at is null,'can_manage',manager and r.frozen_at is null,
  'can_invite',current_read and not r.archived and r.frozen_at is null and r.kind='idea' and (manager or r.visibility='group' and joined is not null),
  'can_read_links',current_read,'can_publish',manager and r.kind='idea' and not r.archived and r.frozen_at is null and coalesce(private.group_authority_role(r.group_id,p_actor) in ('creator','co_creator'),false),
  'frozen',case when historical then coalesce((snapshot->>'frozen')::boolean,false) else r.frozen_at is not null end,'muted',coalesce(prefs.muted,false),'manually_hidden',coalesce(prefs.hidden,false),
  'automatically_hidden',r.kind='idea' and not historical and r.last_activity_at<=statement_timestamp()-interval '7 days',
  'invitation_link_version',case when historical then 1 else r.invitation_link_version end,
  'unread_count',case when current_read then private.group_discussion_unread_count(p_room,p_actor) else 0 end,
  'preview',case when current_read then (select m.body from private.group_discussion_messages m where m.room_id=p_room order by sequence desc limit 1) end);
end; $$;
create function public.get_group_discussion_v2(p_expected_profile_id uuid,p_room_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
 if private.group_discussion_can_read_current(p_room_id,actor) then perform private.ensure_group_discussion_access(p_room_id,actor); end if;
 result:=private.group_discussion_summary_v2(p_room_id,actor);
 if result is null then raise sqlstate '42501' using message='The discussion is unavailable.'; end if; return result;
end; $$;
create function public.list_group_discussions_v2(p_expected_profile_id uuid,p_group_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null,p_hidden boolean default false) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb; cursor_general boolean:=false;
begin
 perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
 if not private.group_discussion_group_available(p_group_id) or (not private.group_discussion_person_current(p_group_id,actor) and not exists(
  select 1 from private.group_discussions r where r.group_id=p_group_id and private.group_discussion_history_frontier(r.id,actor) is not null)) then
  raise sqlstate '42501' using message='The discussions are unavailable.'; end if;
 if p_before_id is not null then select r.kind='general' into cursor_general from private.group_discussions r where r.id=p_before_id and r.group_id=p_group_id;
  if cursor_general is null then raise sqlstate '22023' using message='The discussion cursor is invalid.'; end if; end if;
 select coalesce(jsonb_agg(page.summary order by page.is_general desc,page.created_at desc,page.id desc),'[]') into result from (
  select r.id,r.created_at,r.kind='general' is_general,s.summary from private.group_discussions r
  cross join lateral (select private.group_discussion_summary_v2(r.id,actor) summary) s
  where r.group_id=p_group_id and s.summary is not null
   and (p_before_id is null or r.kind<>'general' and (cursor_general or (r.created_at,r.id)<(p_before_created_at,p_before_id)))
   and (p_hidden or r.kind='general' or not ((s.summary->>'manually_hidden')::boolean or (s.summary->>'automatically_hidden')::boolean))
  order by is_general desc,r.created_at desc,r.id desc limit p_limit
 ) page; return result;
end; $$;
create function public.list_my_discussion_groups_v2(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
 perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
 select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.group_id desc),'[]') into result from (
  select g.id group_id,g.name,g.created_at,true can_read_ideas,count(r.id) room_count,coalesce(sum(private.group_discussion_unread_count(r.id,actor)),0) unread_count
  from private.community_groups g join private.group_discussions r on r.group_id=g.id
  where private.group_discussion_summary_v2(r.id,actor) is not null and (p_before_id is null or (g.created_at,g.id)<(p_before_created_at,p_before_id))
  group by g.id order by g.created_at desc,g.id desc limit p_limit
 ) page; return result;
end; $$;
create function public.get_group_discussion_settings(p_expected_profile_id uuid,p_group_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
 if not private.group_discussion_person_current(p_group_id,actor) then raise sqlstate '42501' using message='The Group settings are unavailable.'; end if;
 select jsonb_build_object('group_id',g.id,'creation_policy',g.idea_creation_policy,'version',g.idea_settings_version,
  'can_edit',coalesce(private.group_authority_role(g.id,actor) in ('creator','co_creator'),false),
  'can_create',g.idea_creation_policy='members' or private.group_authority_role(g.id,actor) is not null,
  'general_room_id',(select r.id from private.group_discussions r where r.group_id=g.id and r.kind='general')) into result from private.community_groups g where g.id=p_group_id;
 return result;
end; $$;
create function public.set_group_discussion_settings(p_expected_profile_id uuid,p_client_request_id uuid,p_group_id uuid,p_expected_version bigint,p_creation_policy text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); receipt private.group_discussion_receipts%rowtype; intent jsonb; result jsonb; g private.community_groups%rowtype;
begin
 if p_client_request_id is null or p_creation_policy is null or p_creation_policy not in ('managers','members') then raise sqlstate '22023' using message='The Group settings are invalid.'; end if;
 intent:=jsonb_build_object('operation','settings','group',p_group_id,'version',p_expected_version,'policy',p_creation_policy);
 perform pg_advisory_xact_lock(hashtextextended('group-discussion:'||actor::text||':'||p_client_request_id::text,0));
 select * into g from private.community_groups where id=p_group_id for update;
 perform private.require_group_actor(actor); perform private.require_group_manager(p_group_id,actor,true);
 select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_client_request_id;
 if found then if receipt.intent<>intent then raise sqlstate '22023' using message='The command identity was reused.'; end if; return receipt.result; end if;
 if g.idea_settings_version is distinct from p_expected_version then raise sqlstate 'PT409' using message='The Group settings changed.'; end if;
 update private.community_groups set idea_creation_policy=p_creation_policy,idea_settings_version=idea_settings_version+1 where id=p_group_id returning * into g;
 result:=jsonb_build_object('room_id',coalesce((select r.id from private.group_discussions r where r.group_id=g.id and r.kind='general'),g.id),'object_id',g.id,'version',g.idea_settings_version,'sequence',0);
 insert into private.group_discussion_receipts values(actor,p_client_request_id,intent,result);
 perform realtime.send(jsonb_build_object('group_id',p_group_id),'changed','group-discussions:group:'||p_group_id::text,true);
 return result;
end; $$;
create function public.preview_group_discussion_invitation_link(p_expected_profile_id uuid,p_token text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
 if p_token is null or p_token!~'^[0-9a-f]{64}$' then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
 select jsonb_build_object('kind','group_discussion','room_id',r.id,'group_id',r.group_id,
  'group_name',(select name from private.community_groups where id=r.group_id),'title',r.title,'purpose',r.purpose,'visibility',r.visibility,
  'creator_id',r.creator_id,'expires_at',l.expires_at,'room_kind',r.kind,'created_at',r.created_at,'version',r.version,'archived',false,
  'admission_id',null,'access_id',null,'access','discoverable','can_join',private.group_discussion_admission(r.id,actor) is null,
  'can_send',false,'can_manage',false,'can_invite',false,'can_read_links',false,'can_publish',false,'frozen',false,
  'muted',false,'manually_hidden',false,'automatically_hidden',false,'invitation_link_version',r.invitation_link_version,'unread_count',0,'preview',null)
 into result from private.group_discussion_invitation_links l join private.group_discussions r on r.id=l.room_id
 where l.token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and l.revoked_at is null and l.expires_at>statement_timestamp()
 and private.group_discussion_person_current(r.group_id,actor) and private.group_discussion_can_manage(r.id,l.issuer_id)
 and not private.has_active_user_block_between(actor,l.issuer_id) and not r.archived and r.frozen_at is null;
 if result is null then raise sqlstate '42501' using message='The invitation is unavailable.'; end if; return result;
end; $$;
create function private.capture_group_discussion_exit() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.ended_at is not null and (new.ended_at,new.ended_by,new.end_sequence,new.end_snapshot)
  is distinct from (old.ended_at,old.ended_by,old.end_sequence,old.end_snapshot) then
  raise sqlstate '55000' using message='An ended discussion admission is immutable.';
 end if;
 if old.ended_at is null and new.ended_at is not null then
  -- Group relationship commands and room commands use the same Group->room order.
  perform 1 from private.group_discussions where id=new.room_id for update;
  select last_sequence into new.end_sequence from private.group_discussions where id=new.room_id;
  new.end_snapshot:=private.group_discussion_snapshot(new.room_id);
 end if; return new;
end; $$;
create trigger a_group_discussion_capture_exit before update of ended_at on private.group_discussion_admissions
for each row execute function private.capture_group_discussion_exit();
create or replace function private.end_group_discussion_source() returns trigger
language plpgsql security definer set search_path='' as $$
declare r record; remaining boolean;
begin
 remaining:=private.group_discussion_source(new.group_id,new.profile_id) is not null;
 for r in select d.id,d.last_sequence from private.group_discussions d where d.group_id=new.group_id order by d.id for update loop
  if not remaining then
   update private.group_discussion_admissions set ended_at=clock_timestamp(),ended_by=coalesce(auth.uid(),new.profile_id)
    where room_id=r.id and profile_id=new.profile_id and ended_at is null;
   update private.group_discussion_invitations set status='revoked' where room_id=r.id and recipient_id=new.profile_id and status='pending';
  end if;
  update private.group_discussion_views v set ended_at=clock_timestamp(),
   end_sequence=case when v.access_kind='oversight' then v.observed_sequence else r.last_sequence end,
   end_snapshot=private.group_discussion_snapshot(r.id)
   where v.room_id=r.id and v.profile_id=new.profile_id and v.ended_at is null
    and (not remaining or v.access_kind='oversight' and private.group_authority_role(new.group_id,new.profile_id) is null);
 end loop;
 perform private.group_discussion_signal(new.profile_id); return new;
end; $$;
-- A managerial role replacement is also a frontier boundary when authority ends;
-- ordinary independent Group membership never resurrects an ended room episode.
create function private.ensure_group_general() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.publication_state='published' and not new.directory_suppressed and private.group_has_accountable_identity(new.id) then
  insert into private.group_discussions(group_id,creator_id,title,kind,visibility)
   values(new.id,new.original_actor_id,'General','general','group') on conflict(group_id) where kind='general' do nothing;
  insert into private.group_discussion_views(room_id,profile_id,access_kind,read_sequence,observed_sequence)
   select r.id,m.profile_id,'general',r.last_sequence,0 from private.group_discussions r
   join private.community_group_managers m on m.group_id=r.group_id
   where r.group_id=new.id and r.kind='general' and m.profile_id is not null
   on conflict(room_id,profile_id,access_kind) where ended_at is null do nothing;
 end if; return new;
end; $$;
create trigger community_groups_ensure_general after insert or update of publication_state,directory_suppressed on private.community_groups
for each row execute function private.ensure_group_general();
insert into private.group_discussions(group_id,creator_id,title,kind,visibility)
select g.id,g.original_actor_id,'General','general','group' from private.community_groups g
where private.group_discussion_group_available(g.id) on conflict(group_id) where kind='general' do nothing;

create function private.emit_group_discussion_event(p_room uuid,p_kind text,p_actor uuid,p_target uuid default null,p_object uuid default null) returns void
language sql security definer set search_path='' as $$
 insert into private.group_discussion_events(room_id,event_kind,actor_id,target_id,object_id,sequence,visibility)
 select r.id,p_kind,p_actor,p_target,p_object,r.last_sequence,r.visibility from private.group_discussions r where r.id=p_room
 on conflict do nothing;
$$;

create or replace function private.group_discussion_invitation_available(p_invitation uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.group_discussion_invitations i join private.group_discussions r on r.id=i.room_id
 where i.id=p_invitation and i.status='pending' and not r.archived and r.frozen_at is null
 and private.group_discussion_person_current(r.group_id,i.recipient_id)
 and (private.group_discussion_can_manage(r.id,i.inviter_id) or r.visibility='group' and private.group_discussion_admission(r.id,i.inviter_id)=i.inviter_admission_id)
 and not private.has_active_user_block_between(i.inviter_id,i.recipient_id));
$$;
create or replace function private.group_discussion_command(p_actor uuid,p_key uuid,p_operation text,p_group uuid,p_room uuid,p_arguments jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_actor); intent jsonb; receipt private.group_discussion_receipts%rowtype;
 room private.group_discussions%rowtype; admission private.group_discussion_admissions%rowtype; invitation private.group_discussion_invitations%rowtype;
 source jsonb; result jsonb; target uuid; object_id uuid; access_id uuid; policy text; manager boolean; token text; link private.group_discussion_invitation_links%rowtype;
begin
 if p_key is null or p_arguments is null or p_operation is null then raise sqlstate '22023' using message='The discussion command is invalid.'; end if;
 if p_operation in ('create','update') and (p_arguments->>'title' is null or char_length(p_arguments->>'title') not between 1 and 120
  or char_length(coalesce(p_arguments->>'purpose',''))>500 or coalesce(p_arguments->>'visibility','invitation') not in ('group','invitation'))
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
 elsif p_operation='respond' then
  select * into invitation from private.group_discussion_invitations where id=(p_arguments->>'invitation_id')::uuid and room_id=p_room;
  if invitation.id is null or invitation.recipient_id<>actor then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
  perform private.lock_user_interaction_pair(actor,invitation.inviter_id);
 elsif p_operation='accept_link' then
  select * into link from private.group_discussion_invitation_links where room_id=p_room and token_hash=encode(extensions.digest(p_arguments->>'token','sha256'),'hex');
  if link.room_id is not null then perform private.lock_user_interaction_pair(actor,link.issuer_id); end if;
 end if;
 perform 1 from private.community_groups where id=p_group for update;
 if p_room is not null then select * into room from private.group_discussions where id=p_room for update; end if;
 perform private.require_group_identity(p_actor);
 select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_key;
 if found then
  if receipt.intent<>intent then raise sqlstate '22023' using message='The command identity was reused.'; end if;
  if p_operation not in ('leave','respond','join','accept_link','preferences') and not private.group_discussion_person_current(p_group,actor) then
   raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  -- Replayed consent is only its original receipt; never a new admission.
  return receipt.result;
 end if;
 if p_operation not in ('leave','respond') and not exists(select 1 from public.profiles where id=actor and display_name is not null) then
  raise sqlstate '55000' using message='A complete profile is required.'; end if;
 if p_operation='create' then
  select idea_creation_policy into policy from private.community_groups where id=p_group;
  if not private.group_discussion_person_current(p_group,actor) or policy='managers' and private.group_authority_role(p_group,actor) is null then
   raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  source:=private.group_discussion_source(p_group,actor);
  insert into private.group_discussions(group_id,creator_id,title,purpose,visibility)
   values(p_group,actor,p_arguments->>'title',coalesce(p_arguments->>'purpose',''),coalesce(p_arguments->>'visibility','invitation')) returning * into room;
  insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
   values(room.id,actor,source->>'kind',(source->>'id')::uuid,0,0) returning id into object_id;
  perform private.emit_group_discussion_event(room.id,'created',actor,null,room.id);
 elsif p_operation='leave' then
  select * into admission from private.group_discussion_admissions where id=(p_arguments->>'admission_id')::uuid and room_id=p_room and profile_id=actor for update;
  if admission.id is null or room.kind='general' then raise sqlstate '42501' using message='The admission is unavailable.'; end if;
  update private.group_discussion_admissions set ended_at=coalesce(ended_at,clock_timestamp()),ended_by=coalesce(ended_by,actor) where id=admission.id;
  object_id:=admission.id;
 elsif p_operation='respond' then
  if p_arguments->>'response' is null or p_arguments->>'response' not in ('accepted','declined') then raise sqlstate '22023' using message='The invitation response is invalid.'; end if;
  select i.* into invitation from private.group_discussion_invitations i where i.id=invitation.id for update;
  if invitation.status<>'pending' then raise sqlstate 'PT409' using message='The invitation changed.'; end if;
  if p_arguments->>'response'='accepted' then
   if not private.group_discussion_invitation_available(invitation.id) then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
   if private.group_discussion_admission(p_room,actor) is not null then raise sqlstate 'PT409' using message='The discussion membership changed.'; end if;
   source:=private.group_discussion_source(p_group,actor);
   insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
    values(p_room,actor,source->>'kind',(source->>'id')::uuid,room.last_sequence,room.last_sequence) returning id into object_id;
   update private.group_discussion_preferences set hidden=false where room_id=p_room and profile_id=actor;
  else object_id:=invitation.id; end if;
  update private.group_discussion_invitations set status=p_arguments->>'response' where id=invitation.id;
 elsif p_operation in ('join','accept_link') then
  if not private.group_discussion_person_current(p_group,actor) or room.kind<>'idea' or room.frozen_at is not null or room.archived then
   raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  if p_operation='accept_link' then
   select * into link from private.group_discussion_invitation_links where room_id=p_room
    and token_hash=encode(extensions.digest(p_arguments->>'token','sha256'),'hex') and revoked_at is null and expires_at>clock_timestamp();
   if link.room_id is null or not private.group_discussion_can_manage(p_room,link.issuer_id) or private.has_active_user_block_between(actor,link.issuer_id) then
    raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
  elsif room.visibility<>'group' and private.group_authority_role(p_group,actor) is null then raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  if private.group_discussion_admission(p_room,actor) is not null then raise sqlstate 'PT409' using message='The discussion membership changed.'; end if;
  source:=private.group_discussion_source(p_group,actor);
  insert into private.group_discussion_admissions(room_id,profile_id,source_kind,source_id,frontier,read_sequence)
   values(p_room,actor,source->>'kind',(source->>'id')::uuid,room.last_sequence,room.last_sequence) returning id into object_id;
  update private.group_discussion_preferences set hidden=false where room_id=p_room and profile_id=actor;
 elsif p_operation='preferences' then
  if not private.group_discussion_person_current(p_group,actor) or not (room.visibility='group' or private.group_discussion_can_read_current(p_room,actor)) then
   raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  if jsonb_typeof(p_arguments->'muted') is distinct from 'boolean' or jsonb_typeof(p_arguments->'hidden') is distinct from 'boolean'
    or (p_arguments->>'hidden')::boolean and (room.kind='general' or private.group_discussion_admission(p_room,actor) is not null) then
   raise sqlstate '22023' using message='The discussion preference is invalid.'; end if;
  insert into private.group_discussion_preferences(room_id,profile_id,muted,hidden) values(p_room,actor,(p_arguments->>'muted')::boolean,(p_arguments->>'hidden')::boolean)
   on conflict(room_id,profile_id) do update set muted=excluded.muted,hidden=excluded.hidden;
  object_id:=room.id;
 else
  access_id:=private.ensure_group_discussion_access(p_room,actor);
  manager:=private.group_discussion_can_manage(p_room,actor);
  select * into admission from private.group_discussion_admissions where id=private.group_discussion_admission(p_room,actor);
  if room.frozen_at is not null or room.archived and p_operation<>'update' then raise sqlstate '55000' using message='The discussion is read-only.'; end if;
  if p_operation in ('withdraw','remove','update','rotate_link','revoke_link') and not manager then raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
  case p_operation
  when 'send' then
   update private.group_discussions set last_sequence=last_sequence+1,last_activity_at=clock_timestamp() where id=p_room returning * into room;
   insert into private.group_discussion_messages(room_id,sequence,sender_id,body) values(p_room,room.last_sequence,actor,p_arguments->>'body') returning id into object_id;
   perform private.emit_group_discussion_event(p_room,'message',actor,null,object_id);
  when 'invite' then
   if room.kind='general' or not (manager or room.visibility='group' and admission.id is not null) then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
   perform private.assert_user_interaction_available(actor,target);
   source:=private.group_discussion_source(p_group,target);
   if source is null or not private.group_discussion_person_current(p_group,target) then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
   if private.group_discussion_admission(p_room,target) is not null then raise sqlstate 'PT409' using message='The discussion membership changed.'; end if;
   update private.group_discussion_invitations i set status='revoked' where i.room_id=p_room and i.recipient_id=target and i.status='pending' and not private.group_discussion_invitation_available(i.id);
   insert into private.group_discussion_invitations(room_id,inviter_id,recipient_id,inviter_admission_id,source_kind,source_id)
    values(p_room,actor,target,admission.id,source->>'kind',(source->>'id')::uuid) returning id into object_id;
   perform private.emit_group_discussion_event(p_room,'invited',actor,target,object_id);
   perform private.group_discussion_signal(target);
  when 'withdraw' then
   update private.group_discussion_invitations set status='withdrawn' where id=(p_arguments->>'invitation_id')::uuid and room_id=p_room and status='pending' returning id,recipient_id into object_id,target;
   if object_id is null then raise sqlstate 'PT409' using message='The invitation changed.'; end if;
   perform private.group_discussion_signal(target);
  when 'remove' then
   update private.group_discussion_admissions set ended_at=clock_timestamp(),ended_by=actor where id=(p_arguments->>'admission_id')::uuid
    and room_id=p_room and profile_id<>actor and ended_at is null returning id,profile_id into object_id,target;
   if object_id is null then raise sqlstate 'PT409' using message='The admission changed.'; end if;
   perform private.group_discussion_signal(target);
  when 'update' then
   if room.kind='general' then raise sqlstate '42501' using message='General is a reserved conversation.'; end if;
   if p_arguments->>'version' is null or jsonb_typeof(p_arguments->'archived') is distinct from 'boolean' then raise sqlstate '22023' using message='The discussion content is invalid.'; end if;
   if room.version<>(p_arguments->>'version')::bigint then raise sqlstate 'PT409' using message='The discussion changed.'; end if;
   if (room.title,room.purpose,room.visibility,room.archived) is distinct from
    (p_arguments->>'title',coalesce(p_arguments->>'purpose',room.purpose),coalesce(p_arguments->>'visibility',room.visibility),(p_arguments->>'archived')::boolean) then
    update private.group_discussions set title=p_arguments->>'title',purpose=coalesce(p_arguments->>'purpose',room.purpose),visibility=coalesce(p_arguments->>'visibility',room.visibility),
     archived=(p_arguments->>'archived')::boolean,version=version+1 where id=p_room returning * into room;
   end if;
   object_id:=room.id;
  when 'rotate_link','revoke_link' then
   if room.kind='general' or (p_arguments->>'version')::bigint is distinct from room.invitation_link_version then raise sqlstate 'PT409' using message='The invitation link changed.'; end if;
   if p_operation='rotate_link' then
    token:=encode(extensions.gen_random_bytes(32),'hex');
    insert into private.group_discussion_invitation_links(room_id,token_hash,issuer_id,expires_at)
     values(p_room,encode(extensions.digest(token,'sha256'),'hex'),actor,clock_timestamp()+interval '30 days')
     on conflict(room_id) do update set token_hash=excluded.token_hash,issuer_id=excluded.issuer_id,issued_at=clock_timestamp(),expires_at=excluded.expires_at,revoked_at=null;
   else update private.group_discussion_invitation_links set revoked_at=clock_timestamp() where room_id=p_room; end if;
   update private.group_discussions set invitation_link_version=invitation_link_version+1 where id=p_room returning * into room;
   object_id:=room.id;
  else raise sqlstate '22023' using message='The discussion command is invalid.';
  end case;
 end if;
 result:=jsonb_build_object('room_id',room.id,'object_id',object_id,'version',room.version,'sequence',room.last_sequence);
 if p_operation in ('rotate_link','revoke_link') then result:=result||jsonb_build_object('invitation_link_version',room.invitation_link_version,'token',token,
  'expires_at',(select expires_at from private.group_discussion_invitation_links where room_id=room.id)); end if;
 insert into private.group_discussion_receipts values(actor,p_key,intent,result);
 -- Content-free room hints avoid an unbounded per-recipient write/fanout.
 perform realtime.send(jsonb_build_object('group_id',p_group),'changed','group-discussions:group:'||p_group::text,true);
 perform private.group_discussion_signal(actor);
 return result;
end; $$;

create function public.create_group_discussion_v2(p_expected_profile_id uuid,p_client_request_id uuid,p_group_id uuid,p_title text,p_purpose text,p_visibility text) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'create',p_group_id,null,jsonb_build_object('title',btrim(p_title),'purpose',btrim(p_purpose),'visibility',p_visibility));$$;
create function public.update_group_discussion_v2(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_version bigint,p_title text,p_purpose text,p_visibility text,p_archived boolean) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'update',null,p_room_id,jsonb_build_object('version',p_expected_version,'title',btrim(p_title),'purpose',btrim(p_purpose),'visibility',p_visibility,'archived',p_archived));$$;
create function public.join_group_discussion(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'join',null,p_room_id,'{}');$$;
create function public.set_group_discussion_preferences(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_muted boolean,p_hidden boolean) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'preferences',null,p_room_id,jsonb_build_object('muted',p_muted,'hidden',p_hidden));$$;
create function public.create_group_discussion_invitation_link(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'rotate_link',null,p_room_id,jsonb_build_object('version',p_expected_version));$$;
create function public.revoke_group_discussion_invitation_link(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_command(p_expected_profile_id,p_client_request_id,'revoke_link',null,p_room_id,jsonb_build_object('version',p_expected_version));$$;
create function public.accept_group_discussion_invitation_link(p_expected_profile_id uuid,p_client_request_id uuid,p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); room_id uuid; receipt private.group_discussion_receipts%rowtype;
begin
 if p_token is null or p_token!~'^[0-9a-f]{64}$' then raise sqlstate '42501' using message='The invitation is unavailable.'; end if;
 -- A lost accepted reply remains recoverable after capability rotation.
 select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_client_request_id;
 if found and receipt.intent->>'operation'='accept_link' and receipt.intent->'arguments'->>'token'=p_token then room_id:=(receipt.intent->>'room')::uuid;
 else select l.room_id into room_id from private.group_discussion_invitation_links l where token_hash=encode(extensions.digest(p_token,'sha256'),'hex'); end if;
 return private.group_discussion_command(actor,p_client_request_id,'accept_link',null,room_id,jsonb_build_object('token',p_token));
end; $$;

create function public.get_group_discussion_message_page_v2(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); frontier bigint; access_id uuid; items jsonb; newest private.group_discussion_messages%rowtype; secret uuid; current_read boolean;
begin
 if p_limit is null or p_limit not between 1 and 50 or p_before_sequence<=0 then raise sqlstate '22023' using message='The discussion page is invalid.'; end if;
 current_read:=private.group_discussion_can_read_current(p_room_id,actor);
 if current_read then access_id:=private.ensure_group_discussion_access(p_room_id,actor);
 else access_id:=(private.group_discussion_summary_v2(p_room_id,actor)->>'access_id')::uuid; end if;
 frontier:=private.group_discussion_history_frontier(p_room_id,actor);
 if frontier is null or access_id is null then raise sqlstate '42501' using message='The discussion is unavailable.'; end if;
 select coalesce(jsonb_agg(to_jsonb(page) order by page.sequence desc),'[]') into items from (
  select m.id message_id,m.sequence,m.sender_id,p.display_name sender_name,m.body,m.created_at from private.group_discussion_messages m
  left join public.profiles p on p.id=m.sender_id where m.room_id=p_room_id and m.sequence<=frontier and (p_before_sequence is null or m.sequence<p_before_sequence)
  order by m.sequence desc limit p_limit
 ) page;
 if current_read and p_before_sequence is null then
  select * into newest from private.group_discussion_messages where room_id=p_room_id and sequence<=frontier order by sequence desc limit 1;
  select read_secret into secret from private.group_discussions where id=p_room_id;
 end if;
 if current_read then
  update private.group_discussion_views set observed_sequence=greatest(observed_sequence,coalesce((items->0->>'sequence')::bigint,0)) where id=access_id;
 end if;
 return jsonb_build_object('profile_id',actor,'room_id',p_room_id,'admission_id',access_id,'access_id',access_id,'items',items,
  'snapshot_token',case when newest.id is not null then private.group_discussion_read_token(access_id,newest.sequence,newest.id,secret) end);
end; $$;
create function public.acknowledge_group_discussion_read_v2(p_expected_profile_id uuid,p_room_id uuid,p_snapshot_token text) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); room private.group_discussions%rowtype; access_id uuid; message private.group_discussion_messages%rowtype;
begin
 perform 1 from private.community_groups where id=(select group_id from private.group_discussions where id=p_room_id) for update;
 select * into room from private.group_discussions where id=p_room_id for update;
 perform private.require_group_identity(actor); access_id:=private.require_group_discussion_access(p_room_id,actor);
 if p_snapshot_token is null or p_snapshot_token!~'^[0-9]+:[0-9a-f-]{36}:[0-9a-f]{64}$' then raise sqlstate '22023' using message='The read snapshot is invalid.'; end if;
 select * into message from private.group_discussion_messages where room_id=p_room_id and id=split_part(p_snapshot_token,':',2)::uuid;
 if message.id is null or p_snapshot_token<>private.group_discussion_read_token(access_id,message.sequence,message.id,room.read_secret) then raise sqlstate '22023' using message='The read snapshot is invalid.'; end if;
 update private.group_discussion_admissions set read_sequence=greatest(read_sequence,message.sequence) where id=access_id;
 update private.group_discussion_views set read_sequence=greatest(read_sequence,message.sequence) where id=access_id;
 perform private.group_discussion_signal(actor);
end; $$;
-- Installed readers keep their exact JSON shape. They now obey full-history
-- admission too; new discovery/General/former kinds are only in v2 summaries.
create or replace function public.list_group_discussion_messages(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
 perform private.require_group_discussion(p_room_id,actor);
 return public.get_group_discussion_message_page_v2(actor,p_room_id,p_limit,p_before_sequence)-'profile_id'-'room_id'-'admission_id'-'access_id';
end; $$;
create or replace function public.get_group_discussion_message_page(p_expected_profile_id uuid,p_room_id uuid,p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin perform private.require_group_discussion(p_room_id,actor); return public.get_group_discussion_message_page_v2(actor,p_room_id,p_limit,p_before_sequence)-'access_id'; end; $$;
create or replace function public.acknowledge_group_discussion_read(p_expected_profile_id uuid,p_room_id uuid,p_snapshot_token text) returns void
language plpgsql security definer set search_path='' as $$
begin perform private.require_group_discussion(p_room_id,private.require_group_identity(p_expected_profile_id)); perform public.acknowledge_group_discussion_read_v2(p_expected_profile_id,p_room_id,p_snapshot_token); end; $$;
create or replace function public.get_group_discussion_unread(p_expected_profile_id uuid) returns bigint
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin return (select coalesce(sum(private.group_discussion_unread_count(r.id,actor)),0) from private.group_discussions r where private.group_discussion_can_read_current(r.id,actor)); end; $$;
create or replace function public.get_own_message_unread_summary_with_discussions(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); base jsonb; rooms bigint;
begin
 base:=public.get_own_message_unread_summary(actor);
 select count(*) into rooms from private.group_discussions r where private.group_discussion_unread_count(r.id,actor)>0;
 return jsonb_build_object('total',(base->>'total')::bigint+rooms,'private',(base->>'private')::bigint,'groups',(base->>'groups')::bigint+rooms);
end; $$;

-- Conversion's later migration replaces this fail-closed recipient seam.
create function private.group_discussion_project_invite_recipient(p_project uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$select false;$$;
create function private.group_discussion_notice_available(p_event uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select e.actor_id<>p_actor and private.group_discussion_person_current(r.group_id,p_actor)
 and (e.target_id is null or e.target_id=p_actor)
 and case e.event_kind
  when 'invited' then private.group_discussion_invitation_available(e.object_id)
  when 'created' then (e.visibility='group' and r.visibility='group' or private.group_authority_role(r.group_id,p_actor) is not null)
   and (exists(select 1 from private.community_group_managers c where c.group_id=r.group_id and c.profile_id=p_actor)
    or exists(select 1 from private.group_delegates d where d.group_id=r.group_id and d.profile_id=p_actor and d.revoked_at is null and d.granted_at<=e.created_at)
    or e.visibility='group' and exists(select 1 from private.group_memberships m where m.group_id=r.group_id and m.profile_id=p_actor and m.ended_at is null and m.joined_at<=e.created_at))
  when 'message' then private.group_discussion_can_read_current(r.id,p_actor)
   and not coalesce((select muted from private.group_discussion_preferences p where p.room_id=r.id and p.profile_id=p_actor),false)
   and (exists(select 1 from private.group_discussion_admissions a where a.id=private.group_discussion_admission(r.id,p_actor) and e.sequence>a.frontier)
    or exists(select 1 from private.group_discussion_views v where v.id=private.group_discussion_current_access(r.id,p_actor) and v.created_at<=e.created_at))
  when 'conversion_proposed' then private.group_authority_role(r.group_id,p_actor) is not null
  when 'converted' then private.group_discussion_can_read_current(r.id,p_actor)
  when 'project_invitation' then private.group_discussion_project_invite_recipient(e.object_id,p_actor) and private.group_discussion_can_read_current(r.id,p_actor)
  else false end
 from private.group_discussion_events e join private.group_discussions r on r.id=e.room_id where e.id=p_event),false);
$$;
create function public.list_own_group_discussion_notices(p_expected_profile_id uuid,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
 perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
 select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.notice_id desc),'[]') into result from (
  select e.id notice_id,e.event_kind,e.room_id,r.group_id,r.title,r.purpose,e.actor_id,e.object_id,e.created_at,
   exists(select 1 from private.group_discussion_notice_reads n where n.profile_id=actor and n.event_id=e.id) is_read
  from private.group_discussion_events e join private.group_discussions r on r.id=e.room_id
  where private.group_discussion_notice_available(e.id,actor) and (p_before_id is null or (e.created_at,e.id)<(p_before_created_at,p_before_id))
  order by e.created_at desc,e.id desc limit p_limit
 ) page; return result;
end; $$;
create function public.mark_group_discussion_notice_read(p_expected_profile_id uuid,p_notice_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
 if not private.group_discussion_notice_available(p_notice_id,actor) then raise sqlstate '42501' using message='The notice is unavailable.'; end if;
 insert into private.group_discussion_notice_reads values(actor,p_notice_id) on conflict do nothing;
end; $$;

-- Existing bounded roster and invitation readers use current rights; historical
-- message retention never grants a current roster or edited link collection.
do $$ declare definition text; signature text; begin
 foreach signature in array array['public.list_group_discussion_people(uuid,uuid,integer,timestamptz,uuid)','public.list_group_discussion_managed_invitations(uuid,uuid,integer,timestamptz,uuid)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  definition:=replace(definition,'perform private.require_group_discussion(p_room_id,actor);','perform private.require_group_discussion_access(p_room_id,actor);');
  definition:=replace(definition,'private.group_authority_role((select group_id from private.group_discussions where id=p_room_id),actor) is null','not private.group_discussion_can_manage(p_room_id,actor)');
  execute definition;
 end loop;
 definition:=pg_get_functiondef('public.submit_group_discussion_report(uuid,uuid,uuid,text,text)'::regprocedure);
 definition:=replace(definition,'select * into admission from private.group_discussion_admissions where id=private.require_group_discussion(message.room_id,actor);','perform private.require_group_identity(actor);');
 definition:=replace(definition,'message.sequence<=admission.frontier','private.group_discussion_history_frontier(message.room_id,actor) is null or message.sequence>private.group_discussion_history_frontier(message.room_id,actor)');
 definition:=replace(definition,'''title'',room.title','''title'',private.group_discussion_summary_v2(room.id,actor)->>''title''');
 execute definition;
end; $$;

create function private.start_group_general_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare r private.group_discussions%rowtype;
begin
 select * into r from private.group_discussions where group_id=new.group_id and kind='general';
 if r.id is not null and private.group_discussion_person_current(new.group_id,new.profile_id) then
  insert into private.group_discussion_views(room_id,profile_id,access_kind,read_sequence,observed_sequence)
   values(r.id,new.profile_id,'general',r.last_sequence,0) on conflict(room_id,profile_id,access_kind) where ended_at is null do nothing;
 end if; return new;
end; $$;
create trigger group_memberships_start_general after insert on private.group_memberships for each row execute function private.start_group_general_access();
create trigger group_delegates_start_general after insert on private.group_delegates for each row execute function private.start_group_general_access();
-- Migration-only, duplicate-safe materialization of existing General audiences.
insert into private.group_discussion_views(room_id,profile_id,access_kind,read_sequence,observed_sequence)
select r.id,p.profile_id,'general',r.last_sequence,0 from private.group_discussions r cross join lateral (
 select m.profile_id from private.community_group_managers m where m.group_id=r.group_id
 union select d.profile_id from private.group_delegates d where d.group_id=r.group_id and d.revoked_at is null
 union select m.profile_id from private.group_memberships m where m.group_id=r.group_id and m.ended_at is null
) p where r.kind='general' and private.group_discussion_person_current(r.group_id,p.profile_id)
on conflict(room_id,profile_id,access_kind) where ended_at is null do nothing;

do $$ declare object record; begin
 for object in select c.oid::regclass name from pg_class c where c.relnamespace='private'::regnamespace and c.relkind='r' and c.relname like 'group_discussion%'
 loop execute format('alter table %s enable row level security',object.name); execute format('revoke all on table %s from public,anon,authenticated,service_role',object.name); end loop;
 for object in select p.oid::regprocedure name,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','private') and (p.proname like '%group_discussion%' or p.proname in ('list_my_discussion_groups_v2','ensure_group_general','start_group_general_access'))
 loop execute format('revoke all on function %s from public,anon,authenticated,service_role',object.name);
  if object.nspname='public' or object.proname='group_discussion_topic_allowed' then execute format('grant execute on function %s to authenticated',object.name); end if;
 end loop;
end; $$;
comment on table private.group_discussion_views is 'Opened General/manager oversight scopes; oversight loss retains only actually fetched sequence frontier, never unknown rooms.';
comment on table private.group_discussion_admissions is 'Explicit planner episodes: full earlier history, separate unread baseline, captured committed exit sequence; union of live Group participation and authority supports current access.';
comment on table private.group_discussion_events is 'Private identifier-only durable events, bounded reader projects current and event-time eligible audiences; no external-provider delivery claim.';
