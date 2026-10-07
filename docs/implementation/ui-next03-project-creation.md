# UI-NEXT-03 — Project creation and editor controls

## Base and sequence

The user explicitly replaces merged-predecessor gating with sequential stacked
implementation, followed by ordered merges. UI-NEXT-01 #156 is preserved and
UI-NEXT-02 #158 is the exact dependency at
`4ecbd15f124e231190670698875acc8cc42ce856`. Its implementation commit is
`eca0a709d24b0a1c9eb986727ca07b8ec1e72925`. Main at branch creation remains
`9cd024cc38c02b0333a32f8abe71fdc9681df548`. The PR evidence records final source,
documentation and merge heads once validated.

## Implemented scope

Normal Create Project opens an EN/IT choice before either scratch or Workshop.
Choosing, browsing, cancelling and repeated taps create no empty draft. Direct
edits, receipts and recovery retain the existing editor path. Meaningful draft
entry into Workshop still saves once and opens independent template destinations.

The form owns its existing DRAFT01 state, validation, matching, cover and trust
logic. New controls provide bounded capacity stepping plus unfiltered raw numeric
entry; the step callback reads the current controller to reject paste/tap races.
Organizer counting stays off by default with a full-width explanation. Start/End
show localized wall time in the named event zone, and adapt alongside the large
Save draft/Publish pair to narrow screens and text scaling. Picker cancellation
retains existing values. Selected skill chips reuse the controlled Profile picker
and retain visible Required/Useful importance; new selections default to Useful.

Only genuine scratch/new template creation adopts `Europe/Rome`. An additive
replacement of `create_proposal_draft_from_template` changes its creation argument
after the existing receipt-recovery return; old destinations and UTC instants are
never updated by it. Legacy non-Rome events retain their zone and show a hint.
Legacy undated drafts with null timezone preserve null on text-only save; choosing
their schedule uses the prior UTC picker convention. No RPC signature, schema,
grant, RLS, public Web projection or template eligibility policy changes.

Sample fill stays hard-off in production and moves below the real actions. Its
scrollable confirmation protects meaningful input even with a keyboard and large
text. It never saves/publishes itself. The removed Workshop publication notice
was informational `Text`, with no consent control. Dedicated Workshop explanations
and report controls remain. Typed hub-origin Project saves return to the same
filtered hub; ordinary entry retains owner management.

## Validation and reproduction

`npm run check:mobile` passed localization, formatting, analysis and 1,524 tests
with two existing skips. Invitation/departure fixtures now target the explicit
scratch editor because Create itself is the mutation-free chooser; their guard,
identity replacement, retry and replay assertions remain intact.

Full `npm run check:db` passed on the isolated stack, including migration replay,
pgTAP, authenticated verifiers, template recovery, stable demo reruns and generated
type equality. Web's 283 tests passed (one existing skip) with `--maxWorkers=2`,
followed by standard lint, typecheck and production build; tooling tests passed.
The initial unbounded Web run hit an unchanged test's timeout under local load.
No timeout or Web implementation was changed. Backend mutations
use only batch-owned `planets-community-ui-next02-qa-20261007` at API/DB/Mailpit
55381/55382/55384, verified by selector and container ports. Temporary configuration
is restored before commit. Retained phone-demo and other tasks' stacks are preserved.

Automated fixtures cover chooser cancel/scratch/templates, sparse Workshop
departure/independent sessions, actual protected OTP return, hub save, capacity
unset/direct/invalid/bounds, current organizer and server conflict regressions,
picker cancellation, legacy zones, Rome DST intervals, skill search/default/removal,
similar matching, cover partial success and photo-required publication. A narrow
320-pixel, 2x-text keyboard case exercises both actions and demo confirmation.

Native Android uses the existing explicitly opted-in UI02 fake-gateway harness
built from this checkout and `ui_next03_native_smoke.dart`. The debug build and
chooser, scratch capacity, competence selection, separated actions, sample-fill
cancellation and draft save passed on owned `emulator-5580`. One footer reveal
needed an assisted emulator swipe while the driver waited for offscreen scrolling.
Captures confirmed the selected Useful competence and saved owner card. Its results are separate
from real canonical backend validation. Native iOS is unavailable on this Windows
host, and the founder's physical phone is untouched.

Manual reproduction: Browse → Create Project → From scratch, enter a capacity
directly or with +, choose dates, select competences and edit their importance,
then Save draft. The folder hub opens direct editing and retains its filters on
save. From a template uses existing seeded Completed templates; applying creates
an independent draft with unset schedule/location and Rome timezone. Existing
records keep their stored schedule. Demo sample fill is after Save/Publish and
requires confirmation when input exists.

## Next slice

UI-NEXT-04 stacks on this validated head. The founder approved a disabled
provider-neutral location foundation, retained manual fields and documented
activation requirements. No provider licensing, billing or live-map activation
is inferred from the current manual location or PostGIS installation.
