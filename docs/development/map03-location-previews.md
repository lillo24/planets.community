# MAP03 location previews and Google Maps

Proposal, Tavolo and Scambio/Dona cards now have a separate Maps tap region;
the remainder opens PLANETS detail. Details share the same read-only panel.
The default build says that map imagery is unavailable and retains readable
location text and a deliberate Maps action. No GPS, tracking, Google SDK/key,
silent geocoding or MAP04/05 discovery is introduced.

## Canonical precision and permissions

get_location_preview_v1(kind,item,view,expected_profile_id) wraps MAP01 public
and protected reads. Project/Tavolo card view always uses the independent
public locality, even when exact meeting visibility is public. Missing public
area is never inferred from an exact point. Resource cards may use their
public address/venue. public_detail permits explicitly public exact Project
geometry. protected_detail requires the current expected identity and existing
effective creator/delegate/current-member entitlement. A denied signed-in read
falls back to a fresh public read; transport failures stay failures. Terminal
availability follows the existing MAP01 canonical domain rules.

The dedicated read projection has item kind/ID, revision, area/exact scope,
public/protected audience, sanitized place kind/label/locality/country/coordinates,
structured public legacy locality/country and a fixed-render SHA256 image key.
It excludes instructions, provider IDs, queries, receipts and provenance.
get_public_location_previews_v1 accepts at most 50 kind/ID pairs, deduplicates and
derives only card projections. Existing browse/detail DTO allowlists and raw
table grants are unchanged. Reads are anon/authenticated only; service_role
cannot impersonate a protected reader. Private configuration/meters/images
have RLS and no Data API grants.

