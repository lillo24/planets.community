# Local demo data

PLANETS has two deliberately separate demo conveniences:

- **DEMO-A** is presentation-only Flutter tooling. It shows a DEMO marker and fills supported forms, but never submits or persists data.
- **DEMO-B** is this trusted local backend dataset. It authenticates synthetic users and calls the real Supabase RPC, RLS, Storage, outbox, notification, Messages, chat, and discovery paths. Flutter continues to use its normal repositories.

## Create or rebuild the world

Start the project-scoped local stack, then choose one command:

```text
npm run demo:seed:local
npm run demo:reset:local
```

`demo:seed:local` composes the original nine scenarios, PI05's four invitation activities and TW05's 18-source Workshop/matching inventory under seven synthetic personas. Eight core Completed templates remain publicly usable; dedicated fixtures own removal/cancellation/version QA. Repeated seeds preserve canonical IDs, receipts, Completed clocks/tokens and owner edits; only documented relative-time examples refresh. It does not reset unrelated developer rows. The [TW05 record](workshop-demo-validation.md) and [integration record](template-stack-integration.md) document inventory and evidence.

Older local worlds are adopted in place: an exact legacy `DEMO · ...` title owned by its expected demo identity is renamed to the realistic title before reconciliation. Ambiguous or duplicate matches fail loudly. This narrow trusted local SQL is necessary for already-frozen historical/closed rows and never searches by a broad prefix or changes other accounts' content. The closed legacy Resource example is temporarily restored to its prior published state only when it lacks the expected cover, repaired through the normal owner media API, and closed again without changing its ID.

The three original English chat fixture bodies are similarly matched exactly and rewritten in place to the Italian copy. This trusted local transaction temporarily suppresses the message-immutability trigger only for those exact rows so their message IDs and notification references remain stable; it does not change the production trigger or expose a client mutation path.

`demo:reset:local` is intentionally destructive to the local database: it runs the existing migration reset and then seeds the demo world. To return to a clean non-demo database, run `npm run db:reset` without the demo seed.

Both commands derive credentials from `supabase status` and refuse a non-local or non-loopback API, database, or Mailpit target. There is no staging command, remote reset, production mode, app-start hook, or public reset endpoint. Run the focused read/security check at any time with:

```text
npm run demo:verify:local
```

If Projects or Workshop appear empty, first identify the build's database and
clear browse filters; DEMO-A form helpers do not populate staging or the local
backend. The [UXFIX01 diagnosis](uxfix01-qa-copy.md) records safe endpoint/inventory
checks and Android host configuration. Do not reset or silently reseed the retained
phone-demo world to resolve an empty screen.

## Personas and useful flows

MSG01 reuses Marco and Giulia: Marco's mural request and one added pending request
to Giulia's existing monthly Tavolo yield one Private pair row, two distinct
request bubbles, a `2 richieste in attesa` banner, and two stable pair follow-ups.
The rejected repair and withdrawn weekly requests and PI05 superseded histories
remain intact. Seeding reuses source IDs and adds only missing pair messages;
verification never repairs. The demo snapshot covers pair anchors, associations,
authors, text and timestamps alongside the retained invitation/request history.

On a separate clean demo-only stack, use Marco's two requests → Giulia's one
conversation → resolve one → banner one → resolve the last → read-only → a new
legitimate request → the same history. Re-seed explicitly to restore the two
pending fixtures after interactive actions. Keep this presentation stack separate
from `check:db` mutation-verifier data and the founder's phone-demo services.

| Login email                  | Display name | Role in the world                                                                  |
| ---------------------------- | ------------ | ---------------------------------------------------------------------------------- |
| `demo-alice@planets.invalid` | Giulia       | Organizer: owns Proposals, Tavoli, a donation listing, and the mural chat          |
| `demo-bob@planets.invalid`   | Marco        | Requester: has pending, rejected, and withdrawn Messages plus an exchange listing  |
| `demo-carla@planets.invalid` | Sara         | Participant: accepted into the mural Project and active in its chat                |
| `demo-dario@planets.invalid` | Dario        | Photo-free participant in both invitation Projects; retained leave/removal history |
| `demo-elena@planets.invalid` | Elena        | Photo-free, otherwise ready, unjoined recipient for explicit interactive Join      |

