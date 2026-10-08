# UI-NEXT-04 — Disabled location foundation

## Sequence and base

The user authorized UI-NEXT-01 → 02 → 03 → 04 as a preserved stack followed by
ordered merges, overriding merged-predecessor gates. Initial base is UI03
`8c59f434eb916b47519eaac3b734fa24a140b4f9` (#159), source `4e91f54`.
It incorporates UI02 `863b118` (#158), UI01 `6526a4a` (#156) and current main
`7054abc` (#157 Explore spacing). PR evidence records final tested/merge SHAs.

## Scope

The founder chose a disabled foundation retaining manual locations. The app-owned
gateway has no production adapter or activation flag. Its isolated transient
controller provides Italy restriction/Trento bias, IT/EN bounded requests,
debounce/sessions, explicit selection, failure states, expiry erasure and stale
completion rejection. Independent broad locality is distinct from exact precision.
None is persisted or copied into Project inputs.

The editor shows localized unavailable-search feedback and explains its single
existing visibility choice. All manual fields/instructions remain. Project detail
adds an inert map-unavailable message below canonical location information; it
accepts no point/ID/URL and creates no platform map or directions. No feed maps.
Participation still owns meeting authorization and actor-bound caches.

No schema/RLS/grant/type change, provider call, SDK/dependency, secret, GPS
permission, signing/identity change, licensing or paid deployment. Legacy manual
drafts, raw values, instants and normal recovery remain valid. The controller is a
tested future seam, not wired native search or live provider authorization.
See [activation requirements](../development/location-provider-readiness.md).

## Validation and reproduction

`npm run check:mobile` passed localization, formatting, analysis and 1,543 tests
with two existing skips. The 19 focused location tests passed. The Android debug
build and owned emulator-5580 interaction passed: public map fallback, manual
entry, visibility explanation and saved draft. Captures were inspected separately
from live-provider claims. Final hosted head/merge evidence is recorded in the PR.
No new database/Web contract is changed; their inherited stack remains
covered by predecessor checks and applicable hosted CI. Synthetic tests
need no provider credentials. They cover bounds, country filtering, mixed
suggestions, sessions, explicit selection, editing/cancel/expiry/disposal, late
responses and quota/offline/disabled/timeout errors; independent public area;
legacy non-Italian text-only save, first manual save and narrow dark EN/IT fallback.
Existing participation tests cover protected-meeting leave/removal and account
changes. Unit lifecycle hooks do not claim new live actor integration.

Reproduce: Browse → Create Project → From scratch. Search is unavailable; enter
normal country/locality/public label and separate instructions, review visibility,
then Save draft. Reopen a legacy draft from the folder and save a title-only edit.
Public Project detail retains permitted text and shows the inert map fallback.
No backend setup or geocoding is needed.

Android fallback rehearsal uses the opted-in UI02 fake-gateway harness built from
this checkout. iOS and real provider search/maps remain unverified on Windows and
without approved setup. Activation is a separately authorized task.
