# STAGING-AUTO03 verified staging migration policy

The standing authorization covers development staging `cllpvruvrrvxczjitlqd` only.
It replaces per-migration owner fingerprint comments. Code merge and hosted
eligibility remain separate; production, mock schema operations, Edge rollout,
provider settings and Play publication have their own explicit authorization.

## Decisions and independent evidence

- `auto-eligible-for-staging`: exact canonical bytes, predecessor, populated rows,
  catalog effects, independent security contracts and real Auth/Storage checks pass.
- `review-required-for-hosted`: valid source can merge, but an identified
  unsupported effect or missing contract withholds the **whole** hosted chain.
- `blocked-unsafe`: destructive/history edits, malformed or failing replay,
  changed existing rows/columns, removed contracts, weakened RLS or widened
  existing table privileges fail source validation.

The original nullable-column grammar remains. The additional bounded class admits
isolated RLS-protected private tables without direct role grants. Privileged
service functions require an independently installed contract; unknown bodies are
held. MAPMOCK's contract tests the actual shared global ledger, mock subcaps,
concurrent reservations, cache/kill behavior and real authenticated RPC denials.
An unchanged signature is insufficient. Negative controls actually replace its
body with a wrong ledger, widen execution, disable RLS, change definer context
and install a hidden trigger on the disposable database; those changes must fail.

The already merged product baseline `ec4c57060331b96577d512794b8c5bd78ac16d2b`
defines existing catch-up candidates and immutable pgTAP/Auth fixture producers.
Its hash is **not deployment authorization**: actual per-file security effects,
old rows and independent tests must still pass. Any unproven existing contract
change is held with its exact object/version. New contracts must first land in a
separate policy PR.

Validation loads its classifier and SQL rehearsal from the PR's pre-change base.
A policy-only PR exercises its candidate engine after unchanged base tests.
Canonical migrations cannot be added in the same PR as release policy, workflow,
dependency or evidence-fixture changes. All five existing required checks remain.
The policy PR's proposed #300 SQL is a disposable negative-control input pinned
to `b20c20758f6addfa1a15b670b6155e09cac614f6`; it is neither canonical history nor
an approval. When MAPMOCK exists, the controls exercise the installed candidate.

## Protected writer and live predecessor

The protected `observe` job can run a read-only manual `inspect` before activation.
It verifies fixed project identity, the actual database secret using strict CA
and hostname validation on port 5432, stable session and agreement between session
and Management API SQL history. The observed artifact is bound to the same run
and source. It reconstructs the exact non-contiguous predecessor on an isolated
Linux Actions runner. PR checks use the committed metadata-only predecessor when
no protected observation is available.

The rehearsal populates fictional Auth/profile/proposal records and uploads an
actual private Storage object through a real user's session. It compares every
original column/row digest after each file and checks the original photo API and
downloaded bytes. It executes trusted baseline security tests, independent
service RPC denials with two actual Auth sessions, generated public types and a
second CLI invocation proving no-op retry. Two real sessions prove lock exclusion.

The unchanged baseline pgTAP fixtures require clean synthetic data (fixed Auth
emails and singleton/count assumptions). Their phase follows all populated
upgrade and Storage proofs: only the owned loopback stack is reset, its entire
effective catalog must match the actually upgraded catalog, and then every
trusted test runs unchanged. This mode is explicit in the receipt; no hosted
target can enter the rehearsal and no security assertion is skipped. FILL01's
specific private recruitment helper delegation must retain its original OID,
body and permission context under its new private name while the legacy caller
contract and independently trusted recruitment tests remain valid. Public RPC
replacements still retain their original OID and permission context.

After the entire pending chain qualifies, the writer rechecks current main,
source/tree/policy hash, exact predecessor, recovery mode, live RLS/grants/Storage
and an advisory lock. Each CLI invocation contains already applied canonical
files plus exactly **one** qualified pending file. `--include-all` is limited to
that single historical hole. Session and CLI use the same pinned public CA,
`verify-full`, a 5-second lock timeout and 60-second statement timeout. No reset,
seed, role deployment, history repair or broad backlog application is allowed.
Actual catalog effects must match independently observed rehearsal effects; old
rows and authoritative history are checked after **each** file. A final actual
CLI retry must preserve catalog/history/rows.

Sanitized `staging-eligibility.json`, `rehearsal.json`, `connection.json`,
`safety.json` and `deployment.json` receipts contain hashes, counts, identities,
statuses and effect digests, never credentials, function bodies or user data.
The writer reads prior protected run artifacts. An interrupted/partial/unverified
write holds future writes until its real outcome is independently reconciled.
Unrelated read-only runs cannot push that state outside a fixed lookback: history
is paginated with a fail-closed audit bound. Expired ZIPs cannot manufacture
success; only a genuinely successful protected writer job at the matching source
can preserve an independently completed reconciliation without its old artifact.
Only then may protected `STAGING_RECONCILED_FAILURE_RUN_ID` and
`STAGING_RECONCILED_PREDECESSOR_SHA256` identify that exact run/live inventory;
they are incident recovery settings, not recurring SQL approval comments.

## One-time activation and limits

Keep the protected `planets-staging` environment, main-only branch policy,
no admin bypass and existing five-check ruleset. Verify native Supabase GitHub
migration deployment is disabled, then retain
`STAGING_DEPLOYMENT_OWNER=github-actions`. Reuse existing protected
`SUPABASE_ACCESS_TOKEN`, `STAGING_DB_URL`, `STAGING_CONFIG_JSON`.
After successful strict read-only inspection and owner-authorized setup, remove
only the staging deployment reviewer, set protected
`STAGING_AUTOMATION_READY=true` and repository
`STAGING_RELEASE_ENABLED=true`. Main pushes then run the exact-source full
Validation/rehearsal and one serialized writer. A configuration change is not
proof of a successful live run; retain that run's receipts separately.

`STAGING_RECOVERY_MODE=development-no-backup` records the founder's accepted
possible development-data loss honestly as `waived`; it does not waive row,
security, history or concurrency checks. Missing/unknown modes fail closed.
`verified-backup` remains available with independently verified encrypted DB
**and Storage-object** recovery. Switch to it before retaining irreplaceable data.

Pushes use ordinary `staging` verification. Manual Android builds explicitly
select `closed-test-mock` and require its separately deployed mock image route.
Main pushes never build/upload AABs. Keep `STAGING_AUTO_PUBLISH=false` and the
Play reviewer unchanged. This mechanism deploys no Edge functions and makes no
paid provider calls. MAPMOCK's separately authorized hosted smoke retains its
12-quarter-unit maximum and unchanged shared Geoapify ceiling.

## Validation

`npm run test:tooling` includes the release, legacy and new policy suites.
Full manual Validation remains available. The required classification job runs
the isolated populated/security rehearsal for SQL/release/workflow/dependency
changes; ordinary unrelated changes avoid that cost. Policy/workflow edits
select all existing validation areas. The protected live workflow repeats only
the distinct observed-predecessor deployment proof and reuses exact-source
Validation where available.
