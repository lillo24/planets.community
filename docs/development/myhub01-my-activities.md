# MYHUB01: My activities

The existing `/drafts` folder now opens **My activities / Le mie attività**. Its
Type and Status fields open staged multi-select sheets; Apply commits, dismiss
cancels, and Clear + Apply restores All. Type choices combine with OR, status
choices combine with OR, and the two dimensions combine with AND. Contextual
`types=` links retain all statuses by default. There are no permanent filter-chip
rows, extra filter headings or management overflow.

Owned Project, Tavolo, Donate and Exchange records share a lazy updated-first
list. The compact local cards have 84–96dp left thumbnails, wrapping titles,
small status badges and one type/date line. At 320dp/2× text selectors stack and
badges remain right-aligned above the title. EN/IT and light/dark use the same
layout. Co-organized work follows separately with role labels and grant-date
ordering; it never claims an unknown content update time.

Legacy owner routes continue to work. Non-draft rows use their optional `item`
query to focus the established controls, including terminal/read-only cases.
Drafts use the original guarded editors. Their save/publish return preserves
hub filters; only the affected owner source refreshes. Source errors remain
explicit and local; successful sibling rows remain visible. DRAFT01 uncertain
creation recovery stays actor-bound. DRAFTFIX01 is deferred; no old unexplored
Bozze error is claimed fixed.

Private covers use a session LRU capped at 32 entries and 8 MiB, with no disk or
bulk history preload. Owner projections can include moderated records, so hub
covers remain actor-scoped even when published. Public discovery retains its
public immutable-path provider. Sign-out/readiness/account replacement, observed
authorization loss, memory pressure, backgrounding and disposal purge private
bytes/decoded keys, and stale completions cannot refill the cache. Pull refresh
revalidates after authorization failure. First fetch/decode still takes time.

## Reproduction and evidence

From the repository root run `npm run check:mobile`. Focused checks from
`apps/mobile` are:

```text
flutter test test/features/drafts/drafts_test.dart test/features/cover_media/application/owner_cover_cache_test.dart test/features/cover_media/presentation/project_cover_image_test.dart test/app/router/navigation_shell_test.dart
flutter test test/features/drafts/drafts_test.dart --plain-name "hub rendered" --dart-define=UI_POLISH_CAPTURE_DIR=<absolute-output-directory>
```

The matrix captures actual Flutter-rendered widgets with real fonts and the
repository's garden-tools cover fixture in EN/IT, light/dark, 390dp/1× and
320dp/2×, including picker sheets. These synthetic fixtures do not access a
hosted backend or prove a real-phone session. The layout assertions check row
and thumbnail bounds and absence of framework overflow errors.

Cache tests measure one gateway download across disposal/revisit, one additional
download for a changed immutable path, rejection without a download for another
actor, refetch after cache invalidation, stale-completion rejection, authorization
loss and both LRU limits. Full validation and selected screenshots are recorded
with the PR after final review. No staging SQL, provider write, phone installation,
production deployment or Play upload is part of this change.
