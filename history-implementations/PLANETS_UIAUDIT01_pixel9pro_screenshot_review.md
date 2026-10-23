# PLANETS UIAUDIT01 - Pixel 9 Pro screenshot review

## Goal and authority

Run the current PLANETS Android app, visit every distinct mobile page and significant dialog/sheet, capture it, **open and visually inspect every screenshot**, and deliver a finished review that Leonardo can read comfortably on his phone.

The review must identify visible defects, confusing behavior, unnecessary/debug-oriented copy, and worthwhile UI improvements. Each proposal needs a permanent ID such as **A1, A2, B1**, so Leonardo can reply `A1 yes, A2 no, B1 yes`.

Complete the capture, inspection, comments, and final files in this task. A capture script, a route list, a contact sheet, or instructions for Leonardo to assemble the report are not the requested result.

General UI changes remain proposals for Leonardo's review. The one narrow implementation exception is a proven, small duplicate-chat regression described below. Do not turn this audit into a redesign or a new reporting product.

Read `AGENTS.md`, relevant nested instructions, `docs/development/codex-tooling.md`, and the current architecture before implementation. Use an isolated task branch/worktree, preserving unrelated work. Follow the repository's PR, validation, merge, and cleanup workflow for any committed audit tooling or safe bug fix. Merging the review does not approve its proposed UI changes or authorize an app-store release.

## External inputs and evidence boundaries

**Reference image:** `Screenshot_20261023-102754.png`, attached separately to this Codex task. A local upload may have a numeric filename prefix. Locate the supplied attachment; do not assume access to the ChatGPT conversation or a previous machine's absolute path.

The image shows Italian dark-mode **Messaggi > Privato** with two rows bearing the same person's displayed name. One has date **14/10/2026** and preview **"Ancora nessun messaggio."**; the other has **12/10/2026** and **"Richiesta accettata"**. Leonardo reports this is his real account and the same person, and wants a quick fix if one is justified. The installed app version and backend state are not established by this image.

If the image is unavailable, explicitly report the missing input and stop only the image-dependent reference comparison. Continue the independent native audit. Do not recreate or invent the missing screenshot, its account IDs, or its hidden state. No external product document is required for this task.

Use fictional data for new captures and interactions. Keep the supplied real-account screenshot and any personal payloads out of public GitHub commits. It may be included in the review delivered privately to Leonardo. Do not publish credentials, OTPs, sessions, invitation capabilities, real messages, or unredacted account diagnostics.

## Repository evidence checked while preparing this prompt

Planning baseline: `main` at **9945ad0102218f69acbafd543d8112aa8fa90cec**, rechecked **23 October 2026** after PR #297 integrated Find People, Communities, meetings, and related Mock Mode changes. The initial inspection was at `33f0309bcc02c2a54b872210c4f6ec51a6ccc731`, with mobile version **0.1.10+14**. Start execution from the latest appropriate `main`, recheck these references, and record the actual audited source. These are navigation aids, not instructions to freeze an old checkout.

| Area | Current places to inspect and reuse |
| --- | --- |
| Route inventory and navigation conventions | `apps/mobile/lib/app/router/app_router.dart`, its `README.md`, feature navigation and in-screen dialogs |
| Native capture setup and drivers | `apps/mobile/integration_test/README.md`, `apps/mobile/test_driver/README.md` |
| Existing complete Android capture workflow | `docs/play-store-assets/README.md` and capture provenance; reuse the method, not old screenshots or its old device geometry |
| Local data and setup | `docs/development/getting-started.md`, `docs/development/demo-data.md`, root `package.json` |
| Shared mock environment limitations | `docs/development/mock-environment.md`, `docs/development/mock-mobile-sessions.md`; prior status files are historical observations |
| Find People, Communities, meetings and local fixtures | `apps/mobile/lib/features/co_creation/README.md`, `docs/development/cocreate-experimental-contract.md`, `docs/development/cocreate-fill01.md`, `scripts/seed-local-cocreate.mjs` |
| Inbox implementation | `apps/mobile/lib/features/messages/{domain,application,data,presentation}/`, especially `message_chat_models.dart`, `message_chats_controller.dart`, `message_chats_gateway.dart`, `messages_screen.dart` |
| Participation chat contract | `docs/architecture/decisions/0007-participation-pair-conversations.md` and its canonical migrations/tests |

