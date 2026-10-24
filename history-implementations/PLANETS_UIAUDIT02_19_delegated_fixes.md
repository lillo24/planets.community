# PLANETS UIAUDIT02 - Implement the 19 delegated audit fixes

## Task and authorization

Implement all 19 findings listed below from UIAUDIT01 that Leonardo delegated as clearly beneficial corrections. Deliver working changes, focused verification, and a concise before/after review. This is an implementation task, not another proposal round.

Approved IDs, exactly:
P1, AA1, AU1, BL1, BL2, CQ1, DK1, DU1, DY1, FW1, GI1, GL1, FO1, HS1, IR1, KT1, KX1, MT1, OA1.

**A1 and DE1 remain outside this task.** They are being considered in a separate conversation. Do not add chat-context rows, unify conversations, deduplicate counterparties, or replace an author's People interest form with a management action under this prompt. If another task merges those changes, preserve them and integrate normally.

Leonardo has approved the bounded text, formatting, readability, and correctness repairs here without another individual yes/no vote. Choose the exact implementation and equivalent English wording using current code and existing patterns. This authorization is scoped to the 19 findings; it is not blanket permission to redesign unrelated pages or change policy/business rules. Changing collapse behavior is not independently required by any finding.

Continue through implementation, checks, PR, eligible merge, and normal cleanup. Do not stop after producing a plan or a set of suggested changes.

## Evidence, freshness, and external dependencies

Prepared on 24 October 2026 against main at 04c63e5fb6ac08fb72a2b395f247be5bcdc3cb3c. Start from the newest main available when executing; this SHA records inspection provenance and is not a request to rewind.

The original audit reviewed source b9a8603, app 0.1.10+14, using a native Pixel 9 Pro SDK profile on Android 16/API 36. It contains 418 reviewed captures, 457 portrait PDF pages, and 21 unique findings across all ten original Mock personas. Its coverage was explicitly partial. Later Calendar, catalogue and map changes were outside that audit.

The seven-page decision filter delegates the 19 IDs here and retains only A1 and DE1 for founder review. Its DK1, FO1 and IR1 guardrails are incorporated below.

**No external attachment, Google Doc, Google Drive session, or source ZIP is required to implement this prompt.** Each approved proposal and its acceptance criteria are reproduced here. Optional historical evidence:

- Original PDF: https://drive.google.com/file/d/15JV1lj79l2q6DmPxL72lxuy9X6pT6nd9/view
- Original audit prompt on main: history-implementations/PLANETS_UIAUDIT01_pixel9pro_screenshot_review.md
- Existing native tools: scripts/ui-audit/README.md and apps/mobile/integration_test/ui_audit_test.dart
- Optional local original deliverables: PLANETS_UIAUDIT01_Review.pdf and PLANETS_UIAUDIT01_Sources.zip. Locate through the prior task's manifest/known output directory if available; do not scan unrelated personal folders.

The original PDF/ZIP are private evidence. Do not commit them, account credentials, or personal screenshots to the public repository. Lack of the historical image is not a reason to stall a source-verifiable repair; produce a current before capture. If a specific finding cannot be reproduced or its current meaning has changed, record that accurately rather than inventing its state.

The four volunteer-law PDFs attached elsewhere in this conversation are unrelated to this task.

## Repository workflow and scope

Read current AGENTS.md, applicable nested instructions, docs/development/codex-tooling.md, and the relevant accepted architecture. Inspect current implementation, manifests, generated-file conventions, and tests before editing.

Use the task's isolated managed checkout, or one isolated branch/worktree if needed. Preserve unrelated work. The primary task is one cohesive audit-fix batch, with two internal tranches: client copy/layout/inbox repairs and the reporter projection repair FO1. Keep commits reviewable by responsibility and reference finding IDs. One implementation PR is preferred. If repository policy requires an independently reviewable migration PR, split only at that boundary, finish both in dependency order, and keep one 19-item completion ledger.

Synchronize with newest main before final validation/merge, especially if the A1/DE1 task or other UI work lands concurrently. Preserve their approved changes without claiming their findings as part of this batch.

Do not deploy a release or submit to Play/App Store. Do not alter shared experiment gates, hosted Mock fixtures, provider configuration, signing, CI policy, staging activation, or production settings. A code merge is separate from an app update. Follow existing verified staging automation as configured; do not change or bypass its policy.

