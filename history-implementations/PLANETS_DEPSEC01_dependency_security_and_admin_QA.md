# PLANETS — DEPSEC-01: dependency security and remaining admin QA

## Goal and authorization

Close the actionable dependency-security findings recorded by WEBHOST-01, strengthen its privacy verifier, and finish the explicitly missing 09C2A admin browser checks. This is a bounded maintenance follow-up before further moderation UX work. It does not select or provision a hosting provider.

Implement the supported, narrowly scoped fixes and validate them. Leave a draft PR for review of residual security exposure and real browser results. Do not merge this PR or any predecessor. Complete independent work before surfacing a consequential decision; an unpatched advisory must not prevent fixing unrelated actionable findings.

## 1. Exact dependency base and repository inspection

Repository: `lillo24/planets.community`.

This task explicitly selects the unmerged WEBHOST-01 branch as its dependency base:

- PR: <https://github.com/lillo24/planets.community/pull/130>
- Branch: `codex/webhost01-cloudflare-admin-compatibility`
- Exact head: `99e95f90d0105cc3049fa9b76965f328104d8e4b`
- Its 09C2A base: `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7`, PR #126.
- Earlier required ancestry: 09C1B PR #125 at `c0548a25d39ddc77a92bc02514c83a01f731e9ae`, then 09C1A PR #123 at `010471320779ffb5edaa7546b12cdc8f14809d2d`.

Verify remote heads and ancestry before editing. Create an isolated task branch, suggested `codex/depsec01-dependencies-admin-qa`, from the exact selected head. Target the draft PR to the WEBHOST-01 branch so its diff contains only this follow-up. This explicitly overrides the repository's normal PR-to-main and automatic-merge defaults. Do not silently bring unrelated latest-main features into this stack. If the selected head moved or was merged, inspect the change and use an equivalent verified base; explain any material divergence before dependent edits.

Read the root and relevant nested `AGENTS.md`, current manifests/lockfiles, `.nvmrc`, `.github/workflows/validation.yml`, validation classifier, architecture and tooling policy. For Next.js edits, use the documentation bundled with the installed version as required by `apps/web/AGENTS.md`.

Read these existing evidence sources:

- `docs/development/webhost01-cloudflare-admin-compatibility.md`
- `docs/development/webhost01-local-evidence.json`
- `apps/web/scripts/README.md` and the guarded fixture/probe/verifier scripts.
- PR #130's [late cleanup/advisor update](https://github.com/lillo24/planets.community/pull/130#issuecomment-5981311142), which supersedes only the earlier environment limitation.
- `docs/implementation/roadmap.md`, especially 09C2A/09C2B and deferred production infrastructure.

Current code and tests are the source of implemented behavior. No external Google Doc is required for this maintenance scope.

## 2. Starting evidence and boundaries

WEBHOST-01's final hosted run passed Web, Site and Database on the exact selected head; Mobile was skipped. Its runtime/non-documentation tree matches validated implementation `47fc70cdc6b574fc37b190617d83eb67e3a420a1`. Those results establish the starting snapshot, not validation of this new change.

The assessment reported 16 vulnerable npm package entries: 11 high, five moderate, zero critical. Parent entries are not necessarily independent vulnerabilities. Reproduce current results instead of treating these counts or patch versions as permanent facts.

Next.js and `eslint-config-next` are already patched to 16.3.8. No Cloudflare adapter or deployment configuration was adopted. The tested Worker still has Sentry module-startup Wasm errors and experimental Node-runtime Proxy support; this task does not resolve or reclassify those blockers. Conventional Next.js/Node remains a recommendation, not an approved provider or a production readiness claim.

Do not implement 09C2B, appeals, moderation policy changes, new notifications, new hosting infrastructure, or a runtime/framework replacement. Preserve canonical authorization, roles, suspension enforcement, case scope, staff privacy and user reason/private-note separation. No database migration or domain/RPC change is expected.

## 3. Reproduce and triage dependency findings

Use the repository's supported Node 24/npm 11 environment and a clean lockfile-based install. Record actual Node/npm and embedded Undici versions. Run read-only audit first, including the full graph and production graph, and use `npm explain` or equivalent to map findings to resolved owners.

