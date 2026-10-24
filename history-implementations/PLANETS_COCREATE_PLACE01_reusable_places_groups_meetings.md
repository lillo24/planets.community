# PLANETS — COCREATE-PLACE01: reusable places for groups and meetings

**Prepared:** 24 October 2026 (Europe/Rome).  
**Status:** Ready for implementation.  
**Repository:** `lillo24/planets.community`.  
**Current main inspected:** `4a1003c52bafa2a8369d0ee252a3d20da4e30b11`.  
**Predecessors:** CAL01 calendar #309 and CAL01-FIX01 #316 are merged.

## Assignment

Implement the second step of the Find People calendar/place/map direction:

1. Keep the existing community calendar and meeting/admission behavior.
2. Add reusable, explicit PLANETS **Places** that numbered groups can usually use and individual meetings can explicitly use.
3. Make a place tappable so an authorized user can see the relevant groups and upcoming sessions at that place, including actual meeting availability.
4. Prepare a clean canonical projection for the later shared-map integration.
5. Do **not** implement the combined map in this PR.

Start from current `main`, inspect current `AGENTS.md`, current co-creation/location/map code and any concurrent work before editing. The inspected SHA is evidence, not a required checkout target. Preserve later fixes.

The product intent comes from the founder discussion: a football field should be a meaningful object that can be opened to see the PLANETS groups/sessions using it; Valorant or another online/roaming community must remain fully usable with no location. The existing product design also treats map/location as a discovery dimension rather than a requirement for every community.

## Why this must be a separate Place model

Do **not** add one `location` field directly to a community/hub.

A named community such as “Calcetto” or “Valorant” is a topic/locality hub. It has no single owner who should be allowed to assign one permanent venue to everyone. Its numbered groups can meet at different places, and one group can hold a particular session somewhere other than its usual place.

The required relationships are therefore:

- **Place** — stable PLANETS-owned identity for a verified real-world venue.
- **Numbered group → usual Place** — optional, manager-owned preference.
- **Meeting → Place** — optional, occurrence-specific and authoritative for that meeting.
- **Community/hub → Places** — derived from its eligible groups/meetings; no direct permanent hub location in this phase.

A meeting place never changes chat membership or RSVP capacity. A group’s usual place never silently rewrites an already scheduled meeting.

## Existing foundation to reuse

Inspect the current repository rather than duplicating these systems:

### Co-creation

- `private.cocreate_hubs`, `private.cocreate_rooms` and numbered-group authority.
- `private.cocreate_meetings` and meeting attendance.
- `schedule_cocreate_meeting`, current meeting review, recruitment, calendar and the CAL01/FIX01 readers.
- Immutable command IDs/receipts, canonical hub locks, exact episode/history boundaries, blocking, moderation and experiment gates.
- Current rule: one future non-cancelled meeting per numbered group.
- Calendar availability is meeting occupancy, separate from persistent chat occupancy.

### Locations

- `private.valid_selected_place(jsonb)` and the existing normalized Geoapify/OpenStreetMap place contract.
- Current normalized selected places deliberately discard provider IDs and opaque provider JSON. Do not reintroduce those fields as a hidden identity dependency.
- Existing selected place kinds are `locality`, `address`, and `amenity`.
- Existing `location-search` Edge adapter, server-only provider key, receipts, budgets, actor fencing and attribution.
- Existing map/location UI components and Google Maps destination behavior where appropriate.
- Current location search/provider activation rules and budgets remain authoritative.

### Map/discovery

- Existing geographic discovery renderer, list/map state, clustering, basemap/cache/budget rules and attribution.
- External Activities/Sports already has its own public geometry and map integration. Do not merge external catalogue identity with the new PLANETS co-creation Place identity in this PR.
- The later combined map should consume a small typed co-creation place projection from this work rather than scraping mobile widgets or rebuilding place logic.

## 1. Canonical PLANETS Place identity

Add a canonical place entity with an app-owned UUID. Choose exact table/function names after inspecting repository conventions.

A place must contain only the minimal normalized provider-derived fields already admitted by the repository, sufficient for:

- user-facing venue label;
- locality/administrative area;
- exact public geometry;
- kind/precision;
- attribution/source licence;
- verification/provenance;
- deterministic server-side comparison/deduplication where safe.

### Identity rules

The current provider adapter intentionally strips `place_id`, OSM IDs, raw datasource JSON and other opaque provider identifiers. Keep that contract.

