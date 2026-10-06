-- TW01: identity and a private saved-draft baseline are retained; reusable
-- content is projected synchronously from the canonical source, never copied
-- into an independently editable store. No clock-driven completion state.
create table private.proposal_templates (
  id uuid primary key default gen_random_uuid(),
  source_proposal_id uuid not null unique
    references public.proposals (id) on delete restrict,
  original_creator_profile_id uuid not null
    references public.profiles (id) on delete restrict,
  linked_at timestamptz not null,
  removed_at timestamptz
);

create index proposal_templates_catalog_idx
  on private.proposal_templates (linked_at desc, id desc)
  where removed_at is null;
create index proposal_templates_creator_idx
  on private.proposal_templates (original_creator_profile_id);

create table private.proposal_template_baselines (
  template_id uuid primary key
    references private.proposal_templates (id) on delete restrict,
  title text,
  summary text,
  description text,
  skill_selections jsonb not null
    check (jsonb_typeof(skill_selections) = 'array'),
  captured_at timestamptz not null
);

alter table private.proposal_templates enable row level security;
alter table private.proposal_template_baselines enable row level security;
revoke all on private.proposal_templates, private.proposal_template_baselines
  from public, anon, authenticated, service_role;

comment on table private.proposal_templates is
  'One immutable identity per once-published one-time Proposal. removed_at is the private TW02 removal seam, with no TW01 removal/reactivation API.';
comment on table private.proposal_template_baselines is
  'Original-Creator-private last persisted draft text and skill selections at first successful publication. Absent for legacy/trusted published inserts; not an outcome or draft history.';

create function private.protect_proposal_template_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.id, new.source_proposal_id, new.original_creator_profile_id, new.linked_at)
    is distinct from
    (old.id, old.source_proposal_id, old.original_creator_profile_id, old.linked_at) then
    raise exception using errcode = '55000',
      message = 'A linked template identity cannot be changed.';
  end if;
  return new;
end;
$$;

create trigger proposal_templates_protect_identity
before update on private.proposal_templates
for each row execute function private.protect_proposal_template_identity();

create function private.protect_proposal_template_baseline()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using errcode = '55000',
    message = 'A saved pre-publication baseline is immutable.';
end;
$$;

create trigger proposal_template_baselines_immutable
before update or delete on private.proposal_template_baselines
for each row execute function private.protect_proposal_template_baseline();

create function private.link_published_proposal_template()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_template_id uuid;
begin
  if new.lifecycle_state <> 'published' then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if old.lifecycle_state <> 'draft' then
      return new;
    end if;
  end if;

  insert into private.proposal_templates (
    source_proposal_id, original_creator_profile_id, linked_at
  ) values (new.id, new.creator_profile_id, new.published_at)
  on conflict (source_proposal_id) do nothing
  returning id into new_template_id;

  -- BEFORE UPDATE still sees the last persisted draft and its saved selections.
  -- A trusted already-published INSERT has no genuine pre-publication baseline.
  -- Conflict/retry never fills or overwrites an existing/legacy baseline.
  if tg_op = 'UPDATE' and new_template_id is not null then
    insert into private.proposal_template_baselines (
      template_id, title, summary, description, skill_selections, captured_at
    ) values (
      new_template_id, old.title, old.summary, old.description,
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'skill_id', selection.skill_id, 'importance', selection.importance
        ) order by selection.skill_id)
        from public.proposal_skills as selection
        where selection.proposal_id = old.id
      ), '[]'::jsonb), statement_timestamp()
    );
  end if;
  return new;
end;
$$;

create trigger proposals_link_template_on_publication
before update of lifecycle_state on public.proposals
for each row execute function private.link_published_proposal_template();
create trigger proposals_link_template_on_published_insert
after insert on public.proposals
for each row execute function private.link_published_proposal_template();

-- Idempotent data backfill: future and historical published sources plus retained
-- cancelled publications get identities, never fabricated drafts/events/outcomes.
insert into private.proposal_templates (
  source_proposal_id, original_creator_profile_id, linked_at
)
select proposal.id, proposal.creator_profile_id, proposal.published_at
from public.proposals as proposal
where proposal.published_at is not null
on conflict (source_proposal_id) do nothing;

create function private.is_proposal_template_publicly_usable(
  p_template_id uuid, p_reference_time timestamptz
)
returns boolean
language sql stable security definer set search_path = ''
as $$
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
      and proposal.published_at is not null
      and proposal.starts_at is not null and proposal.ends_at is not null
      and private.derive_proposal_status(
        proposal.starts_at, proposal.ends_at, p_reference_time
      ) = 'completed'
      and private.is_project_publicly_viewable(proposal.id)
  )
$$;

comment on function private.is_proposal_template_publicly_usable(uuid,timestamptz) is
  'Shared Workshop list/detail/blueprint and future TW03 application gate: published one-time source, canonical Completed, current source public boundary, and no template removal. TW02 composes approved source restrictions here.';

