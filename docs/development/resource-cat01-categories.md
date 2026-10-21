# Resource categories (CAT01)

Scambio-Dona has one optional canonical `category_slug`, independent of
`listing_mode`. This provisional classification does not approve or prohibit
goods, change Community Rules, or define a Project resource-needs taxonomy.

| Slug                   | Italiano                    | English                 |
| ---------------------- | --------------------------- | ----------------------- |
| `tools_diy`            | Attrezzi e fai-da-te        | Tools & DIY             |
| `garden_outdoors`      | Giardinaggio ed esterni     | Garden & Outdoors       |
| `home_furniture`       | Casa e arredamento          | Home & Furniture        |
| `electronics`          | Elettronica                 | Electronics             |
| `clothing_accessories` | Abbigliamento e accessori   | Clothing & Accessories  |
| `books_learning`       | Libri e materiali didattici | Books & Learning        |
| `sports_hobbies`       | Sport, hobby e giochi       | Sports, Hobbies & Games |
| `materials`            | Materiali e forniture       | Materials & Supplies    |
| `other`                | Altro                       | Other                   |

`All` is an unset filter, not a stored category. Existing listing and saved-search
rows retain NULL. A specific category matches only explicitly classified
listings; an unfiltered query includes legacy rows. Unknown slugs fail with
`22023`; API input is trimmed and lowercased, and stored values are constrained.
There is no automatic classification or publication/matching backfill.

## API and rollout compatibility

Deploy the additive migration before releasing the updated mobile client.
No hosted migration or app release is authorized by this code change.

The category-aware client uses these uniquely named successors, avoiding
PostgREST overload resolution and PostgreSQL return-type replacement:

- `create_resource_listing_draft_v2`, `create_editor_resource_listing_draft_v2`,
  `update_own_resource_listing_v2`: existing content arguments plus
  `p_category_slug`. The editor creation receipt includes category in its
  immutable intent hash; existing recovery and cover retry boundaries remain.
- `list_public_resource_listings_v2`: existing keyset and filters plus optional
  `p_category_slug`; filtering precedes the limit. Category/published-at/id has
  the same scoped index pattern as existing published discovery filters.
- `get_public_resource_listing_v2`, `list_own_resource_listings_v2`,
  `get_own_resource_listing_v2`: existing authorization/projection plus category.
- `create_resource_saved_search_v2`, `update_resource_saved_search_v2`,
  `get_own_resource_saved_search_v2`, `list_own_resource_saved_searches_v2`:
  complete category-aware definitions. Category alone is valid; semantic
  uniqueness includes category with the existing case-insensitive query/locality.

Existing listing RPC signatures, return shapes, and publication rules remain.
An old-client content edit preserves an existing category. Backend publication
still accepts legacy clients omitting category; only the updated mobile client's
new-publication action requires an explicit choice. Drafts can remain unset, and
already-published legacy content can still be edited without classification.

Legacy saved-search reads return only NULL-category definitions: old clients
cannot parse category-only definitions or faithfully restore category-restricted
ones. Their original definitions and row shapes retain their meaning. V2 reads
return all owned definitions. Clearing a category makes a definition visible to
legacy readers again. Existing delete and legacy write signatures are retained.

## Matching and maps

The private V2 predicate combines category equality with the existing literal
keyword, exact case-insensitive locality, and nullable mode predicates. The
publication projector and notification resolver use it with canonical rows.
Source chronology, saved-search version tokens, owner suppression, identifier-only
events, preferences, and recipient/listing delivery uniqueness remain unchanged.
The seven-argument private predicate remains for legacy callers. Project-needs
matching keeps its existing keyword/geography/mode behavior.

`search_public_geography_v1` accepts optional `resource_category_slug`. Its
validated normalized value participates in query identity. Radius and bounds
candidate branches apply category only to Resource items, before candidate caps
and paging; mixed All retains Projects and Tavoli. NULL/absent category is stripped
from the normalized query so legacy map cursor identity is preserved. The map
response shape remains unchanged.

## Mobile ownership

`resource_category.dart` owns stable wire values; `resource_category_field.dart`
owns localized labels, metadata and the shared nullable single-select. The
dropdown menu wraps full labels, while selected labels stay compact with
ellipsis at narrow widths and large text. Browse places category between mode
and locality inside the existing disclosure. Its badge includes category but
excludes the always-visible keyword. Category changes flush pending text once;
disclosure, retry, pagination, stale-response checks and saved-search Open retain
the whole tuple. Public card/detail and owner history omit category for NULL.

The editor keeps an unset draft option and validates category on the first new
Publish attempt, before the photo gate or draft creation. Existing published
legacy edits remain valid. Saved-search Edit and summary support category-only
definitions. Map snapshots apply it only when Resource is an active family.

## Verification

`148_resource_categories.test.sql` covers constraints, grants, legacy and V2
requests, creation receipts, category-only definitions and duplicates,
conjunctive filters/keysets, matching/delivery revalidation and deduplication,
terminal closure, and family-scoped radius/bounds/cursors. The exact-column
assertions in 031 and 085 add the intentionally new nullable column.
`resource:listings:verify:local` also exercises V2 PostgREST contracts through
synthetic OTP identities and closes/deletes its extra public/search fixtures.

Run SQL checks only against a disposable QA stack. Regenerate database types
with the repository's `npm run db:types`; never hand-edit generated contracts.
The existing tested generator nullability registry marks `category_slug` nullable
on the six V2 readers because pg-meta cannot infer `RETURNS TABLE` nullability.
Flutter tests cover parsers/transport, category-only Save/Edit/Open, stale fetches,
retry and identity reset, first-publication/legacy editing, List/Map family scope,
and EN/IT light/dark selectors at 320 logical pixels with 1x/2x text. The real-font
rendered fixtures accept `--dart-define=UI_POLISH_CAPTURE_DIR=<absolute-folder>`.
