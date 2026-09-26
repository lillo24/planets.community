alter table public.notifications
  drop constraint notifications_kind_valid,
  drop constraint notifications_destination_kind_valid,
  drop constraint notifications_category_matches_kind,
  drop constraint notifications_destination_matches_kind,
  drop constraint notifications_reference_shape_valid;

alter table public.notifications
  add constraint notifications_kind_valid check (
    notification_kind in (
      'participation_request_received',
      'participation_request_withdrawn',
      'participation_request_accepted',
      'participation_request_rejected',
      'participant_left',
      'participant_removed',
      'chat_message_received',
      'resource_request_received',
      'resource_request_withdrawn',
      'resource_request_accepted',
      'resource_request_rejected',
      'resource_request_listing_closed',
      'resource_chat_message_received',
      'resource_exchange_terms_proposed',
      'resource_exchange_terms_accepted',
      'resource_exchange_terms_rejected',
      'resource_exchange_terms_withdrawn',
      'resource_exchange_milestone_recorded',
      'resource_exchange_cancelled',
      'resource_exchange_completed',
      'matching_available'
    )
  ),
  add constraint notifications_destination_kind_valid check (
    destination_kind in (
      'participation_request',
      'project_participation',
      'project_detail',
      'project_chat',
      'resource_request',
      'resource_chat',
      'matching_result'
    )
  ),
  add constraint notifications_category_matches_kind check (
    (
      category_slug = 'participation'
      and notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected',
        'participant_left',
        'participant_removed'
      )
    )
    or (
      category_slug = 'chat'
      and notification_kind = 'chat_message_received'
    )
    or (
      category_slug = 'resources'
      and notification_kind like 'resource_%'
    )
    or (
      category_slug = 'matching'
      and notification_kind = 'matching_available'
    )
  ),
  add constraint notifications_destination_matches_kind check (
    (
      notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected'
      )
      and destination_kind = 'participation_request'
    )
    or (
      notification_kind = 'participant_left'
      and destination_kind = 'project_participation'
    )
    or (
      notification_kind = 'participant_removed'
      and destination_kind = 'project_detail'
    )
    or (
      notification_kind = 'chat_message_received'
      and destination_kind = 'project_chat'
    )
    or (
      notification_kind in (
        'resource_request_received',
        'resource_request_withdrawn',
        'resource_request_rejected',
        'resource_request_listing_closed'
      )
      and destination_kind = 'resource_request'
    )
    or (
      notification_kind in (
        'resource_request_accepted',
        'resource_chat_message_received',
        'resource_exchange_terms_proposed',
        'resource_exchange_terms_accepted',
        'resource_exchange_terms_rejected',
        'resource_exchange_terms_withdrawn',
        'resource_exchange_milestone_recorded',
        'resource_exchange_cancelled',
        'resource_exchange_completed'
      )
      and destination_kind = 'resource_chat'
    )
    or (
      notification_kind = 'matching_available'
      and destination_kind = 'matching_result'
    )
  ),
  add constraint notifications_reference_shape_valid check (
    (
      resource_listing_id is null
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
      and project_id is not null
      and (
        (
          notification_kind in (
            'participation_request_received',
            'participation_request_withdrawn',
            'participation_request_rejected'
          )
          and request_id is not null
          and membership_id is null
          and chat_id is null
          and message_id is null
        )
        or (
          notification_kind = 'participation_request_accepted'
          and request_id is not null
          and membership_id is not null
          and chat_id is null
          and message_id is null
        )
        or (
          notification_kind in ('participant_left', 'participant_removed')
          and request_id is null
          and membership_id is not null
          and chat_id is null
          and message_id is null
        )
        or (
          notification_kind = 'chat_message_received'
          and actor_profile_id is not null
          and request_id is null
          and membership_id is null
          and chat_id is not null
          and message_id is not null
        )
      )
    )
    or (
      category_slug = 'resources'
      and project_id is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and actor_profile_id is not null
      and resource_listing_id is not null
      and resource_request_id is not null
      and (
        (
          notification_kind in (
            'resource_request_received',
            'resource_request_withdrawn',
            'resource_request_rejected',
            'resource_request_listing_closed'
          )
          and resource_chat_id is null
          and resource_chat_message_id is null
          and resource_agreement_id is null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_request_accepted'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_chat_message_received'
          and resource_chat_id is not null
          and resource_chat_message_id is not null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind like 'resource_exchange_%'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is not null
        )
      )
    )
    or (
      category_slug = 'matching'
      and notification_kind = 'matching_available'
      and destination_kind = 'matching_result'
      and actor_profile_id is null
      and project_id is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and resource_listing_id is not null
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
    )
  );