create function private.proposal_template_skills(p_proposal_id uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', skill.id, 'slug', skill.slug, 'label', skill.label,
    'category_id', category.id, 'category_slug', category.slug,
    'category_label', category.label, 'importance', selection.importance
  ) order by skill.id), '[]'::jsonb)
  from public.proposal_skills as selection
  join public.skills as skill on skill.id = selection.skill_id
  join public.skill_categories as category on category.id = skill.category_id
  where selection.proposal_id = p_proposal_id
$$;

-- Internal complete allow-list, suitable for an atomic TW03 copy after gating.
-- Public detail never serializes this wholesale: blueprints have their own
-- bounded read with version checking and an explicit total in detail.
create function private.proposal_template_reusable_content(p_proposal_id uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'title', proposal.title, 'summary', proposal.summary,
    'description', proposal.description,
    'skills', private.proposal_template_skills(proposal.id),
    'registration_capacity_recommendation', project.registration_capacity,
    'duration_seconds', extract(epoch from proposal.ends_at - proposal.starts_at),
    'cover_object_path', case when private.is_project_publicly_viewable(proposal.id)
      then cover.object_path else null end,
    'resource_blueprints', coalesce((
      select jsonb_agg(jsonb_build_object(
        'source_need_id', need.id, 'title', need.title, 'details', need.details
      ) order by need.id)
      from public.project_resource_needs as need
      where need.project_id = proposal.id and need.state = 'open'
    ), '[]'::jsonb)
  )
  from public.proposals as proposal
  join public.projects as project on project.id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
$$;

create function private.proposal_template_content_version(p_content jsonb)
returns text
language sql immutable security invoker set search_path = ''
as $$
  select 'tw01:' || encode(extensions.digest(p_content::text, 'sha256'), 'hex')
$$;

comment on function private.proposal_template_reusable_content(uuid) is
  'Explicit full reusable allow-list; no baseline, logistics, profiles, participation, coverage, commitments or evidence. Stable functions share the calling statement snapshot; do not use as an ungated public read.';
comment on function private.proposal_template_content_version(jsonb) is
  'Opaque tw01 SHA-256 of canonical JSONB allow-list, arrays ordered by immutable IDs. Same payload has the same token; all copied fields/descriptors/open need IDs/text affect it. Attribution/privacy, logistics and occupancy do not. Not chronological or a visibility authorization token.';

