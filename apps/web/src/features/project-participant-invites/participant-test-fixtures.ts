import { vi } from "vitest";
import type { ParticipantGateway } from "./participant-gateway";
import type {
  AdmissionReceipt,
  ParticipantAuth,
  ParticipantPreview,
  ProjectContext,
} from "./participant-models";

export const account = "00000000-0000-4000-8000-000000000001";
export const otherAccount = "00000000-0000-4000-8000-000000000002";
export const project: ProjectContext = {
  id: "00000000-0000-4000-8000-000000000003",
  kind: "one_time",
};
export const token = "a".repeat(43);
export const preview: ParticipantPreview = {
  available: true,
  project,
  title: "Community mural",
};
export const receipt: AdmissionReceipt = {
  projectId: project.id,
  membershipId: "00000000-0000-4000-8000-000000000004",
  membershipStatus: "current",
  outcome: "joined",
  replayed: false,
};
export const ready: ParticipantAuth = { account, phase: "ready" };
export function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((yes, no) => {
    resolve = yes;
    reject = no;
  });
  return { promise, resolve, reject };
}
export function fakeGateway() {
  let observer: (account: string | null) => void = () => {};
  const gateway = {
    auth: vi.fn<ParticipantGateway["auth"]>().mockResolvedValue(ready),
    preview: vi.fn<ParticipantGateway["preview"]>().mockResolvedValue(preview),
    accept: vi.fn<ParticipantGateway["accept"]>().mockResolvedValue(receipt),
    participation: vi
      .fn<ParticipantGateway["participation"]>()
      .mockResolvedValue({ current: false, creator: false }),
    observeIdentity: vi
      .fn<ParticipantGateway["observeIdentity"]>()
      .mockImplementation((callback) => {
        observer = callback;
        return vi.fn();
      }),
  } satisfies ParticipantGateway;
  return { gateway, identity: (id: string | null) => observer(id) };
}