create unique index notifications_matching_recipient_listing_unique
  on public.notifications (
    recipient_profile_id,
    resource_listing_id,
    notification_kind
  )
  where category_slug = 'matching'
    and notification_kind = 'matching_available';

alter table private.push_delivery_jobs
  drop constraint push_delivery_jobs_resource_shape_valid;

alter table private.push_delivery_jobs
  add constraint push_delivery_jobs_resource_shape_valid check (
    (
      category_slug not in ('resources', 'matching')
      and resource_listing_id is null
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
    )
    or (
      category_slug = 'resources'
      and project_id is null
      and project_kind is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and actor_profile_id is not null
      and resource_listing_id is not null
      and resource_request_id is not null
      and (
        (
          notification_kind in (
            'resource_request_received',
            'resource_request_withdrawn',
            'resource_request_rejected',
            'resource_request_listing_closed'
          )
          and destination_kind = 'resource_request'
          and resource_chat_id is null
          and resource_chat_message_id is null
          and resource_agreement_id is null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_request_accepted'
          and destination_kind = 'resource_chat'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_chat_message_received'
          and destination_kind = 'resource_chat'
          and resource_chat_id is not null
          and resource_chat_message_id is not null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind in (
            'resource_exchange_terms_proposed',
            'resource_exchange_terms_accepted',
            'resource_exchange_terms_rejected',
            'resource_exchange_terms_withdrawn',
            'resource_exchange_milestone_recorded',
            'resource_exchange_cancelled',
            'resource_exchange_completed'
          )
          and destination_kind = 'resource_chat'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is not null
        )
      )
    )
    or (
      category_slug = 'matching'
      and notification_kind = 'matching_available'
      and destination_kind = 'matching_result'
      and actor_profile_id is null
      and project_id is null
      and project_kind is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and resource_listing_id is not null
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
    )
  );

create unique index push_delivery_jobs_matching_recipient_listing_unique
  on private.push_delivery_jobs (
    recipient_profile_id,
    resource_listing_id,
    notification_kind
  )
  where category_slug = 'matching'
    and notification_kind = 'matching_available';