## Original issue index

PDF page numbers below are physical pages in the original 457-page PDF, not in the seven-page shortlist. IDs remain stable across recaptures and repeated occurrences.

| ID | Original card page | Primary evidence / persona | Approved correction |
| --- | --- | --- | --- |
| P1 | 18 | P / guest | Name the setting Trova persone (sperimentale) |
| AA1 | 19 | AA / Giulia; IH / Marco | Replace lifecycle jargon in management |
| AU1 | 20 | AU, BJ / Marco | Shorten the Scambio-Dona search hint |
| BL1 | 21 | BL / Marco | Show the complete private-note audience statement |
| BL2 | 22 | BL / Marco; JI, NY / Giulia | Call a Resource listing an annuncio |
| CQ1 | 23 | CQ, CS / Luca; multiple People chats | Format chat timestamps for reading |
| DK1 | 25 | DK / Maya; DR / Nora; IU / Dario; KH / Iris | Explain existing close/withdraw actions |
| DU1 | 26 | DU / Teo; DZ, FQ / Iris | Compute honest composite inbox empty states |
| DY1 | 27 | DY, DX / Teo; EG, EH / Iris; KE / Luca; LL / Maya | Distinguish numbered-group exit from community exit |
| FW1 | 28 | FW, FX / Giulia | Format template durations in hours/minutes |
| GI1 | 29 | GI / Giulia | Localize the safety request target label |
| GL1 | 30 | GL, GM, JP, JQ, JR / Giulia | Show complete witness-response choices |
| FO1 | 31 | FO, FN, KI / Iris | Repair reporter-only People report reading |
| HS1 | 32 | HS / Giulia | Use the Group General history label |
| IR1 | 33 | IR, MD / Dario | Remove the raw creator UUID from Idea discovery |
| KT1 | 34 | KT / normal local sign-in | Describe ambiguous OTP failures accurately |
| KX1 | 35 | KX, KY, KZ / normal local profile setup | Show the complete name-validation message |
| MT1 | 36 | MT / Elena | Localize the generic blocking target |
| OA1 | 37 | OA / Giulia | Label published-Group departure saves accurately |

## Approved requirements, one finding at a time

### P1 - Settings name

Observed: the setting says "Modalità Co-creazione", whereas its public feature name and help use "Trova persone".

Use **Trova persone (sperimentale)** for the Italian setting title, with an equivalent English title consistent with existing Find People terminology. Retain the experimental qualification and existing switch/help behavior. Do not rename internal identifiers, routes, database objects, or the entire feature.

Current inspection: apps/mobile/lib/features/settings/presentation/co_creation_setting.dart uses l.coCreationSetting. The Italian catalog still defines that key as Modalità Co-creazione. Inspect all consumers before changing a shared key.

Acceptance: the guest/member Settings screen uses the discovery name, fits naturally, and toggles the same presentation setting.

### AA1 - Management wording

Observed: an ordinary organizer menu action is called "Dettagli del progetto e ciclo di vita".

Use **Dettagli e stato del progetto**. Update its adjacent description where needed so the same menu does not retain unexplained lifecycle jargon. Apply an equivalent label to the Tavolo variant if the same responsibility and existing terminology justify it. Do not change lifecycle states, cancellation/completion rules, management permissions, or navigation.

Current inspection: projectManageStructuralTitle and projectManageStructuralDescription in apps/mobile/lib/l10n/app_it.arb; apps/mobile/lib/features/project_delegates/presentation/project_manage_screen.dart is a relevant owner.

Acceptance: creator/manager screens describe the existing destination plainly, including the related Marco Tavolo evidence where applicable.

### AU1 - Resource search hint

Observed: "Cerca nel titolo e nella descrizione" truncates in the Scambio-Dona search field at default scale.

Use **Cerca un annuncio**, with concise equivalent English copy. Keep the existing title-and-description search behavior, filters, and search accessibility intact. If the same localization key is also an explicit label elsewhere, inspect those consumers and choose a safe reuse/split rather than changing unrelated meaning.

Current inspection: resourceSearchLabel contains the long Italian string.

Acceptance: the hint fits at normal phone width, and searching still matches the same fields.

### BL1 - Private-note audience disclosure

Observed: the private exchange note helper is ellipsized, hiding part of who can read the note.

