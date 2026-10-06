-- Realtime caches connection authorization. Deny new joins and omit suspended
-- per-profile recipients from all canonical private broadcasters. Already queued
-- pre-boundary hints are not recalled; clients must close subscriptions too.
create policy account_active_required on realtime.messages
  as restrictive for select to authenticated
  using ((select private.current_account_is_active()));

create function private.send_account_active_realtime(
  p_payload jsonb, p_event text, p_topic text, p_private boolean
)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  recipient_id uuid;
begin
  if not p_private or p_topic is null or p_topic !~ '^(project-chat|project-request-chat|resource-chat):[0-9a-f-]{36}:profile:[0-9a-f-]{36}$' then
    raise exception using errcode = '22023', message = 'A canonical per-profile private topic is required.';
  end if;
  recipient_id := split_part(p_topic, ':', 4)::uuid;
  -- Do not acquire recipient profile locks under a Project/Resource domain lock:
  -- suspension withdrawal acquires those locks in the opposite direction.
  if not private.profile_has_active_account_suspension(recipient_id) then
    perform realtime.send(p_payload, p_event, p_topic, true);
  end if;
end;
$$;
revoke all on function private.send_account_active_realtime(jsonb,text,text,boolean)
  from public, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.record_project_requirement_coverage_event(p_event_type text, p_actor_profile_id uuid, p_project_id uuid, p_project_kind text, p_requirement_kind text, p_requirement_id uuid, p_membership_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  identifier_payload jsonb := jsonb_strip_nulls(jsonb_build_object(
    'project_id', p_project_id,
    'project_kind', p_project_kind,
    'requirement_kind', p_requirement_kind,
    'requirement_id', p_requirement_id,
    'actor_profile_id', p_actor_profile_id,
    'membership_id', p_membership_id
  ));
  canonical_created_at timestamptz;
  source_outbox_event_id uuid;
  resolved_chat_id uuid;
  system_event_id uuid;
  recipient_profile_id uuid;
  realtime_payload jsonb;
begin
  if p_event_type not in (
    'project.requirement_covered',
    'project.requirement_needed_again'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported Project requirement coverage event type.';
  end if;

  select chat.id
  into resolved_chat_id
  from public.project_group_chats as chat
  where chat.project_id = p_project_id;

  canonical_created_at := clock_timestamp();

  if resolved_chat_id is not null
    and p_event_type = 'project.requirement_needed_again' then
    select greatest(
      canonical_created_at,
      coalesce(
        max(event.created_at) + interval '1 microsecond',
        canonical_created_at
      )
    )
    into canonical_created_at
    from public.project_chat_system_events as event
    where event.chat_id = resolved_chat_id;
  end if;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    p_event_type,
    p_actor_profile_id,
    'project_requirement',
    p_requirement_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    p_event_type,
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  )
  returning id into source_outbox_event_id;

  if resolved_chat_id is null then
    return;
  end if;

  if p_event_type = 'project.requirement_needed_again' then
    insert into public.project_chat_system_events (
      chat_id,
      event_kind,
      requirement_kind,
      skill_id,
      resource_need_id,
      source_outbox_event_id,
      created_at
    )
    values (
      resolved_chat_id,
      'requirement_needed_again',
      p_requirement_kind,
      case when p_requirement_kind = 'skill' then p_requirement_id end,
      case when p_requirement_kind = 'resource' then p_requirement_id end,
      source_outbox_event_id,
      canonical_created_at
    )
    returning id into system_event_id;

    realtime_payload := jsonb_build_object(
      'chat_id', resolved_chat_id,
      'project_id', p_project_id,
      'system_event_id', system_event_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  else
    realtime_payload := jsonb_build_object(
      'chat_id', resolved_chat_id,
      'project_id', p_project_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  end if;

  for recipient_profile_id in
    select project.creator_profile_id
    from public.projects as project
    where project.id = p_project_id

    union

    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    where delegate.project_id = p_project_id
      and delegate.revoked_at is null

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.left_at is null
      and membership.removed_at is null
    order by 1
  loop
    perform private.send_account_active_realtime(
      realtime_payload,
      p_event_type,
      private.project_chat_realtime_topic(
        resolved_chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION private.record_resource_exchange_agreement_event(p_event_kind text, p_agreement_id uuid, p_terms_id uuid, p_leg_kind text, p_actor_profile_id uuid, p_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  agreement_event_id uuid;
  request_id uuid;
  listing_id uuid;
  owner_profile_id uuid;
  requester_profile_id uuid;
  resource_chat_id uuid;
  recipient_profile_id uuid;
  canonical_created_at timestamptz := coalesce(
    p_created_at,
    clock_timestamp()
  );
  external_event_type text;
  identifier_payload jsonb;
  realtime_payload jsonb;
begin
  if p_event_kind not in (
    'agreement_created',
    'terms_proposed',
    'terms_superseded',
    'terms_accepted',
    'terms_rejected',
    'terms_withdrawn',
    'resource_provided',
    'resource_received',
    'resource_returned',
    'resource_return_received',
    'agreement_cancelled',
    'agreement_completed'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported resource exchange agreement event.';
  end if;

  select
    request.id,
    request.listing_id,
    listing.owner_profile_id,
    request.requester_profile_id,
    chat.id
  into
    request_id,
    listing_id,
    owner_profile_id,
    requester_profile_id,
    resource_chat_id
  from public.resource_exchange_agreements as agreement
  join public.resource_listing_requests as request
    on request.id = agreement.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  left join public.resource_request_chats as chat
    on chat.request_id = request.id
  where agreement.id = p_agreement_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  insert into public.resource_exchange_agreement_events (
    agreement_id,
    terms_id,
    event_kind,
    leg_kind,
    actor_profile_id,
    created_at
  )
  values (
    p_agreement_id,
    p_terms_id,
    p_event_kind,
    p_leg_kind,
    p_actor_profile_id,
    canonical_created_at
  )
  returning id into agreement_event_id;

  external_event_type := case
    when p_event_kind in (
      'resource_provided',
      'resource_received',
      'resource_returned',
      'resource_return_received'
    ) then 'resource_exchange.milestone_recorded'
    else 'resource_exchange.' || p_event_kind
  end;

  identifier_payload := jsonb_strip_nulls(jsonb_build_object(
    'agreement_id', p_agreement_id,
    'request_id', request_id,
    'listing_id', listing_id,
    'owner_profile_id', owner_profile_id,
    'requester_profile_id', requester_profile_id,
    'terms_id', p_terms_id,
    'agreement_event_id', agreement_event_id,
    'actor_profile_id', p_actor_profile_id
  ));

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    external_event_type,
    p_actor_profile_id,
    'resource_exchange_agreement',
    p_agreement_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    external_event_type,
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  );

  if resource_chat_id is not null then
    realtime_payload := jsonb_strip_nulls(jsonb_build_object(
      'chat_id', resource_chat_id,
      'request_id', request_id,
      'agreement_id', p_agreement_id,
      'agreement_event_id', agreement_event_id,
      'terms_id', p_terms_id,
      'created_at', canonical_created_at
    ));

    for recipient_profile_id in
      select profile_id
      from (
        values (owner_profile_id), (requester_profile_id)
      ) as counterpart(profile_id)
      order by profile_id
    loop
      perform private.send_account_active_realtime(
        realtime_payload,
        'resource.exchange_changed',
        private.resource_request_chat_realtime_topic(
          resource_chat_id,
          recipient_profile_id
        ),
        true
      );
    end loop;
  end if;

  return agreement_event_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.send_resource_request_chat_message(p_expected_profile_id uuid, p_chat_id uuid, p_body text)
 RETURNS TABLE(message_id uuid, chat_id uuid, sender_profile_id uuid, created_at timestamp with time zone, body text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    true
  );
  chat_record public.resource_request_chats%rowtype;
  agreement_record public.resource_exchange_agreements%rowtype;
  request_record public.resource_listing_requests%rowtype;
  listing_record public.resource_listings%rowtype;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.resource_request_chat_messages%rowtype;
  identifier_payload jsonb;
  realtime_payload jsonb;
  recipient_profile_id uuid;
begin
  perform private.lock_profile_new_interactions(current_profile_id);
  perform private.assert_profile_account_active(current_profile_id);
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A resource request chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A resource request chat message cannot exceed 4,000 characters.';
  end if;

  select * into chat_record
  from public.resource_request_chats
  where id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The resource request chat is unavailable.';
  end if;

  -- Completion and cancellation lock this same row first. A waiter therefore
  -- observes their committed close before it evaluates send entitlement.
  select * into agreement_record
  from public.resource_exchange_agreements
  where request_id = chat_record.request_id
  for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The resource request chat is unavailable.';
  end if;

  select * into request_record
  from public.resource_listing_requests
  where id = agreement_record.request_id;

  select * into listing_record
  from public.resource_listings
  where id = request_record.listing_id;

  if current_profile_id not in (
    listing_record.owner_profile_id,
    request_record.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The resource request chat is unavailable.';
  end if;

  if request_record.status <> 'accepted'
    or request_record.coordination_closed_at is not null
    or agreement_record.lifecycle_state in ('completed', 'cancelled') then
    raise sqlstate 'PT409'
      using message = 'The resource request chat is read-only because coordination is closed.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.resource_request_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    chat_record.id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  identifier_payload := jsonb_build_object(
    'chat_id', chat_record.id,
    'request_id', request_record.id,
    'agreement_id', agreement_record.id,
    'listing_id', listing_record.id,
    'owner_profile_id', listing_record.owner_profile_id,
    'requester_profile_id', request_record.requester_profile_id,
    'message_id', inserted_message.id,
    'sender_profile_id', current_profile_id
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
    'resource_chat.message_sent',
    current_profile_id,
    'resource_request_chat',
    chat_record.id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    'resource_chat.message_sent',
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  );

  realtime_payload := jsonb_build_object(
    'chat_id', chat_record.id,
    'request_id', request_record.id,
    'message_id', inserted_message.id,
    'sender_profile_id', current_profile_id,
    'created_at', inserted_message.created_at
  );

  for recipient_profile_id in
    select profile_id
    from (
      values (
        listing_record.owner_profile_id
      ), (
        request_record.requester_profile_id
      )
    ) as counterpart(profile_id)
    order by profile_id
  loop
    perform private.send_account_active_realtime(
      realtime_payload,
      'resource.chat_message_sent',
      private.resource_request_chat_realtime_topic(
        chat_record.id,
        recipient_profile_id
      ),
      true
    );
  end loop;

  return query
  select
    inserted_message.id,
    inserted_message.chat_id,
    inserted_message.sender_profile_id,
    inserted_message.created_at,
    inserted_message.body;
end;
$function$;

CREATE OR REPLACE FUNCTION public.send_project_join_request_chat_message(p_expected_profile_id uuid, p_chat_id uuid, p_body text)
 RETURNS TABLE(message_id uuid, chat_id uuid, sender_profile_id uuid, created_at timestamp with time zone, body text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  request_project_id uuid;
  request_record public.project_join_requests%rowtype;
  project_record record;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.project_join_request_chat_messages%rowtype;
  identifier_payload jsonb;
  realtime_payload jsonb;
  recipient_profile_id uuid;
begin
  perform private.lock_profile_new_interactions(current_profile_id);
  perform private.assert_profile_account_active(current_profile_id);
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A participation-request chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A participation-request chat message cannot exceed 4,000 characters.';
  end if;

  select request.project_id into request_project_id
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(request_project_id, false);

  select request.* into request_record
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id
  for update of request;

  if not found or (
    request_record.requester_profile_id <> current_profile_id
    and not private.profile_is_project_manager(
      request_record.project_id,
      current_profile_id
    )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  if request_record.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The participation-request chat is read-only because the request is resolved.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.project_join_request_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    p_chat_id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  identifier_payload := jsonb_build_object(
    'chat_id', p_chat_id,
    'request_id', request_record.id,
    'project_id', request_record.project_id,
    'project_kind', project_record.project_kind,
    'message_id', inserted_message.id,
    'sender_profile_id', current_profile_id
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
    'project.join_request_chat_message_sent',
    current_profile_id,
    'project_join_request_chat',
    p_chat_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    'project.join_request_chat_message_sent',
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  );

  realtime_payload := jsonb_build_object(
    'chat_id', p_chat_id,
    'request_id', request_record.id,
    'message_id', inserted_message.id,
    'created_at', inserted_message.created_at
  );

  for recipient_profile_id in
    select request_record.requester_profile_id

    union

    select project_record.creator_profile_id

    union

    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    where delegate.project_id = request_record.project_id
      and delegate.revoked_at is null
    order by 1
  loop
    perform private.send_account_active_realtime(
      realtime_payload,
      'project.join_request_chat_message_sent',
      private.project_join_request_chat_realtime_topic(
        p_chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;

  return query
  select
    inserted_message.id,
    inserted_message.chat_id,
    inserted_message.sender_profile_id,
    inserted_message.created_at,
    inserted_message.body;
end;
$function$;

CREATE OR REPLACE FUNCTION public.send_project_chat_message(p_expected_profile_id uuid, p_chat_id uuid, p_body text)
 RETURNS TABLE(message_id uuid, chat_id uuid, sender_profile_id uuid, created_at timestamp with time zone, body text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := private.require_complete_project_chat_profile(
    p_expected_profile_id
  );
  chat_record record;
  project_record record;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.project_chat_messages%rowtype;
  recipient_profile_id uuid;
begin
  perform private.lock_profile_new_interactions(current_profile_id);
  perform private.assert_profile_account_active(current_profile_id);
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A Project chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A Project chat message cannot exceed 4,000 characters.';
  end if;

  select chat.id, chat.project_id
  into chat_record
  from public.project_group_chats as chat
  where chat.id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable for sending.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(chat_record.project_id, false);

  if not private.profile_has_current_project_chat_entitlement(
    chat_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable for sending.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.project_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    chat_record.id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  insert into private.outbox_events (event_type, payload)
  values (
    'project.chat_message_sent',
    jsonb_build_object(
      'chat_id', chat_record.id,
      'project_id', chat_record.project_id,
      'project_kind', project_record.project_kind,
      'message_id', inserted_message.id,
      'sender_profile_id', current_profile_id
    )
  );

  -- Existing connections cache topic authorization. Addressing only current
  -- managers/members makes revocation effective for subsequent durable sends.
  for recipient_profile_id in
    select project.creator_profile_id
    from public.projects as project
    where project.id = chat_record.project_id

    union

    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    where delegate.project_id = chat_record.project_id
      and delegate.revoked_at is null

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = chat_record.project_id
      and membership.left_at is null
      and membership.removed_at is null
    order by 1
  loop
    perform private.send_account_active_realtime(
      jsonb_build_object(
        'chat_id', chat_record.id,
        'message_id', inserted_message.id,
        'created_at', inserted_message.created_at
      ),
      'project.chat_message_sent',
      private.project_chat_realtime_topic(
        chat_record.id,
        recipient_profile_id
      ),
      true
    );
  end loop;

  return query
  select
    inserted_message.id,
    inserted_message.chat_id,
    inserted_message.sender_profile_id,
    inserted_message.created_at,
    inserted_message.body;
end;
$function$;
