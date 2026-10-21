# ADR 0008: Independent mock realm and anonymous client capability

Status: Accepted, amended 2026-10-21 by
`00_MOCK_ACCESS_CORRECTION_Open_Test_App.md`. This supersedes the original normal
control identity / human enrollment requirement in this ADR and the MOCK prompts.

The dedicated mock project is `pnolarmzxmmjtguligfc`; protected normal staging is
`cllpvruvrrvxczjitlqd`. Auth/signing keys, product data, Storage and Realtime are
independent. Canonical migrations/domain/RLS remain shared source, never data.

Anyone, including a signed-out guest, may use the public fixed-persona demo
broker while enabled. No normal login, tester identities or installation proof
is required. Production builds keep this explicit test capability off. The
endpoint itself is public; the flag is not a secret or backend entitlement.

A server-generated 256-bit random client capability isolates pending issuance,
encrypted recovery and local retirement. It is unrelated to human identity or a
hardware/email identifier. The server stores only its hash; the app uses platform
confidential storage. Only the public client UUID enters version-2 mode metadata.
Existing normal Auth is retained separately and never used for broker access.

Only registered fictional ordinary accounts can be selected. Secrets and one-time
Auth generation remain server-side, followed by standard session verification.
Two-minute AES-GCM delivery binds mock origin, generation, capability, request
and persona. Shared personas retain independent client sessions. Global ceilings
bound resource use even when callers create new capabilities. No paid identity
or attestation provider, new PII collection or enrollment surrogate is introduced.

Every operator mutation verifies the exact mock marker and canonical digest.
Controls are outside canonical migrations; non-destructive fixture receipts
preserve shared world edits. Upgrading disabled legacy controls revokes only
their recorded mock sessions and removes obsolete ownership tables/functions.
Version-1 device metadata is never adopted; bounded legacy mock credential keys
are deleted while normal credentials remain untouched.

The coordinator replaces the complete provider/router/image scope on commit.
Monotone revisions fence stale operation/account/mode ABA results. Normal account
changes fence in-flight transitions; normal Auth expiry does not remove stable
mock eligibility. No product traffic crosses realms. Guest No returns guest Home;
retained valid normal accounts restore; genuinely expired retained accounts use
ordinary honest sign-in recovery. Logout retires only this client's mock session.

Shutdown disables issuance and revokes registered mock-persona refresh sessions,
preserving the world and all normal sessions. Existing bearer tokens expire within
the configured maximum one hour. Hiding production UI alone is not shutdown.
Code qualification, hosted public-mock readiness and release artifacts are
reported independently. See the operator runbook and mobile boundary inventory.
