create table public.resource_request_chats (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null
    constraint resource_request_chats_request_id_fkey
      references public.resource_listing_requests (id) on delete restrict,
  activated_at timestamptz not null,
  constraint resource_request_chats_request_id_key unique (request_id)
);

comment on table public.resource_request_chats is
  'Private two-counterparty conversation anchor for one accepted resource-listing request episode.';
comment on column public.resource_request_chats.activated_at is
  'Canonical request-acceptance time; agreement completion, cancellation, or listing closure never deletes the chat anchor.';

alter table public.resource_request_chats enable row level security;
revoke all privileges on table public.resource_request_chats
  from public, anon, authenticated, service_role;

create function private.validate_resource_request_chat_anchor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_record public.resource_listing_requests%rowtype;
begin
  select * into request_record
  from public.resource_listing_requests
  where id = new.request_id;

  if not found or request_record.status <> 'accepted' then
    raise exception using
      errcode = '55000',
      message = 'A resource request chat requires an accepted request.';
  end if;

  if new.activated_at < coalesce(
    request_record.resolved_at,
    request_record.created_at
  ) then
    raise exception using
      errcode = '22023',
      message = 'Resource request chat activation cannot predate request acceptance.';
  end if;

  return new;
end;
$$;

create trigger resource_request_chats_validate_anchor
before insert or update on public.resource_request_chats
for each row execute function private.validate_resource_request_chat_anchor();

create function private.ensure_resource_request_chat_for_request(
  p_request_id uuid,
  p_activated_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_record public.resource_listing_requests%rowtype;
  resource_chat_id uuid;
  canonical_activated_at timestamptz;
begin
  select * into request_record
  from public.resource_listing_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  if request_record.status <> 'accepted' then
    raise exception using
      errcode = '55000',
      message = 'Only an accepted resource listing request can own a chat.';
  end if;

  canonical_activated_at := coalesce(
    p_activated_at,
    request_record.resolved_at,
    statement_timestamp()
  );

  insert into public.resource_request_chats (
    request_id,
    activated_at
  )
  values (
    request_record.id,
    canonical_activated_at
  )
  on conflict (request_id) do nothing
  returning id into resource_chat_id;

  if resource_chat_id is null then
    select chat.id into resource_chat_id
    from public.resource_request_chats as chat
    where chat.request_id = request_record.id;
  end if;

  return resource_chat_id;
end;
$$;

do $$
declare
  accepted_request record;
begin
  for accepted_request in
    select
      request.id,
      coalesce(request.resolved_at, request.created_at) as activated_at
    from public.resource_listing_requests as request
    where request.status = 'accepted'
    order by request.id
  loop
    perform private.ensure_resource_request_chat_for_request(
      accepted_request.id,
      accepted_request.activated_at
    );
  end loop;
end;
$$;

create table public.resource_request_chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null
    constraint resource_request_chat_messages_chat_id_fkey
      references public.resource_request_chats (id) on delete restrict,
  sender_profile_id uuid not null
    constraint resource_request_chat_messages_sender_profile_id_fkey
      references public.profiles (id) on delete restrict,
  body text not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint resource_request_chat_messages_body_canonical check (
    body = regexp_replace(
      body,
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    )
    and char_length(body) between 1 and 4000
  )
);

comment on table public.resource_request_chat_messages is
  'Immutable human-authored plain-text messages for one accepted resource-request conversation; agreement events remain in their structured timeline.';
comment on column public.resource_request_chat_messages.body is
  'Canonical plain text trimmed of surrounding whitespace and bounded to 4,000 Unicode characters.';
comment on column public.resource_request_chat_messages.created_at is
  'Server-owned creation time assigned after the agreement serialization lock is acquired.';

create index resource_request_chat_messages_chat_created_idx
  on public.resource_request_chat_messages (
    chat_id,
    created_at desc,
    id desc
  );
create index resource_request_chat_messages_sender_created_idx
  on public.resource_request_chat_messages (
    sender_profile_id,
    created_at desc,
    id desc
  );

alter table public.resource_request_chat_messages enable row level security;
revoke all privileges on table public.resource_request_chat_messages
  from public, anon, authenticated, service_role;

create function private.protect_resource_request_chat_message_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Resource request chat messages are immutable.';
end;
$$;

create trigger resource_request_chat_messages_immutable
before update or delete on public.resource_request_chat_messages
for each row execute function
  private.protect_resource_request_chat_message_immutability();

