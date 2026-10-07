-- UI-NEXT-03: the Italy default belongs only to new template applications.
-- Receipt recovery returns before creation, preserving existing timezone/instants.
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
  if source_id is null then
    raise exception using errcode = '42501', message = 'The Proposal template is unavailable.';
  end if;
  -- Same order as TW02 removal: source Proposal -> template, held through commit.
  perform 1 from public.proposals as proposal where proposal.id = source_id for update;
  perform 1 from private.proposal_templates as template
  where template.id = p_template_id and template.source_proposal_id = source_id for update;
  perform private.require_expected_identity(p_expected_creator_profile_id);
  perform private.require_complete_profile(p_expected_creator_profile_id);
  if not private.is_proposal_template_publicly_usable(p_template_id, clock_timestamp()) then
    raise exception using errcode = '42501', message = 'The Proposal template is unavailable.';
  end if;
  -- One complete post-wait snapshot. All destination content comes from this value.
  payload := private.proposal_template_reusable_content(source_id);
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

comment on function public.create_proposal_draft_from_template(uuid,uuid,text,uuid,boolean) is
  'Identity-bound independent draft application. New drafts default to Europe/Rome with no schedule/location; existing receipts and drafts are never rewritten.';
