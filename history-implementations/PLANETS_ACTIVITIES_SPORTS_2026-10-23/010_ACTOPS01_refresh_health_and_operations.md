# ACTOPS01 — maintain the catalogue without babysitting

Read [001_context.md](001_context.md). Depends on merged 005. Use any implemented connectors; synthetic adapters can verify orchestration when live sources are unavailable. Do not activate hosted scheduling/imports as part of this step.

## Outcome and existing evidence

The repository already has a disabled daily refresh workflow, manual Node import CLI, explicit target check, server-only credentials and per-source leased atomic runs. Completed run rows are pruned on new runs; if scheduling stops, that alone does not guarantee ongoing maintenance. The old workflow is hard-coded to blocked Agenda Trento.

Finish the operational path for the small multi-source catalogue. Extend current tooling and runbooks, keeping ordinary cron/self-hosted Supabase portability. No new dashboard, managed queue, monitoring vendor or host provisioning.

## Required operations

- A bounded command/workflow can select an explicit allow-listed source or an explicitly configured small source set and refresh independently. Respect per-source supported kinds, reuse gates, due cadence, local target safety and parent runtime/attempt budgets. Do not fetch every known source, retry indefinitely or repeatedly hit Agenda Trento's known block.
- One source's blocked/failed import leaves others eligible to run. Output a compact per-source outcome plus overall success/partial/failure, and use meaningful nonzero failure semantics. Do not let a scheduler report success merely because one source succeeded or because none were configured.
- Keep separate run identities/leases and per-target/source concurrency appropriate to the existing workflow. Prevent overlapping execution and late completions from corrupting state. Inspect actual Actions job/runtime limits before choosing a sequential runner versus a tiny bounded matrix; no speculative parallel infrastructure.
- Preserve/manual dry-run validates without canonical writes. Applying requires explicit target and credential equality checks under the existing policy. Reuse server-only secrets; no mobile/public-env keys, no PR/fork secrets or credentials embedded in commands/docs.
- Use a modest declared default cadence: normally daily for official calendars and the municipal directory, adjustable through bounded private/code-owned source policy. Do not turn that into per-user or background mobile polling. Fetch conditional content only when the source actually supports ETag/Last-Modified and a 304 can revalidate the exact known complete revision; otherwise do a bounded fresh fetch.
- Keep observation freshness separate from course season/event dates and organizer-confirmed availability. An unavailable run preserves last valid rows within their own expiry policies. A healthy source cannot refresh records it did not actually observe. Explicit cancellations/removals follow source contract; absence from a partial result is not cancellation.
- Detect obvious source-shape anomalies: a previously nonempty full export becoming structurally empty, duplicate IDs, unknown schema/type drift or truncated traversal must yield actionable diagnostics rather than a destructive “success.” Do not freeze normal genuine source changes by hard-coding the planning row count. Any threshold needs a documented conservative rationale and explicit local tests.
- Provide private/operator inspection of source last attempt/success, accepted/rejected/changed counts, per-record freshness and enabled/rights state using existing safe CLI/SQL conventions. No new user-facing technical dashboard or public raw run endpoint. Logs contain bounded codes/counts and source IDs, not raw documents, personal contacts, tokens or full request URLs with secrets.
- Provide bounded maintenance for expired leases and existing compact run metadata retention, runnable even if no source refresh succeeds. Honor existing retention rules; do not introduce historical raw-response storage or delete canonical provenance/history for convenience. Any canonical expiry remains a visibility rule unless an already authorized retention policy says otherwise.
- Public mixed-source health accurately distinguishes unconfigured, never-synchronized, healthy empty, partial/degraded, stale and unavailable states. Keep UI copy concise and distinguish client transport failure from source upstream trouble; frontend pull-to-refresh reads backend only.

## Activation and rollback handoff

Leave schedules **disabled by default** and commit no enabled hosted source rows. Document exact configuration order: required migrations, source/licence/origin evidence, disabled source metadata, local dry-run/acceptance, owner-controlled enablement, first bounded hosted import, public-read validation, optional schedule activation, and client release/config if needed.

For each implemented source, give the actual CLI invocation and environment placeholder names derived from code, including how to disable/unpublish just that source immediately, stop the schedule and recover from a failed import. Avoid fictitious flags or unsupported Supabase CLI commands; discover current commands via help. Do not print secret values. Clearly separate already authorized automatic staging migration behavior from manual hosted actions this queue has not performed.

No account creation, billing, secret updates, live schedule switch, provider-budget increase, production deployment or manual hosted import is authorized here. Missing owner configuration is a precise final setup item, not a reason to abandon other implementation.

## Acceptance and validation

Test orchestration with source A success/source B failure, B rights-blocked before provider IO, all disabled, all failed, a successful empty full traversal, interrupted run, expired lease and a bounded parent timeout. Prove no cross-source loss and meaningful exit/outcome codes. Verify local dry-run zero writes and wrong-target refusal.

Validate workflow YAML/permissions/concurrency with repository tooling and relevant CI. Test that defaults send no provider traffic and secrets cannot enter PR/fork jobs. Check retention maintenance bounds and safe logs. Re-run affected catalogue/public-health UI checks if changed; no paid infrastructure is needed.

Update operational runbook, feature maps and progress; merge, then immediately proceed to 011. Record exactly what is implemented versus configured/enabled anywhere.
