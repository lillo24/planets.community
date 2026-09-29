# PLANETS DEMO-01 — Realistic Local Demo World + Licensed Cover Assets

**Task type:** Demo/presentation tooling refinement, not a production feature  
**Repository:** `lillo24/planets.community`  
**Required base at prompt creation:** PR #112 head `35277413f84ba8110fee1ec1f9953692aae1d7bb` (`codex/08b2b-resource-cover-mobile-ux`)  
**Preferred branch:** `codex/demo-realistic-world-covers`  
**Do not merge the implementation PR.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_DEMO-01_realistic_demo_world_covers.md
```

---

## 0. Objective

Turn the local PLANETS demo dataset from obvious technical fixture data into a small, coherent, realistic-looking Trento community.

The current demo concept is good functionally, but presentation is poor:

```text
Demo Alice
DEMO · Riverside mural
DEMO · Weekly community table
DEMO · Community garden tools
```

and the newer cover-image UI has no demo covers.

After DEMO-01:

- the existing local demo world still exercises the same important domain states;
- names, titles, descriptions, rough locations, and chat copy read like plausible user-generated Italian content;
- published Proposal, Tavolo, and Scambio-Dona cards have realistic cover photography;
- owner-history examples also have covers where useful;
- demo identities satisfy the current profile-photo trust gates;
- demo runs remain deterministic, local-only, rerunnable, and safe;
- cover photos are vendored into the repository as normalized WebP assets;
- runtime demo seeding never fetches images from the internet;
- photo sources/licenses are recorded in the repository.

This is not a redesign of production content or a new public fixture system.

---

## 1. Critical branch divergence: reconcile DEMO-B, do not recreate it

The current 08B media stack and current `main` diverged after commit:

```text
fe3cd28cec066ff262da049f15f58dd53b3fa6aa
```

The required base for this task is the media stack:

```text
PR #112
codex/08b2b-resource-cover-mobile-ux
35277413f84ba8110fee1ec1f9953692aae1d7bb
```

That stack contains the latest profile-photo gates and Proposal/Tavolo/Resource cover infrastructure, but it does **not** contain the newer deterministic DEMO-B tooling currently merged on `main`.

Current `main` contains:

```text
a78e0e09dc4f459ccd44f78b0168164b9146fcfa
feat(demo): seed deterministic local world