Verify current primary advisories and maintained releases at execution. Start with the recorded families:

| Family | Recorded consumers / question |
| --- | --- |
| brace-expansion | minimatch/glob, lint/build tooling, Sentry exports and shadcn; review each resolved major separately |
| braces | micromatch/fast-glob; report previously found no patched release, which must be rechecked |
| fast-uri | AJV/schema-utils/Webpack/Sentry and shadcn configuration/MCP paths |
| Undici | Site Miniflare, jsdom, shadcn tooling, plus Node's independently embedded copy |
| Hono and ip-address | shadcn MCP/server and socks paths; confirm actual usage and versions |

For each distinct advisory, report dependency path, affected version, patched range if available, deployment/build/tooling reachability, attacker-controlled input if identified, chosen fix, and remaining exposure. Audit labels such as `dev` are insufficient evidence of absence from the emitted application. Inspect actual imports and emitted artifacts where that distinction matters. Do not infer exploitability merely from severity, or claim safety merely because a direct API call was not found.

Keep raw audit data local where it contains unnecessary machine details; commit a concise reproducible findings table with dated primary links. Record before/after counts and explain residual findings.

## 4. Implement supported narrow fixes

Prefer supported patch/minor updates to existing owning dependencies that resolve the affected transitive paths. Respect existing pins and package-manager conventions, and regenerate the root lockfile deliberately. Inspect the lockfile diff for unrelated churn.

- Do not run blind `npm audit fix --force`, replace whole toolchains, suppress audit findings, or weaken checks.
- Use a transitive override only when upstream ranges cannot otherwise resolve the issue, compatibility is justified, the affected paths are understood, and focused validation proves the installed result. Do not force a newer incompatible major into an older parent.
- If shadcn is used only as a development CLI, verify repository-wide imports, scripts/configs, docs, build behavior and production packaging before moving it to `devDependencies`. Moving it alone is not remediation of tooling vulnerabilities; do not remove required tooling without a working supported replacement.
- Retain the current Next 16, React 19 and Sentry 10 major lines. A supported narrow security patch within an existing major is allowed when justified and tested. Sentry 11, vinext, OpenNext adoption and other consequential migrations require a separate reviewed task.
- Review Node 24's maintained security release independently of npm's Undici package. If a supported Node 24 patch is needed and available, validate it and align `.nvmrc`, CI pins and applicable setup docs. Remain within the repository's Node 24/npm 11 engine contract. Do not install a new global runtime silently or claim npm updates fixed Node's bundled implementation.
- For a genuine no-fix path, reduce exposure only through a justified compatible change. Otherwise document the exact remaining path, evidence, bounded mitigations and review requirement. Do not invent a workaround to produce a zero audit count.

Preserve enabled and disabled Sentry behavior on conventional Node. Do not stub, remove or disable monitoring to pass a build or claim the Cloudflare problem is solved.

## 5. Fix the private-data probe's false-pass risk

`verify-local-hosting-auth.mjs` currently checks denied HTML/Flight bodies for `Synthetic PRIVATE`, while the relevant seeded notes use `Synthetic private note`. The uppercase string occurs in other probe-created history, but does not cover the seeded note used by the case read. This is an assertion weakness, not evidence that the application actually leaked data.

Make the verifier check known sensitive markers actually present in the seeded case. Share marker definitions with the fixture, or use an equally reliable explicit contract. First prove the authorized read contains each selected marker, then prove denied HTML and Flight responses omit it. Include representative notes and private evidence where the fixture permits it. Do not print response bodies or secret/private payloads.

Check expected HTTP status, content type, cache policy and not-found semantics together. Preserve the measured Next distinction: denied HTML is 404, while the applicable Flight response may be HTTP 200 with `NEXT_HTTP_ERROR_FALLBACK;404`. A digest alone must not hide a private payload in the same response.

Add focused regression tests showing a denial-shaped response containing an actual private fixture marker fails. Preserve loopback/backend guards, redacted failures, nonzero exits, independent cookie jars, origin rejection and the real encoded action transport. No remote target or production credentials are authorized.

