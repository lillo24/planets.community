create or replace function public.remove_project_member_as_manager(
  p_expected_manager_profile_id uuid,
  p_membership_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
  membership_record public.project_memberships%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(
    membership_record.project_id,
    false
  );

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if not private.profile_is_project_manager(
    membership_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can remove a participant.';
  end if;

  if membership_record.participant_profile_id = current_profile_id then
    raise exception using
      errcode = '55000',
      message = 'A Project manager cannot remove their own participant membership. Leave the Project instead.';
  end if;

  if membership_record.left_at is not null
    or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current Project membership can be removed.';
  end if;

  update public.project_memberships
  set
    removed_at = transition_time,
    removed_by_profile_id = current_profile_id
  where id = membership_record.id;

  perform private.record_project_participation_event(
    'project.participant_removed',
    current_profile_id,
    membership_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'membership_id', membership_record.id,
      'participant_profile_id', membership_record.participant_profile_id,
      'status', 'removed'
    )
  );

  return membership_record.id;
end;
$$;

comment on function public.remove_project_member_as_manager(uuid, uuid) is
  'Ends another profile current membership as an owner or active delegate; managers must use leave_project for their own independent membership.';
