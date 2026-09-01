# Suggested Sections for Codex Implementation Plans

This is a menu, not a mandatory template. Use only the sections that improve a specific task. Small tasks should remain small; architecture, security, and cross-layer work needs more context.

The implementation prompt is a practical handoff artifact. It should give Codex enough context to avoid wrong assumptions while leaving implementation details open where repository inspection provides better evidence.

## 1. Task title and identifier

Use the roadmap identifier when relevant, for example:

```text
PLANETS 00 — Architecture and Repository Bootstrap
```

State whether the task is a complete roadmap plan, a follow-up, or a narrow corrective task.

## 2. Objective

Describe the end state, not only a list of files to edit.

Useful questions:

- What problem should be solved?
- What should a developer or user be able to do afterward?
- What does success look like?

## 3. Current repository evidence

Summarize what was verified in the repository immediately before writing the prompt:

- current branch/default branch;
- relevant applications, packages, migrations, and documents;
- existing implementation and tests;
- missing expected areas;
- recent pull requests or reports that affect the task.

Do not describe an assumed folder structure as current fact. Use flexible wording such as “likely areas to inspect” when exact paths are not established.

## 4. Status classification

Distinguish clearly between:

- **implemented behavior:** supported by repository evidence;
- **accepted/intended design:** approved but not yet implemented;
- **tentative proposal:** unresolved or future-facing idea.

This prevents Codex from treating product notes as existing code or silently deciding between competing ideas.

## 5. Product and architecture context

Include only context needed for this task. Link to repository documents rather than copying them wholesale.

State any architecture guardrails the task must preserve. When a material architecture change is allowed, say so explicitly and require an ADR/document update.

## 6. External context and access

List every required resource outside the repository, such as:

- Google Docs;
- screenshots or design exports;
- logs/data files;
- provider dashboards;
- credentials or certificates;
- existing deployed environments.

For each resource, state whether Codex can access it.

When required context is inaccessible, instruct Codex to stop and report the missing item instead of guessing. When external context is optional, make that clear so it does not block useful work.

## 7. Decisions already made

Record settled choices that Codex should not reopen during ordinary implementation.

Examples:

- selected framework or provider;
- source-of-truth boundary;
- accepted lifecycle behavior;
- security/privacy rule;
- explicitly deferred feature.

Avoid prescribing low-level implementation details that Codex can judge better after inspecting the repository.

## 8. Scope

Describe required work by behavior and layer.

Possible groupings:

- repository/tooling;
- database/schema/RLS;
- server functions/background work;
- Flutter data/domain/presentation;
- Next.js public/admin behavior;
- monitoring/analytics;
- CI/deployment;
- documentation.

Prefer explicit outcomes over “implement everything needed.”

## 9. Non-goals

Name tempting adjacent work that must not be included.

This is important when the task touches a broad domain such as authentication, chat, maps, moderation, analytics, or deployment.

## 10. Functional requirements

Describe observable behavior and relevant state transitions.

Include:

- actors and permissions;
- normal flow;
- validation;
- loading/empty/error behavior where relevant;
- retries and idempotency;
- relevant notifications/deep links;
- effects on existing records.

Use examples or a small scenario when they clarify ambiguous behavior.

## 11. Data and security requirements

Use this section whenever the task changes stored or exposed data.

Consider:

- schema and migration needs;
- constraints and indexes;
- RLS actor matrix;
- public versus private fields/views;
- exact versus approximate location;
- service-role boundaries;
- deletion/retention effects;
- audit events;
- abuse/rate-limit considerations;
- safe logs and analytics.

Require security-sensitive defaults to fail closed.

## 12. Implementation guidance

Provide constraints and likely areas to inspect without forcing unsupported code structure.

Good guidance:

- preserve the established feature-first Flutter structure;
- implement a multi-step mutation as one canonical backend operation;
- reuse the existing error/result convention;
- add a migration rather than editing released history;
- prefer the existing component library.