create function private.resource_request_chat_realtime_topic(
  p_chat_id uuid,
  p_profile_id uuid
)
returns text
language sql
immutable
security definer
set search_path = ''
as $$
  select format(
    'resource-chat:%s:profile:%s',
    p_chat_id::text,
    p_profile_id::text
  );
$$;

create function private.profile_can_receive_resource_request_chat_topic(
  p_topic text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  topic_chat_id uuid;
  topic_profile_id uuid;
begin
  if current_profile_id is null or p_topic is null then
    return false;
  end if;

  begin
    topic_chat_id := split_part(p_topic, ':', 2)::uuid;
    topic_profile_id := split_part(p_topic, ':', 4)::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  if p_topic <> private.resource_request_chat_realtime_topic(
    topic_chat_id,
    topic_profile_id
  ) or topic_profile_id <> current_profile_id then
    return false;
  end if;

  return exists (
    select 1
    from public.resource_request_chats as chat
    join public.resource_listing_requests as request
      on request.id = chat.request_id
    join public.resource_listings as listing
      on listing.id = request.listing_id
    where chat.id = topic_chat_id
      and current_profile_id in (
        listing.owner_profile_id,
        request.requester_profile_id
      )
  );
end;
$$;

create policy resource_request_chat_counterparties_receive_broadcasts
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and private.profile_can_receive_resource_request_chat_topic(
    (select realtime.topic())
  )
);

