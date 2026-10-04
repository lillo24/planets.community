# PLANETS WEBHOST-01 — Cloudflare Admin Compatibility and Hosting Limits

**Revision:** Resume after validated 09C2A PR #126; reviewed 2026-10-03.

## Objective

Determine whether the existing dynamic `apps/web` application, including the completed 09C2A moderation controls, can run reliably on Cloudflare within PLANETS' low-cost hosting constraints. Produce reproducible local compatibility evidence, the smallest justified hosting configuration, and a clear hosting recommendation with unresolved checks stated explicitly.

This is an assessment and local hosting-readiness task. It does not authorize a deployment, DNS change, paid-plan activation, or production backend work.

Success means the founder can review concrete evidence and know which option is viable, what it would cost, and what remains before publication. “Build passed” and “low moderator traffic” are insufficient conclusions about the free tier.

## 1. Dependency and Git workflow

**Repository:** `lillo24/planets.community`

**Required predecessor is completed:** [PR #126 — 09C2A Admin Moderation Consequence Controls](https://github.com/lillo24/planets.community/pull/126).

**Exact selected base:** `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7`.

**Base branch / draft PR target:** `codex/09c2a-admin-consequence-controls`.

PR #126 is open, draft and cleanly mergeable. It is exactly two commits ahead of PR #125 head `c0548a25d39ddc77a92bc02514c83a01f731e9ae`, with no divergence. #125 itself is stacked on #123 head `010471320779ffb5edaa7546b12cdc8f14809d2d`. Do not reimplement these predecessors or require them to merge before this explicitly authorized stacked task.

This revision supersedes the earlier read-only stop caused by missing 09C2A. Resume WEBHOST-01's assessment, local configuration, runtime tests and draft-PR workflow now. Existing read-only findings may be reused after verifying their version-sensitive claims.

Current main is `996f019f19f9fc3f661c388c30cb01d966e64d37`, after PR #128's participant-invitation domain. The selected base is #126, not this newer main; do not silently import separate invitation/template work into the hosting branch. Record the known separation and preserve the stack for later integration.

At execution:

1. Read root and applicable nested `AGENTS.md`, architecture documents, and the current dependency graph.
2. Fetch #126 and confirm the exact head and #125/#123 ancestry above. Inspect changed commits if #126 has moved; proceed with a verified compatible update and record it, but surface any material moderation/auth policy change before using it.
3. Create an isolated branch/worktree from the selected #126 head, suggested name `codex/webhost01-cloudflare-admin-compatibility`. If an isolated managed checkout is already provided, use it. Check whether the earlier attempt created reusable work before creating duplicates.
4. Open a draft stacked PR targeting `codex/09c2a-admin-consequence-controls`. If #126 has since merged and its branch disappeared, use main containing it and record the new verified base rather than inventing a branch or using stale main.
5. Commit intended configuration, checks, and findings; push and open the draft PR. Leave it unmerged for hosting-choice and evidence review. Do not change parent PRs, branches or main.

No additional moderation product decision or completed manual browser review is required before the local hosting assessment. Remaining browser usability checks belong in this task's validation evidence. Do not merge or deploy.

### Validated inherited baseline

[Hosted Validation run 37143553475](https://github.com/lillo24/planets.community/actions/runs/37143553475) passed on the exact #126 head, attempt 1. Change classification and Web ran successfully; Database, Mobile and Site were skipped by the unchanged change-scoped policy.

The predecessor reports local Web 253 tests and tooling 27, complete database 3,465 assertions plus inherited consequence/suspension races, Mobile 1,087 tests, Site 53, and production SSR OTP/cookie/unauthorized-admin checks. These are inherited results, not claims that this hosting task reran them.

09C2A source review found no code/policy blocker in fresh server authorization, admin-only suspension, self-suspension prevention, case-bound revocation, independent history, or reason/note separation. No real-browser visual/usability audit was claimed. Hosting and dependency security remain unverified by those results.

## 2. Current implementation evidence

The inspected repository separates these responsibilities:

| Surface | Current owner | Relevant behavior |
| --- | --- | --- |
| Informational/launch website | `apps/site`, Vite/React | Native Cloudflare Worker with Static Assets; `/api/waitlist` uses D1 and Turnstile. |
| Discovery and authenticated administration | `apps/web`, Next.js | Dynamic server rendering, Supabase SSR sessions, staff-authorized `/admin`, server actions. |
| Product data and authorization | Supabase/PostgreSQL | Canonical RPCs, RLS, moderation consequences, suspension, private evidence. |
| Main user application | `apps/mobile`, Flutter | Android/iOS product experience. |

Verified manifests on main and #125 specify Next.js `16.3.4`, React `19.2.8`, `@supabase/ssr` `0.12.5`, `@supabase/supabase-js` `2.113.0`, and `@sentry/nextjs` `10.73.0`. Root engines require Node 24 and npm 11. Recheck actual lockfile resolutions at the selected base.

Important existing implementation:

- `apps/web/src/proxy.ts` calls the Supabase session-refresh boundary.
- `apps/web/src/features/auth/update-session.ts` propagates refreshed cookies and response-cache headers.
- `apps/web/src/lib/supabase/server.ts` creates a per-request server client through `cookies()`.
- `apps/web/src/features/moderation/` verifies claims and canonical active staff role, then calls database RPCs.
- 09C2A is implemented at the selected base: `moderation-consequence-models.ts` parses case-only immutable history and strict commands; `moderation-consequence-components.tsx` renders episodes; `moderation-consequence-controls.tsx` owns explicit blank reason/note forms through `useActionState`; `performModerationConsequence` reauthorizes and calls dedicated canonical RPCs.
- Admin layout authorization precedes streaming; signed-out and ordinary-user `/admin` access returns a genuine HTTP 404.
- Existing moderation server actions call `revalidatePath`; 09C2A adds consequence apply/revoke actions.
- Invite responses have privacy headers, and `/.well-known` routes have fail-closed association behavior.
- Optional Sentry instrumentation distinguishes Node/edge runtime and must be checked under any adapter.
- Main has no web Wrangler/OpenNext/vinext hosting configuration. `apps/site/wrangler.jsonc` is a separate existing deployment configuration.

Repository configuration does not establish current cloud resource status, actual plan, DNS state, or resource ownership. Do not claim a site is deployed or undeployed without evidence.

## 3. Sources and external access

Required external context: current official Cloudflare and relevant adapter documentation. This prompt contains the product constraints; no Google Doc or Library file is needed to execute it. Read the archived 09C2A prompt/report in the repository when available.

Start with:

- [Cloudflare Next.js guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/)
- [Cloudflare OpenNext guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/opennext/)
- [OpenNext for Cloudflare](https://opennext.js.org/cloudflare)
- [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Static Assets billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)

Use version-compatible primary documentation and upstream release/support information. Follow `apps/web/AGENTS.md`: read the relevant bundled Next.js documentation before coding.

At prompt preparation, Cloudflare's Next.js guide recommended **vinext**, described it as beta, and documented OpenNext as an alternative adaptation of `next build`. Its OpenNext guide listed Node.js middleware as unsupported. Therefore neither “Cloudflare supports Next.js” nor an old generic OpenNext recipe proves compatibility with this repository's Next.js 16 proxy, Supabase SSR, and Sentry versions. Recheck these specifics.

Cloudflare credentials are not required for the local phase. Use existing authorized read-only account evidence if available and relevant; do not initiate login or fabricate account details. If required official compatibility information cannot be obtained, report that limitation before claiming provider support. Complete independent repository/local work where possible.

## 4. Architecture and domain guardrails

Preserve the existing public website, waitlist, and `planets.community` routing. Give any candidate web Worker its own name/configuration and isolated output; never reuse `planets-public-site` or its D1/Turnstile bindings.

A possible later layout is the current public domain for `apps/site` and a separate subdomain for `apps/web`. Treat that as a documented proposal, not an approved or configured domain. The whole existing web app is the initial assessment unit; `/admin` is not an independently deployable package today.

Keep Supabase/PostgreSQL authoritative. The admin uses the current user's verified session and canonical staff RPCs. Do not add a service-role bypass, a Cloudflare copy of moderation state, or a competing backend. Support configurable managed/local/self-hosted Supabase endpoints; Cloudflare cannot call the developer computer's `localhost` in a future deployment.

Do not move the admin into `apps/site`, convert authenticated server behavior to static export, rewrite it as a browser-only SPA, or remove discovery/auth/invite routes for convenience.

Do not change consequence policy, suspension, reason privacy, role authority, RLS, lifecycle, relationships, or notifications. 09C2B stays separate.

## 5. Compare viable runtime paths before choosing

Inspect actual runtime imports, build output, route behavior, and dependency versions. Produce a short comparison:

| Candidate | Evidence to establish |
| --- | --- |
| Current Next.js through a supported Cloudflare adapter | Exact Next/proxy/SSR/action support, retained build behavior, Sentry compatibility, required bindings, maintenance burden. |
| Current Cloudflare-recommended Next.js-compatible path | Exact compatibility, beta/stability status, deviations from current Next behavior, tooling changes and migration size. |
| Conventional Node hosting of existing Next.js | Minimal fallback if Cloudflare cannot preserve behavior economically; distinguish an existing server's incremental cost from its total operating cost. |

Select the least disruptive supported option from evidence. Adapter/tooling versions must be pinned consistently with repository policy; update lockfiles deliberately.

Check the previous research's reported OpenNext/Next patch-version mismatch against the actual upstream release and support matrix. Do not install a latest adapter blindly or assume the existing Node-runtime `proxy.ts` is supported. When a narrow stable patch within the existing dependency version line is required for verified adapter compatibility or a security fix, it may be implemented here with documented justification, corresponding package/lockfile updates, and full affected regression checks. This does not authorize a major framework upgrade, downgrade, runtime replacement or broad dependency refresh.

The #126 report documented 17 inherited vulnerable package entries, including one critical Next.js ImageResponse advisory, with no `next/og` exposure found in that source review. That is a reported snapshot, not complete security clearance. Re-run read-only dependency triage for the selected versions and distinguish production runtime exposure, optional/build tooling, patched ranges and actual source use using primary advisories. Do not dismiss other high-severity entries solely because ImageResponse is unused. Make only justified narrow fixes tied to this hosting path; record separate follow-up for unrelated or consequential changes. Do not run a blind audit fix.

Local experiments in disposable output are allowed. A prototype with beta tooling is not authorization to adopt a replacement production runtime. If viability requires a framework/runtime migration, dependency downgrade, removing Sentry, a paid service, or a substantial architecture change, document the concrete result and options for review. Continue the assessment without silently making that decision.

If a supported additive adapter is viable, implement its minimal local configuration and reproducible build/preview/dry-run commands in the isolated branch. Keep the current Next development/build path working. Document why any change to it is necessary.

Do not add R2, KV, Durable Objects, Queues, Images, or other resources merely because an example includes them. If an adapter needs one, explain what it stores, why it is required, its cost/limits, and how authenticated data is excluded from shared caches. Unnecessary ISR/cache features should stay disabled rather than create new infrastructure.

## 6. Build and runtime compatibility checks

Inventory and test the runtime features the selected baseline actually uses:

- App Router, React Server Components, SSR/streaming, route handlers, async headers/cookies, `proxy.ts`.
- Email OTP, refresh, sign-out, response/request cookie propagation and multiple `Set-Cookie` headers.
- Public discovery, missing/invalid route responses, invite return-path/privacy behavior, association handlers.
- Staff queue and case detail with reports, notes, corroboration and counterstatements.
- 09C2A apply/revoke actions, form submissions, validation, safe conflict errors, redirects/revalidation.
- Monitoring imports and optional Sentry-off/on runtime compatibility without real personal data.

Run the generated application in the actual local Workers-compatible runtime, not only `next dev` or `next start`. A passing conventional Next build remains a regression check, not adapter proof.

Use synthetic local fixtures and the supported local Supabase setup for authenticated tests. Exercise the real browser/form boundary and canonical RPCs for at least one authorized apply/revoke flow; do not replace all security-sensitive behavior with mocks. Cover both ordinary moderator controls and admin-only suspension. Existing domain tests may supply unchanged consequence semantics.

Complete the predecessor's outstanding real-browser QA on the local candidate runtime: separate blank reason/note fields and their stored values, moderator/admin/self-suspension controls, direct-target content-hide compatibility, received versus reviewed/completed case behavior, active versus historical episodes, stale state, keyboard focus/labels and narrow viewport readability. Use a disposable synthetic backend/account scope. Record the browser/runtime/viewport and any screenshots with synthetic content; do not claim this audit from component tests alone. If no usable browser is available, finish independent checks and mark this coverage unrun without blocking the rest of the task.

If Docker/local Supabase is unavailable, complete build, anonymous-route, parser/configuration, and other independent checks. Explicitly mark authenticated integration coverage blocked; do not substitute mocked success and call it complete.

## 7. Privacy, authentication, and cache verification

Verify these boundaries under the candidate runtime:

- Signed-out and ordinary users cannot read `/admin`, case HTML, RSC payloads, or execute its actions. Preserve actual HTTP 404 behavior, including before streaming.
- Moderator/admin role changes and suspension take effect through backend reauthorization; a stale page cannot confer authority.
- Admin-only suspension and self-suspension denial remain enforced.
- User-facing reasons and staff notes remain separate, and private evidence stays staff-only.
- Auth refresh/sign-out works across navigations; current identity is bound per request. No module-global client/session holds another user's state.
- Two independent browser sessions cannot receive each other's case, notes, role, user data, or refreshed cookies through CDN, adapter caches, HTML/RSC responses, or revalidation.
- Account/staff responses and token-bearing invite routes preserve appropriate private/no-store behavior. Never put them into public ISR/CDN cache to fit CPU limits.
- Server-action origin/host validation and cookie attributes work for the proposed separate hostname without wildcard trust, broad cookie-domain scope, or disabling CSRF/origin checks.
- Logs, source maps, build artifacts, and monitoring do not expose credentials, cookies, OTPs, staff notes, or report text. Keep required publishable values distinct from server secrets.

Implement narrowly necessary hosting compatibility fixes and tests. A failure must be visible and actionable. Do not disable authorization or error handling to make an adapter succeed.

## 8. Hosting limits and cost assessment

Research current limits at execution and cite dated official sources in a committed report. At preparation, Workers Free allowed 100,000 dynamic requests per account/day and 10 ms CPU per invocation; Paid had a $5/month account minimum with included usage and overages. This is a checkpoint, not a locked pricing contract.

Audit all constraints relevant to the selected path: CPU, request volume, memory, startup, bundle size, outbound subrequests/connections, static assets, build quota, logs, and any required extra bindings. State which limits are account-wide. Include existing public-site waitlist Worker usage in shared-account assumptions; a separate Worker name does not necessarily provide a separate quota.

Distinguish CPU execution from network waiting and total response latency. Measure emitted bundle size with the current documented limit units. Do not carry forward stale compressed-size rules.

Prepare a route/workload evidence table covering at least cold/warm admin queue/detail, auth/session refresh, and apply/revoke submissions. Include CPU evidence where measurable, wall time, output/bundle/startup measurements, outbound calls and test fixture size. Use realistic multi-report case data and bounded pagination, not only an empty queue.

Provide transparent, editable assumptions for a small pilot and a larger pilot: moderators, sessions, navigations, mutations, refresh/subrequests and public discovery traffic. Label these scenarios as estimates. Count dynamic HTTP/RSC/prefetch/proxy invocations rather than equating one page click with one Worker request.

For Paid, show the account minimum plus request/CPU and any extra-service overages under the cited pricing. Distinguish incremental cost when an account is already paid from a new subscription. Separate Workers cost from backend, email, domain and unrelated services.

The existing public-site traffic and account billing state are unknown unless independently verified. State that uncertainty rather than assume the account has unused quota or already pays.

**Evidence standard:** local workerd measurements, profiles and dry runs are local evidence. They cannot certify production CPU distribution, cold-start behavior or account quotas. Without representative already-available Cloudflare execution metrics, the strongest free-tier outcome is “locally compatible; live free-tier limits unverified.” A live test would require a separately authorized deployment; do not perform it here.

Use a clear result: compatible with limits still unverified; incompatible with a specific limit; or viable with a stated hosting/cost change. Do not claim “free production-ready” from a build alone. Do not treat a budget alert as a guaranteed hard spending cap; document current provider behavior and available controls.

## 9. Configuration and operational handoff

For a viable additive path, provide:

- Isolated web runtime/adapter/Wrangler configuration, justified compatibility date/flags, local preview, build and deployment dry-run commands.
- Reuse compatible existing tooling where practical without coupling web settings to `apps/site`.
- A table of environment variable names, build-time versus runtime use, public versus secret values, and where to configure them later. Preserve static `NEXT_PUBLIC_*` access semantics and explain rebuilding when baked values change.
- A short future setup checklist: account plan, Worker identity, separate hostname, allowed origins/auth settings if required, backend endpoint, build settings, secrets, metrics and rollback.
- A future validation sequence for representative hosted CPU/error measurements before a production decision.

Use placeholders rather than real account IDs/secrets. Normal build/CI must not deploy, upload secrets, create cloud resources or require Cloudflare login. Document any future deploy command without running it.

Do not change domain records, custom domains, existing Worker routes, certificates, Supabase production settings or allowlists, D1 schema/resources, Turnstile configuration, or billing. Do not publish a temporary remote preview in this task.

## 10. Validation and CI

Run the smallest complete checks for changed areas, including:

```text
npm run check:web
npm run check:site
npm run format:check:web
npm run format:check:site
git diff --check
```

Use current equivalents if scripts evolve. Add/run the candidate runtime build, local preview integration and deployment dry run. Preserve the independent public-site build, tests and dry-run gate, especially if root dependencies/lockfiles change.

Extend Web CI only as required to exercise the committed adapter/configuration without credentials or deployment. Inspect path classification and required checks; do not leave statuses permanently pending or add unrelated expensive validation. If CI/classification changes, run its tooling tests and required manual full validation under repository policy.

Run database/auth integration checks needed by the real runtime smoke tests. Do not add SQL migrations for a hosting assessment. Run Mobile or broader checks when a shared change can affect them, not solely because this is a new PR.

Check final-head hosted CI, investigate repository-owned failures, and distinguish passed, failed, blocked, and unrun checks. Never claim a dry run deployed a Worker or established live plan compatibility.

## 11. Deliverables and review

Commit a concise report, suggested path:

`docs/development/webhost01-cloudflare-admin-compatibility.md`

It must include the exact base/final SHA, runtime versions, compatibility matrix, tests, measurements and their provenance, limit/cost scenarios, unchanged site boundary, selected option or blocker, and remaining owner actions. Link evidence rather than dumping private fixtures.

Update the nearest web/hosting documentation and architecture decision if this establishes a supported optional hosting path. Preserve factual distinctions between assessed, configured locally, deployed, and operationally verified. No domain selection, free-tier guarantee, paid commitment or framework replacement is implicit.

Archive this exact prompt as:

`history-implementations/PLANETS_WEBHOST01_Cloudflare_admin_compatibility_and_limits.md`

Leave a draft PR with a concrete review request: hosting recommendation, beta/runtime-change decision if applicable, recurring-cost assumptions, and any unverified live limits. This task explicitly overrides automatic merge for that review.

Completion report:

1. Branch, exact dependency base, final SHA and draft PR.
2. Runtime compatibility result and evidence.
3. Configuration/fixes, if any, and preserved behavior.
4. Authentication, staff privacy, suspension and cache results.
5. Free-tier verdict, its evidence limits and identified bottlenecks.
6. Pilot cost assumptions and minimum-cost viable alternative.
7. Local/hosted checks and blocked or unrun validation.
8. Exact remaining steps before deployment.
9. Confirmation that no deployment, resource/billing/DNS change, merge, or 09C2B work occurred.

If Cloudflare is unsuitable without a consequential change, the task can conclude with a well-supported draft assessment PR rather than forcing a deployment configuration. Complete all authorized independent work before surfacing the concrete decision.
