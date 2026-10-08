-- Compose newly merged MSG01/MSG02 topics with 09C1B's existing recipient
-- boundary. No entitlement, stored unread state, message or notification policy
-- changes: only signals addressed after suspension are omitted.
create or replace function private.send_account_active_realtime(
  p_payload jsonb, p_event text, p_topic text, p_private boolean
)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare recipient_id uuid;
begin
  if not p_private or p_topic is null then
    raise exception using errcode = '22023', message = 'A canonical per-profile private topic is required.';
  end if;
  if p_topic ~ '^(project-chat|project-request-chat|resource-chat|participation-conversation):[0-9a-f-]{36}:profile:[0-9a-f-]{36}$' then
    recipient_id := split_part(p_topic, ':', 4)::uuid;
  elsif p_topic ~ '^message-unread:profile:[0-9a-f-]{36}$' then
    recipient_id := split_part(p_topic, ':', 3)::uuid;
  else
    raise exception using errcode = '22023', message = 'A canonical per-profile private topic is required.';
  end if;
  -- Keep the original lock order: no recipient profile lock under domain locks.
  -- Already queued pre-boundary hints cannot be recalled.
  if not private.profile_has_active_account_suspension(recipient_id) then
    perform realtime.send(p_payload, p_event, p_topic, true);
  end if;
end;
$$;

create or replace function private.signal_participation_conversation(p_chat_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
  -- Only immutable endpoints, never delegates. Suspension changes delivery,
  -- not the durable endpoint/history contract.
  for recipient in select c.lower_profile_id from public.participation_conversations c where c.id = p_chat_id
    union all select c.upper_profile_id from public.participation_conversations c where c.id = p_chat_id
  loop
    perform private.send_account_active_realtime(jsonb_build_object('chat_id', p_chat_id), 'participation.conversation_changed',
      private.participation_conversation_topic(p_chat_id, recipient), true);
  end loop;
end;
$$;

create or replace function private.signal_message_unread(p_profile uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform private.send_account_active_realtime(jsonb_build_object('profile_id',p_profile),'messages.unread_changed',
    'message-unread:profile:' || p_profile::text,true);
end;
$$;

-- Retain MSG01's recorded actor, exact-request message payload, endpoint-only
-- recipients and legacy URL contract. Replace only its delivery boundary.
create or replace function public.send_project_join_request_chat_message(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_body text
)
returns table (
  message_id uuid,
  chat_id uuid,
  sender_profile_id uuid,
  created_at timestamptz,
  body text
)
language plpgsql
security definer
set search_path = ''
as $$
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

  if not private.profile_can_access_project_join_request_chat(p_chat_id, current_profile_id) then
    raise exception using errcode = '42501', message = 'The participation-request chat is unavailable.';
  end if;
  perform private.lock_project_manager_interactions(request_project_id,
    (select r.requester_profile_id from public.project_join_requests r
     join public.project_join_request_chats c on c.request_id = r.id where c.id = p_chat_id));
  select * into project_record from private.lock_project_for_participation(request_project_id, false);

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
$$;
