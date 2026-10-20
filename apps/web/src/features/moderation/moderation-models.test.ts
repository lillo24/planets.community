import { describe, expect, it } from "vitest";

import {
  decodeModerationCursor,
  encodeModerationCursor,
  parseModerationCase,
  parseModerationCounterstatement,
  parseModerationQueue,
} from "./moderation-models";
import {
  moderationCounterstatementRow,
  moderationDetailRow,
  moderationQueueRow,
} from "./moderation-test-fixtures";

describe("moderation model parsing", () => {
  it.each([
    "group_contact_request",
    "group_contact_message",
    "group_coordination_proposal",
    "member_contact_request",
    "member_contact_message",
  ])(
    "keeps %s reports reviewable after the author's profile is erased",
    (targetKind) => {
      const subject = {
        target_kind: targetKind,
        subject_profile_id: null,
        subject_display_name: "Deleted account",
      };
      expect(
        parseModerationQueue([{ ...moderationQueueRow(), ...subject }])[0],
      ).toMatchObject({
        targetKind,
        subjectProfileId: null,
        subjectDisplayName: "Deleted account",
      });
      expect(
        parseModerationCase([{ ...moderationDetailRow(), ...subject }]),
      ).toMatchObject({
        targetKind,
        subjectProfileId: null,
        subjectDisplayName: "Deleted account",
      });
      expect(() =>
        parseModerationQueue([
          { ...moderationQueueRow(), ...subject, subject_profile_id: "bad" },
        ]),
      ).toThrow("malformed");
    },
  );
  it("keeps genuine group targets and their accountable human subjects", () => {
    const group = { target_kind: "group", target_summary: "Group" };
    expect(
      parseModerationQueue([{ ...moderationQueueRow(), ...group }])[0],
    ).toMatchObject({
      targetKind: "group",
      subjectProfileId: moderationQueueRow().subject_profile_id,
    });
    expect(
      parseModerationCase([{ ...moderationDetailRow(), ...group }]),
    ).toMatchObject({
      targetKind: "group",
      subjectProfileId: moderationDetailRow().subject_profile_id,
    });
    expect(() =>
      parseModerationQueue([
        { ...moderationQueueRow(), ...group, subject_profile_id: null },
      ]),
    ).toThrow("malformed");
  });

  it("keeps organization template cases visible without weakening other subjects", () => {
    const organization = {
      target_kind: "proposal_template",
      subject_profile_id: null,
      subject_display_name: "Planets Community Official",
    };
    expect(
      parseModerationQueue([{ ...moderationQueueRow(), ...organization }])[0]
        .subjectProfileId,
    ).toBeNull();
    expect(
      parseModerationCase([{ ...moderationDetailRow(), ...organization }])
        ?.subjectDisplayName,
    ).toBe("Planets Community Official");
    expect(() =>
      parseModerationQueue([
        { ...moderationQueueRow(), subject_profile_id: null },
      ]),
    ).toThrow("malformed");
  });
  it("parses a bounded queue row and round-trips its cursor", () => {
    const row = moderationQueueRow();
    const parsed = parseModerationQueue([row]);
    expect(parsed[0]).toMatchObject({
      state: "received",
      targetSummary: "Project chat message",
    });
    const cursor = encodeModerationCursor({
      createdAt: row.created_at,
      caseId: row.case_id,
    });
    expect(decodeModerationCursor(cursor)).toEqual({
      createdAt: row.created_at,
      caseId: row.case_id,
    });
    expect(decodeModerationCursor("not-a-cursor"), undefined);
  });

  it("parses private notes and chronology only from the staff detail shape", () => {
    const detail = parseModerationCase([moderationDetailRow()]);
    expect(detail?.notes[0].body).toBe("Private note");
    expect(detail?.events.map((event) => event.eventKind)).toEqual([
      "report_received",
      "note_added",
    ]);
  });

  it("rejects invented enforcement states", () => {
    expect(() =>
      parseModerationQueue([{ ...moderationQueueRow(), state: "sanctioned" }]),
    ).toThrow("malformed");
  });

  it("parses pending and submitted counterparty evidence", () => {
    expect(
      parseModerationCounterstatement([moderationCounterstatementRow()]),
    ).toMatchObject({ recipientDisplayName: "Taylor", statement: null });
    expect(
      parseModerationCounterstatement([
        moderationCounterstatementRow("My private version of events."),
      ]),
    ).toMatchObject({
      statement: "My private version of events.",
      submittedAt: "2026-09-28T10:05:00Z",
    });
    expect(parseModerationCounterstatement([])).toBeNull();
    expect(() =>
      parseModerationCounterstatement([
        {
          ...moderationCounterstatementRow("My private version of events."),
          submitted_at: null,
        },
      ]),
    ).toThrow("malformed");
  });
});