Therefore:

- PLANETS owns the durable place UUID.
- Creating/reusing a Place must consume a valid server-issued normalized place selection, not client-supplied labels/coordinates.
- It is acceptable to reuse an existing PLANETS Place when its admitted normalized snapshot matches exactly under a server-owned canonical fingerprint.
- **Never** infer that two records are the same venue merely because coordinates are near each other, labels are similar, or locality text matches.
- A later provider result that does not exactly match may create another Place. Do not add an unsafe fuzzy merge system in this phase.
- Existing Place rows remain stable if provider wording changes later; do not mutate historical identity merely because a future autocomplete result differs.
- No raw provider response, search text, provider key, user GPS, opening hours or unreviewed metadata is stored.

Use current Italy/provider restrictions unless a separate accepted location architecture change already exists on current main.

### Precision and public-safety rule

A reusable discovery Place is meant for a **venue**, not a private home.

For this phase:

- `amenity` is eligible for explicit Find People discovery.
- Exact `address` may be associated with an authorized group/meeting if the existing privacy model permits it, but must not automatically become globally/discovery-visible.
- `locality` is not a reusable exact venue; it may remain useful as broad context but must not masquerade as a football field/building.
- Manual text alone does not create a canonical Place or geometry.

If current repository evidence supports a safer equivalent distinction, use it and document it.

## 2. Group usual place

A numbered-group manager may optionally set or clear one **usual place**.

Semantics:

- This means “this group usually meets here.”
- It is not a reservation, exclusive venue claim, live-presence indicator or guarantee for the next meeting.
- Only the current active group manager has structural authority to change it.
- Changing it does not alter any existing meeting.
- Removing it does not delete the Place or other groups’ associations.
- Leaving/archiving/suppression follows existing room lifecycle rules; stale associations must not remain discoverable through an archived/suppressed group.

Use canonical command IDs/receipts and existing hub/group lock ordering. Do not add an unprotected direct table write.

### Optional discovery publication

The manager can explicitly opt the usual-place association into **Find People discovery**. Default must be conservative/off for newly added data unless existing product policy on current main clearly says otherwise.

Discovery publication:

- is allowed only for a provider-verified public venue suitable under the precision rule above;
- exposes only the minimal group/community summary needed for discovery;
- never exposes chat text, member list, manager identity, private history or attendance roster;
- can be turned off without deleting the underlying authorized group/place relation.

Do not invent a hub-wide “community location” setting. A community may later appear at one or several places because eligible groups use them.

## 3. Meeting place

A future meeting may optionally reference one Place.

The meeting Place is the occurrence-specific truth. If it differs from the group’s usual Place, show the meeting Place for that occurrence.

### Scheduling

Prefer an atomic scheduling contract for the new client:

- preserve the installed `schedule_cocreate_meeting(...)` signature for older clients;
- add a versioned scheduling path if necessary for an optional Place/reference;
- preserve the existing immutable intent/retry semantics;
- if the meeting is created and recruitment is published in one transaction today, the selected meeting Place should be committed in that same successful transaction when practical.

The scheduling UI should allow:

- **No place / online / decide later** without blocking meeting creation;
- **Use usual place** when the group has one;
- **Choose another verified place** through the existing server-side place-search infrastructure.

For the “create a new numbered group while scheduling” path, design the location-search scope carefully: there is no existing numbered room before the command. Reuse an existing authorized hub/actor scope or another server-owned pre-command scope; do not fabricate a room ID or make client coordinates authoritative.

If the current search receipt architecture makes atomic pre-schedule selection unsafe, implement the smallest safe alternative and explain it, but do not publish a discoverable session whose Place is only partially committed.

### Mutability

Preserve the current meeting model’s expectation that scheduled occurrence data is stable. The default design for this phase is:

- meeting Place is fixed once the meeting is successfully scheduled;
- changing it requires the same deliberate cancellation/rescheduling behavior as other immutable occurrence details rather than silently moving attendees.

Do not introduce a mutable meeting-place workflow, push-notification system or rescheduling state machine unless current repository contracts already provide it.

### Discovery publication

Meeting discovery must be explicit and independent from the group’s usual-place publication.

A scheduled meeting can be marked discoverable only when:

- its Place is a discovery-safe public venue;
- the manager explicitly selected the discovery option;
- the meeting/recruitment lifecycle is currently eligible.