Manual records never become verified points. Canonical city plus two-letter
country can form an encoded city search; missing, ambiguous or address-like
inputs form no invented destination. Every Maps tap performs a fresh canonical
read. Localities open Google's /maps/@ with api=1, map_action=map, center and
zoom=10, without markers/directions. Exact points use /maps/search/ with api=1
and query=lat,lon. Instructions, JWTs, labels and secrets are excluded. Universal
HTTPS URLs use external application launch with platform/browser fallback and
localized failure feedback.
The fresh tap also replaces the panel projection and cancels older in-flight
reads/images when revision or public/protected audience changed. A late image
cannot restore exact access after the tap observed a public fallback or denial.
[Google Maps URL contract](https://developers.google.com/maps/documentation/urls/get-started).

## Client ownership and invalidation

The location_preview domain model never enters MAP02 editor snapshots, DRAFT01
or templates. location_preview_gateway owns canonical reads, the disabled
static transport and launcher. public_preview_batch groups visible cards within
16 ms, chunks at 50, deduplicates pending reads and keeps at most 100 public
projections for 15 seconds. Public locality bitmaps have a separate 32-entry,
one-minute RAM cache with in-flight deduplication. Exact/protected images do
not enter this shared cache.

location_preview_panel checks the clipped viewport, current route, TickerMode
and foreground before fetching. Offscreen, route, actor/readiness, ABA,
membership, role, meeting-details and content changes revoke pending work,
coordinates and images. Generations prevent old reads from refilling cleared
caches. Late protected byte buffers are overwritten. Decoded images are
widget-owned and disposed through RawImage, outside Flutter's global ImageCache.
Revocation disposes the decoded bitmap and invalidates pending decode immediately,
even if the backgrounded app cannot schedule another UI frame.
A visible panel reauthorizes every 15 seconds, hiding geometry/bitmap during
the read and reusing its bitmap only after matching key AND revision.
Known revocation clears immediately; remote changes without a client signal
are observed at that lease or the mandatory fresh tap. OS screenshot/recents
protection is not established by these component tests.

## Disabled static transport and budgets

Production registers DisabledStaticPreviewGateway. The server endpoint
supabase/functions/location-preview requires LOCATION_PREVIEW_ENABLED=true
and the server-only GEOAPIFY_STATIC_MAPS_KEY. Its .env.example is false/empty.
Database enabled and cache_license_approved default false; both credit limits
default zero. Nothing was configured, deployed or contacted live.

Requests contain only kind/ID, view, expected actor, revision and image key.
Coordinates, URLs, style/zoom/options are rejected. Public reads use anonymous
authorization; protected reads verify Auth and use the user's bearer token.
A separate service credential invokes only credit/cache RPCs. Canonical
authorization/revision is reread after provider/cache I/O before returning bytes.
No permanent public image URL or protected shared cache exists.

An optional image/quota/decoding failure keeps a successfully authorized place
label and reports unavailable imagery. Image transport denial or stale
authorization erases the projection; it cannot masquerade as a quota fallback.

Fixed upstream: https://maps.geoapify.com/v1/staticmap; osm-carto; 512x256 PNG;
scaleFactor 1; pitch/bearing 0; default embedded attribution. Area zoom 10 has
no marker. Exact zoom 16 has one circle marker without an icon lookup.
Redirects are forbidden; provider timeout four seconds, Auth/RPC timeout two
seconds, client invoke seven seconds. Upstream MIME must be image/png.
Streaming is bounded to 512 KiB; PNG signature, 512x256 IHDR and IEND are checked.
Resolved functions_client 2.7.1 decodes image/png as UTF-8, so the validated PNG
is returned as application/octet-stream with no-store/nosniff, then revalidated
and decoded by the client. This is deliberate binary transport compatibility.

[Static credits](https://apidocs.geoapify.com/docs/maps/static/) are request +
included tiles/4 + markers. Fixed unrotated 512x256 raster geometry covers at
most 3x2 tiles: 1 + 6/4 + one marker = 3.5, rounded up to FOUR reserved credits.
Areas also reserve four conservatively. Failures are not refunded. Changing
dimensions/style/options requires recalculating the bound and versioning the key.

reserve_location_preview_v1 and finish_location_preview_v1 are service-only.
Rendering locks autocomplete config, then preview config; search reservations
use that same first lock. MAP01 search gains only the shared ceiling guard.
Owner-selected daily_credit_limit/account_daily_credit_limit range 0..2000;
new rendering costs four, new autocomplete costs one. Missing, zero or disabled
meters fail closed. Rates: 60 global and 12 per actor/shared anonymous bucket
per minute, including cache hits. Each actor/shared anonymous bucket gets at
most 80 new-render credits/day. Both daily ceilings apply before generation.
Provider soft quotas are not a spending control.

Only canonically public locality images may be stored in the private image
table after licensing approval. Keys hash geometry/scope/style/dimensions/options
version, excluding labels/instructions/actors. Every delivery checks current
canonical item revision/visibility. Ready/pending/failed claims deduplicate until
UTC day end. At most 500 generations fit under the 2000-credit ceiling, each
bounded to 512 KiB. Exact public Resource and protected images never persist
server-side. There is no bulk generation job.

## Attribution and owner activation

Linked Geoapify/OpenStreetMap credits appear in editor/manual/clear states,
all three mobile card types, shared Project/Tavolo and Resource details,
legacy ProposalLocation, Web Proposal/Tavolo cards and SSR detail pages.
osm-carto retains embedded credits and does not need OpenMapTiles attribution
according to [style documentation](https://apidocs.geoapify.com/docs/maps/).
Text credits survive clearing geometry because derived labels may remain.

Template Workshop models/renderers and reusable-content allowlists contain
no location labels/geography, so no copied location is displayed there.
Applied templates use the normal credited editor. No template geography or
private provenance was added. SSR/share metadata keeps its public allowlist;
canonical detail pages supply visible credits.

Before real activation the owner must:

1. Approve commercial/free-tier use, derived text/image retention, public
   locality caching and attribution against current
   [terms](https://www.geoapify.com/terms-and-conditions/),
   [cache guidance](https://www.geoapify.com/static-maps-api/) and
   [pricing](https://www.geoapify.com/pricing-details/).
2. Approve map/privacy disclosure through POLICY01: rendering sends authorized
   coordinates to Geoapify; a deliberate Maps tap sends the authorized point
   or public city/country to Google. This change publishes no policy approval.
3. Provision a restricted server static-map key and an account-wide ceiling
   including autocomplete, rendering and headroom for other account consumers.
   This application's meter cannot govern other applications' use.
4. Explicitly deploy/serve with the appropriate anonymous gateway setting.
   Local command: supabase functions serve location-preview --no-verify-jwt.
   Protected requests still verify Auth and perform user-bound reads; never
   substitute service-role authorization.
5. Deliberately enable database licensing/budgets, runtime and client injection
   of ServerStaticPreviewGateway(client, enabled:true). Keep defaults off until
   approved live Android/iOS MIME, timeout, credits, app/browser Maps and
   revocation/privacy QA passes.

## Reproduction and evidence

This task's disposable stack is planets-map03-qa, API/database 55621/55622,
Mailpit 55624. Worktree configuration is temporary. The retained
planets-community 54321/54322 and physical phone are untouched.

Run npm run check:mobile, npm run check:web, and npm run check:db with
PLANETS_DISPOSABLE_QA=1 and the disposable MAILPIT_URL. location:verify:local
now includes 64 MAP01/02/03 authenticated REST/concurrency checks, real canonical
reads and deterministic Edge Auth/provider fakes with binary cache delivery.
Tooling covers strict input, permission rechecks, MIME/bytes/errors and disabled
zero calls. SQL adds preview roles/batches/meters to MAP01 receipt regression.
Mobile covers URLs, actual card taps, EN/IT at 320px/2x, offscreen/deduplication,
images, readiness/ABA/lifecycle and fresh launch denial. Web verifies DOM/SSR
fixed credit links.

Native debug opt-in command:
flutter run -d emulator-5580 -t test_support/map03_rehearsal.dart --dart-define=MAP03_REHEARSAL=true
Then dart run test_support/map03_native_smoke.dart <owned-vm-uri> <capture-directory>.
It uses actual cards/shared detail panels and deterministic Maps/image gateways.
The driver first proves zero disabled image calls, then explicitly enables the
fake renderer and captures decoded PNG presentation. MAP03_FAKE_IMAGES=true
can also start the harness directly in image mode.
This is not live Geoapify output, native Google dispatch, iOS, physical-device
privacy or owner policy approval evidence. Final gate counts are recorded in PR.

MAP04 may stack on the implemented head; MAP05 remains deferred. Neither new
geographic discovery nor a live key is required for this disabled Maps-link path.
