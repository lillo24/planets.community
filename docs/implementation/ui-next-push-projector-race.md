# Push projector concurrency repair during UI-NEXT integration

UI-NEXT-04 CI run 37602836394 failed the inherited push foundation verifier:
two concurrent workers reported two processed events, one job and no suppression,
where exactly one processed event was expected. The location slice changes no
database code. This separate repair preserves the UI stack and all current push
event mappings, service-only grants, channel independence and provider boundaries.

A probe against the batch-owned disposable PostgreSQL 17.6 database repeatedly
removed only the verifier's synthetic event receipt and ran four workers. It
reproduced duplicate counts in 17 of 200 rounds while the event retained exactly
one receipt. The event cursor's receipt predicate can use a snapshot taken before
a different worker's commit; locking the unchanged outbox event afterward does
not refresh that predicate. Unique recipient jobs prevent duplicate jobs but do
not prevent repeated eligibility evaluation or processed/suppressed counts.

Migration `20261007103000_push_projector_receipt_recheck.sql` replaces the latest
projector body with a fresh receipt check under the existing event lock, before
resolution or counters. It retains post-fan-out receipt insertion. No historical
migration, signature, schema, RLS policy, grant, payload or provider behavior changes.
The local verifier adds 100 rounds of four concurrent lost-receipt retries with
strict processed/job/suppression and durable job/receipt assertions.

The repaired projector completed the same 200-round probe with zero duplicate
counts. A clean canonical migration/seed replay passed, followed by lint, security
advisors, 118 pgTAP files / 3617 tests, the fake delivery protocol verifier, the
expanded real-OTP push verifier, generated-type drift checks and tooling tests.
Formatting passed. A source comparison verified that the projector body differs
from the latest predecessor only by the receipt recheck.

The exact final-head CI and merge result are recorded on the repair PR. All
database mutation is confined to the batch's disposable QA instance; the retained
phone backend and production/provider configuration are untouched.