create function public.list_public_proposal_templates(
  p_limit integer default 20,
  p_cursor_linked_at timestamptz default null,
  p_cursor_id uuid default null,
  p_skill_ids uuid[] default null,
  p_query text default null
)
returns table (
  template_id uuid, source_proposal_id uuid, linked_at timestamptz,
  title text, summary text, skills jsonb, cover_object_path text,
  original_creator_profile_id uuid, creator_display_name text
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode = '22023',
      message = 'Template page size must be between 1 and 50.';
  end if;
  if (p_cursor_linked_at is null) <> (p_cursor_id is null)
    or (p_cursor_linked_at is not null and not isfinite(p_cursor_linked_at)) then
    raise exception using errcode = '22023',
      message = 'Template cursor values must be finite and supplied together.';
  end if;
  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using errcode = '22023',
      message = 'Template search query must contain at most 120 characters.';
  end if;
  if coalesce(cardinality(p_skill_ids), 0) > 50
    or array_position(p_skill_ids, null) is not null
    or exists (
      select 1 from unnest(p_skill_ids) as filter_id(id)
      where not exists (select 1 from public.skills as skill where skill.id = filter_id.id)
    ) then
    raise exception using errcode = '22023',
      message = 'Template skill filters must contain at most 50 controlled non-null identifiers.';
  end if;
  return query
  select template.id, proposal.id, template.linked_at, proposal.title,
    proposal.summary, private.proposal_template_skills(proposal.id), cover.object_path,
    template.original_creator_profile_id,
    case when visibility.audience = 'public' then creator.display_name else null end
  from private.proposal_templates as template
  join public.proposals as proposal on proposal.id = template.source_proposal_id
  join public.profiles as creator on creator.id = template.original_creator_profile_id
  left join public.profile_field_visibility as visibility
    on visibility.profile_id = creator.id and visibility.field_key = 'display_name'
  left join public.project_covers as cover on cover.project_id = proposal.id
  where private.is_proposal_template_publicly_usable(template.id, statement_timestamp())
    and (normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0)
    and (coalesce(cardinality(p_skill_ids), 0) = 0 or exists (
      select 1 from public.proposal_skills as selection
      where selection.proposal_id = proposal.id and selection.skill_id = any(p_skill_ids)
    ))
    and (p_cursor_linked_at is null
      or (template.linked_at, template.id) < (p_cursor_linked_at, p_cursor_id))
  order by template.linked_at desc, template.id desc
  limit p_limit;
end;
$$;

create function public.get_public_proposal_template(p_template_id uuid)
returns table (
  template_id uuid, source_proposal_id uuid, content_version text,
  original_creator_profile_id uuid, creator_display_name text,
  title text, summary text, description text, skills jsonb,
  registration_capacity_recommendation integer, duration_seconds numeric,
  cover_object_path text, resource_blueprint_count integer
)
language sql stable security definer set search_path = ''
as $$
  with eligible as materialized (
    select template.* from private.proposal_templates as template
    where template.id = p_template_id
      and private.is_proposal_template_publicly_usable(template.id, statement_timestamp())
  ), content as materialized (
    select template.*, private.proposal_template_reusable_content(template.source_proposal_id) as payload
    from eligible as template
  )
  select content.id, content.source_proposal_id,
    private.proposal_template_content_version(content.payload),
    content.original_creator_profile_id,
    case when visibility.audience = 'public' then creator.display_name else null end,
    content.payload ->> 'title', content.payload ->> 'summary',
    content.payload ->> 'description', content.payload -> 'skills',
    (content.payload ->> 'registration_capacity_recommendation')::integer,
    (content.payload ->> 'duration_seconds')::numeric,
    content.payload ->> 'cover_object_path',
    jsonb_array_length(content.payload -> 'resource_blueprints')
  from content
  join public.profiles as creator on creator.id = content.original_creator_profile_id
  left join public.profile_field_visibility as visibility
    on visibility.profile_id = creator.id and visibility.field_key = 'display_name'
$$;

create function public.list_public_proposal_template_resource_blueprints(
  p_template_id uuid,
  p_content_version text,
  p_limit integer default 20,
  p_cursor_need_id uuid default null
)
returns table (source_need_id uuid, title text, details text)
language plpgsql stable security definer set search_path = ''
as $$
declare
  source_id uuid;
  current_version text;
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode = '22023',
      message = 'Template blueprint page size must be between 1 and 50.';
  end if;
  if p_content_version is null or p_content_version !~ '^tw01:[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'A valid template content version is required.';
  end if;
  select template.source_proposal_id,
    private.proposal_template_content_version(
      private.proposal_template_reusable_content(template.source_proposal_id)
    ) into source_id, current_version
  from private.proposal_templates as template
  where template.id = p_template_id
    and private.is_proposal_template_publicly_usable(template.id, statement_timestamp());
  if not found then return; end if;
  if current_version <> p_content_version then
    raise exception using errcode = 'PT409',
      message = 'Template content changed; reload detail and restart blueprint pagination.';
  end if;
  return query select need.id, need.title, need.details
  from public.project_resource_needs as need
  where need.project_id = source_id and need.state = 'open'
    and (p_cursor_need_id is null or need.id > p_cursor_need_id)
  order by need.id limit p_limit;
end;
$$;

create function public.get_own_proposal_template_baseline(
  p_expected_creator_profile_id uuid, p_template_id uuid
)
returns table (
  template_id uuid, source_proposal_id uuid, title text, summary text,
  description text, skill_selections jsonb, captured_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(p_expected_creator_profile_id);
begin
  if not exists (
    select 1 from private.proposal_templates as template
    where template.id = p_template_id and template.original_creator_profile_id = current_profile_id
  ) then
    raise exception using errcode = '42501', message = 'The private template baseline is unavailable.';
  end if;
  return query select template.id, template.source_proposal_id,
    baseline.title, baseline.summary, baseline.description,
    baseline.skill_selections, baseline.captured_at
  from private.proposal_templates as template
  join private.proposal_template_baselines as baseline on baseline.template_id = template.id
  where template.id = p_template_id and template.original_creator_profile_id = current_profile_id;
end;
$$;

comment on function public.list_public_proposal_templates(integer,timestamptz,uuid,uuid[],text) is
  'Slim eligible Completed catalog, immutable descending linked_at/id keyset, 1-50 rows, literal trimmed 120-character query and OR controlled-skill filters. Public-name visibility only.';
comment on function public.get_public_proposal_template(uuid) is
  'Zero-or-one eligible reusable detail with exact content version and total open-blueprint count; fetch all bounded blueprint pages against that token. No logistics or private baseline.';
comment on function public.list_public_proposal_template_resource_blueprints(uuid,text,integer,uuid) is
  'Completed-template-only open title/details, ascending immutable need-ID keyset, 1-50 rows. Read detail total and traverse from null cursor; mismatch PT409 requires restart, never silent truncation.';
comment on function public.get_own_proposal_template_baseline(uuid,uuid) is
  'Expected-identity read for immutable original Creator only; legacy missing baseline returns zero rows. No delegate/participant/staff exception; removed/cancelled history remains private to its Creator.';

revoke all on function private.protect_proposal_template_identity(),
  private.protect_proposal_template_baseline(), private.link_published_proposal_template(),
  private.is_proposal_template_publicly_usable(uuid,timestamptz),
  private.proposal_template_skills(uuid), private.proposal_template_reusable_content(uuid),
  private.proposal_template_content_version(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.list_public_proposal_templates(integer,timestamptz,uuid,uuid[],text),
  public.get_public_proposal_template(uuid),
  public.list_public_proposal_template_resource_blueprints(uuid,text,integer,uuid),
  public.get_own_proposal_template_baseline(uuid,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_public_proposal_templates(integer,timestamptz,uuid,uuid[],text),
  public.get_public_proposal_template(uuid),
  public.list_public_proposal_template_resource_blueprints(uuid,text,integer,uuid)
  to anon, authenticated;
grant execute on function public.get_own_proposal_template_baseline(uuid,uuid)
  to authenticated;
