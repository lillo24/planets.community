-- Delayed projection validates the immutable canonical resolution actor, including
-- former managers. Recipients and privileges remain the existing contract.
create or replace function private.resolve_participation_notification_event(
  p_outbox_event_id uuid
)
returns table (
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  request_record record;
  membership_record record;
  v_recipient_profile_id uuid;
  v_actor_profile_id uuid;
  v_project_id uuid;
  v_payload_actor_profile_id uuid;
  v_payload_project_id uuid;
  v_payload_requester_profile_id uuid;
  v_payload_participant_profile_id uuid;
  v_request_id uuid;
  v_membership_id uuid;
  v_notification_kind text;
  v_destination_kind text;
  v_canonical_resolution_valid boolean := true;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed'
    );

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Participation notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  begin
    v_payload_actor_profile_id := (source_event.payload ->> 'actor_profile_id')::uuid;
    v_payload_project_id := (source_event.payload ->> 'project_id')::uuid;

    if source_event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected'
    ) then
      v_request_id := (source_event.payload ->> 'request_id')::uuid;
      v_payload_requester_profile_id :=
        (source_event.payload ->> 'requester_profile_id')::uuid;
      if source_event.event_type = 'project.join_request_accepted' then
        v_membership_id := (source_event.payload ->> 'membership_id')::uuid;
      end if;
    else
      v_membership_id := (source_event.payload ->> 'membership_id')::uuid;
      v_payload_participant_profile_id :=
        (source_event.payload ->> 'participant_profile_id')::uuid;
    end if;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection could not validate identifiers for outbox event %s.',
          source_event.id
        );
  end;

  if source_event.event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected'
  ) then
    select
      request.id as request_id,
      request.project_id,
      request.requester_profile_id,
      request.resolved_by_profile_id,
      request.status,
      project.creator_profile_id,
      project.project_kind
    into request_record
    from public.project_join_requests as request
    join public.projects as project on project.id = request.project_id
    where request.id = v_request_id;

    if not found
      or v_payload_project_id is distinct from request_record.project_id
      or v_payload_requester_profile_id
        is distinct from request_record.requester_profile_id
      or source_event.payload ->> 'project_kind'
        is distinct from request_record.project_kind then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection could not validate outbox event %s against its canonical join request.',
          source_event.id
        );
    end if;

    v_project_id := request_record.project_id;

    if source_event.event_type = 'project.join_requested' then
      v_recipient_profile_id := request_record.creator_profile_id;
      v_actor_profile_id := request_record.requester_profile_id;
      v_notification_kind := 'participation_request_received';
      v_destination_kind := 'participation_request';
    elsif source_event.event_type = 'project.join_request_withdrawn' then
      v_recipient_profile_id := request_record.creator_profile_id;
      v_actor_profile_id := request_record.requester_profile_id;
      v_notification_kind := 'participation_request_withdrawn';
      v_destination_kind := 'participation_request';
    elsif source_event.event_type = 'project.join_request_accepted' then
      select membership.id
      into v_membership_id
      from public.project_memberships as membership
      where membership.id = v_membership_id
        and membership.originating_request_id = request_record.request_id
        and membership.project_id = request_record.project_id
        and membership.participant_profile_id = request_record.requester_profile_id;

      if not found then
        raise exception using
          errcode = '55000',
          message = format(
            'Notification projection could not validate outbox event %s against its canonical membership.',
            source_event.id
          );
      end if;

      v_recipient_profile_id := request_record.requester_profile_id;
      v_actor_profile_id := request_record.resolved_by_profile_id;
      v_canonical_resolution_valid := request_record.status = 'accepted';
      v_notification_kind := 'participation_request_accepted';
      v_destination_kind := 'participation_request';
    else
      v_recipient_profile_id := request_record.requester_profile_id;
      v_actor_profile_id := request_record.resolved_by_profile_id;
      v_canonical_resolution_valid := request_record.status = 'rejected';
      v_notification_kind := 'participation_request_rejected';
      v_destination_kind := 'participation_request';
    end if;
  else
    select
      membership.id as membership_id,
      membership.project_id,
      membership.participant_profile_id,
      membership.removed_by_profile_id,
      membership.removed_at,
      project.creator_profile_id,
      project.project_kind
    into membership_record
    from public.project_memberships as membership
    join public.projects as project on project.id = membership.project_id
    where membership.id = v_membership_id;

    if not found
      or v_payload_project_id is distinct from membership_record.project_id
      or v_payload_participant_profile_id
        is distinct from membership_record.participant_profile_id
      or source_event.payload ->> 'project_kind'
        is distinct from membership_record.project_kind then
      raise exception using
        errcode = '55000',
        message = format(
          'Notification projection could not validate outbox event %s against its canonical membership.',
          source_event.id
        );
    end if;

    v_project_id := membership_record.project_id;

    if source_event.event_type = 'project.participant_left' then
      v_recipient_profile_id := membership_record.creator_profile_id;
      v_actor_profile_id := membership_record.participant_profile_id;
      v_notification_kind := 'participant_left';
      v_destination_kind := 'project_participation';
    else
      v_recipient_profile_id := membership_record.participant_profile_id;
      v_actor_profile_id := membership_record.removed_by_profile_id;
      v_canonical_resolution_valid := membership_record.removed_at is not null;
      v_notification_kind := 'participant_removed';
      v_destination_kind := 'project_detail';
    end if;
  end if;

  if v_actor_profile_id is null or not v_canonical_resolution_valid
    or v_payload_actor_profile_id is distinct from v_actor_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Notification projection found an invalid actor for outbox event %s.',
        source_event.id
      );
  end if;

  return query select
    'participation'::text,
    v_notification_kind,
    v_recipient_profile_id,
    v_actor_profile_id,
    v_project_id,
    case
      when source_event.payload ->> 'project_kind' in ('one_time', 'recurring')
        then source_event.payload ->> 'project_kind'
    end,
    v_request_id,
    v_membership_id,
    v_destination_kind,
    source_event.created_at;
end;
$$;
