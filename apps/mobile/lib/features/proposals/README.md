# Proposals feature

This feature owns one-time proposal discovery and authenticated structural
management for the immutable Creator and current Co-creators.

- `domain/` defines proposal, lifecycle, status, skill and time-zone models.
- `data/` calls only the canonical Supabase proposal RPCs and reads the existing controlled skill catalog.
- `application/` coordinates pagination, requester-only Requested enrichment, detail loading and race-safe owner commands. Every owner mutation carries the identity for which the screen was rendered.
- `presentation/` contains public list/detail screens and complete-profile create/edit/my-proposals screens.

`presentation/skill_filter.dart` adapts the shared compact tag selector for a
staged discovery filter. The bounded bottom sheet uses searchable category
headings and chip/button toggles, Apply sends the entire ID set once, and Clear
stages an empty selection. Dismissing without Apply discards the pending
selection. Reopening starts from the applied IDs, and search does not focus or
open a keyboard until explicitly tapped. The public list displays at most two
skill badges plus `+N more`; locality and the literal free-text query compose
with the skills using backend OR-within-skills semantics. The reference
`general_modular_components` Fancy Multi Select was inspected for its
controlled selection, compact-tag, search, bounded-surface, and clear-action
patterns; the implementation remains native Flutter without React/CSS reuse.

The Browse query is trimmed, limited to 120 characters, and debounced for 350
milliseconds, while submit flushes immediately. Both the paginated public RPC
and the authenticated pending-request projection receive the same query. The
database applies a case-insensitive literal substring match across title,
summary, and description, so `%` and `_` have no wildcard meaning. Controller
revisions keep pagination on the active query and reject late results from an
older filter set.

Browse owns list, detail, mine and editor routes inside the app's stateful shell.
Switching tabs preserves the list scroll/filters and an unsaved editor. Identity
changes discard the shell's retained stacks and clear owner controllers. Revision
checks after each await reject late loads/mutations and prevent an old draft
creation from proceeding to publish in a later session. Every owner RPC still
receives the form's expected identity.

The public client never reads proposal tables directly. Rough location is available on public cards; exact meeting text is rendered only when the sanitized detail RPC returns it. The shared `participation/` feature adds request/member actions and may replace the restricted explanation with participant-authorized operational meeting text without adding that data to Proposal models. Recurring activities, maps and media remain outside this feature.

For a ready authenticated identity, Browse loads the raw public first page and
the filtered own-pending projection in parallel. Requested cards render first
with a localized semantic badge, and matching raw public cards are hidden only
at presentation time. Raw pages still own the cursor and `hasMore`; signed-out
sessions never call the personalized RPC. Account, filter, pull-refresh, and
own-participation revisions refresh or clear the projection without turning a
private-read failure into a public-feed error.

Public details are self-contained: they show the localized start/end schedule in the event's named timezone and the same Required/Useful skill labels as cards. The editor stores UTC instants, initializes both pickers from event-zone wall time, and keeps those instants unchanged while timezone text is invalid. Invalid timezone input displays a validation message and cannot open a picker; correcting the timezone refreshes the schedule without silently changing the instants.

The time helpers explicitly support the existing `UTC` default as an alias for `Etc/UTC`, because the bundled timezone dataset excludes that legacy alias.

In debug builds, new-proposal forms expose a **Fill sample data** action with
synthetic values and a future schedule; the control is removed at compile time
from release builds and never persists or sends data until the developer chooses
Save draft or Publish. Save/publish validation shows a fixed field-name summary
that remains visible while the form scrolls, inline errors for text, timezone,
country and schedule controls, and brings the first mounted invalid field into
view. Drafts keep their intentionally optional fields while still validating
any values that were supplied.

Draft creation, draft saving, and publication remain original-Creator-only.
Drafts may omit People capacity, but publication requires 1–100,000 total
people including the immutable Creator. Public cards and detail use the shared
participation aggregate (`Creator + current memberships`) to show occupancy,
Full, or the legacy “Capacity not set” state. A Creator or current Co-creator
may change capacity only while the same structural content is editable and
never below current occupancy; a legacy published Proposal must receive a
capacity on its next structural save.

For an existing published Proposal, the shared editor instead shows **Save
changes** and never invokes the draft-only publish operation. Content becomes
read-only once the Proposal starts, while cancellation remains available until
the canonical end boundary. Completed and cancelled Proposals expose no
mutation controls. Cancellation is a retained-history transition rather than
deletion and does not change participation or delegated authority.

The editor uses the exact structural management read for both Creator and
Co-creator access. Co-organizers and stale/demoted/revoked Co-creators fail
closed. Successful structural mutations refresh the exact record and affected
owned, delegated, public-list, and public-detail state.
