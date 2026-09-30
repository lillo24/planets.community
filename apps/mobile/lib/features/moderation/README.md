# Moderation reporting

This feature owns the authenticated reporter experience. `domain/` defines the
bounded report vocabulary and safe reporter projection, `data/` owns the narrow
Supabase RPC contract, `application/` protects identity changes and duplicate
submissions, and `presentation/` provides the report form and the current
user's status list. The evidence-request files own one discriminated Review
Requests history and a best-effort once-per-app-session oldest-pending prompt
across Project corroboration and Scambio-Dona counterstatement requests. The
kind-specific files retain separate detail, validation, and immutable response
contracts.

Reports always enter manual review. This mobile feature does not read staff
notes, enforce sanctions, expose reports to a reported person, or assign staff
roles. Project-context disclosures anticipate the later 09A2 evidence flow but
09A2A shares the first explanation only with snapshotted eligible Project
recipients, never the reporter identity, peer responses, or aggregates. The UI
warns that wording may indirectly identify the reporter, that membership is
not proof of witnessing, and that each identity/choice/explanation is visible
only to staff. “Later” writes nothing and may prompt again after app restart.
Responses are immutable evidence, not votes or automatic decisions.

09A2B gives only the canonical reported Resource counterparty the original
category, explanation, and safe request context. The mobile projection has no
reporter identity field, staff notes, peer evidence, or other cases. A
counterstatement is required, trimmed to 10–4000 characters, and final after
submission; exact delivery retries reuse one client submission ID. Completed
cases show unanswered requests as closed and omit them from pending prompts;
reopen restores the same unanswered request. “Later” writes nothing. The copy
warns that a two-person interaction can make reporter identity inferable and
that staff review is manual. This feature emits no notification or Resource
state change.
