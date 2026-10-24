# PLACE01 — reusable co-creation Places

A **Place** is a stable PLANETS UUID for a normalized venue. A topic/locality
community has no permanent venue or venue owner. Numbered groups can have an
optional usual Place; meetings can independently have an immutable occurrence
Place. Neither association changes chat membership, attendance or capacity.
Online, roaming and undecided groups/meetings remain fully valid without one.

## Identity and provenance

`private.cocreate_places` stores only MAP01 admitted normalized OSM-backed
Geoapify fields and a server fingerprint. Exact comparison includes every field
except `verified_at`: verification time is provenance rather than venue identity.
Confidence, kind, coordinates, label, locality, administrative area and licensing
fields must all match. A fingerprint match is checked against the actual JSON.
There is no proximity/name/locality merge. Changed results may create another
UUID; existing snapshots never update. Verification describes provider provenance,
not a continuing guarantee that a venue is accurate or open.

Creation consumes an actual unused, unexpired server selection inside a successful
association/scheduling transaction. Clients send a receipt or an already authorized
PLANETS UUID, never labels/coordinates. Reuse requires a currently visible
association in the same community and makes no provider request. A guessed or
orphaned UUID alone grants no access. Clear leaves the Place and other associations
intact. No provider/OSM IDs, raw JSON, query text, GPS or enrichment metadata are stored.

## Visibility and lifecycle

| Association                    | Current numbered member             | Other hub member                | Cross-community discovery            |
| ------------------------------ | ----------------------------------- | ------------------------------- | ------------------------------------ |
| Usual Place, publication OFF   | Authorized group                    | Hidden                          | Hidden                               |
| Meeting Place, publication OFF | Canonical current-meeting authority | Hidden                          | Hidden                               |
| Exact address                  | Authorized group only               | Hidden                          | Hidden                               |
| Explicitly published amenity   | Authorized member review            | Eligible group/recruitment rows | Eligible published associations only |

Publication defaults OFF independently for usual and occurrence associations.
Only an `amenity` can be published. Addresses stay inside current numbered
membership. Localities are filtered from exact venue selections; manual text
does not create a Place.

Private member review retains FIX01 parity after blocking or temporary creator
unavailability. Newcomer publication also requires an available unblocked manager,
public/unsuppressed/unarchived group and hub, and for a meeting a future,
non-cancelled latest occurrence with live recruitment. Full sessions remain visible
with actual occupancy; viewer eligibility reuses `cocreate_can_join_recruitment`.
Ended episodes grant no member exception. Hidden associations contribute no rows,
counts or continuations. No roster, manager identity, transcript, read token,
attendance list or ACK is returned. An authorized current member can open a retained
past/cancelled venue with an empty upcoming list; this adds no discovery exception.

## Commands and compatibility

`set_cocreate_usual_place_v1` requires the current manager, exact active numbered
episode, room CAS version, command UUID, optional authorized Place/receipt and
explicit publication. It sets/clears only the usual relation and advances the room
version. `schedule_cocreate_meeting_v2` commits its optional Place/publication in
the same transaction as the installed atomic scheduler, attendance and recruitment.
A private child command and the outer immutable intent/receipt commit together.
Lost replies retry the same outer command, including after expiry/provider shutdown
or cancellation. Changed intent is rejected.

The installed scheduler and every admission/attendance command keep their signature
and behavior. Old clients schedule without Place fields. No mutable occurrence-place
or publication-edit workflow is added: cancel and deliberately schedule another
occurrence. Usual changes never move an already scheduled meeting. New private
tables have RLS defense in depth and no direct client/service grants. Commands keep
identity/profile → actor → canonical hub lock ordering.

## Search and activation

The existing `location-search` adapter, normalization, attribution, Italy restriction,
TTL, account fencing and shared meters are reused. Two exact scopes are added:

- `cocreate_hub`: item ID is the actor's **current General episode UUID**, revision
  `0`, before any numbered room exists.
- `cocreate_room`: item ID is the manager's **exact current numbered episode**,
  revision is the current room version.