06e983bb230a7a48514095fe407250ad6d38c148
merge of DEMO-B
```

DEMO-B includes the established implementation around:

```text
scripts/lib/demo-world.mjs
scripts/lib/demo-world.test.mjs
scripts/seed-local-demo-world.mjs
scripts/verify-local-demo-world.mjs
docs/development/demo-data.md
package.json demo commands
```

### Required reconciliation approach

Start from PR #112.

Then bring the **DEMO-B functionality** from current `main` into this branch semantically.

Preferred approach:

- cherry-pick `a78e0e09dc4f459ccd44f78b0168164b9146fcfa` if it applies cleanly;
- otherwise port that commit's DEMO-B files/changes manually and resolve them against the current stack.

Do **not** merge `main` wholesale.

Do **not** pull unrelated DEMO-A/mobile-config changes merely because they are nearby on main.

The point is to preserve the existing deterministic DEMO-B implementation rather than inventing another demo seeder.

After reconciliation, adapt DEMO-B to the newer 08A/08B contracts described below.

---

## 2. Current DEMO-B behavior to preserve

The merged DEMO-B design on current `main` already provides:

```text
npm run demo:seed:local
npm run demo:reset:local
npm run demo:verify:local
```

It:

- authenticates three synthetic users through the real local OTP flow;
- uses normal canonical RPCs for application behavior;
- refuses staging/production/non-loopback targets;
- uses an advisory lock;
- is rerunnable/idempotent for its owned scenarios;
- creates Proposals, Tavoli, Resource listings, participation states, notifications, and Project chat;
- verifies public/private boundaries;
- does not run automatically on app startup;
- does not expose a public reset endpoint;
- does not print OTPs/tokens/secrets.

Preserve these properties.

Do not replace DEMO-B with raw SQL fixture insertion.

Trusted direct local PostgreSQL should remain limited to narrow demo-owned lookup/migration/verification tasks where canonical product RPCs cannot express demo maintenance.

---

## 3. Current DEMO-B topology to keep

Keep approximately the same world and state coverage rather than expanding scope:

### Personas

Three stable demo login identities:

```text
demo-alice@planets.invalid
demo-bob@planets.invalid
demo-carla@planets.invalid
```

Internal keys `alice`, `bob`, `carla` may remain for compatibility.

### Proposal scenarios

Keep three:

1. upcoming, participant-restricted exact location;
2. upcoming, public exact location;
3. recently finished / historical example.

### Tavoli

Keep three:

1. active weekly;
2. active monthly;
3. paused owner-history example.

### Scambio-Dona

Keep three:

1. published Dona;
2. published Scambia;
3. closed owner-history example.

### Participation/chat

Preserve the existing useful states:

- pending join request;
- current accepted participant;
- rejected request;
- withdrawn request;
- real projected notifications;
- Project chat history.

Do not remove these merely for presentation polish.

---

## 4. Realistic persona presentation

Keep the stable emails, but stop displaying technical persona names.

Use plausible first names only, for example:

```text
alice → Giulia
bob   → Marco
carla → Sara
```

Use short, natural Italian bios.

Suggested direction:

### Giulia

```text
Mi piace trasformare idee di quartiere in progetti semplici da fare insieme.
```

Skills remain oriented around:

```text
organizzazione eventi
facilitazione
murales
```

### Marco

```text
Mi piace aggiustare cose, lavorare con il legno e dare una mano nei progetti pratici.
```

### Sara

```text
Fotografia, musica e attività creative: soprattutto quando diventano occasioni per conoscere persone.
```

Do not use full fake surnames unless they add value.

Keep the identities explicitly synthetic in developer documentation.

---

## 5. Profile-photo gates must work

The current 08A stack requires canonical profile photos for relevant Proposal/Tavolo/Scambio-Dona publication flows.

The old main DEMO-B predates these gates.

Therefore DEMO-01 must ensure each demo persona has a canonical profile photo **before** any gated publication/request action that requires it.

Reuse the existing local profile-photo fixture boundary where appropriate:

```text
scripts/lib/local-profile-photo.mjs
ensureLocalProfilePhoto(...)
```

Do not bypass the trust gate with service-role mutations.

### Presentation quality

The existing tiny verifier WebP is valid for tests but is visually poor as a demo avatar.

For DEMO-01, add three small, clearly synthetic/local avatar fixtures if practical.

Requirements:

- 512×512 WebP;
- under the current profile-photo hard limit;
- no identifiable real stock person's face;
- no implication that a stock model is "Giulia", "Marco", or "Sara";
- simple abstract/illustrated/initial-based avatars are acceptable;
- commit the bytes into a demo-assets directory;
- seed them through the real Storage + canonical profile-photo RPC flow.

Do not download stock portrait headshots for fake user identities.

If implementation cost becomes disproportionate, use the existing safe local profile-photo fixture and report the visual limitation, but the cover-photo work below remains required.

---

## 6. Realistic content copy

Replace the technical fixture titles with plausible Italian user-generated content.

Use the following as the target direction.

### Proposals

#### Mural

Title:

```text
Coloriamo insieme il muro del sottopasso
```

Summary:

```text
Un pomeriggio per ridare colore al sottopasso con un murale progettato insieme.
```

Description should sound like a real organizer:

```text
Partiamo da una bozza semplice, prepariamo il muro e poi dipingiamo insieme.
Non serve essere illustratori: servono anche mani per nastro, colori, pulizia e foto.
```

Keep mural/organization skill semantics.

#### Repair Café

Title:

```text
Repair Café: aggiustiamo piccoli oggetti insieme
```

Summary:

```text
Porta un piccolo oggetto da riparare oppure vieni a dare una mano al banco.
```

Description should mention realistic small repairs without promising professional repair service.

Keep repair/woodworking skills.

#### Recently finished concert

Title:

```text
Concerto acustico nel cortile
```

Summary:

```text
Un piccolo concerto di quartiere con strumenti acustici e qualche sedia portata da casa.
```

Keep musician/audio skill semantics.

### Tavoli

#### Weekly community table

Title:

```text
Idee per il quartiere — tavolo del mercoledì
```

Summary:

```text
Un incontro settimanale per trasformare piccole idee locali in cose da fare davvero.
```

Topic:

```text
Progetti di quartiere
```

#### Monthly makers table

Title:

```text
Laboratorio aperto: legno e piccole riparazioni
```

Summary:

```text
Una mattina al mese per condividere attrezzi, tecniche e lavori lasciati a metà.
```

Topic:

```text
Fare e riparare
```

#### Paused reading table

Title:

```text
Gruppo di lettura del sabato
```

Summary:

```text
Un incontro tranquillo per leggere e discutere insieme, in pausa finché non troviamo un nuovo facilitatore.
```

Topic:

```text
Lettura e discussione
```

### Scambio-Dona

#### Dona

Title:

```text
Regalo attrezzi da giardinaggio
```

Description:

```text
Un rastrello, due palette e due annaffiatoi che non uso più. Preferirei darli a qualcuno che li userà per un orto o un giardino condiviso.
```

#### Scambia

Title:

```text
Scambio due tavoli pieghevoli per aiuto con una mensola
```

Description:

```text
Ho due tavoli pieghevoli in buono stato. Li scambio volentieri con una mano per sistemare e fissare una mensola in legno.
```

Do not accidentally convert current `exchange` semantics into a contractual barter/loan system; this is still ordinary listing description copy.

#### Closed

Title:

```text
Vassoi per piantine — già assegnati
```

Description:

```text
Vassoi riutilizzabili da semina. Questo annuncio resta nel demo come esempio di inserzione chiusa.
```

---

## 7. More realistic Trento location data

The old demo hardcodes nearly everything as:

```text
Trento · Povo
```

Make location definitions scenario-specific while keeping the same locality for useful filters.

Use:

```text
countryCode = IT
locality = Trento
administrativeArea = Provincia autonoma di Trento
```

and varied rough public labels such as:

```text
Trento · Povo
Trento · San Martino
Trento · Le Albere
Trento · Centro
```

Do not invent private home street addresses.

For public exact meeting examples, use plausible public meeting descriptions rather than fake civic-street addresses.

For restricted examples, store a plausible private/restricted meeting text that remains hidden from unauthorized users, for example:

```text
Cortile privato vicino a Povo — dettagli nel gruppo dei partecipanti
```

The purpose is to demonstrate privacy boundaries, not claim that a real resident is hosting an event.

Refactor demo definitions so location fields live in scenario data instead of being hardcoded inside `ensureProposal`, `ensureTavolo`, or `ensureListing`.

---

## 8. Realistic chat copy

Replace the synthetic English Project-chat messages with short Italian coordination messages.

For example:

```text
Ho preparato una bozza del murale e porto nastro e pennarelli per decidere i colori.
```

```text
Io posso fare qualche foto del muro prima di iniziare e dare una mano con la composizione.
```

```text
Perfetto. Domani confermiamo qui materiali e orario così arriviamo già organizzati.
```

Keep exactly the same functional chat-history role in the scenario.

---

## 9. Licensed cover photography

Use real stock photography for demo **content covers**, not profile identities.

The final repository must vendor normalized WebP copies.

Do not hotlink Pexels or any other website at runtime.

Do not make local demo seeding require internet.

### License

Use Pexels assets under the Pexels license.

At prompt creation, Pexels states that its photos can be downloaded and used for free, including in apps, and attribution is not required, although appreciated.

Still record attribution/source metadata in the repository for provenance.

### Curated source set

Use these source pages as the default curated assets unless one becomes unavailable or clearly unsuitable when inspected.

#### Mural

Source page:

```text
https://www.pexels.com/photo/people-having-conversation-while-working-on-the-street-10615943/
```

Photographer:

```text
Quang Nguyen Vinh
```

Use for:

```text
Coloriamo insieme il muro del sottopasso
```

Prefer a crop where the collaborative wall-painting activity reads clearly.

#### Repair Café

Source page:

```text
https://www.pexels.com/photo/man-working-in-a-workshop-surrounded-by-tools-33531812/
```

Photographer:

```text
Bulat843 🌙
```

If this source has a clearly identifiable central portrait that feels too much like a fake PLANETS participant, prefer this alternative:

```text
https://www.pexels.com/photo/tools-in-a-toolbox-9607203/
```

Photographer:

```text
Anastasia Shuraeva
```

#### Acoustic concert

Source page:

```text
https://www.pexels.com/photo/acoustic-guitar-performance-at-outdoor-event-36109670/
```

Photographer:

```text
Alicia Christin Gerald
```

Alternative:

```text
https://www.pexels.com/photo/people-playing-musical-instruments-in-the-field-10434985/
```

Photographer:

```text
cottonbro studio
```

#### Weekly community table

Source page:

```text
https://www.pexels.com/photo/a-group-of-people-talking-to-each-other-while-sitting-near-the-table-7495293/
```

Photographer:

```text
Moe Magners
```

Choose a crop that reads as informal collaboration, not corporate advertising.

#### Makers / woodworking Tavolo

Source page:

```text
https://www.pexels.com/photo/man-and-woman-working-inside-a-room-6791491/
```

Photographer:

```text
Tima Miroshnichenko
```

Alternative:

```text
https://www.pexels.com/photo/people-working-with-wood-12345606/
```

Photographer:

```text
Mehmet Turgut Kirkgoz
```

#### Reading group

Source page:

```text
https://www.pexels.com/photo/people-cooperate-around-book-15017187/
```

Photographer:

```text
Xhemi Photo
```

#### Garden-tools donation

Source page:

```text
https://www.pexels.com/photo/various-gardening-tools-with-plants-and-opened-book-6231722/
```

Photographer:

```text
Gary Barnes
```

#### Folding-table exchange

Source page:

```text
https://www.pexels.com/photo/folding-chairs-by-folding-tables-26832125/
```

Photographer:

```text
quang vinh
```

#### Closed seedling-tray listing

Source page:

```text
https://www.pexels.com/photo/person-flowers-pattern-texture-6508561/
```

Photographer:

```text
Tima Miroshnichenko
```

Alternative:

```text
https://www.pexels.com/photo/green-plants-on-a-seedling-tray-5029765/
```

Photographer:

```text
Anna Shvets
```

### Selection caution

Avoid imagery with:

- visible third-party logos as the focal point;
- political slogans;
- sensitive situations;
- an identifiable individual framed in a way that strongly implies they are the synthetic PLANETS organizer/listing owner.

People can appear naturally as part of an activity scene. Do not describe stock participants as Giulia/Marco/Sara.

---

## 10. External context requirement

Downloading the curated source images is the only required external context.

Codex must have internet access during implementation to obtain the selected Pexels assets.

If it cannot access the source pages/downloads:

- do not substitute random copyrighted Google Images;
- do not hotlink remote URLs;
- do not silently omit all covers;
- stop and report the missing external asset access.

Once downloaded and committed, normal demo seed/verify commands must work fully offline.

---

## 11. Vendored demo asset layout

Create a clear demo-only location such as:

```text
scripts/demo-assets/
  README.md
  covers/
    mural.webp
    repair-cafe.webp
    acoustic-concert.webp
    weekly-community-table.webp
    makers-table.webp
    reading-group.webp
    garden-tools.webp
    folding-tables.webp
    seedling-trays.webp
  profiles/
    giulia.webp
    marco.webp
    sara.webp
