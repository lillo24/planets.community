-- D02: public-reference identity only, and immediate content-cache invalidation.
create or replace function private.group_contact_request_projection(p_request private.group_contact_requests,p_actor uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  with base as(select private.group_contact_request_projection_base(p_request,p_actor) value)
  select value||jsonb_build_object('chat_id',(select c.id from private.group_contact_conversations c where c.request_id=p_request.id and private.group_contact_can_read(c.id,p_actor)),
    'public_project_kind',case when value->>'public_project_id' is not null then (select p.project_kind from public.projects p where p.id=p_request.public_project_id) end,
    'public_project_title',case when value->>'public_project_id' is not null then coalesce(
      (select p.title from public.proposals p where p.id=p_request.public_project_id),(select a.title from public.recurring_activities a where a.id=p_request.public_project_id)) end)
  from base;
$$;
create function private.group_contact_access_signal(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  -- A former/erased person's connected own socket may receive this neutral
  -- access-change hint, never a new activity/request/chat identifier or content.
  if p_actor is not null then perform realtime.send(jsonb_build_object('profile_id',p_actor),'group.contact_access_changed','group-contact:profile:'||p_actor::text,true); end if;
end; $$;
create or replace function private.group_contact_signal_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; row_data jsonb:=coalesce(to_jsonb(new),to_jsonb(old)); groups uuid[]; chats uuid[];
begin
  if tg_table_name='group_delegates' then
    perform private.group_contact_access_signal((row_data->>'profile_id')::uuid);
    select array_agg(conversation_id) into chats from private.group_contact_admissions where delegate_id=(row_data->>'id')::uuid;
  elsif tg_table_name='group_contact_admissions' then
    perform private.group_contact_access_signal((row_data->>'profile_id')::uuid); chats:=array[(row_data->>'conversation_id')::uuid];
  elsif tg_table_name='group_contact_conversations' then chats:=array[(row_data->>'id')::uuid];
  elsif tg_table_name='community_group_managers' then
    groups:=array[(row_data->>'group_id')::uuid];
    perform private.group_contact_access_signal((to_jsonb(old)->>'profile_id')::uuid);
  else groups:=array[(row_data->>'id')::uuid]; end if;
  for recipient in select distinct a.profile_id from private.group_contact_admissions a where
    (a.group_id=any(groups) or a.conversation_id=any(chats)) and a.left_at is null order by a.profile_id
  loop perform private.group_contact_access_signal(recipient); end loop;
  return coalesce(new,old);
end; $$;
create trigger group_contact_new_delegate_access after insert on private.group_delegates for each row execute function private.group_contact_signal_access();
create trigger group_contact_close_access after update on private.group_contact_conversations for each row when(old.closed_at is distinct from new.closed_at) execute function private.group_contact_signal_access();
create trigger group_contact_anchor_access after update on private.community_group_managers for each row when(old.profile_id is distinct from new.profile_id) execute function private.group_contact_signal_access();
create function private.group_contact_identity_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; subject uuid:=coalesce(new.id,old.id);
begin
  if exists(select 1 from private.group_contact_admissions where profile_id=subject) then
    perform private.group_contact_access_signal(subject);
    for recipient in select distinct b.profile_id from private.group_contact_admissions a join private.group_contact_admissions b on b.conversation_id=a.conversation_id
      where a.profile_id=subject and b.profile_id<>subject and b.left_at is null order by b.profile_id
    loop perform private.group_contact_access_signal(recipient); end loop;
  end if;
  return coalesce(new,old);
end; $$;
create trigger group_contact_profile_update_access after update of display_name on public.profiles for each row when(old.display_name is distinct from new.display_name) execute function private.group_contact_identity_access();
create trigger group_contact_profile_delete_access after delete on public.profiles for each row execute function private.group_contact_identity_access();
create trigger group_contact_auth_delete_access after delete on auth.users for each row execute function private.group_contact_identity_access();
revoke all on function private.group_contact_access_signal(uuid),private.group_contact_identity_access() from public,anon,authenticated,service_role;
