import { describe, expect, it } from "vitest";
import { parseModerationCase } from "./moderation-models";
import {
  consequenceChoices,
  parseConsequenceActionResult,
  parseConsequenceCommand,
  parseConsequenceForm,
  parseConsequenceHistory,
} from "./moderation-consequence-models";
import {
  moderationConsequenceRow,
  moderationDetailRow,
} from "./moderation-test-fixtures";

const caseId = moderationDetailRow().case_id;
const staffId = moderationConsequenceRow().actor_profile_id;
const valid = {
  mode: "apply",
  caseId,
  type: "safety_notice",
  userReason: "  Public explanation  ",
  internalNote: "  Private evidence reference  ",
};

describe("consequence command boundary", () => {
  it("normalizes the two distinct text fields without merging them", () => {
    expect(parseConsequenceCommand(valid)).toEqual({
      ...valid,
      userReason: "Public explanation",
      internalNote: "Private evidence reference",
    });
  });
  it.each([
    { ...valid, userReason: " \n " },
    { ...valid, internalNote: " \t " },
    { ...valid, userReason: "a".repeat(2001) },
    { ...valid, internalNote: "a".repeat(4001) },
    { ...valid, type: "permanent_ban" },
    { ...valid, mode: "auto" },
    { ...valid, caseId: "../../admin" },
    { ...valid, staffProfileId: staffId },
    { ...valid, targetProfileId: staffId },
    { ...valid, mode: "revoke" },
    { ...valid, consequenceId: staffId },
    { ...valid, userReason: {} },
    null,
    [],
  ])(
    "rejects malformed, missing, excessive or extra browser input %#",
    (input) => {
      expect(parseConsequenceCommand(input)).toBeNull();
    },
  );
  it("counts Unicode characters consistently with PostgreSQL", () => {
    expect(
      parseConsequenceCommand({
        ...valid,
        userReason: "😀".repeat(2000),
        internalNote: "😀".repeat(4000),
      }),
    ).not.toBeNull();
    expect(
      parseConsequenceCommand({ ...valid, userReason: "😀".repeat(2001) }),
    ).toBeNull();
  });
  it("accepts only Next action metadata in addition to the exact command fields", () => {
    const data = form();
    data.append("$ACTION_REF_0", "transport");
    expect(parseConsequenceForm(data)).not.toBeNull();
    data.append("expectedStaffProfileId", staffId);
    expect(parseConsequenceForm(data)).toBeNull();
  });
  it("rejects duplicate form entries and File bodies", () => {
    const duplicate = form();
    duplicate.append("type", "account_suspension");
    expect(parseConsequenceForm(duplicate)).toBeNull();
    const file = form();
    file.set("userReason", new File(["secret"], "evidence.txt"));
    expect(parseConsequenceForm(file)).toBeNull();
  });
  it.each([
    null,
    {},
    { status: "idle" },
    { status: "success" },
    { status: "error", kind: "raw SQL" },
    { status: "success", kind: "applied", sql: "secret" },
  ])("fails explicitly on malformed action result %#", (result) => {
    expect(parseConsequenceActionResult(result)).toEqual({
      status: "error",
      kind: "unavailable",
    });
  });
});

describe("immutable current-case episodes", () => {
  it("keeps each revoked episode and a subsequent active episode separate", () => {
    const first = {
      ...moderationConsequenceRow(),
      revoked_at: "2026-09-28T11:00:00Z",
    };
    const revoke = {
      ...first,
      action_id: "00000000-0000-4000-8000-000000000933",
      action_kind: "revoked",
      user_reason: "The restriction is lifted.",
      action_at: first.revoked_at,
    };
    const later = {
      ...moderationConsequenceRow(),
      consequence_id: "00000000-0000-4000-8000-000000000934",
      action_id: "00000000-0000-4000-8000-000000000935",
      applied_at: "2026-09-29T10:00:00Z",
      action_at: "2026-09-29T10:00:00Z",
    };
    const episodes = parseConsequenceHistory([later, revoke, first]);
    expect(episodes).toHaveLength(2);
    expect(episodes[0].actions.map((action) => action.kind)).toEqual([
      "applied",
      "revoked",
    ]);
    expect(episodes[1].revokedAt).toBeNull();
  });
  it("preserves stored plain text rather than reformatting history", () => {
    expect(
      parseConsequenceHistory([
        {
          ...moderationConsequenceRow(),
          user_reason: "\nQuoted explanation\n",
        },
      ])[0].actions[0].userReason,
    ).toBe("\nQuoted explanation\n");
  });
  it.each([
    null,
    [{}],
    [{ ...moderationConsequenceRow(), consequence_type: "ban" }],
    [{ ...moderationConsequenceRow(), consequence_id: "bad" }],
    [{ ...moderationConsequenceRow(), applied_at: "invalid" }],
    [{ ...moderationConsequenceRow(), action_kind: "revoked" }],
    [{ ...moderationConsequenceRow(), revoked_at: "2026-09-28T11:00:00Z" }],
    [{ ...moderationConsequenceRow(), consequence_type: "content_hide" }],
    [{ ...moderationConsequenceRow(), project_id: staffId }],
    [moderationConsequenceRow(), moderationConsequenceRow()],
    [
      moderationConsequenceRow(),
      { ...moderationConsequenceRow(), affected_profile_id: staffId },
    ],
  ])(
    "never presents malformed or incomplete history as empty/success %#",
    (data) => {
      expect(() => parseConsequenceHistory(data)).toThrow(
        "response was malformed",
      );
    },
  );
});

