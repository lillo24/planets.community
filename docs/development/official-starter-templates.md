# Official starter templates (OST01)

The canonical Workshop has two kinds of identities. Community entries retain a
real source Proposal, original Creator, genuine Completed eligibility, source
visibility and moderation rules. Official starter entries are reusable examples
attributed to the **Planets Community Official organization**. They have no Auth
user, Profile, source Project, event history, attendance, membership or chat.
An ordinary account using that display name gains no designation or authority.

## Catalog and ownership

The eight Italian-first entries adapt the reviewed TW05 scenarios:

| Key       | Title                                                           | Required / useful skills            | Capacity |
| --------- | --------------------------------------------------------------- | ----------------------------------- | -------- |
| repair    | Repair Café: una mattina per aggiustare piccoli oggetti         | basic-repairs / woodworking         | 16       |
| mural     | Murale di quartiere: prepariamo e dipingiamo insieme            | mural-painting / event-organization | 20       |
| flowerbed | Aiuola condivisa: piantiamo e curiamo uno spazio comune         | gardening / urban-gardening         | 12       |
| concert   | Concerto acustico di quartiere: suoniamo e prepariamo lo spazio | musician / audio-sound-setup        | 24       |
| trail     | Pulizia del sentiero: raccogliamo e separiamo i rifiuti         | event-organization / gardening      | 18       |
| books     | Scambio di libri: portane uno e scopri nuove letture            | facilitation / event-organization   | 16       |
| bookcase  | Libreria di comunità: costruiamo un piccolo punto di scambio    | woodworking / practical-making      | 10       |
| dinner    | Cena di quartiere: prepariamo e condividiamo una tavolata       | cooking / event-organization        | 24       |

Each suggests three hours and two open resource descriptions. Text preserves
permissions, safe repair/tool use, waste handling, food ingredient/allergen and
maintenance boundaries. No location or successful outcome is asserted.

- `supabase/catalog/official-starter-templates.json` is the reviewed release
  manifest: stable keys, UUIDs, skill slugs, content and resource blueprint IDs.
- `20261011094930_official_starter_templates.sql` is the additive deployment
  history and embeds that release manifest. Future releases add a migration;
  they never rewrite applied history. HTTP validation checks manifest/database
  equality and bundled-image checksums.
- `private.proposal_templates` owns immutable kind/key/identity and removal.
  `private.official_starter_template_content` owns the curated allow-list.
  `private.workshop_template_content` resolves current controlled descriptors.
- `private.provision_official_starter_template` is a database-owner-only,
  reviewed maintenance operation. No API role, including `service_role`, has
  table/helper access. RLS remains enabled. Public clients cannot curate content.
- `private.official_starter_template_reviews` records database session actor,
  time, reason, before/after content and retirement, append-only. An operator
  using a shared DB login must retain their personal change-ticket attribution.

The fixed organization display is derived from the subtype on the server. It is
deliberately not a navigable human profile. Moderation reports may have a null
subject Profile only for an organization template with null source provenance;
all ordinary report targets retain a human subject. Staff queue/detail show the
organization name, current reusable content, token drift and protected removal.
No Project incident, corroboration, user sanction or account deletion is invented.

## API, versioning and independent drafts

Opt-in reads are `list_public_proposal_templates_v2`,
`get_public_proposal_template_v2` and
`list_public_proposal_template_resource_blueprints_v2`. They retain existing
limits, literal search, OR skill filters, paired descending `(linked_at,id)`
catalog cursors and ascending blueprint UUID cursors. Official `linked_at` is a
fixed catalog-introduction instant, not an event timestamp. `is_official` and
`cover_asset_key` are additive fields; official source/Profile IDs are null.

**Client release requirement:** the pre-OST01 parser requires non-null source
and Creator UUIDs and source-bound cover paths. Sending organization entries to
that API would break the whole list. Legacy reads therefore remain unchanged
and community-only. An existing Closed-testing build using those reads cannot
show these eight entries; a new mobile AAB using v2 is required, for content as
well as the localized **Predefinito / Default** badge. This is verified against
repository parser/contracts, not a claim that an installed physical phone was
inspected. No Play upload/submission is included.