All seven have complete synthetic basic profiles. Giulia, Marco and Sara retain their controlled skills and abstract initial avatars. Dario and Elena have no canonical profile-photo row; verification asserts absence. PLANETS — demo locale owns three synthetic starter examples; Revisore — demo locale is the only fixture staff identity. Both Workshop personas use abstract geometric avatars. Clearing a canonical photo does not promise removal of an earlier orphaned Storage object.

The realistic Italian scenario set is:

- Proposals: **Coloriamo insieme il muro del sottopasso**, **Repair Café: aggiustiamo piccoli oggetti insieme**, and the recently finished **Concerto acustico nel cortile**;
- Tavoli: **Idee per il quartiere — tavolo del mercoledì**, **Laboratorio aperto: legno e piccole riparazioni**, and the paused **Gruppo di lettura del sabato**;
- Scambio-Dona: **Regalo attrezzi da giardinaggio**, **Scambio due tavoli pieghevoli per aiuto con una mensola**, and the closed **Vassoi per piantine — già assegnati**.

The world retains restricted/public location examples, pending/accepted/rejected/withdrawn participation, projected in-app notifications, and a three-message Italian Project chat. Locations are safe synthetic rough/detail text around Trento; no stock-photo subject is described as a demo persona or real PLANETS participant.

## Participant invitation cases

The original nine examples remain intact. Four additional activities reuse existing licensed covers without adding stock subjects or assets:

| Activity                                                   | Purpose                                                                                                |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Proposal **Prepariamo insieme le cassette per l'orto**     | Active special admission; organizers excluded from capacity                                            |
| Proposal **Piccolo banco di riparazione — posti esauriti** | Full with one counted Creator; preview may be available but admission returns the canonical full error |
| Tavolo **Orto condiviso — idee e lavori del mese**         | Active special admission; organizers included in capacity                                              |
| Tavolo **Idee per il cortile — Tavolo concluso**           | Ended, unavailable                                                                                     |

Both active cases retain a replaced generation, a revoked generation and one current generation. Marco's pending ordinary request has skill/resource offers and a human request-chat message before direct admission withdraws it with `direct_participant_invitation`; the original request, offers, message and superseding membership relationship remain. Tavoli have no Proposal skill selections. No automatic membership commitments are created. Sara is also admitted; Creator and already-joined receipts consume no new slot. Dario has deliberate joined → left → joined → removed → joined episodes and can read/send Project chat without a photo. Elena stays unjoined and cannot read the private chat or meeting details.

The finished concert and paused reading group also receive links while joinable. Their existing historical/paused purpose stays intact. On an explicit TW05-to-integrated seed, the original concert may already have its historical cover but lack a PI05 generation: only that missing generation is prepared with its Upcoming fixture clock before restoring Just Finished. Existing generations and unchanged reruns never rewind it. Resuming the reading group makes the same unrevoked generation usable again. Ordinary public sharing uses the public detail with one `intent=join` marker and never admits by opening it.

Raw links are written only to ignored `.env.demo-participant-links.json`, keyed by generation ID and scoped to the loopback API. Keep that file private; normal command output contains no capabilities. Current links are obtained through the authenticated `get_current_project_participant_invitation` RPC, or the normal mobile organizer sharing sheet. Retrieving/resharing does not rotate. The PI05 loopback browser launch helper below consumes the ignored journal/current manager API without echoing a token. It is distinct from canonical `https://planets.community` URLs and proves no public hosting or OS association.

## Stability, verification and recovery

`demo:verify:local` authenticates only already-created demo identities and reads canonical state; it never creates/completes a profile, admits a member, rotates a link, sends a message or projects events to repair failure. It checks explicit photo state, generations/secret destruction, direct origins, Creator/existing outcomes, retained episodes, superseded offers/chat history, zero commitments, own membership/chat reads and public/RLS boundaries. Authentication creates local session/email state, which is separate from domain repair.

