# My activities

This feature owns the authenticated personal activity hub. Its legacy `/drafts`
route and `DraftKind`/editor-origin contracts are retained for saved links and
DRAFT01 recovery. The page now includes owned drafts, published records and
history for Projects, Tavoli, Donate and Exchange, plus a separate authorized
co-organized section. Ordinary joined Projects are not managed activities.

- `domain/draft_entry.dart` owns cross-domain identity, presentation status,
  contextual `types=` parsing and existing editor/owner destinations.
- `application/own_drafts.dart` adapts the three existing complete owner
  controllers without extra queries. `ownActivitiesProvider` sorts actual
  `updatedAt` descending, then type and ID, deduplicating by `(type, ID)`.
  `ownDraftsProvider` remains the unpublished subset for explicit draft callers.
- `presentation/drafts_screen.dart` owns two staged compact multi-select fields.
  Empty means All; choices use OR within each field and AND between fields.
  Contextual types preselect only Type. Source loading/errors remain independent;
  each Retry refreshes its source, and pull-to-refresh reloads all four sources.
  Idle invalidations are reloaded, including delegated authority after editor save.
  Returning from a row refreshes its source while preserving filters and scroll.
- `presentation/activity_card.dart` is the local horizontal row: 84–96dp square
  thumbnail, title, top-right status and one muted metadata line. Lazy slivers
  download only constructed viewport/near-viewport covers. At narrow widths or
  large text the pickers stack and the badge has its own right-aligned line.
- `presentation/activity_card_preview.dart` provides a Flutter widget preview;
  `test_support/myhub01_preview.dart` is its standalone runnable entry.

Published completed/just-finished Projects and ended Tavoli group as Finished;
paused and cancelled remain distinct, and closed Resources retain Closed.
Unpublished Ideas remain Draft. These are presentation groupings of canonical
states, not backend transitions. Owned rows show genuine update dates. Delegated
rows sort by grant date separately, show the current Co-creator/Co-organizer role,
and open the canonical role-checked management screen without inventing edit power.

Drafts open guarded editors with typed `DraftEditorOrigin.hub`. Project, Tavolo
and Resource draft saves/publishes return to the hub. Focused owner controls pass
the same origin to nested editors so their save/close does not replace the hub. Non-draft rows open the established
owner route with `?item=<id>`, focusing its existing lifecycle/request actions.
Unfiltered `/proposals/mine`, `/tavoli/mine` and `/resources/mine` still work.
DRAFT01 pending-create recovery and actor replacement guards are preserved.

Owner cover projections may contain moderated records; published lifecycle alone
cannot establish public media access. All hub owner covers use the bounded private
session cache described in [cover media](../cover_media/README.md). Public
browse retains the existing immutable public provider. Covers never gate titles
or status. This change makes no claim to diagnose the older Bozze error;
DRAFTFIX01 remains deferred.

See [MYHUB01 verification](../../../../../docs/development/myhub01-my-activities.md)
for screenshots and repeatable checks.
