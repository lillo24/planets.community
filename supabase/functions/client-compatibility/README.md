# Public compatibility metadata

`handler.mjs` validates bounded Android/iOS requests and operational policy.
`index.ts` supplies `PLANETS_CLIENT_COMPATIBILITY_POLICY` from environment;
`.env.example` contains explicit inactive floors. No Auth, service key, product
data, database write or provider call is involved. Pre-login public access is
deliberate (`verify_jwt = false`); responses use `no-store`.

Schema 1 has `android` and `ios` entries: exact `application_id`, numeric
three-component `minimum_version`, numeric string `minimum_build` (integer for
Android; up to three components for iOS). iOS also requires `app_store_id`, null
only while its floor is `0.0.0`/`0`. Raising that floor without a verified numeric
listing ID is invalid. URLs are constructed from the configured package or
numeric ID; no arbitrary redirect or guessed store search is accepted.

POST `{"platform":"android","application_id":"community.planets.app"}`.
Success returns exact schema/platform/application/minimum-version/minimum-build/
update-URL fields. Bad request is 400; unknown app 409; streamed input over 1024
bytes 413; missing/invalid policy 503. Failure never becomes an inactive policy.
Pure tests run in `npm run test:tooling`. The function is portable to local and
self-hosted Supabase Edge runtimes; explicitly configure the example before
serving. No hosted deployment/activation is performed. See
[APPVER01](../../../docs/development/appver01-client-compatibility.md).

Local serving (after copying the inactive example to an operator-owned file):

```text
supabase functions serve client-compatibility --env-file <absolute-env-file>
```

For a separately authorized hosted rollout, set the reviewed policy with
`supabase secrets set --env-file <absolute-env-file> --project-ref <verified-ref>`,
then deploy with `supabase functions deploy client-compatibility --no-verify-jwt
--project-ref <verified-ref>`. These are operator instructions, not operations
performed by this implementation. Never raise floors before store verification.