Useful existing native journeys include `batch_a_smoke_test.dart`, `groups_smoke_test.dart`, `group_membership_smoke_test.dart`, `group_discussion_smoke_test.dart`, `group_contact_smoke_test.dart`, `member_contact_smoke_test.dart`, Workshop, tutorial, map, and navigation-header probes under `apps/mobile/integration_test/`, with their preparation scripts and host drivers.

Some probes inject identities, fake gateways, or presentation-only routers. Identify those boundaries before reusing them. An injected session does not verify the sign-in UI; a presentation fixture does not prove canonical routing, backend authorization, or a live-account repair.

The host drivers already address excessive memory use from serializing screenshot bytes twice. Reuse their PNG-plus-metadata pattern; do not embed every PNG as a huge integer array in JSON.

## 1. Establish the run and capture environment

1. Inspect tools, the current worktree, available Android SDK/AVDs, Flutter version, and capture helpers. Reuse supported tooling and narrow official skills where available; do not introduce a new automation framework without a concrete need.
2. Use a **task-owned Pixel 9 Pro Android emulator**, portrait. Prefer its SDK hardware profile. If absent, create a matching custom profile from verified Android/Google documentation where feasible. Use a compatible installed system image and record its exact Android/API version.
3. Verify actual Android display size, logical density, font scale, safe areas, and navigation mode. Pixel 9 Pro physical panel specifications are 1280 x 2856; those pixels and physical PPI are **not** sufficient to infer Android's logical layout size. Do not simulate the device by resizing screenshots or using a browser viewport. If a substitute device/image is necessary, identify it accurately and explain the resulting coverage limit.
4. Main pass: **Italian, dark mode, default text/display scaling**, matching the reference's language and theme. Keep the soft keyboard enabled for input checks. Add focused light-mode, English, and increased-text checks on screens where they can reveal a different problem; avoid a blind multiplication of every state by every setting.
5. Prefer a release-like native build with normal product widgets, no debug banner, and normal production feature configuration. A native integration build is acceptable when required by the capture harness, but identify it and verify any suspected developer-only text against a normal build before calling it a shipped defect. Audit closed-test-only screens separately.
6. Use a **new disposable local canonical backend** with synthetic identities for mutation journeys, following existing setup/seed scripts. Verify target ownership, project ID, ports, and Mailpit configuration before a reset. Do not reset a retained demo, staging, production, or the shared hosted mock world. The hosted fictional world is shared and mutable, not a disposable per-person sandbox.
7. Use a fresh run directory. Record source SHA, dirty patch if any, app version/build, build mode/flags, backend type and migration provenance, device/OS/settings, timestamp/timezone, and capture method. Separate latest-source observations from the supplied installed-app evidence.

If local native execution is blocked, resolve ordinary tool/setup issues autonomously where permitted. Complete the inventory and other possible work, then report the exact blocker and partial status. Do not present browser renders, widget goldens, old captures, or source-only judgments as a completed Pixel audit.

Official device/capture references:
- https://developer.android.com/studio/run/managing-avds
- https://developer.android.com/studio/run/emulator-take-screenshots
- https://support.google.com/pixelphone/answer/7158570

## 2. Make "every page" auditable

Build a route-and-state inventory from the **current router plus feature code**, including pushed pages, sheets, dialogs, menus, and native handoffs. A filename search for `*_screen.dart` is insufficient.

Cover these implemented families, rechecking actual availability rather than inventing screens:

| Family | Required scope where implemented/reachable |
| --- | --- |
| Entry and authentication | Welcome, all tutorial steps, sign-in choice, email and OTP, required profile setup, policy acceptance, unavailable/invalid link |
| Home and discovery | Home, Projects, Tavoli, Scambio/Dona, search/filter/sort controls, contextual maps, external Activities and detail |
| Profile, settings, help | Own/public profile, profile preview/editor, photo/crop flow, language, visibility, navigation preference, notifications/preferences, Help/contact/bug guidance, account-deletion confirmation |
| Projects and Tavoli | Detail, own lists/My activities/drafts, create chooser/editor, edit, template Workshop/catalog/detail, suggestions, needs/resource matches, join, participants, management/team, workspace, participant and organizer invitations |
| Scambio/Dona | Browse/detail, own listings, create/edit, categories/filters, saved searches, loan schedule, requests, agreement/chat states |
| Messages | Chats and Requests, Private and Groups, each implemented conversation kind and detail/info view, unread/read, empty/populated, pending/accepted/rejected/withdrawn/read-only/blocked/history states where visually different |
| Registered Groups | Directory/detail/report, create/edit/structural edit, My groups, People, memberships/requests/Team/offers, histories, roles, links and invitations |
| Group discussions and Ideas | General/Ideas lists, creation, chat, People, invitation/consent/link/leave/decline, history, Idea-to-Project conversion/planning states |
| Personal/representative contacts | Member-contact and group-contact compose/request/chat/info, coordination proposals and consent |
| Safety | Blocked people, reports and own reports, evidence requests, corroboration and counterstatement UI |
| Closed-test-only surfaces | Persona selection, unavailable/recovery/boundary/return-to-normal UI, clearly marked as test-app-specific |

Also audit the newly integrated **Find People / Co-Creation** family: intro/replay; browse/filter/detail; create/edit/My posts; interests and author responses; accepted-contact chat and close/withdraw; Communities categories/proposals/support/Your interests; hub join/General; numbered groups and People/settings/leave; timed meetings/RSVP/recruitment; source-to-native-Project and external-event handoffs; Messages/notification integration and gate-OFF recovery.

Treat the local **Co-Creation presentation setting**, the **server experiment gate**, and the **Mock backend realm** as separate axes. Co-Creation and Activities Split are now mutually exclusive presentation selections; switching them does not silently switch the account. Cover the distinct UIs with legitimate task-owned local fixtures, enabling the local server gate only through the documented fixture setup. Turning the presentation OFF preserves existing Messages and own-exit routes. Clearly label `/people/demo` previews as fictional presentation-only screens. The source merge does not prove hosted migration/activation or installed-app delivery; do not activate a shared server to obtain screenshots.

Do not expand this into a full independent web/admin/iOS audit. Include external browser/native screens only where needed to understand a mobile flow, and label the boundary.

For every distinct page, capture a normal meaningful state. Where relevant add empty, loading, error/retry/offline, validation, keyboard-open, long-content, and role-specific states. Use at least guest, ordinary member/requester, and creator/organizer fixtures where their visible UI differs. Use legitimate local authorization; do not weaken access rules to obtain screenshots.

Inspect long screens top to bottom and capture successive viewports or clearly labeled continuations. The first viewport alone is not coverage of controls below the fold. Test forms and sheets with the keyboard open, plus representative long Italian labels/names and larger text. Use fresh coherent fixture dates instead of silently treating expired demo events as ordinary future activities.

Avoid redundant captures for aliases of identical UI; map every alias to the shared evidence and explain the equivalence. Add states when they reveal different controls or a concrete layout risk. No arbitrary screenshot limit or "one page per feature" shortcut.

Every inventory entry must end as **captured**, **blocked with reason**, or **not applicable with evidence**. Track planned/captured/visually-reviewed counts. Empty results do not substitute for populated-state coverage.
For the mixed Messages inbox, explicitly capture **no native chats plus an existing Find People contact**, and **no native requests plus an existing People/discussion request**, as well as mixed-kind ordering/pagination. Current source composition suggests a risk of contradictory empty-state copy beside populated added sections; verify the rendered state before recording a defect.

## 3. Investigate the reported repeated private-chat rows first

Keep this investigation bounded so it does not stall the whole review. Preserve the reference as screenshot **A** if supplied; reserve **A1** for this reported problem. New native captures start at B and can cross-reference A1.

Current-source evidence makes a cross-domain explanation plausible:
- `resourceChatNoMessages` in `app_it.arb` is "Ancora nessun messaggio."; the inbox uses it for an empty Resource chat.
- A participation-request activity can produce "Richiesta accettata".
- Both kinds use the counterparty name as their card title.
- ADR 0007 unifies Project/Tavolo participation history for a pair but explicitly preserves Resource conversations separately. Newer personal member contacts are also group-scoped.
- Current Find People also appends post-scoped accepted-contact rows through `PeopleContactItems`; these are a separate section, not another v7 `MessageChatItem` kind. Include this domain in inbox coverage where enabled.

