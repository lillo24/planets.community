import type { ProjectContext } from "../src/features/project-participant-invites/participant-models";

type PendingJoin = Readonly<{
  id: symbol;
  token: string;
  project: ProjectContext;
  account: string | null;
  proof?: symbol;
}>;
type OtpProof = Readonly<{ intent: symbol; verification: symbol }>;

// A single explicit Join can continue through prerequisites in this tab only.
// This is consent state, not Auth state; claims and the canonical controller
// still verify eligibility, current membership and identity before admission.
export class JoinContinuation {
  private pending: PendingJoin | null = null;
  private identity: string | null | undefined;
  private listeners = new Set<() => void>();
  snapshot = () => this.pending;
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  private set(pending: PendingJoin | null) {
    this.pending = pending;
    this.listeners.forEach((listener) => listener());
  }
  cancel = () => this.set(null);
  begin(token: string, project: ProjectContext, account: string | null) {
    if (account !== this.identity) return;
    this.set({ id: Symbol(), token, project, account });
  }
  identityChanged(next: string | null) {
    const previous = this.identity;
    this.identity = next;
    if (next === previous || !this.pending) return;
    // Only an OTP verification initiated in this tab may carry an anonymous
    // consent through its first signed-in identity event. A restored session
    // or another tab's login cannot authorize the pending Join.
    if (
      this.pending.account === null &&
      this.pending.proof &&
      previous === null &&
      next !== null
    )
      return;
    if (next !== this.pending.account) this.cancel();
  }
  startOtpVerification(): OtpProof | undefined {
    const pending = this.pending;
    if (!pending || pending.account !== null || this.identity !== null) return;
    const verification = Symbol();
    this.set({ ...pending, proof: verification });
    return { intent: pending.id, verification };
  }
  finishOtpVerification(proof: OtpProof | undefined, account?: string) {
    const pending = this.pending;
    if (
      !proof ||
      !pending ||
      pending.id !== proof.intent ||
      pending.proof !== proof.verification
    )
      return;
    if (account && this.identity === account) {
      this.set({ ...pending, account, proof: undefined });
    } else if (this.identity === null) {
      this.set({ ...pending, proof: undefined });
    } else {
      this.cancel();
    }
  }
  consume(token: string, account: string, project: ProjectContext) {
    const pending = this.pending;
    if (!pending || pending.token !== token || pending.account === null)
      return false;
    const matches =
      pending.account === account &&
      this.identity === account &&
      pending.project.id === project.id &&
      pending.project.kind === project.kind;
    this.cancel();
    return matches;
  }
}
