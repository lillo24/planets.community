# IDEA01B: public Idea clients

## Dependency and integration order

This client branch started at the reviewed PR #201 head
`cbf44c3981148016632cd2fc1a169708e74d9c34`, then integrated its correction
`85c150fd965064d8c5d5c092a068e491da703715`. That predecessor includes main
`8c20719846594bc656178144a02a1a124bc2d200` (LOCATION01 staging documentation and
MAPDETAIL02). The correction retains `actor_id` in the Idea-publication outbox
payload; it does not create another event contract.

Keep PR #201 draft through correction and combined client/domain validation.
Merge the reviewed backend first, update this client branch against the resulting
main, then merge the clients after affected CI passes. Code merge is separate
from hosted migration, web deployment and mobile distribution.

## User behavior

Private drafts use the existing save/departure/recovery flow. Publication is an
explicit choice: **In definition** or **Defined**, with a separate **Save private
draft** action. Idea publication requires a readable title and a 10-character
purpose summary; other content and logistics can remain absent. Saving a public
Idea does not promote it. Its tentative dates do not freeze editing or produce
an event status. Creator/current Co-creator structural authority still comes
from the canonical management RPC, including revocation and session checks.

Null Idea capacity is undecided and admits participants without a finite cap.
The editor explains that a later finite cap cannot be below current usage.
Existing admission, invitation, profile/photo, blocking, capacity and group-chat
rules apply without adding a logistics prerequisite to participation.

**Complete planning** first saves genuine edits while retaining the Idea phase,
then requests canonical missing requirements. The localized dialog previews
saved public content, dates, city and capacity. Back/dismiss retains the public
Idea; only explicit confirmation calls the atomic promotion RPC. The server
rechecks current authority, trust, future schedule and capacity. Failures retain
the same Idea and report an error. Successful promotion keeps ID, original
publication time, collaborators, invitations and chat history.

The initial Idea publication creates the existing private template baseline.
It becomes reusable only after a genuinely Completed Defined Project, never
from tentative past Idea dates. Checklist/tasks/polls and new chat message kinds
remain deferred until a separate collaborative-planning design is approved.

## Discovery and compatibility

New app/public web readers opt into IDEA01A's v2 RPCs. The Flutter gateway also
opts own, requested and delegated projections into their v2 contracts. Parsers
discriminate `idea | defined`; missing phase or incomplete Defined payloads are
errors, while Idea logistics/description/status may be null. Public payloads
remain sanitized; protected exact details are never inferred from author data.

All, In definition and Defined compose with existing keyword, city and skills.
All orders newest original publication first, rather than soonest event. Pages
carry `(published_at,id)` plus the first-page `reference_time`; filter changes
reset pagination. Phase/lifecycle/authorization filters remain live. Requested
rows retain their own ordering and deduplicate against raw public pages without
changing those pages' cursor. Retained app tab state preserves scroll/filters.
Web links use a versioned publication cursor; old schedule cursors reset to the
first page. Unknown logistics show honest undecided text, optional dates are
tentative, and Ideas remain List-only without requesting a map preview.

Legacy RPCs continue excluding Ideas. An installed old app opening an Idea link
gets its existing unavailable state, not unsupported null schedule fields.
The updated public web detail renders the same share URL and explains returning
to the web page or updating the app. Ordinary authenticated invitation routes
use the v2 sanitized detail too; token-specific permissions remain separate.
Existing Android intent handling stays unchanged; there is no new app-version
detection or automatic store redirect.

## Controlled hosted rollout (separate task)

1. Review the final merged migration and existing staging history. Apply pending
   additive migrations through the controlled migration workflow; never reset a
   shared stack. Verify legacy and v2 RPCs, grants, RLS and generated types.
2. Deploy the updated public web fallback and invite rendering before distributing
   an app that can publish Ideas. Verify a synthetic Idea share URL from an old
   app and from a browser. Legacy list/detail must continue excluding Ideas.
3. Distribute the updated app through the separately authorized release process.
   Verify creator/private draft/publication, unrelated request, organizer acceptance,
   member chat, Co-creator promotion, revoked authority and capacity races on the
   intended environment. Verify EN/IT narrow screens and large text on devices.
4. Keep provider activation, DNS, hosting cutover, Play submission and collaborative
   checklist design outside this rollout unless separately authorized.

## Validation evidence

Disposable local project `planets-idea01b-qa` uses ports 59421/59422/59424.
The retained founder stack is not reset. Local configuration and the temporary
QA Android package identifier are not committed.

- SQL: 127 files, 4,021 assertions passed; legacy readers, optionality, roles,
  privacy, outbox shape and promotion invariants are included.
- `proposal:verify:local`: base proposal/LOCATION/TW01 checks and 77 real local
  OTP/JWT Idea checks passed, including join/chat, invitation preservation,
  concurrent promotion/edit/admission and denials.
- Client tests cover discriminated parsing, publication anchors/filter reset,
  optional Idea publication, explicit promotion, server rejection and logout/rejoin.
  Flutter presentation tests include EN/IT at 320dp and 1x/2x text.

Rendered browser/emulator evidence and final scoped check results are recorded
in the PR. Widget/REST/emulator evidence is not physical-device, staging or Play
qualification. No hosted migration, public deployment or release is performed
by this plan.
