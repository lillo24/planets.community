-- D01c: additive projections. Legacy kinds, exact shapes, totals and routes stay
-- unchanged. Each bounded legacy candidate window suffices for a global page;
-- canonical union/order/limit happens here, never on the client.
create function private.group_contact_kind_rank(p_kind text) returns integer
language sql immutable set search_path='' as $$
  select case p_kind when 'project_chat' then 0 when 'resource_chat' then 1 when 'project_request_chat' then 2 when 'group_contact_chat' then 3
    when 'participation_request' then 0 when 'resource_request' then 1 when 'group_contact_request' then 2 end;
$$;
create function public.list_own_scoped_conversation_items_v6(p_expected_profile_id uuid,p_scope text,p_limit integer,
  p_cursor_activity_at timestamptz default null,p_cursor_item_kind text default null,p_cursor_chat_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); legacy jsonb; old_time timestamptz:=p_cursor_activity_at;
  old_kind text:=p_cursor_item_kind; old_id uuid:=p_cursor_chat_id;
begin
  perform private.validate_group_page(p_limit,p_cursor_activity_at,p_cursor_chat_id);
  if p_scope is null or p_scope not in ('private','groups') or (p_cursor_item_kind is null)<>(p_cursor_chat_id is null)
    or (p_cursor_item_kind is not null and (p_cursor_item_kind not in ('project_chat','resource_chat','project_request_chat','group_contact_chat')
      or (p_scope='groups' and p_cursor_item_kind not in ('project_chat','group_contact_chat'))
      or (p_scope='private' and p_cursor_item_kind not in ('resource_chat','project_request_chat')))) then
    raise sqlstate '22023' using message='Invalid conversation scope or cursor.'; end if;
  if p_cursor_item_kind='group_contact_chat' then
    old_time:=p_cursor_activity_at+interval '1 microsecond'; old_kind:='project_chat'; old_id:='00000000-0000-0000-0000-000000000000';
  end if;
  legacy:=public.list_own_scoped_conversation_items_v5(actor,p_scope,p_limit,old_time,old_kind,old_id);
  return (with candidates as (
      select value row from jsonb_array_elements(legacy)
      union all select private.group_contact_chat_projection(c.id,actor)||jsonb_build_object('unread_count',private.group_contact_unread(actor,c.id))
        from private.group_contact_conversations c where p_scope='groups' and private.group_contact_can_read(c.id,actor)
    ), page as (
      select row from candidates where p_cursor_chat_id is null or
        ((row->>'activity_at')::timestamptz,private.group_contact_kind_rank(row->>'item_kind'),(row->>'chat_id')::uuid)
          <(p_cursor_activity_at,private.group_contact_kind_rank(p_cursor_item_kind),p_cursor_chat_id)
      order by (row->>'activity_at')::timestamptz desc,private.group_contact_kind_rank(row->>'item_kind') desc,(row->>'chat_id')::uuid desc limit p_limit
    ) select coalesce(jsonb_agg(row order by (row->>'activity_at')::timestamptz desc,private.group_contact_kind_rank(row->>'item_kind') desc,(row->>'chat_id')::uuid desc),'[]') from page);
end; $$;

