create function public.get_own_blocked_profile_status(
  p_expected_blocker_profile_id uuid,
  p_target_profile_id uuid
)
returns table (
  block_episode_id uuid,
  blocked_profile_id uuid,
  blocked_display_name text,
  blocked_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_blocking_profile(
    p_expected_blocker_profile_id
  );
begin
  if p_target_profile_id is null or p_target_profile_id = current_profile_id then
    raise exception using
      errcode = '22023',
      message = 'A distinct target profile is required.';
  end if;

  return query
  select
    episode.id,
    episode.blocked_profile_id,
    profile.display_name,
    episode.blocked_at
  from private.user_block_episodes as episode
  join public.profiles as profile on profile.id = episode.blocked_profile_id
  where episode.blocker_profile_id = current_profile_id
    and episode.blocked_profile_id = p_target_profile_id
    and episode.unblocked_at is null
  limit 1;
end;
$$;

revoke all privileges on function public.get_own_blocked_profile_status(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.get_own_blocked_profile_status(uuid, uuid)
  to authenticated;

comment on function public.get_own_blocked_profile_status(uuid, uuid) is
  'Returns zero or one caller-owned active outbound block for one exact target. It deliberately exposes no inbound, reciprocal, moderation, or private-profile state.';
