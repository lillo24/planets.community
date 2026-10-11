-- OST01: organization-authored examples, never synthetic completed Projects.
alter table private.proposal_templates
  alter column source_proposal_id drop not null,
  alter column original_creator_profile_id drop not null,
  add column template_kind text not null default 'community',
  add column starter_key text unique,
  add constraint proposal_templates_kind_valid check (
    (template_kind = 'community' and source_proposal_id is not null
      and original_creator_profile_id is not null and starter_key is null)
    or (template_kind = 'official_starter' and starter_key is not null and source_proposal_id is null
      and original_creator_profile_id is null and starter_key in
        ('repair','mural','flowerbed','concert','trail','books','bookcase','dinner'))
  );

create table private.official_starter_template_content (
  template_id uuid primary key references private.proposal_templates(id) on delete restrict,
  content jsonb not null check (jsonb_typeof(content) = 'object')
);
create table private.official_starter_template_reviews (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references private.proposal_templates(id) on delete restrict,
  reviewed_at timestamptz not null default clock_timestamp(),
  database_actor text not null default session_user,
  reason text not null check (char_length(btrim(reason)) between 10 and 1000),
  previous_content jsonb,
  accepted_content jsonb not null,
  retired boolean not null
);
alter table private.official_starter_template_content enable row level security;
alter table private.official_starter_template_reviews enable row level security;
revoke all on private.official_starter_template_content,
  private.official_starter_template_reviews from public, anon, authenticated, service_role;
create trigger official_starter_template_reviews_append_only
before update or delete on private.official_starter_template_reviews
for each row execute function private.protect_moderation_append_only();

-- A nullable source means organization provenance; no auth/profile row is created.
alter table private.proposal_template_applications alter column source_proposal_id drop not null;
alter table private.proposal_template_removal_actions alter column source_proposal_id drop not null;
alter table private.moderation_cases alter column subject_profile_id drop not null;
alter table private.moderation_cases drop constraint moderation_cases_template_provenance_valid;
alter table private.moderation_cases add constraint moderation_cases_template_provenance_valid check (
  (target_kind = 'proposal_template' and template_report_content_version is not null
    and template_report_content_version ~ '^tw01:[0-9a-f]{64}$'
    and ((template_source_proposal_id is null and subject_profile_id is null)
      or (template_source_proposal_id is not null and subject_profile_id is not null)))
  or (target_kind <> 'proposal_template' and subject_profile_id is not null
    and template_source_proposal_id is null and template_report_content_version is null)
);

create function private.workshop_template_content(p_template_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when t.template_kind = 'community'
    then private.proposal_template_reusable_content(t.source_proposal_id)
    else (c.content - 'skill_selections') || jsonb_build_object('cover_object_path', null, 'skills', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', s.id, 'slug', s.slug, 'label', s.label,
        'category_id', cat.id, 'category_slug', cat.slug,
        'category_label', cat.label, 'importance', selection->>'importance'
      ) order by s.id), '[]'::jsonb)
      from jsonb_array_elements(c.content->'skill_selections') as selection
      join public.skills s on s.slug = selection->>'slug'
      join public.skill_categories cat on cat.id = s.category_id
    )) end
  from private.proposal_templates t
  left join private.official_starter_template_content c on c.template_id = t.id
  where t.id = p_template_id
$$;

-- Database-owner maintenance only. Expected raw-content hash detects drift even
-- if controlled skill labels changed since the review. Retirement is terminal.
create function private.provision_official_starter_template(
  p_template_id uuid, p_key text, p_expected_content_hash text,
  p_content jsonb, p_reason text, p_retire boolean default false
)
returns text language plpgsql security invoker set search_path = ''
as $$
declare
  t private.proposal_templates%rowtype;
  previous jsonb;
  current_hash text;
  entry jsonb;
begin
  if p_template_id is null or p_key is null or p_retire is null
    or p_reason is null or char_length(btrim(p_reason)) not between 10 and 1000
    or p_content is null or jsonb_typeof(p_content) <> 'object'
    or (select count(*) from jsonb_object_keys(p_content)) <> 8
    or not p_content ?& array['title','summary','description','skill_selections',
      'registration_capacity_recommendation','duration_seconds','cover_asset_key','resource_blueprints']
    or jsonb_typeof(p_content->'title') <> 'string'
    or char_length(btrim(p_content->>'title')) not between 1 and 100
    or jsonb_typeof(p_content->'summary') <> 'string'
    or char_length(btrim(p_content->>'summary')) not between 1 and 240
    or jsonb_typeof(p_content->'description') <> 'string'
    or char_length(btrim(p_content->>'description')) not between 1 and 5000
    or jsonb_typeof(p_content->'skill_selections') <> 'array'
    or jsonb_typeof(p_content->'resource_blueprints') <> 'array'
    or jsonb_array_length(p_content->'skill_selections') not between 1 and 50
    or jsonb_array_length(p_content->'resource_blueprints') > 50
    or (p_content->>'registration_capacity_recommendation')::integer not between 1 and 100000
    or (p_content->>'duration_seconds')::numeric <= 0
    or (p_content->>'duration_seconds')::numeric >= 'Infinity'::numeric
    or jsonb_typeof(p_content->'registration_capacity_recommendation') <> 'number'
    or jsonb_typeof(p_content->'duration_seconds') <> 'number'
    or (p_content->>'cover_asset_key' is not null and p_content->>'cover_asset_key' not in
      ('repair-cafe','mural','seedling-trays','acoustic-concert','reading-group','makers-table')) then
    raise exception using errcode = '22023', message = 'Invalid reviewed starter content.';
  end if;
  for entry in select value from jsonb_array_elements(p_content->'skill_selections') loop
    if jsonb_typeof(entry) <> 'object' or (select count(*) from jsonb_object_keys(entry)) <> 2
      or entry->>'importance' is null or entry->>'importance' not in ('required','useful')
      or not exists(select 1 from public.skills s where s.slug = entry->>'slug') then
      raise exception using errcode = '22023', message = 'Invalid controlled starter skill.';
    end if;
  end loop;
  if (select count(*) <> count(distinct s->>'slug')
      from jsonb_array_elements(p_content->'skill_selections') s) then
    raise exception using errcode = '22023', message = 'Duplicate starter skills.';
  end if;
  for entry in select value from jsonb_array_elements(p_content->'resource_blueprints') loop
    if jsonb_typeof(entry) <> 'object' or (select count(*) from jsonb_object_keys(entry)) <> 3
      or not entry ?& array['source_need_id','title','details']
      or (entry->>'source_need_id')::uuid is null
      or jsonb_typeof(entry->'title') <> 'string'
      or char_length(btrim(entry->>'title')) not between 1 and 160
      or jsonb_typeof(entry->'details') <> 'string'
      or char_length(entry->>'details') > 1000 then
      raise exception using errcode = '22023', message = 'Invalid starter resource blueprint.';
    end if;
  end loop;
  if (select count(*) <> count(distinct n->>'source_need_id')
      from jsonb_array_elements(p_content->'resource_blueprints') n) then
    raise exception using errcode = '22023', message = 'Duplicate starter resource identities.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('official.starter:' || p_key, 0));
  select * into t from private.proposal_templates where starter_key = p_key for update;
  if found then
    if t.id <> p_template_id then
      raise exception using errcode = '22023', message = 'Starter identity drift.';
    end if;
    select content into previous from private.official_starter_template_content where template_id = t.id;
    if not found then
      raise exception using errcode = 'PT409', message = 'Starter content is missing; review inventory before repairing.';
    end if;
    current_hash := private.proposal_template_content_version(previous);
    if previous = p_content and (t.removed_at is not null) = p_retire then return current_hash; end if;
    if current_hash is distinct from p_expected_content_hash or t.removed_at is not null then
      raise exception using errcode = 'PT409', message = 'Starter content drift or terminal retirement; review current inventory.';
    end if;
  else
    if p_expected_content_hash is not null or p_retire then
      raise exception using errcode = 'PT409', message = 'Expected starter is missing.';
    end if;
    insert into private.proposal_templates(id, template_kind, starter_key, linked_at)
    values (p_template_id, 'official_starter', p_key, '2026-10-11 00:00:00+00');
  end if;
  insert into private.official_starter_template_content(template_id, content)
  values (p_template_id, p_content)
  on conflict (template_id) do update set content = excluded.content;
  if p_retire then
    update private.proposal_templates set removed_at = clock_timestamp() where id = p_template_id;
  end if;
  insert into private.official_starter_template_reviews(template_id, reason, previous_content, accepted_content, retired)
  values (p_template_id, btrim(p_reason), previous, p_content, p_retire);
  return private.proposal_template_content_version(p_content);
