# 0001 — Root npm workspace and task entry point

- **Status:** Accepted
- **Date:** 2026-09-01

## Context

PLANETS contains a Next.js application, a Flutter application, and a project-scoped Supabase CLI. Contributors need one reproducible Node dependency graph and memorable commands that work on Windows, macOS, Linux, and CI without adding a monorepo framework or a globally installed backend CLI.

## Decision

Use a private npm workspace at the repository root. `apps/web` is the initial Node workspace, the root owns the single `package-lock.json`, and the Supabase CLI is an exact root development dependency. Root npm scripts delegate to the standard Next.js, Flutter/Dart, and Supabase commands.

Flutter continues to own its dependencies independently through `apps/mobile/pubspec.yaml` and `pubspec.lock`. No general monorepo build framework or additional package manager is introduced.

## Alternatives considered

- A separate Node lockfile inside `apps/web` would fragment dependency restoration and leave the project-scoped Supabase CLI without a clear owner.
- A global Supabase CLI would make local and CI versions drift.
- Turborepo, Nx, pnpm, Yarn, Bun, Make, and similar orchestration layers add another prerequisite without solving a demonstrated bootstrap problem.

## Consequences

Node dependency installation runs once from the repository root, and CI can use `npm ci` against one lockfile. Common commands remain discoverable through `npm run`. Flutter retains its normal toolchain and lockfile, so cross-ecosystem orchestration stays intentionally thin.
