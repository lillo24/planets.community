-- Compose canonical conversation counts without changing either installed
-- lane's reader. Project folders are visual aliases, never another unread item.
create function public.get_own_message_unread_summary_with_contacts_and_discussions(
  p_expected_profile_id uuid
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.require_group_identity(p_expected_profile_id);
  contacts jsonb;
  discussions jsonb;
  legacy jsonb;
begin
  contacts := public.get_own_message_unread_summary_v3(actor);
  discussions := public.get_own_message_unread_summary_with_discussions(actor);
  legacy := public.get_own_message_unread_summary(actor);
  return jsonb_build_object(
    'total', (contacts->>'total')::bigint + (discussions->>'total')::bigint - (legacy->>'total')::bigint,
    'private', (contacts->>'private')::bigint,
    'groups', (contacts->>'groups')::bigint + (discussions->>'groups')::bigint - (legacy->>'groups')::bigint
  );
end;
$$;
revoke all on function public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.get_own_message_unread_summary_with_contacts_and_discussions(uuid)
  to authenticated;
comment on function public.get_own_message_unread_summary_with_contacts_and_discussions(uuid) is
  'Authenticated complete conversation counts: canonical D/M v3 plus C discussion delta, with legacy counted once and Project folders excluded as aliases. Installed lane readers retain their contracts.';

-- A named Group People action needs eligible destinations, not chat summaries.
-- Reuse C's current reader/manager/admission and invitation-availability rules
-- before pagination; preferences never create or revoke invitation authority.
create function public.list_group_discussion_invite_destinations(
  p_expected_profile_id uuid,
  p_group_id uuid,
  p_profile_id uuid,
  p_limit integer default 25,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.require_group_identity(p_expected_profile_id);
begin
  perform private.group_discussion_page(p_limit,p_before_created_at,p_before_id);
  if p_group_id is null or p_profile_id is null or p_profile_id=actor then
    raise sqlstate '22023' using message='The invitation context is invalid.';
  end if;
  if not private.group_discussion_person_current(p_group_id,actor)
    or not private.group_discussion_person_current(p_group_id,p_profile_id)
    or private.has_active_user_block_between(actor,p_profile_id) then
    raise sqlstate '42501' using message='The invitation context is unavailable.';
  end if;
  return (select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc,page.room_id desc),'[]'::jsonb)
    from (
      select r.id room_id,r.group_id,p_profile_id target_profile_id,r.title,
        coalesce(r.purpose,'') purpose,r.visibility,r.created_at
      from private.group_discussions r
      where r.group_id=p_group_id and r.kind='idea' and not r.archived and r.frozen_at is null
        and private.group_discussion_can_read_current(r.id,actor)
        and (private.group_discussion_can_manage(r.id,actor)
          or r.visibility='group' and private.group_discussion_admission(r.id,actor) is not null)
        and private.group_discussion_admission(r.id,p_profile_id) is null
        and not exists(select 1 from private.group_discussion_invitations i
          where i.room_id=r.id and i.recipient_id=p_profile_id and i.status='pending'
            and private.group_discussion_invitation_available(i.id))
        and (p_before_id is null or (r.created_at,r.id)<(p_before_created_at,p_before_id))
      order by r.created_at desc,r.id desc limit p_limit
    ) page);
end;
$$;
revoke all on function public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid)
  to authenticated;
comment on function public.list_group_discussion_invite_destinations(uuid,uuid,uuid,integer,timestamptz,uuid) is
  'Read-only target-bound Group People Idea destinations, authorized before limit; no preview, history, roster, unread, invitation/source/grant IDs or membership changes. Existing canonical invite command rechecks all predicates under locks.';
