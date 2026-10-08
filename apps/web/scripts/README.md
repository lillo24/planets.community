# Web hosting assessment checks

MODINT01 reuses these checks with the explicit seed flag
`--disposable-modint01` and the same flag appended to the authenticated verifier.
This selects only `planets-community-modint01-qa` on API/DB/Mailpit
54611/54612/54614. Omitting the flag retains the original WEBHOST01 scope; neither
scope accepts shared/remote endpoints or arbitrary project names. Synthetic OTP
emails use the matching `modint01-` prefix. The MODINT seed additionally prepares
a photo-free browser applicant and stores the participant bearer token only in
ignored `supabase/.temp/modint01-browser-fixture.json`. Never publish that file,
invitation URLs, Auth tokens, cookies or private response bodies. This is local
combined-source QA, not a hosting selection or production deployment.

After the clean combined Database gate and matching Web build, seed with
`node apps/web/scripts/seed-local-hosting-qa.mjs --disposable-modint01`, then set
`MODINT01_LOCAL_REHEARSAL=1` and run
`node apps/web/test-support/modint01-browser-fixture.ts` from the repository root.
The guarded launcher binds only loopback 3118 and starts production Next on 3119.
Open its root page for normal browser sign-in/case/participant actions without
printing the ignored bearer journal. It injects no session and performs no
admission; Ctrl+C stops only its child server. Neither the normal handoff nor
this rehearsal invents missing app-store URLs. Use a fresh `.invalid` email for
first-time browser profile completion; the seed's applicant has a basic profile
and deliberately no photo metadata.

`probe-local-hosting.mjs` owns a loopback-only, anonymous HTTP probe for an already
running production Next.js or disposable OpenNext/workerd build. It measures
three full-response wall times per route and asserts HTML denial, Flight
not-found payloads, invite privacy headers, genuine anonymous consequence-action
denial and mismatched-origin rejection. It logs no response bodies, cookies,
action identifiers or manifest secrets. A nonmatching response exits nonzero.

`probe-local-hosting.test.ts` tests the loopback guard and response assertions;
the normal Web Vitest suite includes it. No runtime/configuration is adopted by
these checks, and they never start a server or deploy.

`hosting-private-fixture.mjs` owns exact synthetic note/witness/counterstatement
markers shared by the seed and authenticated verifier. Its regression tests
reject denial-shaped responses containing any actual marker. The verifier first
requires every selected marker in authorized HTML **and** Flight, then requires
their absence for anonymous/ordinary/stale-role requests. Status, content type,
private/no-store and not-found semantics are asserted together (HTML 404 versus
Flight 200 with the Next 404 digest). No private response bodies are printed.

`local-hosting-backend.mjs` guards the exact disposable project/API/database
before its seed or authenticated verifier can write. Its tests cover shared,
remote and missing endpoints. The Supabase CLI must be on PATH (npm scripts
already add the root `node_modules/.bin` directory).

`verify-local-hosting-auth.mjs` uses real synthetic OTP sessions in independent
in-memory cookie jars. It forces genuine refresh-token use by expiring only the
client session envelope, pads synthetic Auth metadata to exercise multiple
cookie chunks, interleaves staff HTML/Flight/profile reads, submits real encoded
denied actions, temporarily suspends/restores the fixture moderator through
canonical admin RPCs, and checks independent local sign-out. It requires the
same guarded backend plus the case IDs printed by the seed. Tokens, cookies,
raw errors and private response bodies are never logged. Failure exits nonzero
with a redacted stage. It adds a synthetic report/case and retains its revoked
suspension history; it is not a production benchmark or CDN isolation test.
Padding is 2,000 synthetic characters and a fresh JWT is issued after updating
it: metadata is present in both JWT and user data, so the former 4,500-character
fixture could exceed Node's default 16 KiB request-header limit on repeated runs.
Multiple cookie chunks and a later genuine Proxy refresh are still required;
the server header limit is not increased. Boundary metadata is printed before
assertions to distinguish an explicit HTTP failure from a privacy-contract error.
It also temporarily deactivates/restores only the synthetic moderator's staff
role via guarded local SQL, checking existing-session reads and an encoded
safety-notice submit; no submitted private note may persist. This is a fixture
authority change, not a new staff-management feature or database contract.

`seed-local-hosting-qa.mjs` creates a synthetic 35-report/35-case fixture with
eight long private notes, reviewed/received states, witness evidence and a
counterparty statement. It requires the exact disposable WEBHOST-01 project and
ports described in the assessment, plus the explicit `--disposable-webhost01`
flag. It uses Mailpit OTP sessions and canonical domain RPCs; the existing
repository fixture helper/direct SQL is used only for local staff-role,
content and accepted-relationship bootstrap. It never seeds the shared local
project, creates production roles, or prints sessions. Re-running adds fixtures;
reset only the named disposable stack before clean database tests. Current
domain behavior creates one case per report, not aggregated multi-report cases.
The Resource listing has a real synthetic `cover-images` upload attached through
the owner's canonical RPC. The printed `coverPath` permits actual Storage
denial/restoration QA; neither profile-photo bootstrap metadata nor a signed URL
is proof that an object exists or remains accessible.

From the repository root, after building and starting the matching artifact:

```text
node apps/web/scripts/probe-local-hosting.mjs http://127.0.0.1:3117
# Only after setting up the named disposable stack:
node apps/web/scripts/seed-local-hosting-qa.mjs --disposable-webhost01
node apps/web/scripts/verify-local-hosting-auth.mjs http://127.0.0.1:3117 PROFILE_CASE ADMIN_SELF_CASE CORROBORATION_CASE COUNTERSTATEMENT_CASE
```

The action encoder comes from the installed, pinned Next.js internal test
transport, and the action ID is read from that build's private server manifest.
Recheck this probe on framework changes. Never publish that manifest (it includes
an encryption key). Timings include network waits and are not CPU
usage. Redirects are not followed. A pass does not prove valid Supabase reads, OTP/refresh, authenticated
forms, session isolation, enabled Sentry, cloud startup or Free-tier suitability.
See the [WEBHOST-01 assessment](../../../docs/development/webhost01-cloudflare-admin-compatibility.md).