```

Exact file names may vary.

Do not put these into production Flutter bundled assets unless the application itself needs them at runtime. The local seeder can read them from the repository filesystem.

### Cover normalization

Every cover asset must be preprocessed before commit to approximately the same production cover contract:

```text
16:9
max 1280×720
WebP
<= 512 KiB
prefer roughly <= 280 KiB
metadata stripped where tooling permits
```

Use a thoughtful crop rather than stretching.

Do not add a permanent heavyweight image-processing dependency merely to perform a one-time asset conversion if local implementation tooling can preprocess them.

The committed result is the normalized WebP.

---

## 12. Asset provenance manifest

Add a small machine- or human-readable manifest, for example:

```text
scripts/demo-assets/README.md
```

or:

```text
scripts/demo-assets/assets.json
```

For every external cover include:

- local file name;
- scenario;
- Pexels photo page URL;
- photographer;
- license URL:
  `https://www.pexels.com/license/`
- date retrieved;
- note that the file was cropped/resized/converted to WebP for PLANETS demo use.

Do not store temporary signed download URLs.

Prefer crediting photographers in this developer manifest even though attribution is not required.

The app UI does not need to display stock-photo attribution for this local demo task.

---

## 13. Seed demo profile photos first

Before publishing gated content:

```text
complete demo profile
→ ensure canonical profile photo
→ create/publish demo content
```

