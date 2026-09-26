drop function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[]);
drop function public.list_own_pending_requested_proposals(uuid, text, uuid[]);

create function public.list_public_proposals(
  p_limit integer default 20,
  p_cursor_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null,
  p_skill_ids uuid[] default null,
  p_query text default null
)
returns table (
  proposal_id uuid,
  title text,
  summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
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
    proposal.id as proposal_id,
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
    ) as derived_status,
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
    ) as skills
  from public.proposals as proposal
  where proposal.lifecycle_state = 'published'
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
$$;

create function public.list_own_pending_requested_proposals(
  p_expected_requester_profile_id uuid,
  p_locality text default null,
  p_skill_ids uuid[] default null,
  p_query text default null
)
returns table (
  proposal_id uuid,
  request_id uuid,
  request_created_at timestamptz,
  title text,
  summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
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
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and proposal.lifecycle_state = 'published'
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
$$;

revoke all privileges on function public.list_public_proposals(
  integer,
  timestamptz,
  uuid,
  text,
  uuid[],
  text
) from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_pending_requested_proposals(
  uuid,
  text,
  uuid[],
  text
) from public, anon, authenticated, service_role;

grant execute on function public.list_public_proposals(
  integer,
  timestamptz,
  uuid,
  text,
  uuid[],
  text
) to anon, authenticated;
grant execute on function public.list_own_pending_requested_proposals(
  uuid,
  text,
  uuid[],
  text
) to authenticated;

comment on function public.list_public_proposals(
  integer,
  timestamptz,
  uuid,
  text,
  uuid[],
  text
) is
  'Returns a cursor-paginated sanitized public discovery page with rough location and optional literal title/summary/description query.';
comment on function public.list_own_pending_requested_proposals(
  uuid,
  text,
  uuid[],
  text
) is
  'Returns at most 200 sanitized, publicly discoverable Proposal cards for the expected identity current pending requests, filtered by the same optional literal query as public discovery.';
