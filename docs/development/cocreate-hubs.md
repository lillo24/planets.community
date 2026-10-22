# Experimental topic hubs and General (C01)

This implements RUNALL's explicit experimental defaults. Activation stays OFF
outside an owned local test. It creates no native Project, registered Group,
provider integration or production topic-curation service.

## Owners and access

`20261022090000_cocreate_hubs_general.sql` owns curated hubs, one transactional
General anchor per hub, membership episodes, immutable human messages, private
command receipts and scoped reports/moderation. It reuses the tested curated
topic catalogue and A01 identity/policy/account gate; post acceptance grants no
hub or room membership. Every private table has RLS and no API-role grants.

Public list/detail contain only hub/topic identity, topic label, broad locality
and creation time. Filtering (literal text, exact case-insensitive locality,
curated topic) and lifecycle/suppression checks precede paired cursor paging.
There is no prejoin roster, transcript, unread or room admission in this shape.

Hub admission is explicit. General membership is the hub's current General
episode, never all its numbered children. Active members may read earlier room
history; joining baselines unread at the current committed sequence. Leaving
freezes this episode through the exit sequence, stops sending and denies roster
reads. Rejoin creates a new episode and read secret. Every history/send/People/
ACK call binds both room and exact episode to the current actor. Old receipts
acknowledge an old command and cannot re-admit, close a new episode, grant future
history or acknowledge the new episode. Removal creates a persistent admission
barrier; only a scoped staff reversal permits a fresh deliberate join.

Room mutation/send/exit/ACK serialize on the same hub row. Mutations first share
lock the current account/profile, then take the actor command lock and hub lock;
they recheck canonical eligibility. All actor/hub effects and immutable receipts
commit together. `private.cocreate_cascade_hub_exit(hub,actor)` is the private
transaction extension point C03 must replace before children become available.
It currently validates its scope and has no children to alter.

## Reads, unread and invalidation

`get_cocreate_room_page` returns actor/room/episode, closed status, descending
human messages and a newest-page HMAC receipt. The receipt binds actor, room,
episode and committed sequence; older pages have none. A former episode cannot
read beyond its exit sequence. ACK rechecks live authority and advances only
its own monotonic frontier. Reads never acknowledge implicitly.

`list_own_cocreate_rooms` chooses one latest episode per canonical room before
paging. Complete unread counts compose with native Messages and B02 contacts;
one unread General contributes one Groups conversation, independently of loaded
pages. Mute persists on the episode and affects delivery preferences, never
silently marks human messages read. This experiment activates no push provider.

Only actor-scoped metadata hints are broadcast. They contain `profile_id` plus
the pinned Realtime delivery UUID, with no body/room/roster/capability. A former
member gets no future room activity hint. Reconnect must reread authority.
Suppression, suspension and erased accounts deny current reads/ACK/send even
with retained identifiers. Exact own-exit metadata and leave remain identity-only
with the gate OFF or policies outdated. Local fixture erasure tests follow the
existing `145_contact_erased_subject_reports` profile-before-Auth order and
verify the exact synthetic email; they are not a production erasure policy.

Current configurable bounds: 25-row default/50 maximum list pages, 30-message
default/50 maximum history pages, 2,000 Unicode-character messages, 30 messages
per actor per minute (configured 1–120), and 50 active hub memberships per actor
(configured 1–100). Curated topics retain B02's 100-entry bounded projection.

## Scoped moderation

`submit_cocreate_room_report` accepts only an exact message inside one of the
reporter's admitted history windows. It uses the existing global report UUID,
categories, case state machine, immutable evidence and identifier-only audit.
It does not expose a transcript after access loss. Staff can inspect the exact
reported snapshot and separate current source versions through
`get_moderation_case_cocreate_room`; a staff role grants no room/roster access.

`moderate_cocreate_hub` requires current staff, an exact General report case,
immutable command intent and hub version. It can suppress/restore, remove or
reverse removal of that reported sender, or archive the hub with frozen exits.
No user curator obtains private oversight. It does not transfer management or
alter another hub/native domain. Numbered-room moderation is C03 work.

## Local reproduction and evidence

Use only the owned `planets-cocreate-qa-root` connection and pipe
`npipe:////./pipe/podman-planets-cocreate-qa`, with the installed pinned CLI.
`SUPABASE_INTERNAL_IMAGE_REGISTRY=ghcr.io` uses the same pinned official images.
CI explicitly sets `PLANETS_DISPOSABLE_QA=1`; every tool additionally checks API,
database and Mailpit loopback endpoints. No hosted flags/credentials are used.