describe("case and role compatible choices", () => {
  const detail = parseModerationCase([
    { ...moderationDetailRow(), state: "under_review" },
  ])!;
  it("offers profile-scoped actions for message/request cases, not an arbitrary content hide", () => {
    expect(
      consequenceChoices(detail, [], "moderator", staffId).map(
        (choice) => choice.type,
      ),
    ).toEqual(["safety_notice", "interaction_restriction"]);
    expect(
      consequenceChoices(
        { ...detail, targetKind: "resource_request" },
        [],
        "admin",
        staffId,
      ).map((choice) => choice.type),
    ).toEqual([
      "safety_notice",
      "interaction_restriction",
      "account_suspension",
    ]);
  });
  it.each(["project", "resource_listing"] as const)(
    "offers accurate direct %s content hiding without a caller-supplied target",
    (targetKind) => {
      const choice = consequenceChoices(
        { ...detail, targetKind },
        [],
        "moderator",
        staffId,
      ).find((choice) => choice.type === "content_hide")!;
      expect(choice.mode).toBe("apply");
      expect(choice.effect).toContain(
        targetKind === "project" ? "Project" : "Resource listing",
      );
      expect(choice.effect).toContain(
        "existing pending requests remain pending",
      );
      expect(choice).not.toHaveProperty("targetId");
    },
  );
  it("does not offer received-case apply but allows completed-case actions", () => {
    expect(
      consequenceChoices(
        { ...detail, state: "received" },
        [],
        "admin",
        staffId,
      ),
    ).toEqual([]);
    expect(
      consequenceChoices(
        { ...detail, state: "completed" },
        [],
        "admin",
        staffId,
      ),
    ).toHaveLength(3);
  });
  it("does not offer self-suspension to an admin", () => {
    expect(
      consequenceChoices(
        { ...detail, subjectProfileId: staffId },
        [],
        "admin",
        staffId,
      ).map((choice) => choice.type),
    ).not.toContain("account_suspension");
  });
  it("offers only active episode revocation and preserves independent types", () => {
    const episodes = parseConsequenceHistory([moderationConsequenceRow()]);
    const choices = consequenceChoices(detail, episodes, "moderator", staffId);
    expect(choices.map((choice) => [choice.mode, choice.type])).toEqual([
      ["revoke", "safety_notice"],
      ["apply", "interaction_restriction"],
    ]);
    expect(choices[0].consequenceId).toBe(episodes[0].consequenceId);
    expect(
      consequenceChoices(
        { ...detail, state: "received" },
        episodes,
        "moderator",
        staffId,
      ),
    ).toHaveLength(1);
  });
  it("never offers unsuspension to a moderator, even for a visible active episode", () => {
    const episodes = parseConsequenceHistory([
      { ...moderationConsequenceRow(), consequence_type: "account_suspension" },
    ]);
    expect(
      consequenceChoices(detail, episodes, "moderator", staffId).map(
        (choice) => choice.type,
      ),
    ).not.toContain("account_suspension");
    expect(
      consequenceChoices(detail, episodes, "admin", staffId).find(
        (choice) => choice.type === "account_suspension",
      ),
    ).toMatchObject({ mode: "revoke", label: "Unsuspend account" });
  });
});

function form() {
  const data = new FormData();
  for (const [key, value] of Object.entries(valid)) data.set(key, value);
  return data;
}