-- Preserve the already-reviewed projection and add only an authorized route.
do $$ declare definition text:=pg_get_functiondef('private.group_contact_request_projection(private.group_contact_requests,uuid)'::regprocedure);
begin execute replace(definition,'FUNCTION private.group_contact_request_projection(','FUNCTION private.group_contact_request_projection_base('); end; $$;
create or replace function private.group_contact_request_projection(p_request private.group_contact_requests,p_actor uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select private.group_contact_request_projection_base(p_request,p_actor)||jsonb_build_object('chat_id',
    (select c.id from private.group_contact_conversations c where c.request_id=p_request.id and private.group_contact_can_read(c.id,p_actor)));
$$;
create function public.list_own_structured_request_message_items_v2(p_expected_profile_id uuid,p_limit integer,
  p_cursor_activity_at timestamptz default null,p_cursor_item_kind text default null,p_cursor_request_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); old_time timestamptz:=p_cursor_activity_at;
  old_kind text:=p_cursor_item_kind; old_id uuid:=p_cursor_request_id;
begin
  perform private.validate_group_page(p_limit,p_cursor_activity_at,p_cursor_request_id);
  if (p_cursor_item_kind is null)<>(p_cursor_request_id is null) or
    (p_cursor_item_kind is not null and p_cursor_item_kind not in ('participation_request','resource_request','group_contact_request')) then
    raise sqlstate '22023' using message='Invalid structured request cursor.'; end if;
  if p_cursor_item_kind='group_contact_request' then
    old_time:=p_cursor_activity_at+interval '1 microsecond'; old_kind:='participation_request'; old_id:='00000000-0000-0000-0000-000000000000';
  end if;
  return (with candidates as (
      select to_jsonb(r) row from public.list_own_structured_request_message_items(actor,p_limit,old_time,old_kind,old_id) r
      union all select private.group_contact_request_projection(r,actor) from private.group_contact_requests r where private.group_contact_request_visible(r,actor)
    ), page as (
      select row from candidates where p_cursor_request_id is null or
        ((row->>'activity_at')::timestamptz,private.group_contact_kind_rank(row->>'item_kind'),(row->>'request_id')::uuid)
          <(p_cursor_activity_at,private.group_contact_kind_rank(p_cursor_item_kind),p_cursor_request_id)
      order by (row->>'activity_at')::timestamptz desc,private.group_contact_kind_rank(row->>'item_kind') desc,(row->>'request_id')::uuid desc limit p_limit
    ) select coalesce(jsonb_agg(row order by (row->>'activity_at')::timestamptz desc,private.group_contact_kind_rank(row->>'item_kind') desc,(row->>'request_id')::uuid desc),'[]') from page);
end; $$;
create function public.get_own_structured_request_message_item_v2(p_expected_profile_id uuid,p_item_kind text,p_request_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if p_item_kind='group_contact_request' then return public.get_own_group_contact_request(p_expected_profile_id,p_request_id); end if;
  return (select to_jsonb(r) from public.get_own_structured_request_message_item(p_expected_profile_id,p_item_kind,p_request_id) r);
end; $$;
create function public.get_own_message_unread_summary_v2(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); legacy jsonb; extra bigint;
begin
  legacy:=public.get_own_message_unread_summary(actor);
  select count(*) into extra from private.group_contact_admissions a where a.profile_id=actor and private.group_contact_unread(actor,a.conversation_id)>0;
  return jsonb_build_object('total',(legacy->>'total')::bigint+extra,'private',(legacy->>'private')::bigint,'groups',(legacy->>'groups')::bigint+extra);
end; $$;
create function public.acknowledge_own_message_read_v2(p_expected_profile_id uuid,p_kind text,p_chat_id uuid,p_boundary uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  if p_kind='group_contact_chat' then perform public.acknowledge_group_contact_read(actor,p_chat_id,p_boundary);
  else perform public.acknowledge_own_message_read(actor,p_kind,p_chat_id,p_boundary); end if;
  return public.get_own_message_unread_summary_v2(actor);
end; $$;

-- Broadcast only to the current authorized recipient set. An access-change hint
-- has no request/chat identity and is allowed to invalidate former own caches.
create function private.group_contact_signal_request() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  if private.group_contact_representation_valid(new.source_group_id,new.submitter_id,new.source_delegate_id) then perform private.group_contact_signal(new.submitter_id); end if;
  if new.status='pending' and new.expires_at>clock_timestamp() and private.group_contact_triage_available(new) then
    for recipient in select profile_id from private.current_group_manager_profile_ids(new.target_group_id) order by profile_id
    loop perform private.group_contact_signal(recipient); end loop;
  end if;
  if new.status='accepted' then
    for recipient in select a.profile_id from private.group_contact_conversations c join private.group_contact_admissions a on a.conversation_id=c.id
      where c.request_id=new.id and private.group_contact_can_read(c.id,a.profile_id) order by a.profile_id
    loop perform private.group_contact_signal(recipient); end loop;
  end if;
  return new;
end; $$;
create trigger group_contact_request_signal after insert or update on private.group_contact_requests for each row execute function private.group_contact_signal_request();
create function private.group_contact_signal_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; row_data jsonb:=coalesce(to_jsonb(new),to_jsonb(old));
begin
  if tg_table_name='group_delegates' then perform private.group_contact_signal((row_data->>'profile_id')::uuid);
  elsif tg_table_name='group_contact_admissions' then
    perform private.group_contact_signal((row_data->>'profile_id')::uuid);
  else
    for recipient in select distinct a.profile_id from private.group_contact_admissions a where a.group_id=(row_data->>'id')::uuid order by a.profile_id
    loop perform private.group_contact_signal(recipient); end loop;
  end if;
  return coalesce(new,old);
end; $$;
create trigger group_contact_delegate_access after update on private.group_delegates for each row execute function private.group_contact_signal_access();
create trigger group_contact_admission_access after update on private.group_contact_admissions for each row execute function private.group_contact_signal_access();
create trigger group_contact_lifecycle_access after update on private.community_groups for each row
  when(old.publication_state is distinct from new.publication_state or old.directory_suppressed is distinct from new.directory_suppressed)
  execute function private.group_contact_signal_access();
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'group_contact_%') or
      (n.nspname='public' and p.proname=any(array['list_own_scoped_conversation_items_v6','list_own_structured_request_message_items_v2','get_own_structured_request_message_item_v2','get_own_message_unread_summary_v2','acknowledge_own_message_read_v2']))
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
