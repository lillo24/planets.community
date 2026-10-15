-- Keep the established public projector as the canonical worker. The initial
-- contact migration delegated legacy work to a renamed function; that obscured
-- its resolver/locking contract and changed the OID used by cached callers.
-- Restore that original function identity and add only the contact page budget.
do $$
declare definition text; marker text:=E'  for source_event in\n';
begin
  definition:=replace(pg_get_functiondef('private.process_notification_outbox_before_contacts(integer)'::regprocedure),E'\r\n',E'\n');
  if (length(definition)-length(replace(definition,E'  inserted_count integer;\n','')))<>length(E'  inserted_count integer;\n')
    or (length(definition)-length(replace(definition,marker,'')))<>length(marker)
    or (length(definition)-length(replace(definition,E'    limit p_limit\n','')))<>length(E'    limit p_limit\n')
    or strpos(definition,'private.resolve_notification_event(source_event.id)')=0
    or strpos(definition,'for update of event skip locked')=0 then
    raise exception 'Review the installed notification projector before composing contact pages.';
  end if;

  -- DROP affects only the new wrapper. The original worker regprocedure moves
  -- back to its prior public name, preserving its identity and existing body.
  drop function public.process_notification_outbox_batch(integer);
  alter function private.process_notification_outbox_before_contacts(integer) set schema public;
  alter function public.process_notification_outbox_before_contacts(integer) rename to process_notification_outbox_batch;
  definition:=replace(pg_get_functiondef('public.process_notification_outbox_batch(integer)'::regprocedure),E'\r\n',E'\n');
  definition:=replace(definition,E'  inserted_count integer;\n',E'  inserted_count integer;\n  contact_result record;\n');
  definition:=replace(definition,marker,E'  -- One canonical worker budget covers bounded contact pages and legacy events.\n'
    ||E'  select * into contact_result from private.process_contact_activity_batch(greatest(1,p_limit/2));\n'
    ||E'  resolved_processed_count := contact_result.processed_count;\n'
    ||E'  resolved_notifications_created := contact_result.notifications_created;\n'
    ||E'  resolved_notifications_suppressed := contact_result.notifications_suppressed;\n\n'
    ||marker);
  definition:=replace(definition,E'    limit p_limit\n',E'    limit greatest(0,p_limit-contact_result.processed_count)\n');
  execute definition;
end;
$$;
revoke all on function public.process_notification_outbox_batch(integer) from public,anon,authenticated,service_role;
grant execute on function public.process_notification_outbox_batch(integer) to service_role;
comment on function public.process_notification_outbox_batch(integer) is
  'Canonical service-only notification worker. Shares one bounded budget between contact event pages and unchanged legacy resolver events; continue until processed_count is zero.';
