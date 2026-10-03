import { describe, expect, it, vi } from "vitest";
import { performModerationConsequence } from "./moderation-operations";
import type { ModerationServerClient } from "./moderation-server";
import type { ConsequenceType } from "./moderation-consequence-models";
import {
  moderationConsequenceRow,
  moderationDetailRow,
} from "./moderation-test-fixtures";

vi.mock("server-only", () => ({}));
const caseId = moderationDetailRow().case_id;
const profileId = moderationConsequenceRow().actor_profile_id;
const consequenceId = moderationConsequenceRow().consequence_id;
const command = {
  mode: "apply",
  caseId,
  type: "safety_notice",
  userReason: "  Reason for user  ",
  internalNote: "  Evidence for staff only  ",
};
const types: ConsequenceType[] = [
  "safety_notice",
  "interaction_restriction",
  "content_hide",
  "account_suspension",
];

describe("staff consequence operations", () => {
  it.each([null, "ordinary"])(
    "denies %s access without reading or mutating a case",
    async (role) => {
      const staff = client({ role });
      expect(
        await performModerationConsequence(command, async () => staff),
      ).toEqual({ status: "error", kind: "unauthorized" });
      expect(staff.rpc).not.toHaveBeenCalledWith(
        "get_moderation_case_detail",
        expect.anything(),
      );
    },
  );
  it("denies signed-out access without any RPC", async () => {
    const staff = client({ signedOut: true });
    expect(
      await performModerationConsequence(command, async () => staff),
    ).toMatchObject({ kind: "unauthorized" });
    expect(staff.rpc).not.toHaveBeenCalled();
  });
  it.each(types)(
    "applies %s with canonical case identity and separate normalized fields",
    async (type) => {
      const staff = client({
        role: type === "account_suspension" ? "admin" : "moderator",
        targetKind:
          type === "content_hide" ? "project" : "project_chat_message",
      });
      expect(
        await performModerationConsequence(
          { ...command, type },
          async () => staff,
        ),
      ).toEqual({ status: "success", kind: "applied" });
      expect(staff.rpc).toHaveBeenLastCalledWith(
        type === "account_suspension"
          ? "apply_account_suspension"
          : "apply_moderation_consequence",
        {
          p_expected_staff_profile_id: profileId,
          p_case_id: caseId,
          p_user_reason: "Reason for user",
          p_internal_note: "Evidence for staff only",
          ...(type === "account_suspension"
            ? {}
            : { p_consequence_type: type }),
        },
      );
      expect(staff.rpc).not.toHaveBeenCalledWith(
        "transition_moderation_case",
        expect.anything(),
      );
    },
  );
  it("allows completed Resource listing content hide", async () => {
    const staff = client({
      targetKind: "resource_listing",
      state: "completed",
    });
    expect(
      await performModerationConsequence(
        { ...command, type: "content_hide" },
        async () => staff,
      ),
    ).toMatchObject({ status: "success" });
  });
  it.each(types)(
    "revokes active %s through its correct RPC without mixing its reasons",
    async (type) => {
      const staff = client({ role: "admin", history: history(type) });
      expect(
        await performModerationConsequence(
          { ...command, mode: "revoke", type, consequenceId },
          async () => staff,
        ),
      ).toEqual({ status: "success", kind: "revoked" });
      expect(staff.rpc).toHaveBeenLastCalledWith(
        type === "account_suspension"
          ? "revoke_account_suspension"
          : "revoke_moderation_consequence",
        {
          p_expected_staff_profile_id: profileId,
          p_consequence_id: consequenceId,
          p_user_reason: "Reason for user",
          p_internal_note: "Evidence for staff only",
        },
      );
    },
  );
  it.each(["apply", "revoke"])(
    "denies moderator suspension %s even with forged form intent",
    async (mode) => {
      const staff = client({
        role: "moderator",
        history: history("account_suspension"),
      });
      const input = {
        ...command,
        mode,
        type: "account_suspension",
        ...(mode === "revoke" ? { consequenceId } : {}),
      };
      expect(
        await performModerationConsequence(input, async () => staff),
      ).toMatchObject({ kind: "unauthorized" });
      expect(staff.rpc).toHaveBeenCalledTimes(1);
    },
  );
  it("rechecks authority on the next submit rather than trusting render-time staff", async () => {
    const staff = client({ role: "admin", roles: ["admin", "moderator"] });
    expect(
      await performModerationConsequence(
        { ...command, type: "account_suspension" },
        async () => staff,
      ),
    ).toMatchObject({ status: "success" });
    expect(
      await performModerationConsequence(
        { ...command, type: "account_suspension" },
        async () => staff,
      ),
    ).toMatchObject({ kind: "unauthorized" });
    expect(
      vi
        .mocked(staff.rpc)
        .mock.calls.filter(([name]) => name === "apply_account_suspension"),
    ).toHaveLength(1);
  });
  it.each([
    [{ state: "received" }, "safety_notice", "review_required"],
    [{ targetKind: "resource_request" }, "content_hide", "incompatible_target"],
    [
      { targetKind: "project_chat_message" },
      "content_hide",
      "incompatible_target",
    ],
    [
      { role: "admin", subjectId: profileId },
      "account_suspension",
      "self_suspension",
    ],
  ] as const)(
    "rejects incompatible action before mutation %#",
    async (options, type, kind) => {
      const staff = client(options);
      expect(
        await performModerationConsequence(
          { ...command, type },
          async () => staff,
        ),
      ).toMatchObject({ status: "error", kind });
      expect(
        vi
          .mocked(staff.rpc)
          .mock.calls.some(([name]) => name.startsWith("apply_")),
      ).toBe(false);
    },
  );
  it("rejects a forged staff ID before creating a client", async () => {
    const factory = vi.fn(async () => client());
    expect(
      await performModerationConsequence(
        { ...command, staffProfileId: profileId },
        factory,
      ),
    ).toMatchObject({ kind: "invalid_input" });
    expect(factory).not.toHaveBeenCalled();
  });
  it("cannot revoke another case's episode or route suspension as a notice", async () => {
    const absent = client();
    expect(
      await performModerationConsequence(
        { ...command, mode: "revoke", consequenceId },
        async () => absent,
      ),
    ).toMatchObject({ kind: "stale" });
    const forged = client({ history: history("account_suspension") });
    expect(
      await performModerationConsequence(
        { ...command, mode: "revoke", consequenceId },
        async () => forged,
      ),
    ).toMatchObject({ kind: "incompatible_target" });
    expect(forged.rpc).not.toHaveBeenCalledWith(
      "revoke_moderation_consequence",
      expect.anything(),
    );
  });
  it("rejects historical already-revoked episodes without mutation", async () => {
    const applied = {
      ...moderationConsequenceRow(),
      revoked_at: "2026-09-28T11:00:00Z",
    };
    const staff = client({
      history: [
        applied,
        {
          ...applied,
          action_id: "00000000-0000-4000-8000-000000000933",
          action_kind: "revoked",
          action_at: applied.revoked_at,
        },
      ],
    });
    expect(
      await performModerationConsequence(
        { ...command, mode: "revoke", consequenceId },
        async () => staff,
      ),
    ).toMatchObject({ kind: "already_revoked" });
    expect(staff.rpc).not.toHaveBeenCalledWith(
      "revoke_moderation_consequence",
      expect.anything(),
    );
  });
  it.each([
    ["42501", "role revoked after lookup", "unauthorized"],
    ["42501", "An admin cannot suspend their own account.", "self_suspension"],
    ["PT403", "suspended staff", "unauthorized"],
    [
      "PT409",
      "The case must be reviewed before applying a consequence.",
      "review_required",
    ],
    [
      "PT409",
      "An active consequence already exists for this target.",
      "duplicate",
    ],
    ["PT409", "An active account suspension already exists.", "duplicate"],
    ["PT409", "The consequence is no longer active.", "already_revoked"],
    ["PT409", "The account suspension is no longer active.", "already_revoked"],
    [
      "22023",
      "Content hide requires a Project or Resource listing case.",
      "incompatible_target",
    ],
    ["22023", "raw invalid internal text", "invalid_input"],
    ["P0002", "not found", "stale"],
    ["PT409", "unknown conflict", "stale"],
    ["23505", "raw unique index", "duplicate"],
    ["XX000", "secret SQL and report identity", "unavailable"],
  ])(
    "maps %s to bounded %s/%s without exposing SQL/private text",
    async (code, message, kind) => {
      const staff = client({ mutationError: { code, message } });
      expect(
        await performModerationConsequence(command, async () => staff),
      ).toEqual({ status: "error", kind });
    },
  );
  it.each(["throw", "malformed"])(
    "does not report an unconfirmed %s mutation as success",
    async (result) => {
      const staff = client({
        mutationThrows: result === "throw",
        mutationData: result === "malformed" ? [] : consequenceId,
      });
      expect(
        await performModerationConsequence(command, async () => staff),
      ).toEqual({ status: "error", kind: "unavailable" });
    },
  );
  it("fails explicitly on malformed authorized case/history data", async () => {
    const staff = client({ history: [{}] });
    expect(
      await performModerationConsequence(
        { ...command, mode: "revoke", consequenceId },
        async () => staff,
      ),
    ).toMatchObject({ kind: "unavailable" });
  });
});

