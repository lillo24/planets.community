import { describe, expect, it } from "vitest";
import { JoinContinuation } from "./join-continuation";
import {
  account,
  otherAccount,
  project,
  token,
} from "../src/features/project-participant-invites/participant-test-fixtures";

function anonymousJoin() {
  const continuation = new JoinContinuation();
  continuation.identityChanged(null);
  continuation.begin(token, project, null);
  return continuation;
}

describe("tab-local explicit Join continuation", () => {
  it("carries the verified local OTP account through setup and consumes once", () => {
    const continuation = anonymousJoin();
    const proof = continuation.startOtpVerification();
    continuation.identityChanged(account);
    expect(continuation.consume(token, account, project)).toBe(false);
    continuation.finishOtpVerification(proof, account);
    expect(continuation.consume(token, account, project)).toBe(true);
    expect(continuation.consume(token, account, project)).toBe(false);
  });

  it("does not inherit consent on reload or a restored/cross-tab sign-in", () => {
    const continuation = anonymousJoin();
    continuation.identityChanged(account);
    expect(continuation.snapshot()).toBeNull();
    expect(continuation.consume(token, account, project)).toBe(false);
    const reloaded = new JoinContinuation();
    reloaded.identityChanged(account);
    expect(reloaded.consume(token, account, project)).toBe(false);
  });

  it("rejects a different subject during local OTP verification", () => {
    const continuation = anonymousJoin();
    const proof = continuation.startOtpVerification();
    continuation.identityChanged(otherAccount);
    continuation.finishOtpVerification(proof, account);
    expect(continuation.snapshot()).toBeNull();
  });

  it("allows a failed OTP retry without authorizing admission", () => {
    const continuation = anonymousJoin();
    continuation.finishOtpVerification(continuation.startOtpVerification());
    expect(continuation.snapshot()?.account).toBeNull();
    const retry = continuation.startOtpVerification();
    continuation.identityChanged(account);
    continuation.finishOtpVerification(retry, account);
    expect(continuation.consume(token, account, project)).toBe(true);
  });

  it("cannot revive a cancelled or newer Join with a late OTP completion", () => {
    const continuation = anonymousJoin();
    const obsolete = continuation.startOtpVerification();
    continuation.cancel();
    continuation.begin("b".repeat(43), project, null);
    continuation.identityChanged(account);
    continuation.finishOtpVerification(obsolete, account);
    expect(continuation.snapshot()).toBeNull();
  });

  it("binds signed-in profile setup to the same account and project", () => {
    const continuation = new JoinContinuation();
    continuation.identityChanged(account);
    continuation.begin(token, project, account);
    expect(
      continuation.consume(token, account, { ...project, kind: "recurring" }),
    ).toBe(false);
    expect(continuation.snapshot()).toBeNull();
    continuation.begin(token, project, account);
    continuation.identityChanged(otherAccount);
    expect(continuation.consume(token, otherAccount, project)).toBe(false);
    continuation.begin(token, project, account);
    expect(continuation.snapshot()).toBeNull();
  });
});
