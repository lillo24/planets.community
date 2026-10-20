-- C-owned links use the same committed room ordinal/frontier as messages.
-- Edits never move an older link across a later admission's frontier.
create table private.group_discussion_links (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references private.group_discussions(id),
  creator_id uuid not null,
  created_sequence bigint not null check(created_sequence>0),
  display_name text not null check(display_name=btrim(display_name) and char_length(display_name) between 1 and 120 and display_name!~'[[:cntrl:]]'),
  destination text not null check(destination=private.normalize_project_workspace_url(destination)),
  version bigint not null default 1 check(version>0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  removed_at timestamptz,
  unique(room_id,created_sequence)
);
create index group_discussion_links_page on private.group_discussion_links(room_id,created_at desc,id desc) where removed_at is null;
alter table private.group_discussion_links enable row level security;
revoke all on private.group_discussion_links from public,anon,authenticated,service_role;

create function private.protect_group_discussion_link() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='DELETE' or row(new.id,new.room_id,new.creator_id,new.created_sequence,new.created_at)
      is distinct from row(old.id,old.room_id,old.creator_id,old.created_sequence,old.created_at)
    or old.removed_at is not null then
    raise sqlstate '22023' using message='The discussion link identity is immutable.';
  end if;
  return new;
end; $$;
create trigger group_discussion_links_identity before update or delete on private.group_discussion_links for each row execute function private.protect_group_discussion_link();

create function private.group_discussion_link_payload(p_actor uuid,p_admission uuid,p_link private.group_discussion_links) returns jsonb
language sql stable set search_path='' as $$
  select jsonb_build_object('profile_id',p_actor,'room_id',p_link.room_id,'admission_id',p_admission,
    'link_id',p_link.id,'name',p_link.display_name,'url',p_link.destination,'version',p_link.version,
    'created_at',p_link.created_at,'updated_at',p_link.updated_at);
$$;
create function public.get_group_discussion_link(p_expected_profile_id uuid,p_room_id uuid,p_link_id uuid,p_expected_admission_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); admission uuid:=private.require_group_discussion(p_room_id,actor); link private.group_discussion_links%rowtype;
begin
  if p_expected_admission_id is null or admission<>p_expected_admission_id then raise sqlstate '42501' using message='The discussion link is unavailable.'; end if;
  select l.* into link from private.group_discussion_links l join private.group_discussion_admissions a on a.id=admission
    where l.id=p_link_id and l.room_id=p_room_id and l.removed_at is null and l.created_sequence>a.frontier;
  if not found then raise sqlstate '42501' using message='The discussion link is unavailable.'; end if;
  return private.group_discussion_link_payload(actor,admission,link);
end; $$;
create function public.list_group_discussion_links(p_expected_profile_id uuid,p_room_id uuid,p_expected_admission_id uuid default null,p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_expected_profile_id); admission uuid:=private.require_group_discussion(p_room_id,actor); items jsonb; archived boolean; manager boolean;
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  if p_limit>25 then raise sqlstate '22023' using message='The discussion link page is invalid.'; end if;
  if p_expected_admission_id is not null and admission<>p_expected_admission_id then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  select r.archived,not r.archived and private.group_authority_role(r.group_id,actor) is not null into archived,manager from private.group_discussions r where r.id=p_room_id;
  select coalesce(jsonb_agg(private.group_discussion_link_payload(actor,admission,l::private.group_discussion_links) order by l.created_at desc,l.id desc),'[]'::jsonb) into items
    from (select l.* from private.group_discussion_links l join private.group_discussion_admissions a on a.id=admission
      where l.room_id=p_room_id and l.removed_at is null and l.created_sequence>a.frontier
        and (p_before_created_at is null or (l.created_at,l.id)<(p_before_created_at,p_before_id))
      order by l.created_at desc,l.id desc limit p_limit) l;
  return jsonb_build_object('profile_id',actor,'room_id',p_room_id,'admission_id',admission,'archived',archived,'can_manage',manager,'items',items);
end; $$;

create function private.group_discussion_link_command(p_actor uuid,p_key uuid,p_room uuid,p_admission uuid,p_operation text,p_link uuid,p_version bigint,p_name text,p_url text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_actor(p_actor); group_id uuid; room private.group_discussions%rowtype;
  admission private.group_discussion_admissions%rowtype; link private.group_discussion_links%rowtype;
  receipt private.group_discussion_receipts%rowtype; intent jsonb; result jsonb; recipient uuid;
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
  select a.* into admission from private.group_discussion_admissions a where a.id=private.require_group_discussion(p_room,actor);
  if admission.id<>p_admission then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  select * into receipt from private.group_discussion_receipts where actor_id=actor and request_id=p_key;
  if found then
    if receipt.intent<>intent then raise sqlstate '22023' using message='The command identity was reused.'; end if;
    return receipt.result;
  end if;
  if private.group_authority_role(group_id,actor) is null then raise sqlstate '42501' using message='The discussion links are unavailable.'; end if;
  if room.archived then raise sqlstate '55000' using message='The discussion is read-only.'; end if;
  if p_operation='add' then
    update private.group_discussions r set last_sequence=r.last_sequence+1 where r.id=p_room returning r.* into room;
    insert into private.group_discussion_links(room_id,creator_id,created_sequence,display_name,destination)
      values(p_room,actor,room.last_sequence,p_name,p_url) returning * into link;
  else
    select l.* into link from private.group_discussion_links l where l.id=p_link and l.room_id=p_room
      and l.removed_at is null and l.created_sequence>admission.frontier for update;
    if not found then raise sqlstate '42501' using message='The discussion link is unavailable.'; end if;
    if link.version<>p_version then raise sqlstate 'PT409' using message='The discussion link changed.'; end if;
    if p_operation='remove' then
      update private.group_discussion_links l set removed_at=clock_timestamp(),updated_at=clock_timestamp(),version=l.version+1 where l.id=link.id returning l.* into link;
    elsif (link.display_name,link.destination) is distinct from (p_name,p_url) then
      update private.group_discussion_links l set display_name=p_name,destination=p_url,updated_at=clock_timestamp(),version=l.version+1 where l.id=link.id returning l.* into link;
    end if;
  end if;
  result:=jsonb_build_object('room_id',p_room,'object_id',link.id,'version',link.version,'sequence',link.created_sequence);
  insert into private.group_discussion_receipts(actor_id,request_id,intent,result) values(actor,p_key,intent,result);
  for recipient in select a.profile_id from private.group_discussion_admissions a where a.room_id=p_room and a.id=private.group_discussion_admission(p_room,a.profile_id)
  loop perform private.group_discussion_signal(recipient); end loop;
  return result;
end; $$;
create function public.add_group_discussion_link(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_admission_id uuid,p_name text,p_url text) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_link_command(p_expected_profile_id,p_client_request_id,p_room_id,p_expected_admission_id,'add',null,null,p_name,p_url);$$;
create function public.update_group_discussion_link(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_admission_id uuid,p_link_id uuid,p_expected_version bigint,p_name text,p_url text) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_link_command(p_expected_profile_id,p_client_request_id,p_room_id,p_expected_admission_id,'edit',p_link_id,p_expected_version,p_name,p_url);$$;
create function public.remove_group_discussion_link(p_expected_profile_id uuid,p_client_request_id uuid,p_room_id uuid,p_expected_admission_id uuid,p_link_id uuid,p_expected_version bigint) returns jsonb
language sql security definer set search_path='' as $$select private.group_discussion_link_command(p_expected_profile_id,p_client_request_id,p_room_id,p_expected_admission_id,'remove',p_link_id,p_expected_version,null,null);$$;
revoke all on function private.protect_group_discussion_link(),private.group_discussion_link_payload(uuid,uuid,private.group_discussion_links),private.group_discussion_link_command(uuid,uuid,uuid,uuid,text,uuid,bigint,text,text) from public,anon,authenticated,service_role;
revoke all on function public.get_group_discussion_link(uuid,uuid,uuid,uuid),public.list_group_discussion_links(uuid,uuid,uuid,integer,timestamptz,uuid),public.add_group_discussion_link(uuid,uuid,uuid,uuid,text,text),public.update_group_discussion_link(uuid,uuid,uuid,uuid,uuid,bigint,text,text),public.remove_group_discussion_link(uuid,uuid,uuid,uuid,uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function public.get_group_discussion_link(uuid,uuid,uuid,uuid),public.list_group_discussion_links(uuid,uuid,uuid,integer,timestamptz,uuid),public.add_group_discussion_link(uuid,uuid,uuid,uuid,text,text),public.update_group_discussion_link(uuid,uuid,uuid,uuid,uuid,bigint,text,text),public.remove_group_discussion_link(uuid,uuid,uuid,uuid,uuid,bigint) to authenticated;
comment on table private.group_discussion_links is 'Room-owned named HTTPS links. Since-admission committed ordinal, per-item versions and soft removal; no public/template/event projection.';
comment on column private.group_discussions.last_sequence is 'Shared committed ordinal for room messages and link creation; message pages may contain gaps. Admission frontiers apply to both.';
