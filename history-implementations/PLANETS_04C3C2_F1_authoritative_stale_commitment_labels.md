# PLANETS 04C3C2-F1 — Do Not Infer Stale Commitments Without a Valid Options Snapshot

**Repository:** `lillo24/planets.community`  
**Existing PR:** #62 — `codex/04c3c2-mobile-commitment-management`  
**Current stack:** PR #62 → PR #61 → PR #60 → PR #52 → PR #45 → `main`

## Goal

Patch the existing PR #62 only.

Static review found one UI correctness bug in the commitment editor/read-only sheet.

Current presentation logic derives:

```text
isRetained = current commitment ID is absent from `options`
```

That is correct **only when the addable-options RPC successfully returned a canonical options snapshot**.

But two important states intentionally have no valid options snapshot:

```text
1. historical/read-only membership
   → options are never requested

2. transient options-read failure
   → options list is empty because loading failed
```

In both cases the current code treats every commitment as retained/stale and can render:

```text
"No longer requested: Paint"
"No longer requested: Carpentry"
```

even though the client does not actually know that.

Fix this in the existing PR #62.

Do not open a new PR.
Do not merge any PR.
No database/backend change is required.

---

# Correct semantic rule

A commitment may be labeled:

```text
No longer requested
```

only when:

```text
optionsPhase == ready
AND
the canonical current commitment (kind, id)
is absent from the successfully loaded addable-option set.
```

Do **not** infer staleness when:

```text
optionsPhase == notRequested
optionsPhase == loading
optionsPhase == failure
optionsPhase == noLongerEditable
```

because those states do not provide a complete canonical “currently addable” snapshot.

---

# Historical/read-only behavior

For former/ended membership history:

```text
listCommitments only
```

Render the final commitment labels normally.

Do not append:

```text
No longer requested
```

to all historical items.

Historical mode does not need to call `listOptions` merely to classify old labels.

---

# Current membership with transient options failure

If:

```text
current commitments load successfully
options RPC fails transiently
```

continue showing the current commitments normally.

Show the existing local options error/retry.

Do not mark those commitments stale until a successful option read proves that.

After retry succeeds:

```text
optionsPhase = ready
```

then genuine current-but-non-addable commitments may receive the stale/retained treatment.

---

# Current membership no longer editable

If the options RPC returns canonical lifecycle conflict and the controller transitions to:

```text
optionsPhase = noLongerEditable
```

show the commitment set read-only.

Do not infer that every commitment is “No longer requested.”

The Project becoming non-operational is not equivalent to every commitment becoming a stale Project requirement.

---

# Suggested implementation

Keep the current model if convenient, but make retained/stale classification explicitly depend on whether options are authoritative.

For example, conceptually:

```text
itemsFor(kind, classifyRetained: optionsPhase == ready)
```

or derive `isRetained` in the controller only when the options snapshot is ready.

Do not encode this by checking whether `options.isEmpty`; an authoritative empty option set is valid and should mark existing commitments retained.

The important distinction is:

```text
options snapshot successfully loaded?
```

not:

```text
options array non-empty?
```

---

# Tests

Add/update tests for at least:

1. historical read-only commitments are **not** labeled “No longer requested”;
2. current commitments during initial option loading are not labeled stale;
3. transient options failure leaves current labels normal while showing Retry;
4. successful options read marks only genuinely absent current commitments as retained/stale;
5. a successful authoritative **empty** options result marks existing current commitments stale;
6. `noLongerEditable` lifecycle state leaves final commitments read-only without falsely marking all as stale;
7. existing retained stale commitment edit/remove/reselect behavior still passes;
8. after a real successful removal/reload, the stale removed item still disappears as designed.

Run:

```text
npm run check:mobile
flutter build apk --debug
git diff --check
```

The full stack's backend validation remains externally blocked; do not change that classification.

---

# Documentation

If any README currently implies that stale status is always inferred by absence from `options`, clarify:

```text
stale/retained presentation is only authoritative after a successful current-options read.
```

No roadmap scope change is needed.

---

# Completion report

Return:

1. PR #62 new head;
2. changed files;
3. corrected retained/stale classification rule;
4. historical behavior;
5. transient-option-failure behavior;
6. no-longer-editable behavior;
7. tests added/updated;
8. mobile validation;
9. hosted Validation executed/not-executed;
10. warnings/blockers.

Do not merge any PR.
