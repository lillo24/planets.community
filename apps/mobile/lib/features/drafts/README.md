# Own drafts

This feature presents only unpublished records owned by the ready current actor.
Published/history management and delegated Projects stay in their existing modules.

- `domain/draft_entry.dart` owns typed Project/Tavolo/Donate/Exchange identity,
  existing editor destinations and `/drafts?types=project,table,donate,exchange`.
  Selected types compose with OR; no selected types means all four.
- `application/own_drafts.dart` derives cards from the existing three owner
  controllers, sorts by actual update time, and performs no extra backend reads.
  Their gateways exhaust canonical owner collections using bounded keyset pages;
  Project/Tavolo capacity queries honor the server's 100-ID request bound.
- `presentation/drafts_screen.dart` starts those three reads once per entry,
  shows each relevant source's pending/error state, retries failures, retains
  filters/scroll on editor return, and refreshes only the edited source once.
  Actor or readiness replacement clears the view and ignores old completions.

The folder actions in Projects, Tavoli and Scambio open contextual types. The
management menu retains `/proposals/mine`, `/tavoli/mine`, `/resources/mine`,
including published history and co-organizer work. DRAFT01 uncertain creation
recovery uses its original actor-bound request and existing editor route.

Cards use canonical owner cover metadata without placeholders. The local demo
world has four ordinary Giulia-owned drafts; see
[demo data](../../../../../docs/development/demo-data.md).