Do this using normal authenticated Storage/RPC behavior.

The seeder must not disable or bypass the profile-photo publication gates.

The demo verification should assert that the expected profile-photo records exist.

---

## 14. Seed canonical covers through real APIs

Do not directly insert into:

```text
project_covers
resource_listing_covers
storage.objects
```

Use the authenticated Storage + canonical cover RPC boundary introduced by 08B1.

For Project covers, use paths shaped like:

```text
<creator_profile_id>/projects/<project_id>/<stable-demo-version>.webp
```

For Resource covers:

```text
<owner_profile_id>/resources/<listing_id>/<stable-demo-version>.webp
```

Use deterministic per-scenario version UUID constants so reruns know the intended object path.

Then:

```text
upload normalized WebP
→ set canonical cover RPC
→ clean replaced path best-effort if needed
```

Do not use `upsert=true`.

---

## 15. Lifecycle ordering matters

Some demo entities end in states where cover mutation is no longer allowed.

Seed in the correct order.

### Historical Proposal

The existing DEMO-B deliberately creates the concert with safe future initial times before moving it into a historical/just-finished time window.

Cover sequence must be:

```text
create editable draft
→ profile photo already exists
→ upload/commit cover
→ publish
→ then perform the existing controlled demo timestamp aging
```

Do not try to add the cover after the Proposal has become frozen.

