# PLANETS PEOPLEHOME01 — Three Home intentions + relevant-link warning in Co-Creation General

**Implementation handoff to Codex.** Implement one focused, reversible Find People UX change, covering (1) the experimental three-card Home and (2) a link-sharing warning before sending an ordinary human message to a Co-Creation community's **General** chat. The underlying event radar and Project system remain intact but are **not** wired to their new Home placeholders in this pass.

## Goal and delivery shape

In **Settings → Sandbox → Co-Creation Mode**, the Home expresses the intended PLANETS directions:

1. **Find your people / Trova le tue persone** — active, enters the real current `/people` experience (including its existing first-entry planetary introduction).
2. **Find activities / Trova attività** — present, explicitly **Coming soon / In arrivo**, disabled with **no** navigation or side effect.
3. **Propose an idea / Proponi un'idea** — present, explicitly **Coming soon / In arrivo**, disabled with **no** navigation or side effect. Conceptually reserves the existing Projects/co-creation product space for later integration, but is not a working Project entry in this experimental Home.

In that experimental state, **replace** the current Crazy Ideas placeholder and the separate active Projects/Scambio-Dona Home cards rather than displaying five or six competing calls to action. Preserve those old routes, data and features elsewhere, and preserve every Home layout when Co-Creation Mode is OFF. Do **not** remove the native Projects, Tavoli, Resources or Activities route families, or infer a final taxonomy for them.

In the ordinary human-message composer of a **Co-Creation community General** chat, detect a link before initiating a new send. Display a clear **nonblocking pre-send warning** explaining that relevant links are welcome, but repeated, unrelated event/content promotion and spam are strictly prohibited, can be reported, and are subject to human moderation. A user may cancel and edit the draft or explicitly continue sending an appropriate link. **A link is not itself an infringement.** Preserve exact-server-send retry semantics, and rely on the existing case/reporting pipeline for manual review; do not create automated sanctions.

This is **one UI/flow PR**, not a complete account-suspension implementation or a rewrite of chat transport.

## Current implementation evidence — verify again before editing

Inspected repository `lillo24/planets.community` on 2026-10-23:

- `main` was `667bf57b51912f8c1d92b54828bb1e4d801a7303`. It does **not** yet include the Co-Creation application. The consolidated [PR #297](https://github.com/lillo24/planets.community/pull/297) (draft; branch `codex/cocreate-fill01`, inspected head `7faba51c7b35e1fc3f287e9ebb54e101d3e60adf`) **does** include it, based on `main`, with migration review still pending. Its current owner-review/release protections are not optional. Avoid editing #287 or #292 separately: their relevant work is already in #297.
- `apps/mobile/lib/app/foundation_screen.dart`: when Co-Creation Mode is enabled, Home currently shows active **Trova persone**, disabled **Crazy Ideas**, active **Progetti**, and active **Scambio-Dona**. The same widget handles baseline/Activities Split and tutorial presentation. `_HomePillarCard` supports an absent tap handler, suitable for real disabled states.
- `apps/mobile/lib/features/settings/`: `planets.sandbox.coCreation` defaults OFF. The Activities Split setting and Co-Creation are mutually exclusive upon successful new selection. A Mock realm is separate. No change to their saved keys, persistence, precedence or initial bootstrap.
- `apps/mobile/lib/features/co_creation/presentation/people_entry_screen.dart`: `/people` owns the first-entry interest/planet illustration. Preserve it rather than replacing `/people` with a new mock.
- `apps/mobile/lib/features/co_creation/presentation/co_creation_general_screen.dart`: `widget.numbered == false` is **General**, `true` is a numbered crew chat. General uses `PeopleCommand` with `send_cocreate_room_message`, `p_body`, `room/…/send`, and immutable, retryable commands. The same screen renders report actions for individual received messages.
- `apps/mobile/lib/features/co_creation/presentation/people_widgets.dart` and `application/people_attempt.dart`: commands freeze intent, protect identity/account transitions, and preserve exact retry after ambiguous delivery or post-delivery UI failure. This mechanism must not be bypassed by a direct alternate RPC or by the confirmation dialog.
- `apps/mobile/lib/features/moderation/domain/moderation_models.dart`: `ModerationCategory.spam` and `ModerationTargetKind.cocreateRoomMessage` already exist. `ModerationRoutes.openReport` is used for Co-Creation General messages; reports are reviewed manually. Avoid a second reporting pipeline.
- `apps/site/src/policies/content.json`: community rule C1 already forbids spam and unwanted advertising. Terms A8 describes manual review and calls restrictions/suspension **proposed and not yet operational**. `apps/web/src/features/moderation/README.md` says its staff UI has no blanket suspension action. `docs/implementation/roadmap.md` places actual restrictions, suspensions and appeals in **09C**. These are consequential boundaries; do not describe an indefinite account ban as a deployed, guaranteed action.
- Existing language keys are in `apps/mobile/lib/l10n/app_it.arb`, `app_en.arb`; use the app's normal localization generation and accessibility conventions. Current real app and Mock environments must remain isolated.

Before editing: read `AGENTS.md`, nested feature instructions, `implementation_plan_sections_suggestions.md`, current #297 code/CI and the policy/moderation contract. Source code and migrations outrank historical planning. If #297 has since merged, base the task on updated main; otherwise create an **isolated feature branch derived from #297 head** and a dependent PR into `codex/cocreate-fill01` (or the current verified integration target). Do not stack unmerged changes on an unrelated or older main base. Do not modify the SQL-owner-review gate or insert this work into the already-staged reviewed migration set.

**External context:** none required beyond the repository and ordinary tools. No Google Doc, screenshot, external link feed, Play Console settings, or hosted credentials are necessary. No deployed app interaction is required for coding. Physical QA may be deferred accurately.

## A. Home — exact observable behavior

- Co-Creation Mode ON: exactly the three intention cards above, in the given order. Use compact, grounded IT/EN subcopy; each placeholder visibly states “In arrivo” / “Coming soon.” Prefer the existing Card/theme/icon hierarchy; do not create an elaborate separate launcher or another navigation tab. An inaccessible hidden tap target is not an acceptable substitute for a visibly disabled card.
- “Find your people” continues to navigate to `/people`, preserving its introduction/replay behavior, eligible login handoff, actual community/post actions, in-app messages and Mock persona selection as before.
- The two Coming soon placeholders **perform no navigation, authentication, backend query or mutation**. They must not misleadingly show Projects/Activities live content or fake previews; don't implement the radar or Project creation here. Handle large text / 320dp layouts and accessible disabled semantics.
- When Co-Creation Mode is OFF, keep baseline and Activities Split Home unchanged, including genuine `/proposals`, `/activities` and `/resources` entry points. Do not remove preexisting links, routes or admin areas. Preserved capabilities may continue to be reached via their existing explicit destinations when Co-Creation is ON, but the new Home itself has only three cards.
- Do not rename or modify underlying Project/Resource/Tavolo models, workflows, public shares, database schema, Supabase realms, tutorials or legal bundle versions as part of this launcher change. If needed, retain the old Crazy Ideas localization keys when removing the obsolete Home card to avoid breaking other screens.

## B. Link warning — exact observable behavior

### Detection and scope

- The warning is **only for ordinary human text sends in the main General of Co-Creation topic communities** (`widget.numbered == false`). It is not a rule on numbered-group chats, registered Groups' General/Ideas discussions, Project/Tavolo/Resource/private chats, structured recruitment cards, notification payloads or externally imported events.
- Inspect the outgoing draft locally at explicit send time for likely web links. Cover `https://`, `http://`, `www.` and credible bare web domains including links embedded in prose or Markdown. Handle case, Unicode whitespace and punctuation. Avoid treating ordinary times (`18.30`), decimal numbers and standalone email addresses as links. Keep logic pure, deterministic, bounded, and unit-testable. Do **not** fetch/open a detected URL, call an AI classifier, collect its contents or persist link-analysis telemetry.
- A detected link is an **educational warning trigger**, not spam classification, message rejection, hidden reporting, automatic strike or a reason to redact otherwise allowed text. Legitimate relevant activities/events can be shared.

### Sending / confirmation

- For a *new* ordinary send containing a link, show a responsive IT/EN confirmation dialog or equivalent review step **before** acquiring/sending the immutable command. The message remains visible, editable and unsent on Cancel. Continue must send **exactly the reviewed text** using the existing gateway/idempotent attempt contract; if the text, actor, hub, room, episode or current live eligibility changes while the dialog is open, discard/revalidate the confirmation rather than sending stale content. If an in-flight command already has an uncertain response or acknowledged completion, its Retry must recover **the exact frozen intent without another preflight/new command ID**. No duplicate send, erroneous success, or automatic resend. Keep the normal no-link path unchanged.
- Do not allow confirmation to bypass server-side account, policy, room-membership, moderation, capacity or disabled-feature checks. Server remains authoritative for admitting a message; the UI warning isn't the authoritative spam gate.
- Use concise explanatory copy, not an accusatory warning merely because a link exists. Suggested **current** Italian copy: “Condividi solo link pertinenti a questa comunità. Spam e promozioni ripetute di eventi o contenuti non pertinenti sono severamente vietati. I messaggi segnalati possono essere esaminati dai moderatori e portare a provvedimenti secondo le Regole della community.” English counterpart: “Only share links relevant to this community. Spam and repeated promotion of unrelated events or content are strictly prohibited. Reported messages may be reviewed by moderators and lead to action under the Community Rules.” Buttons: “Modifica” / “Invia comunque” (English: “Edit” / “Send anyway”). Consider an unobtrusive inline hint near the composer when a link is detected, but avoid permanent noisy banners and redundant prompts.
- The founder additionally proposed **indefinite account suspension after manual finding of harmful off-topic spam**. Record this as a **proposed 09C moderation policy**, *not* a currently enforceable or automatic sanction. Do **not** promise an indefinite block in shipped UI copy until a reviewed, proportionate staff-side suspension/reason/appeal mechanism and corresponding Terms/Rules are approved and operational. Do not implement account suspension, banned_until manipulation, staff impersonation, silent user restrictions, raw link logs, new analytics or a new report table in this PR.
- Reuse the existing per-message Report action and Spam category. It must still submit genuine source-bound evidence for moderator review; no public exposure of a reporter identity, message transcript outside authorized room, or third-party URLs beyond the report's existing evidence scope. There is no need to auto-file a report merely because someone sends a link.

## Testing, rollout and review

- New/affected Flutter tests: baseline/Activities Split Home unchanged; Co-Creation Home has three correct buttons and labels; both placeholders are noninteractive; Find your people enters real `/people`; intro, tutorial, Mock switching, Back and deep links still behave; EN/IT 320dp, 2× text and accessibility/disabled semantics.
- Link detector table tests: `https`, `http`, `www`, Markdown, bare domain, punctuation and mixed case; negatives for email-only, plain times/numbers, non-web text; repeated links and near-length-bound drafts.
- Integration/widget tests: only General link send shows warning; non-link sends unchanged; numbered chat link sends unaffected; Cancel preserves draft and sends nothing; Continue sends once; stale actor/room/text invalidates confirmation; duplicate taps; network loss or ambiguous send retries frozen intent; acknowledged UI-completion retry doesn't send twice; report/Spam pathway remains available and unchanged. Test no accidental extra messages/unread/ACK, no auto report/sanction and no user-data leaks.
- Run localization generator, scoped Flutter analyze/tests, formatting, actual router/baseline regressions and relevant Android debug build. Inspect representative IT/EN renders, including a narrow/large-text confirmation and the three-button Home. Use existing CI and mention any skipped real-phone or iOS QA accurately. SQL migrations and browser/site legal update are **out of scope**, so do not claim DB/backoffice changes or successful hosted activation.
- Document feature behavior, warning scope, source policy compatibility and remaining 09C decision in the nearest `docs/development/` + relevant README. The UI copy must not claim technical sanctions that are absent. Do not modify provisional Terms/Community Rules or bump acceptance versions without separate owner approval.
- Make a focused implementation branch/PR, preserving ongoing #297 owner migration review, #298 catalogue work, staging release and Mock changes. **No direct main code commits, automatic merge, deployment, store upload, hosted migrations, policy activation or account banning.** If integration changes after the task starts, recheck verified bases and retarget only via the normal review path. Report exact PR/head/checks and remaining user/owner actions.

## Acceptance checklist

- [ ] Co-Creation Home shows only the three requested intentions; only Find your people acts.
- [ ] All other presentation modes, domain routes, existing data, Mock/realms and first-entry introduction remain intact.
- [ ] New General human messages with web links receive an explicit warning, not an automatic ban.
- [ ] Cancel/Continue and uncertain retry are correct and auditable; no duplicate sends.
- [ ] Existing spam reports remain manual and source-bound; no 09C suspension claimed implemented.
- [ ] IT/EN, accessibility, small-screen and automated regressions pass; no production write or deployment.