create function private.resolve_saved_search_matching_notification_event(
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
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
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
  match_fact private.resource_saved_search_listing_matches%rowtype;
  saved_search public.resource_saved_searches%rowtype;
  listing public.resource_listings%rowtype;
  payload_match_id uuid;
  payload_saved_search_id uuid;
  payload_recipient_profile_id uuid;
  payload_listing_id uuid;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type = 'resource_saved_search.matched';

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> 4
    or not source_event.payload ?& array[
      'saved_search_match_id',
      'saved_search_id',
      'recipient_profile_id',
      'listing_id'
    ] then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    payload_match_id :=
      (source_event.payload ->> 'saved_search_match_id')::uuid;
    payload_saved_search_id :=
      (source_event.payload ->> 'saved_search_id')::uuid;
    payload_recipient_profile_id :=
      (source_event.payload ->> 'recipient_profile_id')::uuid;
    payload_listing_id := (source_event.payload ->> 'listing_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  if payload_match_id is null
    or payload_saved_search_id is null
    or payload_recipient_profile_id is null
    or payload_listing_id is null then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has invalid identifiers.',
        source_event.id
      );
  end if;

  select fact.* into match_fact
  from private.resource_saved_search_listing_matches as fact
  where fact.id = payload_match_id;

  if not found then
    if exists (
      select 1
      from public.resource_saved_searches as current_search
      where current_search.id = payload_saved_search_id
    ) then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching notification event %s references no canonical match fact for its current saved search.',
          source_event.id
        );
    end if;

    return;
  end if;

  if payload_saved_search_id is distinct from match_fact.saved_search_id
    or payload_recipient_profile_id
      is distinct from match_fact.recipient_profile_id
    or payload_listing_id is distinct from match_fact.listing_id
    or source_event.created_at is distinct from match_fact.matched_at then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s diverges from its canonical match fact.',
        source_event.id
      );
  end if;

  select current_search.* into saved_search
  from public.resource_saved_searches as current_search
  where current_search.id = match_fact.saved_search_id;

  select current_listing.* into listing
  from public.resource_listings as current_listing
  where current_listing.id = match_fact.listing_id;

  if saved_search.id is null
    or listing.id is null
    or saved_search.profile_id
      is distinct from match_fact.recipient_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has inconsistent canonical context.',
        source_event.id
      );
  end if;

  if saved_search.profile_id = listing.owner_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s violates self-owner suppression.',
        source_event.id
      );
  end if;

  if saved_search.updated_at is distinct from match_fact.saved_search_updated_at
    or listing.lifecycle_state <> 'published'
    or not private.resource_listing_matches_saved_search_filters(
      listing.listing_mode,
      listing.title,
      listing.description,
      listing.locality,
      saved_search.listing_mode,
      saved_search.query,
      saved_search.locality
    ) then
    return;
  end if;

  return query
  select
    'matching'::text,
    'matching_available'::text,
    match_fact.recipient_profile_id,
    null::uuid,
    null::uuid,
    null::text,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    match_fact.listing_id,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    'matching_result'::text,
    source_event.created_at;
end;
$$;

revoke all privileges on function
  private.resolve_saved_search_matching_notification_event(uuid)
  from public, anon, authenticated, service_role;

comment on function
  private.resolve_saved_search_matching_notification_event(uuid) is
  'Validates an identifier-only saved-search match against its private fact and current search/listing state, returning only safe matching semantics or a fail-closed suppression.';

create or replace function private.resolve_notification_event(
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
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  resolved_event_type text;
begin
  select event.event_type into resolved_event_type
  from private.outbox_events as event
  where event.id = p_outbox_event_id;

  if not found then
    raise exception using
      errcode = '55000',
      message = format('Notification event %s is unavailable.', p_outbox_event_id);
  end if;

  if resolved_event_type = 'project.chat_message_sent' then
    return query
    select
      resolved.category_slug,
      resolved.notification_kind,
      resolved.recipient_profile_id,
      resolved.actor_profile_id,
      resolved.project_id,
      resolved.project_kind,
      resolved.request_id,
      resolved.membership_id,
      resolved.chat_id,
      resolved.message_id,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      resolved.destination_kind,
      resolved.source_created_at
    from private.resolve_chat_message_notification_event(
      p_outbox_event_id
    ) as resolved;
    return;
  end if;

  if resolved_event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed'
  ) then
    return query
    select
      resolved.category_slug,
      resolved.notification_kind,
      resolved.recipient_profile_id,
      resolved.actor_profile_id,
      resolved.project_id,
      resolved.project_kind,
      resolved.request_id,
      resolved.membership_id,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      resolved.destination_kind,
      resolved.source_created_at
    from private.resolve_participation_notification_event(
      p_outbox_event_id
    ) as resolved;
    return;
  end if;

  if resolved_event_type like 'resource_listing.request_%' then
    return query
    select *
    from private.resolve_resource_request_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  if resolved_event_type = 'resource_chat.message_sent' then
    return query
    select *
    from private.resolve_resource_chat_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  if resolved_event_type in (
    'resource_exchange.terms_proposed',
    'resource_exchange.terms_accepted',
    'resource_exchange.terms_rejected',
    'resource_exchange.terms_withdrawn',
    'resource_exchange.milestone_recorded',
    'resource_exchange.agreement_cancelled',
    'resource_exchange.agreement_completed'
  ) then
    return query
    select *
    from private.resolve_resource_exchange_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  if resolved_event_type = 'resource_saved_search.matched' then
    return query
    select *
    from private.resolve_saved_search_matching_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  raise exception using
    errcode = '55000',
    message = format('Notification event %s is unsupported.', p_outbox_event_id);
