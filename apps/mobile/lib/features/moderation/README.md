# Moderation reporting

This feature owns the authenticated reporter experience. `domain/` defines the
bounded report vocabulary and safe reporter projection, `data/` owns the narrow
Supabase RPC contract, `application/` protects identity changes and duplicate
submissions, and `presentation/` provides the report form and the current
user's status list. The corroboration files add the recipient-owned Project
evidence request list/detail, one final response controller, and a best-effort
once-per-app-session prompt with a dedicated retryable screen.

Reports always enter manual review. This mobile feature does not read staff
notes, enforce sanctions, expose reports to a reported person, or assign staff
roles. Project-context disclosures anticipate the later 09A2 evidence flow but
09A2A shares the first explanation only with snapshotted eligible Project
recipients, never the reporter identity, peer responses, or aggregates. The UI
warns that wording may indirectly identify the reporter, that membership is
not proof of witnessing, and that each identity/choice/explanation is visible
only to staff. “Later” writes nothing and may prompt again after app restart.
Responses are immutable evidence, not votes or automatic decisions.
