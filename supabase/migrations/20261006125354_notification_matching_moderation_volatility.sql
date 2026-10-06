-- MODINT01: 07C4 wraps the existing dispatcher after 09C1A made its matching
-- branch locking/volatile. Propagate that declaration through the new wrapper;
-- retain its role-offer branch, canonical recorded actors and grant boundary.
alter function private.resolve_notification_event(uuid) volatile;