Let the complete existing disclosure wrap and grow naturally. The current Italian helper is "Visibile solo alle due persone che coordinano questo scambio." Do not remove, weaken, or invent its audience statement; verify it remains consistent with the existing agreement contract.

Current inspection: apps/mobile/lib/features/resource_exchange/presentation/resource_exchange_widgets.dart sets helperText to resourceExchangePrivateNoteHelp without explicit multiline capacity.

Acceptance: the whole sentence is visible at default and enlarged text sizes, including with the native keyboard open. The note remains private under the same backend rules.

### BL2 - Resource agreement terminology

Observed: the agreement sheet says "Il proprietario della lista fornisce".

Replace this with **Il proprietario dell’annuncio offre**. Use natural equivalent English where a corresponding change is needed. Inspect compose/review/historical terms so the same concept is consistent without rewriting stored agreement content or historical commitments.

Current inspection: resourceExchangeOwnerProvides owns the incorrect Italian label.

Acceptance: current and historical agreement views use the correct listing noun; the stored terms, offers and acceptance behavior are unchanged.

### CQ1 - People chat timestamps

Observed: General, numbered-group and People-contact message metadata shows raw numeric dates with six fractional-second digits.

Reuse the existing localized compact chat date/time formatting pattern, omitting seconds and microseconds. Format display values in the app's established timezone/locale convention. Keep original instants, sorting, cursor values, read boundaries, grouping and unread logic unchanged. Do not convert stored timestamps into display strings or invent new relative-time rules.

Inspect current consumers in co_creation presentation, including General, numbered groups, contacts and any shared message widgets. The related audit captures include DI/Maya, DT/Nora, DX/Teo, EA/ED/EG/EH/Iris and LL/Maya. Cover shared occurrences under CQ1, without duplicate findings.

Acceptance: Italian and English metadata is compact and readable; messages remain correctly ordered across dates and account changes.

### DK1 - Explain existing exit actions

Observed: the close page repeats "Chiudi" for its heading, toolbar exit and action; withdrawal similarly only says "Ritira". The affected object and actual consequence are unclear.

Improve the **existing** close/withdraw screen or confirmation content. Use a specific title, a concise explanation of what the existing action does, an unambiguous primary action and **Annulla** for cancellation where that control is intended to cancel. Do not add another confirmation dialog/page or a new mandatory tap.

Read the existing mutations before describing effects. Do not promise deletion, restored access, permanence, retained history, or effects on other members unless the canonical contract supports the claim.

Use currently authorized post/contact context when already available. Gate-OFF and identity-only recovery must keep working: use a generic, accurate description where object context cannot lawfully be read. Do not fetch hidden post details, roster data, private message text or profile names merely to make this copy more specific. Never show raw UUIDs as a substitute.

Current inspection: apps/mobile/lib/features/co_creation/presentation/people_exit_screens.dart owns PeopleContactCloseScreen and PeopleInterestWithdrawScreen. They use requirePolicy: false for the existing recovery path. Keep that purpose and its identity checks. Related IU evidence also concerns an existing decline/exit confirmation; inspect and apply the same clarity principle only where its actual action matches.

Acceptance: closing and withdrawing are understandable before the existing action, cancellation performs no mutation, and server-gate-OFF/identity-only exits retain the same privacy and availability.

### DU1 - Composite inbox empty state

Observed:
- Teo has a pending People request above "Nessun messaggio".
- Iris has an accepted People contact and unread badge above "Ancora nessuna chat privata".

Show a screen-wide empty state only when **all applicable content sources for that selected tab/scope have completed successfully and are empty**. Account for native participation/Resource conversations, People requests/contacts, discussion invitations/folders and retained own-exit entries as applicable. Audit the current composition rather than assuming this list is exhaustive.

Current inspection: apps/mobile/lib/features/messages/presentation/messages_screen.dart renders PeopleContactItems above an unconditional native-empty message, and PeopleRequestItems/DiscussionRequests above another native-empty message. People widgets currently load independently; choose the smallest maintainable way to communicate their actual state to the composing screen.

