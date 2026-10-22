# Activities sandbox

ACTSPLIT01 owns the local example catalogue and its read-only presentation.
Settings > Sandbox > Activities Split Mode opts this installation in; it is off
by default. The Settings feature owns storage and bootstrap restoration.

- `domain/activity_example.dart` defines fictional identities, bilingual content,
  category, sport discipline and format separately, plus pure example filtering.
  A missing schedule stays unknown, even for an ongoing course.
- `data/activity_examples.dart` bundles 12 deterministic examples (nine sports,
  three cultural). They have no backend/provider IDs, URLs, fetched images or
  real organizer contacts. The discipline picker derives from these fixtures.
- `presentation/activities_screen.dart` owns the explicit fictional preview at
  `/activities/examples`, with view-local category, discipline and
  example search. All/Culture exposes a separate native Tavoli entry; Sports
  excludes that entry. Example search never filters native Tavoli. Trento names
  this catalogue only and does not change native geographic preferences.
- `presentation/activity_example_widgets.dart` owns compact cards, provenance
  badges and schedule/format labels.
- `presentation/activity_example_detail_screen.dart` renders only local content,
  including an explicit unknown-ID state. It has no participation, booking,
  messaging, sharing, reporting, submission or analytics commands.

The `/activities/examples` and `/activities/examples/:exampleId` routes live in
the existing Browse branch. Detail Close/system Back retains filters and scroll.
The native `/tavoli` route, pagination, requested rows, draft/create/manage
actions, details, authorization and map remain owned by `recurring_activities`.
Its map is explicitly Tavoli-only. Examples never enter native models,
controllers, caches or RPCs, and a native failure stays a native error.

Turning the setting off gates experiment URLs to `/proposals`, restores normal
Home/browse wording, and leaves domain data, drafts, onboarding and the independent
Messages/Browse shortcut untouched. The router refreshes its gate in place;
preference changes do not replace branch keys. The tutorial explicitly previews
the baseline Home/list presentation in either mode without saving a preference.

See [the experiment record](../../../../../docs/development/actsplit01-activities-sandbox.md)
for activation, validation, rendered evidence and limitations. The main
`/activities` route is owned by `external_activities`, which reads the canonical
backend and exposes this preview through a labelled action.

ACTAPI01's [source checkpoint](../../../../../docs/development/actapi01-source-checkpoint.md)
records the live official API evidence and unresolved reuse-permission gate.
The [infrastructure runbook](../../../../../docs/development/actapi01-infrastructure.md)
describes the source-independent catalogue and still-blocked municipal parser.
This folder continues to own examples only.
