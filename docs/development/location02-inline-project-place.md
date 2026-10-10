# LOCATION02: one-time Project place and directions

The Project editor uses one primary location input for mixed city/address/venue
search. `ProposalLocationEditor` owns the transient query; raw address text never
enters `ProposalInput`, similar-Project matching or public city fields. Typing
invalidates earlier results, receipts and retries. A deliberate inline result tap
resolves and applies a receipt after the ordinary draft save and authorized
revision read. No second search dialog or address field appears in directions.
Tavolo and Resource editors retain their existing flows.

The disabled/offline/manual path requires **Use as public city** confirmation.
It creates text only, with no geometry, geocoding claim or Maps destination.
Obvious address-shaped text (digits, street prefixes, newlines) is rejected by
the manual-city affordance; this is a conservative UI guard, not a geocoder.
An empty location remains valid in a sparse draft. Defined publication still
requires the existing city, schedule and other canonical requirements.

## Canonical selection and privacy

Migration `20261010131622_proposal_inline_location_privacy.sql` adds the
one-time-only `place` search slot and authenticated `apply_proposal_place_v1`.
Inputs are expected actor, item, revision, stable request UUID, action and an
optional opaque receipt. Actions are `replace`, `clear`, `public`, `participants`;
only `replace` accepts a receipt. Existing service issuance, expiry, session,
actor/item/revision binding, parent-first authority lock, idempotent retry,
quota, shared meter, cache and master/provider kill switches still apply.
Public/anonymous/service-role callers cannot invoke this mutation.

- A locality result supplies the independent broad public place/point and clears
  the exact selection. An address/venue supplies the protected exact point and
  **always starts with participants visibility**, including old exact-slot clients.
- Exact selection uses verified city/administrative components for public text.
  It retains a previously selected independent broad place only when city and
  administrative area match; otherwise Discovery has no point. Exact coordinates
  are never copied, rounded, blurred or used as a public Discovery point.
- The organizer switch applies a fresh revision-bound visibility mutation.
  Ordinary content saves preserve the current visibility and reject a different
  value for an existing verified place (`40001`, reload). A stale tab cannot
  publish a replacement selected after its earlier revision.
- Manual locality changes invalidate old verified exact selections server-side.
  Explicit exact removal retains separate arrival directions. Editing/clearing
  directions retains the independently selected point.
- Existing selections rehydrate with their actual stored visibility. This is an
  additive migration with no data backfill, blanket visibility rewrite or
  arrival-text deletion.

`proposal_meeting_details.exact_meeting_text` is now **arrival directions** for
one-time Projects. It is always participants/organizers only, including legacy
rows marked public. The existing participant and group-chat meeting readers
retain their structural authorization and nullable-direction contract. No
arrival text is added to public cards, map queries, invitation metadata or URLs.

For signature compatibility, `get_public_proposal.exact_meeting_text` now means
only the verified selected place **label** when deliberately public; it never
returns arrival directions. The unchanged MAP03 public-detail preview RPC
supplies a public exact point only when allowed. Mobile detail uses that existing
authorized panel; MAPDETAIL02 preview, tap and credit presentation files are
unchanged. Web SSR performs a fresh public-detail preview read before offering a
coordinate-based Google Maps link. A newer private/cleared/different selection
revokes the older label and URL. There is no persistent exact-detail web cache.

## Editor lifecycle and presentation

`LocationEditorSession` owns ordinary save, fresh revision, scoped search,
receipt mutation, idempotent retry and canonical reread. A write is not shown as
success until its canonical revision is read. Query and draft snapshots contain
no receipt or provider identifier. Actor/readiness changes, edits, expiry,
departure and backgrounding invalidate transient work. Confirmed unsaved manual
city text survives foreground rereads until its ordinary save acknowledgement.

Arrival directions use a neutral disclosure, collapsed for new content and
expanded when saved text exists. The exact-place switch and directions clearing
are independent. The short-description helper and skills/resources explanation
paragraphs are removed only from the Project editor. Existing controls, capacity
default/semantics and essential save-draft resource cue remain. Capacity has one
small localized reassurance. EN/IT strings and 320dp/large-text layouts are covered.

## Validation and staging handoff

Use the repository `check:mobile`, `check:web` and `check:db` gates. `check:db`
resets its selected environment: run only against an explicitly disposable task
stack, never the retained founder/demo stack. SQL fixture 126 and the authenticated
REST verifier cover anonymous/unrelated/pending/member/organizer access, revocation,
private defaults, public exact details without directions, stale revisions,
idempotent retries and simultaneous selection/visibility writes. Node provider
fixtures distinguish Trento in Trentino-Alto Adige from Trento in Veneto by
explicit province/region labels. Fixture provider success is not live Geoapify,
hosted staging or Android evidence.

Rendered evidence uses the real Flutter widgets, AppTheme, Roboto and Material
icons with synthetic data. Twenty-one captures cover EN/IT at 320dp and 1×/2×
text, selected private/public states, directions, inline province/region results,
the actual creation form and a 768dp dark variant. Representative captures:

- [Italian inline results](screenshots/location02/it-inline-results.png)
- [Public selected place with private directions](screenshots/location02/it-public-private-directions.png)
- [Italian private place at 2× text](screenshots/location02/it-2x-private.png)
- [Actual English form cleanup](screenshots/location02/en-form-cleanup.png)

Separate approval is required before staging synchronization:

1. Review and apply migration `20261010131622` after the existing staging history.
2. Redeploy `location-search` with the new one-time `place` slot and province/region
   normalization. Preserve its JWT configuration, existing secrets, flags and
   provider/account limits; no provider activation or billing change is needed.
3. Build/sign a new staging APK from the merged commit using the existing ignored
   staging configuration. Verify deployed schema/function parity before testing
   inline lookup, private/public selection and private directions on the visible
   emulator with an authorized account.

This implementation does not perform hosted changes, issue real provider traffic,
install on the Pixel, uninstall an app or upload to Play. See the existing
[activation runbook](map-live01-android-activation.md) and
[LOCATION01 contract](location01-defined-project-city-only.md) for prior setup.
