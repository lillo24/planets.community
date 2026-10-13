-- GRP03C atomic initial binding. Legacy signatures and recovery remain available.


create function public.create_group_editor_proposal_draft(
  p_expected_creator_profile_id uuid, p_client_request_id uuid, p_title text, p_summary text, p_description text, p_starts_at timestamptz, p_ends_at timestamptz, p_event_timezone text, p_country_code text, p_locality text, p_administrative_area text, p_public_location_label text, p_exact_meeting_text text, p_exact_location_visibility text, p_skill_ids uuid[], p_skill_importances text[], p_registration_capacity integer, p_count_organizers_toward_capacity boolean, p_group_id uuid
) returns uuid
language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
  intent text := private.group_command_hash(jsonb_build_array(p_expected_creator_profile_id,p_client_request_id,p_title,p_summary,p_description,p_starts_at,p_ends_at,p_event_timezone,p_country_code,p_locality,p_administrative_area,p_public_location_label,p_exact_meeting_text,p_exact_location_visibility,p_skill_ids,p_skill_importances,p_registration_capacity,p_count_organizers_toward_capacity,p_group_id));
  receipt private.project_attribution_receipts%rowtype;
  destination uuid;
  result jsonb;
begin
  if p_client_request_id is null then raise sqlstate '22023' using message='A creation request ID is required.'; end if;
  -- The exact legacy namespace also serializes mixed old/new deliveries.
  perform pg_advisory_xact_lock(hashtextextended('proposal.draft_create:'||actor::text||':'||p_client_request_id::text,0));
  perform private.require_expected_identity(p_expected_creator_profile_id);
  select * into receipt from private.project_attribution_receipts where actor_id=actor
    and command_kind='proposal' and client_request_id=p_client_request_id;
  if found then
    if receipt.intent_hash<>intent then raise sqlstate '22023' using message='The accepted creation/group intent differs.'; end if;
    if not exists(select 1 from public.projects where id=receipt.project_id and creator_profile_id=actor) then
      raise sqlstate 'P0002' using message='The accepted Project is unavailable.';
    end if;
    destination := receipt.project_id; result := receipt.accepted_result;
    return destination;

  end if;
  if exists(select 1 from private.proposal_draft_creations where creator_profile_id=actor and client_request_id=p_client_request_id) then
    raise sqlstate '22023' using message='This request was accepted without this group creation intent.';
  end if;
  destination := public.create_editor_proposal_draft(p_expected_creator_profile_id,p_client_request_id,p_title,p_summary,p_description,p_starts_at,p_ends_at,p_event_timezone,p_country_code,p_locality,p_administrative_area,p_public_location_label,p_exact_meeting_text,p_exact_location_visibility,p_skill_ids,p_skill_importances,p_registration_capacity,p_count_organizers_toward_capacity);
  if p_group_id is not null then perform private.assign_project_group(actor,destination,0,p_group_id); end if;
  result := private.project_group_binding(destination);
  insert into private.project_attribution_receipts(actor_id,command_kind,client_request_id,intent_hash,project_id,accepted_result)
    values(actor,'proposal',p_client_request_id,intent,destination,result);
  return destination;
