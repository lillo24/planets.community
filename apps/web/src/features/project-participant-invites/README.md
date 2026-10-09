# Browser participant invitations

This feature owns `/join/project/[token]` and the token-free
`/joined/proposals/[id]` / `/joined/tavoli/[id]` confirmations. PostgreSQL/PI01
owns eligibility, receipts and membership episodes. Authority invitations stay
in `project-delegates`; ordinary joining stays in the mobile request journey.

- `participant-models.ts` validates the minimal preview, original admission
  receipt and canonical own-membership episodes, and classifies safe failures.
- `participant-rpc.ts` implements the typed shared read/admission contract;
  `participant-gateway.ts` adds the browser client and Auth identity observer.
- `participant-server.ts` provides read-only, request-scoped server adapters.
- `participant-controller.ts` owns explicit admission and identity/revision
  guards, retained attempts, receipt recovery and independent status retries.
- `participant-browser.ts` retains one controller in browser/tab memory, outside
  React mounts. It is created only in the browser, never during server rendering.
- `participant-invite-flow-view.tsx` renders preview, prerequisites, explicit Join,
  recovery and deliberate re-entry; `participant-confirmation-view.tsx` rechecks
  live canonical participation before presenting the app handoff. The original
  `participant-invite-flow.tsx` / `participant-confirmation.tsx` entry points retain
  Next navigation. The static trial uses the same views and canonical controller
  with a small host adapter, without Next runtime aliases.
  That adapter can carry one explicit Join through Auth/name prerequisites using
  a tab-local, OTP-subject-bound request. The shared view consumes it once and
  calls this same controller; opening a link or restoring Auth cannot admit.
  Successful invitation/confirmation views omit Refresh controls; failed reads
  retain read-only recovery. Confirmation says "You joined the project" only
  after a fresh canonical membership check; owner context stays distinct.
- `participant-messages.ts` supplies safe UI failure copy.
- Colocated tests and `participant-test-fixtures.ts` cover wire contracts,
  gateway calls, identity/navigation races and controls. The opt-in production
  HTTP/gateway verifier is in `../../../test-support/` relative to the source
  feature; see the [PI03 record](../../../../../docs/implementation/pi03-browser-participant-invitations.md).

An attempt retains account/token/action UUID only in process memory. It survives
client navigation/remounts, including an unavailable refreshed preview. Reload
or process restart clears it: a subsequent click is fresh intent, guarded by a
canonical current-membership read, and never claims to recover the lost UUID.
Logout/account change clears all account-bound state. Auth hints invalidate;
verified claims bind mutation and result publication. Late context/identity
results are ignored. A committed receipt plus failed status read is resolved
with read-only Retry status check, never another admission.
