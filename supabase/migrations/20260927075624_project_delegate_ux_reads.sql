create function public.get_own_project_management_role(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  management_role text;
begin
  select case
    when project.creator_profile_id = current_profile_id then 'owner'
    when private.profile_is_project_manager(project.id, current_profile_id)
      then 'delegate'
    else 'none'
  end
  into management_role
  from public.projects as project
  where project.id = p_project_id;

  return coalesce(management_role, 'none');
end;
$$;

comment on function public.get_own_project_management_role(uuid, uuid) is
  'Identity-bound owner/delegate/none result for one exact Project. It discloses no manager roster or participation data.';

create function public.list_own_delegated_projects(
  p_expected_profile_id uuid
)
returns table (
  project_id uuid,
  project_kind text,
  project_title text,
  project_status text,
  delegated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
begin
  return query
  select
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then activity.title
    end,
    case project.project_kind
      when 'one_time' then case
        when proposal.lifecycle_state = 'cancelled' then 'cancelled'
        when proposal.ends_at <= statement_timestamp() then 'completed'
        else proposal.lifecycle_state
      end
      when 'recurring' then activity.lifecycle_state
    end,
    delegate.delegated_at
  from public.project_delegates as delegate
  join public.projects as project on project.id = delegate.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where delegate.delegate_profile_id = current_profile_id
    and delegate.revoked_at is null
    and (
      (
        project.project_kind = 'one_time'
        and proposal.id is not null
        and proposal.lifecycle_state <> 'draft'
      )
      or (
        project.project_kind = 'recurring'
        and activity.id is not null
        and activity.lifecycle_state <> 'draft'
      )
    )
  order by delegate.delegated_at desc, project.id;
end;
$$;

comment on function public.list_own_delegated_projects(uuid) is
  'Lists the current profile active co-organizer relationships with public card/navigation fields only; owner drafts remain excluded.';

revoke all on function public.get_own_project_management_role(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.list_own_delegated_projects(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.get_own_project_management_role(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_delegated_projects(uuid)
  to authenticated;
