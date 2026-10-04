import type { ParticipantGateway } from "./participant-gateway";
import {
  mapParticipantFailure,
  ParticipantError,
  type AdmissionReceipt,
  type CurrentParticipation,
  type ParticipantAuth,
  type ParticipantFailure,
  type ParticipantPreview,
  type ProjectContext,
} from "./participant-models";

export type ParticipantState = Readonly<{
  loading: boolean;
  busy: boolean;
  auth?: ParticipantAuth;
  preview?: ParticipantPreview;
  previewFailure?: ParticipantFailure;
  project?: ProjectContext;
  participation?: CurrentParticipation;
  readFailure?: ParticipantFailure;
  failure?: ParticipantFailure;
  hasAttempt: boolean;
  receipt?: AdmissionReceipt;
}>;
type Context = { token: string } | { project: ProjectContext };
type Attempt = {
  account: string;
  token: string;
  action: string;
  project: ProjectContext;
  busy: boolean;
  receipt?: AdmissionReceipt;
};
const initialState: ParticipantState = Object.freeze({
  loading: true,
  busy: false,
  hasAttempt: false,
});

// Browser/tab memory, independent of React mounts. No token/action persistence.
export class ParticipantController {
  private state: ParticipantState = initialState;
  private context?: Context;
  private attempts = new Map<string, Attempt>();
  private account: string | null | undefined;
  private revision = 0;
  private identityRevision = 0;
  private listeners = new Set<() => void>();
  private unsubscribe: () => void;
  private identityTimer?: ReturnType<typeof setTimeout>;
  private disposed = false;