Treat that as a hypothesis to verify, not a conclusion about Leonardo's installed build.

Inspect typed list results and routes: conversation kind, chat ID, counterparty profile UUID, and relevant request/agreement/group identity. Keep personal diagnostics private and sanitized. Reproduce with synthetic same-pair participation requests, reversed roles, a Resource request, and relevant member contacts. Compare refresh, paging, reopening, and account-switch behavior when indicated.

Distinguish:
- the same `(kind, chatId)` projected more than once;
- multiple participation anchors that violate the canonical same-pair invariant;
- separate legitimate chat domains for the same two people;
- different accounts sharing a display name;
- a source/APK/backend migration mismatch.

**Never deduplicate by display name or hide a conversation just because its counterparty matches another row.** Do not merge histories, discard messages, or relax access rules to make the inbox look cleaner.

If there is a verified small regression under the existing contract, Leonardo authorizes a narrow fix: preserve messages, references, unread/read semantics and authorization; add the focused regression check; keep baseline and after evidence. Use a separate clearly labeled commit so the fix is distinguishable from review artifacts. Any schema correction must be a new reviewed migration, not a rewrite of applied history.

If the rows are different legitimate domains, record the user-facing ambiguity as A1 and give **one concrete recommended proposal**, for example a compact context cue if warranted. State that universal one-person messaging would require a separate design decision. Do not silently choose new cross-domain lifecycle/access behavior.

Potential focused validation already exists under:
- `apps/mobile/test/features/messages/`
- `supabase/tests/112_participation_conversations.test.sql`
- `supabase/tests/119_message_list_activity_preview.test.sql`
- `supabase/tests/140_member_contact.test.sql`
- `supabase/tests/144_contact_mixed_pagination.test.sql`
- `scripts/verify-local-participation-conversations.mjs`

A destructive or ambiguous real-data repair is outside this quick-fix exception. Prepare the evidence and precise repair proposal while finishing the audit. Do not claim Leonardo's live account is fixed merely because a local test or source PR passes. If existing safe read-only access can establish installed/backend parity, use it; do not require his private account to complete the synthetic audit.

## 4. Capture, open, and critique each image

Use native emulator screenshots or the existing native Flutter integration capture callbacks. Prefer normal navigation for the primary page coverage. Mark any direct-route/fixture-only setup and separately verify entry/exit behavior where it matters.

Wait for a settled state unless deliberately capturing loading/error behavior. Capture the actual visible UI, including useful keyboard/system-inset context. Do not remove visible defects from the capture, alter app pixels, stretch the aspect ratio, or use generated mockups as evidence.

**Open every delivered capture in an image-viewing tool at readable scale.** Contact sheets support navigation but do not replace individual inspection. Inspect crops at full size when needed. Record the visual-review status per capture only after it has been inspected.

Look for:
- text overlap, clipping, overflow, truncation, poor contrast, inaccessible tap targets;
- keyboard/safe-area collisions, hidden actions, scroll traps and awkward sheets;
- unclear hierarchy, excessive repeated explanation, developer/debug copy in ordinary flows;
- inconsistent labels, icons, spacing, navigation exits and feedback;
- confusing duplicated rows, statuses, previews, unread counts and action states;
- avoidable steps or unclear empty/error states.

Separate **observed evidence**, **interpretation**, and **proposed change**. Label each as confirmed defect, suspected defect, copy/usability problem, or optional design suggestion, with a simple impact level and confidence. Code inspection may support a cause; it must not be described as something visible in an image.

Do not invent a problem for every screen. Say **"No issue observed in this captured state"** where appropriate. Keep necessary consent, permissions, safety, and error explanations; do not classify every explanatory sentence as debug clutter. Check conditional provider attribution before proposing its removal.

## 5. Deliver a review designed for a phone

### Required output 1: PLANETS_UIAUDIT01_Review.pdf

Use a **portrait, screen-first PDF** as the primary review. No account, local server, ZIP extraction, or PowerPoint installation should be necessary to read it. Do not make a landscape deck the only usable artifact.

