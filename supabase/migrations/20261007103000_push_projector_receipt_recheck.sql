-- Preserve all current push event mappings, channel policy and grants while
-- preventing a stale cursor from projecting an already-receipted event twice.

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
    -- The cursor's receipt predicate uses its earlier statement snapshot. A
    -- worker can commit after that snapshot but before this unchanged event
    -- row is locked. Re-read under the lock before resolving or counting it.
    -- This VOLATILE function uses fresh READ COMMITTED statement snapshots.
    if exists (
      select 1
      from private.outbox_consumer_receipts as receipt
      where receipt.outbox_event_id = source_event.id
        and receipt.consumer_key = 'push.v1'
    ) then
      continue;
    end if;

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
