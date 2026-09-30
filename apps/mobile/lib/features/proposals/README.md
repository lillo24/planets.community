# Proposals feature

This feature owns one-time proposal discovery and authenticated owner management.

- `domain/` defines proposal, lifecycle, status, skill and time-zone models.
- `data/` calls only the canonical Supabase proposal RPCs and reads the existing controlled skill catalog.
- `application/` coordinates pagination, requester-only Requested enrichment, detail loading and race-safe owner commands. Every owner mutation carries the identity for which the screen was rendered.
- `presentation/` contains public list/detail screens and complete-profile create/edit/my-proposals screens.

`presentation/skill_filter.dart` owns the compact, searchable Skills popover:
categorized checkboxes stage a selection, Apply sends the entire ID set once,
and Clear all stages an empty selection. Dismissing without Apply discards the
pending selection. Reopening starts from the applied IDs. Search does not focus
or open a keyboard until explicitly tapped. The public list displays at most
two skill badges plus `+N more`; locality composes with the skills using the
existing backend OR semantics. The reference `general_modular_components` Fancy
Multi Select was inspected for its controlled selection/badge/search pattern;
this is a native Flutter MenuAnchor implementation, without React/CSS reuse.

Browse owns list, detail, mine and editor routes inside the app's stateful shell.
Switching tabs preserves the list scroll/filters and an unsaved editor. Identity
changes discard the shell's retained stacks and clear owner controllers. Revision
checks after each await reject late loads/mutations and prevent an old draft
creation from proceeding to publish in a later session. Every owner RPC still
receives the form's expected identity, and publication remains
database-authoritative.

Draft creation and editing remain available without a profile photo. Publish
performs a local owner-metadata preflight for guidance, while
`publish_proposal` authoritatively requires a current canonical photo for the
actual draft-to-published transition. Either photo audience qualifies. The
detail screen loads the organizer avatar through the distinct Project-context
photo boundary and degrades to a placeholder independently of detail content.

The public client never reads proposal tables directly. Rough location is available on public cards; exact meeting text is rendered only when the sanitized detail RPC returns it. The shared `participation/` feature adds request/member actions and may replace the restricted explanation with participant-authorized operational meeting text without adding that data to Proposal models. The sibling `cover_media/` feature owns optional cover processing, persistence orchestration, and loading; Proposal controllers create/update the parent before cover reconciliation and publish only after it succeeds. Recurring activities and maps remain outside this feature.

Cover add/change/remove choices stay local to the editor until Save or Publish.
If cover persistence fails after content succeeds, the controller retains the
same draft and reports whether a draft or later changes were saved. Public and
owner cards/details consume only the canonical `coverObjectPath`; they do not
issue per-card metadata RPCs.

For a ready authenticated identity, Browse loads the raw public first page and
the filtered own-pending projection in parallel. Requested cards render first
with a localized semantic badge, and matching raw public cards are hidden only
at presentation time. Raw pages still own the cursor and `hasMore`; signed-out
sessions never call the personalized RPC. Account, filter, pull-refresh, and
own-participation revisions refresh or clear the projection without turning a
private-read failure into a public-feed error.

Public details are self-contained: they show the localized start/end schedule in the event's named timezone and the same Required/Useful skill labels as cards. The editor stores UTC instants, initializes both pickers from event-zone wall time, and keeps those instants unchanged while timezone text is invalid. Invalid timezone input displays a validation message and cannot open a picker; correcting the timezone refreshes the schedule without silently changing the instants.

The time helpers explicitly support the existing `UTC` default as an alias for `Etc/UTC`, because the bundled timezone dataset excludes that legacy alias.

When demo tools are enabled, new-proposal forms expose a **Fill sample data**
action with synthetic values and a future schedule. The configuration gate is
hard-off in production, and the preset never persists or sends data until the
developer chooses Save draft or Publish. Save/publish validation shows a fixed field-name summary
that remains visible while the form scrolls, inline errors for text, timezone,
country and schedule controls, and brings the first mounted invalid field into
view. Drafts keep their intentionally optional fields while still validating
any values that were supplied.

09B2 composes the separate blocking feature on public organizer detail. The
Proposal and organizer remain visible; caller-owned organizer blocks replace a
new Join action with an Unblock path, while inbound-only denial stays generic.