function history(type: ConsequenceType) {
  return [
    {
      ...moderationConsequenceRow(),
      consequence_type: type,
      project_id:
        type === "content_hide"
          ? moderationDetailRow().project_context_id
          : null,
    },
  ];
}
function client({
  role = "moderator",
  roles,
  signedOut = false,
  state = "under_review",
  targetKind = "project_chat_message",
  subjectId = moderationDetailRow().subject_profile_id,
  history: episodes = [],
  mutationError = null,
  mutationThrows = false,
  mutationData = consequenceId,
}: {
  role?: string | null;
  roles?: Array<string | null>;
  signedOut?: boolean;
  state?: string;
  targetKind?: string;
  subjectId?: string;
  history?: unknown[];
  mutationError?: unknown;
  mutationThrows?: boolean;
  mutationData?: unknown;
} = {}): ModerationServerClient {
  let roleIndex = 0;
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue({
        data: signedOut ? null : { claims: { sub: profileId } },
        error: signedOut ? { code: "signed_out" } : null,
      }),
    },
    rpc: vi.fn(async (name) => {
      if (name === "get_own_moderation_staff_access") {
        const current = roles ? roles[roleIndex++] : role;
        return { data: current ? [{ staff_role: current }] : [], error: null };
      }
      if (name === "get_moderation_case_detail")
        return {
          data: [
            {
              ...moderationDetailRow(),
              state,
              target_kind: targetKind,
              subject_profile_id: subjectId,
            },
          ],
          error: null,
        };
      if (name === "list_moderation_case_consequence_history")
        return { data: episodes, error: null };
      if (name.startsWith("apply_") || name.startsWith("revoke_")) {
        if (mutationThrows) throw new Error("private transport diagnostics");
        return { data: mutationData, error: mutationError };
      }
      throw new Error(`Unexpected RPC ${name}`);
    }),
  };
}
