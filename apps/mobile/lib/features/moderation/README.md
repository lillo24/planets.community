# Moderation reporting

GRP01 adds genuine `group` wire targets so own-report history remains readable.
Group reports have no Project context and use standard disclosure; the public
entry point belongs to GRP02. See the
[backend contract](../../../../../docs/development/persistent-groups.md).

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

Profile navigation exposes My Reports and Review Requests as siblings. Their
canonical paths are `/profile/reports` and `/profile/review-requests`; evidence
details are nested only under Review Requests so Back returns to that list, and
Back from either sibling returns directly to Profile. Legacy nested Review
Requests URLs redirect to the canonical destination.

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

TW02 extends the shared typed vocabulary with `proposal_template`.
`proposalTemplateReportTarget` in `moderation_routes.dart` gives TW04 the current
form route without a Workshop screen/navigation entry. Original Creators use the
same authenticated manual-review flow and neutral receipt. Italian/English
copy explains that reporting removes nothing automatically. Template provenance
never activates Project corroboration or Resource counterstatement disclosures;
identity-change/retry safeguards and narrow own-report parsing are reused.

D adds typed `group_contact_request` and `group_contact_message` targets through
the same manual form and receipt. Own reports use the additive v2 projection;
known-content reporting remains available after D authority loss. These targets
do not activate Project corroboration or Resource counterstatements. Long category
labels wrap within the form and menu at narrow width and enlarged EN/IT text.

M adds `member_contact_request` and `member_contact_message` targets; messages
bind `member_contact_chat` context. Own report history uses the additive v4
projection, preserving Project, Resource, D and coordination report kinds.
Known received-note/message IDs remain reportable through canonical evidence
projection after ordinary read access ends. No manager chat access is added.

## UIAUDIT02 reporter projection and labels

The additive `uiaudit02_people_report_summaries` migration extends the private
summary chain with bounded generic labels for all five supported People targets.
All supported own-report readers retain identity, ownership, pagination, grants
and legacy summaries. The extension reads no target bodies, profiles or evidence;
own retained reading still uses the existing canonical identity rules with the
People gate OFF. The strict mobile parser continues to reject malformed summaries.

`presentation/moderation_target_label.dart` localizes typed People/Resource-request
summaries at the presentation boundary. Persisted wire kinds and historical terms
remain unchanged. Witness choices use a single RadioGroup with wrapping labels;
selection, submission locking and the existing response contract remain.