### Paused Tavolo

```text
create draft
→ set cover
→ publish
→ pause
```

### Closed Resource listing

```text
create draft
→ set cover
→ publish
→ close
```

This both respects production authorization and verifies the intended lifecycle boundary.

---

## 16. Idempotency and legacy demo-title migration

The original DEMO-B identifies stable scenario rows partly by title.

Changing titles naively would cause duplicate demo rows when a developer already has the old demo world and runs:

```text
npm run demo:seed:local
```

Preserve the command's rerunnable promise.

Introduce an explicit mapping between old demo titles and new display titles.

Legacy examples include:

```text
DEMO · Riverside mural
DEMO · Repair café
DEMO · Courtyard concert
DEMO · Weekly community table
DEMO · Monthly makers table
DEMO · Paused reading table
DEMO · Community garden tools
DEMO · Folding tables for a skill swap
DEMO · Seedling trays (claimed)
```

Before normal scenario reconciliation, safely migrate an existing unique row owned by the expected demo identity from its old title to the new title, or otherwise adopt a deterministic migration strategy.

Requirements:

- only touch rows owned by the stable demo identities;
- only touch exact known legacy titles;
- fail if duplicates/ambiguous state exist;
- do not rewrite arbitrary developer-created rows;
- after migration, reruns reuse canonical IDs;
- old `DEMO · ...` rows do not remain duplicated beside the new ones.

Direct local SQL is acceptable for this narrow trusted demo migration because historical/frozen domain rules may make ordinary user edits impossible; document why.

Do not add production schema solely for demo registry metadata.

---

## 17. Scenario keys should stop being display-copy hacks

Refactor the scenario definitions so internal stability is not based on prepending:

```text
DEMO ·
```

to user-facing titles.

A good direction is structured definitions containing:

```text
key
legacyTitle
title
summary
description
location
coverAsset
coverVersion
...
```

Use stable internal object keys such as:

```text
mural
repairCafe
concert
weekly
monthly
paused
donate
exchange
closed
```

Tests should assert those keys/definitions are unique and complete.

