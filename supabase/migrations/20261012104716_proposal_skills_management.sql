-- UI02: skills have a narrow canonical write; all existing actors/lifecycles
-- and matching events remain canonical. Hosted activation is separate.
create function public.update_proposal_skills(
  p_expected_structural_profile_id uuid,
  p_proposal_id uuid,
  p_expected_skills jsonb,
  p_skill_ids uuid[],
  p_skill_importances text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := private.require_expected_identity(p_expected_structural_profile_id);
  proposal public.proposals%rowtype;
  current_skills jsonb;
begin
  -- Concrete activity before registry, matching structural/delegate lock order.
  -- FOR UPDATE first avoids shared-to-exclusive upgrade deadlocks.
  select * into proposal from public.proposals
  where id = p_proposal_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'Proposal skills are unavailable.';
  end if;
  perform 1 from public.projects where id = p_proposal_id for update;
  if not private.profile_has_project_structural_authority(p_proposal_id, actor_id)
    or (proposal.lifecycle_state = 'draft' and proposal.creator_profile_id <> actor_id) then
    raise exception using errcode = '42501', message = 'Proposal skills are unavailable.';
  end if;
  if proposal.lifecycle_state not in ('draft', 'published')
    or (proposal.lifecycle_state = 'published' and proposal.starts_at <= clock_timestamp()) then
    raise exception using errcode = '55000', message = 'This Proposal can no longer be edited.';
  end if;
  if p_expected_skills is null or jsonb_typeof(p_expected_skills) <> 'object' then
    raise exception using errcode = '22023', message = 'The expected skill collection is required.';
  end if;
  select coalesce(jsonb_object_agg(skill_id::text, importance), '{}'::jsonb)
  into current_skills from public.proposal_skills where proposal_id = p_proposal_id;
  if p_expected_skills <> current_skills then
    raise exception using errcode = '40001', message = 'Proposal skills changed. Reload before saving.';
  end if;
  if p_skill_ids is null
    or p_skill_importances is null
    or cardinality(p_skill_ids) <> cardinality(p_skill_importances)
    or array_position(p_skill_ids, null) is not null
    or array_position(p_skill_importances, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skills and importance values must be matching non-null lists.';
  end if;

  if cardinality(p_skill_ids) <> (
    select count(distinct requested.skill_id)
    from unnest(p_skill_ids) as requested(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'A proposal skill may be selected only once.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_importances) as requested(importance)
    where requested.importance not in ('required', 'useful')
  ) then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill importance must be required or useful.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_ids) as requested(skill_id)
    left join public.skills as skill on skill.id = requested.skill_id
    where skill.id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'One or more proposal skills are not in the catalog.';
  end if;

  delete from public.proposal_skills where proposal_id = p_proposal_id;
  insert into public.proposal_skills (proposal_id, skill_id, importance)
  select p_proposal_id, requested.skill_id, requested.importance
  from unnest(p_skill_ids, p_skill_importances) as requested(skill_id, importance);
  update public.proposals set updated_at = statement_timestamp() where id = p_proposal_id;

  insert into private.audit_events (action, actor_user_id, target_type, target_id)
  values ('proposal.updated', actor_id, 'proposal', p_proposal_id);
  insert into private.outbox_events (event_type, payload)
  values ('proposal.updated', jsonb_build_object('proposal_id', p_proposal_id, 'actor_id', actor_id));
  return p_proposal_id;
end;
$$;

revoke all on function public.update_proposal_skills(uuid, uuid, jsonb, uuid[], text[])
from public, anon, authenticated, service_role;
grant execute on function public.update_proposal_skills(uuid, uuid, jsonb, uuid[], text[])
to authenticated;
comment on function public.update_proposal_skills(uuid, uuid, jsonb, uuid[], text[]) is
  'Identity-bound Creator/Co-creator skill-only replacement with expected-collection conflict detection; original Creator only for drafts; no resource-need privilege change.';

create or replace function public.update_own_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid,
  p_title text,
  p_summary text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_event_timezone text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_exact_meeting_text text,
  p_exact_location_visibility text,
  p_skill_ids uuid[],
  p_skill_importances text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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

  -- Explicit null/null means this caller does not own skill editing. Resolve
  -- the current collection under the same Proposal lock as the content write.
  -- Empty arrays still explicitly clear skills; one null list remains invalid.
  if p_skill_ids is null and p_skill_importances is null then
    select
      coalesce(array_agg(skill_id order by skill_id), '{}'::uuid[]),
      coalesce(array_agg(importance order by skill_id), '{}'::text[])
    into p_skill_ids, p_skill_importances
    from public.proposal_skills where proposal_id = p_proposal_id;
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
$$;

comment on function public.update_own_proposal(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[]) is
  'Canonical structural content update. Null/null skill lists preserve the locked current collection; non-null lists replace it, including empty arrays. Draft ownership and published lifecycle rules are unchanged.';