## 6. Complete the outstanding admin browser QA

Run a production Next.js build/server locally against a separately identified disposable Supabase backend with synthetic users and real OTP sessions. Reuse and preserve the existing explicit WEBHOST-01 project/endpoint guards if using its fixture scripts. Record exact tested artifact SHA, runtime and backend identity. Never reset or stop an unrelated/shared stack; restore temporary configuration and stop only task-owned services with data backup preserved.

Complete the two gaps called out by WEBHOST-01:

1. Resource-listing content-hide apply/revoke through real browser forms: exercise compatible case/type controls, distinct user reason and private note, authoritative mutation, case history and the actual canonical listing/cover visibility surface. Verify revoke restores only the visibility allowed by existing lifecycle/privacy rules. A direct SQL write or mocked result cannot substitute for the form action.
2. Keyboard and accessibility interaction through the implemented admin queue, pagination, case navigation, consequence forms, validation errors, confirmation/cancel, apply/revoke and history. Check visible focus, reachable labels/actions, sensible focus after errors/updates, role-restricted controls and both desktop and narrow layouts. Report findings against implemented behavior; do not perform a broad visual redesign.

Use genuinely independent browser contexts for session checks when supported. If the available browser cannot provide them, retain the independent HTTP cookie-jar checks and explicitly mark browser-profile coverage unrun. Different cookie hostnames are not proof of independent browser profiles or live CDN isolation.

After dependency changes, rerun the relevant real OTP, refresh/chunked cookies, authorized/denied admin HTML/Flight, forged actions, stale-role/suspension reauthorization, self-suspension denial and sign-out checks on conventional Node. Preserve private/no-store and origin validation. Use existing passing checks; repeat only the coverage that validates changed dependencies or new assertions.

Fix concrete, narrowly scoped QA defects found in this work with meaningful tests. If a result requires new moderation policy or a major UX decision, isolate it, finish independent work and present the concrete options in the draft report. Do not call source review or unit tests real browser QA. If Docker or browser tools are unavailable, report that limitation precisely and finish all independent remediation and checks; never substitute fabricated passing evidence.

## 7. Validation and reviewable deliverables

Run the smallest complete validation for every changed area, including Web/tooling and the independent Site build/tests/dry run when the root lockfile changes:

```text
npm run check:web
npm run check:site
npm run format:check:web
npm run format:check:site
git diff --check
```

Also run the real local integration/browser checks above, before/after audit and clean-install verification. A dry run must not deploy or upload resources. Follow current path classification: root dependency changes affect Database checks as well. Verify exact final-head hosted CI jobs and skips rather than assuming a successful overall badge covered every area.

If CI/workflow files change, run the classifier/tooling tests and the repository's required manual full-validation checkpoint, including Mobile where required. Keep required statuses working and preserve scoped CI; do not add unrelated recurring hosted cost. If an environment blocks a required gate, identify it separately from failing or passing checks.

Commit a concise report at `docs/development/depsec01-dependency-security-and-admin-qa.md` with exact base/tested/final SHA, dependency changes and rationale, before/after findings, residual exposure, local and hosted results, browser evidence and remaining review items. Update nearby docs for actual changed behavior. Preserve WEBHOST-01 as a dated assessment; annotate superseded dependency/QA findings by linking the follow-up, without rewriting its original measurements as newly tested Worker evidence.

Archive this exact prompt at `history-implementations/PLANETS_DEPSEC01_dependency_security_and_admin_QA.md`. Leave a clean, pushed draft PR stacked on the selected WEBHOST-01 branch. This task explicitly requires review of residual vulnerabilities, the actual admin QA and the unmerged stack, and therefore prohibits automatic merge.

Return a short completion report with PR/branch/base/head, actionable fixes, residual findings with reasons, true browser results, final CI and any blocked/unrun checks. State the next remaining functional plan (09C2B) and its required user-copy/contextual-warning decisions without implementing it.

No deployment, remote preview, provider/account login, resource or billing commitment, DNS change, production secret upload, production/shared database operation, merge, or 09C2B work is authorized. Hosting selection remains a separate owner decision; this task can finish without choosing a provider or certifying a free tier.
