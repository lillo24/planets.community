import {
  consentVersion,
  groupFailure,
  groupTokenPattern,
  type GroupAuth,
  type GroupCurrent,
  type GroupFailure,
  type GroupPreview,
  type GroupReceipt,
  type PublicGroupContent,
} from "./group-models";
import type { GroupInvitationGateway } from "./group-gateway";
export type GroupInvitationState = Readonly<{
  token?: string;
  authority: boolean;
  auth?: GroupAuth;
  preview?: GroupPreview;
  content?: PublicGroupContent | null;
  receipt?: GroupReceipt;
  current?: GroupCurrent;
  policyAccepted: boolean;
  loading: boolean;
  busy: boolean;
  failure?: GroupFailure;
  readFailure?: GroupFailure;
  contentFailure?: GroupFailure;
  hasAttempt: boolean;
}>;
type Attempt = {
  actor: string;
  key: string;
  token: string;
  authority: boolean;
  consent: string | null;
  receipt?: GroupReceipt;
};
const empty: GroupInvitationState = Object.freeze({
  authority: false,
  policyAccepted: false,
  loading: false,
  busy: false,
  hasAttempt: false,
});
/** Tab-memory capability attempts outlive React components, never Auth identity. */
export class GroupInvitationController {
  private state: GroupInvitationState = empty;
  private listeners = new Set<() => void>();
  private attempts = new Map<string, Attempt>();
  private revision = 0;
  private active = true;
  private disposed = false;
  private identity: string | null | undefined;
  consentEpoch = 0;
  private stop: () => void;
  constructor(
    readonly gateway: GroupInvitationGateway,
    private uuid: () => string = () => crypto.randomUUID(),
    private routeAllowed: () => boolean = () => true,
  ) {
    this.stop = gateway.observeIdentity((actor) => {
      if (this.identity === actor) return;
      this.identity = actor;
      this.consentEpoch++;
      this.revision++;
      this.attempts.clear();
      const { token, authority } = this.state;
      this.set({ ...empty, token, authority });
      // Supabase auth callbacks must return without awaiting another Auth call.
      queueMicrotask(() => {
        if (token && this.active && !this.disposed)
          void this.open(token, authority);
      });
    });
  }
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  snapshot = () => this.state;
  private set(next: GroupInvitationState) {
    this.state = Object.freeze(next);
    this.listeners.forEach((f) => f());
  }
  private patch(next: Partial<GroupInvitationState>) {
    this.set({ ...this.state, ...next });
  }
  private slot(token: string, authority: boolean) {
    return `${authority ? "authority" : "participant"}/${token}`;
  }
  private live(revision: number) {
    return !this.disposed && this.active && revision === this.revision;
  }
  async open(token: string, authority: boolean) {
    if (
      this.state.token === token &&
      this.state.authority === authority &&
      this.state.busy
    )
      return;
    this.active = true;
    const revision = ++this.revision;
    this.set({ ...empty, token, authority, loading: true });
    if (!groupTokenPattern.test(token) || !this.routeAllowed()) {
      this.patch({ loading: false, preview: { available: false } });
      return;
    }
    try {
      const [auth, preview] = await Promise.all([
        this.gateway.auth(),
        this.gateway.preview(token, authority),
      ]);
      if (!this.live(revision)) return;
      if (this.identity !== undefined && this.identity !== auth.account) {
        this.consentEpoch++;
        this.attempts.clear();
      }
      this.identity = auth.account;
      const attempt = this.attempts.get(this.slot(token, authority));
      const receipt =
        attempt?.actor === auth.account ? attempt?.receipt : undefined;
      this.patch({ auth, preview, receipt, hasAttempt: !!attempt });
      const group = receipt?.group ?? (preview.available ? preview.id : null);
      const reads = await Promise.allSettled([
        auth.account
          ? this.gateway.policy(auth.account)
          : Promise.resolve(false),
        group ? this.gateway.publicGroup(group) : Promise.resolve(null),
        auth.account && group
          ? this.gateway.current(auth.account, group)
          : Promise.resolve(undefined),
      ]);
      if (!this.live(revision)) return;
      this.patch({
        policyAccepted:
          reads[0].status === "fulfilled" ? reads[0].value : false,
        content: reads[1].status === "fulfilled" ? reads[1].value : undefined,
        contentFailure:
          reads[1].status === "rejected"
            ? groupFailure(reads[1].reason)
            : undefined,
        current: reads[2].status === "fulfilled" ? reads[2].value : undefined,
        readFailure:
          reads[0].status === "rejected"
            ? groupFailure(reads[0].reason)
            : reads[2].status === "rejected"
              ? groupFailure(reads[2].reason)
              : undefined,
      });
    } catch (error) {
      if (this.live(revision)) this.patch({ failure: groupFailure(error) });
    } finally {
      if (this.live(revision)) this.patch({ loading: false });
    }
  }
  deactivate(token: string) {
    if (this.state.token === token) {
      this.active = false;
      this.revision++;
    }
  }
  confirmed() {
    const s = this.state;
    return (
      !!s.receipt &&
      !!s.current &&
      (s.authority
        ? s.current.role !== null
        : s.current.membership !== null || s.current.role === "creator")
    );
  }
  async accept(
    consent: string | null,
    policyConsent: boolean,
    reenter = false,
  ) {
    const state = this.state,
      { token, authority } = state;
    if (
      !token ||
      !this.routeAllowed() ||
      state.loading ||
      state.busy ||
      state.auth?.phase !== "ready" ||
      !state.auth.account ||
      state.readFailure
    )
      return;
    if (state.receipt && !reenter) {
      await this.retryStatus();
      return;
    }
    if (
      reenter &&
      (authority ||
        !state.receipt ||
        !state.current ||
        this.confirmed() ||
        !state.preview?.available)
    )
      return;
    const actor = state.auth.account,
      slot = this.slot(token, authority),
      revision = this.revision;
    if (reenter) {
      this.attempts.delete(slot);
      this.patch({ receipt: undefined, current: undefined });
    }
    let attempt = this.attempts.get(slot);
    if (!attempt) {
      if (
        !state.preview?.available ||
        consentVersion(state.preview) !== consent
      )
        return;
      attempt = { actor, key: this.uuid(), token, authority, consent };
      this.attempts.set(slot, attempt);
    }
    if (attempt.actor !== actor) return;
    this.patch({ busy: true, failure: undefined, hasAttempt: true });
    try {
      const verified = await this.gateway.auth();
      if (!this.live(revision)) return;
      if (verified.account !== actor || verified.phase !== "ready") {
        this.attempts.clear();
        this.patch({
          auth: verified,
          current: undefined,
          receipt: undefined,
          policyAccepted: false,
          hasAttempt: false,
        });
        return;
      }
      const accepted = await this.gateway.policy(actor);
      if (!this.live(revision)) return;
      if (!accepted) {
        if (!policyConsent) {
          this.patch({ policyAccepted: false });
          return;
        }
        await this.gateway.policy(actor, true);
        if (!this.live(revision)) return;
      }
      this.patch({ policyAccepted: true });
      const recovered = await this.gateway.recover(actor, attempt.key);
      if (!this.live(revision)) return;
      if (!recovered) {
        const preview = await this.gateway.preview(token, authority);
        if (!this.live(revision)) return;
        if (!preview.available || consentVersion(preview) !== attempt.consent) {
          this.patch({ preview, failure: "stale" });
          return;
        }
      }
      const receipt =
        recovered ??
        (await this.gateway.accept(actor, attempt.key, token, authority));
      if (!this.live(revision)) return;
      if (state.preview?.available && receipt.group !== state.preview.id) {
        this.patch({ failure: "malformed" });
        return;
      }
      attempt.receipt = receipt;
      this.patch({ receipt });
      await this.retryStatus();
    } catch (error) {
      if (this.live(revision)) this.patch({ failure: groupFailure(error) });
    } finally {
      if (this.live(revision)) this.patch({ busy: false });
    }
  }
  async retryStatus() {
    const s = this.state,
      actor = s.auth?.account,
      group = s.receipt?.group ?? (s.preview?.available ? s.preview.id : null);
    if (!actor || !group) return;
    const revision = this.revision;
    try {
      const verified = await this.gateway.auth();
      if (!this.live(revision)) return;
      if (verified.account !== actor) {
        this.attempts.clear();
        this.patch({
          auth: verified,
          current: undefined,
          receipt: undefined,
          policyAccepted: false,
          hasAttempt: false,
        });
        return;
      }
      const current = await this.gateway.current(actor, group);
      if (this.live(revision)) this.patch({ current, readFailure: undefined });
    } catch (error) {
      if (this.live(revision))
        this.patch({ current: undefined, readFailure: groupFailure(error) });
    }
  }
  dispose() {
    this.disposed = true;
    this.revision++;
    this.attempts.clear();
    this.stop();
    this.listeners.clear();
  }
  toString() {
    return "GroupInvitationController(redacted)";
  }
}