Do not show `DEMO` in titles solely for test identification.

Developer docs and login emails already make the dataset clearly synthetic.

---

## 18. Cover behavior to verify

At minimum verify:

### Public

- published Proposal cover path is returned;
- anonymous Storage download of current canonical public cover succeeds;
- published Tavolo cover succeeds;
- published Resource listing cover succeeds.

### Non-public / owner-only

- closed Resource does not expose cover publicly through stale path;
- owner can still access current owner data according to existing semantics;
- replaced stale cover object is not treated as canonical/public.

### UI contract

DEMO-01 does not need new Flutter cover widgets: PR #110/#112 already render covers.

The seeded canonical paths are enough for the normal app to display them.

Do not add special “demo image” branches to production widgets.

---

## 19. Demo verification expansion

Extend:

```text
npm run demo:verify:local
```

to verify the realistic world.

Include:

- three expected display names;
- no public scenario title starts with `DEMO ·`;
- exact expected scenario count;
- profile photos exist for all demo identities;
- each intended content entity has the expected canonical cover path;
- public cover reads/downloads work where parent is public;
- hidden/private location checks still pass;
- participation states still pass;
- notification projection still passes;
- chat history contains the new expected Italian messages;
- public Resource discovery includes published examples but not the closed example;
- historical/paused states remain correct.

Do not weaken existing privacy/security assertions merely to focus on presentation.

---

## 20. Demo tooling unit tests

Update `demo-world.test.mjs` for:

- stable demo emails remain unchanged;
- new persona display names;
- unique structured scenario definitions;
- new titles do not contain the old technical prefix;
- legacy title mapping is unique;
- every cover-requiring scenario references a known asset;
- deterministic cover version UUIDs are valid and unique;
- no duplicate asset assignment unless explicitly intentional;
- safe error output remains secret-free;
- local-target refusal remains unchanged.

Add focused asset-manifest tests where useful.

Do not make unit tests contact Pexels.

---

## 21. Offline deterministic behavior

After implementation has downloaded and vendored the assets:

```text
npm run demo:reset:local
```

and:

```text
npm run demo:seed:local
```

must not require internet.

Do not call:

- Pexels API;
- Pexels image CDN;
- Google Drive;
- Unsplash;
- remote URLs;

during seeding or verification.

The only network used by DEMO-B at runtime should be the local PLANETS/Supabase/Mailpit stack as before.

---

## 22. No production database migration expected

This is demo tooling.

Do not add a database migration.

All required profile-photo and cover-media production contracts already exist in the PR #112 dependency stack.

If the demo cannot be seeded through those contracts, report the concrete issue rather than changing production security rules to accommodate the demo.

---

## 23. Do not modify production authorization for demo convenience

Explicitly forbidden:

- disabling profile-photo gates in demo mode;
- service-role publishing instead of real user RPCs;
- publicizing private buckets;
- inserting cover rows directly;
- weakening lifecycle checks;
- special `is_demo` bypass in production functions;
- hardcoded demo user IDs in migrations.

The demo should prove the real product paths work.

---

## 24. Scope boundaries

Do not implement:

- template marketplace/workshop;
- finished-project template cloning;
- popularity ranking;
- shared Google Drive/workspace link;
- chat attachments;
- image galleries;
- camera capture;
- production seed data;
- staging demo reset;
- production demo reset;
- stock-photo search inside the app;
- AI image generation;
- web redesign;
- new localization infrastructure.

This task is only the trusted local demo-world presentation/data refinement.

---

## 25. Documentation

Update:

```text
docs/development/demo-data.md
scripts/lib/README.md
docs/development/getting-started.md
```

as appropriate.

Document:

- realistic synthetic persona names;
- stable login emails;
- available scenarios;
- vendored cover-photo provenance;
- covers are real Pexels demo assets, not user-uploaded production content;
- profile avatars are synthetic/local fixtures;
- seeding is offline after checkout;
- DEMO-B remains local-only;
- old `DEMO ·` scenario rows are safely migrated on rerun;
- current branch reconciles DEMO-B from main because the media stack originally diverged before DEMO-B merged.

Do not present stock-photo scenes as real PLANETS events.

