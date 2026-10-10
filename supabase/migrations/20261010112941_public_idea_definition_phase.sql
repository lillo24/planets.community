-- IDEA01A: independent definition phase; legacy rows retain Defined via a constant
-- default. No published data/logistics are rewritten and no provider is enabled.
alter table public.proposals add column definition_phase text not null default 'defined'
  constraint proposals_definition_phase_valid check (definition_phase in ('defined','idea'));
comment on column public.proposals.definition_phase is
  'Server-owned planning phase, independent of draft/published/cancelled. Idea dates are tentative and never derive event completion. Only explicit promotion enters Defined.';
create index proposals_publication_cursor_v2_idx on public.proposals(published_at desc,id desc)
  where lifecycle_state='published';

create function private.is_public_idea(p_project_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.proposals where id=p_project_id
   and lifecycle_state='published' and definition_phase='idea')
$$;
revoke all on function private.is_public_idea(uuid) from public,anon,authenticated,service_role;

create function private.assert_idea_publishable(p_proposal_id uuid)
returns void language plpgsql stable security definer set search_path='' as $$
declare p public.proposals%rowtype;
begin
 select * into p from public.proposals where id=p_proposal_id;
 if p.id is null or p.title is null or p.title !~ '[[:alnum:]]'
   or p.summary is null or char_length(p.summary)<10 or p.summary !~ '[[:alnum:]]' then
  raise exception using errcode='PT422',message='An Idea needs a title and a meaningful short explanation (10–240 characters).';
 end if;
 if (p.starts_at is not null and not isfinite(p.starts_at))
   or (p.ends_at is not null and not isfinite(p.ends_at))
   or (p.starts_at is not null and p.ends_at is not null and p.ends_at<=p.starts_at) then
  raise exception using errcode='22023',message='Tentative dates must be finite and ordered.';
 end if;
 if p.event_timezone is not null and not exists(
   select 1 from pg_catalog.pg_timezone_names z where z.name=p.event_timezone) then
  raise exception using errcode='22023',message='A supplied time zone must be a recognized IANA identifier.';
 end if;
 if not exists(select 1 from public.proposal_meeting_details where proposal_id=p.id) then
  raise exception using errcode='55000',message='The protected meeting record is unavailable.';
 end if;
end;
$$;
revoke all on function private.assert_idea_publishable(uuid) from public,anon,authenticated,service_role;


CREATE OR REPLACE FUNCTION private.assert_defined_proposal_publishable(p_proposal_id uuid, p_require_future_start boolean)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  proposal public.proposals%rowtype;
  meeting public.proposal_meeting_details%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id;

  select * into meeting
  from public.proposal_meeting_details
  where proposal_id = p_proposal_id;

  if proposal.title is null
    or proposal.summary is null
    or proposal.description is null
    or proposal.starts_at is null
    or proposal.ends_at is null
    or proposal.event_timezone is null
    or proposal.country_code is null
    or proposal.locality is null
    or proposal.public_location_label is null
    or meeting.proposal_id is null then
    raise exception using
      errcode = '22023',
      message = 'Published proposals require complete content, schedule, and public locality.';
  end if;

  if proposal.ends_at <= proposal.starts_at then
    raise exception using
      errcode = '22023',
      message = 'Proposal end time must be later than its start time.';
  end if;

  if proposal.ends_at <= statement_timestamp() then
    raise exception using
      errcode = '22023',
      message = 'A proposal cannot be published after it has ended.';
  end if;

  if p_require_future_start and proposal.starts_at <= statement_timestamp() then
    raise exception using
      errcode = '55000',
      message = 'A published proposal cannot be edited after it starts.';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_timezone_names as time_zone
    where time_zone.name = proposal.event_timezone
  ) then
    raise exception using
      errcode = '22023',
      message = 'Proposal time zone must be a recognized IANA identifier.';
  end if;
end;
$function$;

revoke all on function private.assert_defined_proposal_publishable(uuid,boolean) from public,anon,authenticated,service_role;
create or replace function private.assert_proposal_publishable(p_proposal_id uuid,p_require_future_start boolean)
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if private.is_public_idea(p_proposal_id) then perform private.assert_idea_publishable(p_proposal_id);
 else perform private.assert_defined_proposal_publishable(p_proposal_id,p_require_future_start);
 end if;
end;
$$;


