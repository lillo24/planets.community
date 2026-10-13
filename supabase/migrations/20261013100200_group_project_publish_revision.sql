-- New clients bind their deliberate publication to the confirmed selection.
-- Legacy publishers remain supported and share the source-level live guard.
create function public.publish_project_with_group(p_expected_profile_id uuid,p_project_id uuid,
  p_expected_version bigint,p_group_id uuid,p_idea boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid := private.require_group_identity(p_expected_profile_id);
  project public.projects%rowtype;
begin
  perform 1 from public.proposals where id=p_project_id for update;
  perform 1 from public.recurring_activities where id=p_project_id for update;
  select * into project from public.projects where id=p_project_id for update;
  perform private.require_group_identity(p_expected_profile_id);
  if project.id is null or project.creator_profile_id<>actor then
    raise sqlstate '42501' using message='The Project is unavailable.';
  end if;
  if p_expected_version is null or project.attribution_version<>p_expected_version
    or project.attributed_group_id is distinct from p_group_id then
    raise sqlstate 'PT409' using message='Project attribution changed. Reload before publishing.';
  end if;
  if p_idea is null then raise sqlstate '22023' using message='A publication kind is required.'; end if;
  if project.project_kind='recurring' then
    if p_idea then raise sqlstate '22023' using message='A Tavolo cannot be an Idea.'; end if;
    return public.publish_recurring_activity(actor,p_project_id);
  elsif p_idea then return public.publish_proposal_idea(actor,p_project_id);
  else return public.publish_proposal(actor,p_project_id); end if;
end;
$$;
revoke all on function public.publish_project_with_group(uuid,uuid,bigint,uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function public.publish_project_with_group(uuid,uuid,bigint,uuid,boolean) to authenticated;