Applications use the existing `create_proposal_draft_from_template` and private
receipt/recovery RPC. All fields come from one locked canonical snapshot. Edits,
reports, removal and application take the same template lock; community paths
retain Proposal-before-template lock order. New applications recheck visibility
and the exact `tw01` hash after waiting. Hashes include resolved skills, needs,
capacity, duration and the illustration key. Equal restored content hashes
identically; a token is not authorization or a chronological revision number.

Copies have editable text, skill selections, fresh need IDs, optional capacity,
organizer counting off and Italy's existing timezone default. Dates, location,
people, historical state and covers are unset, as in the existing application
contract. The illustration is preview guidance, never a user-owned cover.
Accepted receipts retain null source provenance and remain recoverable after
content edits, administrative retirement or moderation removal. Recovery
returns the same independent destination and never reapplies content over user
edits. New keys still require a complete current profile and current eligibility.

## Licensed illustrations

Six unchanged WebP covers are bundled in `apps/mobile/assets/official_templates`.
Their Pexels source pages, photographer credits, license and SHA-256 provenance
are in [the existing asset ledger](../../scripts/demo-assets/assets.json) and
[media notes](../../scripts/demo-assets/README.md). They illustrate example
activities; pictured people are not PLANETS participants or organizers. Trail
cleanup and dinner use the ordinary cover placeholder. No remote URL or public
Storage ownership is fabricated. **No Storage upload, bucket, service key or
staging media setup is needed.** A new cover requires reviewed licensed bytes,
an allowed asset key, a content migration and a mobile release.

## Shared staging activation — operator steps, approval required

This implementation does not deploy or mutate staging/production. The read-only
inspection on 2026-10-11 confirmed project `cllpvruvrrvxczjitlqd`
(`planets-staging`), three Proposals, two linked identities, zero legacy public
Workshop results. Those counts are a checkpoint, not permission to reset data.

Prerequisites: checkout the merged commit, `npm ci`, project-scoped Supabase CLI,
an authorized project migration operator's `SUPABASE_ACCESS_TOKEN` and
`SUPABASE_DB_PASSWORD` supplied securely in the environment. Do not print them,
commit them, pass a service-role key to a client, or invent a synthetic Auth user.
The HTTP readback only needs the target API URL and its publishable key.

First inspect without database writes. `--project-ref` makes the target explicit;
SQL files are emitted locally by a script with no mutation mode:

```powershell
node scripts/official-starter-inventory.mjs --preflight-sql > "$env:TEMP/ost01-preflight.sql"
npx supabase db query --project-ref cllpvruvrrvxczjitlqd --file "$env:TEMP/ost01-preflight.sql"
npx supabase db push --project-ref cllpvruvrrvxczjitlqd --skip-vault --dry-run
```

Compare remote migration history with the merged checkout. **Stop if the dry
run includes unreviewed predecessors or drift**; OST01 must not incidentally
activate other features. Reconcile/approve those separately before applying.
If OST01 is already installed, also produce the inventory/diff:

```powershell
node scripts/official-starter-inventory.mjs --catalog-sql > "$env:TEMP/ost01-catalog.sql"
npx supabase db query --project-ref cllpvruvrrvxczjitlqd --file "$env:TEMP/ost01-catalog.sql"
```

All eight rows should be `MATCH`; `MISSING`, `CONTENT_DRIFT`, `IDENTITY_DRIFT`
and `RETIRED` require review. Exact repeated provisioning is a no-op. A changed
release cannot overwrite drift with a null expected hash.

**Only after separate explicit staging authorization**, when the dry run shows
only approved pending migrations:

```powershell
npx supabase db push --project-ref cllpvruvrrvxczjitlqd --skip-vault
node scripts/official-starter-inventory.mjs --catalog-sql > "$env:TEMP/ost01-catalog.sql"
npx supabase db query --project-ref cllpvruvrrvxczjitlqd --file "$env:TEMP/ost01-catalog.sql"
$env:PLANETS_STARTER_API_URL = 'https://cllpvruvrrvxczjitlqd.supabase.co'
# Supply PLANETS_STARTER_PUBLISHABLE_KEY securely; it is a publishable, not service-role, key.
node scripts/official-starter-inventory.mjs --readback
```