-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION private.lock_project_for_participation(p_project_id uuid, p_require_joinable boolean)
 RETURNS TABLE(project_kind text, creator_profile_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_is_joinable boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    into source_creator_profile_id, source_is_joinable
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state = 'published'
    into source_creator_profile_id, source_is_joinable
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if p_require_joinable and not source_is_joinable then
    raise exception using
      errcode = '55000',
      message = 'This project is not accepting participation requests.';
  end if;

  -- Every participation transition locks the concrete row first and the shared row second.
  -- This prevents lifecycle changes from crossing a request/accept decision boundary.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION private.lock_project_for_delegate_management(p_project_id uuid, p_require_operational boolean)
 RETURNS TABLE(project_kind text, owner_profile_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
  source_owner_profile_id uuid;
  source_is_operational boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The Project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    into source_owner_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  else
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_owner_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_owner_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The Project registry is inconsistent with its concrete activity.';
  end if;

  if p_require_operational and source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Delegate collaboration is unavailable for this Project lifecycle.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query
  select registry.project_kind, registry.creator_profile_id;
end;
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION private.lock_project_for_membership_commitment_mutation(p_project_id uuid)
 RETURNS TABLE(project_kind text, creator_profile_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_is_operational boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    into source_creator_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_creator_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Membership commitments can only change while the Project is operational.';
  end if;

  -- Match participation/resource transitions: concrete Project first, shared
  -- Project second. The caller then locks membership and resource rows.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION private.lock_project_for_live_requirement_coverage(p_project_id uuid, p_require_operational boolean DEFAULT true)
 RETURNS TABLE(project_kind text, creator_profile_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_is_operational boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    into source_creator_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_creator_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if p_require_operational and source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Live requirement coverage is available only while the Project is operational.';
  end if;

  -- Preserve the established global order: concrete Proposal/Tavolo, shared
  -- Project, membership when applicable, then resource need when applicable.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION private.project_allows_delegate_collaboration(p_project_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    return false;
  end if;

  if registry.project_kind = 'one_time' then
    return exists (
      select 1
      from public.proposals as proposal
      where proposal.id = registry.id
        and proposal.creator_profile_id = registry.creator_profile_id
        and proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    );
  end if;

  return exists (
    select 1
    from public.recurring_activities as activity
    where activity.id = registry.id
      and activity.creator_profile_id = registry.creator_profile_id
      and activity.lifecycle_state in ('published', 'paused')
  );
end;
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION private.project_has_live_coverage_lifecycle(p_project_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case project.project_kind
    when 'one_time' then exists (
      select 1
      from public.proposals as proposal
      where proposal.id = project.id
        and proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    )
    when 'recurring' then exists (
      select 1
      from public.recurring_activities as activity
      where activity.id = project.id
        and activity.lifecycle_state in ('published', 'paused')
    )
    else false
  end
  from public.projects as project
  where project.id = p_project_id
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION public.list_own_project_membership_commitment_options(p_expected_profile_id uuid, p_membership_id uuid)
 RETURNS TABLE(option_kind text, option_id uuid, label text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  membership_record public.project_memberships%rowtype;
  registry public.projects%rowtype;
  source_owner_profile_id uuid;
  source_is_operational boolean;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The membership commitment options are unavailable.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = membership_record.project_id;

  if not found
    or (
      membership_record.participant_profile_id <> current_profile_id
      and not private.profile_is_project_manager(
        membership_record.project_id,
        current_profile_id
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'The membership commitment options are unavailable.';
  end if;

  if membership_record.left_at is not null
    or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current membership can list commitment options.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
    into source_owner_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id;
  else
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_owner_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id;
  end if;

  if not found or source_owner_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The Project registry is inconsistent with its concrete activity.';
  end if;

  if source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Membership commitments can only change while the Project is operational.';
  end if;

  return query
  with ordered_options as (
    select
      'skill'::text as resolved_kind,
      available_skill.skill_id as resolved_id,
      skill.label as resolved_label,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from public.proposal_skills as available_skill
    join public.skills as skill on skill.id = available_skill.skill_id
    join public.skill_categories as category on category.id = skill.category_id
    where registry.project_kind = 'one_time'
      and available_skill.proposal_id = membership_record.project_id

    union all

    select
      'resource'::text,
      resource_need.id,
      resource_need.title,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from public.project_resource_needs as resource_need
    where resource_need.project_id = membership_record.project_id
      and resource_need.state = 'open'
  )
  select
    ordered.resolved_kind,
    ordered.resolved_id,
    ordered.resolved_label
  from ordered_options as ordered
  order by
    ordered.kind_order,
    ordered.category_order,
    ordered.item_order,
    ordered.resource_created_at,
    ordered.resolved_id;
end;
$function$;

-- Idea collaboration uses lifecycle, never tentative event time.
CREATE OR REPLACE FUNCTION public.list_public_project_resource_needs(p_project_id uuid)
 RETURNS TABLE(resource_need_id uuid, title text, details text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    need.id,
    need.title,
    need.details,
    need.created_at
  from public.project_resource_needs as need
  join public.projects as project on project.id = need.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where need.project_id = p_project_id
    and need.state = 'open'
    and (
      (
        project.project_kind = 'one_time'
        and proposal.lifecycle_state = 'published'
        and (proposal.definition_phase = 'idea' or (proposal.ends_at is not null and statement_timestamp() < proposal.ends_at))
      )
      or (
        project.project_kind = 'recurring'
        and activity.lifecycle_state = 'published'
      )
    )
  order by need.created_at, need.id
$function$;

CREATE OR REPLACE FUNCTION private.is_project_cover_editable(p_project_id uuid, p_creator_profile_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and project.creator_profile_id = p_creator_profile_id
      and (
        (
          project.project_kind = 'one_time'
          and exists (
            select 1
            from public.proposals as proposal
            where proposal.id = project.id
              and proposal.creator_profile_id = p_creator_profile_id
              and (
                proposal.lifecycle_state = 'draft'
                or (
                  proposal.lifecycle_state = 'published'
                  and (proposal.definition_phase = 'idea' or proposal.starts_at > statement_timestamp())
                )
              )
          )
        )
        or (
          project.project_kind = 'recurring'
          and exists (
            select 1
            from public.recurring_activities as activity
            where activity.id = project.id
              and activity.creator_profile_id = p_creator_profile_id
              and activity.lifecycle_state in ('draft', 'published', 'paused')
          )
        )
      )
  )
$function$;

CREATE OR REPLACE FUNCTION private.lock_owned_editable_project_cover_parent(p_creator_profile_id uuid, p_project_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  parent_project_kind text;
  source_creator_profile_id uuid;
  source_is_editable boolean;
begin
  select project.project_kind
  into parent_project_kind
  from public.projects as project
  where project.id = p_project_id;

  if parent_project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'draft'
        or (
          proposal.lifecycle_state = 'published'
          and (proposal.definition_phase = 'idea' or proposal.starts_at > statement_timestamp())
        )
    into source_creator_profile_id, source_is_editable
    from public.proposals as proposal
    where proposal.id = p_project_id
    for update;
  elsif parent_project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('draft', 'published', 'paused')
    into source_creator_profile_id, source_is_editable
    from public.recurring_activities as activity
    where activity.id = p_project_id
    for update;
  end if;

  if parent_project_kind is null
    or source_creator_profile_id is null
    or source_creator_profile_id <> p_creator_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this Project.';
  end if;

  if not source_is_editable then
    raise exception using
      errcode = '55000',
      message = 'This Project cover can no longer be edited.';
  end if;

  perform 1
  from public.projects as project
  where project.id = p_project_id
    and project.project_kind = parent_project_kind
    and project.creator_profile_id = p_creator_profile_id
  for update;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The Project registry is inconsistent with its concrete activity.';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION private.lock_project_for_resource_need_mutation(p_project_id uuid)
 RETURNS TABLE(project_kind text, creator_profile_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_is_mutable boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'draft'
        or (
          proposal.lifecycle_state = 'published'
          and (proposal.definition_phase = 'idea' or proposal.starts_at > statement_timestamp())
        )
    into source_creator_profile_id, source_is_mutable
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('draft', 'published', 'paused')
    into source_creator_profile_id, source_is_mutable
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if source_is_mutable is not true then
    raise exception using
      errcode = '55000',
      message = 'This project can no longer manage resource needs.';
  end if;

  -- Keep the established transition order: concrete Proposal/Tavolo first,
  -- then the shared Project row, before locking a resource-need row.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.project_accepts_participant_invitations(p_project_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.projects p
    left join public.proposals proposal on proposal.id = p.id and p.project_kind = 'one_time'
    left join public.recurring_activities activity on activity.id = p.id and p.project_kind = 'recurring'
    where p.id = p_project_id and (
      (p.project_kind = 'one_time' and proposal.lifecycle_state = 'published'
        and (proposal.definition_phase='idea' or clock_timestamp() < proposal.ends_at))
      or (p.project_kind = 'recurring' and activity.lifecycle_state = 'published')
    )
  );
$function$;

CREATE OR REPLACE FUNCTION private.lock_location_item(p_actor uuid, p_kind text, p_item uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner_id uuid; state text; starts timestamptz; revision bigint;
begin
  if p_actor is null or not exists(select 1 from public.profiles where id=p_actor) then
    raise exception using errcode='42501',message='Location actor unavailable.';
  end if;
  if p_kind='one_time' then
    select creator_profile_id,lifecycle_state,starts_at,location_revision into owner_id,state,starts,revision
      from public.proposals where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state not in ('draft','published') or (state='published' and not private.is_public_idea(p_item) and starts<=statement_timestamp()) then
      raise exception using errcode='55000',message='Location item is immutable.';
    end if;
  elsif p_kind='recurring' then
    select creator_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.recurring_activities where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state='ended' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  elsif p_kind='resource' then
    select owner_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.resource_listings where id=p_item for update;
    if owner_id is null or owner_id<>p_actor then raise exception using errcode='42501',message='Location edit unavailable.'; end if;
    if state='closed' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return revision;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_own_proposal(p_expected_creator_profile_id uuid, p_proposal_id uuid, p_title text, p_summary text, p_description text, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone, p_event_timezone text, p_country_code text, p_locality text, p_administrative_area text, p_public_location_label text, p_exact_meeting_text text, p_exact_location_visibility text, p_skill_ids uuid[], p_skill_importances text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null
    or (
      proposal.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_proposal_id,
        current_profile_id
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.creator_profile_id <> current_profile_id
    and proposal.lifecycle_state = 'draft' then
    raise exception using
      errcode = '42501',
      message = 'Only the original Creator can edit a proposal draft.';
  end if;

  if proposal.lifecycle_state = 'published'
    and proposal.definition_phase = 'defined'
    and proposal.starts_at <= statement_timestamp() then
    raise exception using
      errcode = '55000',
      message = 'A published proposal cannot be edited after it starts.';
  end if;

  if proposal.lifecycle_state not in ('draft', 'published') then
    raise exception using
      errcode = '55000',
      message = 'This proposal can no longer be edited.';
  end if;

  perform private.replace_proposal_content(
    p_proposal_id,
    p_title,
    p_summary,
    p_description,
    p_starts_at,
    p_ends_at,
    p_event_timezone,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_exact_meeting_text,
    p_exact_location_visibility,
    p_skill_ids,
    p_skill_importances
  );

  if proposal.lifecycle_state = 'published' then
    perform private.assert_proposal_publishable(p_proposal_id, true);
  end if;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  ) values (
    'proposal.updated',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.updated',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_proposal(p_expected_creator_profile_id uuid, p_proposal_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null
    or not private.profile_has_project_structural_authority(
      p_proposal_id,
      current_profile_id
    ) then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.lifecycle_state <> 'published' then
    raise exception using
      errcode = '55000',
      message = 'Only a published proposal can be cancelled.';
  end if;

  if proposal.definition_phase = 'defined' and proposal.ends_at <= statement_timestamp() then
    raise exception using
      errcode = '55000',
      message = 'A proposal cannot be cancelled after it ends.';
  end if;

  update public.proposals
  set
    lifecycle_state = 'cancelled',
    cancelled_at = statement_timestamp()
  where id = p_proposal_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  ) values (
    'proposal.cancelled',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.cancelled',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.set_project_registration_capacity_for_structural_edit(p_expected_profile_id uuid, p_project_id uuid, p_registration_capacity integer, p_count_organizers_toward_capacity boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_profile_id
  );
  resolved_project_kind text;
  resolved_creator_profile_id uuid;
  resolved_lifecycle_state text;
  resolved_starts_at timestamptz;
  prior_count_organizers boolean;
  capacity_record record;
  proposed_capacity_used integer;
begin
  if p_registration_capacity is not null
    and p_registration_capacity not between 1 and 100000 then
    raise exception using
      errcode = '22023',
      message = 'Registration capacity must be between 1 and 100,000.';
  end if;

  if p_count_organizers_toward_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'The organizer-capacity setting is required.';
  end if;

  select project.project_kind into resolved_project_kind
  from public.projects as project
  where project.id = p_project_id;

  if resolved_project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state,
      proposal.starts_at
    into resolved_creator_profile_id, resolved_lifecycle_state, resolved_starts_at
    from public.proposals as proposal
    where proposal.id = p_project_id
    for update;

    if not found
      or (
        resolved_creator_profile_id <> current_profile_id
        and not private.profile_has_project_structural_authority(
          p_project_id,
          current_profile_id
        )
      ) then
      raise exception using
        errcode = '42501',
        message = 'The Project capacity is unavailable.';
    end if;

    if resolved_creator_profile_id <> current_profile_id
      and resolved_lifecycle_state = 'draft' then
      raise exception using
        errcode = '42501',
        message = 'Only the original Creator can edit a Project draft.';
    end if;

    if resolved_lifecycle_state = 'published'
      and not private.is_public_idea(p_project_id)
      and resolved_starts_at <= statement_timestamp() then
      raise exception using
        errcode = '55000',
        message = 'A published Proposal capacity cannot be edited after it starts.';
    end if;

    if resolved_lifecycle_state not in ('draft', 'published') then
      raise exception using
        errcode = '55000',
        message = 'This Proposal capacity can no longer be edited.';
    end if;
  elsif resolved_project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state
    into resolved_creator_profile_id, resolved_lifecycle_state
    from public.recurring_activities as activity
    where activity.id = p_project_id
    for update;

    if not found
      or (
        resolved_creator_profile_id <> current_profile_id
        and not private.profile_has_project_structural_authority(
          p_project_id,
          current_profile_id
        )
      ) then
      raise exception using
        errcode = '42501',
        message = 'The Project capacity is unavailable.';
    end if;

    if resolved_creator_profile_id <> current_profile_id
      and resolved_lifecycle_state = 'draft' then
      raise exception using
        errcode = '42501',
        message = 'Only the original Creator can edit a Project draft.';
    end if;

    if resolved_lifecycle_state = 'ended' then
      raise exception using
        errcode = '55000',
        message = 'An ended Tavolo capacity is immutable.';
    end if;
  else
    raise exception using
      errcode = '42501',
      message = 'The Project capacity is unavailable.';
  end if;

  select project.count_organizers_toward_capacity
  into prior_count_organizers
  from public.projects as project
  where project.id = p_project_id
    and project.project_kind = resolved_project_kind
    and project.creator_profile_id = resolved_creator_profile_id
  for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The Project capacity is unavailable.';
  end if;

  select * into capacity_record
  from private.project_registration_capacity_snapshot(p_project_id);

  proposed_capacity_used := capacity_record.ordinary_participant_count + case
    when p_count_organizers_toward_capacity then capacity_record.organizer_count
    else 0
  end;

  if resolved_lifecycle_state <> 'draft'
    and not private.is_public_idea(p_project_id)
    and p_registration_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'Registration capacity is required for a published Project.';
  end if;

  if p_registration_capacity is not null
    and p_registration_capacity < proposed_capacity_used then
    if p_count_organizers_toward_capacity and not prior_count_organizers then
      raise exception using
        errcode = 'PT409',
        message = 'Increase registration capacity before counting organizers toward capacity.';
    end if;
    raise exception using
      errcode = '22023',
      message = 'Registration capacity cannot be lower than current capacity usage.';
  end if;

  update public.projects
  set
    registration_capacity = p_registration_capacity,
    count_organizers_toward_capacity = p_count_organizers_toward_capacity
  where id = p_project_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_capacity_for_project_publication()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  configured_capacity integer;
begin
  if tg_table_name='proposals' then
    if new.definition_phase='idea' then return new; end if;
  end if;
  if old.lifecycle_state = 'draft' and new.lifecycle_state = 'published' then
    select project.registration_capacity into configured_capacity
    from public.projects as project
    where project.id = new.id
    for update;

    if configured_capacity is null then
      raise exception using
        errcode = '22023',
        message = 'Registration capacity is required before publication.';
    end if;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_capacity_for_legacy_structural_edit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  target_project_id uuid;
  target_lifecycle text;
  configured_capacity integer;
begin
  if tg_table_name='proposals' then
    if new.definition_phase='idea' then return coalesce(new,old); end if;
  end if;
  if tg_table_name = 'proposals' then
    target_project_id := new.id;
    target_lifecycle := new.lifecycle_state;
  elsif tg_table_name = 'recurring_activities' then
    target_project_id := new.id;
    target_lifecycle := new.lifecycle_state;
  elsif tg_table_name = 'proposal_skills' then
    target_project_id := coalesce(new.proposal_id, old.proposal_id);
    select proposal.lifecycle_state into target_lifecycle
    from public.proposals as proposal
    where proposal.id = target_project_id;
  else
    target_project_id := coalesce(
      new.recurring_activity_id,
      old.recurring_activity_id
    );
    select activity.lifecycle_state into target_lifecycle
    from public.recurring_activities as activity
    where activity.id = target_project_id;
  end if;

  if target_lifecycle in ('published', 'paused') and not private.is_public_idea(target_project_id) then
    select project.registration_capacity into configured_capacity
    from public.projects as project
    where project.id = target_project_id;

    if configured_capacity is null then
      raise exception using
        errcode = '22023',
        message = 'Set registration capacity before saving structural changes to this legacy Project.';
    end if;
  end if;

  return coalesce(new, old);
end;
$function$;

CREATE OR REPLACE FUNCTION private.lock_project_for_actual_contribution_mutation(p_project_id uuid)
 RETURNS TABLE(creator_profile_id uuid, project_ends_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_lifecycle_state text;
  source_ends_at timestamptz;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind <> 'one_time' then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended one-time Proposals.';
  end if;

  -- Preserve the established order: concrete Proposal, shared Project,
  -- membership in the caller, then resource rows when desired IDs require it.
  select
    proposal.creator_profile_id,
    proposal.lifecycle_state,
    proposal.ends_at
  into
    source_creator_profile_id,
    source_lifecycle_state,
    source_ends_at
  from public.proposals as proposal
  where proposal.id = registry.id
  for share;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if private.is_public_idea(p_project_id) or source_lifecycle_state <> 'published'
    or source_ends_at is null
    or statement_timestamp() < source_ends_at then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended published one-time Proposals.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.creator_profile_id, source_ends_at;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_project_membership_actual_contributions(p_expected_profile_id uuid, p_membership_id uuid)
 RETURNS TABLE(contribution_kind text, contribution_id uuid, label text, attribution_source text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  membership_record public.project_memberships%rowtype;
  registry public.projects%rowtype;
  proposal_record public.proposals%rowtype;
  baseline_eligible boolean;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The actual contributions are unavailable.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = membership_record.project_id;

  if not found
    or (
      membership_record.participant_profile_id <> current_profile_id
      and not private.profile_is_project_manager(
        membership_record.project_id,
        current_profile_id
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'The actual contributions are unavailable.';
  end if;

  if registry.project_kind <> 'one_time' then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended one-time Proposals.';
  end if;

  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = registry.id;

  if not found or proposal_record.creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if proposal_record.definition_phase <> 'defined' or proposal_record.lifecycle_state <> 'published'
    or proposal_record.ends_at is null
    or statement_timestamp() < proposal_record.ends_at then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended published one-time Proposals.';
  end if;

  baseline_eligible :=
    membership_record.joined_at <= proposal_record.ends_at
    and (
      coalesce(membership_record.left_at, membership_record.removed_at) is null
      or proposal_record.ends_at < coalesce(
        membership_record.left_at,
        membership_record.removed_at
      )
    );

  return query
  with baseline_skills as (
    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where baseline_eligible
      and commitment.membership_id = p_membership_id
  ),
  skill_candidates as (
    select baseline.skill_id from baseline_skills as baseline
    union
    select override_row.skill_id
    from public.project_membership_actual_skill_overrides as override_row
    where override_row.membership_id = p_membership_id
  ),
  effective_skills as (
    select
      candidate.skill_id,
      baseline.skill_id is not null as is_baseline
    from skill_candidates as candidate
    left join baseline_skills as baseline on baseline.skill_id = candidate.skill_id
    left join public.project_membership_actual_skill_overrides as override_row
      on override_row.membership_id = p_membership_id
      and override_row.skill_id = candidate.skill_id
    where coalesce(
      override_row.is_included,
      baseline.skill_id is not null
    )
  ),
  baseline_resources as (
    select commitment.resource_need_id
    from public.project_membership_resource_commitments as commitment
    where baseline_eligible
      and commitment.membership_id = p_membership_id
  ),
  resource_candidates as (
    select baseline.resource_need_id from baseline_resources as baseline
    union
    select override_row.resource_need_id
    from public.project_membership_actual_resource_overrides as override_row
    where override_row.membership_id = p_membership_id
  ),
  effective_resources as (
    select
      candidate.resource_need_id,
      baseline.resource_need_id is not null as is_baseline
    from resource_candidates as candidate
    left join baseline_resources as baseline
      on baseline.resource_need_id = candidate.resource_need_id
    left join public.project_membership_actual_resource_overrides as override_row
      on override_row.membership_id = p_membership_id
      and override_row.resource_need_id = candidate.resource_need_id
    where coalesce(
      override_row.is_included,
      baseline.resource_need_id is not null
    )
  ),
  ordered_contributions as (
    select
      'skill'::text as resolved_kind,
      effective.skill_id as resolved_id,
      skill.label as resolved_label,
      case
        when effective.is_baseline then 'final_commitment'::text
        else 'creator_added'::text
      end as resolved_source,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from effective_skills as effective
    join public.skills as skill on skill.id = effective.skill_id
    join public.skill_categories as category on category.id = skill.category_id

    union all

    select
      'resource'::text,
      effective.resource_need_id,
      resource_need.title,
      case
        when effective.is_baseline then 'final_commitment'::text
        else 'creator_added'::text
      end,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from effective_resources as effective
    join public.project_resource_needs as resource_need
      on resource_need.id = effective.resource_need_id

    union all

    select
      'substantial_effort'::text,
      null::uuid,
      null::text,
      'substantial_effort'::text,
      2::smallint,
      0::smallint,
      0::smallint,
      marker.marked_at
    from public.project_membership_actual_effort_markers as marker
    where marker.membership_id = p_membership_id
  )
  select
    contribution.resolved_kind,
    contribution.resolved_id,
    contribution.resolved_label,
    contribution.resolved_source
  from ordered_contributions as contribution
  order by
    contribution.kind_order,
    contribution.category_order,
    contribution.item_order,
    contribution.resource_created_at,
    contribution.resolved_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_project_membership_actual_contribution_options_for_manager(p_expected_manager_profile_id uuid, p_membership_id uuid)
 RETURNS TABLE(option_kind text, option_id uuid, label text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
  membership_record public.project_memberships%rowtype;
  registry public.projects%rowtype;
  proposal_record public.proposals%rowtype;
  baseline_eligible boolean;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The actual-contribution options are unavailable.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = membership_record.project_id;

  if not found or not private.profile_is_project_manager(
    membership_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The actual-contribution options are unavailable.';
  end if;

  if registry.project_kind <> 'one_time' then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended one-time Proposals.';
  end if;

  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = registry.id;

  if not found or proposal_record.creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if proposal_record.definition_phase <> 'defined' or proposal_record.lifecycle_state <> 'published'
    or proposal_record.ends_at is null
    or statement_timestamp() < proposal_record.ends_at then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended published one-time Proposals.';
  end if;

  baseline_eligible :=
    membership_record.joined_at <= proposal_record.ends_at
    and (
      coalesce(membership_record.left_at, membership_record.removed_at) is null
      or proposal_record.ends_at < coalesce(
        membership_record.left_at,
        membership_record.removed_at
      )
    );

  return query
  with available_skills as (
    select proposal_skill.skill_id
    from public.proposal_skills as proposal_skill
    where proposal_skill.proposal_id = membership_record.project_id

    union

    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where baseline_eligible
      and commitment.membership_id = p_membership_id
  ),
  ordered_options as (
    select
      'skill'::text as resolved_kind,
      available.skill_id as resolved_id,
      skill.label as resolved_label,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from available_skills as available
    join public.skills as skill on skill.id = available.skill_id
    join public.skill_categories as category on category.id = skill.category_id

    union all

    select
      'resource'::text,
      resource_need.id,
      resource_need.title,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from public.project_resource_needs as resource_need
    where resource_need.project_id = membership_record.project_id
  )
  select
    option_row.resolved_kind,
    option_row.resolved_id,
    option_row.resolved_label
  from ordered_options as option_row
  order by
    option_row.kind_order,
    option_row.category_order,
    option_row.item_order,
    option_row.resource_created_at,
    option_row.resolved_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.is_proposal_template_publicly_usable(p_template_id uuid, p_reference_time timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from private.proposal_templates as template
    join public.proposals as proposal on proposal.id = template.source_proposal_id
    join public.projects as project on project.id = proposal.id
    where template.id = p_template_id
      and p_reference_time is not null and isfinite(p_reference_time)
      and template.removed_at is null
      and project.project_kind = 'one_time'
      and proposal.lifecycle_state = 'published'
      and proposal.definition_phase = 'defined'
      and proposal.published_at is not null
      and proposal.starts_at is not null and proposal.ends_at is not null
      and private.derive_proposal_status(
        proposal.starts_at, proposal.ends_at, p_reference_time
      ) = 'completed'
      and private.is_project_publicly_viewable(proposal.id)
  )
$function$;

CREATE OR REPLACE FUNCTION public.list_project_resource_need_listing_matches(p_expected_creator_profile_id uuid, p_resource_need_id uuid, p_location_scope text, p_limit integer DEFAULT 20, p_listing_mode text DEFAULT NULL::text, p_cursor_text_match_kind text DEFAULT NULL::text, p_cursor_location_match_kind text DEFAULT NULL::text, p_cursor_published_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_listing_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(resource_need_id uuid, listing_id uuid, cover_object_path text, listing_mode text, title text, description text, country_code text, locality text, administrative_area text, public_location_label text, published_at timestamp with time zone, active_request_count bigint, text_match_kind text, location_match_kind text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_creator_profile_id
  );
  resource_need public.project_resource_needs%rowtype;
  project_record public.projects%rowtype;
  source_state text;
  source_ends_at timestamptz;
  source_country_code text;
  source_locality text;
  source_administrative_area text;
  normalized_mode text := pg_catalog.lower(pg_catalog.btrim(p_listing_mode));
  cursor_text_rank integer;
  cursor_location_rank integer;
begin
  if p_location_scope is null or p_location_scope not in (
    'same_locality', 'same_administrative_area', 'same_country', 'anywhere'
  ) then
    raise exception using errcode = '22023',
      message = 'An explicit valid Project resource matching location scope is required.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode = '22023',
      message = 'Project resource matching page size must be between 1 and 50.';
  end if;

  if normalized_mode is not null
    and normalized_mode not in ('donate', 'exchange') then
    raise exception using errcode = '22023',
      message = 'Project resource matching mode must be donate or exchange.';
  end if;

  if num_nonnulls(
    p_cursor_text_match_kind,
    p_cursor_location_match_kind,
    p_cursor_published_at,
    p_cursor_listing_id
  ) not in (0, 4) then
    raise exception using errcode = '22023',
      message = 'All Project resource matching cursor values must be supplied together.';
  end if;

  cursor_text_rank := case p_cursor_text_match_kind
    when 'title_phrase' then 1
    when 'need_title_in_listing_title' then 2
    when 'need_title_in_listing_description' then 3
    when 'need_details_in_listing_title' then 4
    when 'need_details_in_listing_description' then 5
  end;
  cursor_location_rank := case p_cursor_location_match_kind
    when 'same_locality' then 1
    when 'same_administrative_area' then 2
    when 'same_country' then 3
    when 'other_or_unknown' then 4
  end;

  if p_cursor_listing_id is not null and (
    cursor_text_rank is null or cursor_location_rank is null
  ) then
    raise exception using errcode = '22023',
      message = 'Project resource matching cursor reasons are invalid.';
  end if;

  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id;

  if not found then
    raise exception using errcode = 'P0002',
      message = 'The Project resource need does not exist.';
  end if;

  select * into project_record
  from public.projects as project
  where project.id = resource_need.project_id;

  if not found or project_record.creator_profile_id <> current_profile_id then
    raise exception using errcode = '42501',
      message = 'Only the Project creator can match its resource need.';
  end if;

  if resource_need.state <> 'open' then
    raise exception using errcode = '55000',
      message = 'Only an open Project resource need can be matched.';
  end if;

  if project_record.project_kind = 'one_time' then
    select
      proposal.lifecycle_state,
      proposal.ends_at,
      proposal.country_code,
      proposal.locality,
      proposal.administrative_area
    into
      source_state,
      source_ends_at,
      source_country_code,
      source_locality,
      source_administrative_area
    from public.proposals as proposal
    where proposal.id = project_record.id
      and proposal.creator_profile_id = current_profile_id;

    if not found then
      raise exception using errcode = '55000',
        message = 'The Project registry does not match its Proposal.';
    end if;

    if not (
      source_state = 'draft'
      or (source_state = 'published' and (private.is_public_idea(project_record.id) or source_ends_at > statement_timestamp()))
    ) then
      raise exception using errcode = '55000',
        message = 'The Proposal is no longer eligible for resource matching.';
    end if;
  elsif project_record.project_kind = 'recurring' then
    select
      activity.lifecycle_state,
      activity.country_code,
      activity.locality,
      activity.administrative_area
    into
      source_state,
      source_country_code,
      source_locality,
      source_administrative_area
    from public.recurring_activities as activity
    where activity.id = project_record.id
      and activity.creator_profile_id = current_profile_id;

    if not found then
      raise exception using errcode = '55000',
        message = 'The Project registry does not match its Tavolo.';
    end if;

    if source_state not in ('draft', 'published', 'paused') then
      raise exception using errcode = '55000',
        message = 'The Tavolo is no longer eligible for resource matching.';
    end if;
  else
    raise exception using errcode = '55000',
      message = 'The Project kind is not eligible for resource matching.';
  end if;

  if (source_locality is null and p_location_scope = 'same_locality')
    or (
      (source_country_code is null or source_administrative_area is null)
      and p_location_scope = 'same_administrative_area'
    )
    or (source_country_code is null and p_location_scope = 'same_country') then
    raise exception using errcode = '55000',
      message = 'The Project lacks rough geography required by the selected matching scope.';
  end if;

  return query
  with source_terms as materialized (
    select
      private.project_resource_match_or_query(resource_need.title) as title_query,
      private.project_resource_match_or_query(resource_need.details) as details_query,
      pg_catalog.lower(pg_catalog.regexp_replace(
        pg_catalog.btrim(resource_need.title), '\s+', ' ', 'g'
      )) as normalized_title
  ), candidates as (
    select
      listing.id,
      listing.published_at,
      reason.text_match_kind,
      reason.location_match_kind,
      case reason.text_match_kind
        when 'title_phrase' then 1
        when 'need_title_in_listing_title' then 2
        when 'need_title_in_listing_description' then 3
        when 'need_details_in_listing_title' then 4
        else 5
      end as text_rank,
      case reason.location_match_kind
        when 'same_locality' then 1
        when 'same_administrative_area' then 2
        when 'same_country' then 3
        else 4
      end as location_rank
    from public.resource_listings as listing
    cross join source_terms as terms
    cross join lateral private.evaluate_project_resource_listing_match(
      resource_need.title,
      resource_need.details,
      source_country_code,
      source_locality,
      source_administrative_area,
      listing.title,
      listing.description,
      listing.country_code,
      listing.locality,
      listing.administrative_area
    ) as reason
    where listing.lifecycle_state = 'published'
      and (normalized_mode is null or listing.listing_mode = normalized_mode)
      and (
        (
          terms.normalized_title <> ''
          and pg_catalog.strpos(
            pg_catalog.lower(pg_catalog.regexp_replace(
              pg_catalog.btrim(listing.title), '\s+', ' ', 'g'
            )),
            terms.normalized_title
          ) > 0
        )
        or (
          terms.title_query is not null
          and (
            pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.title, '')
            ) @@ terms.title_query
            or pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.description, '')
            ) @@ terms.title_query
          )
        )
        or (
          terms.details_query is not null
          and (
            pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.title, '')
            ) @@ terms.details_query
            or pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.description, '')
            ) @@ terms.details_query
          )
        )
      )
      and reason.is_match
      and (
        p_location_scope = 'anywhere'
        or (
          p_location_scope = 'same_locality'
          and pg_catalog.lower(pg_catalog.btrim(listing.locality)) =
            pg_catalog.lower(pg_catalog.btrim(source_locality))
        )
        or (
          p_location_scope = 'same_administrative_area'
          and listing.country_code = source_country_code
          and pg_catalog.lower(pg_catalog.btrim(listing.administrative_area)) =
            pg_catalog.lower(pg_catalog.btrim(source_administrative_area))
        )
        or (
          p_location_scope = 'same_country'
          and listing.country_code = source_country_code
        )
      )
  )
  select
    resource_need.id,
    candidate.id,
    public_listing.cover_object_path,
    public_listing.listing_mode,
    public_listing.title,
    public_listing.description,
    public_listing.country_code,
    public_listing.locality,
    public_listing.administrative_area,
    public_listing.public_location_label,
    candidate.published_at,
    public_listing.active_request_count,
    candidate.text_match_kind,
    candidate.location_match_kind
  from candidates as candidate
  cross join lateral public.get_public_resource_listing(candidate.id)
    as public_listing
  where p_cursor_listing_id is null
    or candidate.text_rank > cursor_text_rank
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank > cursor_location_rank
    )
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at < p_cursor_published_at
    )
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at = p_cursor_published_at
      and candidate.id < p_cursor_listing_id
    )
  order by
    candidate.text_rank,
    candidate.location_rank,
    candidate.published_at desc,
    candidate.id desc
  limit p_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_similar_active_proposals(p_expected_profile_id uuid, p_title text, p_skill_ids uuid[] DEFAULT NULL::uuid[], p_country_code text DEFAULT NULL::text, p_locality text DEFAULT NULL::text, p_excluded_proposal_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 5)
 RETURNS TABLE(proposal_id uuid, cover_object_path text, title text, summary text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, availability text, title_evidence text, shared_skill_ids uuid[], location_relation text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  reference_time timestamptz := pg_catalog.statement_timestamp();
  country text := pg_catalog.upper(pg_catalog.btrim(p_country_code));
  locality_hint text := nullif(pg_catalog.lower(pg_catalog.regexp_replace(
    pg_catalog.btrim(p_locality), '[[:space:]]+', ' ', 'g')), '');
  selected_skills uuid[];
  idea_words text[];
begin
  perform private.require_expected_identity(p_expected_profile_id);
  if p_title is null or pg_catalog.char_length(p_title) > 100 then
    raise exception using errcode = '22023',
      message = 'Idea title is required and must contain at most 100 characters.';
  end if;
  if p_limit is null or p_limit not between 1 and 10 then
    raise exception using errcode = '22023',
      message = 'Similar Proposal limit must be between 1 and 10.';
  end if;
  if p_country_code is not null and country !~ '^[A-Z]{2}$' then
    raise exception using errcode = '22023',
      message = 'Rough country code must contain two letters.';
  end if;
  if pg_catalog.char_length(p_locality) > 120 then
    raise exception using errcode = '22023',
      message = 'Rough locality must contain at most 120 characters.';
  end if;
  if p_skill_ids is not null and (
    pg_catalog.cardinality(p_skill_ids) > 50
    or coalesce(pg_catalog.array_ndims(p_skill_ids), 1) <> 1
  ) then
    raise exception using errcode = '22023',
      message = 'Selected skills must be a one-dimensional list of at most 50 IDs.';
  end if;
  if exists (
    select 1 from pg_catalog.unnest(p_skill_ids) as selected(id)
    where selected.id is null or not exists (
      select 1 from public.skills as skill where skill.id = selected.id
    )
  ) then
    raise exception using errcode = '22023',
      message = 'Selected skills must be known non-null controlled IDs.';
  end if;
  select coalesce(array_agg(distinct selected.id order by selected.id), array[]::uuid[])
    into selected_skills from pg_catalog.unnest(p_skill_ids) as selected(id);
  select coalesce(array_agg(word order by word), array[]::text[]) into idea_words
    from pg_catalog.unnest(private.proposal_idea_lexemes(p_title)) as words(word)
    where word <> all(private.proposal_idea_lexemes(p_locality));
  -- Weak input exits before candidate reads. Skills cannot admit rows.
  if pg_catalog.cardinality(idea_words) = 0 then return; end if;

  -- SIM01 candidate query: the plan verifier explains this exact query.
  return query
  with admitted as materialized (
    select proposal.*,
      topics.words as candidate_words,
      evidence.words as matching_words
    from public.proposals as proposal
    join public.projects as project on project.id = proposal.id
      and project.project_kind = 'one_time'
    cross join lateral (
      select coalesce(array_agg(word order by word), array[]::text[]) as words
      from pg_catalog.unnest(private.proposal_idea_lexemes(proposal.title)) as terms(word)
      where word <> all(private.proposal_idea_lexemes(proposal.locality))
        and word <> all(private.proposal_idea_lexemes(proposal.administrative_area))
    ) as topics
    cross join lateral (
      select coalesce(array_agg(word order by word), array[]::text[]) as words
      from pg_catalog.unnest(topics.words) as terms(word)
      where word = any(idea_words)
    ) as evidence
    where proposal.lifecycle_state = 'published'
      and proposal.definition_phase = 'defined'
      and proposal.starts_at > reference_time
      and pg_catalog.isfinite(proposal.starts_at)
      and pg_catalog.isfinite(proposal.ends_at)
      and proposal.ends_at > proposal.starts_at
      and private.derive_proposal_status(proposal.starts_at, proposal.ends_at, reference_time) = 'upcoming'
      and (p_excluded_proposal_id is null or proposal.id <> p_excluded_proposal_id)
      and private.proposal_idea_lexemes(proposal.title) && idea_words
      and pg_catalog.cardinality(evidence.words) > 0
      and private.is_project_publicly_viewable(proposal.id)
  ),
  ranked as (
    select candidate.*,
      pg_catalog.cardinality(candidate.matching_words)::numeric /
        greatest(pg_catalog.cardinality(idea_words), pg_catalog.cardinality(candidate.candidate_words)) as title_rank,
      shared.ids as shared_ids,
      case when capacity.registration_capacity is null then 'capacity_unknown'
        when capacity.is_full then 'full' else 'available' end as capacity_state,
      case when locality_hint is not null
        and (country is null or candidate.country_code = country)
        and pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(candidate.locality), '[[:space:]]+', ' ', 'g')) = locality_hint
        then 'same_locality'
        when country is not null and candidate.country_code = country then 'same_country'
        when country is null and locality_hint is null then 'not_provided'
        else 'other' end as rough_relation
    from admitted as candidate
    cross join lateral private.project_registration_capacity_snapshot(candidate.id) as capacity
    cross join lateral (
      select coalesce(array_agg(skill.skill_id order by skill.skill_id), array[]::uuid[]) as ids
      from public.proposal_skills as skill
      where skill.proposal_id = candidate.id and skill.skill_id = any(selected_skills)
    ) as shared
  )
  select candidate.id, cover.object_path, candidate.title, candidate.summary,
    candidate.starts_at, candidate.ends_at, candidate.event_timezone,
    candidate.country_code, candidate.locality, candidate.administrative_area,
    candidate.public_location_label, 'upcoming'::text, candidate.capacity_state,
    case when pg_catalog.cardinality(candidate.matching_words) > 1
      then 'multiple_title_terms' else 'title_topic' end,
    candidate.shared_ids, candidate.rough_relation
  from ranked as candidate
  left join public.project_covers as cover on cover.project_id = candidate.id
  order by candidate.title_rank desc,
    pg_catalog.cardinality(candidate.shared_ids) desc,
    case candidate.capacity_state when 'available' then 0 when 'capacity_unknown' then 1 else 2 end,
    case candidate.rough_relation when 'same_locality' then 0 when 'same_country' then 1 else 2 end,
    candidate.starts_at, candidate.id
  limit p_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION private.geo_public_candidates_v1(p_query jsonb, p_reference timestamp with time zone, p_after_kind text, p_after_id uuid)
 RETURNS TABLE(kind text, item_id uuid)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_center extensions.geography; v_box extensions.geometry;
begin
  if p_query->>'mode'='radius' then
    v_center:=extensions.st_setsrid(extensions.st_makepoint((p_query->>'longitude')::double precision,(p_query->>'latitude')::double precision),4326)::extensions.geography;
    return query
    (select 'one_time'::text, p.id from public.proposals p
    where p.lifecycle_state='published' and p.definition_phase='defined' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'one_time'
      and (p_after_kind is null or ('one_time'::text,p.id)>(p_after_kind,p_after_id))
      and p.ends_at > p_reference - interval '24 hours' and p.ends_at > statement_timestamp() - interval '24 hours'
      and (p_query->>'proposal_locality' is null or lower(p.locality)=p_query->>'proposal_locality')
      and (p_query->>'proposal_keyword' is null or strpos(lower(p.title),p_query->>'proposal_keyword')>0 or strpos(lower(p.summary),p_query->>'proposal_keyword')>0 or strpos(lower(p.description),p_query->>'proposal_keyword')>0)
      and (jsonb_array_length(p_query->'proposal_skill_ids')=0 or exists(select 1 from public.proposal_skills s where s.proposal_id=p.id and s.skill_id in (select value::uuid from jsonb_array_elements_text(p_query->'proposal_skill_ids'))))
      and extensions.st_dwithin(p.approximate_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001)
    union all
    (select 'recurring'::text, p.id from public.recurring_activities p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'recurring'
      and (p_after_kind is null or ('recurring'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'tavolo_locality' is null or lower(p.locality)=p_query->>'tavolo_locality')
      and extensions.st_dwithin(p.approximate_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001)
    union all
    (select 'resource'::text, p.id from public.resource_listings p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.public_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'resource'
      and (p_after_kind is null or ('resource'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'resource_locality' is null or lower(p.locality)=p_query->>'resource_locality')
      and (p_query->>'resource_mode' is null or p.listing_mode=p_query->>'resource_mode')
      and (p_query->>'resource_keyword' is null or strpos(lower(p.title),p_query->>'resource_keyword')>0 or strpos(lower(p.description),p_query->>'resource_keyword')>0)
      and extensions.st_dwithin(p.public_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001);
  else
    v_box:=extensions.st_makeenvelope((p_query->>'west')::double precision,(p_query->>'south')::double precision,(p_query->>'east')::double precision,(p_query->>'north')::double precision,4326);
    return query
    (select 'one_time'::text, p.id from public.proposals p
    where p.lifecycle_state='published' and p.definition_phase='defined' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'one_time'
      and (p_after_kind is null or ('one_time'::text,p.id)>(p_after_kind,p_after_id))
      and p.ends_at > p_reference - interval '24 hours' and p.ends_at > statement_timestamp() - interval '24 hours'
      and (p_query->>'proposal_locality' is null or lower(p.locality)=p_query->>'proposal_locality')
      and (p_query->>'proposal_keyword' is null or strpos(lower(p.title),p_query->>'proposal_keyword')>0 or strpos(lower(p.summary),p_query->>'proposal_keyword')>0 or strpos(lower(p.description),p_query->>'proposal_keyword')>0)
      and (jsonb_array_length(p_query->'proposal_skill_ids')=0 or exists(select 1 from public.proposal_skills s where s.proposal_id=p.id and s.skill_id in (select value::uuid from jsonb_array_elements_text(p_query->'proposal_skill_ids'))))
      and (p.approximate_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001)
    union all
    (select 'recurring'::text, p.id from public.recurring_activities p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'recurring'
      and (p_after_kind is null or ('recurring'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'tavolo_locality' is null or lower(p.locality)=p_query->>'tavolo_locality')
      and (p.approximate_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001)
    union all
    (select 'resource'::text, p.id from public.resource_listings p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.public_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'resource'
      and (p_after_kind is null or ('resource'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'resource_locality' is null or lower(p.locality)=p_query->>'resource_locality')
      and (p_query->>'resource_mode' is null or p.listing_mode=p_query->>'resource_mode')
      and (p_query->>'resource_keyword' is null or strpos(lower(p.title),p_query->>'resource_keyword')>0 or strpos(lower(p.description),p_query->>'resource_keyword')>0)
      and (p.public_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001);
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_public_proposal_v2(p_proposal_id uuid)
 RETURNS TABLE(proposal_id uuid, definition_phase text, cover_object_path text, creator_profile_id uuid, creator_display_name text, title text, summary text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb, exact_meeting_text text, exact_location_restricted boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    proposal.id,
    proposal.definition_phase,
    cover.object_path,
    proposal.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case when proposal.definition_phase='defined' then private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ) else null end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.exact_meeting_text
      else null
    end,
    meeting.exact_location_visibility = 'participants'
      and (meeting.exact_meeting_text is not null or meeting.exact_location is not null)
  from public.proposals as proposal
  join public.profiles as creator on creator.id = proposal.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
    and proposal.lifecycle_state = 'published'
$function$;

CREATE OR REPLACE FUNCTION public.get_own_proposal_v2(p_expected_creator_profile_id uuid, p_proposal_id uuid)
 RETURNS TABLE(proposal_id uuid, definition_phase text, cover_object_path text, lifecycle_state text, title text, summary text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb, exact_meeting_text text, exact_location_visibility text, created_at timestamp with time zone, updated_at timestamp with time zone, published_at timestamp with time zone, cancelled_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal_record public.proposals%rowtype;
begin
  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = p_proposal_id;

  if not found
    or (
      proposal_record.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_proposal_id,
        current_profile_id
      )
    )
    or (
      proposal_record.creator_profile_id <> current_profile_id
      and proposal_record.lifecycle_state = 'draft'
    ) then
    raise exception using
      errcode = '42501',
      message = 'The proposal management record is unavailable.';
  end if;

  return query
  select
    proposal.id,
    proposal.definition_phase,
    cover.object_path,
    proposal.lifecycle_state,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case
      when proposal.lifecycle_state = 'published' then case when proposal.definition_phase='defined' then private.derive_proposal_status(
        proposal.starts_at,
        proposal.ends_at,
        statement_timestamp()
      ) else null end
      else null
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_own_proposals_v2(p_expected_creator_profile_id uuid)
 RETURNS TABLE(proposal_id uuid, definition_phase text, cover_object_path text, lifecycle_state text, title text, summary text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb, exact_meeting_text text, exact_location_visibility text, created_at timestamp with time zone, updated_at timestamp with time zone, published_at timestamp with time zone, cancelled_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    proposal.id,
    proposal.definition_phase,
    cover.object_path,
    proposal.lifecycle_state,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case
      when proposal.lifecycle_state = 'published'
        then case when proposal.definition_phase='defined' then private.derive_proposal_status(
          proposal.starts_at,
          proposal.ends_at,
          statement_timestamp()
        ) else null end
      else null
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.creator_profile_id = current_profile_id
  order by proposal.created_at desc, proposal.id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_own_pending_requested_proposals_v2(p_expected_requester_profile_id uuid, p_locality text DEFAULT NULL::text, p_skill_ids uuid[] DEFAULT NULL::uuid[], p_query text DEFAULT NULL::text)
 RETURNS TABLE(proposal_id uuid, definition_phase text, cover_object_path text, request_id uuid, request_created_at timestamp with time zone, title text, summary text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if char_length(normalized_locality)>120 or cardinality(p_skill_ids)>100 then
    raise exception using errcode='22023',message='Requested Proposal filters exceed their supported bounds.';
  end if;
  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Requested Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    proposal.definition_phase,
    cover.object_path,
    request.id,
    request.created_at,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case when proposal.definition_phase='defined' then private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ) else null end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.project_join_requests as request
  join public.proposals as proposal on proposal.id = request.project_id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and proposal.lifecycle_state = 'published'
    and (proposal.definition_phase='idea' or proposal.ends_at > statement_timestamp() - interval '24 hours')
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
  order by request.created_at desc, proposal.id desc
  limit 200;
end;
$function$;

CREATE FUNCTION public.list_public_proposals_v2(p_limit integer default 20,p_cursor_published_at timestamptz default null,p_cursor_id uuid default null,p_locality text default null,p_skill_ids uuid[] default null,p_query text default null,p_definition_phase text default null,p_reference_time timestamptz default statement_timestamp())
 RETURNS TABLE(proposal_id uuid, definition_phase text, published_at timestamptz, reference_time timestamptz, cover_object_path text, title text, summary text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_reference_time is null or not isfinite(p_reference_time)
    or p_reference_time>statement_timestamp() or (p_definition_phase is not null and p_definition_phase not in ('idea','defined'))
    or char_length(normalized_locality)>120 or cardinality(p_skill_ids)>100 then
    raise exception using errcode='22023',message='Invalid discovery phase, reference time or filters.';
  end if;
  if p_cursor_id is not null and not exists(select 1 from public.proposals p
    where p.id=p_cursor_id and p.published_at=p_cursor_published_at
      and p.published_at<=p_reference_time and p.lifecycle_state in ('published','cancelled')) then
    raise exception using errcode='22023',message='Invalid publication cursor.';
  end if;
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Proposal page size must be between 1 and 50.';
  end if;

  if (p_cursor_published_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Proposal cursor values must be supplied together.';
  end if;

  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    proposal.definition_phase,
    proposal.published_at,
    p_reference_time,
    cover.object_path,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case when proposal.definition_phase='defined' then private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ) else null end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.proposals as proposal
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.lifecycle_state = 'published'
    and (proposal.definition_phase='idea' or proposal.ends_at > statement_timestamp() - interval '24 hours')
    and proposal.published_at <= p_reference_time
    and (p_definition_phase is null or proposal.definition_phase=p_definition_phase)
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
    and (
      p_cursor_published_at is null
      or (proposal.published_at, proposal.id) < (p_cursor_published_at, p_cursor_id)
    )
  order by proposal.published_at desc, proposal.id desc
  limit p_limit;
end;
$function$;

-- Legacy strict reader: keep its output shape and ordering.
CREATE OR REPLACE FUNCTION public.get_public_proposal(p_proposal_id uuid)
 RETURNS TABLE(proposal_id uuid, cover_object_path text, creator_profile_id uuid, creator_display_name text, title text, summary text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb, exact_meeting_text text, exact_location_restricted boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    proposal.id,
    cover.object_path,
    proposal.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.exact_meeting_text
      else null
    end,
    meeting.exact_location_visibility = 'participants'
      and (meeting.exact_meeting_text is not null or meeting.exact_location is not null)
  from public.proposals as proposal
  join public.profiles as creator on creator.id = proposal.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
    and proposal.definition_phase = 'defined'
    and proposal.lifecycle_state = 'published'
$function$;

-- Legacy strict reader: keep its output shape and ordering.
CREATE OR REPLACE FUNCTION public.get_own_proposal(p_expected_creator_profile_id uuid, p_proposal_id uuid)
 RETURNS TABLE(proposal_id uuid, cover_object_path text, lifecycle_state text, title text, summary text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb, exact_meeting_text text, exact_location_visibility text, created_at timestamp with time zone, updated_at timestamp with time zone, published_at timestamp with time zone, cancelled_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal_record public.proposals%rowtype;
begin
  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = p_proposal_id;

  if not found
    or (
      proposal_record.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_proposal_id,
        current_profile_id
      )
    )
    or (
      proposal_record.creator_profile_id <> current_profile_id
      and proposal_record.lifecycle_state = 'draft'
    ) then
    raise exception using
      errcode = '42501',
      message = 'The proposal management record is unavailable.';
  end if;

  return query
  select
    proposal.id,
    cover.object_path,
    proposal.lifecycle_state,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case
      when proposal.lifecycle_state = 'published' then private.derive_proposal_status(
        proposal.starts_at,
        proposal.ends_at,
        statement_timestamp()
      )
      else null
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
    and proposal.definition_phase = 'defined';
end;
$function$;

-- Legacy strict reader: keep its output shape and ordering.
CREATE OR REPLACE FUNCTION public.list_own_proposals(p_expected_creator_profile_id uuid)
 RETURNS TABLE(proposal_id uuid, cover_object_path text, lifecycle_state text, title text, summary text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb, exact_meeting_text text, exact_location_visibility text, created_at timestamp with time zone, updated_at timestamp with time zone, published_at timestamp with time zone, cancelled_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    proposal.id,
    cover.object_path,
    proposal.lifecycle_state,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case
      when proposal.lifecycle_state = 'published'
        then private.derive_proposal_status(
          proposal.starts_at,
          proposal.ends_at,
          statement_timestamp()
        )
      else null
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.creator_profile_id = current_profile_id
    and proposal.definition_phase = 'defined'
  order by proposal.created_at desc, proposal.id;
end;
$function$;

-- Legacy strict reader: keep its output shape and ordering.
CREATE OR REPLACE FUNCTION public.list_own_pending_requested_proposals(p_expected_requester_profile_id uuid, p_locality text DEFAULT NULL::text, p_skill_ids uuid[] DEFAULT NULL::uuid[], p_query text DEFAULT NULL::text)
 RETURNS TABLE(proposal_id uuid, cover_object_path text, request_id uuid, request_created_at timestamp with time zone, title text, summary text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Requested Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    cover.object_path,
    request.id,
    request.created_at,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.project_join_requests as request
  join public.proposals as proposal on proposal.id = request.project_id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and proposal.lifecycle_state = 'published'
    and proposal.definition_phase = 'defined'
    and proposal.ends_at > statement_timestamp() - interval '24 hours'
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
  order by request.created_at desc, proposal.id desc
  limit 200;
end;
$function$;

-- Legacy strict reader: keep its output shape and ordering.
CREATE OR REPLACE FUNCTION public.list_public_proposals(p_limit integer DEFAULT 20, p_cursor_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_id uuid DEFAULT NULL::uuid, p_locality text DEFAULT NULL::text, p_skill_ids uuid[] DEFAULT NULL::uuid[], p_query text DEFAULT NULL::text)
 RETURNS TABLE(proposal_id uuid, cover_object_path text, title text, summary text, starts_at timestamp with time zone, ends_at timestamp with time zone, event_timezone text, country_code text, locality text, administrative_area text, public_location_label text, derived_status text, skills jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Proposal page size must be between 1 and 50.';
  end if;

  if (p_cursor_starts_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Proposal cursor values must be supplied together.';
  end if;

  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    cover.object_path,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.proposals as proposal
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.lifecycle_state = 'published'
    and proposal.definition_phase = 'defined'
    and proposal.ends_at > statement_timestamp() - interval '24 hours'
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
    and (
      p_cursor_starts_at is null
      or (proposal.starts_at, proposal.id) > (p_cursor_starts_at, p_cursor_id)
    )
  order by proposal.starts_at, proposal.id
  limit p_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_own_delegated_projects_v2(p_expected_profile_id uuid)
 RETURNS TABLE(project_id uuid, project_kind text, project_title text, project_status text, delegated_at timestamp with time zone, authority_role text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        when proposal.definition_phase='idea' then 'in_definition'
        when proposal.ends_at <= statement_timestamp() then 'completed'
        else proposal.lifecycle_state
      end
      when 'recurring' then activity.lifecycle_state
    end,
    delegate.delegated_at,
    delegate.authority_role
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
    and delegate.authority_role in ('co_organizer', 'co_creator')
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
$function$;

CREATE OR REPLACE FUNCTION public.list_own_delegated_projects(p_expected_profile_id uuid)
 RETURNS TABLE(project_id uuid, project_kind text, project_title text, project_status text, delegated_at timestamp with time zone, authority_role text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    delegate.delegated_at,
    delegate.authority_role
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
    and delegate.authority_role in ('co_organizer', 'co_creator')
    and (
      (
        project.project_kind = 'one_time'
        and proposal.id is not null
        and proposal.lifecycle_state <> 'draft'
        and proposal.definition_phase = 'defined'
      )
      or (
        project.project_kind = 'recurring'
        and activity.id is not null
        and activity.lifecycle_state <> 'draft'
      )
    )
  order by delegate.delegated_at desc, project.id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.publish_proposal(p_expected_creator_profile_id uuid, p_proposal_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_complete_profile(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null or proposal.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.definition_phase <> 'defined' then
    raise exception using errcode='55000',message='Use explicit Idea promotion to enter Defined.';
  end if;

  if proposal.lifecycle_state = 'published' then
    return proposal.id;
  end if;

  if proposal.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft proposal can be published.';
  end if;

  perform private.assert_proposal_publishable(p_proposal_id, false);

  if not private.has_current_profile_photo(current_profile_id) then
    raise exception using
      errcode = 'PT422',
      message = 'A current profile photo is required for this trust-sensitive action.';
  end if;

  update public.proposals
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_proposal_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'proposal.published',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.published',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$function$;

revoke all on function public.get_public_proposal_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_public_proposal_v2(uuid) to anon,authenticated;

revoke all on function public.get_own_proposal_v2(uuid, uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_own_proposal_v2(uuid, uuid) to authenticated;

revoke all on function public.list_own_proposals_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_own_proposals_v2(uuid) to authenticated;

revoke all on function public.list_own_pending_requested_proposals_v2(uuid, text, uuid[], text) from public,anon,authenticated,service_role;
grant execute on function public.list_own_pending_requested_proposals_v2(uuid, text, uuid[], text) to authenticated;

revoke all on function public.list_public_proposals_v2(integer,timestamptz,uuid,text,uuid[],text,text,timestamptz) from public,anon,authenticated,service_role;
grant execute on function public.list_public_proposals_v2(integer,timestamptz,uuid,text,uuid[],text,text,timestamptz) to anon,authenticated;

revoke all on function public.list_own_delegated_projects_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_own_delegated_projects_v2(uuid) to authenticated;

-- The public phase is server-owned; lifecycle and membership identities do not change.
create function private.protect_proposal_definition_phase()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.definition_phase is distinct from old.definition_phase then
  if not (
    (old.lifecycle_state='draft' and old.definition_phase='defined'
      and new.lifecycle_state='published' and new.definition_phase='idea')
    or (old.lifecycle_state='published' and old.definition_phase='idea'
      and new.lifecycle_state='published' and new.definition_phase='defined')
  ) then
   raise exception using errcode='55000',message='Only deliberate Idea publication and forward promotion may change planning phase.';
  end if;
 end if;
 return new;
end;
$$;
revoke all on function private.protect_proposal_definition_phase() from public,anon,authenticated,service_role;
create trigger proposals_protect_definition_phase before update of definition_phase on public.proposals
for each row execute function private.protect_proposal_definition_phase();

create function public.publish_proposal_idea(p_expected_creator_profile_id uuid,p_proposal_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_complete_profile(p_expected_creator_profile_id);
 p public.proposals%rowtype;
begin
 select * into p from public.proposals where id=p_proposal_id for update;
 if p.id is null or p.creator_profile_id<>actor then
  raise exception using errcode='42501',message='Only the original Creator can publish this private draft.';
 end if;
 if p.lifecycle_state='published' and p.definition_phase='idea' then return p.id; end if;
 if p.lifecycle_state<>'draft' then
  raise exception using errcode='55000',message='Only a private draft can be published as an Idea.';
 end if;
 perform private.assert_idea_publishable(p.id);
 if not private.has_current_profile_photo(actor) then
  raise exception using errcode='PT422',message='A current profile photo is required for this trust-sensitive action.';
 end if;
 -- Concrete -> shared Project lock order matches joins, capacity and promotion.
 perform 1 from public.projects where id=p.id for update;
 update public.proposals set definition_phase='idea',lifecycle_state='published',
   published_at=statement_timestamp() where id=p.id;
 insert into private.audit_events(action,actor_user_id,target_type,target_id)
  values('proposal.published',actor,'proposal',p.id);
 insert into private.outbox_events(event_type,payload) values('proposal.published',
  jsonb_build_object('proposal_id',p.id,'creator_profile_id',actor,'definition_phase','idea'));
 return p.id;
end;
$$;
revoke all on function public.publish_proposal_idea(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.publish_proposal_idea(uuid,uuid) to authenticated;

-- Preview is advisory. Promotion rechecks every condition under the concrete/shared locks.
create function private.proposal_promotion_missing_fields(p_proposal_id uuid)
returns text[] language sql stable security definer set search_path='' as $$
 select array(
  select requirement from (
   values
    ('title',p.title is null),
    ('summary',p.summary is null),
    ('description',p.description is null),
    ('starts_at',p.starts_at is null or not isfinite(p.starts_at) or p.starts_at<=statement_timestamp()),
    ('ends_at',p.ends_at is null or not isfinite(p.ends_at) or p.ends_at<=p.starts_at),
    ('event_timezone',p.event_timezone is null or not exists(select 1 from pg_catalog.pg_timezone_names z where z.name=p.event_timezone)),
    ('country_code',p.country_code is null),
    ('locality',p.locality is null),
    ('public_location_label',p.public_location_label is null),
    ('registration_capacity',c.registration_capacity is null or c.registration_capacity<c.capacity_used_count),
    ('creator_profile',not exists(select 1 from public.profiles f where f.id=p.creator_profile_id and f.display_name is not null)),
    ('creator_photo',not private.has_current_profile_photo(p.creator_profile_id))
  ) r(requirement,missing) where missing order by requirement
 )
 from public.proposals p
 cross join lateral private.project_registration_capacity_snapshot(p.id) c
 where p.id=p_proposal_id
$$;
revoke all on function private.proposal_promotion_missing_fields(uuid) from public,anon,authenticated,service_role;

create function public.get_proposal_promotion_requirements(p_expected_profile_id uuid,p_proposal_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_complete_profile(p_expected_profile_id);
 p public.proposals%rowtype; missing text[];
begin
 select * into p from public.proposals where id=p_proposal_id;
 if p.id is null or not private.profile_has_project_structural_authority(p.id,actor) then
  raise exception using errcode='42501',message='Idea promotion is unavailable to this account.';
 end if;
 if p.lifecycle_state<>'published' then
  raise exception using errcode='55000',message='Only a public Idea can be promoted.';
 end if;
 if p.definition_phase='defined' then missing:=array[]::text[];
 else
  missing:=private.proposal_promotion_missing_fields(p.id);
  if not private.has_current_profile_photo(actor) then missing:=array_append(missing,'organizer_photo'); end if;
 end if;
 return jsonb_build_object('proposal_id',p.id,'definition_phase',p.definition_phase,
   'missing_fields',missing,'can_promote',p.definition_phase='idea' and cardinality(missing)=0);
end;
$$;
revoke all on function public.get_proposal_promotion_requirements(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_proposal_promotion_requirements(uuid,uuid) to authenticated;

create function public.promote_proposal_idea(p_expected_profile_id uuid,p_proposal_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_complete_profile(p_expected_profile_id);
 p public.proposals%rowtype; missing text[];
begin
 select * into p from public.proposals where id=p_proposal_id for update;
 if p.id is null or not private.profile_has_project_structural_authority(p.id,actor) then
  raise exception using errcode='42501',message='Only the Creator or a current Co-creator can promote an Idea.';
 end if;
 if p.lifecycle_state<>'published' then
  raise exception using errcode='55000',message='Only a public Idea can be promoted.';
 end if;
 -- Serialize with role revocation, capacity, invitations and normal admissions.
 perform 1 from public.projects where id=p.id for update;
 if not private.profile_has_project_structural_authority(p.id,actor) then
  raise exception using errcode='42501',message='Idea promotion authority has changed.';
 end if;
 if p.definition_phase='defined' then return p.id; end if;
 missing:=private.proposal_promotion_missing_fields(p.id);
 if not private.has_current_profile_photo(actor) then missing:=array_append(missing,'organizer_photo'); end if;
 if cardinality(missing)>0 then
  raise exception using errcode='PT422',message='Complete the missing planning fields before promotion.',
    detail=jsonb_build_object('missing_fields',missing)::text;
 end if;
 perform private.assert_defined_proposal_publishable(p.id,true);
 -- No recreation/publication: preserve ID, original published_at and all collaborators/history.
 update public.proposals set definition_phase='defined' where id=p.id;
 insert into private.audit_events(action,actor_user_id,target_type,target_id)
  values('proposal.promoted',actor,'proposal',p.id);
 insert into private.outbox_events(event_type,payload) values('proposal.promoted',
  jsonb_build_object('proposal_id',p.id,'actor_id',actor,'definition_phase','defined'));
 return p.id;
end;
$$;
revoke all on function public.promote_proposal_idea(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.promote_proposal_idea(uuid,uuid) to authenticated;

comment on function public.publish_proposal_idea(uuid,uuid) is
 'Explicit original-Creator publication of readable public Idea. Optional logistics/capacity are not fabricated. Idempotent while Idea; complete profile/current photo required.';
comment on function public.promote_proposal_idea(uuid,uuid) is
 'Atomic forward Idea-to-Defined promotion, Creator/current Co-creator only. PT422 details contain missing_fields; preserves published_at, Project/chat/membership/template identity.';
comment on function public.list_public_proposals_v2(integer,timestamptz,uuid,text,uuid[],text,text,timestamptz) is
 'Opt-in nullable logistics and definition_phase. Immutable published_at/id DESC cursor and reference_time anchor; phase null=all. Legacy schedule-order readers remain Defined-only. Idea derived_status is null.';
