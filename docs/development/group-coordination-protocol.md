# D03 provisional coordination protocol

**Review only. D00 approval reference remains absent.** This is a bounded extension
of a live accepted bilateral D contact. It is not deployed or approved for release.
The [D00 contract](group-contact-contract.md) owns the access and retention gate.

## Seats, audience and activation

The two original admitted people remain fixed. The initiator explicitly selects
one to three additional public groups and authors a new title (120 Unicode
codepoints) and note (1000). No message/link/preview is copied automatically.
Eligible current managers can see that invitation and the initiator's disclosed
identity. The original peer's identity/affiliation and the source conversation's
existence, title and ID are withheld from new invitees.

A manager claims one group seat, binding their individual ID and exact authority
grant episode. Claiming explicitly shares their identity/group with the original
representatives and does not open a chat. One person cannot occupy two seats,
even when they represent several groups. Ordinary membership supplies no seat.

Every seat claim/replacement changes the audience version. Both original people
review the complete named audience and confirm that exact version before the
additional claimants can see the complete human audience. Each additional person
then confirms the same version. This staged identity disclosure is a conservative
**provisional clarification requiring founder review**, not an approved policy.
Any changed group/person/grant invalidates earlier confirmations. Changed targets
retire the previous additional seats and start a new selection round even when
the same groups are chosen; original seats remain. A revoked grant
never revives old consent or history after regrant. A fresh explicit claim begins
another audience version.

The last valid confirmation atomically creates one new coordination conversation,
its exact three to five admissions, and a receipt. It has the freshly authored
summary and zero inherited messages/read state. Existing conversations stay
unchanged. Source navigation appears only after independent source authorization.
After activation, leaving the source does not revoke the separate fresh admission.

Cancellation by the initiator is a safe terminal exit even after expiry/role loss;
an eligible invited person may decline. Block resolves affected pending proposals
without exposing its direction. Expiry is a seven-day predicate, with no timer or
automatic deletion. Three live proposals and ten new proposals per actor per day
use the D00 limits. Coordination cannot recursively start from another coordination
room. Current admitted people may close a room; former people may leave only their
own seat, recover their own receipt and report known received content.

## Serialization and delivery

Commands use the existing actor/action receipt namespace, hash the exact submitted
operation, IDs, audience version and text, and replay only identical intent.
The caller freezes these fields in memory while delivery is uncertain. Receipt
recovery is metadata only and never restores authorization. Account/phase changes
discard retained attempts; late replies are checked against the initiating epoch.

Lock order is actor/action, actor quota for creation, sorted complete block pairs,
sorted complete group set, sorted Auth/profile rows, then proposal/admissions.
The manager snapshot is rechecked after lock waits. All groups, named people,
grants, source access, expiry, block state and audience version are rechecked at
activation. Block's existing pair hook reserves the complete legacy/D group set
before acquiring any group row. Safe cancellation needs only sorted groups and
the proposal row and introduces no inverse pair/account locks.

## Projections and safety

Requests v3 unions legacy requests, D01 contact requests and coordination proposals
before one `(activity_at, kind rank, UUID)` keyset limit. Coordination rank is 3.
Installed Requests v1/v2 shapes/kinds remain unchanged. Chats v6 and unread v2 use
the existing D human-message boundary; proposal/consent progress is never fake
human unread. One existing own-profile channel carries identifier-only activity
or neutral access invalidation. No room/participant subscriptions are added.
Claim/retirement/resolution invalidation also reaches other managers who may have
cached the invitation, including known former recipients; it carries no target ID.

Exact invitation reads record a private seen receipt. A previously received note
can be reported after role loss/removal/block, without rereading the note. Typed
`group_coordination_proposal` reports store an immutable target and expose only
that fresh note through the existing case-scoped staff evidence API. Ordinary
staff do not gain participant history. Own report history v3 includes the new
kind; v1/v2 filter it before their limits. Coordination human messages reuse D01
message reporting, safe leave and read/unread protection.

## Reproducible local checks

Use only the checkout's disposable loopback Supabase project. On Windows/Podman,
the task selector uses `DOCKER_HOST=npipe:////./pipe/podman-planets-development`
and the project's configured ports; those task ports are not committed.

Podman's Windows mount adapter requires the empty local `supabase/snippets/`
directory before starting Studio. Create it locally; it contains no source and
needs no committed placeholder. When CLI database recreation stalls, an explicit
task-only cold start at D02 can establish the baseline. Run the upgrader with
`--from-current-d02` only after that fresh D02 replay: it requires disposable local
QA, rejects CI and checks the exact last D02 migration before populating contacts,
hashing old records and applying D03. This is a separately recorded upgrade
procedure, never an automatic success fallback. Normal CI still runs full reset.
The D03 upgrader invokes the installed pinned CLI binary directly and gives each
subprocess five minutes; a timeout is a failure, not a passing upgrade.

- `npm run group:contact:upgrade:verify:local`: populated pre-D main upgrade.
- `npm run group:coordination:upgrade:verify:local`: populated D02 contacts/messages,
  old table/column/row hashes, warmed Block OID and repeat additive migration-up.
- `npm run group:contact:verify:local`: D01 real-Auth regression coverage.
- `npm run group:coordination:verify:local`: independent real OTP/PostgREST actors,
  fresh history, exact consent, replay, role regrant, Block and equal-time pages.
- `npm run db:lint`, `npm run db:test`, `npm run db:types:check` after full replay.
- `npm run check:mobile`, `npm run check:web` for the shared Messages/safety seams.

`PLANETS_DISPOSABLE_QA=1` is required for local upgrade resets (CI is separately
allowed); `MAILPIT_URL` selects the task's loopback mailbox. Validation CI adds the
D03 upgrade and race verifier only inside the existing change-scoped Database job,
preserving required status names and avoiding a duplicate main-push campaign.

The native preparer uses four synthetic OTP accounts and three groups. Its
credential-bearing compile defines must be outside the checkout in OS temporary
storage. Run `integration_test/group_contact_smoke_test.dart` through the existing
`test_driver/group_contact_screenshots.dart` on a task-owned Android emulator, with
ADB reverse to that task's API port and demo tools disabled. Screenshots live in
ignored `build/group-contact-screenshots`. Never print or commit these JWT defines.
The journey covers D02 and staged/all-party D03 consent with a lost final reply,
fresh empty history, real human send, role loss/report/block, independent Project
participation, and Italian 320dp/2x audience/composer layouts. Record actual runs
and screenshot inspection in the final evidence; source code alone is not a pass.