```text
npm run cocreate:seed:local
npm run cocreate:hubs:verify:local
npm run db:lint
npm run db:advisors
npm run db:types
```

Seeding creates only three deterministic synthetic topics/hubs (Calcetto, Giochi
da tavolo, Nuovi a Trento) and never enables the gate. The OTP verifier requires
the gate initially OFF, temporarily enables it, and restores OFF in `finally`.
It covers duplicate admission/send, changed intent, prejoin denial, earlier and
frozen history, send/exit concurrency, stale receipts, read frontiers, scoped
staff evidence, removal/reversal, suppression, bans, shared-room blocking and
erased identity. Run rolled-back pgTAP on a fresh disposable replay **before**
populating OTP fixtures; global predecessor assertions assume a clean baseline.

Fresh replay and all 163 files/7,113 pgTAP assertions passed before two additional
metadata assertions. The final targeted C01 file passes 240 assertions; genuine
OTP/concurrency passes 77. Initial lint found an unused People variable and two
unused extension parameters; source was repaired and lint rerun. See the current
progress ledger for final results. C02 supplies mobile hub/General UI, C03 the
atomic child extension; no live mobile hub journey or native phone QA is claimed
by this backend stage.

## C02 mobile integration

Migration 20261022100000 adds only an admitted General context reader, with
actor/hub/room/episode checks and no implicit read ACK. It deliberately supports
frozen history after public retirement. Its eight negative/context assertions
pass on the populated C01 local upgrade. Lint and security advisors are clean.

Communities, General, member-only People, mute and explicit warned leave are
registered separately from Demo. Existing Messages Groups shows one canonical
latest-episode General row, including frozen history. Mode OFF preserves it and
exact Auth-only hub exits. Report submission uses the C01 exact message endpoint;
foreign Project/other context is rejected before transport. The shared viewport
keeps visibility/identity/exact retry rules while its General adapter supplies
the episode-bound server receipt. No preview or member list marks messages read.

C02 contract-fixture widget tests cover guest/auth return without auto-join,
deliberate admission, lost-reply retry after canonical membership appears, A/B
and same-actor episode changes, frozen former history, one Messages row and
non-ACK People. Separate genuine backend testing remains the C01 OTP verifier.

## C03 numbered rooms

Migration 20261022110000 allocates a persistent per-hub number, room and creator
episode in one transaction. Numbers never depend on visible rows or get reused.
Capacity defaults to 5 (2–50), includes the creator and reserves suspended members'
seats. Admission, capacity, removal, archive and hub departure serialize under the
same hub lock. Leaving a managed room archives it and freezes all active episodes;
hub departure ends only that hub's children. Explicit removal blocks self-rejoin
until the manager/staff reverses it; reversal never enrolls anyone automatically.

Experimental abuse defaults are 50 active numbered memberships (1–200) and 5
creations per rolling 24 hours (1–50). They are private server configuration, not
production policy. Public summaries deliberately expose aggregate occupied/capacity
and stable numbers, never managers, episodes, rosters or messages. Private context
binds actor/hub/room/episode. The versioned own-room reader adds kind/number while
the existing General-only reader retains its exact shape.

Scoped staff actions require an exact reported numbered-room message and current
room version; staff gains no room browsing. Permanent Auth erasure/deletion ends
co-creation episodes and archives creator orphans through the existing reviewed
metadata hooks, preserving their OIDs/ACLs. It does not change profile creation,
native retention or moderation evidence. Temporary suspension only denies access.

Reproduce with `npm run cocreate:numbered:verify:local` on the same owned disposable
backend. Fresh full database tests pass 165 files / 7,268 assertions; the numbered
file contributes 74. Genuine OTP/concurrency checks pass 101 assertions, including
last-seat and capacity races, stable concurrent numbering, frozen history,
cross-room ACK rejection, removal/reversal, scoped moderation and soft/physical
erasure. Existing post/contact (72) and hub (77) verifiers pass again. Lint/advisors
are clean and activation is OFF. Physical erasure of a reported subject correctly
hits native retained-case FK protection; the verifier asserts that protection and
uses a separate unreported synthetic identity to qualify physical deletion.