---

## 26. Validation

Because this task reconciles demo tooling from current main into the current media/resource stack, validate both tooling and real local behavior.

At minimum run:

```text
npm run test:tooling
npm run db:reset
npm run demo:seed:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

The second seed/verify pair is important for idempotency.

Also test legacy migration behavior if practical:

1. seed an old-title DEMO-B world or controlled equivalent;
2. run the new seeder;
3. verify canonical IDs are adopted and no duplicate new/old scenarios remain.

Run relevant database/media verifiers if the seeder exercises newer boundaries:

```text
npm run cover:verify:local
```

plus any profile-photo verifier command present on the branch.

Run:

```text
npm run check:mobile
```

because the current app is the consumer of the seeded data and branch reconciliation may touch demo/editor code.

Run:

```text
npm run check:web
```

if the reconciled main DEMO-B/tooling changes fall under the repository web/tooling validation.

Run changed-scope format checks and:

```text
git diff --check
```

Do not claim physical-device QA.

The current hosted GitHub CI may still fail before starting because of the known billing/spending-limit restriction. Inspect once, document accurately, and do not rerun unchanged infrastructure failures.

---

## 27. Acceptance criteria

DEMO-01 is complete only if all are true:

- [ ] Branch is based on exact PR #112 head unless an explicitly approved newer base is used.
- [ ] Existing DEMO-B functionality from current main is reconciled rather than rewritten from scratch.
- [ ] `demo:seed:local`, `demo:reset:local`, and `demo:verify:local` exist on the branch.
- [ ] Demo remains local/loopback only.
- [ ] Stable demo emails remain unchanged.
- [ ] Persona display names are natural rather than `Demo Alice/Bob/Carla`.
- [ ] User-facing scenario titles no longer start with `DEMO ·`.
- [ ] Proposal/Tavolo/Resource copy is realistic Italian content.
- [ ] Locations vary realistically while remaining safe.
- [ ] Current participation/notification/chat test topology remains intact.
- [ ] Demo profiles satisfy current profile-photo gates through canonical behavior.
- [ ] No identifiable stock headshot is used as a synthetic persona identity.
- [ ] Every selected cover is a vendored local WebP.
- [ ] Runtime seeding performs no internet image fetch.
- [ ] Cover assets are normalized to the current 16:9 / <=512 KiB contract.
- [ ] External photo source/photographer/license provenance is committed.
- [ ] Project covers are uploaded and committed through real authenticated Storage/RPCs.
- [ ] Resource covers are uploaded and committed through real authenticated Storage/RPCs.
- [ ] Historical/paused/closed entities receive covers before becoming non-editable.
- [ ] Public canonical covers can be downloaded anonymously where allowed.
- [ ] Closed/private/stale media remains non-public.
- [ ] Rerunning the seed is idempotent.
- [ ] Existing old `DEMO ·` rows migrate safely without duplication.
- [ ] No production DB migration is added.
- [ ] No production authorization is weakened.
- [ ] Demo seed/verify passes twice consecutively.
- [ ] Tooling tests pass.
- [ ] Relevant mobile/build checks pass.
- [ ] Exact prompt is archived.
- [ ] Focused PR is opened and remains unmerged.

---

## 28. Completion report

Return a concise structured report containing:

1. branch;
2. exact base commit;
3. final head commit;
4. PR number/link and target branch;
5. how DEMO-B from main was reconciled;
6. final persona display names;
7. final Proposal/Tavolo/Resource titles;
8. cover asset directory;
9. asset source/license manifest path;
10. any curated photo substitution from the supplied list and why;
11. profile-photo demo approach;
12. how legacy `DEMO ·` rows are migrated safely;
13. cover seed ordering for historical/paused/closed scenarios;
14. exact demo/tooling validation results;
15. second-run idempotency result;
16. any inherited CI/environment warning;
17. confirmation that:
    - seeding works offline after checkout,
    - no DB migration was added,
    - no production security bypass was added,
    - no Drive/chat attachment work was added,
    - the PR remains unmerged.

If external access to the curated Pexels assets is unavailable, stop and report that blocker rather than substituting unlicensed images.
