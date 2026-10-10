-- IDEA01A integration with LOCATION02: preserve strict legacy readers and
-- participants-only arrival directions in both public detail versions.
-- Additive correction; no stored place or visibility is rewritten.

create or replace function public.get_public_proposal(p_proposal_id uuid)
returns table (
  proposal_id uuid,
  cover_object_path text,
  creator_profile_id uuid,
  creator_display_name text,
  title text,
  summary text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb,
  exact_meeting_text text,
  exact_location_restricted boolean
)
language sql
stable
security definer
set search_path = ''
as $$
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
        then meeting.selected_exact_place->>'label'
      else null
    end,
    (meeting.exact_location_visibility <> 'public' or meeting.selected_exact_place is null)
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
    and proposal.definition_phase = 'defined'
$$;


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
        then meeting.selected_exact_place->>'label'
      else null
    end,
    (meeting.exact_location_visibility <> 'public' or meeting.selected_exact_place is null)
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


comment on function public.get_public_proposal_v2(uuid) is
 'IDEA01A/LOCATION02: phase-aware sanitized detail; exact_meeting_text is a deliberately public verified place label, never private arrival directions.';
