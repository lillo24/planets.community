-- LOCATION01: a defined one-time Project requires public locality + schedule.
-- Exact instructions/geometry are optional; the protected one-to-one row remains.
-- Replacing bodies preserves signatures, grants, RLS, and all caller safeguards.
create or replace function private.assert_proposal_publishable(
  p_proposal_id uuid,
  p_require_future_start boolean
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
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
$$;

-- Public absence is distinct from protected presence. No private value is projected.
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
$$;

comment on function private.assert_proposal_publishable(uuid, boolean) is
  'Defined one-time Project: complete ordinary content, valid schedule and broad public locality; protected precise meeting details are optional. Idea/in-definition is a separate future lifecycle.';