Overly rigid guidance:

- inventing exact class/file names before inspection;
- specifying every helper method;
- requiring an abstraction only because it appeared in a generic pattern;
- copying a previous project's architecture into this repository.

## 13. Edge cases and failure behavior

Include edge cases with product or data consequences, such as:

- duplicate/retried requests;
- concurrent acceptance;
- deleted or suspended users;
- stale sessions;
- lost connectivity during a command;
- inaccessible storage objects;
- queue/provider failure;
- membership changes during chat access;
- partially configured environments.

Do not enumerate trivial cases that ordinary validation conventions already cover.

## 14. Testing and validation

Specify the evidence required, not only “add tests.”

Depending on the task:

- migration replay from an empty local database;
- pgTAP constraints/functions/RLS tests;
- Flutter unit/widget/integration tests;
- TypeScript/unit/component tests;
- Next.js production build;
- Playwright user journeys;
- mocked provider tests;
- manual smoke steps that cannot be automated yet.

Require exact commands and results in the completion report. Codex must not claim checks passed when they were not run.

## 15. Acceptance criteria

Write a compact checklist of externally verifiable outcomes.

Acceptance criteria should cover:

- required behavior;
- authorization/data exposure;
- tests/builds;
- documentation;
- absence of scoped non-goals or regressions.

Avoid criteria tied only to internal file names unless those files are themselves the deliverable.

## 16. Documentation and decision records

State which repository documents should change when the implementation establishes or changes:

- architecture;
- commands/setup;
- data model/lifecycle;
- external configuration;
- operational procedures;
- roadmap status.

Require an ADR only for decisions that need lasting rationale, not every library installation.

## 17. Manual or external setup

Separate code completion from account-owner work.

Codex should:

- add `.env.example` placeholders;
- document exact provider/dashboard steps;
- name required permissions and callback URLs;
- identify where secrets belong;
- implement mocks or disabled behavior where practical.

Codex should not:

- fabricate credentials;
- commit secrets;
- claim provider setup was completed without verification;
- block unrelated local work merely because production credentials are absent.

## 18. Autonomy and stop conditions

Tell Codex what it may decide and what must be escalated.

Stop conditions should focus on ambiguity that affects:

- security/privacy;
- irreversible data structure;
- central product behavior;
- legal/moderation/retention policy;
- production infrastructure and recurring cost;
- required inaccessible external context.

Minor implementation choices should be made consistently and reported rather than escalated.

## 19. Deliverables

Possible deliverables include:

- code and migrations;
- tests and fixtures;
- updated documentation;
- a focused pull request;
- generated artifacts/types;
- setup/runbook instructions;
- a completion report.

When the task should not deploy production or merge itself, say so explicitly.

## 20. Completion report format

Ask Codex to return:

1. summary;
2. changed areas/files;
3. decisions and assumptions;
4. migrations and security implications;
5. commands/tests run and results;
6. manual/external setup remaining;
7. limitations/deferred work;
8. warnings or decisions that should block the next plan;
9. pull-request link or commit reference.

## Minimal prompt shape

For a small, low-risk follow-up, this may be enough:

```markdown
# Objective

# Repository evidence

# Required changes

# Non-goals

# Acceptance criteria

# Tests

# Completion report
```

## Complex prompt shape

For a cross-layer roadmap plan, use a fuller structure:

```markdown
# Task
# Objective
# Current repository evidence
# Implemented vs intended vs tentative
# Relevant product/architecture context
# External context and access
# Decisions already made
# Scope
# Non-goals
# Functional requirements
# Data/security requirements
# Implementation guidance
# Edge cases
# Testing/validation
# Acceptance criteria
# Documentation updates
# Manual/external setup
# Autonomy and stop conditions
# Deliverables
# Completion report
```

The prompt should remain focused on the current plan. Link to stable repository documentation instead of reproducing the entire project architecture in every handoff.