end;
$$;

revoke all privileges on function private.resolve_notification_event(uuid)
  from public, anon, authenticated, service_role;

comment on function private.resolve_notification_event(uuid) is
  'Normalizes supported Project, Resource, and saved-search-match outbox sources into provider-neutral, recipient-level semantic alerts.';

-- Match events that predate immediate delivery are deliberately acknowledged
-- without creating retrospective in-app notifications or push jobs.
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
select
  event.id,
  consumer.consumer_key,
  statement_timestamp()
from private.outbox_events as event
cross join (
  values ('notifications.v1'::text), ('push.v1'::text)
) as consumer(consumer_key)
where event.event_type = 'resource_saved_search.matched'
on conflict do nothing;

drop index private.outbox_events_notification_sources_available_idx;
create index outbox_events_notification_sources_available_idx
  on private.outbox_events (available_at, created_at, id)
  where event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed',
    'project.chat_message_sent',
    'resource_listing.request_created',
    'resource_listing.request_withdrawn',
    'resource_listing.request_accepted',
    'resource_listing.request_rejected',
    'resource_listing.request_closed',
    'resource_chat.message_sent',
    'resource_exchange.terms_proposed',
    'resource_exchange.terms_accepted',
    'resource_exchange.terms_rejected',
    'resource_exchange.terms_withdrawn',
    'resource_exchange.milestone_recorded',
    'resource_exchange.agreement_cancelled',
    'resource_exchange.agreement_completed',
    'resource_saved_search.matched'
  );