```text
npm run demo:check:local
```

This explicit **mutating** integration command seeds → verifies → seeds unchanged → verifies and compares canonical IDs and relationships for generations, receipts, memberships, requests/offers, messages, notifications and commitments. Relative refresh times and authentication sessions are excluded. On a clean stack it intentionally interrupts immediately after a committed admission, proves verify fails without domain repair, then recovers that stable action. It also checks full/ended/paused failures, same-generation resume, ordinary request/publication photo gates, ended receipt replay and fresh restoration. It creates/reuses one complete private Dario-owned publication-check draft; this is not another public demo scenario.

Each seed admission UUID is derived from Project, account, generation and deliberate episode purpose. Interrupted committed actions reuse their original receipts. After interactive leave/removal, an explicit seed creates a fresh action bound to the last ended episode; unchanged subsequent seeds preserve it. Old receipts never restore membership. Seeding and transition checks share an advisory lock and reject concurrent mutation.

Interactive changes are intentional drift: verification fails if Elena joined, a baseline generation was revoked/regenerated, or a required member departed. Seeding restores departed seeded members with retained history, but refuses extra/revoked baseline generations rather than silently erasing them. Use `demo:reset:local` only on a known disposable stack to rebuild deliberate baseline history; it resets the entire selected local database. A journal from another API is rejected and must be moved aside deliberately. Never reset a shared rehearsal stack.

`check:db` and hosted Database CI execute `demo:stack:check:local` **after** clean pgTAP, existing mutation verifiers and the unrestricted notification regression, before generated-type drift. It shares the lock/session pool across PI05's admission phase and TW05's Workshop phase; each standalone command remains usable. Dynamic public/private base-table digests include every current invitation and participation-pair table; the initial 5 October candidate covered 77 tables. Only starts/ends/updated clocks for exact original relative-time Proposals, the two PI05 relative-time Proposals and active Workshop fixtures are excluded; application destinations and Completed sources/copies retain full timestamps. The [PI05 record](../implementation/pi05-integration-qa-and-demo-data.md) and [integrated evidence](template-stack-integration.md) distinguish GUI, HTTP, gateway and native checks.

The combined world also retains MSG01's two distinct pending mural/monthly-Tavolo
requests, one writable Marco/Giulia pair and its two canonical human follow-ups.
Explicit seeding returns only those two exact message IDs to the scoped demo
worker; unrelated messages, even in that same pair, stay outside its inventory.
MSG01 events retain the canonical worker's unhandled behavior until MSG02; the
demo adds no chat alerts. Read-only verification never creates or sends messages.

## Workshop stability and non-repairing verification

`demo:verify:local` checks already-created identities and canonical state without product repair. `npm run demo:workshop:check:local` is explicitly mutating, bounded, and never resets: it proves committed-copy interruption/recovery, unchanged IDs/tokens/Bozza/needs/receipts/reports/removal/audit/outbox/notifications, and independent version copies. A coordinated advisory lock prevents half-built snapshots. Interactive baseline drift is reported; removed templates and owner-edited copies are never silently restored. Repeat destructive native journeys only with an explicit reset of a known disposable local stack. See the [TW05 record](workshop-demo-validation.md) for exclusions and later PI05 composition.

## Vendored media and lifecycle ordering

The seeder reads all images from `scripts/demo-assets`; runtime seeding and verification require no internet after checkout. The nine covers are normalized 1280×720 WebP copies of Pexels activity photos used under the Pexels license. Source pages, photographers, retrieval date, dimensions, byte sizes, and checksums are recorded in `scripts/demo-assets/assets.json` and explained in `scripts/demo-assets/README.md`. They are local demo fixtures, not user-uploaded production content.

Profiles are completed and receive canonical profile photos before any gated content is published. Covers follow the real authenticated Storage and canonical RPC boundary with deterministic immutable object paths and no upsert. A new historical Proposal receives its cover before publishing and controlled timestamp aging; a paused Tavolo receives its cover before publish/pause; a closed Resource receives its cover before publish/close. Replaced object cleanup is best-effort only after the database commit succeeds.

