begin;
select plan(4);
select is((select provolatile::text from pg_proc where oid='private.resolve_notification_event(uuid)'::regprocedure),
  'v','role-offer dispatcher propagates locking moderation resolver volatility');
select is((select provolatile::text from pg_proc where oid='private.resolve_notification_event_without_role_offers(uuid)'::regprocedure),
  'v','wrapped legacy dispatcher keeps its moderation lock semantics');
select is((select provolatile::text from pg_proc where oid='private.resolve_saved_search_matching_notification_event(uuid)'::regprocedure),
  'v','matching resolver remains locking, not an optimistic stable read');
select ok(not has_function_privilege('authenticated','private.resolve_notification_event(uuid)','EXECUTE'),
  'volatility repair does not expose the private projector resolver');
select * from finish();
rollback;