Required behavior:
- Any visible conversation/request/folder/recovery item suppresses a contradictory global empty claim.
- Pending loading is not proof of emptiness; do not flash an empty state before a delayed section finishes.
- An error is not an empty result. Preserve actionable retry/error presentation; existing successful items may remain visible under the established refresh rules.
- Disabled/inapplicable sources settle as inapplicable. They must not leave a permanent spinner or trigger unauthorized reads.
- Preserve access to retained People Messages and own-exit routes when presentation is OFF or the server gate is OFF, according to the existing contract.
- Bind composite state to active actor, realm and tab/scope; previous-persona results must not suppress or create an empty state for the next user.
- Preserve pagination, unread badges, pull-to-refresh, and stable row identities. Avoid a second competing loader, polling loop, double-fetch architecture, or checks based on display names.

Acceptance: native-empty + People-present, native-present + People-empty, discussion-only, recovery-only, genuinely all-empty, delayed-load, failure/retry, account/realm switch and relevant OFF states behave honestly. Test the state transitions, not merely the presence of one new boolean.

This finding does not authorize A1 conversation-row changes or merging histories.

### DY1 - Correct numbered-group exit label

Observed: a numbered chat and its exit page say "Lascia la comunità" although the action leaves that numbered group.

Use **Lascia il gruppo** for numbered-group chat/exit controls and the existing confirmation. Reserve **Lascia la comunità** for the broader hub exit. Use equivalent English distinctions.

Current inspection: coRoomsLeave currently says Lascia la comunità; coGroupsLeaveWarning describes numbered-group behavior. Inspect co_creation_numbered_screen.dart and corresponding exit/recovery screens before deciding whether to reuse an existing specific key or add one. Do not globally replace a shared community label.

Preserve creator-archives-group behavior, allowed historical access, meeting participation and effects on other groups. The existing warning must remain accurate.

Acceptance: numbered-group and community exits are clearly distinguished, including retained/OFF paths; no membership behavior changes.

### FW1 - Human-readable template duration

Observed: a workshop template says "Durata indicativa: 10800.0 secondi".

Show localized hours and minutes, for example **Durata indicativa: 3 ore** and **1 ora e 30 minuti**. Preserve the adjacent instruction about selecting fresh dates/times for the draft. Handle singular/plural and zero components naturally using the repository's localization conventions.

Current inspection: template_workshop/presentation/template_workshop_screens.dart passes detail.durationSeconds.toString() into workshopDuration.

Keep the stored duration, precision and scheduling semantics unchanged. Inspect the actual supported numeric range before implementing display conversion. Do not silently truncate non-minute durations if they are valid; use the existing domain precision/rounding convention or a clearly approximate display. Avoid changing the template schema or adding a formatting package for this small task.

Acceptance: representative one-hour, multi-hour and mixed durations read naturally in Italian/English; no raw decimal seconds appear for the audited 10800-second case.

### GI1 - Safety request target translation

Observed: an otherwise Italian evidence/review-request card contains "Resource request".

Display **Richiesta Scambio-Dona** for that target in the Italian safety request list, with a proper English counterpart. Trace whether the label comes from a server projection or client mapping and fix the presentation boundary consistently with established patterns. Never translate the persisted target-kind identifiers or alter a wire enum to change a visible label.

Acceptance: the authorized request card is fully localized, and target routing, privacy and response permissions stay unchanged.

### GL1 - Complete witness-response choices

Observed: all three long Italian witness-response choices are clipped in their current chips.

Show **every complete existing sentence**, with natural multiline wrapping and sufficient vertical growth at default and enlarged text size. Do not shorten the safety statements to labels that lose their meaning. Current Italian options:

- Concordo: corrisponde a ciò che ho osservato personalmente
- Questo non corrisponde a quello che ho osservato personalmente
- Non sono sicuro: non ho visto abbastanza per rispondere

Current inspection: moderation/presentation/corroboration_screens.dart uses ChoiceChip with a single Text label in an Align. Choose a minimal accessible multiline selection layout if the current control cannot grow correctly. Preserve one-of-three semantics, selected state, disabled/submitting behavior, focus/screen-reader labels and existing submission requirements. No extra step or new response option.

Acceptance: all sentences fit and can be selected at normal and enlarged text scale. Scroll to any lower controls and verify they remain usable; a semantics label containing hidden words is not sufficient proof that the visible text is readable.

### FO1 - Own People report read contract

Observed: Iris successfully submits a People post report, receives its receipt, then "My reports" fails to read.