create or replace function private.record_resource_exchange_agreement_event(
  p_event_kind text,
  p_agreement_id uuid,
  p_terms_id uuid,
  p_leg_kind text,
  p_actor_profile_id uuid,
  p_created_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
      perform realtime.send(
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
$$;

create or replace function public.accept_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
  request_listing_id uuid;
  listing public.resource_listings%rowtype;
  request public.resource_listing_requests%rowtype;
  transition_time timestamptz := statement_timestamp();
begin
  select candidate.listing_id into request_listing_id
  from public.resource_listing_requests as candidate
  where candidate.id = p_request_id;

  if request_listing_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  select * into listing
  from public.resource_listings
  where id = request_listing_id
  for update;

  select * into request
  from public.resource_listing_requests
  where id = p_request_id
  for update;

  if listing.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the listing owner can accept this resource listing request.';
  end if;

  if request.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The resource listing request is no longer pending.';
  end if;

  update public.resource_listing_requests
  set
    status = 'accepted',
    resolved_at = transition_time,
    resolved_by_profile_id = current_profile_id
  where id = p_request_id;

  perform private.record_resource_listing_request_event(
    'resource_listing.request_accepted',
    request.id,
    listing.id,
    listing.owner_profile_id,
    request.requester_profile_id,
    current_profile_id
  );

  perform private.ensure_resource_request_chat_for_request(
    p_request_id,
    transition_time
  );

  perform private.ensure_resource_exchange_agreement_for_request(
    p_request_id,
    current_profile_id,
    transition_time
  );

  return p_request_id;
end;
$$;

create function public.send_resource_request_chat_message(
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
    perform realtime.send(
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
$$;

create function public.list_own_resource_request_chat_messages(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_limit integer,
  p_before_created_at timestamptz default null,
  p_before_message_id uuid default null
)
returns table (
  message_id uuid,
  chat_id uuid,
  sender_profile_id uuid,
  sender_display_name text,
  body text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The resource request chat message page size must be between 1 and 50.';
  end if;

  if (p_before_created_at is null) <> (p_before_message_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both resource request chat message cursor values must be provided together.';
  end if;

  if not exists (
    select 1
    from public.resource_request_chats as chat
    join public.resource_listing_requests as request
      on request.id = chat.request_id
    join public.resource_listings as listing
      on listing.id = request.listing_id
    where chat.id = p_chat_id
      and current_profile_id in (
        listing.owner_profile_id,
        request.requester_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The resource request chat is unavailable.';
  end if;

  return query
  select
    message.id,
    message.chat_id,
    message.sender_profile_id,
    sender.display_name,
    message.body,
    message.created_at
  from public.resource_request_chat_messages as message
  join public.profiles as sender on sender.id = message.sender_profile_id
  where message.chat_id = p_chat_id
    and (
      p_before_created_at is null
      or (message.created_at, message.id)
        < (p_before_created_at, p_before_message_id)
    )
  order by message.created_at desc, message.id desc
  limit p_limit;
end;
$$;

create function public.get_own_resource_request_chat(
  p_expected_profile_id uuid,
  p_chat_id uuid
)
returns table (
  chat_id uuid,
  request_id uuid,
  agreement_id uuid,
  listing_id uuid,
  listing_title text,
  viewer_role text,
  owner_profile_id uuid,
  owner_display_name text,
  requester_profile_id uuid,
  requester_display_name text,
  agreement_lifecycle text,
  coordination_closed_at timestamptz,
  has_send_entitlement boolean,
  activated_at timestamptz,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  activity_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
begin
  if not exists (
    select 1
    from public.resource_request_chats as chat
    join public.resource_listing_requests as request
      on request.id = chat.request_id
    join public.resource_listings as listing
      on listing.id = request.listing_id
    where chat.id = p_chat_id
      and current_profile_id in (
        listing.owner_profile_id,
        request.requester_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The resource request chat is unavailable.';
  end if;

  return query
  select
    chat.id,
    request.id,
    agreement.id,
    listing.id,
    listing.title,
    case
      when current_profile_id = listing.owner_profile_id then 'owner'
      else 'requester'
    end,
    listing.owner_profile_id,
    owner.display_name,
    request.requester_profile_id,
    requester.display_name,
    agreement.lifecycle_state,
    request.coordination_closed_at,
    request.status = 'accepted'
      and request.coordination_closed_at is null
      and agreement.lifecycle_state not in ('completed', 'cancelled'),
    chat.activated_at,
    latest_message.id,
    latest_message.body,
    latest_message.created_at,
    latest_message.sender_profile_id,
    latest_message.sender_display_name,
    greatest(
      chat.activated_at,
      coalesce(latest_message.created_at, chat.activated_at),
      coalesce(latest_event.created_at, chat.activated_at)
    )
  from public.resource_request_chats as chat
  join public.resource_listing_requests as request
    on request.id = chat.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  join public.resource_exchange_agreements as agreement
    on agreement.request_id = request.id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  left join lateral (
    select
      message.id,
      message.body,
      message.created_at,
      message.sender_profile_id,
      sender.display_name as sender_display_name
    from public.resource_request_chat_messages as message
    join public.profiles as sender on sender.id = message.sender_profile_id
    where message.chat_id = chat.id
    order by message.created_at desc, message.id desc
    limit 1
  ) as latest_message on true
  left join lateral (
    select event.created_at
    from public.resource_exchange_agreement_events as event
    where event.agreement_id = agreement.id
    order by event.created_at desc, event.id desc
    limit 1
  ) as latest_event on true
  where chat.id = p_chat_id;
end;
$$;

create function public.list_own_resource_request_chats(
  p_expected_profile_id uuid,
  p_limit integer,
  p_before_activity_at timestamptz default null,
  p_before_chat_id uuid default null
)
returns table (
  chat_id uuid,
  request_id uuid,
  agreement_id uuid,
  listing_id uuid,
  listing_title text,
  viewer_role text,
  owner_profile_id uuid,
  owner_display_name text,
  requester_profile_id uuid,
  requester_display_name text,
  agreement_lifecycle text,
  coordination_closed_at timestamptz,
  has_send_entitlement boolean,
  activated_at timestamptz,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  activity_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The resource request chat list page size must be between 1 and 50.';
  end if;

  if (p_before_activity_at is null) <> (p_before_chat_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both resource request chat-list cursor values must be provided together.';
  end if;

  return query
  with visible_chats as (
    select
      chat.id as chat_id,
      request.id as request_id,
      agreement.id as agreement_id,
      listing.id as listing_id,
      listing.title as listing_title,
      case
        when current_profile_id = listing.owner_profile_id then 'owner'
        else 'requester'
      end as viewer_role,
      listing.owner_profile_id,
      owner.display_name as owner_display_name,
      request.requester_profile_id,
      requester.display_name as requester_display_name,
      agreement.lifecycle_state as agreement_lifecycle,
      request.coordination_closed_at,
      request.status = 'accepted'
        and request.coordination_closed_at is null
        and agreement.lifecycle_state not in (
          'completed',
          'cancelled'
        ) as has_send_entitlement,
      chat.activated_at,
      latest_message.id as last_visible_message_id,
      latest_message.body as last_visible_message_body,
      latest_message.created_at as last_visible_message_at,
      latest_message.sender_profile_id
        as last_visible_sender_profile_id,
      latest_message.sender_display_name
        as last_visible_sender_display_name,
      greatest(
        chat.activated_at,
        coalesce(latest_message.created_at, chat.activated_at),
        coalesce(latest_event.created_at, chat.activated_at)
      ) as activity_at
    from public.resource_request_chats as chat
    join public.resource_listing_requests as request
      on request.id = chat.request_id
    join public.resource_listings as listing
      on listing.id = request.listing_id
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = request.id
    join public.profiles as owner on owner.id = listing.owner_profile_id
    join public.profiles as requester
      on requester.id = request.requester_profile_id
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.resource_request_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = chat.id
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select event.created_at
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
      order by event.created_at desc, event.id desc
      limit 1
    ) as latest_event on true
    where current_profile_id in (
      listing.owner_profile_id,
      request.requester_profile_id
    )
  )
  select
    visible.chat_id,
    visible.request_id,
    visible.agreement_id,
    visible.listing_id,
    visible.listing_title,
    visible.viewer_role,
    visible.owner_profile_id,
    visible.owner_display_name,
    visible.requester_profile_id,
    visible.requester_display_name,
    visible.agreement_lifecycle,
    visible.coordination_closed_at,
    visible.has_send_entitlement,
    visible.activated_at,
    visible.last_visible_message_id,
    visible.last_visible_message_body,
    visible.last_visible_message_at,
    visible.last_visible_sender_profile_id,
    visible.last_visible_sender_display_name,
    visible.activity_at
  from visible_chats as visible
  where p_before_activity_at is null
    or (visible.activity_at, visible.chat_id)
      < (p_before_activity_at, p_before_chat_id)
  order by visible.activity_at desc, visible.chat_id desc
  limit p_limit;
end;
$$;

comment on function private.ensure_resource_request_chat_for_request(uuid, timestamptz) is
  'Idempotently creates the single chat anchor for an accepted resource-request episode using its acceptance timestamp.';
comment on function private.resource_request_chat_realtime_topic(uuid, uuid) is
  'Builds the canonical private resource-chat topic for one exact counterparty profile.';
comment on function private.profile_can_receive_resource_request_chat_topic(text) is
  'Strictly parses a private resource-chat topic and permanently authorizes only its canonical request counterparties.';
comment on function private.record_resource_exchange_agreement_event(text, uuid, uuid, text, uuid, timestamptz) is
  'Records identifier-only agreement history/audit/outbox state and sends a private counterparty refresh hint when a resource chat exists.';
comment on function public.accept_resource_listing_request(uuid, uuid) is
  'Atomically accepts one pending listing request and creates exactly one resource chat plus one resource exchange agreement.';
comment on function public.send_resource_request_chat_message(uuid, uuid, text) is
  'Serializes on the agreement row, persists one canonical human message while coordination is open, and emits identifier-only durable and Realtime events.';
comment on function public.list_own_resource_request_chat_messages(uuid, uuid, integer, timestamptz, uuid) is
  'Returns permanent counterparty-authorized human resource-chat history using a complete newest-first keyset cursor.';
comment on function public.get_own_resource_request_chat(uuid, uuid) is
  'Returns one counterparty-only resource-chat summary with honest human preview, agreement-derived activity, and current send entitlement.';
comment on function public.list_own_resource_request_chats(uuid, integer, timestamptz, uuid) is
  'Returns counterparty resource chats ordered by activation, latest human message, or latest structured agreement activity.';

revoke all privileges on function private.validate_resource_request_chat_anchor()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.ensure_resource_request_chat_for_request(uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.protect_resource_request_chat_message_immutability()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resource_request_chat_realtime_topic(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_can_receive_resource_request_chat_topic(text)
  from public, anon, authenticated, service_role;

grant execute on function private.profile_can_receive_resource_request_chat_topic(text)
  to authenticated;

revoke all privileges on function public.send_resource_request_chat_message(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_resource_request_chat_messages(uuid, uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_resource_request_chat(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_resource_request_chats(uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.send_resource_request_chat_message(uuid, uuid, text)
  to authenticated;
grant execute on function public.list_own_resource_request_chat_messages(uuid, uuid, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_own_resource_request_chat(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_resource_request_chats(uuid, integer, timestamptz, uuid)
  to authenticated;
