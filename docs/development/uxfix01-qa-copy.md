# UXFIX01 QA and copy corrections

## Scope and causes

- Ordinary guest Messages mounted `MessageExamplePreview` from its access state.
  Examples now belong only to `controlsOnly` tutorial views; real guest/setup
  pages keep selectors and authentication context. Ready identities keep real data.
- The creation chooser lacked centered text alignment. `summary` was labelled
  “Riepilogo”, although it introduces browse cards. IT/EN labels now distinguish
  short and full descriptions without changing keys, content, limits or copying.
- Project skill chips lacked people-oriented context. Creation, cards, detail
  and the existing tutorial Create explanation distinguish participants' skills
  from resources/materials/tools. Resource management stays separate and requires
  an existing canonical draft; new forms do not auto-create one.
- The shared location section rendered an explicitly redundant Project paragraph.
  Only that paragraph is hidden; Resource location copy, exact-location privacy,
  maps/receipt handling, manual fields and publication validation remain intact.
- The narrow Italian 2x detail check exposed a pre-existing title/status Row
  overflow. It now uses the cards' wrapping `OverflowBar` pattern. Resource
  loading text also wraps within its row.
- Workshop `load()` correctly refuses non-ready identities, but its view could
  render that untouched state as an empty catalog during an identity transition.
  It now shows login/setup/restoration context. Successful empty responses,
  filter misses and failed/offline reads remain distinct; retry uses the real API.

## Read-only environment diagnosis

Inspected against base `d6ae074f331379d043266d89aea9fe59b1271a3c`
on 9–10 October 2026. These are observations, not a claim about the founder's
currently installed phone build or saved filters.

- Primary `apps/mobile/config/local.json` targets loopback port 54321.
  `staging.json` targets the hosted staging project. Only environment/URL were
  inspected; keys were never printed or committed.
- The primary checkout's existing debug APK contained the same staging backend
  URL. UI-only DEMO-A helpers do not populate either database.
- Read-only anonymous staging RPCs (unfiltered first page, limit 50) returned
  HTTP 200: **1 Project, 0 Tavoli, 0 Scambio listings, 0 templates**. The Tavolo
  request included the required current `p_reference_time`. No staging data,
  users, configuration or schema were changed. Zero templates is a successful
  empty response; local fixtures are not implicitly copied to staging.
- The retained primary local stack held **30 Projects** (8 draft, 1 cancelled,
  21 published), **6 Tavoli**, **5 Scambio listings**, and **22 template identities**
  (21 not removed). Raw identities/published sources are not catalog eligibility.
  Anonymous canonical RPCs returned **8 public Projects and 12 usable templates**;
  **all 8 documented core Completed templates** were visible by exact synthetic
  fixture title. This stack is not empty.
- `npm run demo:verify:local` **failed**, reporting
  `Demo historical, paused, or closed lifecycle state drifted.` Its clock/state
  expectations include future/recently-finished fixtures. The existing world
  was not repaired. The independent read-only catalog inventory above passed;
  it does not imply that the complete demo verifier passed.

There was no destructive reset, migration, seed, fake production discovery,
private hosted read or phone/emulator mutation. No setup-only issue was presented
as a code repair. Missing staging fixtures and retained local lifecycle drift
remain setup findings; the actual phone/filter combination was not reproduced.

## Safely show the intended demo

1. Identify the exact configuration used to build the installed APK/AAB. Inspect
   only `APP_ENV` and `SUPABASE_URL`, not key values. `staging.json` and `local.json`
   are different databases; installing a build does not seed either one.
2. In the primary repository, use `npm run demo:verify:local` to check the existing
   local world. This inventory does not repair state. If it fails, retain the
   failure and diagnose it before any explicit reseed. Do not run
   `demo:reset:local` or `db:reset` on the retained phone-demo stack.
3. To use the existing local dataset on an Android emulator, generate ignored
   config with `npm run mobile:config:local -- --host 10.0.2.2`, then from
   `apps/mobile` run `flutter run --dart-define-from-file=config/local.json`.
   For a physical phone, use the reachable LAN host instead; the phone's
   `127.0.0.1` refers to the phone itself. Confirm connectivity to the intended
   existing stack before rebuilding. These are manual instructions, not actions
   performed by UXFIX01.
4. Clear Project locality/query/skill filters and Workshop query/skill filters.
   Complete login/profile setup for the mobile Workshop. Only eligible Completed
   sources appear: drafts, cancelled, removed or not-yet-Completed sources are
   not usable templates. Network errors must show retry, not “no templates”.
5. If a **separate task-owned disposable loopback stack** needs fixtures, explicitly
   choose that stack, use guarded non-resetting `npm run demo:seed:local`, then
   reverify. UXFIX01 needed no seed. Populating staging or reseeding the founder's
   retained demo requires separate authorization and the correct environment.

## Validation

Widget coverage checks tutorial-only Messages examples versus ordinary guest,
setup, login/logout and account switches; zero signed-out private reads; explicit
Workshop guest/ready/empty/filtered/offline/retry states; and IT/EN creation,
cards/detail, Tavolo and tutorial presentation at 320px with normal/2x text.
Existing location receipt/privacy and draft/resource navigation tests remain.

Commands and final results are recorded in the PR. No native-device proof is
claimed from widget tests. No database suite/reset is needed for presentation-only
changes.

## Separate plans still required

At UXFIX01 completion, public **In definizione / Idea** and the **one-field
location editor/model** remained unimplemented. LOCATION01 subsequently adds
the one-field city editor and optional exact details; Idea remains deferred.
Projects still obey canonical schedule and public-city publication rules.
No lifecycle, authorization, capacity, policy or persistence rules were changed.
