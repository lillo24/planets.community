-- GROUPCOVER01: preserve v4 clients; add only a bounded, authorized image hint.
create function public.list_own_scoped_conversation_items_v5(
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
    'group_cover_object_path', case
      when item.value->>'item_kind' = 'project_chat'
        and public.can_read_public_cover_image_object(cover.object_path)
      then cover.object_path else null end
    ) order by item.ordinality), '[]'::jsonb) into result
  from jsonb_array_elements(public.list_own_scoped_conversation_items_v4(
    actor, p_scope, p_limit, p_cursor_activity_at, p_cursor_item_kind, p_cursor_chat_id
  )) with ordinality item(value, ordinality)
  left join public.project_covers cover
    on item.value->>'item_kind' = 'project_chat'
    and cover.project_id = (item.value->>'project_id')::uuid;
  return result;
end;
$$;
revoke all on function public.list_own_scoped_conversation_items_v5(uuid,text,integer,timestamptz,text,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_own_scoped_conversation_items_v5(uuid,text,integer,timestamptz,text,uuid)
  to authenticated;
comment on function public.list_own_scoped_conversation_items_v5(uuid,text,integer,timestamptz,text,uuid) is
  'V4 plus nullable current Project/Tavolo cover path, only when existing public Storage authorization permits it. Private kinds always null. No entitlement, unread, cursor or Storage-policy changes.';
