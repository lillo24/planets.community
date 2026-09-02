# Codex tooling policy

Codex plugins and skills supplement PLANETS implementation work; they do not decide product or repository architecture.

## Authority order

When guidance conflicts, use this order:

1. current repository code, migrations, configuration, and tests;
2. repository `AGENTS.md` files and accepted architecture/ADR documentation;
3. the active implementation plan;
4. external plugin or skill examples.

## Persistent core tooling

The official Dart/Flutter plugin is the approved persistent mobile-development plugin. Inspect first with `codex plugin list`; if it is missing, install it with:

```text
codex plugin marketplace add flutter/agent-plugins
codex plugin add dart-flutter@dart-flutter
```

The narrow official Supabase/Postgres best-practices skill is persistent support for later schema, RLS, and query work. Inspect global skills first; if it is missing, install only that skill with:

```text
npx skills add supabase/agent-skills --skill supabase-postgres-best-practices -g -a codex -y
```

The official broad Supabase skill is also persistent because Auth, client SDK, CLI, Storage, Realtime, and Edge Function work recurs across the roadmap. It was added for plan 03A with:

```text
npx skills add supabase/agent-skills --skill supabase -g -a codex -y
```

Use the broad skill for Supabase product/client work. Load the narrower Postgres skill before any schema, migration, grant, RLS, function, or SQL-test edit. Plan 03A required no database migration or permission change, so its work used the broad skill only.

PLANETS' Riverpod, restrained feature-first, routing, database, and security decisions override generic examples from either tool.

## Deferred tooling

- Use the version-matched Next.js documentation already exposed from the installed Next.js package; do not install an old standalone Next.js guidance pack.
- Defer Vercel bootstrap, deployment, and CLI plugins until provider provisioning or deployment is in scope.
- Do not install broad clean-code, architecture, superpowers, or framework bundles that duplicate repository guidance.

## Web foundation tooling

Plan 02B initialized shadcn/ui before installing shadcn's official narrow skill, and installed Vercel Engineering's current narrow React guidance under its renamed `vercel-react-best-practices` identifier:

```text
npx skills add vercel-labs/agent-skills --skill vercel-react-best-practices -g -a codex -y
npx skills add shadcn/ui --skill shadcn -g -a codex -y
```

These skills guide implementation but remain subordinate to the installed Next.js documentation and repository rules. No broad Vercel/deployment plugin or standalone Next.js skill is installed. Use `npx shadcn@latest info`, `docs`, `--dry-run`, and `--diff` before adding or updating shadcn source.

## Lifecycle and repository hygiene

Keep narrow core-technology guidance installed across PLANETS tasks. Disable or uninstall one-time migration, provider-bootstrap, deployment, or upgrade tooling after its task unless it has an ongoing maintenance role. Do not commit external skill directories or copy their generic instructions into PLANETS documentation.
