# Co-creation experimental contract (A01)

Authority: [COCREATE-RUNALL](../../history-implementations/PLANETS_COCREATE_RUNALL_autonomous_implementation.md).
These defaults apply only to this isolated development programme. They do not
settle production policy or change any existing domain's audience/history.
Project/Event/Tavolo classification and final visual identity remain unresolved.

## Objects and access

| Object                | Deliberate public projection, while server gate ON                               | Admitted access                                                                               | Authority                                                                                 |
| --------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| People-seeking post   | Open, unexpired, unsuppressed public text, curated topic and broad locality only | Author's drafts/management; each requester and author see only their request                  | Author edits/publishes/closes/renews; no membership rights                                |
| Accepted post contact | None: no note, count revealing identity, roster or transcript                    | The two accepted counterparties; explicit acceptance creates/reuses the post-scoped contact   | Neither can enroll the other in anything                                                  |
| Curated topic hub     | Stable ID, topic, broad locality, sanitized description                          | Explicit active hub membership grants General only                                            | Catalogue curation is database-owner controlled; ordinary members can create small groups |
| Numbered group        | Stable hub number, occupied/capacity, availability; no roster/transcript         | Explicit separate group membership; active hub membership prerequisite                        | Creator manages that room; staff see only scoped reported evidence                        |
| General/group history | None before admission                                                            | Earlier room history disclosed on admission; former episode frozen at committed exit sequence | Every read rechecks account/moderation; receipts never grant access                       |

Hub membership is not registered Group membership. There is no synthetic Project,
shared registered-Group permission or cross-domain automatic admission. Capacity
defaults to 5, creation range 2–50, includes the creator, and never shrinks below
occupied seats. Per-hub numbers are stable, never reused or renumbered. Full is
not archived. Empty/orphaned groups archive; no automatic manager succession.
Multiple group memberships are permitted.

Hub leave atomically ends all that actor's child memberships, freezes their
history, and archives groups orphaned by the departure. Other hubs and native
domains are unaffected. Removed users cannot self-rejoin without an authorized
reversal. New admission is a fresh episode with fresh eligibility.

## Gates, eligibility and own-exit

The device setting `planets.sandbox.coCreation` owns presentation only. The
private `cocreate_settings` singleton owns availability, default OFF; clients,
including service-role API callers, have no table access or activation endpoint.
`get_cocreate_availability()` returns exactly `{"enabled":false|true}`.
Missing configuration is OFF. All domain readers/commands must call
`private.require_cocreate_enabled()`; availability alone is never admission.
Do not read configuration once and retain it as a room grant.

The shared actor boundary validates expected Auth/Profile identity, current
complete profile, nonanonymous/nondeleted/nonbanned Auth identity and the
existing registered policy acceptance. It uses the current published
`POLICY01-2026-10-08-v1` bundle through the private server setting; it collects
no second consent or birthday. The execution base has no separate verified
age or application suspension domain. Existing Terms/Rules eligibility remains
the boundary; do not invent an age policy or implement Plan 09 suspension here.
Auth ban/deletion are checked live. Any later canonical account restriction must
also be composed into this boundary before activation.

Identity-only own-exit/recovery remains possible with the gate OFF or incomplete
profile; it must return no transcript, roster or another person's metadata.
Changing presentation does not revoke backend membership. Messages and exact own
exit destinations remain reachable independently of the visual mode.

## Posts and contact

Post states are draft/open/closed, with configurable 30-day discovery lifetime.
Expiry filters discovery/admission before pagination; it is not erasure or a
retention promise. Renewal/closure are deliberate author actions. No exact
address, private contact field, invitation, request note or transcript belongs in
a public projection. Guidance reminds authors that free text is public; it is
not advertised as an automatic personal-data detector.

Interested is a private pending/accepted/declined/withdrawn request, with optional
bounded note. No self-request. Explicit acceptance opens a bilateral contact;
opening a post, returning from login or joining a hub never sends a request.
Closed/expired posts accept no new requests. Closure preserves existing accepted
contacts. A fresh attempt after decline is deliberate and rate limited.

## Reuse and implementation decisions

- Keep canonical data in private PostgreSQL tables with RLS and no client table
  grants. Hardened expected-identity RPCs follow the existing repository pattern,
  with empty search paths and explicit least-privilege function grants.
- Use distinct typed Post/Hub/NumberedGroup UUIDs and domain routes; Demo IDs
  cannot parse as canonical IDs. Existing RPC signatures remain unchanged.
- Reuse message rendering/viewport components where their contracts fit. Do not
  reuse registered-Group audiences, automatic General membership or Project
  participation as co-creation grants. Add typed Messages projections.
- Immutable commands freeze actor/key/action/intent. Exact retries recover the
  original result after reauthorization; changed intent fails. Lock ordering is
  command identity, source post/hub, numbered room, episode/message. Capacity,
  send, exit and archival must serialize at the same room/sequence boundary.
- Unread counts human incoming messages only. Admission exposes history without
  retroactive unread; only a rendered authorized newest-page receipt can ACK.
  Recruitment is structured, capacity-resolved content, not a fake human send.
- Existing symmetric blocks bar direct contact/admission against counterparties
  and relevant managers. Shared hub membership follows the existing shared-room
  rule: blocking does not promise that blocked people cannot share a public hub.
  Reporting remains available. No public chat activation before moderation and
  scoped evidence paths are complete.
- Existing moderation staff roles/evidence infrastructure own review; staff do
  not inherit private-room browsing. Report targets must be extended explicitly,
  with canonical subject identity and no raw evidence in generic outbox/audit.
- New raw actor provenance must not introduce new Auth/Profile erasure blockers.
  Current erasure restrictions and lawful-retention decisions remain unchanged;
  no destructive cleanup, perpetual exemption or invented retention interval.
- Server bounds: 5 open posts per actor, request cooldown 300 seconds,
  recruitment cooldown 3600 seconds; all are documented bounded owner settings.
  Later stage payload/page bounds belong at their RPC interfaces, not just UI.

## Automated design checkpoint

A00's eight rendered combinations cover EN/IT, light/dark and 320dp at 1x/2x.
Actual router tests exercise mode-off detail redirection and unchanged native
destinations. The initial large-text test scrolled a card only partly into view;
the test now settles and fully reveals it before tapping. Manual inspected
captures include Italian hub 2x and English dark Posts 2x. No physical Android,
iOS, screen-reader or founder phone acceptance is claimed.

Previews always say Demo, have no gateway/ACK/analytics and never stand in for an
empty/error live result. The composer is local, ephemeral and account-cleared.
Native routes, protected drafts, tutorial baseline and bottom-right preference
remain owned by their existing modules.

## Activation and qualification

Only the owned `planets-cocreate-qa` Podman machine is authorized for test
activation. Its CLI process must set both
`CONTAINER_CONNECTION=planets-cocreate-qa-root` and
`DOCKER_HOST=npipe:////./pipe/podman-planets-cocreate-qa`; the pinned CLI's
Podman invocation otherwise follows the user's unrelated default connection.
Never change that global default or start/reset existing PLANETS machines.

Canonical migrations keep activation OFF. pgTAP activation is transaction-local
and rolled back. The owned local verifier may deliberately enable it for
synthetic sessions and must restore OFF when finished. Hosted configuration,
provider delivery, analytics, app installation/store publishing and deployment
are outside this programme. Pending backend stages and actual evidence are
tracked in [the progress record](cocreate-progress.md).
