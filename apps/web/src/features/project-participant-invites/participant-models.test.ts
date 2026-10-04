import { describe, expect, it } from "vitest";
import {
  mapParticipantFailure,
  parseAdmissionReceipt,
  parseCurrentParticipation,
  parseParticipantPreview,
} from "./participant-models";
import { project, receipt } from "./participant-test-fixtures";

const available = {
  available: true,
  project_id: project.id,
  project_kind: "one_time",
  project_title: "Mural",
};
const unavailable = {
  available: false,
  project_id: null,
  project_kind: null,
  project_title: null,
};
const admission = {
  project_id: receipt.projectId,
  outcome: receipt.outcome,
  membership_id: receipt.membershipId,
  membership_status: receipt.membershipStatus,
  replayed: false,
};
const episode = {
  project_id: project.id,
  project_kind: "one_time",
  membership_id: receipt.membershipId,
  membership_status: "left",
  joined_at: "2026-10-04T12:00:00Z",
};
describe("participant wire contracts", () => {
  it("retains only the public preview contract for both kinds", () => {
    expect(
      parseParticipantPreview([{ ...available, issuer_name: "private" }]),
    ).toEqual({ available: true, project, title: "Mural" });
    expect(
      parseParticipantPreview([{ ...available, project_kind: "recurring" }]),
    ).toMatchObject({ project: { kind: "recurring" } });
    expect(parseParticipantPreview([unavailable])).toEqual({
      available: false,
    });
  });
  it.each(
    [
      null,
      [],
      [available, available],
      [{ ...unavailable, project_title: "leak" }],
      [{ ...available, project_id: "bad" }],
      [{ ...available, available: "true" }],
      [{ ...available, project_kind: "group" }],
      [{ ...available, project_title: " " }],
    ].map((value) => ({ value })),
  )(
    "rejects malformed preview $value without inventing unavailable",
    ({ value }) => {
      expect(() => parseParticipantPreview(value)).toThrow(/malformed/);
    },
  );
  it.each(["current", "left", "removed"])(
    "preserves original joined outcome with %s episode",
    (status) => {
      expect(
        parseAdmissionReceipt([
          { ...admission, membership_status: status, replayed: true },
        ]),
      ).toMatchObject({
        outcome: "joined",
        membershipStatus: status,
        replayed: true,
      });
    },
  );
  it("allows only Creator null/null and already-joined episode receipts", () => {
    expect(
      parseAdmissionReceipt([
        {
          ...admission,
          outcome: "creator",
          membership_id: null,
          membership_status: null,
        },
      ]),
    ).toMatchObject({
      outcome: "creator",
      membershipId: null,
      membershipStatus: null,
    });
    expect(
      parseAdmissionReceipt([{ ...admission, outcome: "already_joined" }]),
    ).toMatchObject({ outcome: "already_joined" });
  });
  it.each(
    [
      [],
      [admission, admission],
      [{ ...admission, replayed: 1 }],
      [{ ...admission, project_id: "bad" }],
      [{ ...admission, membership_id: null }],
      [{ ...admission, membership_status: null }],
      [{ ...admission, membership_status: "pending" }],
      [{ ...admission, outcome: "creator" }],
      [{ ...admission, outcome: "accepted" }],
    ].map((value) => ({ value })),
  )("rejects malformed admission $value", ({ value }) => {
    expect(() => parseAdmissionReceipt(value)).toThrow(/malformed/);
  });
  it("finds newer current membership independently of an ended receipt", () => {
    expect(
      parseCurrentParticipation(
        [
          episode,
          {
            ...episode,
            membership_id: "00000000-0000-4000-8000-000000000005",
            membership_status: "current",
          },
        ],
        "none",
        project,
      ),
    ).toEqual({ current: true, creator: false });
    expect(parseCurrentParticipation([], "creator", project)).toEqual({
      current: false,
      creator: true,
    });
    expect(parseCurrentParticipation([episode], "co_creator", project)).toEqual(
      { current: false, creator: false },
    );
  });
  it.each(
    [
      [episode, episode],
      [{ ...episode, project_kind: "recurring" }],
      [{ ...episode, membership_status: "pending" }],
      [{ ...episode, joined_at: "bad" }],
    ].map((value) => ({ value })),
  )("rejects inconsistent own memberships $value", ({ value }) => {
    expect(() => parseCurrentParticipation(value, "none", project)).toThrow(
      /malformed/,
    );
  });
  it.each([
    ["PT409", "This Project is full.", "full"],
    ["PT409", "secret unavailable", "unavailable"],
    ["42501", "private", "identity"],
    ["55000", "private", "profile"],
    ["22023", "private", "input"],
    ["XX000", "private", "network"],
  ])("maps %s into useful safe state", (code, message, expected) => {
    expect(mapParticipantFailure({ code, message })).toBe(expected);
  });
});
