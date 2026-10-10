# LOCATION01: defined Projects with a public city

## Contract and boundaries

A defined public one-time Project requires public city + valid start/end schedule
and all existing content, organizer-photo, capacity and lifecycle safeguards.
Exact venue/instructions are optional. A structurally required meeting row can
contain null text/coordinates. This adds no lifecycle state and does not change
Completed. Public **In definizione / Idea**, absent city/date, promotion and a
collaborative chat checklist remain separate plans. Tavoli/Resources retain their
existing publication rules and default shared editor behavior.

## Authoring and privacy

The one-time editor exposes one public field: **Dove si svolgerà? / Where will it
take place?** New manually typed Italy entries derive country IT, locality and
public label internally. An untouched existing record retains country, region,
timezone, labels and precise details, including international records. Manual
editing deliberately updates locality/label and clears obsolete region metadata.
Canonical bounds still apply; incomplete drafts can be saved without publishing.

Optional precise controls start collapsed for new content, expand for existing
instructions or protected selection, and show Public/Participants only when
precise content exists. Explicit removal clears the protected selection through
the identity/revision-bound session before clearing text; failure retains text
for retry. A lost clear response retries the same idempotent command and also
finishes the text removal; new edits or identity changes revoke that intent.
Ordinary manual edits still invalidate stale verified geometry through
existing triggers. Absent public exact text with `exact_location_restricted=false`
means no protected content is being hidden. Restricted still covers protected
geometry with null instructions. Authorized null instructions get localized
absence copy, distinct from denied or failed reads. No new public projection of
protected coordinates is introduced.

MAP02 lookup uses the same public field, receipts, actor/item/revision/expiry
scopes, credits and attribution. Failure leaves manual entry usable without
network or lookup success. Provider activation, keys, limits and paid traffic
are unchanged. City-only manual Projects remain List-only, with no invented marker or Maps
action. Existing manual precise records retain their canonical broad-area Maps
search, while verified broad/exact projections retain their existing destinations. Independently verified broad geometry can appear as an approximate Map
reference; exact details never supply public discovery geometry.

## Migration and deployment handoff

`20261010075613_defined_proposal_city_only.sql` replaces the authoritative
`private.assert_proposal_publishable(uuid, boolean)` body, removing only the exact
text completeness condition, and replaces `get_public_proposal(uuid)`'s restricted
flag expression to require actual protected text/geometry. Signatures, grants,
RLS, row requirements, photo/capacity extensions, audit/outbox and later callers
are preserved. There is no column/type/RPC shape change or data rewrite.
Historical migrations are unchanged; generated types remain compatible.

Apply through the normal controlled migration process after merge. Staging and
production are not migrated by this task. The phone's backend must also receive
this migration through its authorized environment workflow before its server
accepts city-only publication. Do not reset the retained founder demo.

## Reproduction and evidence

Use a task-owned disposable local stack for `npm run check:db`, which resets its
selected database. LOCATION01 uses project `planets-location01-qa`, API 59221,
DB 59222 and Mailpit 59224. These temporary local overrides are not committed.
`MAILPIT_URL=http://127.0.0.1:59224` keeps verification on that stack.

- `supabase/tests/125_defined_proposal_location.test.sql`: 22 transactional checks
  cover publication/List/Map, malformed input, protected reads, joining/chat,
  Public/Participants instructions and clearing protected provenance.
- `npm run proposal:verify:local`: real local JWT/REST round trip publishes a
  synthetic Trento Project with null exact text, joins/accepts a second actor,
  checks chat and authorized null meeting reads, then adds/clears instructions.
- Flutter tests cover domain validation, single-field entry, international
  rehydration, removal, disabled/offline/timeout/quota lookup, provider choices,
  stale accounts, draft recovery, null chat info and EN/IT at 320dp normal/2x text.
- Web detail tests distinguish absent instructions from restricted exact content.

Visual evidence: [screenshots](screenshots/location01/README.md) includes the
collapsed/expanded city editor and published city-only detail in EN/IT. Captured
at 320 logical pixels with normal/2x text using the actual widgets, AppTheme,
Flutter SDK Roboto/MaterialIcons fonts and deterministic fake gateways.
Screenshots are deterministic widget fixtures, not native-device or live-backend
proof. Local JWT/SQL evidence separately proves backend behavior. No physical
Android/iOS test, hosted migration, staging seed, retained-data reset, provider
activation, production deployment or app-store operation is claimed.
