# 09C2A — Admin moderation consequence controls review report

## 1. Summary

The existing staff-only Next.js case detail now reads and manually manages the
four canonical consequence types. Separate immutable episodes, explicit
confirmations and fresh server authorization preserve the approved backend
semantics. No database, Mobile, Site, dependency, CI or public-surface change was
needed. This delivery stays draft/unmerged; it does not deploy.

## 2. Git

Branch: `codex/09c2a-admin-consequence-controls`.
Exact dependency: PR #125 head
`c0548a25d39ddc77a92bc02514c83a01f731e9ae`, reconfirmed against the remote
before commit. The new draft PR targets `codex/09c1b-account-suspension`, not
`main`. Code/documentation commit:
`d4e621f1cb831d5f6567818a9ee2a3a01b1285a9`.
The final report commit, PR URL/number and hosted run identity/result are recorded
in the draft PR's final validation comment and the task handoff; this avoids
self-referential SHA edits and duplicate hosted runs. The review worktree remains
available. Parent PRs are neither merged nor modified.

## 3. Existing admin architecture extended

The existing `/admin/cases/[id]` route composes the original evidence/review
view with a separate consequences section. `moderation-server.ts` reads the
case-only history in parallel with independent evidence projections, after
canonical staff authorization. `moderation-operations.ts` owns fresh identity,
role, case and episode checks; the thin Next.js Server Action delegates to the
existing RPCs and revalidates trusted paths. Existing shadcn/Base UI fields,
buttons, cards, alerts and badges are reused without a new dependency or Dialog.

## 4. Consequence history presentation

The flat authorized RPC projection is strictly grouped into separate episodes.
Active and Revoked states, applied/revoked UTC timestamps, both action reasons
and linked already-authorized staff notes remain visible. Matching note author
identity supplies the actor display name when available. Stored plain text is
escaped and preserved. Malformed/failed history never becomes a success-shaped
empty history. The heading/help explicitly says **this case only**, not the
subject's global history or reputation.

## 5. Moderator vs admin controls

Moderators may apply/revoke safety notice, interaction restriction and compatible
content hide. Only current admins receive functional suspension/unsuspension.
Moderators can still read authorized suspension history, without its controls.
Every submit verifies signed claims and the current canonical staff role again;
render-time role and browser staff/target IDs are never trusted.

## 6. Apply flow

Select a compatible action, inspect its factual effect summary, enter two blank
text fields independently, then Confirm apply. Pending state disables controls,
fields, confirmation and cancellation to prevent duplicate submits. Canonical
success revalidates the queue/case and announces the result. No optimistic
episode mutation, implicit review transition or automatic retry occurs.

## 7. Revoke flow

Only an active episode offers its matching role-compatible revoke action.
The server rereads current-case history and binds the validated consequence ID
to its actual type, preventing cross-case revocation or a disguised suspension
through the generic RPC. Revoke has its own blank reason/note confirmation.
Historical revoked episodes remain visible and cannot be acted on again.
Future same-type episodes are separate, not a mutable replacement of history.

## 8. User-facing reason/private-note privacy

Reason shown to the user is required plain text, 1–2,000 Unicode characters;
Private moderation note is independently required, 1–4,000. Help text makes
the audience explicit and warns against reporter identity/staff-only evidence.
Neither report, corroboration, counterstatement nor existing note is autofilled.
The server trims each independently, rejects extra/duplicate/File fields and
passes distinct RPC arguments. Native textarea UTF-16 ceilings allow surrogate
pairs; server limits match PostgreSQL character counts. Client choices and action
results contain no private evidence body. No reason/note is logged.

## 9. Safety notice UX

The effect summary states that this records a moderator-confirmed safety notice,
does not itself restrict the account or create a public badge, and leaves later
contextual warning UX separate. Removing it affects only that episode; other
consequences and blocks remain.

## 10. Interaction restriction UX

The confirmation explains new Project join/Resource-request prevention and
withdrawal of current pending outbound requests. Existing memberships, chats and
accepted Resource coordination remain. Revoke permits future interactions only
subject to other rules and never restores withdrawn requests.