Historical diagnosis, not an assumption to copy blindly: an ordinary Iris call to list_own_moderation_reports_v4 returned a cocreate_post row with target_summary = null. The mobile parser requires bounded, nonempty target_summary. This is a producer/consumer projection-contract defect, not proof that the report submission failed.

Current inspection:
- scripts/ui-audit/diagnostics.mjs makes the ordinary reporter call without staff privileges.
- moderation/data/moderation_gateway.dart calls list_own_moderation_reports_v4 and parses target_summary through _boundedString(..., 200).
- moderation/presentation/own_reports_screen.dart renders the report's summary.
- People reports were added in the cocreate migrations; the v4 own-report reader originates in the earlier member/contact upgrade chain. Search current definitions and wrappers, including later migrations, rather than patching only the first textual occurrence.

Repair the canonical reporter-only projection/contract so supported People targets yield a privacy-safe, nonempty bounded summary that the app can render and localize through the established boundary. Inspect cocreate_post, cocreate_interest, cocreate_contact_message and any currently supported related target variants. Choose concise target-type summaries if that satisfies the existing contract; do not expose report evidence to get richer wording.

Required guardrails:
- Keep reporter identity binding, ownership checks, pagination, supported-reader compatibility and report-state semantics.
- Do not broaden who can read reports, staff case details, evidence snapshots, private notes, contact message bodies, counterpart profiles or erased-subject data.
- Do not hide malformed responses by filtering them out, returning an empty report list, weakening the parser globally or swallowing the error.
- Preserve legacy target handling and the established denied/removed-content behavior. Own retained report access must follow current canonical gate/identity rules, not a new blanket gate.
- If SQL changes are needed, add a new backward-compatible migration; do not rewrite applied history. Keep grants/search_path/security properties intact. Update generated contracts only when the repository's actual generation/checks require it.
- No repair of shared live data, resets, migration squashing or direct hosted SQL is authorized.

Prove a genuine local ordinary-account sequence: submit People report -> receive receipt -> read RPC -> parse/render My reports -> refresh/reopen. Include existing populated reports, relevant other People target kinds, and negative attempts by another reporter/guest or a mismatched expected actor. Verify the private/staff-only material remains inaccessible. Include gate-OFF/retained behavior where the contract supports it.

Acceptance: the new report remains readable only to its authorized reporter through the same app path, without exposing additional content or breaking legacy reports.

### HS1 - Group General history label

Observed: a registered Group's Generale conversation footer says "Cronologia completa dell’Idea".

Use a **General-specific history label** when the conversation is General. Preserve the existing access warning, including responsible Group roles where applicable. Retain the Idea-specific label in actual Idea discussions and the current former-member/read-only wording.

Current inspection: group_discussions/presentation/discussion_chat_screen.dart uses discussionHistory in more than one branch. Select by the actual typed discussion context; do not infer from a display title or replace that shared string globally.

Acceptance: active General, active Idea and retained/read-only history labels all describe the correct context.

### IR1 - Idea creator UUID

Observed: the pre-join Idea invitation/discovery page shows "Creatore dell’Idea" followed by a raw 36-character profile UUID.

When no authorized display name is already available, replace the UUID line with **Creatore: disponibile nella vista Persone autorizzata**, or an equally concise equivalent preserving that meaning. Localize English too. An already-authorized name may be displayed through the existing contract.

The original source intentionally avoids a separate profile lookup. **Do not add profile/roster reads, expand an invitation preview, expose membership, or relax permission checks** to obtain a name. Do not introduce a new tappable destination that itself requires a product decision. Keep internal IDs for identity logic.

Acceptance: the pre-join view contains no raw creator UUID as user-facing copy; accepted/member views retain their authorized information. No new network/profile lookup is introduced.

### KT1 - Ambiguous invalid/expired OTP error

Observed: a fresh deliberately wrong 000000 sample was called only "expired", while the actually delivered code still worked immediately afterward.

For the ambiguous backend OTP error, use **Il codice non è valido o è scaduto. Controllalo o richiedine uno nuovo.** Use equivalent English. Inspect current error classification and all consumers before choosing a key/mapping change. Keep more specific messages where the provider reliably distinguishes them.

Current inspection: auth/presentation/auth_failure_message.dart maps expiredCode to authExpiredCode; the Italian text currently says only that the code expired.

