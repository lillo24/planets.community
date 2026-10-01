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

`demo:seed:local` brings only the nine known scenarios owned by the three stable demo identities to their desired state. Repeated runs reuse canonical entity IDs, add only missing transitions/messages, refresh relative Proposal times, and let the notification projector consume pending supported local events. It does not reset unrelated developer rows.

Older local worlds are adopted in place: an exact legacy `DEMO · ...` title owned by its expected demo identity is renamed to the realistic title before reconciliation. Ambiguous or duplicate matches fail loudly. This narrow trusted local SQL is necessary for already-frozen historical/closed rows and never searches by a broad prefix or changes other accounts' content. The closed legacy Resource example is temporarily restored to its prior published state only when it lacks the expected cover, repaired through the normal owner media API, and closed again without changing its ID.

The three original English chat fixture bodies are similarly matched exactly and rewritten in place to the Italian copy. This trusted local transaction temporarily suppresses the message-immutability trigger only for those exact rows so their message IDs and notification references remain stable; it does not change the production trigger or expose a client mutation path.

`demo:reset:local` is intentionally destructive to the local database: it runs the existing migration reset and then seeds the demo world. To return to a clean non-demo database, run `npm run db:reset` without the demo seed.

Both commands derive credentials from `supabase status` and refuse a non-local or non-loopback API, database, or Mailpit target. There is no staging command, remote reset, production mode, app-start hook, or public reset endpoint. Run the focused read/security check at any time with:

```text
npm run demo:verify:local
```

## Personas and useful flows

| Login email                  | Display name | Role in the world                                                                 |
| ---------------------------- | ------------ | --------------------------------------------------------------------------------- |
| `demo-alice@planets.invalid` | Giulia       | Organizer: owns Proposals, Tavoli, a donation listing, and the mural chat         |
| `demo-bob@planets.invalid`   | Marco        | Requester: has pending, rejected, and withdrawn Messages plus an exchange listing |
| `demo-carla@planets.invalid` | Sara         | Participant: accepted into the mural Project and active in its chat               |

All three profiles are complete, synthetic, and use different skills from the controlled catalog. Their canonical profile photos are locally generated abstract initial avatars, not stock faces.

The realistic Italian scenario set is:

- Proposals: **Coloriamo insieme il muro del sottopasso**, **Repair Café: aggiustiamo piccoli oggetti insieme**, and the recently finished **Concerto acustico nel cortile**;
- Tavoli: **Idee per il quartiere — tavolo del mercoledì**, **Laboratorio aperto: legno e piccole riparazioni**, and the paused **Gruppo di lettura del sabato**;
- Scambio-Dona: **Regalo attrezzi da giardinaggio**, **Scambio due tavoli pieghevoli per aiuto con una mensola**, and the closed **Vassoi per piantine — già assegnati**.

The world retains restricted/public location examples, pending/accepted/rejected/withdrawn participation, projected in-app notifications, and a three-message Italian Project chat. Locations are safe synthetic rough/detail text around Trento; no stock-photo subject is described as a demo persona or real PLANETS participant.

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