end;
$$;
revoke all on function private.workshop_template_content(uuid),
  private.provision_official_starter_template(uuid,text,text,jsonb,text,boolean)
  from public, anon, authenticated, service_role;


-- Compose organization provenance with the existing atomic application and moderation paths.
create or replace function private.protect_proposal_template_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.id, new.source_proposal_id, new.original_creator_profile_id, new.linked_at, new.template_kind, new.starter_key)
    is distinct from
    (old.id, old.source_proposal_id, old.original_creator_profile_id, old.linked_at, old.template_kind, old.starter_key) then
    raise exception using errcode = '55000',
      message = 'A linked template identity cannot be changed.';
  end if;
  return new;
end;
$$;

create or replace function private.is_proposal_template_publicly_usable(
  p_template_id uuid, p_reference_time timestamptz
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from private.proposal_templates t
    join private.official_starter_template_content c on c.template_id=t.id
    where t.id=p_template_id and t.template_kind='official_starter'
      and t.removed_at is null and p_reference_time is not null and isfinite(p_reference_time)
  ) or exists (
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
$$;

create or replace function public.create_proposal_draft_from_template(
  p_expected_creator_profile_id uuid,
  p_template_id uuid,
  p_content_version text,
  p_client_request_id uuid,
  p_prefill_capacity boolean default true
)
returns table (
  request_id uuid, proposal_id uuid, template_id uuid, source_proposal_id uuid,
  accepted_content_version text, prefill_capacity boolean,
  capacity_recommendation integer, duration_seconds numeric,
  accepted_at timestamptz, outcome text
)
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
  receipt private.proposal_template_applications%rowtype;
  source_id uuid;
  payload jsonb;
  accepted_version text;
  skill_ids uuid[];
  skill_importances text[];
  blueprint jsonb;
  new_proposal_id uuid;
  recommendation integer;
begin
  if p_template_id is null or p_client_request_id is null
    or p_content_version is null or p_content_version !~ '^tw01:[0-9a-f]{64}$'
    or p_prefill_capacity is null then
    raise exception using errcode = '22023', message = 'A template, exact content version, request ID and capacity choice are required.';
  end if;

  -- Independent namespace; duplicates wait here before any source lock/write.
  perform pg_advisory_xact_lock(hashtextextended(
    'template.apply:' || actor::text || ':' || p_client_request_id::text, 0
  ));
  perform private.require_expected_identity(p_expected_creator_profile_id);
  select * into receipt from private.proposal_template_applications as application
  where application.applicant_profile_id = actor
    and application.client_request_id = p_client_request_id;
  if found then
    if receipt.template_id <> p_template_id
      or receipt.accepted_content_version <> p_content_version
      or receipt.prefill_capacity <> p_prefill_capacity then
      raise exception using errcode = '22023', message = 'This request ID was accepted for different template application inputs.';
    end if;
    if not exists(select 1 from public.proposals as proposal
      where proposal.id = receipt.proposal_id and proposal.creator_profile_id = actor) then
      raise exception using errcode = 'P0002', message = 'The accepted template draft is unavailable.';
    end if;
    return query select receipt.client_request_id, receipt.proposal_id,
      receipt.template_id, receipt.source_proposal_id, receipt.accepted_content_version,
      receipt.prefill_capacity, receipt.capacity_recommendation, receipt.duration_seconds,
      receipt.accepted_at, 'recovered'::text;
    return;
  end if;

  perform private.require_complete_profile(p_expected_creator_profile_id);
  select template.source_proposal_id into source_id
  from private.proposal_templates as template where template.id = p_template_id;
  if not found then
    raise exception using errcode = '42501', message = 'The Proposal template is unavailable.';
  end if;
  -- Same order as TW02 removal: source Proposal -> template, held through commit.
  perform 1 from public.proposals as proposal where proposal.id = source_id for update;
  perform 1 from private.proposal_templates as template
  where template.id = p_template_id and template.source_proposal_id is not distinct from source_id for update;
  perform private.require_expected_identity(p_expected_creator_profile_id);
  perform private.require_complete_profile(p_expected_creator_profile_id);
  if not private.is_proposal_template_publicly_usable(p_template_id, clock_timestamp()) then
    raise exception using errcode = '42501', message = 'The Proposal template is unavailable.';
  end if;
  -- One complete post-wait snapshot. All destination content comes from this value.
  payload := private.workshop_template_content(p_template_id);
  accepted_version := private.proposal_template_content_version(payload);
  if accepted_version <> p_content_version then
    raise exception using errcode = 'PT409', message = 'The Proposal template content changed. Refresh the preview before creating a draft.';
  end if;
  recommendation := (payload->>'registration_capacity_recommendation')::integer;
  select coalesce(array_agg((skill->>'id')::uuid order by ordinal), array[]::uuid[]),
    coalesce(array_agg(skill->>'importance' order by ordinal), array[]::text[])
  into skill_ids, skill_importances
  from jsonb_array_elements(payload->'skills') with ordinality as selected(skill, ordinal);

  new_proposal_id := public.create_proposal_draft(
    actor, payload->>'title', payload->>'summary', payload->>'description',
    null, null, 'Europe/Rome', null, null, null, null, null, 'participants',
    skill_ids, skill_importances,
    case when p_prefill_capacity then recommendation else null end, false
  );
  for blueprint in select value from jsonb_array_elements(payload->'resource_blueprints') loop
    -- Ordinary validation, fresh IDs, locks and identifier-only audit/outbox effects.
    perform public.create_project_resource_need(actor, new_proposal_id,
      blueprint->>'title', blueprint->>'details');
  end loop;
  insert into private.proposal_template_applications (
    applicant_profile_id, client_request_id, proposal_id, template_id, source_proposal_id,
    accepted_content_version, prefill_capacity, capacity_recommendation, duration_seconds
  ) values (
    actor, p_client_request_id, new_proposal_id, p_template_id, source_id,
    accepted_version, p_prefill_capacity, recommendation, (payload->>'duration_seconds')::numeric
  ) returning * into receipt;
  return query select receipt.client_request_id, receipt.proposal_id,
    receipt.template_id, receipt.source_proposal_id, receipt.accepted_content_version,
    receipt.prefill_capacity, receipt.capacity_recommendation, receipt.duration_seconds,
    receipt.accepted_at, 'created'::text;
end;
$$;

create or replace function private.protect_moderation_case_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id <> old.id
    or new.subject_profile_id is distinct from old.subject_profile_id
    or new.target_kind <> old.target_kind
    or new.target_profile_id is distinct from old.target_profile_id
    or new.target_project_id is distinct from old.target_project_id
    or new.target_project_chat_message_id
      is distinct from old.target_project_chat_message_id
    or new.target_resource_listing_id
      is distinct from old.target_resource_listing_id
    or new.target_resource_request_id
      is distinct from old.target_resource_request_id
    or new.target_resource_chat_message_id
      is distinct from old.target_resource_chat_message_id
    or new.project_context_id is distinct from old.project_context_id
    or new.resource_listing_context_id
      is distinct from old.resource_listing_context_id
    or new.resource_request_context_id
      is distinct from old.resource_request_context_id
    or new.resource_chat_context_id
      is distinct from old.resource_chat_context_id
    or new.target_proposal_template_id is distinct from old.target_proposal_template_id
    or new.template_source_proposal_id is distinct from old.template_source_proposal_id
    or new.template_report_content_version is distinct from old.template_report_content_version
    or new.created_at <> old.created_at then
    raise exception using
      errcode = '55000',
      message = 'Moderation case target identity is immutable.';
  end if;

  return new;
end;
$$;

create or replace function public.submit_moderation_report(
  p_expected_reporter_profile_id uuid,
  p_client_submission_id uuid,
  p_category text,
  p_explanation text,
  p_target_kind text,
  p_target_id uuid,
  p_context_kind text default null,
  p_context_id uuid default null
)
returns table (
  report_id uuid,
  case_id uuid,
  state text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  reporter_id uuid := private.require_moderation_identity(
    p_expected_reporter_profile_id,
    true
  );
  normalized_explanation text := regexp_replace(
    coalesce(p_explanation, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  existing_report record;
  template_record private.proposal_templates%rowtype;
  template_content jsonb;
  target_subject_id uuid;
  target_profile_id uuid;
  target_project_id uuid;
  target_project_message_id uuid;
  target_listing_id uuid;
  target_request_id uuid;
  target_resource_message_id uuid;
  project_context_id uuid;
  listing_context_id uuid;
  request_context_id uuid;
  chat_context_id uuid;
  project_record public.projects%rowtype;
  project_message_record public.project_chat_messages%rowtype;
  resource_message_record public.resource_request_chat_messages%rowtype;
  request_record public.resource_listing_requests%rowtype;
  listing_record public.resource_listings%rowtype;
  resource_chat_record public.resource_request_chats%rowtype;
  new_case private.moderation_cases%rowtype;
  new_report private.moderation_reports%rowtype;
begin
  if p_client_submission_id is null
    or p_target_id is null
    or p_target_kind is null
    or p_category not in (
      'safety_concern',
      'harassment_abuse',
      'fraud_scam',
      'inappropriate_content_conduct',
      'spam',
      'other'
    ) then
    raise exception using
      errcode = '22023',
      message = 'The report request is invalid.';
  end if;

  if (p_context_kind is null) <> (p_context_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Report context kind and identifier must be provided together.';
  end if;

  if char_length(normalized_explanation) not between 10 and 4000 then
    raise exception using
      errcode = '22023',
      message = 'The report explanation must contain between 10 and 4,000 characters.';
  end if;

  -- Serialize identity-bound deliveries before target resolution, including retry
  -- after removal. The namespace is separate from Project/profile locks.
  perform pg_advisory_xact_lock(hashtextextended(
    'moderation.report:' || reporter_id::text || ':' || p_client_submission_id::text, 0));

  select
    report.id,
    report.case_id,
    moderation_case.state,
    report.created_at, report.category, report.explanation,
    moderation_case.target_kind,
    moderation_case.target_proposal_template_id
  into existing_report
  from private.moderation_reports as report
  join private.moderation_cases as moderation_case
    on moderation_case.id = report.case_id
  where report.reporter_profile_id = reporter_id
    and report.client_submission_id = p_client_submission_id;

  if found then
    -- Legacy report kinds retain their existing retry contract. Template keys
    -- cannot be reused for changed text/category/target or incident context.
    if (p_target_kind = 'proposal_template' or existing_report.target_kind = 'proposal_template')
      and (existing_report.target_kind is distinct from p_target_kind
        or existing_report.target_proposal_template_id is distinct from p_target_id
        or existing_report.category is distinct from p_category
        or existing_report.explanation is distinct from normalized_explanation
        or p_context_kind is not null or p_context_id is not null) then
      raise exception using errcode = '22023', message = 'The template report retry key has incompatible inputs.';
    end if;
    return query select
      existing_report.id,
      existing_report.case_id,
      existing_report.state,
      existing_report.created_at;
    return;
  end if;

  case p_target_kind
    when 'proposal_template' then
      if p_context_kind is not null then
        raise exception using errcode = '22023', message = 'Template provenance is not incident context.';
      end if;
      select * into template_record from private.proposal_templates where id = p_target_id;
      if not found then
        raise exception using errcode = '42501', message = 'The report target is unavailable.';
      end if;
      -- Source mutations already take the Proposal lock. Use the same order as
      -- removal/future copy, so eligibility and report token come from one state.
      perform 1 from public.proposals where id = template_record.source_proposal_id for update;
      select * into template_record from private.proposal_templates where id = p_target_id for update;
      if private.is_proposal_template_publicly_usable(p_target_id, clock_timestamp()) is not true then
        raise exception using errcode = '42501', message = 'The report target is unavailable.';
      end if;
      template_content := private.workshop_template_content(template_record.id);
      target_subject_id := template_record.original_creator_profile_id;
    when 'profile'  then
      select profile.id into target_subject_id
      from public.profiles as profile
      where profile.id = p_target_id
        and profile.display_name is not null;

      if not found then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_profile_id := p_target_id;

      if p_context_kind = 'project' then
        select * into project_record
        from public.projects as project
        where project.id = p_context_id;

        if not found
          or not private.profile_has_project_association(
            project_record.id,
            reporter_id
          )
          or not private.profile_has_project_association(
            project_record.id,
            target_subject_id
          ) then
          raise exception using
            errcode = '42501',
            message = 'The report target is unavailable.';
        end if;
        project_context_id := project_record.id;
      elsif p_context_kind = 'resource_request' then
        select * into request_record
        from public.resource_listing_requests as request
        where request.id = p_context_id;
        select * into listing_record
        from public.resource_listings as listing
        where listing.id = request_record.listing_id;

        if request_record.id is null
          or listing_record.id is null
          or reporter_id not in (
            listing_record.owner_profile_id,
            request_record.requester_profile_id
          )
          or target_subject_id not in (
            listing_record.owner_profile_id,
            request_record.requester_profile_id
          )
          or target_subject_id = reporter_id then
          raise exception using
            errcode = '42501',
            message = 'The report target is unavailable.';
        end if;

        listing_context_id := listing_record.id;
        request_context_id := request_record.id;
        select chat.id into chat_context_id
        from public.resource_request_chats as chat
        where chat.request_id = request_record.id;
      elsif p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'The report context is invalid for this target.';
      elsif not exists (
        select 1
        from public.profile_field_visibility as visibility
        where visibility.profile_id = target_subject_id
          and visibility.field_key = 'display_name'
          and visibility.audience = 'public'
      ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

    when 'project' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Project reports derive their canonical context.';
      end if;

      select * into project_record
      from public.projects as project
      where project.id = p_target_id;

      if not found or (
        not private.profile_has_project_association(p_target_id, reporter_id)
        and not exists (
          select 1 from public.proposals as proposal
          where proposal.id = p_target_id
            and proposal.lifecycle_state = 'published'
          union all
          select 1 from public.recurring_activities as activity
          where activity.id = p_target_id
            and activity.lifecycle_state = 'published'
        )
      ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := project_record.creator_profile_id;
      target_project_id := project_record.id;
      project_context_id := project_record.id;

    when 'project_chat_message' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Project message reports derive their canonical context.';
      end if;

      select message.* into project_message_record
      from public.project_chat_messages as message
      where message.id = p_target_id;

      select project.* into project_record
      from public.project_group_chats as chat
      join public.projects as project on project.id = chat.project_id
      where chat.id = project_message_record.chat_id;

      if project_message_record.id is null
        or project_record.id is null
        or private.profile_can_read_project_chat_message(
          project_record.id,
          reporter_id,
          project_message_record.created_at
        ) is not true then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := project_message_record.sender_profile_id;
      target_project_message_id := project_message_record.id;
      project_context_id := project_record.id;

    when 'resource_listing' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Resource listing reports derive their canonical context.';
      end if;

      select * into listing_record
      from public.resource_listings as listing
      where listing.id = p_target_id;

      if not found or (
        listing_record.lifecycle_state <> 'published'
        and not exists (
          select 1
          from public.resource_listing_requests as request
          where request.listing_id = listing_record.id
            and request.requester_profile_id = reporter_id
        )
      ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := listing_record.owner_profile_id;
      target_listing_id := listing_record.id;
      listing_context_id := listing_record.id;

    when 'resource_request' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Resource request reports derive their canonical context.';
      end if;

      select * into request_record
      from public.resource_listing_requests as request
      where request.id = p_target_id;
      select * into listing_record
      from public.resource_listings as listing
      where listing.id = request_record.listing_id;

      if request_record.id is null
        or listing_record.id is null
        or reporter_id not in (
          listing_record.owner_profile_id,
          request_record.requester_profile_id
        ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := case
        when reporter_id = listing_record.owner_profile_id
          then request_record.requester_profile_id
        else listing_record.owner_profile_id
      end;
      target_request_id := request_record.id;
      listing_context_id := listing_record.id;
      request_context_id := request_record.id;

    when 'resource_chat_message' then
      if p_context_kind is not null then
        raise exception using
          errcode = '22023',
          message = 'Resource message reports derive their canonical context.';
      end if;

      select message.* into resource_message_record
      from public.resource_request_chat_messages as message
      where message.id = p_target_id;
      select * into resource_chat_record
      from public.resource_request_chats as chat
      where chat.id = resource_message_record.chat_id;
      select * into request_record
      from public.resource_listing_requests as request
      where request.id = resource_chat_record.request_id;
      select * into listing_record
      from public.resource_listings as listing
      where listing.id = request_record.listing_id;

      if resource_message_record.id is null
        or resource_chat_record.id is null
        or request_record.id is null
        or listing_record.id is null
        or reporter_id not in (
          listing_record.owner_profile_id,
          request_record.requester_profile_id
        ) then
        raise exception using
          errcode = '42501',
          message = 'The report target is unavailable.';
      end if;

      target_subject_id := resource_message_record.sender_profile_id;
      target_resource_message_id := resource_message_record.id;
      listing_context_id := listing_record.id;
      request_context_id := request_record.id;
      chat_context_id := resource_chat_record.id;

    else
      raise exception using
        errcode = '22023',
        message = 'The report target kind is unsupported.';
  end case;

  if target_subject_id = reporter_id and p_target_kind <> 'proposal_template' then
    raise exception using
      errcode = '22023',
      message = 'A profile cannot report itself.';
  end if;

  insert into private.moderation_cases (
    target_proposal_template_id,
    template_source_proposal_id,
    template_report_content_version,
    subject_profile_id,
    target_kind,
    target_profile_id,
    target_project_id,
    target_project_chat_message_id,
    target_resource_listing_id,
    target_resource_request_id,
    target_resource_chat_message_id,
    project_context_id,
    resource_listing_context_id,
    resource_request_context_id,
    resource_chat_context_id
  )
  values (
    template_record.id,
    template_record.source_proposal_id,
    case when template_record.id is not null then private.proposal_template_content_version(template_content) end,
    target_subject_id,
    p_target_kind,
    target_profile_id,
    target_project_id,
    target_project_message_id,
    target_listing_id,
    target_request_id,
    target_resource_message_id,
    project_context_id,
    listing_context_id,
    request_context_id,
    chat_context_id
  )
  returning * into new_case;

  insert into private.moderation_reports (
    case_id,
    reporter_profile_id,
    client_submission_id,
    category,
    explanation,
    created_at
  )
  values (
    new_case.id,
    reporter_id,
    p_client_submission_id,
    p_category,
    normalized_explanation,
    new_case.created_at
  )
  returning * into new_report;

  insert into private.moderation_case_events (
    case_id,
    actor_profile_id,
    event_kind,
    to_state,
    state_version,
    created_at
  )
  values (
    new_case.id,
    reporter_id,
    'report_received',
    'received',
    0,
    new_case.created_at
  );

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'moderation.report_submitted',
    reporter_id,
    'moderation_case',
    new_case.id,
    jsonb_build_object(
      'case_id', new_case.id,
      'report_id', new_report.id,
      'target_kind', new_case.target_kind
    ),
    new_case.created_at
  );

  return query select
    new_report.id,
    new_case.id,
    new_case.state,
    new_report.created_at;
end;
$$;

create or replace function public.get_moderation_case_template(
  p_expected_staff_profile_id uuid, p_case_id uuid
)
returns table (
  template_id uuid, source_proposal_id uuid, original_creator_profile_id uuid,
  report_content_version text, current_content_version text, content_changed boolean,
  publicly_available boolean, removed_at timestamptz, content jsonb,
  resource_blueprint_count integer, removal_action jsonb
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  return query
  with reviewed as materialized (
    select t.*, c.template_report_content_version,
      private.workshop_template_content(t.id) as payload
    from private.moderation_cases as c
    join private.proposal_templates as t on t.id = c.target_proposal_template_id
    where c.id = p_case_id and c.target_kind = 'proposal_template'
  )
  select r.id, r.source_proposal_id, r.original_creator_profile_id,
    r.template_report_content_version, private.proposal_template_content_version(r.payload),
    r.template_report_content_version <> private.proposal_template_content_version(r.payload),
    private.is_proposal_template_publicly_usable(r.id, statement_timestamp()),
    r.removed_at, r.payload - 'resource_blueprints',
    jsonb_array_length(r.payload->'resource_blueprints'),
    (select jsonb_build_object(
      'action_id', a.id, 'case_id', a.case_id, 'actor_profile_id', a.actor_profile_id,
      'actor_display_name', actor.display_name, 'effective_at', a.effective_at,
      'reviewed_content_version', a.reviewed_content_version, 'reason', a.reason)
     from private.proposal_template_removal_actions as a
     join public.profiles as actor on actor.id = a.actor_profile_id
     where a.template_id = r.id and a.outcome = 'removed')
  from reviewed as r;
end;
$$;

create or replace function public.list_moderation_case_template_blueprints(
  p_expected_staff_profile_id uuid, p_case_id uuid, p_content_version text,
  p_limit integer default 20, p_cursor_need_id uuid default null
)
returns table(source_need_id uuid, title text, details text)
language plpgsql stable security definer set search_path = ''
as $$
declare
  payload jsonb;
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  if p_limit is null or p_limit not between 1 and 50
    or p_content_version is null or p_content_version !~ '^tw01:[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'The staff template page is invalid.';
  end if;
  select private.workshop_template_content(c.target_proposal_template_id) into payload
  from private.moderation_cases as c
  where c.id = p_case_id and c.target_kind = 'proposal_template';
  if not found then return; end if;
  if private.proposal_template_content_version(payload) <> p_content_version then
    raise exception using errcode = 'PT409', message = 'Template content changed; refresh the review.';
  end if;
  return query select (need->>'source_need_id')::uuid, need->>'title', need->>'details'
    from jsonb_array_elements(payload->'resource_blueprints') as need
    where p_cursor_need_id is null or (need->>'source_need_id')::uuid > p_cursor_need_id
    order by (need->>'source_need_id')::uuid limit p_limit;
end;
$$;

create or replace function public.remove_moderation_case_template(
  p_expected_staff_profile_id uuid, p_case_id uuid, p_template_id uuid,
  p_client_request_id uuid, p_reviewed_content_version text, p_reason text
)
returns table (
  request_id uuid, outcome text, effective_action_id uuid,
  effective_at timestamptz, effective_actor_profile_id uuid
)
language plpgsql security definer set search_path = ''
as $$
declare
  normalized_reason text := regexp_replace(coalesce(p_reason,''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
  linked_template private.proposal_templates%rowtype;
  receipt private.proposal_template_removal_actions%rowtype;
  effective private.proposal_template_removal_actions%rowtype;
  new_id uuid := gen_random_uuid();
  action_time timestamptz;
  current_token text;
begin
  -- Always establish the current identity/role before recovering a receipt.
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  if p_case_id is null or p_template_id is null or p_client_request_id is null
    or p_reviewed_content_version is null or p_reviewed_content_version !~ '^tw01:[0-9a-f]{64}$'
    or char_length(normalized_reason) not between 10 and 4000 then
    raise exception using errcode = '22023', message = 'The template removal request is invalid.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'moderation.template.remove:' || p_expected_staff_profile_id::text || ':' || p_client_request_id::text, 0));
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  select * into receipt from private.proposal_template_removal_actions as a
    where a.actor_profile_id = p_expected_staff_profile_id and a.client_request_id = p_client_request_id;
  if found then
    if (receipt.case_id, receipt.template_id, receipt.reviewed_content_version, receipt.reason)
      is distinct from (p_case_id, p_template_id, p_reviewed_content_version, normalized_reason) then
      raise exception using errcode = '22023', message = 'The removal retry key has incompatible inputs.';
    end if;
  else
    select t.* into linked_template from private.proposal_templates as t
      join private.moderation_cases as c on c.target_proposal_template_id = t.id
      where c.id = p_case_id and c.target_kind = 'proposal_template' and t.id = p_template_id;
    if not found then
      raise exception using errcode = '42501', message = 'The template case target is unavailable.';
    end if;
    -- Canonical lock order: source Proposal -> template -> case. TW03 must
    -- take the same source/template locks and recheck eligibility/token after
    -- waiting, holding both through the independent draft copy transaction.
    perform 1 from public.proposals where id = linked_template.source_proposal_id for update;
    select * into linked_template from private.proposal_templates where id = p_template_id for update;
    perform 1 from private.moderation_cases where id = p_case_id for update;
    -- A staff revocation committed while waiting also denies the action.
    perform private.require_moderation_staff(p_expected_staff_profile_id);
    current_token := private.proposal_template_content_version(
      private.workshop_template_content(linked_template.id));
    if current_token <> p_reviewed_content_version then
      raise exception using errcode = 'PT409', message = 'Template content changed; refresh the review.';
    end if;
    action_time := clock_timestamp();
    if linked_template.removed_at is null then
      update private.proposal_templates set removed_at = action_time where id = p_template_id;
      insert into private.proposal_template_removal_actions(
        id, actor_profile_id, client_request_id, case_id, template_id, source_proposal_id,
        reviewed_content_version, reason, outcome, effective_action_id, effective_at, created_at
      ) values (new_id, p_expected_staff_profile_id, p_client_request_id, p_case_id, p_template_id,
        linked_template.source_proposal_id, current_token, normalized_reason, 'removed', new_id, action_time, action_time)
      returning * into receipt;
      insert into private.audit_events(action, actor_user_id, target_type, target_id, metadata, created_at)
      values ('moderation.template_removed', p_expected_staff_profile_id, 'proposal_template', p_template_id,
        jsonb_build_object('case_id', p_case_id, 'action_id', new_id, 'reason_record_id', new_id,
          'template_id', p_template_id, 'source_proposal_id', linked_template.source_proposal_id,
          'request_id', p_client_request_id), action_time);
    else
      select * into effective from private.proposal_template_removal_actions as a
        where a.template_id = p_template_id and a.outcome = 'removed';
      if not found or effective.effective_at <> linked_template.removed_at then
        raise exception using errcode = '55000', message = 'Template removal attribution is inconsistent.';
      end if;
      insert into private.proposal_template_removal_actions(
        id, actor_profile_id, client_request_id, case_id, template_id, source_proposal_id,
        reviewed_content_version, reason, outcome, effective_action_id, effective_at, created_at
      ) values (new_id, p_expected_staff_profile_id, p_client_request_id, p_case_id, p_template_id,
        linked_template.source_proposal_id, current_token, normalized_reason, 'already_removed',
        effective.id, effective.effective_at, action_time) returning * into receipt;
    end if;
  end if;
  return query select receipt.id, receipt.outcome, a.id, a.effective_at, a.actor_profile_id
    from private.proposal_template_removal_actions as a where a.id = receipt.effective_action_id;
end;
$$;

create or replace function public.list_moderation_cases(
  p_expected_staff_profile_id uuid,
  p_state text default null,
  p_limit integer default 25,
  p_before_created_at timestamptz default null,
  p_before_case_id uuid default null
)
returns table (
  case_id uuid,
  state text,
  state_version bigint,
  created_at timestamptz,
  category text,
  target_kind text,
  target_summary text,
  context_summary text,
  subject_profile_id uuid,
  subject_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);

  if p_state is not null
    and p_state not in ('received', 'under_review', 'completed') then
    raise exception using
      errcode = '22023',
      message = 'The moderation state filter is invalid.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Moderation queue page size must be between 1 and 50.';
  end if;

  if (p_before_created_at is null) <> (p_before_case_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both moderation queue cursor values must be provided together.';
  end if;

  return query
  select
    moderation_case.id,
    moderation_case.state,
    moderation_case.state_version,
    moderation_case.created_at,
    report.category,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    moderation_case.subject_profile_id,
    case when moderation_case.subject_profile_id is null then 'Planets Community Official' else subject.display_name end
  from private.moderation_cases as moderation_case
  join private.moderation_reports as report
    on report.case_id = moderation_case.id
  left join public.profiles as subject
    on subject.id = moderation_case.subject_profile_id
  where (p_state is null or moderation_case.state = p_state)
    and (
      p_before_created_at is null
      or (moderation_case.created_at, moderation_case.id)
        < (p_before_created_at, p_before_case_id)
    )
  order by moderation_case.created_at desc, moderation_case.id desc
  limit p_limit;
end;
$$;

create or replace function public.get_moderation_case_detail(
  p_expected_staff_profile_id uuid,
  p_case_id uuid
)
returns table (
  case_id uuid,
  state text,
  state_version bigint,
  created_at timestamptz,
  completed_at timestamptz,
  category text,
  explanation text,
  target_kind text,
  target_summary text,
  context_summary text,
  reporter_profile_id uuid,
  reporter_display_name text,
  subject_profile_id uuid,
  subject_display_name text,
  project_context_id uuid,
  resource_listing_context_id uuid,
  resource_request_context_id uuid,
  resource_chat_context_id uuid,
  notes jsonb,
  events jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);

  return query
  select
    moderation_case.id,
    moderation_case.state,
    moderation_case.state_version,
    moderation_case.created_at,
    moderation_case.completed_at,
    report.category,
    report.explanation,
    moderation_case.target_kind,
    private.moderation_target_summary(moderation_case),
    private.moderation_context_summary(moderation_case),
    report.reporter_profile_id,
    reporter.display_name,
    moderation_case.subject_profile_id,
    case when moderation_case.subject_profile_id is null then 'Planets Community Official' else subject.display_name end,
    moderation_case.project_context_id,
    moderation_case.resource_listing_context_id,
    moderation_case.resource_request_context_id,
    moderation_case.resource_chat_context_id,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'note_id', note.id,
            'author_profile_id', note.author_profile_id,
            'author_display_name', author.display_name,
            'body', note.body,
            'created_at', note.created_at
          ) order by note.created_at, note.id
        )
        from private.moderation_case_notes as note
        join public.profiles as author on author.id = note.author_profile_id
        where note.case_id = moderation_case.id
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'event_id', event.id,
            'actor_profile_id', event.actor_profile_id,
            'actor_display_name', actor.display_name,
            'event_kind', event.event_kind,
            'from_state', event.from_state,
            'to_state', event.to_state,
            'state_version', event.state_version,
            'note_id', event.note_id,
            'created_at', event.created_at
          ) order by event.created_at, event.id
        )
        from private.moderation_case_events as event
        join public.profiles as actor on actor.id = event.actor_profile_id
        where event.case_id = moderation_case.id
      ),
      '[]'::jsonb
    )
  from private.moderation_cases as moderation_case
  join private.moderation_reports as report
    on report.case_id = moderation_case.id
  join public.profiles as reporter on reporter.id = report.reporter_profile_id
  left join public.profiles as subject
    on subject.id = moderation_case.subject_profile_id
  where moderation_case.id = p_case_id;
end;
$$;

-- Opt-in reads preserve all legacy RPC shapes and community-only results.
create function public.list_public_proposal_templates_v2(
  p_limit integer default 20, p_cursor_linked_at timestamptz default null,
  p_cursor_id uuid default null, p_skill_ids uuid[] default null, p_query text default null
)
returns table (
  template_id uuid, source_proposal_id uuid, linked_at timestamptz,
  title text, summary text, skills jsonb, cover_object_path text,
  original_creator_profile_id uuid, creator_display_name text,
  is_official boolean, cover_asset_key text
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
  -- Legacy cards retain their unchanged source/public-name projection.
  return query
  with community as materialized (
    select * from public.list_public_proposal_templates(
      p_limit, p_cursor_linked_at, p_cursor_id, p_skill_ids, p_query)
  ), official as materialized (
    select t.id, t.linked_at, private.workshop_template_content(t.id) as payload
    from private.proposal_templates t
    where t.template_kind='official_starter'
      and private.is_proposal_template_publicly_usable(t.id, statement_timestamp())
      and (p_cursor_linked_at is null or (t.linked_at,t.id)<(p_cursor_linked_at,p_cursor_id))
  ), combined as (
    select c.*, false as is_official, null::text as cover_asset_key from community c
    union all
    select o.id, null::uuid, o.linked_at, o.payload->>'title', o.payload->>'summary',
      o.payload->'skills', null::text, null::uuid, 'Planets Community Official'::text,
      true, o.payload->>'cover_asset_key'
    from official o
    where (nullif(btrim(p_query),'') is null
      or position(lower(btrim(p_query)) in lower(o.payload->>'title'))>0
      or position(lower(btrim(p_query)) in lower(o.payload->>'summary'))>0
      or position(lower(btrim(p_query)) in lower(o.payload->>'description'))>0)
      and (coalesce(cardinality(p_skill_ids),0)=0 or exists (
        select 1 from jsonb_array_elements(o.payload->'skills') s
        where (s->>'id')::uuid=any(p_skill_ids)))
  ) select c.* from combined c order by c.linked_at desc,c.template_id desc limit p_limit;
end;
$$;

create function public.get_public_proposal_template_v2(p_template_id uuid)
returns table (
  template_id uuid, source_proposal_id uuid, content_version text,
  original_creator_profile_id uuid, creator_display_name text,
  title text, summary text, description text, skills jsonb,
  registration_capacity_recommendation integer, duration_seconds numeric,
  cover_object_path text, resource_blueprint_count integer,
  is_official boolean, cover_asset_key text
)
language sql stable security definer set search_path = ''
as $$
  select c.*, false, null::text from public.get_public_proposal_template(p_template_id) c
  union all
  select t.id,null::uuid,private.proposal_template_content_version(c.payload),
    null::uuid,'Planets Community Official'::text,c.payload->>'title',c.payload->>'summary',
    c.payload->>'description',c.payload->'skills',
    (c.payload->>'registration_capacity_recommendation')::integer,
    (c.payload->>'duration_seconds')::numeric,null::text,
    jsonb_array_length(c.payload->'resource_blueprints'),true,c.payload->>'cover_asset_key'
  from private.proposal_templates t
  cross join lateral (select private.workshop_template_content(t.id) as payload) c
  where t.id=p_template_id and t.template_kind='official_starter'
    and private.is_proposal_template_publicly_usable(t.id,statement_timestamp())
$$;

create function public.list_public_proposal_template_resource_blueprints_v2(
  p_template_id uuid, p_content_version text,
  p_limit integer default 20, p_cursor_need_id uuid default null
)
returns table(source_need_id uuid,title text,details text)
language plpgsql stable security definer set search_path = ''
as $$
declare payload jsonb;
begin
  if p_limit is null or p_limit not between 1 and 50 or p_content_version is null
    or p_content_version !~ '^tw01:[0-9a-f]{64}$' then
    raise exception using errcode='22023',message='Invalid template blueprint page.';
  end if;
  select private.workshop_template_content(t.id) into payload
  from private.proposal_templates t where t.id=p_template_id
    and private.is_proposal_template_publicly_usable(t.id,statement_timestamp());
  if not found then return; end if;
  if private.proposal_template_content_version(payload) <> p_content_version then
    raise exception using errcode='PT409',message='Template content changed; refresh the preview.';
  end if;
  return query select (n->>'source_need_id')::uuid,n->>'title',n->>'details'
  from jsonb_array_elements(payload->'resource_blueprints') n
  where p_cursor_need_id is null or (n->>'source_need_id')::uuid>p_cursor_need_id
  order by (n->>'source_need_id')::uuid limit p_limit;
end;
$$;
revoke all on function public.list_public_proposal_templates_v2(integer,timestamptz,uuid,uuid[],text),
  public.get_public_proposal_template_v2(uuid),
  public.list_public_proposal_template_resource_blueprints_v2(uuid,text,integer,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.list_public_proposal_templates_v2(integer,timestamptz,uuid,uuid[],text),
  public.get_public_proposal_template_v2(uuid),
  public.list_public_proposal_template_resource_blueprints_v2(uuid,text,integer,uuid)
  to anon,authenticated;
comment on function public.list_public_proposal_templates_v2(integer,timestamptz,uuid,uuid[],text) is
  'OST01 opt-in unified Workshop. Official examples have null source/profile IDs, server attribution and bundled licensed cover keys. Legacy RPCs remain community-only.';
comment on function private.provision_official_starter_template(uuid,text,text,jsonb,text,boolean) is
  'Database-owner reviewed starter-only maintenance. Stable key/ID, raw-content hash compare-and-set, exact-repeat no-op, audited content changes and terminal retirement. Never granted to API roles.';
comment on table private.proposal_templates is
  'Immutable Workshop identities: genuine source-linked community or non-human official starter examples. No official Auth identity, completed Project, membership or statistics.';

-- Reviewed OST01 catalog. Exact repeats are no-ops; edits require an expected hash.
select private.provision_official_starter_template('ea56119c-ea7d-57a6-8347-45ee8525124d','repair',null,
$starter${"title":"Repair Café: una mattina per aggiustare piccoli oggetti","summary":"Accoglienza, piccoli controlli sicuri e un banco condiviso: un esempio da adattare al proprio quartiere.","description":"Accogliamo gli oggetti e decidiamo insieme quali controlli semplici possiamo fare. Separiamo le riparazioni alla nostra portata da quelle da affidare a un professionista; niente lavori su impianti o apparecchi alimentati. Organizziamo piccoli gruppi, annotiamo il prossimo passo e lasciamo puliti i tavoli. Questo esempio non garantisce la riuscita di una riparazione.","skill_selections":[{"slug":"basic-repairs","importance":"required"},{"slug":"woodworking","importance":"useful"}],"registration_capacity_recommendation":16,"duration_seconds":10800,"cover_asset_key":"repair-cafe","resource_blueprints":[{"source_need_id":"0683568f-ae11-595f-85ad-5ecd93d5d5db","title":"Attrezzi manuali","details":"Cacciaviti, pinze e piccoli morsetti; condividiamo solo utensili adatti al lavoro."},{"source_need_id":"660b360d-7068-541b-8c8d-db2b68b302d0","title":"Tavoli da lavoro","details":"Due superfici stabili e protezioni per appoggiare gli oggetti."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('643c276c-d176-5b6d-80b5-082b76d6d674','mural',null,
$starter${"title":"Murale di quartiere: prepariamo e dipingiamo insieme","summary":"Dal disegno condiviso alla pulizia finale, con ruoli anche per chi non dipinge.","description":"Concordiamo un disegno semplice e verifichiamo prima le autorizzazioni necessarie per la superficie scelta. Proteggiamo il pavimento, prepariamo il supporto e dividiamo il disegno in parti. Lavoriamo in piccoli gruppi con colori adatti; riordiniamo materiali e spazio senza promettere un risultato professionale.","skill_selections":[{"slug":"mural-painting","importance":"required"},{"slug":"event-organization","importance":"useful"}],"registration_capacity_recommendation":20,"duration_seconds":10800,"cover_asset_key":"mural","resource_blueprints":[{"source_need_id":"69b57213-8f86-5a5e-8678-fc60e4f65a72","title":"Teli di protezione","details":"Teli riutilizzabili e nastro per proteggere le superfici vicine."},{"source_need_id":"8ab561d3-f205-557b-89ab-f8a466be91bc","title":"Pennelli e rulli","details":"Pennelli di diverse misure e contenitori per lavaggio e riuso."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('4e28f7c7-d532-5b5f-880f-5dddae174d91','flowerbed',null,
$starter${"title":"Aiuola condivisa: piantiamo e curiamo uno spazio comune","summary":"Prepariamo il terreno, scegliamo piante adatte e concordiamo i turni di cura.","description":"Verifichiamo che lo spazio possa essere usato e scegliamo piante adatte al luogo. Prepariamo il terreno con attrezzi manuali, disponiamo le piante e annaffiamo. Concludiamo concordando chi potrà seguire la cura e quando rivedersi; il modello non certifica autorizzazioni o manutenzione futura.","skill_selections":[{"slug":"gardening","importance":"required"},{"slug":"urban-gardening","importance":"useful"}],"registration_capacity_recommendation":12,"duration_seconds":10800,"cover_asset_key":"seedling-trays","resource_blueprints":[{"source_need_id":"cae43f71-11ed-5538-88fd-5147bcfbd57f","title":"Attrezzi da aiuola","details":"Palette, guanti e un piccolo rastrello da condividere."},{"source_need_id":"444c0f23-ff07-5085-8661-b811bde7af46","title":"Annaffiatoi","details":"Annaffiatoi e acqua disponibile nel luogo concordato."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('2a9128ad-c37c-5880-8441-519fcdfa9489','concert',null,
$starter${"title":"Concerto acustico di quartiere: suoniamo e prepariamo lo spazio","summary":"Set brevi, allestimento semplice e tempo per riordinare insieme.","description":"Concordiamo brevi set acustici e controlliamo le condizioni d'uso dello spazio. Prepariamo posti a sedere e un passaggio libero; proviamo il volume senza disturbare. Alterniamo musica e pause, poi ritiriamo strumenti e sedie. Chi non suona può aiutare nell'allestimento.","skill_selections":[{"slug":"musician","importance":"required"},{"slug":"audio-sound-setup","importance":"useful"}],"registration_capacity_recommendation":24,"duration_seconds":10800,"cover_asset_key":"acoustic-concert","resource_blueprints":[{"source_need_id":"29c5b82c-d80f-5af8-81e4-9e2829b5b42c","title":"Sedie pieghevoli","details":"Sedie stabili, con spazio per passaggi accessibili."},{"source_need_id":"c9144037-fe9e-570b-8409-76bfdef4abfa","title":"Audio essenziale","details":"Un piccolo impianto solo se adatto allo spazio e gestito da chi lo conosce."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('9aabac0d-67ec-5d16-8aef-70a19c4756cc','trail',null,
$starter${"title":"Pulizia del sentiero: raccogliamo e separiamo i rifiuti","summary":"Un percorso breve con briefing, raccolta sicura e conferimento concordato.","description":"Scegliamo un percorso accessibile e verifichiamo come conferire i materiali. Spieghiamo quali rifiuti possiamo raccogliere: oggetti taglienti o sospetti restano a personale competente. In coppia raccogliamo e separiamo i materiali ordinari, poi portiamo i sacchi al punto concordato e riordiniamo gli attrezzi.","skill_selections":[{"slug":"event-organization","importance":"required"},{"slug":"gardening","importance":"useful"}],"registration_capacity_recommendation":18,"duration_seconds":10800,"cover_asset_key":null,"resource_blueprints":[{"source_need_id":"488defd9-fde0-5522-817a-b886149d4310","title":"Guanti da lavoro","details":"Guanti integri della misura adatta; niente raccolta a mani nude."},{"source_need_id":"6e62e176-2663-5269-8134-53633f0d6790","title":"Sacchi per raccolta","details":"Sacchi distinti per i materiali ordinari e pinze manuali."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('eb64ee8e-da21-57cb-876f-15aa6ff4387f','books',null,
$starter${"title":"Scambio di libri: portane uno e scopri nuove letture","summary":"Esponiamo libri, scambiamo consigli e decidiamo la destinazione di quelli rimasti.","description":"Raccogliamo libri in buono stato e li ordiniamo su tavoli con etichette leggibili. Ognuno può proporre una lettura o scegliere un libro; concordiamo una regola semplice di scambio. Prima di chiudere decidiamo insieme dove lasciare i libri rimasti, senza promettere donazioni già autorizzate.","skill_selections":[{"slug":"facilitation","importance":"required"},{"slug":"event-organization","importance":"useful"}],"registration_capacity_recommendation":16,"duration_seconds":10800,"cover_asset_key":"reading-group","resource_blueprints":[{"source_need_id":"47d292c0-8e07-5921-81fd-104e27a64351","title":"Tavoli espositivi","details":"Superfici asciutte e stabili per libri ed etichette."},{"source_need_id":"fee7accb-6dda-56e6-853c-3cccdb657111","title":"Cartelli leggibili","details":"Cartoncini e pennarelli per orientarsi tra le letture."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('85825093-ef29-5d50-82f3-adafdce1f96b','bookcase',null,
$starter${"title":"Libreria di comunità: costruiamo un piccolo punto di scambio","summary":"Progetto semplice, assemblaggio e scelta sicura del posto per i libri.","description":"Disegniamo un piccolo mobile e verifichiamo materiale, stabilità e collocazione consentita. Prepariamo i pezzi con persone capaci di usare gli utensili e assembliamo in piccoli gruppi. Controlliamo bordi e fissaggio, poi concordiamo come mantenerlo e quali libri ospitare. Non sostituisce una verifica tecnica professionale.","skill_selections":[{"slug":"woodworking","importance":"required"},{"slug":"practical-making","importance":"useful"}],"registration_capacity_recommendation":10,"duration_seconds":10800,"cover_asset_key":"makers-table","resource_blueprints":[{"source_need_id":"c32643b3-5975-50fc-8166-d8f3b61345b2","title":"Legno e ferramenta","details":"Pezzi integri di misura concordata, viti e protezioni adatte."},{"source_need_id":"2c8fb1de-62bf-50d2-8650-3bf08342cd2e","title":"Utensili manuali","details":"Morsetti e attrezzi usati solo da chi sa gestirli in sicurezza."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
select private.provision_official_starter_template('0ee962fa-e447-5c21-8ea6-b0fce2079a7d','dinner',null,
$starter${"title":"Cena di quartiere: prepariamo e condividiamo una tavolata","summary":"Coordiniamo preparazione, allestimento e riordino con informazioni chiare sugli alimenti.","description":"Concordiamo luogo e condizioni d'uso, poi dividiamo i compiti tra allestimento, preparazione condivisa e riordino. Ogni contributo alimentare indica ingredienti e allergeni, senza promettere assenza di contaminazioni. Disponiamo tavoli e passaggi comodi, condividiamo la cena e puliamo insieme.","skill_selections":[{"slug":"cooking","importance":"required"},{"slug":"event-organization","importance":"useful"}],"registration_capacity_recommendation":24,"duration_seconds":10800,"cover_asset_key":null,"resource_blueprints":[{"source_need_id":"1bebbe24-4a8f-5a9a-8f50-4be8f512581c","title":"Tavoli pieghevoli","details":"Tavoli stabili e tovaglie lavabili per lo spazio concordato."},{"source_need_id":"0352f3df-c82b-5160-8169-fd4fc9684460","title":"Materiale per servire","details":"Piatti e utensili riutilizzabili, contenitori e cartelli degli ingredienti."}]}$starter$::jsonb, 'OST01 initial reviewed starter catalog');