Do not change actual OTP expiry, attempts, rate limits, retry/resend behavior or Auth security to accommodate this text. Do not automatically request a new code on an ordinary invalid entry.

Acceptance: an ambiguous failure gives accurate recovery choices, rate-limit/network errors retain their own messages, and the valid delivered code still succeeds where its existing lifetime allows.

### KX1 - Full display-name validation

Observed: required-profile setup ellipsizes its display-name error before explaining the whitespace restriction.

Allow the complete existing validation text to wrap and reserve sufficient vertical space. Current Italian text: "Inserisci da 2 a 60 caratteri, esclusi gli spazi all’inizio e alla fine."

Inspect the actual form owner used for first profile setup and later editing. Do not change length, trimming/whitespace rules, requiredness or saving behavior. Keep errors visible with the native keyboard and at enlarged text size.

Acceptance: the complete restriction is visible in Italian and English, controls remain reachable and the same invalid/valid inputs keep their intended results.

### MT1 - Generic blocking target

Observed: the Italian confirmation title is "Bloccare this user?".

Replace the hardcoded English generic fallback with a localized target phrase, **questo utente** in Italian, with natural equivalent English. Inspect interpolation grammar in the title/body and all unnamed-target paths.

Current inspection: features/blocking/presentation/blocking_action.dart, BlockingActionButton, is the relevant owner. Reuse existing keys where safe.

Do not add a profile lookup or disclose the identity of a target whose display name is not authorized. Keep named-target behavior, confirmations, blocking/unblocking rules and effects unchanged.

Acceptance: both named and unnamed blocking dialogs are grammatical in Italian/English, and no user-facing "this user" remains in the Italian generic path.

### OA1 - Published Group departure-save action

Observed: when leaving a modified published Group editor, the unsaved-changes dialog offers **Salva bozza** even though saving immediately changes the public Group page.

Use **Salva modifiche pubbliche** for that departure action when the persisted/current Group publication state is published. Retain **Salva bozza** for private drafts/new drafts. Respect archived/read-only permissions and the existing disabled/save-error behavior.

Current inspection: groups/presentation/group_editor_screen.dart already chooses groupsSaveLive versus groupsSave for its main Save button. Its prepareDeparture dialog always uses groupsSave. Apply the same authoritative publication distinction in the dialog rather than changing the generic groupsSave string.

Acceptance: published and draft editors show accurate choices on departure; cancel/discard/save outcomes, validation and policy-save guards remain intact. A published save must not silently become a draft or change publication status.

## Cross-cutting implementation rules

- Use the authoritative localization catalogs and repository's normal generation. Keep Italian/English placeholders/types and plural rules consistent; avoid editing generated strings by hand.
- Reuse existing typography, spacing, input widgets and formatting helpers where they fit. Fix the owning widget rather than globally changing all text fields/chips to repair one screen.
- Avoid shrinking fonts, hiding words, adding ellipses, or substituting tooltips for required visible information. Natural wrapping and page scrolling are preferred.
- Keep private/public content and error/loading/empty states distinct. Never solve a clarity problem by weakening authorization.
- Fix repeat occurrences through the correct shared owner; retain one finding ID and one completion entry for each underlying issue.
- Do not use this task to complete the old audit's 35 blocked inventory entries or redesign later unreviewed Calendar/catalogue/map screens.
- If newest main already fixes an ID, verify the behavior and mark it already satisfied with evidence. Do not reintroduce stale code or create churn to claim an implementation.
- If one item needs a consequential new product decision, isolate it, finish all independent approved work, and report the exact unresolved alternative. A1/DE1 staying pending does not block these 19.

## Verification and current native evidence

Use the existing canonical Mock personas and their real fictional relationships. Do not replace them with one arbitrary profile across all screenshots. Focused scenario coverage is sufficient; a new 418-capture sweep is not required.

Minimum roles to exercise:
- Guest and a genuine normal local OTP/profile-setup account: P1, KT1, KX1.
- Giulia/Marco in the Activities world: management, Resource terms, workshop, moderation choices, Group editor and General.
- Luca/Maya/Nora/Teo/Iris in the People world as needed for chats, contact exits/withdrawal, numbered exit, inbox composition and reporter reading.
- Dario for Idea invitation/discovery, and Elena for generic blocking.
- Every account-scoped/asynchronous change needs a relevant cross-account check; not every copy edit needs every persona.