end;
$$;
revoke all on function public.create_group_editor_proposal_draft(uuid,uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[],integer,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_group_editor_proposal_draft(uuid,uuid,text,text,text,timestamptz,timestamptz,text,text,text,text,text,text,text,uuid[],text[],integer,boolean,uuid) to authenticated;


create function public.create_group_editor_recurring_activity_draft(
  p_expected_creator_profile_id uuid, p_client_request_id uuid, p_title text, p_summary text, p_description text, p_topic text, p_country_code text, p_locality text, p_administrative_area text, p_public_location_label text, p_exact_meeting_text text, p_exact_location_visibility text, p_recurrence_type text, p_weekday integer, p_day_of_month integer, p_local_start_time time without time zone, p_duration_minutes integer, p_event_timezone text, p_effective_from date, p_registration_capacity integer, p_count_organizers_toward_capacity boolean, p_group_id uuid
) returns uuid
language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
  intent text := private.group_command_hash(jsonb_build_array(p_expected_creator_profile_id,p_client_request_id,p_title,p_summary,p_description,p_topic,p_country_code,p_locality,p_administrative_area,p_public_location_label,p_exact_meeting_text,p_exact_location_visibility,p_recurrence_type,p_weekday,p_day_of_month,p_local_start_time,p_duration_minutes,p_event_timezone,p_effective_from,p_registration_capacity,p_count_organizers_toward_capacity,p_group_id));
  receipt private.project_attribution_receipts%rowtype;
  destination uuid;
  result jsonb;
begin
  if p_client_request_id is null then raise sqlstate '22023' using message='A creation request ID is required.'; end if;
  -- The exact legacy namespace also serializes mixed old/new deliveries.
  perform pg_advisory_xact_lock(hashtextextended('recurring_activity.draft_create:'||actor::text||':'||p_client_request_id::text,0));
  perform private.require_expected_identity(p_expected_creator_profile_id);
  select * into receipt from private.project_attribution_receipts where actor_id=actor
    and command_kind='recurring' and client_request_id=p_client_request_id;
  if found then
    if receipt.intent_hash<>intent then raise sqlstate '22023' using message='The accepted creation/group intent differs.'; end if;
    if not exists(select 1 from public.projects where id=receipt.project_id and creator_profile_id=actor) then
      raise sqlstate 'P0002' using message='The accepted Project is unavailable.';
    end if;
    destination := receipt.project_id; result := receipt.accepted_result;
    return destination;

  end if;
  if exists(select 1 from private.recurring_draft_creations where actor_profile_id=actor and client_request_id=p_client_request_id) then
    raise sqlstate '22023' using message='This request was accepted without this group creation intent.';
  end if;
  destination := public.create_editor_recurring_activity_draft(p_expected_creator_profile_id,p_client_request_id,p_title,p_summary,p_description,p_topic,p_country_code,p_locality,p_administrative_area,p_public_location_label,p_exact_meeting_text,p_exact_location_visibility,p_recurrence_type,p_weekday,p_day_of_month,p_local_start_time,p_duration_minutes,p_event_timezone,p_effective_from,p_registration_capacity,p_count_organizers_toward_capacity);
  if p_group_id is not null then perform private.assign_project_group(actor,destination,0,p_group_id); end if;
  result := private.project_group_binding(destination);
  insert into private.project_attribution_receipts(actor_id,command_kind,client_request_id,intent_hash,project_id,accepted_result)
    values(actor,'recurring',p_client_request_id,intent,destination,result);
  return destination;
end;
$$;
revoke all on function public.create_group_editor_recurring_activity_draft(uuid,uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time without time zone,integer,text,date,integer,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_group_editor_recurring_activity_draft(uuid,uuid,text,text,text,text,text,text,text,text,text,text,text,integer,integer,time without time zone,integer,text,date,integer,boolean,uuid) to authenticated;


create function public.create_group_proposal_draft_from_template(
  p_expected_creator_profile_id uuid, p_template_id uuid, p_content_version text, p_client_request_id uuid, p_prefill_capacity boolean, p_group_id uuid
) returns table (
  request_id uuid, proposal_id uuid, template_id uuid, source_proposal_id uuid,
  accepted_content_version text, prefill_capacity boolean,
  capacity_recommendation integer, duration_seconds numeric,
  accepted_at timestamptz, outcome text
)
language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
  intent text := private.group_command_hash(jsonb_build_array(p_expected_creator_profile_id,p_template_id,p_content_version,p_client_request_id,p_prefill_capacity,p_group_id));
  receipt private.project_attribution_receipts%rowtype;
  destination uuid;
  result jsonb;
begin
  if p_client_request_id is null then raise sqlstate '22023' using message='A creation request ID is required.'; end if;
  -- The exact legacy namespace also serializes mixed old/new deliveries.
  perform pg_advisory_xact_lock(hashtextextended('template.apply:'||actor::text||':'||p_client_request_id::text,0));
  perform private.require_expected_identity(p_expected_creator_profile_id);
  select * into receipt from private.project_attribution_receipts where actor_id=actor
    and command_kind='template' and client_request_id=p_client_request_id;
  if found then
    if receipt.intent_hash<>intent then raise sqlstate '22023' using message='The accepted creation/group intent differs.'; end if;
    if not exists(select 1 from public.projects where id=receipt.project_id and creator_profile_id=actor) then
      raise sqlstate 'P0002' using message='The accepted Project is unavailable.';
    end if;
    destination := receipt.project_id; result := receipt.accepted_result;
    return query select r.* from jsonb_to_record(result) as r(request_id uuid, proposal_id uuid, template_id uuid, source_proposal_id uuid,
  accepted_content_version text, prefill_capacity boolean,
  capacity_recommendation integer, duration_seconds numeric,
  accepted_at timestamptz, outcome text);
    return;
  end if;
  if exists(select 1 from private.proposal_template_applications where applicant_profile_id=actor and client_request_id=p_client_request_id) then
    raise sqlstate '22023' using message='This request was accepted without this group creation intent.';
  end if;
  select to_jsonb(r) into result from public.create_proposal_draft_from_template(p_expected_creator_profile_id,p_template_id,p_content_version,p_client_request_id,p_prefill_capacity) r;
  destination := (result->>'proposal_id')::uuid;
  if p_group_id is not null then perform private.assign_project_group(actor,destination,0,p_group_id); end if;

  insert into private.project_attribution_receipts(actor_id,command_kind,client_request_id,intent_hash,project_id,accepted_result)
    values(actor,'template',p_client_request_id,intent,destination,result);
  return query select r.* from jsonb_to_record(result) as r(request_id uuid, proposal_id uuid, template_id uuid, source_proposal_id uuid,
  accepted_content_version text, prefill_capacity boolean,
  capacity_recommendation integer, duration_seconds numeric,
  accepted_at timestamptz, outcome text);
end;
$$;
revoke all on function public.create_group_proposal_draft_from_template(uuid,uuid,text,uuid,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_group_proposal_draft_from_template(uuid,uuid,text,uuid,boolean,uuid) to authenticated;
