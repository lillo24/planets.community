# MAPFIX01 location display and release evidence

## Verified staging diagnosis, 2026-10-11

`planets-staging` (`cllpvruvrrvxczjitlqd`) has exactly one published one-time
Project named **Mappa test**, ID `ca208af9-bacd-4ae7-a107-dd79b9624a9e`, revision 7.
Its selected public place is a verified Geoapify locality: `Trento`, with public
area coordinates `46.0879835, 11.1098388`. The anonymous canonical
`get_location_preview_v1(public_detail)` returned HTTP 200, public/area, that
geometry and structured locality, plus the long province/region/country label.
This establishes public viewer access, not the connected account's exact view.
There is no evidence that this record needs editing or new coordinates.

The staging provider's database enabled/tiles/centers/cache-license switches are
true. Static preview generation remains disabled. `map-provider` is ACTIVE,
version 4, with JWT verification enabled. No configuration, quotas, records or
deployments were changed. An authenticated live tile/PNG/decode test remains
unverified without an authorized session/device.

Phone `48091FDAS0041A` was absent from `adb devices -l`; only an unrelated emulator
was connected. Installed package/version, signing certificate, source SHA and
compiled flags remain unknown. Do not infer them from Play's highest version code.
The owner reports that the current highest Play code is **6**. No matching code-6
artifact/build manifest is available locally. The locally prepared OST01 code-7
AAB at main `5d7a275` used the ordinary builder, with map flags disabled. The local
code-5 map-enabled artifact predates PR #213. Neither observation proves which
artifact is currently installed or distributed. MAPFIX01 reserves code **8** to
avoid reusing the already prepared code-7 artifact; recheck history before upload.

## Client corrections

- Project/Tavolo cards and area details prefer public structured locality. The
  preview DTO now preserves `place.locality`; delayed previews cannot replace
  `Trento` with the full provider label. Recognized Italian province/region
  suffixes offer a narrow legacy fallback. Unknown international/manual comma
  names remain intact. Authorized exact labels and coordinate destinations do
  not undergo city formatting.
- Tile transport and native PNG decode have a modest, noninteractive 48dp
  pending label. They never mount the text Maps fallback. A decoded canvas is
  the single Maps action; disabled or settled unavailable imagery can offer the
  text action only with a canonical destination. Static imagery remains separately
  disabled; failures never enable it.
- Existing public lease/entitlement/inactive retention and synchronous private
  revocation remain in force. Join-request availability is not a location content
  version. Geometry/location changes, account switches, real backgrounding and
  private entitlement loss still invalidate the appropriate content. Each Maps
  activation retains a fresh canonical read.

## Durable public-text provenance

Migration `20261011180000_location_text_provenance.sql` adds a private, RLS-enabled,
API-inaccessible table containing only item kind/ID, a fingerprint of current
public text, and `manual`/`geoapify`. It contains no actor, receipt, provider ID or
exact-place metadata. There is no legacy backfill. Public place selection and
retained provider text after geometry clear preserve provider origin. Ordinary
text edits and template copies cannot attest manual authorship.

The Project editor's explicit manual-city fallback keeps its existing content
save timing. After successful ordinary Save/Publish, a separate idempotent
`confirm_manual_proposal_location_text_v1` checks canonical identity, organizer
rights, revision, exact saved city/locality, no selected public/exact geometry and
the existing broad-city safeguards. It changes only provenance/revision, followed
by a canonical reread. An attestation failure is visible and keeps the editor open
for retry; already saved content is acknowledged. Cancellation revokes intent.
No receipt or raw autocomplete query enters this metadata.

Preview JSON adds `public_label` and `text_source`; authorized editor JSON adds
`public_text_source`. Older clients ignore the extra fields. New clients reading
older servers retain `unknown` and skip the unsupported attestation RPC, so
ordinary manual content saves still work. Durable suppression on staging requires
separate authorized deployment of this migration; MAPFIX01 does not deploy it.

Known manual text without provider/map content has no footer. Provider-derived
labels still carry linked credits when imagery is disabled/failed. Unknown legacy
text and older Tavolo/resource manual-save paths retain conservative credits.
Failed reads with no displayed location content do not create provider credits.
An authorized exact preview is classified only in its authorized projection; its
private provenance is not exported through public metadata.

## Attribution references

Official [Geoapify geocoding](https://www.geoapify.com/geocoding-api/),
[tile attribution](https://apidocs.geoapify.com/docs/maps/map-tiles/#attribution)
and [OSM copyright](https://www.openstreetmap.org/copyright) were rechecked on
2026-10-11. Stored/reused geocoding data keeps attribution obligations; Free
Geoapify maps require Geoapify and OSM credits. The configured `osm-carto` style
is explicitly exempt from additional OpenMapTiles attribution. No paid/white-label
entitlement was verified, so no paid-plan exemption is assumed. Shortening a
provider label does not erase its origin.

## Verification and owner handoff

The regressions cover EN/IT, narrow/large text, long/legacy/async labels, pending
tiles/native decode, disabled/failed imagery, attribution transitions, canonical
manual save/reread/reopen, authorization denial, revision races and retained
MAPDETAIL02/MAP-CACHE lifecycle/ownership guarantees. Database validation must use
the task's disposable loopback stack, never retained/shared staging data.

After green CI and merge, build from then-current main with the existing signed
map-enabled staging builder. Record artifact hash, source, version, certificate
and nonsecret flags outside Git. No upload, publication, phone installation,
uninstall or data clearing is authorized. For a Play-installed app, the owner
must update through the existing Closed testing route after Console review;
an upload-key-signed local APK may have a different certificate from Play signing.
Physical-device/live-provider verification remains separate from widget renders.
