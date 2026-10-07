-- UI-MSG03: additive preview metadata. Released v3 clients retain their exact
-- shape. Route context, pagination, bodies, entitlement and unread are unchanged.
create function public.list_own_scoped_conversation_items_v4(
  p_expected_profile_id uuid, p_scope text, p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null, p_cursor_chat_id uuid default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  result jsonb;
begin
  select coalesce(jsonb_agg(item.value || jsonb_build_object(
    'latest_request_activity_status', case
      when item.value->>'item_kind' = 'project_request_chat'
        and (item.value->>'last_visible_message_at' is null
          or request_activity.activity_at > (item.value->>'last_visible_message_at')::timestamptz)
      then request_activity.status end,
    'latest_group_system_event_label', case
      when item.value->>'item_kind' = 'project_chat'
        and (item.value->>'last_visible_message_at' is null
          or system_activity.created_at > (item.value->>'last_visible_message_at')::timestamptz)
      then system_activity.label end
    ) order by item.ordinality), '[]'::jsonb) into result
  from jsonb_array_elements(public.list_own_scoped_conversation_items_v3(
    actor, p_scope, p_limit, p_cursor_activity_at, p_cursor_item_kind, p_cursor_chat_id
  )) with ordinality item(value, ordinality)
  left join lateral (
    select request.status,
      greatest(request.created_at, coalesce(request.resolved_at, request.created_at)) as activity_at
    from public.participation_conversation_requests association
    join public.project_join_requests request on request.id = association.request_id
    where item.value->>'item_kind' = 'project_request_chat'
      and association.conversation_id = (item.value->>'chat_id')::uuid
    order by greatest(request.created_at, coalesce(request.resolved_at, request.created_at)) desc,
      request.created_at desc, request.id desc
    limit 1
  ) request_activity on true
  left join lateral (
    select event.created_at, case event.requirement_kind
      when 'skill' then skill.label when 'resource' then need.title end as label
    from public.project_chat_system_events event
    left join public.skills skill on skill.id = event.skill_id
    left join public.project_resource_needs need on need.id = event.resource_need_id
    where item.value->>'item_kind' = 'project_chat'
      and event.chat_id = (item.value->>'chat_id')::uuid
      and private.profile_can_read_project_chat_message(
        (item.value->>'project_id')::uuid, actor, event.created_at)
    order by event.created_at desc, event.id desc limit 1
  ) system_activity on true;
  return result;
end;
$$;
revoke all on function public.list_own_scoped_conversation_items_v4(uuid,text,integer,timestamptz,text,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_own_scoped_conversation_items_v4(uuid,text,integer,timestamptz,text,uuid)
  to authenticated;
comment on function public.list_own_scoped_conversation_items_v4(uuid,text,integer,timestamptz,text,uuid) is
  'V3 plus pair latest request status and latest visible group system label; null selects human/empty preview. Human wins exact timestamp ties. No authorization, unread or cursor changes.';
