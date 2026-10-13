import { describe, it, expect, vi } from "vitest";
import { GroupInvitationController } from "./group-controller";
import type { GroupInvitationGateway } from "./group-gateway";
import {
  consentVersion,
  parseGroupCurrent,
  parseGroupPreview,
  parseGroupReceipt,
  type GroupReceipt,
} from "./group-models";
import {
  participantCancelDestination,
  sanitizeReturnDestination,
} from "../auth/return-destination";
import { containsInvitationSecret } from "@/lib/monitoring/invitation-privacy";
const actor = "f303b000-0000-4000-8000-000000000001",
  group = "f303b000-0000-4000-8000-000000000002",
  relationship = "f303b000-0000-4000-8000-000000000003",
  token = "A".repeat(43);
const preview = {
  available: true as const,
  id: group,
  name: "Fictional garden",
  kind: "informal" as const,
};
const receipt: GroupReceipt = {
  group,
  relationship,
  kind: "membership",
  outcome: "joined",
  current: "current",
  replayed: false,
};
function fixture(routeAllowed: () => boolean = () => true) {
  let observe: (actor: string | null) => void = () => {};
  const gateway = {
    auth: vi.fn().mockResolvedValue({ account: actor, phase: "ready" }),
    preview: vi.fn().mockResolvedValue(preview),
    recover: vi.fn().mockResolvedValue(null),
    accept: vi.fn().mockResolvedValue(receipt),
    current: vi.fn().mockResolvedValue({
      role: null,
      delegate: null,
      membership: relationship,
    }),
    publicGroup: vi.fn().mockResolvedValue(null),
    policy: vi.fn().mockResolvedValue(true),
    observeIdentity: vi.fn((callback) => {
      observe = callback;
      return () => {};
    }),
  } satisfies GroupInvitationGateway;
  const uuid = vi.fn().mockReturnValue(relationship),
    controller = new GroupInvitationController(gateway, uuid, routeAllowed);
  return {
    gateway,
    controller,
    uuid,
    observe: (id: string | null) => observe(id),
  };
}
describe("group invitations", () => {
  it("strict parsers reject missing nullable fields and retain unavailable current status", () => {
    expect(() =>
      parseGroupCurrent([
        {
          authority_role: null,
          delegate_id: null,
          current_membership_id: null,
        },
      ]),
    ).toThrow();
    expect(() =>
      parseGroupPreview(
        [
          {
            available: false,
            group_id: group,
            group_name: null,
            group_kind: null,
          },
        ],
        false,
      ),
    ).toThrow();
    expect(
      parseGroupReceipt([
        {
          group_id: group,
          relationship_id: relationship,
          relationship_kind: "membership",
          outcome: "joined",
          current_status: null,
          replayed: true,
          expires_at: null,
        },
      ]).current,
    ).toBeNull();
  });
  it.each(["signedOut", "incompleteProfile", "ready"] as const)(
    "preview and restored %s identity never accept",
    async (phase) => {
      const f = fixture();
      f.gateway.auth.mockResolvedValue({
        account: phase === "signedOut" ? null : actor,
        phase,
      });
      await f.controller.open(token, false);
      await f.controller.open(token, false);
      expect(f.gateway.accept).not.toHaveBeenCalled();
      expect(f.uuid).not.toHaveBeenCalled();
      f.controller.dispose();
    },
  );
  it("recovers the original tuple after lost reply and revoked preview, then only retries status", async () => {
    const f = fixture();
    await f.controller.open(token, false);
    f.gateway.accept.mockRejectedValueOnce(new Error("lost reply"));
    await f.controller.accept(consentVersion(preview), false);
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    f.gateway.preview.mockResolvedValue({ available: false });
    f.gateway.recover.mockResolvedValue({ ...receipt, replayed: true });
    f.gateway.current.mockRejectedValue(new Error("offline"));
    await f.controller.open(token, false);
    // Failed initial status must be retried before mutating. The retained action
    // remains the same UUID and recovers without needing a current preview.
    f.gateway.current.mockResolvedValue({
      role: null,
      delegate: null,
      membership: relationship,
    });
    await f.controller.open(token, false);
    await f.controller.accept(null, false);
    expect(f.controller.snapshot().receipt).toBeDefined();
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    expect(f.uuid).toHaveBeenCalledTimes(1);
    f.gateway.current.mockRejectedValue(new Error("offline"));
    await f.controller.retryStatus();
    expect(f.controller.snapshot().readFailure).toBeDefined();
    f.gateway.current.mockResolvedValue({
      role: null,
      delegate: null,
      membership: null,
    });
    await f.controller.retryStatus();
    expect(f.controller.confirmed()).toBe(false);
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    f.controller.dispose();
  });
  it("fresh re-entry gets another deliberate action; recovery cannot restore an ended episode", async () => {
    const f = fixture();
    f.uuid.mockReturnValueOnce(relationship).mockReturnValueOnce(group);
    await f.controller.open(token, false);
    await f.controller.accept(consentVersion(preview), false);
    expect(f.controller.confirmed()).toBe(true);
    f.gateway.current.mockResolvedValue({
      role: null,
      delegate: null,
      membership: null,
    });
    await f.controller.retryStatus();
    await f.controller.accept(consentVersion(preview), false);
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    await f.controller.accept(consentVersion(preview), false, true);
    expect(f.gateway.accept).toHaveBeenCalledTimes(2);
    expect(f.uuid).toHaveBeenCalledTimes(2);
    f.controller.dispose();
  });
  it("changed role/expiry invalidates informed consent before acceptance", async () => {
    const f = fixture();
    const role = {
      ...preview,
      role: "co_creator" as const,
      expires: "2026-10-19T00:00:00Z",
    };
    f.gateway.preview.mockResolvedValue(role);
    await f.controller.open(token, true);
    f.gateway.preview.mockResolvedValue({ ...role, role: "co_organizer" });
    await f.controller.accept(consentVersion(role), false);
    expect(f.gateway.accept).not.toHaveBeenCalled();
    expect(f.controller.snapshot().failure).toBe("stale");
    f.controller.dispose();
  });
  it("identity change during verification rejects the late action and all private state", async () => {
    const f = fixture();
    await f.controller.open(token, false);
    let release!: (value: { account: string; phase: string }) => void;
    f.gateway.auth.mockReturnValueOnce(
      new Promise((resolve) => {
        release = resolve;
      }),
    );
    const pending = f.controller.accept(consentVersion(preview), false);
    f.observe(null);
    release({ account: actor, phase: "ready" });
    await pending;
    expect(f.gateway.accept).not.toHaveBeenCalled();
    expect(f.controller.snapshot().receipt).toBeUndefined();
    expect(f.controller.snapshot().current).toBeUndefined();
    f.controller.dispose();
  });
  it("policy read failure is explicit and no acceptance follows missing consent", async () => {
    const f = fixture();
    f.gateway.policy.mockResolvedValue(false);
    await f.controller.open(token, false);
    await f.controller.accept(consentVersion(preview), false);
    expect(f.gateway.accept).not.toHaveBeenCalled();
    await f.controller.accept(consentVersion(preview), true);
    expect(f.gateway.policy).toHaveBeenCalledWith(actor, true);
    expect(f.gateway.accept).toHaveBeenCalledOnce();
    f.controller.dispose();
  });
  it("rejects fragments both before preview and before deliberate acceptance", async () => {
    let allowed = false;
    const f = fixture(() => allowed);
    await f.controller.open(token, false);
    expect(f.gateway.preview).not.toHaveBeenCalled();
    allowed = true;
    await f.controller.open(token, false);
    allowed = false;
    await f.controller.accept(consentVersion(preview), false);
    expect(f.gateway.accept).not.toHaveBeenCalled();
    expect(f.uuid).not.toHaveBeenCalled();
    f.controller.dispose();
  });
  it("invalidates consent when the same account signs out and returns", async () => {
    const f = fixture();
    await f.controller.open(token, true);
    const originalEpoch = f.controller.consentEpoch;
    f.observe(null);
    f.observe(actor);
    expect(f.controller.consentEpoch).toBe(originalEpoch + 2);
    expect(f.controller.snapshot().receipt).toBeUndefined();
    f.controller.dispose();
    await Promise.resolve();
    expect(f.gateway.accept).not.toHaveBeenCalled();
  });
  it("literal routes preserve Auth cancel and encoded capability telemetry is dropped", () => {
    for (const kind of ["join", "invite"]) {
      const path = `/${kind}/group/${token}`;
      expect(participantCancelDestination(path)).toBe(path);
      expect(
        participantCancelDestination(
          `/profile?returnTo=${encodeURIComponent(path)}`,
        ),
      ).toBe(path);
      expect(sanitizeReturnDestination(`${path}?unexpected=1`)).toBe("/");
      expect(
        sanitizeReturnDestination(path.replace("/group/", "/%67roup/")),
      ).toBe("/");
      expect(
        containsInvitationSecret(
          `/auth?returnTo=${encodeURIComponent(encodeURIComponent(path))}`,
        ),
      ).toBe(true);
    }
  });
});
