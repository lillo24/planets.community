# PLANETS — Merge Template Workshop PR #146 + Proposal requested-badge polish

## Goal

Finish the Template Workshop integration now that founder review has passed, with one small UI correction discovered during physical-device review, then merge PR #146 into `main`.

Founder review outcome from the product owner:

- Template Workshop behavior/content/copy flow/similar-Proposal flow/draft navigation were tested and approved.
- One UI issue remains:
  - On public Proposal cards, the **“Richiesta inviata” / “Request sent”** badge currently sits beside the Proposal status badge (for example **“In programma” / “Upcoming”**).
  - This consumes horizontal space from the title and can make the title unnecessarily tall.
  - Move **only the requested badge** to the **top-right as an overlay on the cover image**.
  - Keep the Proposal lifecycle/status badge in the card content area.
  - Preserve the existing requested-card visual treatment and behavior unless a repository constraint requires a narrowly justified adjustment.

After that fix, reconcile PR #146 with current `main`, validate the combined result, and merge it.

## Repository and verified starting state

Repository:

`https://github.com/lillo24/planets.community`

At prompt preparation time:

- PR #146: `[TW-STACK01] Integrate Template Workshop with main for founder review`
- PR #146 state: **draft, open, unmerged**
- PR #146 head: `e0d71724537c83b328a85b21437c51a12aac21c1`
- PR branch: `codex/tw-stack01-main-integration`
- Latest observed `main`: `eb70fe249978585f754fa9175d337d7ef8b99e17`
- The PR and `main` are currently diverged.
- Re-fetch before starting; if `main` has advanced again, integrate the then-current `origin/main` rather than assuming the SHA above is still current.

The five main-side commits since #146's original integration base were observed as:

1. `6713302` — account exits and configurable navigation shortcut (#147)
2. `093989c` — compact browse filters and open Proposal covers (#150)
3. `fa082a2` — provider-ready authentication infrastructure (#151)
4. `188544f` — Scambio browse/card polish (#152)
5. `eb70fe2` — durable participation pair conversations (#153)

Do not regress any of these while reconciling #146.

The eight predecessor Template PRs are already closed as superseded and must **not** be reopened or separately merged:

- #127
- #129
- #132
- #135
- #137
- #140
- #143
- #145

## Important implementation observation

At the observed heads, this file is byte-identical in #146 and current `main`:

`apps/mobile/lib/features/proposals/presentation/proposal_widgets.dart`

Current `ProposalCard` behavior is structurally:

- `ProjectCoverImage`
- then padded card content
- title + a trailing `Wrap`
- that trailing `Wrap` contains:
  - `RequestedBadge()` when `isRequested`
  - `ProposalStatusBadge(...)`

That is the reproduced cause of the layout problem.

Likely fix: compose the cover and `RequestedBadge` with a `Stack`/positioned overlay, using existing spacing/tokens, and remove `RequestedBadge` from the title/status row. Inspect the actual current code before editing; choose the simplest implementation consistent with the existing card system.

Do not move the status badge unless needed for a concrete layout defect. The requested product change is specifically to move **“Richiesta inviata”** onto the image.

## UI acceptance criteria

For a public Proposal card with `isRequested == true`:

- “Richiesta inviata” / “Request sent” appears at the **top-right of the cover image**.
- It is visibly overlaid on the cover/cover placeholder, inside the card bounds.
- It no longer consumes width in the title/status row.
- “In programma” / “Upcoming” remains the Proposal lifecycle/status badge in the content area.
- Long titles receive the width recovered from removing the requested badge and no new overflow/layout exception is introduced.
- Existing requested-card border/highlight behavior remains unless there is a demonstrated reason to change it.
- Tapping the card behaves exactly as before.
- Accessibility semantics for the requested state remain available.
- EN/IT text remains unchanged unless the current repository already changed it.
- Non-requested cards are visually/behaviorally unchanged.

Prefer a focused widget regression test that proves the requested badge is laid out within the cover area and that a narrow card with a long title does not overflow. Reuse existing keys/semantics where practical instead of adding test-only production behavior.

Do **not** broaden this into a redesign of Proposal cards, Tavolo cards, request semantics, statuses, or the participation domain.

## Reconcile #146 with current main

Work from an isolated/clean checkout for PR #146. Preserve unrelated user work and other worktrees.

1. Fetch remote state and verify the actual PR head and latest `origin/main`.
2. Inspect ancestry and differences before modifying anything.
3. Integrate the latest `origin/main` into the #146 integration branch in a way that preserves both histories.
   - Do not reconstruct the Template stack via cherry-picks.
   - Do not drop current-main behavior with blanket `ours`/`theirs`.
   - Resolve conflicts semantically.
4. Apply the requested-badge UI fix on the reconciled branch.
5. Keep #146 as the one integration vehicle; do not create another feature PR unless GitHub/repository state makes updating #146 impossible.

Important overlapping areas to treat carefully include:

- router/navigation composition;
- auth/provider-ready infrastructure;
- Proposal browse/detail changes;
- participation pair conversations;
- demo-world composition;
- EN/IT catalogs;
- package scripts / Validation workflow;
- generated database types.

The original #146 integration intentionally composes Template draft-departure behavior with native routing/link behavior. Current main has additional navigation/auth work. Preserve all of these. Do not solve conflicts by disabling draft saving, native-link replay, auth continuation, current navigation settings, or newer message/request behavior.

## Database and generated artifacts

Current `main` has database/type changes newer than #146, including participation pair conversations.

If the reconciliation changes the combined migration history/types:

- replay/validate the integrated migrations on a disposable local stack;
- regenerate database types through the repository's canonical generator;
- preserve the repository's participation RPC nullability correction;
- do not manually choose one side of `database.generated.ts` as the final answer;
- do not rename/rewrite already-published migration files to make ordering easier.

Respect repository-pinned tooling. Do not opportunistically upgrade Supabase CLI or unrelated dependencies.

The combined demo world must retain both:

- Template Workshop/demo fixtures from #146;
- newer main demo additions, including current participation-conversation behavior.

## Validation

Run the smallest useful focused checks first for the card change, then validate the actual integrated final head.

At minimum:

### Focused mobile/UI

- formatting/analyzer for affected Flutter code;
- focused Proposal card/public Proposal tests;
- a regression test for the requested badge overlay / narrow long-title layout.

### Integrated mobile

Run the repository's normal mobile check suite on the final integrated head.

### Database/integration

Because this is not merely a one-file UI PR but a reconciliation of a previously validated stack with a newer `main`, run the repository's complete relevant database/integration gate rather than relying only on the old #146 evidence.

Preserve and verify:

- Template Workshop catalog/detail/copy/retry;
- draft-on-navigation behavior;
- similar-Proposal suggestions;
- participant invitation/link behavior already integrated by #146;
- current participation pair-conversation behavior from `main`;
- combined demo reset/verification;
- generated-type drift checks.

Use disposable/local targets only for destructive reset/seed commands.

### Hosted CI

Push the final #146 head and obtain one final all-area hosted Validation on that exact head.

Inspect the jobs rather than treating a workflow badge generically as success. Do not merge if a required/relevant final-head job is failing or if the only apparent success comes from a superseded run.

If a failure exposes a major product/architecture decision rather than a mechanical integration issue, stop and report it instead of guessing.

## PR update and merge

Once the final head is green:

1. Update #146's description/status so it reflects:
   - founder review approved;
   - requested-badge polish included;
   - latest-main reconciliation;
   - exact final validation evidence;
   - any remaining release-only QA that is still genuinely outstanding.
2. Mark #146 ready for review if GitHub requires leaving draft state before merge.
3. Merge **PR #146** into `main`.

### Merge method

Use a **merge commit**, not squash/rebase, for this integration PR.

Reason: #146 was deliberately constructed to preserve the cumulative Template history and its selected main history as ancestors. A squash merge would land the files but discard that ancestry from `main`.

Before merging, verify both the latest selected `main` input and the Template integration history are ancestors of the final #146 head.

After merging, verify on updated `main` that:

- the final pre-merge `main` commit is an ancestor;
- `e0d71724537c83b328a85b21437c51a12aac21c1` is an ancestor;
- #146 is reported merged;
- the requested-badge fix is present;
- the checkout is clean.

Do not reopen or merge #127/#129/#132/#135/#137/#140/#143/#145; they are already closed as superseded.

## Cleanup

After successful merge:

- update local `main`;
- remove only task-owned temporary worktrees/branches that are safe to remove;
- preserve unrelated worktrees, local changes, credentials/config, emulator state, and other ongoing tasks;
- do not deploy, migrate a shared/staging/production database, publish a store build, or activate external auth providers as part of this task.

## Final report

Return a concise implementation report with:

- initial and final `main` SHAs;
- #146 old and final head SHAs;
- merge commit SHA on `main`;
- exact files changed for the requested-badge polish;
- semantic conflict decisions made while integrating newer `main`;
- focused test results;
- complete local/integrated validation results;
- final hosted Validation link/status;
- ancestry verification;
- confirmation that #146 is merged and the superseded Template PRs remained closed;
- any remaining release-only QA or genuine warnings.

Do not claim checks that were not run.
