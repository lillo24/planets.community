-- A cursor's NOT EXISTS snapshot can precede another worker's commit even when
-- its event row is locked only after that commit. Claim the unique consumer
-- receipt before projection; a stale cursor then skips the committed winner.
-- Receipt and notifications remain in the same transaction, so failure rolls
-- both back. Keep the canonical function/OID, resolver, budget and grants.
do $$
declare
  definition text;
  receipt_block text := $receipt$    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'notifications.v1', statement_timestamp())
    on conflict do nothing;

$receipt$;
  loop_marker text := E'  loop\n    for resolved_event in\n';
begin
  definition := replace(pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ), E'\r\n', E'\n');
  if length(definition) - length(replace(definition, receipt_block, ''))
      <> length(receipt_block)
    or length(definition) - length(replace(definition, loop_marker, ''))
      <> length(loop_marker)
    or strpos(definition, 'private.resolve_notification_event(source_event.id)') = 0
    or strpos(definition, 'for update of event skip locked') = 0
    or strpos(definition, 'private.process_contact_activity_batch') = 0 then
    raise exception 'Review the changed canonical notification worker before moving its receipt claim.';
  end if;

  definition := replace(definition, receipt_block, '');
  definition := replace(definition, loop_marker,
    E'  loop\n'
    || receipt_block
    || E'    get diagnostics inserted_count = row_count;\n'
    || E'    if inserted_count = 0 then\n'
    || E'      continue;\n'
    || E'    end if;\n\n'
    || E'    for resolved_event in\n');
  execute definition;
end;
$$;

comment on function public.process_notification_outbox_batch(integer) is
  'Canonical service-only notification worker. Shares one bounded budget between contact pages and legacy events. Legacy receipts are claimed atomically under the event lock in the same transaction as projection; a failed projection leaves the event retryable. Continue until processed_count is zero.';