Readback traverses actual anonymous public-RPC pages and requires all eight
stable IDs, titles and organization metadata. Recheck the Proposal/Profile
counts against the preflight inventory: the three existing Proposals and tester
account must be intact (concurrent genuine user activity may add rows). No demo
seeder, reset, test persona, truncate, media upload or Vault update is part of
activation. If API schema refresh is delayed, verify migration history and
retry readback; never report deployment success from the push alone.

## Reviewed edits and rollback by retirement

Use a new reviewed migration calling the owner-only function with the stable
UUID/key, **raw content hash from the inventory**, complete reviewed content
and a specific reason. The raw hash is distinct from the public descriptor hash
so skill-label updates do not silently change the operator's expected input.
An exact repeat is harmless; changed input with the wrong expected hash fails
`PT409`. Record review/ticket attribution alongside the migration.

Retire without deleting history or independent drafts, in an approved owner
session (one key or repeat for the eight reviewed keys):

```sql
select private.provision_official_starter_template(
  t.id, t.starter_key, private.proposal_template_content_version(c.content),
  c.content, 'OST01 rollback: approved catalog retirement', true
)
from private.proposal_templates t
join private.official_starter_template_content c on c.template_id=t.id
where t.starter_key='repair';
```

Inspect inventory immediately before this statement and retain the expected
hash in a reviewed change when executing across separate sessions. Retirement
is terminal; initial provisioning cannot resurrect a retired/moderated entry.
Canonical staff removal is also terminal and keeps its attributable receipt.
Do not down-migrate, delete accepted receipts, erase review history or cascade
into a tester's private draft. A future restoration policy is outside OST01.

## Validation

For the populated upgrade rehearsal, use **only a dedicated disposable local
stack** with unique project ID/ports. Set `PLANETS_DISPOSABLE_QA=1` and its
`MAILPIT_URL`; provide `node_modules/.bin` on PATH for direct Node commands:

```powershell
npx supabase db reset --local --version 20261010173000
node scripts/verify-local-proposal-template-workshop.mjs
node scripts/verify-local-template-moderation.mjs
node scripts/verify-local-template-application.mjs
node scripts/verify-local-official-starter-upgrade.mjs --before
npx supabase migration up --local
node scripts/verify-local-official-starter-upgrade.mjs --after
```

The real pre-OST01 main upgrade preserved every existing row across **98**
domain tables, including private application receipts and moderation removals;
only new subtype metadata and eight official entries were introduced. Existing
community rows are compared across their original columns, never dropped from
the preservation check. The checkpoint contains counts/digests, not row bodies.

Run `npm run check:db` afterward to replay clean migrations, pgTAP, canonical
HTTP/concurrency checks, demo idempotency and generated type drift. A populated
verifier database must not be used as the starting state for pgTAP.

`128_official_starter_templates.test.sql` covers eight public examples, least
privilege/RLS, spoofed display names, cursor/filter validation, source-free
drafts, private receipts, stale tokens, edits, staff reporting/removal and
terminal retirement. Existing community and public-Idea tests retain genuine
Completed/defined eligibility; their isolated identity counts explicitly exclude
the permanent official catalog.

`proposal:verify:local` also runs the loopback-only OST01 HTTP verifier. It
checks catalog/manifest equality, licensed cover bytes, independent complete
copies, concurrent exact retries, cross-user receipt privacy and overlapping
edit/application lock order. The TW05 demo seeder continues to create separate
source-linked synthetic local examples through legacy Workshop reads; it never
provisions or claims ownership of the official catalog.

Flutter coverage checks strict organization parsing, localized badges, bundled
image loading, source-link omission, editable-draft navigation and unavailable
states at 320dp/2x in Italian and English. The existing community, retries,
reporting, blueprint paging and editor-departure tests remain active. Admin web
parsers accept organization provenance without inventing a human subject.