A discoverable meeting must stop appearing in discovery when cancelled, past, recruitment is no longer valid for newcomers, the group/hub is suppressed/archived, or other canonical availability rules revoke it.

Do not infer discovery from “has coordinates.”

## 4. Place read models

Add bounded, canonical projections that support both current UI and the later map without leaking protected data.

### Community-scoped places

On a named community page, allow an authorized current hub member to open a **Places / Luoghi** section that aggregates distinct Places used by eligible numbered groups or upcoming meetings in that hub.

For each Place, show only useful counts/status derived from authorized rows, for example:

- venue label/locality;
- number of eligible groups using it as usual place;
- number of upcoming eligible meetings;
- whether at least one meeting currently has places available.

Do not leak hidden groups/meetings through aggregate counts.

### Place detail

Tapping a Place opens a detail screen listing the eligible PLANETS groups and upcoming meetings associated with it.

For each upcoming meeting show the existing calendar concepts:

- community/topic;
- group number/name if already supported;
- local date/time;
- meeting occupancy;
- available/full/already attending/unavailable state;
- the action the viewer is currently authorized to take.

Reuse the canonical calendar/recruitment/attendance rules rather than inventing a second join policy.

If the viewer is already admitted to the relevant community, an eligible session can open its existing recruitment/attendance review.

If later discovery exposes a Place before community admission, the viewer must use the existing deliberate community admission path before meeting admission. A Place tap must never silently join a hub, numbered group or meeting.

### Cross-community discovery projection

Prepare a separate minimal, bounded **discoverable Places** read suitable for the next map phase. It may aggregate explicit discovery-published group/meeting associations across hubs.

Do not add the map UI yet.

The projection must:

- include only explicitly discovery-published, currently eligible associations;
- return a stable Place UUID plus public-safe geometry/label and minimal typed summary;
- support deterministic pagination and current lifecycle filtering;
- expose no roster, chat, manager identity, private meeting history or hidden counts;
- fail closed on experiment/account/policy boundaries as appropriate for Find People.

The map phase should be able to consume this projection directly.

## 5. Mobile UX

Keep this compact and consistent with the existing Find People visual system.

### Numbered group page

Add a small **Place / Luogo** section:

- usual place, if set;
- next meeting place, if set;
- manager actions to set/clear usual place;
- manager discovery toggle only where permitted;
- schedule flow can use the usual place or another place.

Avoid long privacy/debug explanations in normal UI. Use short helper text only where the distinction between “usual place” and “this meeting” could be confusing.

### Calendar and meeting review

Where an authorized meeting has a Place:

- show the venue label under date/time;
- make it tappable to the Place detail;
- preserve availability/attendance status;
- use existing attribution and Maps action patterns where provider-derived content is shown.

Do not add a map rectangle to the calendar in this phase.

### Community page

Add an obvious but compact **Places / Luoghi** entry near Calendar/groups when there is relevant content. An empty online/locationless community must not look broken or demand a Place.

### Accessibility and localization

Cover EN/IT, 320/360dp, 2× text, light/dark where layout is affected. Place rows and discovery/publication controls must have meaningful semantics and not rely on marker color.

## 6. Location-search integration

Reuse the existing server-only search adapter, provider normalization, receipt issuance, budgets, account fencing and attribution.

Extend it only as much as required for co-creation Place selection.

Constraints:

- no provider key in Flutter or public config;
- no direct client Geoapify URL;
- no new provider, Places-directory API, Nominatim/public OSM fallback or GPS prompt;
- no quota/budget increase;
- no automatic provider activation;
- selection receipts remain bounded/expiring and server-owned;
- stale actor/hub/room/meeting authority rejects selection;
- late provider responses cannot cross account/realm/target changes;
- reusing an existing PLANETS Place should require no provider request.

If location search is disabled/unconfigured, all existing co-creation scheduling/group functionality must remain usable without a Place.

## 7. Availability and counts

“Free to join” must mean the actual meeting admission state, not:

- group chat capacity alone;
- usual-place association;
- number of groups at the venue;
- map marker count.

Reuse the corrected CAL01/FIX01 server eligibility.

A Place detail can show:

- **Places available** only when the viewer can currently use the canonical meeting joining/confirmation path;
- **Full** for actual meeting capacity;
- **You're attending** for an attendee;
- neutral wording when the meeting has capacity but the current viewer cannot use newcomer admission.

Do not infer attendance from being in the persistent chat.

