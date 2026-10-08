# Moderation reporting

Account suspension is stronger than an interaction restriction: while suspended,
ordinary report/corroboration/counterstatement and own history APIs/UI are denied.
Stored evidence remains unchanged and can become available again after revocation
if the existing case lifecycle permits. The auth feature owns the minimal safe
suspension screen; staff controls are 09C2A, contextual warnings/delivery and
appeals remain the later 09C2B/09C3 slices.

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

## Private PLANETS notices (09C2B1, draft review)

This is the affected user's own consequence history, separate from submitted
reports and Review Requests. Settings links ready profiles to the protected
`/settings/notices` child; Back returns to Settings. It adds no primary tab.

- `domain/own_consequence_models.dart` validates the exact ten-field safe
  projection, four types, nullable content and consistent apply/remove episodes.
  The raw server timestamp and UUID are the cursor, not a localized date.
- `data/own_consequence_gateway.dart` calls only
  `list_own_moderation_consequences`, with the verified expected ID, default
  20-row pages, exact cursor pair and a 15-second timeout. Malformed, duplicate
  or non-advancing pages fail explicitly; there are no automatic RPC retries.
- `application/own_consequence_controller.dart` derives identity from the ready
  Auth session, rejects late requests and clears reasons on every session
  revision or disposal. Page failures retain loaded rows with an explicit error;
  refresh discards old rows before loading page one, so stale active status is
  not confirmed-looking. A `PT403` denial requests Auth's existing narrow status
  refresh and router guard; general history is never allowlisted for suspension.
- `presentation/own_consequences_screen.dart` renders EN/IT draft explanations,
  active/removed state, device-local dates and verbatim selectable plain reasons.
  Optional owned-content titles have no management/public links. Isolated EN/IT
  widget previews cover narrow/large-text layouts without private backend data.

Reasons stay in account-scoped memory only: no generic cache, preferences,
analytics, breadcrumbs, outbox consumption or reason logging. This screen is
not an authorization boundary or a global restriction summary. It adds no
counterparty warnings, public badges, appeals or notification delivery. Exact
draft wording and remaining founder choices are in
`docs/development/moderation-private-history-09c2b1-review.md`.

`test/features/moderation/` covers parsing/SDK transport, controller identity,
UI, localization and route boundaries. The dedicated SDK integration entrypoint
`integration_test/own_history_test.dart` exercises real OTP sessions and canonical
staff apply/revoke on a disposable local backend; it is not part of host widget
tests or hosted CI and never enables test controls in `lib/main.dart`. See the
review report for preparation/run commands and actual execution status.

## Own new-request explanation (09C2B2, draft review)

After a canonical new Project/Resource `PT409`, the request form calls
`data/own_interaction_restriction_gateway.dart` once for a fresh expected-ID
boolean, with a 15-second timeout and strict parsing. History pagination never
supplies current eligibility. `application/own_request_restriction_controller.dart`
owns one auto-disposed form scope, invalidates every session/attempt revision,
rejects late results and sends `PT403` to the existing Auth refresh. Failed,
inactive or unknown checks leave the generic canonical error understandable.

`presentation/own_request_restriction_notice.dart` announces factual EN/IT draft
copy and pushes the existing guarded notices route above the form/modal. Back
retains the same-session draft; account loss clears private text/options. This
read cannot authorize or retry a mutation, identify a counterparty restriction,
expose reasons/staff/cases, or guarantee eligibility after removal. Canonical
Resource active-request recovery remains visible. No outbox consumer is added.
See `docs/development/moderation-own-request-explanations-09c2b2-review.md` for
exact wording, validation and remaining founder review.
TW02 extends the shared typed vocabulary with `proposal_template`.
`proposalTemplateReportTarget` in `moderation_routes.dart` gives TW04 the current
form route without a Workshop screen/navigation entry. Original Creators use the
same authenticated manual-review flow and neutral receipt. Italian/English
copy explains that reporting removes nothing automatically. Template provenance
never activates Project corroboration or Resource counterstatement disclosures;
identity-change/retry safeguards and narrow own-report parsing are reused.