- Start with a short coverage/status summary, how to answer, and a linked contents/index.
- Give each capture a permanent letter **A, B, ... Z, AA, AB...** and a clear screen/state title.
- Show the full screenshot with numbered markers that do not cover the evidence. Keep the unannotated original separately.
- Put concise comments beside the relevant region only if both stay readable. On a narrow portrait page, place comments directly below the screenshot or enlarged region instead of forcing tiny side-by-side columns.
- For detail that would be too small, add a linked detail page with an enlarged crop and the same issue ID. Keep its full-screen context available.
- Avoid dense pages; split findings into continuation/detail pages without renumbering them.
- Default commentary to concise English, retaining Italian UI quotations and proposed Italian copy.
- Include every reviewed capture, including screens with no issues; separate summary priorities from the complete evidence.
- Keep environment/build details and diagnostic logs in the appendix, not in the main decision cards.

Each finding must contain:
1. **ID and short title**.
2. **What is visible / why it matters**, normally one or two sentences.
3. **One specific proposed change** that a yes/no answer can approve.
4. Type, impact, confidence, and **Decision: pending**.
5. Linked related evidence if the same issue appears elsewhere.

Use A1, A2, B1, etc. **The letter identifies a screenshot, the number identifies one proposal.** Preserve IDs when prioritizing, splitting pages, recapturing, or creating later before/after views. Cross-reference a repeated issue instead of creating several votes for the same change. Never interpret missing answers as approval.

For A1, distinguish the visible repeated-person problem from the diagnosed cause. If the cause is unconfirmed, keep that explicit. If the narrow authorized bug fix was made, label it **fixed under the quick-fix request** with before/after evidence rather than pretending it awaits the general UI vote.

A portrait PPTX may be supplied as an optional extra if straightforward. It must not delay the PDF or replace mobile readability. Do not build a new web dashboard merely to collect votes.

### Required output 2: PLANETS_UIAUDIT01_Sources.zip

Provide the complete review sources in a simple structure, adapting names to repository conventions:

```text
PLANETS_UIAUDIT01/
  captures/                 # original PNGs, named by screenshot ID
  annotated/                # derived marked/cropped images where used
  notes/                    # A.md, B.md... with the same review text
  review.json               # canonical capture metadata, findings and stable IDs
  coverage.md               # page/state inventory and blockers
  decisions.md              # one line per proposal, initially pending
  README.md                 # provenance and how to reproduce captures/report
  report/                   # report generator/source, if created
```

Keep raw images separate from derived annotations. `review.json` should reference image paths and hashes, not embed image bytes. The notes and PDF must agree because they derive from the same findings data. A concise script is enough; avoid building a general reporting framework.

Deliver files through the task's supported attachment/artifact mechanism. Commit appropriate reusable capture/report tooling and sanitized findings through the repository workflow. Keep the original private reference and any report/archive containing it out of the public repository. Do not silently publish private evidence to obtain a download link.

## 6. Verify the result and finish

Before calling the task complete:
- Reconcile the route/state inventory with actual captures. Confirm IDs, image hashes, source/run provenance, and no stale files from earlier runs.
- Confirm every delivered image has been opened and visually assessed.
- Generate the PDF, render all pages, and inspect them for clipping, image distortion, marker alignment, missing glyphs and readable comments. Check representative dense pages at phone-sized fit-to-width. Add crops/pages instead of shrinking text.
- Confirm the PDF and archive open, all image references resolve, the index works, and every issue has one unambiguous proposal.
- Run change-scoped validation for tooling or the narrow fix, including meaningful regression tests if behavior changed. Follow required CI gates; do not add costly recurring suites for a one-time audit.
- Keep captured/fixed/blocked/inferred findings distinct. A partial audit must be labeled partial with exact remaining coverage, not reported as "all pages reviewed".
- Preserve only task-owned evidence/resources needed for reproducibility; clean up disposable credentials, processes, stacks and worktrees according to repository policy.

Finish with links to the **PDF and source ZIP**, the inspected source/build and device, captured/reviewed/blocked counts, a brief duplicate-chat diagnosis and any actual fix status, the most important findings, and this reply example:

**A1 yes, A2 no, B1 yes.**

Do not stop at offering to create the final files or asking Leonardo to assemble them.