create or replace function public.process_notification_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  notifications_created integer,
  notifications_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  in_app_enabled boolean;
  resolved_processed_count integer := 0;
  resolved_notifications_created integer := 0;
  resolved_notifications_suppressed integer := 0;
  inserted_count integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed',
      'project.chat_message_sent',
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed',
      'resource_chat.message_sent',
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed',
      'resource_saved_search.matched'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'notifications.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
      select coalesce(
        preference.in_app_enabled,
        category.default_in_app_enabled
      )
      into in_app_enabled
      from public.notification_categories as category
      left join public.profile_notification_preferences as preference
        on preference.profile_id = resolved_event.recipient_profile_id
        and preference.category_slug = category.slug
      where category.slug = resolved_event.category_slug;

      if in_app_enabled is null then
        raise exception using
          errcode = '55000',
          message = 'The resolved notification category is unavailable.';
      end if;

      if in_app_enabled then
        if resolved_event.category_slug = 'matching'
          and resolved_event.notification_kind = 'matching_available' then
          insert into public.notifications (
            recipient_profile_id,
            category_slug,
            notification_kind,
            source_outbox_event_id,
            project_id,
            actor_profile_id,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            source_event.id,
            resolved_event.project_id,
            resolved_event.actor_profile_id,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict do nothing;

          get diagnostics inserted_count = row_count;
          if inserted_count = 0 then
            resolved_notifications_suppressed :=
              resolved_notifications_suppressed + 1;
          else
            resolved_notifications_created :=
              resolved_notifications_created + inserted_count;
          end if;
        else
          insert into public.notifications (
            recipient_profile_id,
            category_slug,
            notification_kind,
            source_outbox_event_id,
            project_id,
            actor_profile_id,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            source_event.id,
            resolved_event.project_id,
            resolved_event.actor_profile_id,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict (
            source_outbox_event_id,
            recipient_profile_id,
            notification_kind
          ) do nothing;

          get diagnostics inserted_count = row_count;
          resolved_notifications_created :=
            resolved_notifications_created + inserted_count;
        end if;
      else
        resolved_notifications_suppressed :=
          resolved_notifications_suppressed + 1;
      end if;
    end loop;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'notifications.v1', statement_timestamp())
    on conflict do nothing;

    resolved_processed_count := resolved_processed_count + 1;
  end loop;

  return query select
    resolved_processed_count,
    resolved_notifications_created,
    resolved_notifications_suppressed;
end;
$$;

create or replace function public.process_push_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  jobs_created integer,
  jobs_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  push_enabled boolean;
  resolved_processed_count integer := 0;
  resolved_jobs_created integer := 0;
  resolved_jobs_suppressed integer := 0;
  inserted_count integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Push projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed',
      'project.chat_message_sent',
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed',
      'resource_chat.message_sent',
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed',
      'resource_saved_search.matched'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'push.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
      select coalesce(
        preference.push_enabled,
        category.default_push_enabled
      )
      into push_enabled
      from public.notification_categories as category
      left join public.profile_notification_preferences as preference
        on preference.profile_id = resolved_event.recipient_profile_id
        and preference.category_slug = category.slug
      where category.slug = resolved_event.category_slug;

      if push_enabled is null then
        raise exception using
          errcode = '55000',
          message = 'The resolved notification category is unavailable.';
      end if;

      if push_enabled then
        if resolved_event.category_slug = 'matching'
          and resolved_event.notification_kind = 'matching_available' then
          insert into private.push_delivery_jobs (
            source_outbox_event_id,
            recipient_profile_id,
            category_slug,
            notification_kind,
            actor_profile_id,
            project_id,
            project_kind,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            available_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            source_event.id,
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            resolved_event.actor_profile_id,
            resolved_event.project_id,
            resolved_event.project_kind,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            statement_timestamp(),
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict do nothing;

          get diagnostics inserted_count = row_count;
          if inserted_count = 0 then
            resolved_jobs_suppressed := resolved_jobs_suppressed + 1;
          else
            resolved_jobs_created := resolved_jobs_created + inserted_count;
          end if;
        else
          insert into private.push_delivery_jobs (
            source_outbox_event_id,
            recipient_profile_id,
            category_slug,
            notification_kind,
            actor_profile_id,
            project_id,
            project_kind,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            available_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            source_event.id,
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            resolved_event.actor_profile_id,
            resolved_event.project_id,
            resolved_event.project_kind,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            statement_timestamp(),
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict (
            source_outbox_event_id,
            recipient_profile_id,
            notification_kind
          ) do nothing;

          get diagnostics inserted_count = row_count;
          resolved_jobs_created := resolved_jobs_created + inserted_count;
        end if;
      else
        resolved_jobs_suppressed := resolved_jobs_suppressed + 1;
      end if;
    end loop;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'push.v1', statement_timestamp())
    on conflict do nothing;

    resolved_processed_count := resolved_processed_count + 1;
  end loop;

  return query select
    resolved_processed_count,
    resolved_jobs_created,
    resolved_jobs_suppressed;
end;
$$;

comment on function public.process_notification_outbox_batch(integer) is
  'Service-only, concurrency-safe notifications.v1 projector including immediate deduplicated saved-search matching alerts.';
comment on function public.process_push_outbox_batch(integer) is
  'Service-only, concurrency-safe push.v1 eligibility projector including immediate deduplicated saved-search matching jobs; provider delivery remains separate.';
