import { afterEach, describe, expect, it, vi } from "vitest";
import { ParticipantController } from "./participant-controller";
import type { AdmissionReceipt } from "./participant-models";
import {
  account,
  deferred,
  fakeGateway,
  otherAccount,
  preview,
  project,
  ready,
  receipt,
  token,
} from "./participant-test-fixtures";

const controllers: ParticipantController[] = [];
function setup() {
  const fake = fakeGateway();
  const uuid = vi
    .fn()
    .mockReturnValueOnce("00000000-0000-4000-8000-000000000011")
    .mockReturnValue("00000000-0000-4000-8000-000000000012");
  const controller = new ParticipantController(fake.gateway, uuid);
  controllers.push(controller);
  return { ...fake, uuid, controller };
}
afterEach(() => {
  controllers.forEach((controller) => controller.dispose());
  controllers.length = 0;
});
describe("explicit participant admission controller", () => {
  it.each([
    "signedOut",
    "missingProfile",
    "incompleteProfile",
    "ready",
  ] as const)("opening and restoring %s never admits", async (phase) => {
    const { controller, gateway, uuid } = setup();
    gateway.auth.mockResolvedValue({
      account: phase === "signedOut" ? null : account,
      phase,
    });
    await controller.openInvite(token);
    await controller.refresh();
    expect(gateway.accept).not.toHaveBeenCalled();
    expect(uuid).not.toHaveBeenCalled();
    if (phase !== "ready") {
      await controller.join();
      expect(gateway.accept).not.toHaveBeenCalled();
    }
  });
  it("suppresses double clicks before identity verification and allocates UUID only on explicit action", async () => {
    const { controller, gateway, uuid } = setup();
    await controller.openInvite(token);
    const pending = deferred<AdmissionReceipt>();
    gateway.accept.mockReturnValue(pending.promise);
    const joining = controller.join();
    await controller.join();
    await vi.waitFor(() => expect(gateway.accept).toHaveBeenCalledTimes(1));
    expect(uuid).toHaveBeenCalledTimes(1);
    pending.resolve(receipt);
    await joining;
  });
  it.each(["unavailable", "failed"])(
    "recovers same tuple after lost response, remount and %s preview",
    async (state) => {
      const { controller, gateway, uuid } = setup();
      await controller.openInvite(token);
      gateway.accept.mockRejectedValueOnce(new Error("response lost"));
      await controller.join();
      controller.deactivate(token);
      if (state === "failed")
        gateway.preview.mockRejectedValue(new Error("offline"));
      else gateway.preview.mockResolvedValue({ available: false });
      await controller.openInvite(token);
      expect(controller.snapshot().hasAttempt).toBe(true);
      expect(gateway.accept).toHaveBeenCalledTimes(1);
      gateway.accept.mockResolvedValue({ ...receipt, replayed: true });
      gateway.participation.mockResolvedValue({
        current: true,
        creator: false,
      });
      await controller.join();
      expect(gateway.accept.mock.calls[1]).toEqual(
        gateway.accept.mock.calls[0],
      );
      expect(uuid).toHaveBeenCalledTimes(1);
      expect(controller.snapshot().receipt?.replayed).toBe(true);
    },
  );
  it("ignores late route result while keeping unresolved tuple for a deliberate retry", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    const pending = deferred<AdmissionReceipt>();
    gateway.accept.mockReturnValueOnce(pending.promise);
    const joining = controller.join();
    await vi.waitFor(() => expect(gateway.accept).toHaveBeenCalledTimes(1));
    controller.deactivate(token);
    await controller.openInvite(token);
    pending.resolve(receipt);
    await joining;
    expect(controller.snapshot()).toMatchObject({
      busy: false,
      hasAttempt: true,
      receipt: undefined,
    });
    await controller.join();
    expect(gateway.accept.mock.calls[1]).toEqual(gateway.accept.mock.calls[0]);
  });
  it.each([null, otherAccount])(
    "clears account-bound action and ignores late result after cross-tab identity %s",
    async (next) => {
      const { controller, gateway, identity } = setup();
      await controller.openInvite(token);
      const pending = deferred<AdmissionReceipt>();
      gateway.accept.mockReturnValueOnce(pending.promise);
      const joining = controller.join();
      await vi.waitFor(() => expect(gateway.accept).toHaveBeenCalledTimes(1));
      gateway.auth.mockResolvedValue({
        account: next,
        phase: next ? "ready" : "signedOut",
      });
      identity(next);
      pending.resolve(receipt);
      await joining;
      await vi.waitFor(() =>
        expect(controller.snapshot().auth?.account).toBe(next),
      );
      expect(controller.snapshot().receipt).toBeUndefined();
      expect(controller.snapshot().hasAttempt).toBe(false);
      if (next) {
        await controller.join();
        expect(gateway.accept.mock.calls[1][0]).toBe(next);
        expect(gateway.accept.mock.calls[1][2]).not.toBe(
          gateway.accept.mock.calls[0][2],
        );
      }
    },
  );
  it("revalidates identity before mutation without depending on an auth event", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    gateway.auth.mockResolvedValue({ account: otherAccount, phase: "ready" });
    await controller.join();
    expect(gateway.accept).not.toHaveBeenCalled();
    expect(controller.snapshot().auth?.account).toBe(otherAccount);
  });
  it("rejects mismatched result project and never publishes current membership from it", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    gateway.accept.mockResolvedValue({ ...receipt, projectId: otherAccount });
    await controller.join();
    expect(controller.snapshot()).toMatchObject({
      failure: "malformed",
      receipt: undefined,
    });
  });
  it("separates committed result from failed canonical read and retries only reads", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    gateway.participation.mockRejectedValueOnce(new Error("offline"));
    await controller.join();
    expect(controller.snapshot()).toMatchObject({
      receipt,
      readFailure: "network",
      participation: undefined,
    });
    gateway.participation.mockResolvedValue({ current: true, creator: false });
    await controller.retryReads();
    expect(controller.snapshot().participation?.current).toBe(true);
    expect(gateway.accept).toHaveBeenCalledTimes(1);
  });
  it.each(["left", "removed"] as const)(
    "does not restore %s receipt; only explicit Join again allocates a fresh action",
    async (status) => {
      const { controller, gateway, uuid } = setup();
      await controller.openInvite(token);
      gateway.accept.mockResolvedValueOnce({
        ...receipt,
        membershipStatus: status,
        replayed: true,
      });
      await controller.join();
      await controller.join();
      await controller.refresh();
      await controller.retryReads();
      expect(gateway.accept).toHaveBeenCalledTimes(1);
      await controller.join(true);
      expect(uuid).toHaveBeenCalledTimes(2);
      expect(gateway.accept.mock.calls[1][2]).not.toBe(
        gateway.accept.mock.calls[0][2],
      );
    },
  );
  it("honors a newer current episode and Creator without re-entry", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    gateway.accept.mockResolvedValue({
      ...receipt,
      membershipStatus: "removed",
      replayed: true,
    });
    gateway.participation.mockResolvedValue({ current: true, creator: false });
    await controller.join();
    await controller.join(true);
    expect(controller.snapshot().participation?.current).toBe(true);
    expect(gateway.accept).toHaveBeenCalledTimes(1);
    gateway.participation.mockResolvedValue({ current: false, creator: true });
    await controller.refresh();
    await controller.join(true);
    expect(gateway.accept).toHaveBeenCalledTimes(1);
  });
  it("documents full reload as a fresh controller, guarding current membership rather than recovering a UUID", async () => {
    const first = setup();
    await first.controller.openInvite(token);
    first.gateway.accept.mockRejectedValue(new Error("lost"));
    await first.controller.join();
    first.controller.dispose();
    const next = setup();
    next.gateway.participation.mockResolvedValue({
      current: true,
      creator: false,
    });
    await next.controller.openInvite(token);
    await next.controller.join();
    expect(next.controller.snapshot().hasAttempt).toBe(false);
    expect(next.gateway.accept).not.toHaveBeenCalled();
    expect(next.uuid).not.toHaveBeenCalled();
  });
  it("token-free confirmation rechecks canonical state after leave and ignores old route cleanup", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    await controller.openConfirmation(project);
    controller.deactivate(token);
    gateway.participation.mockResolvedValue({ current: true, creator: false });
    await controller.retryReads();
    expect(controller.snapshot().participation?.current).toBe(true);
    gateway.participation.mockResolvedValue({ current: false, creator: false });
    await controller.retryReads();
    expect(controller.snapshot().participation?.current).toBe(false);
    expect(gateway.accept).not.toHaveBeenCalled();
    expect(gateway.preview).toHaveBeenCalledTimes(1);
  });
  it("suppresses result when authoritative identity changes after mutation", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    gateway.auth
      .mockResolvedValueOnce(ready)
      .mockResolvedValue({ account: otherAccount, phase: "ready" });
    await controller.join();
    expect(controller.snapshot().receipt).toBeUndefined();
    expect(controller.snapshot().hasAttempt).toBe(false);
    expect(preview.available).toBe(true);
  });
});