## 11. Project/Resource content-hide UX

The action/effect noun identifies the reported Project or Resource listing.
Public discovery/detail are hidden; new requests/pending acceptance stop while
existing pending requests stay pending. Accepted relationships/history and owner
lifecycle remain. Unhide removes only the moderation barrier, never reverses
cancelled/closed/ended lifecycles or unrelated consequences/blocks.

## 12. Suspension UX

Admin-only copy explains ordinary signed-in/private access denial, pending
outbound request withdrawal, stored relationship/role/content/message/agreement
preservation, no automatic public-content hide, and the supplied reason on the
existing suspension screen. Self-suspension is omitted with the explanation that
another admin is required; the canonical backend denial remains unchanged.
Dedicated apply/revoke suspension RPCs are used. Unsuspend does not recreate
withdrawn requests, removed roles or ended relationships.

## 13. Case-state compatibility

Received cases offer no Apply and explain the existing explicit Start review
action. Under-review and completed cases may apply compatible consequences;
completed cases are not reopened. Revoke is episode-based. Consequence operations
never call the review transition RPC.

## 14. Target compatibility

Profile-scoped consequences use a valid canonical case subject even when the
report targets a message or request. Content hide is offered/checked only for a
direct Project or Resource-listing report, never a profile/message/request's
parent content. Staff cannot enter an arbitrary subject or content ID.

## 15. Error/stale/conflict handling

Finite safe kinds cover changed authority, review required, incompatible target,
duplicate active episode, already revoked, self-suspension, stale/not found,
invalid input and unavailable. Known RPC codes/messages select fixed copy; raw
SQL, lock details and private data never reach the result. A duplicate may
originate from another case and is explained without adding a global API.
Validated commands revalidate `/admin` and their case path after success or
failure. Reload case is explicit. Transport/malformed responses remain
unconfirmed rather than reporting success; even an unexpected idle server result
is rejected.

## 16. Accessibility/responsive behavior

Inline panels use existing semantic controls, associated labels/help/error IDs,
required textareas, expanded-state buttons, live success/error regions and
Cancel focus return. Panel selection resets text drafts rather than copying
them. Buttons wrap; cards/panels remain full-width and long reasons break.
Component tests prove focus, labels, audience copy, pending disables and error
association. No claim of a real-browser visual/accessibility audit is made.

Founder QA remains required by the plan. Use synthetic cases in a separate QA
environment with the dependency migrations, not real accounts:

1. As moderator, compare a received case with an under-review/completed case;
   verify explicit Start review and absence of suspend/unsuspend controls.
2. Open each compatible Apply panel. Verify the two blank fields and effect copy;
   enter visibly different public/private marker text, confirm, then inspect the
   resulting reason and linked private note without changing review state.
3. Revoke with two new distinct marker texts; verify the old episode/history is
   retained and withdrawn requests/owner lifecycles are not restored.
4. As admin, verify suspension/unsuspension and the self-suspension explanation;
   confirm a message/request case never offers parent content hide.
5. Change staff role or revoke the episode in another session before submitting;
   verify bounded failure/fresh state. Check keyboard-only navigation and narrow
   viewport readability, particularly privacy wording and confirmation buttons.

## 17. Backend changes

None. Migrations, RPCs, RLS, grants, generated types, outbox/push behavior,
notification projections and enforcement are identical to the approved base.
The existing case-history RPC was sufficient; no broad subject history/reputation
API or narrow new backend read was needed.

## 18. Web test/validation results

`npm run check:web` passed: **253 tests across 37 files**, **27 tooling tests**,
ESLint, TypeScript/Next route generation and production build. The original base
had 142 Web tests; this adds **111** parsing/role/apply/revoke/history/privacy/
action/UI tests, including inherited-server coverage. The final production SSR
`auth:web:verify:local` also passed real OTP/cookie authentication, signed-out
and ordinary-user admin HTTP 404 boundaries, with no private credential output.
`npm run format:check:web` and `git diff --check` passed. Initial test-writing
failures were missing DOM cleanup, a split-text selector and an incomplete
corroboration fixture; corrected test setup/assertions, not production weakening.

