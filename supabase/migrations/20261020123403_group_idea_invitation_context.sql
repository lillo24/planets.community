-- Targeted consent needs purpose and audience before admission. Keep the legacy
-- strict eight-field reader unchanged; delegate eligibility, ordering and cursor
-- validation to it, then enrich only its already-authorized bounded result.
create function public.list_group_discussion_invitations_v2(
  p_expected_profile_id uuid,
  p_limit integer default 25,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(
    item.value || jsonb_build_object('purpose',r.purpose,'visibility',r.visibility)
    order by item.ordinality
  ),'[]'::jsonb)
  from jsonb_array_elements(public.list_group_discussion_invitations(
    p_expected_profile_id,p_limit,p_before_created_at,p_before_id
  )) with ordinality item(value,ordinality)
  join private.group_discussions r on r.id=(item.value->>'room_id')::uuid;
$$;

revoke all on function public.list_group_discussion_invitations_v2(uuid,integer,timestamptz,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.list_group_discussion_invitations_v2(uuid,integer,timestamptz,uuid)
  to authenticated;
comment on function public.list_group_discussion_invitations_v2(uuid,integer,timestamptz,uuid)
  is 'Pending targeted consent only: authorized title, purpose, audience and sender context; no history, admission, roster or links.';