Follow scripts/ui-audit/README.md ownership/port checks when reusing the harness. Create fresh task-owned disposable local stacks and an explicitly selected emulator; adapt occupied ports safely and record them. Do not reset another run, re-add scenarios into shared fixtures, or activate hosted Mock.

Primary visual check: native Pixel 9 Pro, Italian/dark/default scale, with actual device metrics recorded. Inspect every exported screenshot directly. Add targeted enlarged text checks at 1.3x and 2.0x for BL1, GL1 and KX1, and narrow-screen/layout checks where the fix can regress. Check English and light mode on representative affected views; do not claim coverage that was not run.

Tests should prove behavior rather than mirror code:
- DU1 composite state transition matrix, identity isolation and refresh/pagination compatibility.
- FO1 projection/parser/render path plus genuine local Auth/RPC authorization and retained/legacy coverage.
- GL1/BL1/KX1 readable full text and functioning selection/validation at different widths/scales.
- OA1 published/draft departure choices and unchanged save/discard/cancel behavior.
- HS1 and DY1 typed context distinctions.
- Formatting/localization cases for CQ1/FW1 and OTP classification where changed.

Run the smallest complete repository-standard checks for all affected areas: formatting, localization generation/checks, mobile analysis/tests/build, and relevant SQL/HTTP/generated-contract checks if FO1 changes the backend. Use current scripts and manifests; do not guess command names or copy old assertion counts. Let the existing path classifier select required CI. Do not change CI scope or create an always-on screenshot workflow for this task.

If native execution or one specific scenario is blocked, report exactly which proof is missing and complete source/test/other available work. Never label widget goldens, browser renders, historical screenshots, or source inspection as current native QA.

## Deliverables

1. Working implementation for all currently reproducible approved IDs, with focused regression coverage.
2. A concise Markdown completion ledger using these exact 19 IDs, with columns for status, changed owner, verification and screenshot references. Distinguish fixed, already satisfied, and specifically blocked; do not count pending A1/DE1.
3. A small **portrait before/after PDF**, readable on Leonardo's phone, grouped by finding ID. Include the changed screen/control, brief original problem and completed correction, and relevant persona/state. Show enlarged crops for subtle copy/layout changes; include full-screen context where it helps. For FO1 include the success receipt and working own-report state, plus safe text describing negative authorization results. Repeated observations reference the same ID.
4. Original native before/after PNGs and the ledger in a compact source ZIP. Keep raw images separate from annotated derivatives. No credentials, raw Auth/network payloads, OTPs, service keys, private defines or unrelated audit archives.
5. An implementation PR (or dependency-linked PRs only if required by migration policy) with IDs, scope, validation and remaining limits clearly stated.

Use the available PDF skill for generation and render/visual inspection. Keep the evidence focused; do not rebuild the 457-page review or a general reporting platform.

**Make files accessible remotely.** Attach the PDF/ZIP through the execution environment's supported persistent artifact delivery. If that environment cannot provide a remotely accessible attachment and the existing authenticated Drive upload path is available, upload to the existing private PLANETS - UI Audit 01 folder, verifying its identity before use, and return verified file links. No public link sharing or public-repository evidence dump. If no remote channel is available, report exact local paths and the delivery limitation; do not call a desktop-only path a working phone download.

Follow repository PR/check/merge rules. Merge automatically once required CI passes and no consequential blocker remains. Update from latest main and inspect the final diff before merge. Do not bypass an explicit policy hold; report the concrete hold if one occurs while completing everything independent of it.

After merge, verify the final commit contains the intended changes. Clean up only task-owned stacks/emulator/reverse rules/temp credentials and the task branch/worktree according to the environment's workflow. Preserve deliverables outside any checkout scheduled for removal. Use ordinary cleanup; leave a locked empty directory with a precise note rather than forcing deletion or disrupting another process.

## Final response

State:
- approved findings fixed / already satisfied / blocked, out of 19;
- PR link(s) and merge status;
- accessible before/after PDF and source ZIP links;
- concise validation evidence and any native limitations;
- A1 and DE1 remained outside this task;
- installed-app/release/hosted-application status separately from code merge.

Do not request another vote on routine edits already approved here, and do not imply the original partial audit or later unreviewed screens have now been fully covered.
