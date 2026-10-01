# HTTPS app and universal links

`association-responses.ts` owns the fail-closed website association payloads.
The `/.well-known` route handlers expose them only when final production app
identity values are present and valid. Bootstrap package/bundle identifiers are
rejected deliberately.

See `docs/development/project-invite-links.md` for environment variables,
signing prerequisites, deployment checks, and native validation commands.