  constructor(
    private readonly gateway: ParticipantGateway,
    private readonly uuid: () => string = () => crypto.randomUUID(),
  ) {
    this.unsubscribe = gateway.observeIdentity((account) => {
      if (account === this.account) return;
      this.account = account;
      this.identityRevision++;
      this.revision++;
      this.attempts.clear();
      this.set(initialState);
      // Never await another Supabase Auth operation inside its locked callback.
      clearTimeout(this.identityTimer);
      this.identityTimer = setTimeout(() => {
        void this.refresh();
      }, 0);
    });
  }
  snapshot = (): ParticipantState => this.state;
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  private set(state: ParticipantState) {
    if (this.disposed) return;
    this.state = Object.freeze(state);
    this.listeners.forEach((listener) => listener());
  }
  private current(revision: number) {
    return !this.disposed && revision === this.revision;
  }
  isInvite(token: string) {
    return (
      this.context && "token" in this.context && this.context.token === token
    );
  }
  async openInvite(token: string, preview?: ParticipantPreview) {
    this.context = { token };
    this.set({ ...initialState, preview });
    await this.refresh();
  }
  async openConfirmation(project: ProjectContext) {
    this.context = { project };
    this.set({ ...initialState, project });
    await this.refresh();
  }
  deactivate(expected: string | ProjectContext) {
    const context = this.context;
    if (
      !context ||
      (typeof expected === "string"
        ? !("token" in context) || context.token !== expected
        : !("project" in context) ||
          context.project.id !== expected.id ||
          context.project.kind !== expected.kind)
    )
      return;
    this.revision++;
    this.context = undefined;
    this.set(initialState);
  }
  dispose() {
    this.disposed = true;
    this.revision++;
    this.identityRevision++;
    clearTimeout(this.identityTimer);
    this.unsubscribe();
    this.attempts.clear();
    this.listeners.clear();
  }
  private adopt(auth: ParticipantAuth) {
    if (this.account !== auth.account) {
      this.attempts.clear();
      this.identityRevision++;
      this.account = auth.account;
    }
  }
  async refresh() {
    const context = this.context;
    if (!context || this.disposed) return;
    const revision = ++this.revision;
    const identityRevision = this.identityRevision;
    this.set({
      ...initialState,
      preview: this.state.preview,
      project: "project" in context ? context.project : undefined,
    });
    const [authResult, previewResult] = await Promise.allSettled([
      this.gateway.auth(),
      "token" in context
        ? this.gateway.preview(context.token)
        : Promise.resolve(undefined),
    ]);
    if (!this.current(revision) || identityRevision !== this.identityRevision)
      return;
    if (authResult.status === "rejected") {
      this.set({
        ...this.state,
        loading: false,
        readFailure: mapParticipantFailure(authResult.reason),
        preview:
          previewResult.status === "fulfilled"
            ? previewResult.value
            : undefined,
        previewFailure:
          previewResult.status === "rejected"
            ? mapParticipantFailure(previewResult.reason)
            : undefined,
      });
      return;
    }
    const auth = authResult.value;
    this.adopt(auth);
    const attempt =
      "token" in context ? this.attempts.get(context.token) : undefined;
    const preview =
      previewResult.status === "fulfilled" ? previewResult.value : undefined;
    const project =
      "project" in context
        ? context.project
        : (attempt?.project ??
          (preview?.available ? preview.project : undefined));
    this.set({
      loading: false,
      busy: attempt?.busy === true,
      hasAttempt: !!attempt,
      receipt: attempt?.receipt,
      auth,
      preview,
      project,
      previewFailure:
        previewResult.status === "rejected"
          ? mapParticipantFailure(previewResult.reason)
          : undefined,
    });
    if (
      project &&
      auth.account &&
      (auth.phase === "ready" || "project" in context)
    )
      await this.readParticipation(revision, auth.account, project);
  }
  private async verify(account: string, revision: number): Promise<boolean> {
    const auth = await this.gateway.auth();
    if (!this.current(revision)) return false;
    if (auth.account !== account) {
      this.adopt(auth);
      this.set(initialState);
      await this.refresh();
      return false;
    }
    this.set({ ...this.state, auth });
    return true;
  }
  private async readParticipation(
    revision: number,
    account: string,
    project: ProjectContext,
  ) {
    this.set({
      ...this.state,
      loading: true,
      participation: undefined,
      readFailure: undefined,
    });
    try {
      const participation = await this.gateway.participation(account, project);
      if (!(await this.verify(account, revision))) return;
      this.set({ ...this.state, loading: false, participation });
    } catch (error) {
      if (this.current(revision))
        this.set({
          ...this.state,
          loading: false,
          participation: undefined,
          readFailure: mapParticipantFailure(error),
        });
    }
  }
  async retryReads() {
    const { auth, project } = this.state;
    if (!auth?.account || !project || this.state.loading || this.state.busy) {
      await this.refresh();
      return;
    }
    const revision = ++this.revision;
    try {
      if (!(await this.verify(auth.account, revision))) return;
      await this.readParticipation(revision, auth.account, project);
    } catch (error) {
      if (this.current(revision))
        this.set({
          ...this.state,
          loading: false,
          readFailure: mapParticipantFailure(error),
          participation: undefined,
        });
    }
  }
  async join(reenter = false) {
    const context = this.context;
    const { auth, preview, participation } = this.state;
    if (
      !context ||
      !("token" in context) ||
      this.state.busy ||
      this.state.loading ||
      auth?.phase !== "ready" ||
      !auth.account
    )
      return;
    let attempt = this.attempts.get(context.token);
    if (reenter) {
      if (
        !attempt?.receipt ||
        attempt.receipt.outcome === "creator" ||
        !participation ||
        participation.current ||
        participation.creator ||
        !preview?.available
      )
        return;
    } else if (
      attempt?.receipt ||
      (!attempt &&
        (!participation || participation.current || participation.creator))
    )
      return;
    const revision = this.revision;
    const account = auth.account;
    this.set({ ...this.state, busy: true, failure: undefined });
    try {
      if (!(await this.verify(account, revision))) return;
      if (this.state.auth?.phase !== "ready")
        throw new ParticipantError("profile");
      if (reenter) attempt = undefined;
      if (!attempt) {
        if (!preview?.available) return;
        attempt = {
          account,
          token: context.token,
          action: this.uuid(),
          project: preview.project,
          busy: false,
        };
        this.attempts.set(context.token, attempt);
      }
      if (attempt.busy || attempt.account !== account) return;
      attempt.busy = true;
      this.set({ ...this.state, hasAttempt: true });
      const receipt = await this.gateway.accept(
        account,
        attempt.token,
        attempt.action,
      );
      if (!(await this.verify(account, revision))) return;
      if (receipt.projectId !== attempt.project.id)
        throw new ParticipantError("malformed");
      attempt.receipt = receipt;
      attempt.busy = false;
      this.set({
        ...this.state,
        receipt,
        busy: false,
        project: attempt.project,
      });
      await this.readParticipation(revision, account, attempt.project);
    } catch (error) {
      if (this.current(revision))
        this.set({ ...this.state, failure: mapParticipantFailure(error) });
    } finally {
      if (attempt) attempt.busy = false;
      if (
        this.current(revision) ||
        (this.isInvite(context.token) &&
          this.account === account &&
          this.attempts.get(context.token) === attempt)
      )
        this.set({ ...this.state, busy: false });
    }
  }
}
