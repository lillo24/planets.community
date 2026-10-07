# Proposals feature

This feature owns one-time proposal discovery and authenticated structural
management for the immutable Creator and current Co-creators.

SIM02 adds automatic unpublished-editor suggestions through the narrow
`domain/similar_proposal.dart` DTO/query, `data/similar_proposal_gateway.dart`
RPC parser, `application/similar_proposal_controller.dart` actor/session debounce
and `presentation/similar_proposal_suggestions.dart` inline entry/sheet.
`proposal_editor_screen.dart` observes only matching fields and fully dismisses
the sheet before ordinary guarded detail navigation. Published editors never
match. See [inputs, lifecycle and draft handoff](../../../../../docs/development/automatic-editor-suggestions.md).

TW04 adds Browse and unpublished-editor entries to the sibling
`template_workshop/` feature. The separate **Create from a template** action
pushes through the existing draft departure guard; it preserves this editor
and opens any accepted copy in a different editor by its canonical ID.
Near publication, IT/EN copy explains automatic eligible reuse at Completed
(end + 24 elapsed hours), including open resource descriptions and free-text
responsibility. Ordinary blank creation, My Proposals and Tavoli remain intact.

- `domain/` defines proposal, lifecycle, status, skill and time-zone models.
- `data/` calls only the canonical Supabase proposal RPCs and reads the existing controlled skill catalog.
- `application/` coordinates pagination, requester-only Requested enrichment, detail loading and race-safe owner commands. Every owner mutation carries the identity for which the screen was rendered.
- `presentation/` contains public list/detail screens and complete-profile create/edit/my-proposals screens.

`presentation/proposal_widgets.dart` places only the requested-participation
badge at the top-right of the public card cover (including its placeholder).
The lifecycle badge stays beside the title; requested borders, text, semantics
and card navigation retain their existing behavior.

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

Projects Browse keeps its compact query visible without a character counter.
Locality and the staged skill selector start collapsed behind one filter
button. A badge marks applied locality/skills even while collapsed. Toggling
only changes visibility: text controllers retain pending input and provider
state retains applied filters, results, and pagination.

Browse owns list, detail, mine and editor routes inside the app's stateful shell.
Switching tabs preserves list scroll/filters and saves meaningful dirty unpublished
Proposal content before switching. Published edits remain deliberate. Identity
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

Cover add/change/remove choices stay local to the editor until Save, Publish or guarded draft departure.
If cover persistence fails after content succeeds, the controller retains the
same draft and reports whether a draft or later changes were saved. Public and
owner cards/details consume only the canonical `coverObjectPath`; they do not
issue per-card metadata RPCs.

In My Proposals, only the cover opens a proposal: published records use the
public detail route; drafts and cancelled records use the guarded owner editor
(cancelled records stay read-only). The cover keeps owner-authorized image
loading, with a Material tap target over both images and placeholders. Resources,
Edit, Publish, and Cancel remain separate controls below it.

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
developer chooses Save draft, Publish or leaves the meaningful draft. Save/publish validation shows a fixed field-name summary
that remains visible while the form scrolls, inline errors for text, timezone,
country and schedule controls, and brings the first mounted invalid field into
view. Drafts keep their intentionally optional fields while still validating
any values that were supplied.

09B2 composes the separate blocking feature on public organizer detail. The
Proposal and organizer remain visible; caller-owned organizer blocks replace a
new Join action with an Unblock path, while inbound-only denial stays generic.

Draft creation, draft saving, and publication remain original-Creator-only.
Drafts may omit registration capacity, but publication requires 1–100,000
spots. The editor also persists whether the Creator and active organizers use
spots; this defaults off. Public cards and detail show ordinary-participant
usage, the organizer breakdown, unique people involved, Full, or the legacy
“Registration capacity not set” state. A Creator or current Co-creator may
change both settings only while the same structural content is editable and
never to a combination below current derived usage; a legacy published
Proposal must receive a capacity on its next structural save.

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

DRAFT01 gives each editor a separate session controller, immutable raw
acknowledgements (`application/proposal_draft_session.dart`) and a stable
actor/request first-creation key. `presentation/own_proposals_screen.dart`
offers explicit recovery for unresolved opaque in-memory creation markers.
The editor registers with the app router's departure coordinator; invalid
fields stay editable and partial image failures retain the same draft. See
[save-before-navigation and recovery](../../../../../docs/development/proposal-draft-departure.md).

## UI-NEXT-02 discovery and drafts

Public controls remain mounted during idle/loading/error/empty results. Same-query
refresh retains rows and reports progress/failure; changed filters clear previous
rows. Owner/delegated loads settle independently, never refetch a completed peer
because its sibling is pending, and clear private caches on readiness changes.
The folder action opens `/drafts?types=project`; the hub's management menu retains
this feature's published/history/co-organizer screen and DRAFT01 recovery.