Both accept only `slot=exact`. Reservation, delayed issuance, resolve and consumption
recheck account/policy/experiment/hub/episode/manager authority. Ended/replaced
episodes or changed versions cannot reuse selection authority. The existing
five-minute lifetime and budgets stay unchanged. Project/Tavolo/resource location
domains retain their contracts and contents. Existing service RPC OIDs/ACLs and
signatures stay unchanged; only scope dispatch/validation expands.

No activation, default or ceiling changes occur. Existing staging-only
`LOCATION_EDITOR_SEARCH_ENABLED`, Edge switches/secrets and server meters remain
required. Disabled/unconfigured search makes zero upstream requests; ordinary
scheduling remains usable without a Place. There is no new provider, client key,
provider URL, directory API, fallback or GPS prompt.

Mobile selections are volatile and expire. Expiry/revocation erases the label and
requires review or explicit “No place” confirmation before Save. The scheduling
editor retains its expiry clock when scrolled offscreen. Form dialogs pause late
adoption; account/policy/realm/hints/background erase protected state. Pending
commands keep their separately frozen intent. Explicit Refresh obtains a new scope
after structural conflicts without silently substituting a place.

## Reads and mobile navigation

`list_cocreate_places_v1` and `get_cocreate_place_detail_v1` require the actor's
current General episode. Lists use ascending Place UUID keysets; detail uses
ascending group numbers. Server limits are 1–50, mobile uses 25 and explicit
continuation. Every page rechecks authority. Counts include only authorized usual
and meeting associations, with at most the latest future meeting per group.

`list_discoverable_cocreate_places_v1` is the separate authenticated,
account/policy/experiment-gated projection for the next map phase: published
amenity UUIDs, normalized public-safe geometry/label, eligible usual-group and
upcoming-session counts, and viewer-authorized availability. It performs no
community admission. Later map discovery must use existing deliberate hub admission
before meeting admission. No combined map or external catalogue identity merge is added.

Calendar uses `get_cocreate_calendar_v2`; member review uses
`get_cocreate_current_meeting_v2`; recruitment review uses
`get_cocreate_recruitment_review_v2`. These add nullable Places to new contracts.
Installed v1 readers, nine/eleven-field cards, FIX01 six-field review, calendar
envelopes/rows and signed continuations remain unchanged.

Try community → **Places / Luoghi** when authorized content exists. Tap a venue
for its groups and upcoming available/full/attending/neutral sessions. Review
opens existing recruitment/attendance without an automatic command. Locationless
communities hide the entry. Routes are `/people/hubs/:hub/places` and its
`/:place` child. Group controls show usual and occurrence Places, plus manager-only
**Manage usual place** at the numbered episode route's `/place` child. Scheduling
offers no place, usual place, authorized existing Place or another verified choice.
Calendar/review links retain attribution and the explicit Google Maps destination
pattern. There is no map rectangle or new renderer.

## Validation and delivery

Existing Database CI's COMM01/FILL01 command includes Place HTTP and upgrade
verification, without a second runner job. Focused commands after canonical clean replay:

```text
npm run db:test -- supabase/tests/165_cocreate_places.test.sql
node scripts/verify-local-cocreate-places.mjs
node scripts/verify-local-cocreate-places-upgrade.mjs
```

Upgrade requires `PLANETS_DISPOSABLE_QA=1`; tools refuse non-loopback targets.
`MAILPIT_URL` selects an owned local OTP port. HTTP uses real OTP/Auth and client/
service REST; only Geoapify bytes are synthetic, through the actual handler and
normalizer. Synthetic meter/experiment settings are restored. Upgrade restores
actual pinned CAL01-FIX01-installed main scope bodies, warms installed readers and
cursor, applies actual forward source, compares populated rows and installed
OIDs/ACLs/results/receipts, and rolls everything back.

See [regression evidence and actual Flutter renders](evidence/cocreate-place01/README.md).
Physical Android/iOS, TalkBack/VoiceOver and real venue/provider quality are separate
claims. Source merge does not establish hosted migration eligibility/application.
This task performs no manual hosted apply, hosted experiment/provider activation,
Mock seeding, app installation or store publication.

The changed `location-search` bundle also remains outside the recorded release
source approval. Its reviewed deployment/source-approval workflow is still needed
before released clients can use the new search scopes. The actual policy and
validator are unchanged; unit fixtures do not grant that approval.
