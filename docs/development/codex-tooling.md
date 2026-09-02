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

PLANETS' Riverpod, restrained feature-first, routing, database, and security decisions override generic examples from either tool.

## Deferred tooling

- Install Vercel Engineering's narrow `react-best-practices` skill when 02B starts React/Next.js implementation.
- Use the version-matched Next.js documentation already exposed from the installed Next.js package; do not install an old standalone Next.js guidance pack.
- Install the official shadcn skill only after shadcn/ui is actually initialized.
- Defer Vercel bootstrap, deployment, and CLI plugins until provider provisioning or deployment is in scope.
- Do not install broad clean-code, architecture, superpowers, or framework bundles that duplicate repository guidance.

## Lifecycle and repository hygiene

Keep narrow core-technology guidance installed across PLANETS tasks. Disable or uninstall one-time migration, provider-bootstrap, deployment, or upgrade tooling after its task unless it has an ongoing maintenance role. Do not commit external skill directories or copy their generic instructions into PLANETS documentation.