If an interrupted prior run left the intended deterministic object without its canonical database row, the next run reuses that exact immutable version path and lets the commit RPC revalidate owner, parent, and MIME metadata. It never overwrites bytes in place.

## Sign in and run the app

The seed command consumes its own local OTP messages without printing them. To switch personas in the app, enter one of the emails above, open Mailpit at `http://127.0.0.1:54324`, and paste the newest six-digit code.

```text
npm run restore
npm run db:start
npm run demo:reset:local
npm run mobile:config:local
npm run dev:mobile
```

For a physical Android device, keep the existing ADB reverse or reachable-host configuration described in [Getting started](getting-started.md); the demo dataset does not change networking.

## Trust and implementation history

Ordinary authenticated clients own domain and media mutations. The service role is used only by the existing notification projector. Direct local PostgreSQL is limited to the advisory lock, stable exact demo-owned lookup/migration, verification, and the controlled time/lifecycle repairs that canonical product APIs intentionally cannot express for frozen demo history. It never fabricates notification or chat rows and does not bypass publication gates.

The demo tooling originally landed on `main` after the 08B media branch diverged. DEMO-01 reconciled the established DEMO-B implementation from `main` into the cover-media stack instead of creating a second seeder, then adapted it to the newer profile-photo and cover contracts.

The stable registry could support a future staging runner, but no trusted staging-admin credential/configuration contract exists. Adding one requires an explicit separately named command, HTTPS target allow-listing, account-owner credentials, and non-production environment proof. Production remains an invalid target.

## UI-NEXT-02 own-draft inventory

Giulia (`demo-alice@planets.invalid`) owns four additional ordinary unpublished
drafts. Their broad synthetic location is Trento; none has an exact meeting place.

| Type     | Initial title                               |
| -------- | ------------------------------------------- |
| Project  | Bozza demo · Un pomeriggio per il quartiere |
| Tavolo   | Bozza demo · Tavolo di lettura              |
| Donate   | Bozza demo · Libri da donare                |
| Exchange | Bozza demo · Materiali da scambiare         |

Use the existing explicit mutating `demo:seed:local` on a selected disposable local
stack, then sign in as Giulia and open a discovery folder or `/drafts`. Toggle
any types together; clearing the last selected type shows all. The management
menu preserves published history/co-organizer access. A ready different persona
has a genuinely empty hub unless it saved its own drafts. Opening a draft uses
the ordinary editor, and publishing removes it after the affected source refresh.

`scripts/lib/demo-drafts.mjs` stores only opaque draft IDs/request IDs/pending kinds
in the host temp directory: `planets-demo-drafts-<sha256>.json`, where the hash
covers version, local API URL and Giulia's canonical profile ID. Worktrees on the
same host/API/account share it. No credentials, email, tokens, location or user
content is stored. Preserve this file when moving an existing database to another
host: locate the receipt whose hash matches that API/account and copy it to that
host's temp directory. It is a trusted local seeding receipt, not an application
cache or new database ownership model.

An initial pending receipt is saved before creation. Project retries use their
canonical creation request; Tavolo/Resource committed unknown outcomes recover
only an exact initial title under the same owner when exactly one row exists.
Known destinations may be renamed, edited or published: unchanged seeds retain
their IDs and content. Missing/lost receipts with existing matches, ambiguous
matches, missing known destinations, or unresolved pending operations fail
loudly and require local reconciliation; they never silently create replacements.
Inspect the indicated canonical owner's rows and recover the original opaque ID
into the matching receipt only after confirming that operation's outcome. Do not
erase a pending receipt or re-run creation after an unknown committed outcome.
A confirmed failed/rolled-back create with no row may have its pending entry
cleared explicitly on that disposable stack.

`demo:verify:local` only reads these destinations; `demo:check:local` proves
seed/verify/unchanged-seed/verify stability. The receipt is separate from the
participant-link journal and survives worktree cleanup. No app-start hook,
background publishing, fake login or remote seeding is introduced.