## 8. Migration and compatibility discipline

Use additive forward migrations only.

Preserve all installed CAL01/FIX01 and recruitment DTO/signature contracts. New Place fields/readers should be new/versioned contracts where needed.

The populated-upgrade rehearsal must start from current main with CAL01-FIX01 installed and prove:

- existing hubs, rooms, meetings, attendance and recruitment are unchanged;
- existing calendar/recruitment readers retain OIDs/ACLs/results where not intentionally versioned;
- null Place associations preserve old behavior exactly;
- old clients can continue scheduling/recruiting without Place fields;
- exact retry receipts remain valid;
- new place-search/selection paths do not mutate unrelated location domains.

Do not edit prior applied migration files.

## 9. Validation

Use the smallest complete affected validation set.

Expected coverage includes:

### Database / real HTTP

- create/reuse canonical Place from an actual server-issued normalized selection;
- exact-snapshot deduplication and no proximity/label fuzzy merge;
- group manager sets/clears usual place; ordinary member/outsider denied;
- no place remains fully valid;
- schedule with no place;
- schedule using usual place;
- schedule with another verified place;
- same Place used by two groups;
- one group with a meeting at a different Place from its usual Place;
- explicit discovery off/on;
- address/private precision cannot accidentally enter discovery;
- cancellation/past/retracted/suppressed/archived lifecycle removes discovery;
- block/access/episode/history rules do not leak groups or meetings;
- Place reads change no transcript ACK/unread state;
- last-seat race still cannot overbook;
- command retry/reply loss does not duplicate Place/meeting/group associations;
- stale/expired location receipt and actor/target replacement denied;
- provider disabled yields zero provider attempts and does not block ordinary scheduling.

### Mobile

- locationless Valorant-style community;
- group with usual football field;
- next meeting using usual field;
- next meeting using a different field;
- community Places list;
- Place detail with two groups and mixed available/full sessions;
- already-attending session;
- manager discovery toggle;
- search disabled/unconfigured;
- pending command recovery;
- account/realm/policy/lifecycle fencing;
- EN/IT, small width, 2× text and semantics.

### Map regression

Run the affected native/external geographic discovery tests to prove this work does not fork or weaken the existing map/cache/provider system. The actual combined map is not an acceptance criterion here.

## 10. Documentation and evidence

Update the closest co-creation and location runbooks.

Document clearly:

- Place vs community vs numbered group vs meeting;
- usual place vs occurrence place;
- explicit discovery publication;
- privacy/precision restrictions;
- stable PLANETS Place identity and exact-snapshot deduplication;
- provider/budget/activation state;
- which projections are intended for the later map.

Capture a small set of actual Flutter renders:

- group usual place;
- meeting place;
- locationless group;
- Place detail with two groups / mixed availability;
- discovery toggle;
- IT 2× text.

Label synthetic/widget evidence honestly. Physical Android/iOS, TalkBack/VoiceOver and live provider traffic remain separate claims.

## 11. Delivery

Use one focused implementation branch/PR.

Follow current `AGENTS.md` and current validation/staging policy. Merge automatically when current required source checks pass and no substantive product/security conflict remains.

Source merge and hosted migration eligibility/application remain separate. Do not repeat obsolete per-migration approval workflows. If the current independent release policy reports `review-required-for-hosted`, preserve that hold and report the exact unsupported effect; do not weaken the gate.

Do not perform:

- manual hosted migration application outside the authorized release workflow;
- experiment activation;
- provider/budget activation;
- Mock seeding;
- app installation/store publication;
- combined map implementation.

Final handoff must report:

- PR/final commit/merge status;
- Place data model and identity rules;
- group/meeting association behavior;
- discovery visibility behavior;
- mobile routes and where to try them;
- database/HTTP/mobile validation actually run;
- populated-upgrade/installed-client compatibility;
- source merge vs hosted migration eligibility/application vs experiment/provider activation vs installed app state.

## Next step after PLACE01

The following prompt should implement the requested clean discovery surface:

- compact rectangular map above the result list;
- co-creation Places/communities/sessions from PLACE01;
- Activities/Sports external items from the existing external catalogue;
- typed pins/layers/filters without identity-merging unrelated domains;
- selecting a football field opens its PLANETS groups/upcoming sessions and availability;
- locationless communities remain discoverable in the list;
- reuse the existing renderer, clustering, `Search this area`, cache/budget and attribution rules.