## 19. Database regression results

The complete unchanged `npm run check:db` passed on the isolated QA stack:
reset, schema lint (no errors), security advisors (empty results), **109 pgTAP
files / 3,465 assertions**, every inherited real-auth/domain/Realtime verifier,
**36 consequence winner-order races**, **24 suspension lock-observed races** and
the **193 public-signature suspension audit**. Consequence and suspension real
Auth verifiers each exercised 10 OTP identities. Type regeneration/drift passed
and generated types are unchanged. No inherited database gate was waived.

## 20. Mobile/Site regression results

`npm run check:mobile` passed localization generation, formatting, static
analysis (no issues) and **1,087 tests**. `npm run check:site` passed **53 tests**
(34 UI + 19 worker), lint, typecheck, build and deployment **dry run**.
Mobile/Site production trees and dependencies are unchanged. No APK rebuild or
demo reseed was run: neither is required for this Web-only plan with no database
or public behavior change. No external deployment occurred.

## 21. Hosted CI result

The normal final-head draft-PR hosted attempt is made after both offline commits
are pushed once. Its exact SHA, run URL/attempt, job selection and actual outcome
are recorded in the PR final validation comment/task handoff. The unchanged
workflow selects Web for these source paths; documentation alone adds no costly
jobs. Database/Mobile/Site evidence above is local, not claimed as hosted.
No hosted failure or runner requirement is waived.

## 22. Documentation/roadmap updates

The moderation feature map documents new files, trust boundaries, field privacy,
UTC/Unicode behavior and failure handling. The Web README and system-design
document identify canonical manually controlled consequences. Roadmap keeps
09C1A/09C1B implemented in review, marks 09C2A implemented in review, 09C2B not
started, 09C3 deferred and 09D not started; Plan 09 remains in progress.
The exact prompt archive SHA256 is
`49672987FB55191F0FE539D89E656AC42885F8DDF6F76647D20A324749AA647B`.
Supabase guidance kept enforcement/history canonical; React/Next guidance kept
server-action authorization fresh and independent reads parallel; shadcn guidance
kept explicit labelled confirmations on the installed Base UI components.

## 23. Deferred 09C2B / 09C3 / 09D / Plan 10

Ordinary-user general history/contextual warnings, restricted/content-owner UX,
consequence notification/push/email projection remain 09C2B. Appeals require
09C3 founder policy; minimum-age enforcement remains 09D. Retention, deletion,
anonymization and legal policy remain Plan 10. No scoring, recommendations,
batch moderation or new consequence type was added.

## 24. Stop-worthy findings and review boundary

No backend contract gap or unresolved consequential product decision required
expanding this plan. Founder review must still inspect reason/private-note copy,
role/target compatibility, effects, case-only history and real-browser usability;
the explicit plan requires a draft PR, so it must not merge or deploy.

Read-only `npm audit` reported **17 vulnerable package entries** in the inherited
unchanged lockfile (5 moderate, 11 high, 1 critical). The critical
[Next.js ImageResponse advisory](https://github.com/vercel/next.js/security/advisories/GHSA-vcvr-r3jv-pc5j)
applies to attacker-controlled SVG values rendered with the Node `next/og`
implementation. A source search found no ImageResponse/next-og/OpenGraph-image
usage in these apps; no such exposure path was found here. This is not a clean
dependency-security claim. Dependency triage/update remains separate follow-up;
no blind audit fix or incidental upgrade was made. Local Node 24.13.0 also
produced the inherited jsdom engine warning; tests passed, and hosted CI uses the
repository's Node 24.20.0 pin.

Docker was unavailable initially and became ready after the owner's action.
Only `planets-community-09c2a-qa` (API 54341, DB 54342, Mailpit 54344) was used.
After checks, its disposable synthetic QA volumes were removed and the task's
generated ignored Web config deleted. Shared and other tasks' stacks were not
reset/stopped and the shared stack was verified running. Restored
`supabase/config.toml` SHA256:
`2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6`.
No tracked backend/Mobile/Site/root-tooling/CI/lockfile changes remain.
