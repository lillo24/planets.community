-- DRAFT01: narrow immutable first-creation receipts; no edit history or content copy.
create table private.proposal_draft_creations (
  creator_profile_id uuid not null references public.profiles(id) on delete restrict,
  client_request_id uuid not null,
  proposal_id uuid not null unique references public.proposals(id) on delete restrict,
  accepted_intent_hash text not null check (accepted_intent_hash ~ '^[0-9a-f]{64}$'),
  accepted_at timestamptz not null default clock_timestamp(),
  primary key (creator_profile_id, client_request_id)
);
alter table private.proposal_draft_creations enable row level security;
revoke all on private.proposal_draft_creations from public, anon, authenticated, service_role;
create trigger proposal_draft_creations_append_only
before update or delete on private.proposal_draft_creations
for each row execute function private.protect_moderation_append_only();

create function public.create_editor_proposal_draft(
  p_expected_creator_profile_id uuid, p_client_request_id uuid,
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
  p_skill_importances text[],
  p_registration_capacity integer,
  p_count_organizers_toward_capacity boolean
)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
  receipt private.proposal_draft_creations%rowtype;
  intent_hash text;
  destination uuid;
begin
  if p_client_request_id is null then
    raise exception using errcode = '22023', message = 'A draft creation request ID is required.';
  end if;
  -- Fixed UTC rendering makes timestamptz hashing independent of session zone.
  perform set_config('TimeZone', 'UTC', true);
  intent_hash := encode(extensions.digest(jsonb_build_array(p_title, p_summary, p_description, p_starts_at, p_ends_at, p_event_timezone, p_country_code, p_locality, p_administrative_area, p_public_location_label, p_exact_meeting_text, p_exact_location_visibility, p_skill_ids, p_skill_importances, p_registration_capacity, p_count_organizers_toward_capacity)::text, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended('proposal.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
  perform private.require_expected_identity(p_expected_creator_profile_id);
  select * into receipt from private.proposal_draft_creations
    where creator_profile_id = actor and client_request_id = p_client_request_id;
  if found then
    if receipt.accepted_intent_hash <> intent_hash then
      raise exception using errcode = '22023', message = 'The accepted draft creation intent differs.';
    end if;
    if not exists (select 1 from public.proposals where id = receipt.proposal_id and creator_profile_id = actor) then
      raise exception using errcode = 'P0002', message = 'The recorded draft destination is unavailable.';
    end if;
    return receipt.proposal_id;
  end if;
  -- Ordinary complete-profile and sparse-content validation stay authoritative.
  destination := public.create_proposal_draft(p_expected_creator_profile_id, p_title, p_summary, p_description, p_starts_at, p_ends_at, p_event_timezone, p_country_code, p_locality, p_administrative_area, p_public_location_label, p_exact_meeting_text, p_exact_location_visibility, p_skill_ids, p_skill_importances, p_registration_capacity, p_count_organizers_toward_capacity);
  insert into private.proposal_draft_creations values (actor, p_client_request_id, destination, intent_hash, clock_timestamp());
  return destination;
end;
$$;

create function public.recover_editor_proposal_draft(p_expected_creator_profile_id uuid, p_client_request_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := private.require_expected_identity(p_expected_creator_profile_id);
  destination uuid;
begin
  if p_client_request_id is null then
    raise exception using errcode = '22023', message = 'A draft creation request ID is required.';
  end if;
  -- Wait for the same in-flight creation before deciding that no receipt exists.
  perform pg_advisory_xact_lock(hashtextextended('proposal.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
  perform private.require_expected_identity(p_expected_creator_profile_id);
  select proposal_id into destination from private.proposal_draft_creations
    where creator_profile_id = actor and client_request_id = p_client_request_id;
  if found and not exists (select 1 from public.proposals where id = destination and creator_profile_id = actor) then
    raise exception using errcode = 'P0002', message = 'The recorded draft destination is unavailable.';
  end if;
  return destination;
end;
$$;
revoke all on function public.create_editor_proposal_draft(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[], integer, boolean) from public, anon, authenticated, service_role;
grant execute on function public.create_editor_proposal_draft(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[], integer, boolean) to authenticated;
revoke all on function public.recover_editor_proposal_draft(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.recover_editor_proposal_draft(uuid, uuid) to authenticated;
