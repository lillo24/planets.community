# Moderation reporting

This feature owns the authenticated reporter experience. `domain/` defines the
bounded report vocabulary and safe reporter projection, `data/` owns the narrow
Supabase RPC contract, `application/` protects identity changes and duplicate
submissions, and `presentation/` provides the report form and the current
user's status list.

Reports always enter manual review. This mobile feature does not read staff
notes, enforce sanctions, expose reports to a reported person, or assign staff
roles. Project-context disclosures anticipate the later 09A2 evidence flow but
09A1 does not yet share an explanation with other participants.
