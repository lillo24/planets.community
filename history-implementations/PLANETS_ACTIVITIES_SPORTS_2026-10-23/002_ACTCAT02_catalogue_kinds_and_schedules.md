# ACTCAT02 — extend the catalogue beyond dated events

Read [001_context.md](001_context.md) first. This is implementation step 002; complete it, merge normally, and continue the queue.

## Outcome

The canonical backend and mobile domain can represent a dated event, a course/recurring offering, and an undated sports place without fabricating dates, descriptions, enrollment or native membership. Preserve old event readers. Establish the contracts subsequent UI/source/map steps will consume, with the minimum working client adaptation needed to keep the app functional.

## Evidence and areas to inspect

At the inspected baseline, `private.external_activities.content` is normalized JSON, occurrences have their own table, and current list eligibility requires `private.external_activity_next(...)` within 90 days. Public payloads and `ExternalActivityPage.parse` require a next occurrence. `description` is currently required/nonempty in both Node and SQL validators. There is no public geometry contract. Inspect current migration, `scripts/lib/external-activities/records.mjs`, importer, mobile domain/gateway/controller/widgets, generated types and tests before choosing an additive shape.

Do not build a parallel Sports database. A small discriminated extension of this catalogue is preferred; choose columns/tables versus JSON fields based on current indexing/contracts. Keep stable `(source_id, upstream_id)` identities and internal UUIDs.

## Required behavior

1. Introduce an explicit bounded kind such as **event / course / place**. Distinguish listing kind from category (`sports`, `culture`, `other`) and discipline. Preserve imported/native identities. Keep provider-specific names out of canonical client logic.
2. Events retain verified exact occurrences, cancellation, date-only/all-day semantics, timezone offsets and the current upcoming window. A course is one offering, not one card per lesson. A place requires no occurrence and must not be assigned “today” or midnight to pass validation.
3. Make source descriptions genuinely optional where absent; an official type/name/venue can form a factual title, but missing prose must not be replaced with invented promotional text. Existing event payloads remain valid.
4. Support the minimum explicit course schedule contract: optional season start/end dates, supplied schedule text, structured bounded weekly days/time/timezone when explicitly provided, and explicit occurrences/exceptions when available. Reuse proven time primitives; do not introduce a full unbounded RRULE engine.
5. Only derive future sessions from a complete, explicitly structured rule with a finite term/horizon. Preserve DST, date-only meaning, exceptions and unknown end time. If a course is current by its explicit season but no next lesson can be calculated, show it in Courses with “schedule to confirm”/source schedule, without an invented `next_at`. Unknown-season/expired offerings must not imply current enrollment; keep them out of active course discovery unless the source explicitly asserts ongoing validity under a documented bounded policy.
6. A place can carry source access/opening text, public venue/address and optional **published public geometry**. Add the typed coordinate/precision/provenance fields needed by 007. A point may be venue-level or locality-level; record which. Do not convert a city label to a precise point or infer operating hours/free access/booking availability.
7. Price/audience/level/access information is optional source-backed text or explicit controlled values. Unknown is not free, open, beginner-friendly, adult-only or available. Do not build capacity/booking/organization-profile domains.
8. Define typed server-side filters for kind, category, discipline, literal search and an optional explicit date window for dated/course material. Return complete-catalogue facet metadata rather than deriving choices from a loaded page. Keep this small: unsupported fine facets are not mandatory.
9. Define deterministic ordering: upcoming events by relevant occurrence; current courses by known next session then a stable explicit unknown-session group; places alphabetically by normalized title plus UUID, or another documented stable rule. Mixed-kind ordering must be explicit and stable, not random or a fake popularity ranking. Dates do not erase places from their dedicated section; when a date-only filter cannot apply to places, exclude them with clear UI scope rather than claiming they happen on that date.
10. Keep existing freshness defaults for legacy events. For places, provide a bounded documented source/kind policy suitable for a directory (a conservative initial choice is warning at 7 days, hide at 30 days); current-season validation is separate from fetch freshness. Do not unhide stale records by refreshing only source-wide success. New source-specific overrides must be private, validated and bounded.

## Compatibility and security

Use additive/versioned RPCs or a demonstrated compatible evolution. An old Flutter client that requires `next_at` must never receive a place or new nullable payload unexpectedly. Retain old list/detail signatures/projections with legacy scheduled-event semantics; new clients use the extended contract. Document the rollout order.

Public detail/source-disable/cancellation/expiry rules stay authoritative; examples do not enter this domain. Configuration, rights evidence, import state and credentials remain private. Geometry comes only from the external published source; no native/private location lookup or paid geocoding. No authorization changes to Projects, Tavoli, resources or profiles. Use current migration generation, RLS/grants and generated-type conventions.

Adapt the current Dart model/gateway/parser and minimal cards/details so all supported payloads render safely; substantial layout belongs to 003/004. Preserve ACTMET01 imported item UUIDs, share-link validation and denied analytics gate. Avoid a speculative client-wide repository abstraction.

## Acceptance and verification

- Replay additive migrations on an isolated local stack; verify old event RPC responses still satisfy the old parser/shape. New list/detail returns each kind with honest missing fields.
- Node and SQL canonical validation agree on kind/schedule/geometry/nullability. Reject impossible dates, invalid/infinite/out-of-range coordinates, missing precision, unsupported keys, malformed URLs and unbounded recurrence.
- Meaningful synthetic cases: an event across Rome DST, nonconsecutive occurrences, an explicit weekly term crossing DST with a cancelled lesson, a current course without known next session, an expired/unknown-season course, a place without description/date, and a locality-only place.
- Verify stable repeat/update identity, correct filtering before pagination, deterministic order and expiry/source-disable on list and exact detail. Anonymous readers cannot reach private source/config/raw state or write.
- Flutter parsing/rendering and controller fencing survive kind changes, no-next-session courses, invalid payloads and cancelled/removed items; ordinary legacy fixtures still pass.
- Update payload/eligibility/freshness docs, generated types, feature maps and the queue progress record. Report every intentional contract change and unresolved case. No live source or hosted credentials are required for this step.
