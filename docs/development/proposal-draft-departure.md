# Proposal draft departure (DRAFT01)

DRAFT01 is implemented on the explicitly selected TW03 head
`49742135f3fbd144abb5bce0d87d3b8ca43bacbc`. Its draft PR targets
`codex/tw03-template-to-draft-backend`. Founder review and predecessor/main
integration remain pending; this does not authorize merge or deployment.

## Session and acknowledgement

Each `ProposalEditorScreen` owns a UUID and a separate
`proposalEditorSessionProvider`. Its controller binds the actor and first
canonical Proposal ID. A `/proposals/create` route retains that binding after
saving; it does not compare the new ID with a null route argument. Retained
offstage tabs keep their session alive despite Riverpod subscription pausing.
Actual screen disposal releases that retention and invalidates pending results;
it never starts an asynchronous final save.

`proposal_draft_session.dart` captures immutable raw text, skill importance,
UTC dates, privacy, organizer capacity choice and cover revision. The form
compares against the original or confirmed acknowledgement. Empty/whitespace
new forms with default UTC/privacy create nothing. Tags, dates, changed options
and covers are meaningful. Clearing an existing draft is a real change.

Every save captures one form/image revision. The finite form retains built
validators and pending image state while scrolling. Controls freeze during persistence;
an acknowledgement cleans only its captured revision. If newer input arrives,
departure remains blocked until that input is saved. Manual draft saves,
departure saves and deliberate publication share the same controller and reject
overlapping writes. Published editing continues to use deliberate Save changes
and canonical authority/start-time rules; departure never invokes it.

## Canonical first creation and recovery

`20261004200147_idempotent_editor_draft_creation.sql` adds authenticated-only
`create_editor_proposal_draft` and `recover_editor_proposal_draft` RPCs.
Existing `create_proposal_draft` overloads and callers remain available.

Creation carries expected actor, request UUID and the frozen initial payload.
The server hashes the typed payload in UTC, serializes the actor/request with
the `proposal.draft_create:` advisory namespace and calls ordinary complete-
profile sparse creation. Parent and receipt commit atomically. The private
append-only receipt contains actor/request/Proposal IDs, acceptance time and
intent hash; no content copy, public usage record or edit history is added.
RLS has no raw policies; anon, authenticated and service_role have no raw access
or service-role RPC bypass. Restrictive references preserve accepted identity.

An exact accepted retry returns its existing destination without reapplying
content, including after later owner edits/publication or profile incompleteness.
Incompatible accepted-key reuse fails. Unavailable recorded destinations fail
instead of creating another parent. The narrow owner recovery read takes the
same advisory lock before returning a confirmed ID or an absent receipt.

The controller preserves its original request and creation input through a
lost response, recovers by exact delivery, then applies newer edits through
ordinary owner update. A confirmed ID is bound before cover/read awaits, even
when canonical rereading fails. Subsequent retries update that ID.

Opaque actor/request markers survive form disposal in the application provider.
My Proposals offers explicit Recover draft for the current actor's unresolved
markers; it does not silently choose a latest draft. Markers contain no raw
meeting text, address, image bytes or credentials, and are not authorization.
They are process-memory only. After process termination, confirmed drafts remain
discoverable through ordinary My Proposals; there is no force-kill save/recovery
promise. A fresh explicit Create action starts a separate session/request.

TW03-derived drafts already have an ID and use ordinary update/read. DRAFT01
does not rerun template application, recopy needs or alter immutable provenance,
and editing does not require the source template to remain available.

## Navigation, invalid input and feedback

`DraftDepartureCoordinator.prepare` exposes explicit no-change, saved, blocked,
discarded and partial outcomes for future Workshop/similar-Project callers.
The application router's go_router 18 `onEnter` covers go/push/replace/restore,
including retained shell tabs and Home reset. Editor `onExit` covers app-bar,
system and supported committed gesture pops before page removal.
Proposal routes explicitly build Flutter Material pages: go_router 18 detects
its separate `material_ui` app type, while this app uses Flutter's MaterialApp.
Explicit pages preserve platform transitions and iOS swipe handling rather than
falling back to pages without transitions.
Only the active page/branch owns departure; hidden or nested editors do not intercept unrelated
navigation. Repeated requests are ignored while preparing. If a competing router
parse cancels the first transaction token, the coordinator replays its exact
public RouteInformation after blocking the competing action, preserving original
operation, extra, back-stack and push completion. Dialogs, pickers and native crop routes are temporary subflows.

Invalid title, raw capacity, country, supplied timezone or reversed dates stay
visible. Raw validators run before `int.tryParse` could erase a bad value.
Ordinary server draft limits remain unchanged; the mobile editor additionally
requires a supplied timezone to be recognized, preserving existing UTC instants.
Failure keeps the editor available with field errors and Keep editing / Discard
unsaved changes. Discard never deletes a persisted draft, receipt or template,
and unresolved creation markers remain available for explicit recovery.

Core content commits before optional cover reconciliation through the existing
cover subsystem. Cover failure retains the same ID and processed selection.
Keep editing permits retry. Explicit Leave without image change acknowledges
the committed core and emits localized partial feedback, never plain Draft saved.
The image outcome is described as unconfirmed: a lost cover commit response can
leave its canonical result uncertain even though core content committed.
Read/reconciliation failures do not count as whole-save success. Successful cover
acknowledgement resets only that specific local preview revision; stale-object
cleanup remains best effort and separate from canonical persistence.

The app ScaffoldMessenger delivers `Bozza salvata` / `Draft saved` after the
destination frame and only for the same actor and confirmed revision. An active
outgoing editor, cancelled navigation, empty/unchanged form, explicit discard,
uncertain save or publication cannot emit that message. Forced sign-out/access
loss bypasses saving and drops callbacks/feedback. A same-actor profile recheck
invalidates pending work but preserves retained bindings and departure owners.
No private form content enters telemetry, routes, settings or snackbar bodies.
If the same account loses profile readiness, its private form is discarded;
returning to readiness reloads the route's authorized record and registers a new
departure owner, rather than keeping a reset session in a loading loop.

go_router's onEnter parsing yields before its first route match. Auth restoration
does not regenerate nonexistent retained stacks while the configuration is
empty; dynamic auth readers still apply redirects. Once a route exists, account
changes replace branch keys as before.

## Validation and integration boundary

`114_editor_draft_creation_structure.test.sql` audits receipt/RPC hardening.
`npm run draft:editor:verify:local` uses synthetic real OTP identities on a
loopback-only disposable stack to verify authorization, retries, rollback,
publication/photo gates and ordinary TW03 reopening after template removal with
unchanged receipt/need IDs. Database CI runs this command explicitly and preserves
TW02/TW03 steps. Workflow/root-package changes select all existing validation
areas; manual `check:db` still includes the complete suite.

Mobile tests exercise raw acknowledgement, route/session isolation, RPC payloads,
Back and destination feedback, dirty sparse forms, failure/retry and partial
cover outcomes. Native device gesture checks and iOS builds require their
supported environment; a Flutter widget gesture test is not native-device QA.

TW04/SIM01/SIM02/TW05 remain deferred. At later main integration, inspect then-
current #128/#131 Project links/auth returns/admission and exercise departure
with incoming links. Those stacks are not imported into these unmerged branches.
